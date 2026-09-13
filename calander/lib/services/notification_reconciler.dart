import 'dart:async';

import '../models/calendar_event.dart';
import 'event_repository.dart';
import 'notification_scheduler.dart';

/// Wires a user's live event stream into the [NotificationScheduler], so
/// reminders stay in sync as events are added, edited, or removed.
class NotificationReconciler {
  factory NotificationReconciler({required EventRepository events, required NotificationScheduler scheduler}) {
    return NotificationReconciler._(events, scheduler);
  }

  NotificationReconciler._(this._events, this._scheduler);

  final EventRepository _events;
  final NotificationScheduler _scheduler;
  StreamSubscription<List<CalendarEvent>>? _subscription;

  void start() {
    _subscription ??= _events.watchEvents().listen(_scheduler.reconcile);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
