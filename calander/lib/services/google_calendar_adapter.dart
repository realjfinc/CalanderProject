import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/calendar_event.dart';
import 'provider_adapter.dart';

class GoogleCalendarSyncException implements Exception {
  GoogleCalendarSyncException(this.message);
  final String message;
  @override
  String toString() => 'GoogleCalendarSyncException: $message';
}

/// Fetches events from the signed-in user's primary Google Calendar via
/// the REST API directly (no `googleapis` dependency — that package bundles
/// every Google API, which is unnecessary weight for one endpoint).
///
/// Requires an OAuth access token with the
/// `https://www.googleapis.com/auth/calendar.readonly` scope — obtaining
/// one requires a Google Cloud OAuth client registered for this app, which
/// is a deployment-time dependency this adapter does not set up itself
/// (see README).
class GoogleCalendarAdapter implements ProviderAdapter {
  GoogleCalendarAdapter({required this.accessToken, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final String accessToken;
  final http.Client _httpClient;

  @override
  EventSource get source => EventSource.google;

  @override
  Future<List<CalendarEvent>> fetchEvents() async {
    final uri = Uri.parse(
      'https://www.googleapis.com/calendar/v3/calendars/primary/events?singleEvents=true',
    );
    final response = await _httpClient.get(uri, headers: {'Authorization': 'Bearer $accessToken'});
    if (response.statusCode != 200) {
      throw GoogleCalendarSyncException(
        'Google Calendar request failed with status ${response.statusCode}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body['items'] as List?) ?? const [];
    return items.cast<Map<String, dynamic>>().map(mapGoogleEvent).whereType<CalendarEvent>().toList();
  }
}

/// Pure mapping from a Google Calendar API event resource to the canonical
/// schema. Returns null for an event with no usable start time (e.g. a
/// cancelled event whose time was cleared).
CalendarEvent? mapGoogleEvent(Map<String, dynamic> json) {
  final id = json['id'] as String?;
  if (id == null || json['status'] == 'cancelled') return null;

  final start = _parseGoogleDateTime(json['start'] as Map<String, dynamic>?);
  if (start == null) return null;
  final end =
      _parseGoogleDateTime(json['end'] as Map<String, dynamic>?) ?? start.add(const Duration(hours: 1));

  return CalendarEvent(
    id: '',
    title: json['summary'] as String? ?? 'Untitled event',
    location: json['location'] as String?,
    start: start,
    end: end,
    source: EventSource.google,
    sourceId: id,
    notes: json['description'] as String?,
  );
}

DateTime? _parseGoogleDateTime(Map<String, dynamic>? node) {
  if (node == null) return null;
  final dateTime = node['dateTime'] as String?;
  if (dateTime != null) return DateTime.parse(dateTime).toUtc();
  final date = node['date'] as String?; // all-day event: "YYYY-MM-DD"
  if (date != null) return DateTime.parse(date).toUtc();
  return null;
}
