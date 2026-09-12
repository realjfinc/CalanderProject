import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/calendar_event.dart';
import 'ics_parser.dart';
import 'provider_adapter.dart';

class ICloudSyncException implements Exception {
  ICloudSyncException(this.message);
  final String message;
  @override
  String toString() => 'ICloudSyncException: $message';
}

/// Fetches events from an iCloud calendar over CalDAV.
///
/// Auth is HTTP Basic with an Apple ID email and an app-specific password
/// (generated at appleid.apple.com) — unlike Google/Outlook, this needs no
/// OAuth client registration, so it's the one provider adapter in this
/// step that can genuinely run end-to-end without further account setup.
///
/// Known simplification: [calendarUrl] must be the specific calendar's
/// CalDAV collection URL (e.g. from a calendar sharing/export screen).
/// Full CalDAV service discovery (a `PROPFIND` against
/// `https://caldav.icloud.com/` to resolve the account's principal and
/// enumerate its calendars) isn't implemented — that's a real gap, not an
/// oversight; it would be the natural next addition.
class ICloudCalDavAdapter implements ProviderAdapter {
  ICloudCalDavAdapter({
    required this.appleId,
    required this.appSpecificPassword,
    required this.calendarUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String appleId;
  final String appSpecificPassword;
  final Uri calendarUrl;
  final http.Client _httpClient;

  @override
  EventSource get source => EventSource.icloud;

  @override
  Future<List<CalendarEvent>> fetchEvents() async {
    final credentials = base64Encode(utf8.encode('$appleId:$appSpecificPassword'));
    final response = await _httpClient.send(
      http.Request('REPORT', calendarUrl)
        ..headers.addAll({
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/xml; charset=utf-8',
          'Depth': '1',
        })
        ..body = _calendarQueryBody,
    );
    final body = await http.Response.fromStream(response);
    if (body.statusCode != 207 && body.statusCode != 200) {
      throw ICloudSyncException('iCloud CalDAV request failed with status ${body.statusCode}');
    }

    return parseIcsVEventsFromMultistatus(body.body);
  }
}

const _calendarQueryBody = '''<?xml version="1.0" encoding="utf-8" ?>
<C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:prop>
    <C:calendar-data/>
  </D:prop>
  <C:filter>
    <C:comp-filter name="VCALENDAR">
      <C:comp-filter name="VEVENT"/>
    </C:comp-filter>
  </C:filter>
</C:calendar-query>''';

/// Extracts every VEVENT's `calendar-data` from a CalDAV REPORT's
/// multistatus XML response and maps each to the canonical schema. Doesn't
/// do full XML parsing — CalDAV embeds raw ICS text inside
/// `<C:calendar-data>` elements, so a targeted regex extraction is enough
/// and avoids escaping/namespace edge cases a general XML parser would
/// otherwise need to be configured for just to unwrap one field.
List<CalendarEvent> parseIcsVEventsFromMultistatus(String xml) {
  final events = <CalendarEvent>[];
  final calendarDataPattern = RegExp(r'<[\w:]*calendar-data[^>]*>(.*?)</[\w:]*calendar-data>', dotAll: true);
  for (final match in calendarDataPattern.allMatches(xml)) {
    final ics = _decodeXmlEntities(match.group(1) ?? '');
    for (final vEventBody in splitIcsVEvents(ics)) {
      final event = mapIcsVEvent(vEventBody);
      if (event != null) events.add(event);
    }
  }
  return events;
}

/// Pure mapping from one VEVENT block's body to the canonical schema.
/// Returns null if there's no UID or no parseable start time.
CalendarEvent? mapIcsVEvent(String vEventBody) {
  final properties = parseIcsProperties(vEventBody);
  final uid = firstValue(properties, 'UID');
  if (uid == null) return null;

  final start = parseIcsDateTime(properties, 'DTSTART');
  if (start == null) return null;
  final end = parseIcsDateTime(properties, 'DTEND') ?? start.add(const Duration(hours: 1));

  return CalendarEvent(
    id: '',
    title: firstValue(properties, 'SUMMARY') ?? 'Untitled event',
    location: firstValue(properties, 'LOCATION'),
    start: start,
    end: end,
    source: EventSource.icloud,
    sourceId: uid,
    notes: firstValue(properties, 'DESCRIPTION'),
  );
}

String _decodeXmlEntities(String text) {
  return text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}
