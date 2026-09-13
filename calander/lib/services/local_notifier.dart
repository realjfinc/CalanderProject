/// Thin seam over the local-notifications plugin so scheduling logic
/// (see [NotificationScheduler]) can be unit tested without a platform
/// channel, and so the real plugin wiring lives in exactly one place.
abstract class LocalNotifier {
  Future<void> initialize();

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    String? payload,
  });

  /// Shows a notification immediately (used for FCM-driven sync
  /// notifications, which have no future fire time to schedule for).
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  Future<void> cancel(int id);
}

/// Deterministic, stable-across-restarts int id for a (eventId, reminder)
/// pair, so a previously scheduled notification can always be found again
/// to reschedule or cancel it — without keeping a separate id-lookup table.
///
/// Dart's `String.hashCode` is not guaranteed stable across app runs, so we
/// use a plain FNV-1a hash instead.
int stableNotificationId(String eventId, String reminderName) {
  const fnvPrime = 0x01000193;
  var hash = 0x811c9dc5;
  for (final unit in '$eventId::$reminderName'.codeUnits) {
    hash ^= unit;
    hash = (hash * fnvPrime) & 0x7fffffff;
  }
  return hash;
}
