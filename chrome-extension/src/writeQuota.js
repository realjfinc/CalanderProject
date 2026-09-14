// Same account-wide policy as Flutter's FirestoreWriteLimiter. Firestore rules
// enforce the timestamp, counter and affected path independently of this helper.
export function nextWriteQuota(previous, now = Date.now()) {
  const startedAt = previous?.windowStart?.toMillis();
  const reset = startedAt == null || now >= startedAt + 3600000;
  const count = reset ? 0 : previous.count;
  if (count >= 100) {
    const minutes = Math.max(1, Math.ceil((startedAt + 3600000 - now) / 60000));
    throw new Error(`You’ve reached 100 changes this hour. Try again in ${minutes} ${minutes === 1 ? 'minute' : 'minutes'}. You can still view your calendar.`);
  }
  return { count: count + 1, reset };
}
