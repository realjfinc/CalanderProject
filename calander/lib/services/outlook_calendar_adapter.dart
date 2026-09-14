import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/calendar_event.dart';
import 'provider_adapter.dart';

class OutlookCalendarSyncException implements Exception {
  OutlookCalendarSyncException(this.message);
  final String message;
  @override
  String toString() => 'OutlookCalendarSyncException: $message';
}

/// Fetches events from the signed-in user's Outlook calendar via the
/// Microsoft Graph REST API.
///
/// Sends `Prefer: outlook.timezone="UTC"`, which makes Graph return every
/// event's `start`/`end` already converted to UTC regardless of the
/// event's own timezone — this is the documented, correct way to get UTC
/// out of Graph without needing a Windows-timezone-name database (Graph's
/// `timeZone` field uses Windows names like "Eastern Standard Time", not
/// IANA ones, so there's no drop-in package for converting those; letting
/// the server do it is the standard approach). [mapOutlookEvent] asserts
/// this actually came back as "UTC" rather than silently trusting it.
///
/// Requires an OAuth access token with the `Calendars.Read` scope —
/// obtaining one requires an Azure AD app registration, which is a
/// deployment-time dependency this adapter does not set up itself (see
/// README).
class OutlookCalendarAdapter implements ProviderAdapter {
  OutlookCalendarAdapter({required this.accessToken, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final String accessToken;
  final http.Client _httpClient;

  @override
  EventSource get source => EventSource.outlook;

  @override
  Future<List<CalendarEvent>> fetchEvents() async {
    final uri = Uri.parse('https://graph.microsoft.com/v1.0/me/events');
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken', 'Prefer': 'outlook.timezone="UTC"'},
    );
    if (response.statusCode != 200) {
      throw OutlookCalendarSyncException(
        'Outlook Calendar request failed with status ${response.statusCode}',
      );
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw OutlookCalendarSyncException('Outlook Calendar returned an unexpected response.');
    }
    final items = (body['value'] as List?) ?? const [];
    return items.cast<Map<String, dynamic>>().map(mapOutlookEvent).whereType<CalendarEvent>().toList();
  }
}

/// Pure mapping from a Microsoft Graph event resource to the canonical
/// schema. Assumes the request that produced [json] sent
/// `Prefer: outlook.timezone="UTC"` (see adapter doc comment); returns null
/// if that assumption doesn't hold, rather than silently mis-converting a
/// non-UTC wall-clock time.
CalendarEvent? mapOutlookEvent(Map<String, dynamic> json) {
  final id = json['id'] as String?;
  if (id == null) return null;

  final start = _parseGraphUtcDateTime(json['start'] as Map<String, dynamic>?);
  if (start == null) return null;
  final end =
      _parseGraphUtcDateTime(json['end'] as Map<String, dynamic>?) ?? start.add(const Duration(hours: 1));

  return CalendarEvent(
    id: '',
    title: json['subject'] as String? ?? 'Untitled event',
    location: (json['location'] as Map<String, dynamic>?)?['displayName'] as String?,
    start: start,
    end: end,
    source: EventSource.outlook,
    sourceId: id,
    notes: json['bodyPreview'] as String?,
  );
}

DateTime? _parseGraphUtcDateTime(Map<String, dynamic>? node) {
  if (node == null) return null;
  final dateTime = node['dateTime'] as String?;
  final timeZone = node['timeZone'] as String?;
  if (dateTime == null || timeZone != 'UTC') return null;
  // Graph's UTC dateTime string has no trailing offset ("2026-01-01T10:00:00.0000000").
  return DateTime.parse('${dateTime}Z').toUtc();
}
