import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/google_calendar_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps a timed event, normalizing to UTC', () {
    final event = mapGoogleEvent({
      'id': 'g-1',
      'summary': 'Standup',
      'location': 'Room 2',
      'description': 'Daily sync',
      'start': {'dateTime': '2026-03-01T10:00:00-05:00'},
      'end': {'dateTime': '2026-03-01T10:30:00-05:00'},
    });

    expect(event, isNotNull);
    expect(event!.source, EventSource.google);
    expect(event.sourceId, 'g-1');
    expect(event.title, 'Standup');
    expect(event.location, 'Room 2');
    expect(event.notes, 'Daily sync');
    expect(event.start, DateTime.utc(2026, 3, 1, 15));
    expect(event.end, DateTime.utc(2026, 3, 1, 15, 30));
    expect(event.tag, isNull);
    expect(event.status, EventStatus.active);
  });

  test('maps an all-day event using the bare date', () {
    final event = mapGoogleEvent({
      'id': 'g-2',
      'summary': 'Holiday',
      'start': {'date': '2026-07-04'},
      'end': {'date': '2026-07-05'},
    });

    expect(event!.start, DateTime.utc(2026, 7, 4));
    expect(event.end, DateTime.utc(2026, 7, 5));
  });

  test('defaults a missing end time to one hour after start', () {
    final event = mapGoogleEvent({
      'id': 'g-3',
      'summary': 'No end',
      'start': {'dateTime': '2026-03-01T10:00:00Z'},
    });

    expect(event!.end, DateTime.utc(2026, 3, 1, 11));
  });

  test('defaults a missing title', () {
    final event = mapGoogleEvent({
      'id': 'g-4',
      'start': {'dateTime': '2026-03-01T10:00:00Z'},
    });

    expect(event!.title, 'Untitled event');
  });

  test('returns null for a cancelled event', () {
    final event = mapGoogleEvent({
      'id': 'g-5',
      'status': 'cancelled',
      'start': {'dateTime': '2026-03-01T10:00:00Z'},
    });

    expect(event, isNull);
  });

  test('returns null for an event with no id or no start time', () {
    expect(mapGoogleEvent({'summary': 'No id', 'start': {'dateTime': '2026-03-01T10:00:00Z'}}), isNull);
    expect(mapGoogleEvent({'id': 'g-6', 'summary': 'No start'}), isNull);
  });
}
