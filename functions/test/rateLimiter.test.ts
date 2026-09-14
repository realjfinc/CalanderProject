import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Timestamp, type Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { limitExtraction } from '../src/shared/rateLimiter';

function fakeDb(initial?: { count: number; windowStart: Timestamp }) {
  let data = initial;
  const db = {
    collection: () => ({ doc: () => ({}) }),
    runTransaction: async (run: (tx: unknown) => Promise<void>) => run({
      get: async () => ({ data: () => data }),
      set: (_ref: unknown, next: typeof data) => { data = next; },
    }),
  } as unknown as Firestore;
  return { db, read: () => data };
}

test('10th extraction allowed; 11th returns resource-exhausted with retry time', async () => {
  const { db, read } = fakeDb({ count: 9, windowStart: Timestamp.now() });
  await limitExtraction('user', db);
  assert.equal(read()?.count, 10);
  await assert.rejects(limitExtraction('user', db), (error: unknown) =>
    error instanceof HttpsError && error.code === 'resource-exhausted' &&
    typeof (error.details as { retryAt: number }).retryAt === 'number');
  assert.equal(read()?.count, 10);
});

test('expired extraction window resets', async () => {
  const { db, read } = fakeDb({ count: 10, windowStart: Timestamp.fromMillis(Date.now() - 3600001) });
  await limitExtraction('user', db);
  assert.equal(read()?.count, 1);
});
