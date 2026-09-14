/**
 * Dependencies injected rather than reached for directly, so this can be
 * unit-tested without the Firestore/Storage/Auth emulators (same seam used
 * throughout this codebase -- see pollUpcomingGames.ts).
 */
export interface DeleteAccountDeps {
  /** Recursively deletes `users/{uid}` and every subcollection under it. */
  deleteUserDocTree(uid: string): Promise<void>;
  /** Deletes a single top-level document, e.g. `clientWriteLimits/{uid}`. */
  deleteDoc(collection: string, id: string): Promise<void>;
  /** Deletes every Storage object under the given prefix. */
  deleteStoragePrefix(prefix: string): Promise<void>;
  /** Deletes the Firebase Auth user record itself -- must run last. */
  deleteAuthUser(uid: string): Promise<void>;
}

/**
 * Permanently deletes everything Calander stores for one account: their
 * Firestore data (events, tags, settings, followed teams, per-user meta),
 * both rate-limit counters keyed by uid, their uploaded attachments in
 * Storage, and finally the Auth user itself. There's no undo -- this is
 * only reachable through an authenticated callable function gated on the
 * caller's own uid (see functions/src/index.ts), matching App Store
 * Review Guideline 5.1.1(v)'s requirement for in-app account deletion.
 */
export async function deleteAccount(uid: string, deps: DeleteAccountDeps): Promise<void> {
  await deps.deleteUserDocTree(uid);
  await deps.deleteDoc("clientWriteLimits", uid);
  await deps.deleteDoc("serviceRateLimits", uid);
  await deps.deleteStoragePrefix(`users/${uid}/uploads/`);
  await deps.deleteAuthUser(uid);
}
