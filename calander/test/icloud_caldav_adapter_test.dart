import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/icloud_caldav_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  test('mapIcsVEvent maps a well-formed VEVENT to the canonical schema', () {
    const body = '''
UID:abc-123
SUMMARY:Book Club
LOCATION:Library
DESCRIPTION:Bring a book
DTSTART:20260501T180000Z
DTEND:20260501T190000Z''';

    final event = mapIcsVEvent(body);

    expect(event, isNotNull);
    expect(event!.source, EventSource.icloud);
    expect(event.sourceId, 'abc-123');
    expect(event.title, 'Book Club');
    expect(event.location, 'Library');
    expect(event.notes, 'Bring a book');
    expect(event.start, DateTime.utc(2026, 5, 1, 18));
    expect(event.end, DateTime.utc(2026, 5, 1, 19));
    expect(event.tag, isNull);
  });

  test('mapIcsVEvent returns null without a UID', () {
    const body = 'SUMMARY:No uid\nDTSTART:20260501T180000Z';
    expect(mapIcsVEvent(body), isNull);
  });

  test('mapIcsVEvent returns null without a parseable start time', () {
    const body = 'UID:abc-123\nSUMMARY:No start';
    expect(mapIcsVEvent(body), isNull);
  });

  test('mapIcsVEvent defaults a missing end time to one hour after start', () {
    const body = 'UID:abc-123\nSUMMARY:No end\nDTSTART:20260501T180000Z';
    expect(mapIcsVEvent(body)!.end, DateTime.utc(2026, 5, 1, 19));
  });

  test('parseIcsVEventsFromMultistatus extracts and maps each embedded VEVENT', () {
    const xml = '''<?xml version="1.0"?>
<D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:response>
    <D:propstat>
      <D:prop>
        <C:calendar-data>BEGIN:VCALENDAR
BEGIN:VEVENT
UID:event-1
SUMMARY:First
DTSTART:20260101T100000Z
END:VEVENT
END:VCALENDAR</C:calendar-data>
      </D:prop>
    </D:propstat>
  </D:response>
  <D:response>
    <D:propstat>
      <D:prop>
        <C:calendar-data>BEGIN:VCALENDAR
BEGIN:VEVENT
UID:event-2
SUMMARY:Second
DTSTART:20260102T100000Z
END:VEVENT
END:VCALENDAR</C:calendar-data>
      </D:prop>
    </D:propstat>
  </D:response>
</D:multistatus>''';

    final events = parseIcsVEventsFromMultistatus(xml);

    expect(events, hasLength(2));
    expect(events.map((e) => e.sourceId), containsAll(['event-1', 'event-2']));
    expect(events.every((e) => e.source == EventSource.icloud), isTrue);
  });

  test('parseIcsVEventsFromMultistatus decodes XML entities in the embedded ICS text', () {
    const xml = '''<D:multistatus xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:response><D:propstat><D:prop>
    <C:calendar-data>BEGIN:VCALENDAR
BEGIN:VEVENT
UID:event-1
SUMMARY:Tom &amp; Jerry
DTSTART:20260101T100000Z
END:VEVENT
END:VCALENDAR</C:calendar-data>
  </D:prop></D:propstat></D:response>
</D:multistatus>''';

    final events = parseIcsVEventsFromMultistatus(xml);
    expect(events.single.title, 'Tom & Jerry');
  });
}
