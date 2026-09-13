import 'package:timezone/timezone.dart' as tz;

/// One unfolded, parsed line from an iCalendar (RFC 5545) VEVENT: a
/// property name, its parameters (e.g. `TZID`, `VALUE`), and its value.
class IcsProperty {
  const IcsProperty(this.name, this.params, this.value);
  final String name;
  final Map<String, String> params;
  final String value;
}

/// Splits an ICS document into its VEVENT blocks' raw text.
List<String> splitIcsVEvents(String ics) {
  final blocks = <String>[];
  final pattern = RegExp(r'BEGIN:VEVENT(.*?)END:VEVENT', dotAll: true);
  for (final match in pattern.allMatches(ics)) {
    blocks.add(match.group(1) ?? '');
  }
  return blocks;
}

/// Parses one VEVENT block's body into its properties, first undoing
/// RFC 5545 line folding (a line starting with a space or tab continues
/// the previous line).
List<IcsProperty> parseIcsProperties(String vEventBody) {
  final rawLines = vEventBody.split(RegExp(r'\r\n|\n|\r'));
  final unfolded = <String>[];
  for (final line in rawLines) {
    if (line.isEmpty) continue;
    if ((line.startsWith(' ') || line.startsWith('\t')) && unfolded.isNotEmpty) {
      unfolded[unfolded.length - 1] += line.substring(1);
    } else {
      unfolded.add(line);
    }
  }

  final properties = <IcsProperty>[];
  for (final line in unfolded) {
    final colonIndex = line.indexOf(':');
    if (colonIndex == -1) continue;
    final head = line.substring(0, colonIndex);
    final value = line.substring(colonIndex + 1);
    final parts = head.split(';');
    final name = parts.first.toUpperCase();
    final params = <String, String>{};
    for (final param in parts.skip(1)) {
      final eqIndex = param.indexOf('=');
      if (eqIndex == -1) continue;
      params[param.substring(0, eqIndex).toUpperCase()] = param.substring(eqIndex + 1);
    }
    properties.add(IcsProperty(name, params, value));
  }
  return properties;
}

String? firstValue(List<IcsProperty> properties, String name) {
  for (final property in properties) {
    if (property.name == name) return property.value;
  }
  return null;
}

/// Parses a DTSTART/DTEND-shaped property into a UTC [DateTime], handling:
/// - a trailing `Z` (already UTC)
/// - a `TZID` parameter (converted via the `timezone` package's IANA
///   database — call `initializeTimeZones()` once at app startup first)
/// - `VALUE=DATE` (an all-day event's bare date, treated as UTC midnight)
///
/// Returns null if there's no such property, or its TZID isn't a
/// recognized IANA zone.
DateTime? parseIcsDateTime(List<IcsProperty> properties, String name) {
  IcsProperty? property;
  for (final candidate in properties) {
    if (candidate.name == name) {
      property = candidate;
      break;
    }
  }
  if (property == null) return null;

  final value = property.value.trim();
  if (value.isEmpty) return null;

  if (property.params['VALUE'] == 'DATE') {
    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(4, 6));
    final day = int.parse(value.substring(6, 8));
    return DateTime.utc(year, month, day);
  }

  if (value.endsWith('Z')) {
    return _parseBasicDateTime(value.substring(0, value.length - 1)).toUtc();
  }

  final tzid = property.params['TZID'];
  final naive = _parseBasicDateTime(value);
  if (tzid == null) return naive.toUtc(); // no offset info at all; best effort.

  try {
    final location = tz.getLocation(tzid);
    final zoned = tz.TZDateTime(
      location,
      naive.year,
      naive.month,
      naive.day,
      naive.hour,
      naive.minute,
      naive.second,
    );
    return zoned.toUtc();
  } on tz.LocationNotFoundException {
    return null;
  }
}

/// Parses "YYYYMMDDTHHMMSS" (no offset) into a naive [DateTime] (its
/// `isUtc` is meaningless until the caller applies a zone).
DateTime _parseBasicDateTime(String value) {
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(4, 6));
  final day = int.parse(value.substring(6, 8));
  final hour = value.length > 9 ? int.parse(value.substring(9, 11)) : 0;
  final minute = value.length > 11 ? int.parse(value.substring(11, 13)) : 0;
  final second = value.length > 13 ? int.parse(value.substring(13, 15)) : 0;
  return DateTime.utc(year, month, day, hour, minute, second);
}
