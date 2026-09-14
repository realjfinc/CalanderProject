import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/calendar_event.dart';
import '../models/followed_team.dart';

class SportsApiException implements Exception {
  SportsApiException(this.message);
  final String message;
  @override
  String toString() => 'SportsApiException: $message';
}

/// Client for [TheSportsDB](https://www.thesportsdb.com/api.php)'s free v1
/// REST API. `"3"` (the default) is TheSportsDB's own published test key
/// for their free tier — not a real secret, and the reason Sports Mode is
/// the one external integration in this project that needs no account
/// setup or credential of any kind to actually run.
class TheSportsDbClient {
  TheSportsDbClient({this.apiKey = '3', http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _httpClient;

  String get _basePath => '/api/v1/json/$apiKey';

  Future<List<FollowedTeam>> searchTeams(String query) async {
    final uri = Uri.https('www.thesportsdb.com', '$_basePath/searchteams.php', {'t': query});
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw SportsApiException('Team search failed with status ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final teams = (body['teams'] as List?) ?? const [];
    return teams.cast<Map<String, dynamic>>().map(mapSportsDbTeam).whereType<FollowedTeam>().toList();
  }

  /// Raw upcoming-events JSON for one team, as returned by the API --
  /// separated from [mapSportsDbEvent] so the mapping stays independently
  /// (and easily) unit-testable with fixture data.
  Future<List<Map<String, dynamic>>> fetchUpcomingEventsRaw(String teamId) async {
    final uri = Uri.https('www.thesportsdb.com', '$_basePath/eventsnext.php', {'id': teamId});
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw SportsApiException('Upcoming events request failed with status ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ((body['events'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }
}

/// Pure mapping from a TheSportsDB team resource to [FollowedTeam].
FollowedTeam? mapSportsDbTeam(Map<String, dynamic> json) {
  final id = json['idTeam'] as String?;
  if (id == null) return null;
  return FollowedTeam(
    id: id,
    name: json['strTeam'] as String? ?? 'Unknown team',
    league: json['strLeague'] as String? ?? '',
    // The API's actual field is `strBadge` -- confirmed against the live
    // API (searchteams.php, lookupteam.php, and lookup_all_teams.php all
    // agree); `strTeamBadge` doesn't exist in any real response, so this
    // silently mapped to null for every team before this fix.
    badgeUrl: json['strBadge'] as String?,
    accentColorHex: json['strColour1'] as String?,
  );
}

/// Pure mapping from a TheSportsDB event resource to the canonical schema.
/// Returns null for an event with no id or no parseable time.
///
/// TheSportsDB's docs state `strTimestamp` (and, when absent,
/// `dateEvent`/`strTime`) are UTC — this trusts that documented contract
/// the same way Step 6's Outlook adapter trusts Graph's
/// `Prefer: outlook.timezone="UTC"` header, rather than guessing.
CalendarEvent? mapSportsDbEvent(Map<String, dynamic> json) {
  final id = json['idEvent'] as String?;
  if (id == null) return null;

  final start = _parseUtcStart(json);
  if (start == null) return null;
  // TheSportsDB doesn't provide an end time; a game's actual duration
  // varies by sport, so this is a documented, deliberately generous guess
  // rather than a claim of precision.
  final end = start.add(const Duration(hours: 3));

  final home = json['strHomeTeam'] as String?;
  final away = json['strAwayTeam'] as String?;
  final title = (home != null && away != null) ? '$home vs $away' : (json['strEvent'] as String? ?? 'Game');

  return CalendarEvent(
    id: '',
    title: title,
    location: json['strVenue'] as String?,
    start: start,
    end: end,
    source: EventSource.sports,
    sourceId: id,
    notes: json['strLeague'] as String?,
  );
}

DateTime? _parseUtcStart(Map<String, dynamic> json) {
  final timestamp = (json['strTimestamp'] as String?)?.trim();
  if (timestamp != null && timestamp.isNotEmpty) {
    return DateTime.parse('${timestamp.replaceFirst(' ', 'T')}Z').toUtc();
  }

  final date = (json['dateEvent'] as String?)?.trim();
  if (date == null || date.isEmpty) return null;
  final time = (json['strTime'] as String?)?.trim();
  final timePart = (time == null || time.isEmpty) ? '00:00:00' : time;
  return DateTime.parse('${date}T${timePart}Z').toUtc();
}
