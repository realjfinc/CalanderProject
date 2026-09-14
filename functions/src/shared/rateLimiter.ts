import { getFirestore, Timestamp, type Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

export const EXTRACTIONS_PER_HOUR = 10;

/** Shared across function instances and all devices using this Firebase UID. */
export async function limitExtraction(uid: string, db: Firestore = getFirestore()): Promise<void> {
  const ref = db.collection('serviceRateLimits').doc(uid);
  await db.runTransaction(async transaction => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data();
    const now = Date.now();
    const startedAt = (data?.windowStart as Timestamp | undefined)?.toMillis() ?? now;
    const expired = now >= startedAt + 60 * 60 * 1000;
    const count = expired ? 0 : (data?.count ?? 0);
    if (count >= EXTRACTIONS_PER_HOUR) {
      throw new HttpsError('resource-exhausted',
        'You have reached 10 AI extractions this hour. Please try again later.',
        { retryAt: startedAt + 60 * 60 * 1000 });
    }
    transaction.set(ref, {
      windowStart: Timestamp.fromMillis(expired ? now : startedAt),
      count: count + 1,
    });
  });
}
