/** MIME types the extraction pipeline (`extraction/extractEvent.ts`) and
 * event attachments actually accept -- kept in sync with
 * `ALLOWED_IMAGE_MIME_TYPES` there, plus PDF for the document case.
 */
export const ALLOWED_UPLOAD_CONTENT_TYPES = new Set([
  "image/png",
  "image/jpeg",
  "image/webp",
  "image/heic",
  "image/heif",
  "application/pdf",
]);

/** Mirrors extraction's own caps (~7.5MB decoded image, ~15MB decoded PDF)
 * with headroom for the raw stored copy being slightly larger than what
 * actually gets sent to the LLM.
 */
export const MAX_UPLOAD_BYTES = 20 * 1024 * 1024;

const UPLOAD_PATH_PATTERN = /^users\/[^/]+\/uploads\/[^/]+$/;

export interface UploadValidationResult {
  valid: boolean;
  reason?: string;
}

/**
 * Checks a just-uploaded file against the same content-type and size
 * rules the extraction endpoint already enforces on its own request
 * payload -- but here against the file's *actual* bytes, not what the
 * client's upload request claimed. Storage rules can check a client-set
 * `Content-Type` at write time, but that header is just client-supplied
 * metadata; a renamed executable can claim `image/png` just as easily as
 * a real one. This only trusts what the file's own magic bytes say,
 * which is what `onUploadFinalized`'s Storage trigger calls this with
 * after the file has already landed.
 */
export function validateUploadedFile(params: {
  path: string;
  size: number;
  header: Buffer;
}): UploadValidationResult {
  if (!UPLOAD_PATH_PATTERN.test(params.path)) {
    // Not a path this check governs -- nothing else is writable per
    // storage.rules, but fail open rather than delete something unrelated
    // if that ever changes.
    return { valid: true };
  }
  if (params.size > MAX_UPLOAD_BYTES) {
    return {
      valid: false,
      reason: `File is ${params.size} bytes, over the ${MAX_UPLOAD_BYTES}-byte limit.`,
    };
  }
  if (sniffContentType(params.header) === null) {
    return {
      valid: false,
      reason: "File content doesn't match any allowed type (PNG, JPEG, WEBP, HEIC/HEIF, or PDF).",
    };
  }
  return { valid: true };
}

/** Identifies a file by its real magic bytes, the same handful of formats
 * `ALLOWED_UPLOAD_CONTENT_TYPES` lists. Returns null for anything else --
 * including a real file of some *other* type, and a file with a spoofed
 * extension/Content-Type that doesn't match what it actually is.
 */
function sniffContentType(header: Buffer): string | null {
  if (
    header.length >= 8 &&
    header[0] === 0x89 &&
    header[1] === 0x50 &&
    header[2] === 0x4e &&
    header[3] === 0x47 &&
    header[4] === 0x0d &&
    header[5] === 0x0a &&
    header[6] === 0x1a &&
    header[7] === 0x0a
  ) {
    return "image/png";
  }
  if (header.length >= 3 && header[0] === 0xff && header[1] === 0xd8 && header[2] === 0xff) {
    return "image/jpeg";
  }
  if (
    header.length >= 12 &&
    header.subarray(0, 4).toString("ascii") === "RIFF" &&
    header.subarray(8, 12).toString("ascii") === "WEBP"
  ) {
    return "image/webp";
  }
  if (header.length >= 12 && header.subarray(4, 8).toString("ascii") === "ftyp") {
    const brand = header.subarray(8, 12).toString("ascii");
    if (["mif1", "msf1"].includes(brand)) return "image/heif";
    if (["heic", "heix", "hevc", "hevx", "heim", "heis", "hejx"].includes(brand)) return "image/heic";
  }
  if (header.length >= 5 && header.subarray(0, 5).toString("ascii") === "%PDF-") {
    return "application/pdf";
  }
  return null;
}
