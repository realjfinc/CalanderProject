import { readFile } from 'node:fs/promises';
import { before, after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, writeBatch, serverTimestamp, Timestamp, runTransaction } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-calander',
    firestore: { host: '127.0.0.1', port: 8088,
      rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => env?.cleanup());
beforeEach(async () => env.clearFirestore());
const client = (uid = 'alice') => env.authenticatedContext(uid, { email_verified: true }).firestore();
const path = 'users/alice/tags/test';

async function seed(count, age = 0) {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'clientWriteLimits/alice'), {
      count, windowStart: Timestamp.fromMillis(Date.now() - age), paths: [path], updatedAt: Timestamp.now(),
    });
  });
}

async function change(db, { paths = [path], count = 1, reset = true, writePaths = paths } = {}) {
  const quota = doc(db, 'clientWriteLimits/alice');
  const previous = await getDoc(quota);
  const batch = writeBatch(db);
  batch.set(quota, { count, paths,
    windowStart: reset ? serverTimestamp() : previous.data().windowStart,
    updatedAt: serverTimestamp() });
  for (const p of writePaths) batch.set(doc(db, p), { name: 'Test' });
  return batch.commit();
}

test('direct writes without a quota update are denied', async () => {
  await assertFails(setDoc(doc(client(), path), { name: 'Bypass' }));
});
test('100th write succeeds, 101st and early resets fail; reads remain allowed', async () => {
  const db = client();
  await seed(99);
  await assertSucceeds(change(db, { count: 100, reset: false }));
  await assertFails(change(db, { count: 101, reset: false }));
  await assertFails(change(db, { count: 1, reset: true }));
  await assertSucceeds(getDoc(doc(db, path)));
  await assertFails(deleteDoc(doc(db, 'clientWriteLimits/alice')));
});
test('new and expired windows start at one', async () => {
  await assertSucceeds(change(client()));
  await seed(100, 3601000);
  await assertSucceeds(change(client()));
});
test('cannot undercount batches, reuse a counter, forge time, or affect another user', async () => {
  const db = client();
  await assertFails(change(db, { writePaths: [path, 'users/alice/tags/extra'] }));
  await assertSucceeds(change(db));
  await assertFails(change(db, { count: 1, reset: false }));
  await assertFails(setDoc(doc(db, 'clientWriteLimits/alice'), {
    count: 1, paths: [path], windowStart: Timestamp.fromMillis(0), updatedAt: serverTimestamp(),
  }));
  await assertFails(change(client('bob')));
  await assertFails(getDoc(doc(client('bob'), path)));
  await assertFails(setDoc(doc(db, 'serviceRateLimits/alice'), { count: 0 }));
});
test('each document in a valid batch counts', async () => {
  const db = client();
  await assertSucceeds(change(db, { paths: [path, 'users/alice/tags/other'], count: 2 }));
  assert.equal((await getDoc(doc(db, 'clientWriteLimits/alice'))).data().count, 2);
});
test('current app event payload can be created, edited, and deleted with quota', async () => {
  const db = client();
  const event = doc(db, 'users/alice/events/event');
  const quota = doc(db, 'clientWriteLimits/alice');
  const start = Timestamp.fromMillis(2000000000000);
  const end = Timestamp.fromMillis(2000003600000);
  const payload = {
    title: 'Football', location: '', notes: '', startAt: start, endAt: end,
    start, end, allDay: false, flexible: true, tagId: null, tag: null,
    source: 'manual', sourceId: null, status: 'active', importance: 'flexible',
    attachments: null, repeat: null, reminders: ['oneHour'], conflictGroupId: null,
    conflictRole: null, createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  };
  let batch = writeBatch(db);
  batch.set(event, payload);
  batch.set(quota, { count: 1, windowStart: serverTimestamp(), updatedAt: serverTimestamp(), paths: [event.path] });
  await assertSucceeds(batch.commit());
  const windowStart = (await getDoc(quota)).data().windowStart;
  batch = writeBatch(db);
  batch.update(event, { title: 'Basketball', updatedAt: serverTimestamp() });
  batch.set(quota, { count: 2, windowStart, updatedAt: serverTimestamp(), paths: [event.path] });
  await assertSucceeds(batch.commit());
  await assertFails(deleteDoc(event));
  batch = writeBatch(db);
  batch.delete(event);
  batch.set(quota, { count: 3, windowStart, updatedAt: serverTimestamp(), paths: [event.path] });
  await assertSucceeds(batch.commit());
});
test('all client collections require quota and unauthenticated writes are denied', async () => {
  const db = client();
  for (const name of ['events', 'tags', 'settings', 'followedTeams', 'meta']) {
    await assertFails(setDoc(doc(db, `users/alice/${name}/test`), { bypass: true }));
  }
  await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), path), { name: 'Bypass' }));
});
test('event writes reject an unknown reminders value, too many reminders, and too many attachments', async () => {
  const db = client();
  const event = doc(db, 'users/alice/events/event');
  const quota = doc(db, 'clientWriteLimits/alice');
  const start = Timestamp.fromMillis(2000000000000);
  const end = Timestamp.fromMillis(2000003600000);
  const basePayload = {
    title: 'Football', location: '', notes: '', startAt: start, endAt: end,
    start, end, allDay: false, flexible: true, tagId: null, tag: null,
    source: 'manual', sourceId: null, status: 'active', importance: 'flexible',
    repeat: null, conflictGroupId: null, conflictRole: null,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  };
  async function attempt(overrides) {
    const batch = writeBatch(db);
    batch.set(event, { ...basePayload, attachments: null, reminders: null, ...overrides });
    batch.set(quota, { count: 1, windowStart: serverTimestamp(), updatedAt: serverTimestamp(), paths: [event.path] });
    return batch.commit();
  }
  await assertFails(attempt({ reminders: ['everyMinute'] }));
  await assertFails(attempt({ reminders: Array(21).fill('oneHour') }));
  await assertFails(attempt({ attachments: Array(6).fill('https://example.com/a') }));
  await assertFails(attempt({ attachments: ['a'.repeat(2001)] }));
  await assertSucceeds(attempt({ reminders: ['oneHour', 'oneDay'], attachments: ['https://example.com/a'] }));
});
test('concurrent clients cannot both consume the final slot', async () => {
  await seed(99);
  const consume = async db => runTransaction(db, async tx => {
    const quota = doc(db, 'clientWriteLimits/alice');
    const previous = (await tx.get(quota)).data();
    tx.set(quota, { ...previous, count: previous.count + 1, paths: [path], updatedAt: serverTimestamp() });
    tx.set(doc(db, path), { name: 'Concurrent' });
  });
  const results = await Promise.allSettled([consume(client()), consume(client())]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal((await getDoc(doc(client(), 'clientWriteLimits/alice'))).data().count, 100);
});
test('the global sportsTeamGames cache is readable by any signed-in user', async () => {
  const gamePath = 'sportsTeamGames/133604/games/e-1';
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), gamePath), {
      title: 'Arsenal vs Chelsea', location: 'Emirates Stadium',
      start: Timestamp.fromMillis(2000000000000), end: Timestamp.fromMillis(2000003600000),
      sourceId: 'e-1', league: 'English Premier League',
    });
  });
  await assertSucceeds(getDoc(doc(client(), gamePath)));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), gamePath)));
});
test('sportsTeamGames is writable by a signed-in client only with quota and a valid shape -- the live top-up path', async () => {
  const db = client();
  const gameId = 'e-1';
  const gamePath = `sportsTeamGames/133604/games/${gameId}`;
  const game = doc(db, gamePath);
  const quota = doc(db, 'clientWriteLimits/alice');
  const basePayload = {
    title: 'Arsenal vs Chelsea', location: 'Emirates Stadium',
    start: Timestamp.fromMillis(2000000000000), end: Timestamp.fromMillis(2000003600000),
    sourceId: gameId, league: 'English Premier League',
  };
  async function attempt(payload) {
    const batch = writeBatch(db);
    batch.set(game, payload);
    batch.set(quota, { count: 1, windowStart: serverTimestamp(), updatedAt: serverTimestamp(), paths: [gamePath] });
    return batch.commit();
  }

  // No matching quota update in the same batch -- denied, same as every
  // other client-writable collection.
  await assertFails(setDoc(game, basePayload));
  // sourceId must match the document id -- can't cache a game under a
  // different team/game than its content claims.
  await assertFails(attempt({ ...basePayload, sourceId: 'not-e-1' }));
  // Missing a required field, or an extra one outside the allowed shape.
  const { title: _omittedTitle, ...withoutTitle } = basePayload;
  await assertFails(attempt(withoutTitle));
  await assertFails(attempt({ ...basePayload, tag: 'work' }));
  // end must be after start.
  await assertFails(attempt({ ...basePayload, end: Timestamp.fromMillis(1000000000000) }));

  await assertSucceeds(attempt(basePayload));
  assert.equal((await getDoc(game)).data().title, 'Arsenal vs Chelsea');
  // Counts against the same account-wide quota as everything else.
  assert.equal((await getDoc(quota)).data().count, 1);
});
