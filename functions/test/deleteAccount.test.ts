import assert from "node:assert/strict";
import { test } from "node:test";

import { deleteAccount, type DeleteAccountDeps } from "../src/account/deleteAccount";

function fakeDeps() {
  const calls: string[] = [];
  const deps: DeleteAccountDeps = {
    deleteUserDocTree: async (uid) => {
      calls.push(`deleteUserDocTree:${uid}`);
    },
    deleteDoc: async (collection, id) => {
      calls.push(`deleteDoc:${collection}/${id}`);
    },
    deleteStoragePrefix: async (prefix) => {
      calls.push(`deleteStoragePrefix:${prefix}`);
    },
    deleteAuthUser: async (uid) => {
      calls.push(`deleteAuthUser:${uid}`);
    },
  };
  return { deps, calls };
}

test("deletes the user's Firestore tree, both rate-limit docs, storage uploads, and the auth user, in that order", async () => {
  const { deps, calls } = fakeDeps();

  await deleteAccount("alice", deps);

  assert.deepEqual(calls, [
    "deleteUserDocTree:alice",
    "deleteDoc:clientWriteLimits/alice",
    "deleteDoc:serviceRateLimits/alice",
    "deleteStoragePrefix:users/alice/uploads/",
    "deleteAuthUser:alice",
  ]);
});

test("deleting the auth user is always the last step, even if it's the only thing that matters to the caller", async () => {
  const { deps, calls } = fakeDeps();

  await deleteAccount("bob", deps);

  assert.equal(calls[calls.length - 1], "deleteAuthUser:bob");
});

test("propagates a failure instead of silently deleting the auth user when Firestore cleanup fails", async () => {
  const { deps, calls } = fakeDeps();
  deps.deleteUserDocTree = async () => {
    throw new Error("Firestore unavailable");
  };

  await assert.rejects(() => deleteAccount("carol", deps), /Firestore unavailable/);
  assert.equal(calls.includes("deleteAuthUser:carol"), false);
});
