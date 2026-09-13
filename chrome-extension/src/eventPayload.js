/**
 * Builds the `extractEvent` callable request for a captured screenshot.
 * Same Cloud Function as Step 3 (`functions/src/index.ts`) — no duplicate
 * extraction logic here, just a different `type`/content source.
 */
export function buildExtractionRequest({ base64, mimeType, timezone }) {
  if (!base64 || !mimeType || !timezone) {
    throw new Error("buildExtractionRequest requires base64, mimeType, and timezone.");
  }
  return { type: "image", data: base64, mimeType, timezone };
}

/**
 * Builds the canonical event fields to save after the user confirms an
 * extraction result. Deliberately framework-agnostic (plain ISO date
 * strings, not a Firestore Timestamp) so it's usable from a Node test
 * without pulling in the Firestore SDK — the caller converts to whatever
 * the write path needs.
 *
 * Per the hard contract: source is always "screenshot", sourceId and tag
 * are always null (only direct user action or Step 5's routing logic may
 * ever set tag) — this function does not accept overrides for any of those
 * three fields.
 *
 * Also includes the calendar dashboard's own field names (`startAt`/`endAt`/
 * `allDay`/`flexible`/`tagId`) alongside the canonical ones (`start`/`end`/
 * `tag`), mirroring the same values — the live `firestore.rules` schema
 * (shared with the dashboard's own event writes) requires both field pairs
 * to be present and consistent on every event document, screenshot-sourced
 * ones included. `createdAt`/`updatedAt` still need to be added by the
 * caller as Firestore server timestamps, which this framework-agnostic
 * function can't produce.
 *
 * `location` and `notes` are always strings, never `null`: unlike the
 * schema's other optional fields (`sourceId`, `tagId`, `attachments`, ...),
 * `validEvent()` requires `event.location is string` and `event.notes is
 * string` unconditionally, so a blank field must become `""`, not `null`
 * (Firestore rules' `is string` check fails on `null`) -- the same
 * convention `CalendarEvent.toMap()` already uses (`location ?? ''`,
 * `notes ?? ''`) on the Flutter side.
 */
export function buildScreenshotEvent({ title, location, startUtc, endUtc, notes, attachmentUrl }) {
  if (!startUtc || !endUtc) {
    throw new Error("buildScreenshotEvent requires startUtc and endUtc.");
  }
  return {
    title: title && title.trim() ? title.trim() : "Untitled event",
    location: location && location.trim() ? location.trim() : "",
    start: startUtc,
    end: endUtc,
    startAt: startUtc,
    endAt: endUtc,
    allDay: false,
    source: "screenshot",
    sourceId: null,
    status: "active",
    tag: null,
    tagId: null,
    importance: "flexible",
    flexible: true,
    notes: notes && notes.trim() ? notes.trim() : "",
    attachments: attachmentUrl ? [attachmentUrl] : null,
    repeat: null,
    reminders: null,
  };
}
