/**
 * Chrome's `captureVisibleTab` resolves to a `data:image/png;base64,...`
 * URL. The extraction pipeline (same `extractEvent` Cloud Function as
 * Step 3) wants just the base64 payload and the mime type separately.
 */
export function splitDataUrl(dataUrl) {
  const match = /^data:([^;]+);base64,(.+)$/.exec(dataUrl);
  if (!match) {
    throw new Error("Expected a base64 data URL from captureVisibleTab.");
  }
  return { mimeType: match[1], base64: match[2] };
}
