import '../models/calendar_event.dart';

/// Serializes events to an RFC 5545 `.ics` file so people can import their
/// Calander events into any other calendar app (Google Calendar, Apple
/// Calendar, Outlook, ...). One-way, read-only export -- this never writes
/// back to Firestore, it only formats what's already there.
String buildIcsCalendar(List<CalendarEvent> events) {
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Calander//Calander//EN',
    'CALSCALE:GREGORIAN',
    for (final event in events) ..._vevent(event),
    'END:VCALENDAR',
  ];
  // RFC 5545 requires CRLF line endings.
  return '${lines.map(_fold).join('\r\n')}\r\n';
}

List<String> _vevent(CalendarEvent event) {
  final stamp = _formatUtc(DateTime.now().toUtc());
  return [
    'BEGIN:VEVENT',
    'UID:${event.id}@calander.app',
    'DTSTAMP:$stamp',
    if (event.allDay) ...[
      'DTSTART;VALUE=DATE:${_formatDate(event.start.toUtc())}',
      'DTEND;VALUE=DATE:${_formatDate(event.end.toUtc())}',
    ] else ...[
      'DTSTART:${_formatUtc(event.start)}',
      'DTEND:${_formatUtc(event.end)}',
    ],
    'SUMMARY:${_escape(event.title)}',
    if (event.location != null && event.location!.isNotEmpty)
      'LOCATION:${_escape(event.location!)}',
    if (event.notes != null && event.notes!.isNotEmpty)
      'DESCRIPTION:${_escape(event.notes!)}',
    'STATUS:${event.status == EventStatus.pendingConflict ? 'TENTATIVE' : 'CONFIRMED'}',
    'END:VEVENT',
  ];
}

String _formatUtc(DateTime value) {
  final utc = value.toUtc();
  final y = utc.year.toString().padLeft(4, '0');
  final m = utc.month.toString().padLeft(2, '0');
  final d = utc.day.toString().padLeft(2, '0');
  final h = utc.hour.toString().padLeft(2, '0');
  final min = utc.minute.toString().padLeft(2, '0');
  final s = utc.second.toString().padLeft(2, '0');
  return '$y$m${d}T$h$min${s}Z';
}

String _formatDate(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y$m$d';
}

/// Escapes the handful of characters RFC 5545 requires escaping in TEXT
/// values -- a comma or semicolon would otherwise be read as a field
/// separator by another app's parser, and a literal newline would break
/// the line-based format entirely.
String _escape(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\n', '\\n');

/// Folds a content line to RFC 5545's 75-octet limit, continuing on the
/// next line with a leading space -- a naive one-line-per-field writer
/// would otherwise produce lines some stricter calendar apps reject
/// outright for a long title, location, or description.
String _fold(String line) {
  if (line.length <= 75) return line;
  final buffer = StringBuffer(line.substring(0, 75));
  var rest = line.substring(75);
  while (rest.isNotEmpty) {
    final chunkSize = rest.length > 74 ? 74 : rest.length;
    buffer.write('\r\n ${rest.substring(0, chunkSize)}');
    rest = rest.substring(chunkSize);
  }
  return buffer.toString();
}
