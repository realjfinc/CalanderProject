import assert from "node:assert/strict";
import { test } from "node:test";

import { buildExtractionRequest, buildScreenshotEvent } from "../src/eventPayload.js";

test("buildExtractionRequest produces an image-type request for the extractEvent function", () => {
  const request = buildExtractionRequest({ base64: "abc123", mimeType: "image/png", timezone: "UTC+00:00" });
  assert.deepEqual(request, { type: "image", data: "abc123", mimeType: "image/png", timezone: "UTC+00:00" });
});

test("buildExtractionRequest rejects a missing field", () => {
  assert.throws(() => buildExtractionRequest({ base64: "x", mimeType: "image/png" }));
});

test("buildScreenshotEvent always sets source=screenshot, sourceId=null, tag=null", () => {
  const event = buildScreenshotEvent({
    title: "Fundraiser",
    location: "City Hall",
    startUtc: "2026-05-01T18:00:00.000Z",
    endUtc: "2026-05-01T19:00:00.000Z",
    notes: "Bring ID",
    attachmentUrl: "https://example.com/screenshot.png",
  });

  assert.equal(event.source, "screenshot");
  assert.equal(event.sourceId, null);
  assert.equal(event.tag, null);
  assert.equal(event.title, "Fundraiser");
  assert.deepEqual(event.attachments, ["https://example.com/screenshot.png"]);
});

test("buildScreenshotEvent mirrors the canonical fields into the dashboard's own field names", () => {
  const event = buildScreenshotEvent({
    title: "Fundraiser",
    startUtc: "2026-05-01T18:00:00.000Z",
    endUtc: "2026-05-01T19:00:00.000Z",
  });

  // The shared firestore.rules schema requires both field pairs to be
  // present and consistent on every event write, screenshot-sourced ones
  // included -- see the doc comment on buildScreenshotEvent.
  assert.equal(event.startAt, event.start);
  assert.equal(event.endAt, event.end);
  assert.equal(event.allDay, false);
  assert.equal(event.tagId, event.tag);
  assert.equal(event.flexible, event.importance === "flexible");
});

test("buildScreenshotEvent defaults a blank title and normalizes blank fields to null", () => {
  const event = buildScreenshotEvent({
    title: "   ",
    location: "",
    startUtc: "2026-01-01T00:00:00.000Z",
    endUtc: "2026-01-01T01:00:00.000Z",
    notes: "",
    attachmentUrl: null,
  });

  assert.equal(event.title, "Untitled event");
  assert.equal(event.location, null);
  assert.equal(event.notes, null);
  assert.equal(event.attachments, null);
});

test("buildScreenshotEvent requires a start and end time", () => {
  assert.throws(() => buildScreenshotEvent({ title: "x", startUtc: null, endUtc: "2026-01-01T00:00:00.000Z" }));
  assert.throws(() => buildScreenshotEvent({ title: "x", startUtc: "2026-01-01T00:00:00.000Z", endUtc: null }));
});

test("buildScreenshotEvent never accepts a caller-supplied source, sourceId, or tag override", () => {
  const event = buildScreenshotEvent({
    title: "x",
    startUtc: "2026-01-01T00:00:00.000Z",
    endUtc: "2026-01-01T01:00:00.000Z",
    source: "manual",
    sourceId: "should-be-ignored",
    tag: "should-be-ignored",
  });

  assert.equal(event.source, "screenshot");
  assert.equal(event.sourceId, null);
  assert.equal(event.tag, null);
});
