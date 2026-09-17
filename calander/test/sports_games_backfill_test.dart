import 'dart:convert';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/models/followed_team.dart';
import 'package:calander/services/event_repository.dart';
import 'package:calander/services/sports_games_backfill.dart';
import 'package:calander/services/sports_games_cache_repository.dart';
import 'package:calander/services/thesportsdb_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeGamesCacheRepository implements SportsGamesCacheRepository {
  _FakeGamesCacheRepository(this._byTeamId);
  final Map<String, List<CalendarEvent>> _byTeamId;
  final requestedTeamIds = <String>[];
  final cachedByTeamId = <String, List<CalendarEvent>>{};

  @override
  Future<List<CalendarEvent>> fetchCachedGames(String teamId) async {
    requestedTeamIds.add(teamId);
    return _byTeamId[teamId] ?? const [];
  }

  @override
  Future<void> cacheGames(String teamId, List<CalendarEvent> games) async {
    cachedByTeamId[teamId] = games;
  }
}

class _FakeEventRepository implements EventRepository {
  final Map<String, CalendarEvent> _events = {};
  int _nextId = 0;

  @override
  Stream<List<CalendarEvent>> watchEvents() => Stream.value(_events.values.toList());

  @override
  Future<String> addEvent(CalendarEvent event) async {
    final id = 'gen-${_nextId++}';
    _events[id] = event.copyWith(id: id);
    return id;
  }

  @override
  Future<void> updateEvent(CalendarEvent event) async {
    _events[event.id] = event;
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    _events.remove(eventId);
  }
}

CalendarEvent _cachedGame(String sourceId, {String title = 'Arsenal vs Chelsea'}) {
  final start = DateTime.utc(2026, 3, 1, 15);
  return CalendarEvent(
    id: '',
    title: title,
    start: start,
    end: start.add(const Duration(hours: 3)),
    source: EventSource.sports,
    sourceId: sourceId,
    notes: 'English Premier League',
  );
}

/// An [TheSportsDbClient] whose `eventsnext.php` call returns [rawGames],
/// and fails the test if it's ever called when [expectCalled] is false.
TheSportsDbClient _liveApiReturning(List<Map<String, dynamic>> rawGames, {bool expectCalled = true}) {
  var called = false;
  final client = MockClient((request) async {
    called = true;
    return http.Response(jsonEncode({'events': rawGames}), 200);
  });
  addTearDown(() => expect(called, expectCalled, reason: expectCalled ? 'expected the live API to be called' : 'did not expect the live API to be called'));
  return TheSportsDbClient(httpClient: client);
}

Map<String, dynamic> _rawGame(String eventId, {String home = 'Arsenal', String away = 'Chelsea'}) => {
  'idEvent': eventId,
  'strHomeTeam': home,
  'strAwayTeam': away,
  'strVenue': 'Emirates Stadium',
  'strLeague': 'English Premier League',
  'strTimestamp': '2026-03-01 15:00:00',
};

const _arsenal = FollowedTeam(id: '133604', name: 'Arsenal', league: 'English Premier League');

void main() {
  test('copies every cached game for the followed team into the user\'s own events', () async {
    final cache = _FakeGamesCacheRepository({
      '133604': [_cachedGame('e-1'), _cachedGame('e-2', title: 'Arsenal vs Liverpool')],
    });
    final events = _FakeEventRepository();

    await backfillCachedGamesForTeam(
      team: _arsenal,
      gamesCacheRepository: cache,
      eventRepository: events,
      apiClient: _liveApiReturning(const [], expectCalled: false),
    );

    expect(cache.requestedTeamIds, ['133604']);
    final saved = events._events.values.toList();
    expect(saved, hasLength(2));
    expect(saved.every((e) => e.source == EventSource.sports && e.tag == null), isTrue);
  });

  test('does nothing when the cache is empty and the live API also has no games for this team', () async {
    final cache = _FakeGamesCacheRepository(const {});
    final events = _FakeEventRepository();

    await backfillCachedGamesForTeam(
      team: _arsenal,
      gamesCacheRepository: cache,
      eventRepository: events,
      apiClient: _liveApiReturning(const []),
    );

    expect(events._events, isEmpty);
    expect(cache.cachedByTeamId, isEmpty);
  });

  test(
    'falls back to the live API when nothing is cached yet, caches the result, and ingests it',
    () async {
      final cache = _FakeGamesCacheRepository(const {});
      final events = _FakeEventRepository();

      await backfillCachedGamesForTeam(
        team: _arsenal,
        gamesCacheRepository: cache,
        eventRepository: events,
        apiClient: _liveApiReturning([_rawGame('e-live-1')]),
      );

      expect(cache.cachedByTeamId['133604'], hasLength(1));
      expect(cache.cachedByTeamId['133604']!.single.sourceId, 'e-live-1');
      final saved = events._events.values.toList();
      expect(saved, hasLength(1));
      expect(saved.single.sourceId, 'e-live-1');
      expect(saved.single.source, EventSource.sports);
      expect(saved.single.tag, isNull);
    },
  );

  test('still ingests into the user\'s own events even if caching the live result fails', () async {
    final events = _FakeEventRepository();
    final cache = _ThrowsOnCacheGames();

    await backfillCachedGamesForTeam(
      team: _arsenal,
      gamesCacheRepository: cache,
      eventRepository: events,
      apiClient: _liveApiReturning([_rawGame('e-live-1')]),
    );

    expect(events._events.values.single.sourceId, 'e-live-1');
  });

  test('is a no-op, not an error, when the live API call itself fails', () async {
    final cache = _FakeGamesCacheRepository(const {});
    final events = _FakeEventRepository();
    final client = MockClient((request) async => http.Response('', 500));

    await backfillCachedGamesForTeam(
      team: _arsenal,
      gamesCacheRepository: cache,
      eventRepository: events,
      apiClient: TheSportsDbClient(httpClient: client),
    );

    expect(events._events, isEmpty);
  });

  test('re-following (or a later poll) does not duplicate an already-backfilled game', () async {
    final cache = _FakeGamesCacheRepository({
      '133604': [_cachedGame('e-1')],
    });
    final events = _FakeEventRepository();
    final apiClient = _liveApiReturning(const [], expectCalled: false);

    await backfillCachedGamesForTeam(
      team: _arsenal,
      gamesCacheRepository: cache,
      eventRepository: events,
      apiClient: apiClient,
    );
    await backfillCachedGamesForTeam(
      team: _arsenal,
      gamesCacheRepository: cache,
      eventRepository: events,
      apiClient: apiClient,
    );

    expect(events._events, hasLength(1));
  });

  test('backfilling never overwrites a tag the user already assigned to a since-synced game', () async {
    final cache = _FakeGamesCacheRepository({
      '133604': [_cachedGame('e-1')],
    });
    final events = _FakeEventRepository();
    // Simulate the hourly poller having already synced and the user having
    // tagged it, before a redundant backfill (e.g. re-following) runs.
    final existingId = await events.addEvent(_cachedGame('e-1'));
    await events.updateEvent(
      (await events.watchEvents().first).firstWhere((e) => e.id == existingId).copyWith(tag: 'work'),
    );

    await backfillCachedGamesForTeam(
      team: _arsenal,
      gamesCacheRepository: cache,
      eventRepository: events,
      apiClient: _liveApiReturning(const [], expectCalled: false),
    );

    final saved = (await events.watchEvents().first).single;
    expect(saved.tag, 'work');
  });
}

class _ThrowsOnCacheGames implements SportsGamesCacheRepository {
  @override
  Future<List<CalendarEvent>> fetchCachedGames(String teamId) async => const [];

  @override
  Future<void> cacheGames(String teamId, List<CalendarEvent> games) async {
    throw Exception('quota exceeded');
  }
}
