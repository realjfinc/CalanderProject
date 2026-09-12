import type { LlmClient } from "./llmClient";
import { extractPdfText } from "./pdfText";
import { fetchLinkText } from "./linkFetcher";
import { normalizeExtractedEvent } from "./normalizeEvent";
import type { ExtractedEvent, ExtractRequest } from "./types";

export class InvalidExtractRequestError extends Error {}

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
        return llmClient.extractEvent({
          kind: "image",
          base64: request.data,
          mimeType: request.mimeType,
        });

      case "pdf": {
        if (!request.data) {
          throw new InvalidExtractRequestError("PDF extraction requires data.");
        }
        const text = await extractPdfText(Buffer.from(request.data, "base64"));
        return llmClient.extractEvent({ kind: "text", text });
      }

      case "link": {
        if (!request.url) {
          throw new InvalidExtractRequestError("Link extraction requires a url.");
        }
        const text = await fetchLinkTextFn(request.url);
        return llmClient.extractEvent({ kind: "text", text });
      }
    }
  })();

  return normalizeExtractedEvent(raw, request.timezone);
}
