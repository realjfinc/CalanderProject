import { DateTime } from "luxon";

import type { ExtractedEvent, RawLlmEventOutput } from "./types";

export class ExtractionNormalizationError extends Error {}

const DEFAULT_DURATION_MINUTES = 60;

/**
 * Converts the LLM's raw extraction into the canonical, UTC-normalized
 * shape the client can show in its confirm-before-commit UI.
 *
 * Per the project's hard contract, timestamps are normalized to UTC at the
 * point of ingestion — this is that point. `timezone` is the IANA zone the
 * client is in, used only to disambiguate a start/end string that doesn't
 * carry its own offset (e.g. a flyer that just says "7:00 PM" with no
 * timezone information of its own).
 */
export function normalizeExtractedEvent(raw: RawLlmEventOutput, timezone: string): ExtractedEvent {
  const start = parseToUtc(raw.start, timezone);
  if (start === null) {
    throw new ExtractionNormalizationError(
      "Could not determine a start time from the extracted content.",
    );
  }

  const parsedEnd = parseToUtc(raw.end, timezone);
  const end = parsedEnd ?? start.plus({ minutes: DEFAULT_DURATION_MINUTES });

  const title = normalizeText(raw.title) ?? "Untitled event";

  return {
    title,
    location: normalizeText(raw.location),
    startUtc: start.toUTC().toISO()!,
    endUtc: end.toUTC().toISO()!,
    notes: normalizeText(raw.notes),
  };
}

function parseToUtc(value: string | null | undefined, timezone: string): DateTime | null {
  if (!value) return null;
  const parsed = DateTime.fromISO(value, { zone: timezone });
  return parsed.isValid ? parsed : null;
}

function normalizeText(value: string | null | undefined): string | null {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
}
