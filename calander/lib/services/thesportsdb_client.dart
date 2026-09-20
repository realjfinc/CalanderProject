import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/calendar_event.dart';
import '../models/followed_team.dart';
import 'major_league_teams.dart';

/// How many local nickname matches from [majorLeagueTeams] get resolved
/// to live data per search -- broad queries like "New" match a dozen-plus
/// teams (Knicks, Giants, Jets, Mets, Yankees, Rangers, Islanders...);
/// this keeps one search from firing off that many `lookupteam.php` calls
/// at once.
const _maxRosterMatches = 8;

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
  TheSportsDbClient({this.apiKey = '123', http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _httpClient;

  String get _basePath => '/api/v1/json/$apiKey';

  /// Searches by exact-ish team name (TheSportsDB's own `searchteams.php`,
  /// the only text-search endpoint this free key has -- confirmed against
  /// the live API to match close to the *full official name* and nothing
  /// looser: "Lakers" alone returns an unrelated NCAA team, not "Los
  /// Angeles Lakers"), merged with any local nickname matches from
  /// [majorLeagueTeams] so a query like "Lakers" or "Cowboys" still finds
  /// the right team. Results are deduped by id, direct API matches first.
  Future<List<FollowedTeam>> searchTeams(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final direct = await _searchTeamsDirect(trimmed);
    final rosterMatches = await _searchMajorLeagueRoster(trimmed);

    final seenIds = <String>{};
    final results = <FollowedTeam>[];
    for (final team in [...direct, ...rosterMatches]) {
      if (seenIds.add(team.id)) results.add(team);
    }
    return results;
  }

  Future<List<FollowedTeam>> _searchTeamsDirect(String query) async {
    final uri = Uri.https('www.thesportsdb.com', '$_basePath/searchteams.php', {'t': query});
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw SportsApiException('Team search failed with status ${response.statusCode}');
    }
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw SportsApiException('Team search returned an unexpected response.');
    }
    final teams = (body['teams'] as List?) ?? const [];
    return teams.cast<Map<String, dynamic>>().map(mapSportsDbTeam).whereType<FollowedTeam>().toList();
  }

  /// Local, case-insensitive substring match against the verified major-
  /// league roster, each hit resolved to live data via [_lookupTeamById]
  /// (`lookupteam.php`, a single-item lookup -- unlike the free key's list
  /// endpoints, this one reliably returns real per-id data). A lookup
  /// failure for one match is dropped rather than failing the whole
  /// search -- the direct API results above stand on their own regardless.
  Future<List<FollowedTeam>> _searchMajorLeagueRoster(String query) async {
    final lower = query.toLowerCase();
    final matches = majorLeagueTeams
        .where((team) => team.name.toLowerCase().contains(lower))
        .take(_maxRosterMatches)
        .toList();
    if (matches.isEmpty) return const [];

    final resolved = await Future.wait(matches.map((team) => _lookupTeamById(team.idTeam)));
    return resolved.whereType<FollowedTeam>().toList();
  }

  Future<FollowedTeam?> _lookupTeamById(String id) async {
    final uri = Uri.https('www.thesportsdb.com', '$_basePath/lookupteam.php', {'id': id});
    try {
      final response = await _httpClient.get(uri);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final teams = (body['teams'] as List?) ?? const [];
      if (teams.isEmpty) return null;
      return mapSportsDbTeam(teams.first as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
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
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw SportsApiException('Upcoming events returned an unexpected response.');
    }
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
