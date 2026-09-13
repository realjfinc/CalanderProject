import '../models/calendar_event.dart';
import 'local_notifier.dart';
import 'reminder_planner.dart';

/// Keeps scheduled local notifications in sync with the current set of
/// events. Call [reconcile] whenever the event list changes (or on a fresh
/// app start) with the full current event list — it diffs against what it
/// last scheduled and cancels/schedules accordingly.
class NotificationScheduler {
  NotificationScheduler(this._notifier);

  final LocalNotifier _notifier;
  Set<int> _scheduledIds = {};

  Future<void> reconcile(List<CalendarEvent> events, {DateTime? now}) async {
    final planned = planReminders(events, now ?? DateTime.now().toUtc());
    final desiredIds = planned.map((p) => p.id).toSet();

    for (final staleId in _scheduledIds.difference(desiredIds)) {
      await _notifier.cancel(staleId);
    }
    for (final reminder in planned) {
      await _notifier.schedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        fireAt: reminder.fireAt,
      );
    }
    _scheduledIds = desiredIds;
  }
}
