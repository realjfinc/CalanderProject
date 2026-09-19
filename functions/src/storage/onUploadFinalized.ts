import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions/v2";
import { onObjectFinalized } from "firebase-functions/v2/storage";

import { validateUploadedFile } from "./validateUpload";

/**
 * Fires once a file finishes uploading to Storage. `storage.rules` already
 * restricts `users/{uid}/uploads/{fileName}` writes to their own owner and
 * to a declared Content-Type/size at write time, but that Content-Type is
 * just client-supplied request metadata -- a renamed executable can claim
 * `image/png` as easily as a real one. Storage triggers can't block a
 * write in flight, only react after it lands, so this re-checks the
 * file's *actual* bytes and deletes anything that doesn't really match an
 * allowed type (or exceeds the size cap another client bypassing the app
 * entirely could otherwise sneak past `storage.rules`).
 */
export const onUploadFinalized = onObjectFinalized(async (event) => {
  const { name, size, bucket: bucketName } = event.data;
  if (!name) return;

  const bucket = getStorage().bucket(bucketName);
  const file = bucket.file(name);

  let header: Buffer;
  try {
    // Every signature this checks for fits in the first 32 bytes.
    const [buffer] = await file.download({ start: 0, end: 31 });
    header = buffer;
  } catch (error) {
    logger.error("onUploadFinalized: failed to read uploaded file header", { name, error });
    return;
  }

  const result = validateUploadedFile({ path: name, size: Number(size ?? 0), header });
  if (result.valid) return;

  logger.warn("onUploadFinalized: rejecting uploaded file", { name, reason: result.reason });
  try {
    await file.delete();
  } catch (error) {
    logger.error("onUploadFinalized: failed to delete rejected file", { name, error });
  }
});
