import { HttpsError, onCall } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";

import { extractEvent as runExtraction } from "./extraction/extractEvent";
import { AnthropicLlmClient } from "./extraction/llmClient";
import type { ExtractRequest } from "./extraction/types";

const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");

/**
 * Callable Cloud Function: extracts structured event data from an uploaded
 * image, PDF, or link (Step 3). Returns the extracted fields for the
 * client's confirm-before-commit UI — never writes to Firestore itself.
 */
export const extractEvent = onCall({ secrets: [anthropicApiKey] }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to extract an event.");
  }

  const data = request.data as ExtractRequest;
  if (!data || typeof data.type !== "string" || typeof data.timezone !== "string") {
    throw new HttpsError("invalid-argument", "Request must include a type and timezone.");
  }

  const llmClient = new AnthropicLlmClient(anthropicApiKey.value());
  try {
    return await runExtraction(data, llmClient);
  } catch (error) {
    throw new HttpsError("invalid-argument", (error as Error).message);
  }
});
