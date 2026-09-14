import assert from 'node:assert/strict';
import { test } from 'node:test';
import { nextWriteQuota } from '../src/writeQuota.js';

test('extension shares the 100-change boundary and gives a readable error', () => {
  const windowStart = { toMillis: () => 1000 };
  assert.deepEqual(nextWriteQuota({ count: 99, windowStart }, 2000), { count: 100, reset: false });
  assert.throws(() => nextWriteQuota({ count: 100, windowStart }, 2000), /100 changes this hour/);
  assert.deepEqual(nextWriteQuota({ count: 100, windowStart }, 3601000), { count: 1, reset: true });
  assert.deepEqual(nextWriteQuota(undefined, 2000), { count: 1, reset: true });
});
