import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/outlook_calendar_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps an event whose timeZone is UTC (the only case this adapter trusts)', () {
    final event = mapOutlookEvent({
      'id': 'o-1',
      'subject': 'Planning',
      'location': {'displayName': 'HQ'},
      'bodyPreview': 'Quarterly planning',
      'start': {'dateTime': '2026-03-01T15:00:00.0000000', 'timeZone': 'UTC'},
      'end': {'dateTime': '2026-03-01T16:00:00.0000000', 'timeZone': 'UTC'},
    });

    expect(event, isNotNull);
    expect(event!.source, EventSource.outlook);
    expect(event.sourceId, 'o-1');
    expect(event.title, 'Planning');
    expect(event.location, 'HQ');
    expect(event.notes, 'Quarterly planning');
    expect(event.start, DateTime.utc(2026, 3, 1, 15));
    expect(event.end, DateTime.utc(2026, 3, 1, 16));
    expect(event.tag, isNull);
  });

  test('refuses to guess when the timeZone is not UTC, rather than silently mis-converting', () {
    final event = mapOutlookEvent({
      'id': 'o-2',
      'subject': 'Wrong zone',
      'start': {'dateTime': '2026-03-01T10:00:00.0000000', 'timeZone': 'Eastern Standard Time'},
      'end': {'dateTime': '2026-03-01T11:00:00.0000000', 'timeZone': 'Eastern Standard Time'},
    });

    expect(event, isNull);
  });

  test('defaults a missing end time to one hour after start', () {
    final event = mapOutlookEvent({
      'id': 'o-3',
      'subject': 'No end',
      'start': {'dateTime': '2026-03-01T10:00:00.0000000', 'timeZone': 'UTC'},
    });

    expect(event!.end, DateTime.utc(2026, 3, 1, 11));
  });

  test('defaults a missing subject', () {
    final event = mapOutlookEvent({
      'id': 'o-4',
      'start': {'dateTime': '2026-03-01T10:00:00.0000000', 'timeZone': 'UTC'},
    });

    expect(event!.title, 'Untitled event');
  });

  test('returns null for an event with no id or no start time', () {
    expect(
      mapOutlookEvent({
        'subject': 'No id',
        'start': {'dateTime': '2026-03-01T10:00:00.0000000', 'timeZone': 'UTC'},
      }),
      isNull,
    );
    expect(mapOutlookEvent({'id': 'o-5', 'subject': 'No start'}), isNull);
  });
}
