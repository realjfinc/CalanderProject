import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/thesportsdb_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('malformed responses', () {
    test('searchTeams throws SportsApiException instead of a raw parse error on a malformed body', () async {
      final client = MockClient((request) async => http.Response('not json', 200));
      final sportsClient = TheSportsDbClient(httpClient: client);

      await expectLater(sportsClient.searchTeams('arsenal'), throwsA(isA<SportsApiException>()));
    });

    test('fetchUpcomingEventsRaw throws SportsApiException instead of a raw parse error on a malformed body', () async {
      final client = MockClient((request) async => http.Response('not json', 200));
      final sportsClient = TheSportsDbClient(httpClient: client);

      await expectLater(sportsClient.fetchUpcomingEventsRaw('133604'), throwsA(isA<SportsApiException>()));
    });
  });

  group('mapSportsDbTeam', () {
    test('maps a team resource', () {
      // `strBadge` (not `strTeamBadge`) is the field the real API actually
      // returns, confirmed against searchteams.php, lookupteam.php, and
      // lookup_all_teams.php live -- `strTeamBadge` never appears in any
      // real response.
      final team = mapSportsDbTeam({
        'idTeam': '133604',
        'strTeam': 'Arsenal',
        'strLeague': 'English Premier League',
        'strBadge': 'https://example.com/badge.png',
        'strColour1': '#EF0107',
      });

      expect(team, isNotNull);
      expect(team!.id, '133604');
      expect(team.name, 'Arsenal');
      expect(team.league, 'English Premier League');
      expect(team.badgeUrl, 'https://example.com/badge.png');
      expect(team.accentColorHex, '#EF0107');
    });

    test('leaves accentColorHex null when the API has no strColour1', () {
      final team = mapSportsDbTeam({'idTeam': '1', 'strTeam': 'No Colour FC'});
      expect(team!.accentColorHex, isNull);
    });

    test('returns null without an id', () {
      expect(mapSportsDbTeam({'strTeam': 'No id'}), isNull);
    });

    test('defaults a missing name/league', () {
      final team = mapSportsDbTeam({'idTeam': '1'});
      expect(team!.name, 'Unknown team');
      expect(team.league, '');
    });
  });

  group('mapSportsDbEvent', () {
    test('maps a game using strTimestamp as the UTC start time', () {
      final event = mapSportsDbEvent({
        'idEvent': 'e-1',
        'strHomeTeam': 'Arsenal',
        'strAwayTeam': 'Chelsea',
        'strVenue': 'Emirates Stadium',
        'strLeague': 'English Premier League',
        'strTimestamp': '2026-03-01 15:00:00',
      });

      expect(event, isNotNull);
      expect(event!.source, EventSource.sports);
      expect(event.sourceId, 'e-1');
      expect(event.title, 'Arsenal vs Chelsea');
      expect(event.location, 'Emirates Stadium');
      expect(event.notes, 'English Premier League');
      expect(event.start, DateTime.utc(2026, 3, 1, 15));
      expect(event.tag, isNull);
    });

    test('falls back to dateEvent + strTime when strTimestamp is absent', () {
      final event = mapSportsDbEvent({
        'idEvent': 'e-2',
        'strHomeTeam': 'A',
        'strAwayTeam': 'B',
        'dateEvent': '2026-03-01',
        'strTime': '15:00:00',
      });

      expect(event!.start, DateTime.utc(2026, 3, 1, 15));
    });

    test('falls back to midnight when strTime is also absent (all-day-ish)', () {
      final event = mapSportsDbEvent({
        'idEvent': 'e-3',
        'strHomeTeam': 'A',
        'strAwayTeam': 'B',
        'dateEvent': '2026-03-01',
      });

      expect(event!.start, DateTime.utc(2026, 3, 1));
    });

    test('defaults a 3-hour duration since the API has no end time', () {
      final event = mapSportsDbEvent({
        'idEvent': 'e-4',
        'strHomeTeam': 'A',
        'strAwayTeam': 'B',
        'strTimestamp': '2026-03-01 15:00:00',
      });

      expect(event!.end, DateTime.utc(2026, 3, 1, 18));
    });

    test('falls back to strEvent for the title when team names are missing', () {
      final event = mapSportsDbEvent({
        'idEvent': 'e-5',
        'strEvent': 'Cup Final',
        'strTimestamp': '2026-03-01 15:00:00',
      });

      expect(event!.title, 'Cup Final');
    });

    test('returns null without an id or without any parseable time', () {
      expect(mapSportsDbEvent({'strTimestamp': '2026-03-01 15:00:00'}), isNull);
      expect(mapSportsDbEvent({'idEvent': 'e-6'}), isNull);
    });
  });
}
