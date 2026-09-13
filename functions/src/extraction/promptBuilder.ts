export const EXTRACTION_SYSTEM_PROMPT = `You extract calendar event details from user-supplied content (a flyer, screenshot, PDF, or web page). Respond with ONLY a single JSON object, no prose, no markdown fences, matching exactly this shape:
{
  "title": string | null,
  "location": string | null,
  "start": string | null,   // ISO-8601. Include a UTC offset (e.g. "2026-03-01T19:00:00-05:00") whenever the source specifies or implies a timezone. If no timezone is stated, omit the offset — the caller will interpret it in the user's local timezone.
  "end": string | null,     // Same rules as "start". Omit if the content doesn't state or imply an end time.
  "notes": string | null    // Any other relevant detail (e.g. "bring a dish to pass"), or null.
}
If you cannot determine a start time at all, set "start" to null. Never fabricate a date, time, or location that isn't stated or clearly implied by the content.`;

export function buildExtractionUserPrompt(textContent: string): string {
  return `Extract the event details from the following content:\n\n${textContent}`;
}
