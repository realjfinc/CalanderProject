import type { RawLlmEventOutput } from "./types";
import { EXTRACTION_SYSTEM_PROMPT, buildExtractionUserPrompt } from "./promptBuilder";

export type LlmExtractionInput =
  | { kind: "text"; text: string }
  | { kind: "image"; base64: string; mimeType: string };

/** Seam over the actual LLM call so extraction orchestration is unit-testable. */
export interface LlmClient {
  extractEvent(input: LlmExtractionInput): Promise<RawLlmEventOutput>;
}

export class LlmResponseError extends Error {}

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_MODEL = "claude-sonnet-4-5-20250929";
const ANTHROPIC_VERSION = "2023-06-01";

/**
 * Production `LlmClient` calling the Claude API directly. Requires the
 * `ANTHROPIC_API_KEY` secret to be configured on the function (see
 * functions/README.md) — this is a deployment-time dependency, not
 * something bundled with the code.
 */
export class AnthropicLlmClient implements LlmClient {
  constructor(
    private readonly apiKey: string,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  async extractEvent(input: LlmExtractionInput): Promise<RawLlmEventOutput> {
    const content =
      input.kind === "text"
        ? [{ type: "text", text: buildExtractionUserPrompt(input.text) }]
        : [
            {
              type: "image",
              source: { type: "base64", media_type: input.mimeType, data: input.base64 },
            },
            { type: "text", text: buildExtractionUserPrompt("(see attached image)") },
          ];

    const response = await this.fetchFn(ANTHROPIC_API_URL, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": this.apiKey,
        "anthropic-version": ANTHROPIC_VERSION,
      },
      body: JSON.stringify({
        model: ANTHROPIC_MODEL,
        max_tokens: 1024,
        system: EXTRACTION_SYSTEM_PROMPT,
        messages: [{ role: "user", content }],
      }),
    });

    if (!response.ok) {
      throw new LlmResponseError(`LLM request failed with status ${response.status}`);
    }

    const body = (await response.json()) as { content?: Array<{ type: string; text?: string }> };
    const text = body.content?.find((block) => block.type === "text")?.text;
    if (!text) {
      throw new LlmResponseError("LLM response contained no text content.");
    }

    return parseJsonResponse(text);
  }
}

function parseJsonResponse(text: string): RawLlmEventOutput {
  // Models occasionally wrap JSON in a markdown fence despite instructions
  // not to; strip that defensively rather than failing the whole extraction.
  const unfenced = text.trim().replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/i, "");
  try {
    return JSON.parse(unfenced) as RawLlmEventOutput;
  } catch {
    throw new LlmResponseError("LLM response was not valid JSON.");
  }
}
