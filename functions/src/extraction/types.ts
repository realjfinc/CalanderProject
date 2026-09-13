/** Request payload for the `extractEvent` callable function. */
export type ExtractRequest =
  | { type: "image"; data: string; mimeType: string; timezone: string }
  | { type: "pdf"; data: string; timezone: string }
  | { type: "link"; url: string; timezone: string };

/**
 * What we ask the LLM to return. Intentionally a small, flat shape — this is
 * the contract the prompt instructs the model to produce, not the full
 * canonical event schema (importance/reminders/repeat/etc. are not
 * extraction concerns; they're either defaulted by the client on save or
 * set later by the user).
 */
export interface RawLlmEventOutput {
  title?: string | null;
  location?: string | null;
  /** ISO-8601. May omit a UTC offset, in which case `timezone` disambiguates it. */
  start?: string | null;
  /** ISO-8601, same rules as `start`. */
  end?: string | null;
  notes?: string | null;
}

/** Extraction output after UTC normalization — what the client receives. */
export interface ExtractedEvent {
  title: string;
  location: string | null;
  startUtc: string;
  endUtc: string;
  notes: string | null;
}
