import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/local_notifier.dart';
import 'package:calander/services/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _event({
  String id = 'e1',
  required DateTime start,
  EventStatus status = EventStatus.active,
  List<ReminderOffset>? reminders,
}) {
  return CalendarEvent(
    id: id,
    title: 'Standup',
    start: start,
    end: start.add(const Duration(minutes: 30)),
    source: EventSource.manual,
    status: status,
    reminders: reminders,
  );
}

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);

  test('schedules one reminder per requested offset', () {
    final event = _event(
      start: now.add(const Duration(hours: 2)),
      reminders: [ReminderOffset.tenMinutes, ReminderOffset.oneHour],
    );

    final planned = planReminders([event], now);

    expect(planned.length, 2);
    expect(
      planned.map((p) => p.fireAt).toSet(),
      {
        now.add(const Duration(hours: 2) - const Duration(minutes: 10)),
        now.add(const Duration(hours: 2) - const Duration(hours: 1)),
      },
    );
  });

  test('drops reminders with no offsets configured', () {
    final event = _event(start: now.add(const Duration(hours: 1)));
    expect(planReminders([event], now), isEmpty);
  });

  test('drops reminders whose fire time has already passed', () {
    final event = _event(
      start: now.add(const Duration(minutes: 3)),
      reminders: [ReminderOffset.fiveMinutes], // fires 2 min before `now`
    );
    expect(planReminders([event], now), isEmpty);
  });

  test('ignores pending_conflict events', () {
    final event = _event(
      start: now.add(const Duration(hours: 1)),
      status: EventStatus.pendingConflict,
      reminders: [ReminderOffset.fiveMinutes],
    );
    expect(planReminders([event], now), isEmpty);
  });

  test('two different events never collide on notification id', () {
    final a = _event(id: 'a', start: now.add(const Duration(hours: 1)), reminders: [ReminderOffset.fiveMinutes]);
    final b = _event(id: 'b', start: now.add(const Duration(hours: 1)), reminders: [ReminderOffset.fiveMinutes]);

    final planned = planReminders([a, b], now);

    expect(planned.map((p) => p.id).toSet().length, 2);
  });

  test('the same event+offset always produces the same id (stable across restarts)', () {
    final event = _event(start: now.add(const Duration(hours: 1)), reminders: [ReminderOffset.fiveMinutes]);
    final first = planReminders([event], now).single.id;
    final second = planReminders([event], now).single.id;
    expect(first, second);
    expect(first, stableNotificationId('e1', ReminderOffset.fiveMinutes.name));
  });
}
