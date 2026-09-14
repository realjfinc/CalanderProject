import type { LlmClient } from "./llmClient";
import { extractPdfText } from "./pdfText";
import { fetchLinkText } from "./linkFetcher";
import { normalizeExtractedEvent } from "./normalizeEvent";
import type { ExtractedEvent, ExtractRequest } from "./types";

export class InvalidExtractRequestError extends Error {}

// Base64 is ~4/3 the size of the decoded bytes; these are generous caps on
// the *encoded* string length, chosen to comfortably fit a real photo or
// document while still rejecting a deliberately oversized payload before it
// reaches the LLM API (cost) or the PDF parser (memory/CPU).
const MAX_IMAGE_BASE64_LENGTH = 10_000_000; // ~7.5 MB decoded
const MAX_PDF_BASE64_LENGTH = 20_000_000; // ~15 MB decoded
const MAX_URL_LENGTH = 2048;
const ALLOWED_IMAGE_MIME_TYPES = new Set(["image/png", "image/jpeg", "image/webp", "image/heic", "image/heif"]);

/**
 * Orchestrates one extraction request end-to-end: get the request's content
 * into text/image form, ask the LLM for structured event data, normalize
 * timestamps to UTC. Does not touch Firestore — nothing is saved here; the
 * client only writes the event once the user confirms it (per spec, this
 * step never auto-commits an extracted event).
 */
export async function extractEvent(
  request: ExtractRequest,
  llmClient: LlmClient,
  fetchLinkTextFn: typeof fetchLinkText = fetchLinkText,
): Promise<ExtractedEvent> {
  const raw = await (async () => {
    switch (request.type) {
      case "image":
        if (!request.data || !request.mimeType) {
          throw new InvalidExtractRequestError("Image extraction requires data and mimeType.");
        }
        if (!ALLOWED_IMAGE_MIME_TYPES.has(request.mimeType)) {
          throw new InvalidExtractRequestError(`Unsupported image type: ${request.mimeType}.`);
        }
        if (request.data.length > MAX_IMAGE_BASE64_LENGTH) {
          throw new InvalidExtractRequestError("That image is too large.");
        }
        return llmClient.extractEvent({
          kind: "image",
          base64: request.data,
          mimeType: request.mimeType,
        });

      case "pdf": {
        if (!request.data) {
          throw new InvalidExtractRequestError("PDF extraction requires data.");
        }
        if (request.data.length > MAX_PDF_BASE64_LENGTH) {
          throw new InvalidExtractRequestError("That PDF is too large.");
        }
        const text = await extractPdfText(Buffer.from(request.data, "base64"));
        return llmClient.extractEvent({ kind: "text", text });
      }

      case "link": {
        if (!request.url) {
          throw new InvalidExtractRequestError("Link extraction requires a url.");
        }
        if (request.url.length > MAX_URL_LENGTH) {
          throw new InvalidExtractRequestError("That link is too long.");
        }
        const text = await fetchLinkTextFn(request.url);
        return llmClient.extractEvent({ kind: "text", text });
      }
    }
  })();

  return normalizeExtractedEvent(raw, request.timezone);
}
