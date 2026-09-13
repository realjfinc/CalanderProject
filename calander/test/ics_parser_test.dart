import 'package:calander/services/ics_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  test('splitIcsVEvents finds each VEVENT block', () {
    const ics = '''
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:1
SUMMARY:First
END:VEVENT
BEGIN:VEVENT
UID:2
SUMMARY:Second
END:VEVENT
END:VCALENDAR''';

    final blocks = splitIcsVEvents(ics);
    expect(blocks, hasLength(2));
    expect(blocks[0], contains('UID:1'));
    expect(blocks[1], contains('UID:2'));
  });

  test('parseIcsProperties unfolds a continuation line (RFC 5545 folding)', () {
    const body = '''
SUMMARY:A very long title that got
  folded onto a continuation line
UID:abc''';

    final properties = parseIcsProperties(body);
    expect(firstValue(properties, 'SUMMARY'), 'A very long title that got folded onto a continuation line');
    expect(firstValue(properties, 'UID'), 'abc');
  });

  test('parseIcsProperties captures parameters like TZID and VALUE', () {
    const body = 'DTSTART;TZID=America/New_York:20260301T100000';
    final properties = parseIcsProperties(body);
    expect(properties.single.name, 'DTSTART');
    expect(properties.single.params['TZID'], 'America/New_York');
    expect(properties.single.value, '20260301T100000');
  });

  test('parseIcsDateTime handles a trailing Z as already UTC', () {
    final properties = parseIcsProperties('DTSTART:20260301T100000Z');
    expect(parseIcsDateTime(properties, 'DTSTART'), DateTime.utc(2026, 3, 1, 10));
  });

  test('parseIcsDateTime converts a TZID-qualified time to UTC using the real zone database', () {
    // America/New_York is UTC-5 in March (before DST).
    final properties = parseIcsProperties('DTSTART;TZID=America/New_York:20260301T100000');
    expect(parseIcsDateTime(properties, 'DTSTART'), DateTime.utc(2026, 3, 1, 15));
  });

  test('parseIcsDateTime handles VALUE=DATE as UTC midnight', () {
    final properties = parseIcsProperties('DTSTART;VALUE=DATE:20260704');
    expect(parseIcsDateTime(properties, 'DTSTART'), DateTime.utc(2026, 7, 4));
  });

  test('parseIcsDateTime returns null for an unrecognized TZID', () {
    final properties = parseIcsProperties('DTSTART;TZID=Not/A_Real_Zone:20260301T100000');
    expect(parseIcsDateTime(properties, 'DTSTART'), isNull);
  });

  test('parseIcsDateTime returns null when the property is absent', () {
    final properties = parseIcsProperties('SUMMARY:x');
    expect(parseIcsDateTime(properties, 'DTSTART'), isNull);
  });
}
