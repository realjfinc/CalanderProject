import assert from "node:assert/strict";
import { test } from "node:test";

import { splitDataUrl } from "../src/dataUrl.js";

test("splits a PNG data URL into mime type and base64 payload", () => {
  const result = splitDataUrl("data:image/png;base64,iVBORw0KGgo=");
  assert.equal(result.mimeType, "image/png");
  assert.equal(result.base64, "iVBORw0KGgo=");
});

test("throws on a non-data-URL string", () => {
  assert.throws(() => splitDataUrl("https://example.com/image.png"));
});

test("throws on a data URL that isn't base64-encoded", () => {
  assert.throws(() => splitDataUrl("data:text/plain,hello"));
});
