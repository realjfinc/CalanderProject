import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/notification_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_local_notifier.dart';

CalendarEvent _event({
  required String id,
  required DateTime start,
  List<ReminderOffset>? reminders,
  EventStatus status = EventStatus.active,
}) {
  return CalendarEvent(
    id: id,
    title: 'Event $id',
    start: start,
    end: start.add(const Duration(hours: 1)),
    source: EventSource.manual,
    status: status,
    reminders: reminders,
  );
}

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);

  test('reconcile schedules a notification for a new event', () async {
    final notifier = FakeLocalNotifier();
    final scheduler = NotificationScheduler(notifier);
    final event = _event(id: 'e1', start: now.add(const Duration(hours: 2)), reminders: [ReminderOffset.tenMinutes]);

    await scheduler.reconcile([event], now: now);

    expect(notifier.scheduledCalls, hasLength(1));
    expect(notifier.scheduledCalls.single.title, 'Event e1');
  });

  test('reconcile cancels a reminder whose event disappeared', () async {
    final notifier = FakeLocalNotifier();
    final scheduler = NotificationScheduler(notifier);
    final event = _event(id: 'e1', start: now.add(const Duration(hours: 2)), reminders: [ReminderOffset.tenMinutes]);

    await scheduler.reconcile([event], now: now);
    final scheduledId = notifier.scheduledCalls.single.id;

    await scheduler.reconcile([], now: now);

    expect(notifier.cancelledIds, [scheduledId]);
  });

  test('reconcile cancels a reminder when its event loses its reminders', () async {
    final notifier = FakeLocalNotifier();
    final scheduler = NotificationScheduler(notifier);
    final withReminder = _event(
      id: 'e1',
      start: now.add(const Duration(hours: 2)),
      reminders: [ReminderOffset.tenMinutes],
    );
    await scheduler.reconcile([withReminder], now: now);
    final scheduledId = notifier.scheduledCalls.single.id;

    final withoutReminder = _event(id: 'e1', start: now.add(const Duration(hours: 2)));
    await scheduler.reconcile([withoutReminder], now: now);

    expect(notifier.cancelledIds, [scheduledId]);
  });

  test('reconcile leaves a still-desired reminder alone (no spurious cancel)', () async {
    final notifier = FakeLocalNotifier();
    final scheduler = NotificationScheduler(notifier);
    final event = _event(id: 'e1', start: now.add(const Duration(hours: 2)), reminders: [ReminderOffset.tenMinutes]);

    await scheduler.reconcile([event], now: now);
    await scheduler.reconcile([event], now: now);

    expect(notifier.cancelledIds, isEmpty);
    expect(notifier.scheduledCalls, hasLength(2)); // rescheduled both passes, never cancelled
  });

  test('reconcile ignores pending_conflict events entirely', () async {
    final notifier = FakeLocalNotifier();
    final scheduler = NotificationScheduler(notifier);
    final event = _event(
      id: 'e1',
      start: now.add(const Duration(hours: 2)),
      reminders: [ReminderOffset.tenMinutes],
      status: EventStatus.pendingConflict,
    );

    await scheduler.reconcile([event], now: now);

    expect(notifier.scheduledCalls, isEmpty);
  });
}
