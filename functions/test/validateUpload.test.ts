import assert from "node:assert/strict";
import { test } from "node:test";
import { MAX_UPLOAD_BYTES, validateUploadedFile } from "../src/storage/validateUpload";

const UPLOAD_PATH = "users/alice/uploads/e1.png";

const PNG_HEADER = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
const JPEG_HEADER = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0]);
const WEBP_HEADER = Buffer.concat([Buffer.from("RIFF"), Buffer.from([0, 0, 0, 0]), Buffer.from("WEBP")]);
const HEIC_HEADER = Buffer.concat([Buffer.from([0, 0, 0, 0]), Buffer.from("ftyp"), Buffer.from("heic")]);
const HEIF_HEADER = Buffer.concat([Buffer.from([0, 0, 0, 0]), Buffer.from("ftyp"), Buffer.from("mif1")]);
const PDF_HEADER = Buffer.from("%PDF-1.7\n%\xe2\xe3\xcf\xd3", "binary");
const EXE_HEADER = Buffer.from([0x4d, 0x5a, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00]); // "MZ" (Windows PE)

test("accepts a real PNG within the size limit", () => {
  const result = validateUploadedFile({ path: UPLOAD_PATH, size: 1024, header: PNG_HEADER });
  assert.equal(result.valid, true);
});

for (const [label, header] of Object.entries({
  PNG: PNG_HEADER,
  JPEG: JPEG_HEADER,
  WEBP: WEBP_HEADER,
  HEIC: HEIC_HEADER,
  HEIF: HEIF_HEADER,
  PDF: PDF_HEADER,
})) {
  test(`accepts a real ${label} file by its magic bytes`, () => {
    const result = validateUploadedFile({ path: UPLOAD_PATH, size: 1024, header });
    assert.equal(result.valid, true);
  });
}

test("rejects a Windows executable renamed with a .png extension and an image Content-Type", () => {
  const result = validateUploadedFile({ path: UPLOAD_PATH, size: 1024, header: EXE_HEADER });
  assert.equal(result.valid, false);
  assert.match(result.reason ?? "", /doesn't match any allowed type/);
});

test("rejects plain text content", () => {
  const result = validateUploadedFile({
    path: UPLOAD_PATH,
    size: 1024,
    header: Buffer.from("#!/bin/sh\nrm -rf /\n"),
  });
  assert.equal(result.valid, false);
});

test("rejects a file over the size cap even with a real image header", () => {
  const result = validateUploadedFile({
    path: UPLOAD_PATH,
    size: MAX_UPLOAD_BYTES + 1,
    header: PNG_HEADER,
  });
  assert.equal(result.valid, false);
  assert.match(result.reason ?? "", /limit/);
});

test("accepts a file exactly at the size cap", () => {
  const result = validateUploadedFile({ path: UPLOAD_PATH, size: MAX_UPLOAD_BYTES, header: PNG_HEADER });
  assert.equal(result.valid, true);
});

test("only governs paths under users/{uid}/uploads/ -- anything else fails open", () => {
  const result = validateUploadedFile({
    path: "some/other/path.png",
    size: MAX_UPLOAD_BYTES + 1,
    header: EXE_HEADER,
  });
  assert.equal(result.valid, true);
});

test("a header shorter than any real signature is rejected, not treated as a match", () => {
  const result = validateUploadedFile({ path: UPLOAD_PATH, size: 10, header: Buffer.from([0x89, 0x50]) });
  assert.equal(result.valid, false);
});
