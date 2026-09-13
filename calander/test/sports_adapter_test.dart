import 'dart:async';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/models/followed_team.dart';
import 'package:calander/services/followed_teams_repository.dart';
import 'package:calander/services/sports_adapter.dart';
import 'package:calander/services/thesportsdb_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFollowedTeamsRepository implements FollowedTeamsRepository {
  _FakeFollowedTeamsRepository(this._teams);
  final List<FollowedTeam> _teams;

  @override
  Stream<List<FollowedTeam>> watchFollowedTeams() => Stream.value(_teams);

  @override
  Future<void> followTeam(FollowedTeam team) async {}

  @override
  Future<void> unfollowTeam(String teamId) async {}
}

/// A fake that doesn't make real HTTP calls -- `TheSportsDbClient` isn't
/// behind an interface (it's a small, concrete REST wrapper, same pattern
/// as Step 6's provider adapters), so `SportsAdapter` is tested against
/// `fetchUpcomingEventsRaw`'s *shape* via a subclass overriding just that
/// method, keeping the real class's HTTP internals untouched.
class _FakeSportsDbClient implements TheSportsDbClient {
  _FakeSportsDbClient(this._eventsByTeamId);
  final Map<String, List<Map<String, dynamic>>> _eventsByTeamId;
  final List<String> requestedTeamIds = [];

  @override
  Future<List<Map<String, dynamic>>> fetchUpcomingEventsRaw(String teamId) async {
    requestedTeamIds.add(teamId);
    return _eventsByTeamId[teamId] ?? const [];
  }

  @override
  Future<List<FollowedTeam>> searchTeams(String query) async => const [];

  @override
  String get apiKey => '3';
}

Map<String, dynamic> _rawGame(String id, {String home = 'A', String away = 'B'}) {
  return {
    'idEvent': id,
    'strHomeTeam': home,
    'strAwayTeam': away,
    'strTimestamp': '2026-03-01 15:00:00',
  };
}

void main() {
  test('fetches and maps upcoming games for every followed team', () async {
    final teamsRepo = _FakeFollowedTeamsRepository([
      const FollowedTeam(id: 't1', name: 'Team One', league: 'League A'),
      const FollowedTeam(id: 't2', name: 'Team Two', league: 'League A'),
    ]);
    final apiClient = _FakeSportsDbClient({
      't1': [_rawGame('g1')],
      't2': [_rawGame('g2'), _rawGame('g3')],
    });

    final adapter = SportsAdapter(followedTeamsRepository: teamsRepo, apiClient: apiClient);
    final events = await adapter.fetchEvents();

    expect(events, hasLength(3));
    expect(events.map((e) => e.sourceId), containsAll(['g1', 'g2', 'g3']));
    expect(events.every((e) => e.source == EventSource.sports), isTrue);
    expect(events.every((e) => e.tag == null), isTrue);
    expect(apiClient.requestedTeamIds, containsAll(['t1', 't2']));
  });

  test('returns an empty list when no teams are followed', () async {
    final adapter = SportsAdapter(
      followedTeamsRepository: _FakeFollowedTeamsRepository(const []),
      apiClient: _FakeSportsDbClient(const {}),
    );

    expect(await adapter.fetchEvents(), isEmpty);
  });

  test('skips malformed games from the API rather than crashing', () async {
    final teamsRepo = _FakeFollowedTeamsRepository([
      const FollowedTeam(id: 't1', name: 'Team One', league: 'League A'),
    ]);
    final apiClient = _FakeSportsDbClient({
      't1': [
        _rawGame('g1'),
        {'strHomeTeam': 'No id'}, // missing idEvent -- should be dropped
      ],
    });

    final adapter = SportsAdapter(followedTeamsRepository: teamsRepo, apiClient: apiClient);
    final events = await adapter.fetchEvents();

    expect(events, hasLength(1));
    expect(events.single.sourceId, 'g1');
  });
}
