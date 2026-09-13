import '../models/calendar_event.dart';
import 'local_notifier.dart';

/// One local notification that should exist: a specific event's reminder
/// firing at a specific UTC time.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.eventId,
    required this.title,
    required this.body,
    required this.fireAt,
  });

  final int id;
  final String eventId;
  final String title;
  final String body;
  final DateTime fireAt;
}

/// Pure function: given the current events and the current time, decide
/// exactly which reminder notifications should be scheduled.
///
/// - Only `active` events get reminders (a `pendingConflict` event hasn't
///   been resolved yet, so it shouldn't page the user for a time that might
///   not be real).
/// - A reminder whose fire time has already passed is dropped rather than
///   fired immediately on the next reconcile.
List<PlannedReminder> planReminders(List<CalendarEvent> events, DateTime now) {
  final planned = <PlannedReminder>[];
  for (final event in events) {
    if (event.status != EventStatus.active) continue;
    final reminders = event.reminders;
    if (reminders == null || reminders.isEmpty) continue;

    for (final offset in reminders) {
      final fireAt = event.start.subtract(offset.duration);
      if (fireAt.isBefore(now)) continue;
      planned.add(
        PlannedReminder(
          id: stableNotificationId(event.id, offset.name),
          eventId: event.id,
          title: event.title,
          body: _reminderBody(event, offset),
          fireAt: fireAt,
        ),
      );
    }
  }
  return planned;
}

String _reminderBody(CalendarEvent event, ReminderOffset offset) {
  final label = switch (offset) {
    ReminderOffset.fiveMinutes => 'in 5 minutes',
    ReminderOffset.tenMinutes => 'in 10 minutes',
    ReminderOffset.fifteenMinutes => 'in 15 minutes',
    ReminderOffset.thirtyMinutes => 'in 30 minutes',
    ReminderOffset.oneHour => 'in 1 hour',
    ReminderOffset.oneDay => 'in 1 day',
  };
  final location = event.location;
  final where = (location == null || location.isEmpty) ? '' : ' at $location';
  return '${event.title} starts $label$where';
}
