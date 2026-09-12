import assert from "node:assert/strict";
import { test } from "node:test";

import { currentTimezoneOffsetLabel } from "../src/timezoneOffset.js";

test("formats a moment with no local offset as UTC+00:00", () => {
  const utcNow = new Date();
  // getTimezoneOffset() reflects the *runner's* zone, not the Date's own —
  // fake a zero offset by constructing from getTimezoneOffset() itself.
  const zeroOffsetDate = {
    getTimezoneOffset: () => 0,
  };
  assert.equal(currentTimezoneOffsetLabel(zeroOffsetDate), "UTC+00:00");
});

test("a negative getTimezoneOffset (east of UTC) becomes a + label", () => {
  // e.g. UTC+2 reports getTimezoneOffset() === -120
  const date = { getTimezoneOffset: () => -120 };
  assert.equal(currentTimezoneOffsetLabel(date), "UTC+02:00");
});

test("a positive getTimezoneOffset (west of UTC) becomes a - label", () => {
  // e.g. UTC-5 reports getTimezoneOffset() === 300
  const date = { getTimezoneOffset: () => 300 };
  assert.equal(currentTimezoneOffsetLabel(date), "UTC-05:00");
});

test("handles a half-hour offset", () => {
  // e.g. UTC+5:30 reports getTimezoneOffset() === -330
  const date = { getTimezoneOffset: () => -330 };
  assert.equal(currentTimezoneOffsetLabel(date), "UTC+05:30");
});

test("matches the UTC±HH:MM shape the backend parser expects, by default", () => {
  const label = currentTimezoneOffsetLabel();
  assert.match(label, /^UTC[+-]\d{2}:\d{2}$/);
});
