import assert from "node:assert/strict";
import { test } from "node:test";

import {
  ExtractionNormalizationError,
  normalizeExtractedEvent,
} from "../src/extraction/normalizeEvent";

test("normalizes a start time that already has a UTC offset", () => {
  const result = normalizeExtractedEvent(
    { title: "Team Standup", start: "2026-03-02T09:00:00-05:00", end: "2026-03-02T09:30:00-05:00" },
    "America/Los_Angeles",
  );
  assert.equal(result.startUtc, "2026-03-02T14:00:00.000Z");
  assert.equal(result.endUtc, "2026-03-02T14:30:00.000Z");
});

test("interprets an offset-less time using the supplied timezone", () => {
  const result = normalizeExtractedEvent(
    { title: "Block Party", start: "2026-07-04T19:00:00" },
    "America/New_York", // UTC-4 in July (DST)
  );
  assert.equal(result.startUtc, "2026-07-04T23:00:00.000Z");
});

test("defaults a missing end time to one hour after start", () => {
  const result = normalizeExtractedEvent({ title: "Call", start: "2026-01-01T10:00:00Z" }, "UTC");
  assert.equal(result.startUtc, "2026-01-01T10:00:00.000Z");
  assert.equal(result.endUtc, "2026-01-01T11:00:00.000Z");
});

test("defaults a missing/blank title", () => {
  const result = normalizeExtractedEvent({ start: "2026-01-01T10:00:00Z", title: "   " }, "UTC");
  assert.equal(result.title, "Untitled event");
});

test("normalizes blank location/notes to null", () => {
  const result = normalizeExtractedEvent(
    { start: "2026-01-01T10:00:00Z", location: "  ", notes: "" },
    "UTC",
  );
  assert.equal(result.location, null);
  assert.equal(result.notes, null);
});

test("throws when there is no start time at all", () => {
  assert.throws(
    () => normalizeExtractedEvent({ title: "Mystery event" }, "UTC"),
    ExtractionNormalizationError,
  );
});

test("throws when the start time cannot be parsed", () => {
  assert.throws(
    () => normalizeExtractedEvent({ start: "not a date" }, "UTC"),
    ExtractionNormalizationError,
  );
});
