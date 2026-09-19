import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/ics_export.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _event({
  String id = 'e1',
  String title = 'Team sync',
  String? location,
  String? notes,
  DateTime? start,
  DateTime? end,
  bool allDay = false,
  EventStatus status = EventStatus.active,
}) {
  return CalendarEvent(
    id: id,
    title: title,
    location: location,
    notes: notes,
    start: start ?? DateTime.utc(2026, 3, 1, 15),
    end: end ?? DateTime.utc(2026, 3, 1, 16),
    allDay: allDay,
    status: status,
  );
}

void main() {
  group('buildIcsCalendar', () {
    test('wraps events in a VCALENDAR with the required header fields', () {
      final ics = buildIcsCalendar([_event()]);

      expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(ics, contains('VERSION:2.0\r\n'));
      expect(ics, contains('PRODID:'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
    });

    test('formats a timed event with UTC start/end and a summary', () {
      final ics = buildIcsCalendar([
        _event(title: 'Standup', start: DateTime.utc(2026, 3, 1, 15, 30), end: DateTime.utc(2026, 3, 1, 16)),
      ]);

      expect(ics, contains('BEGIN:VEVENT\r\n'));
      expect(ics, contains('DTSTART:20260301T153000Z\r\n'));
      expect(ics, contains('DTEND:20260301T160000Z\r\n'));
      expect(ics, contains('SUMMARY:Standup\r\n'));
      expect(ics, contains('END:VEVENT\r\n'));
    });

    test('formats an all-day event with a DATE (not date-time) value', () {
      final ics = buildIcsCalendar([
        _event(allDay: true, start: DateTime.utc(2026, 3, 1), end: DateTime.utc(2026, 3, 2)),
      ]);

      expect(ics, contains('DTSTART;VALUE=DATE:20260301\r\n'));
      expect(ics, contains('DTEND;VALUE=DATE:20260302\r\n'));
    });

    test('includes location and description when present, omits them when not', () {
      final withBoth = buildIcsCalendar([_event(location: 'Room 4', notes: 'Bring laptop')]);
      expect(withBoth, contains('LOCATION:Room 4\r\n'));
      expect(withBoth, contains('DESCRIPTION:Bring laptop\r\n'));

      final withNeither = buildIcsCalendar([_event()]);
      expect(withNeither, isNot(contains('LOCATION:')));
      expect(withNeither, isNot(contains('DESCRIPTION:')));
    });

    test('escapes commas, semicolons, backslashes, and newlines in text fields', () {
      final ics = buildIcsCalendar([
        _event(title: 'Lunch; drinks, then\nmore, stuff \\ ok'),
      ]);

      expect(ics, contains('SUMMARY:Lunch\\; drinks\\, then\\nmore\\, stuff \\\\ ok\r\n'));
    });

    test('marks a pending-conflict event as TENTATIVE and an active one as CONFIRMED', () {
      final tentative = buildIcsCalendar([_event(status: EventStatus.pendingConflict)]);
      expect(tentative, contains('STATUS:TENTATIVE\r\n'));

      final confirmed = buildIcsCalendar([_event(status: EventStatus.active)]);
      expect(confirmed, contains('STATUS:CONFIRMED\r\n'));
    });

    test('gives each event a stable, unique UID derived from its id', () {
      final ics = buildIcsCalendar([_event(id: 'abc123')]);
      expect(ics, contains('UID:abc123@calander.app\r\n'));
    });

    test('folds a line longer than 75 octets onto a continuation line', () {
      final longTitle = 'A' * 100;
      final ics = buildIcsCalendar([_event(title: longTitle)]);

      final summaryLineStart = ics.indexOf('SUMMARY:');
      final nextCrlf = ics.indexOf('\r\n', summaryLineStart);
      // The first physical line (up to the fold) is at most 75 octets.
      expect(nextCrlf - summaryLineStart, lessThanOrEqualTo(75));
      // The folded continuation starts with a space, per RFC 5545.
      expect(ics.substring(nextCrlf + 2, nextCrlf + 3), ' ');
    });

    test('serializes multiple events into separate VEVENT blocks', () {
      final ics = buildIcsCalendar([_event(id: 'e1', title: 'First'), _event(id: 'e2', title: 'Second')]);

      expect('BEGIN:VEVENT'.allMatches(ics).length, 2);
      expect(ics, contains('SUMMARY:First\r\n'));
      expect(ics, contains('SUMMARY:Second\r\n'));
    });

    test('an empty event list still produces a valid, empty calendar', () {
      final ics = buildIcsCalendar([]);
      expect(ics, 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Calander//Calander//EN\r\nCALSCALE:GREGORIAN\r\nEND:VCALENDAR\r\n');
    });
  });
}
