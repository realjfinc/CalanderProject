import 'package:calander/models/calendar_event.dart';
import 'package:calander/models/followed_team.dart';
import 'package:calander/services/event_repository.dart';
import 'package:calander/services/sports_games_backfill.dart';
import 'package:calander/services/sports_games_cache_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGamesCacheRepository implements SportsGamesCacheRepository {
  _FakeGamesCacheRepository(this._byTeamId);
  final Map<String, List<CalendarEvent>> _byTeamId;
  final requestedTeamIds = <String>[];

  @override
  Future<List<CalendarEvent>> fetchCachedGames(String teamId) async {
    requestedTeamIds.add(teamId);
    return _byTeamId[teamId] ?? const [];
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

const _arsenal = FollowedTeam(id: '133604', name: 'Arsenal', league: 'English Premier League');

void main() {
  test('copies every cached game for the followed team into the user\'s own events', () async {
    final cache = _FakeGamesCacheRepository({
      '133604': [_cachedGame('e-1'), _cachedGame('e-2', title: 'Arsenal vs Liverpool')],
    });
    final events = _FakeEventRepository();

    await backfillCachedGamesForTeam(team: _arsenal, gamesCacheRepository: cache, eventRepository: events);

    expect(cache.requestedTeamIds, ['133604']);
    final saved = events._events.values.toList();
    expect(saved, hasLength(2));
    expect(saved.every((e) => e.source == EventSource.sports && e.tag == null), isTrue);
  });

  test('does nothing when the cache has no games yet for this team', () async {
    final cache = _FakeGamesCacheRepository(const {});
    final events = _FakeEventRepository();

    await backfillCachedGamesForTeam(team: _arsenal, gamesCacheRepository: cache, eventRepository: events);

    expect(events._events, isEmpty);
  });

  test('re-following (or a later poll) does not duplicate an already-backfilled game', () async {
    final cache = _FakeGamesCacheRepository({
      '133604': [_cachedGame('e-1')],
    });
    final events = _FakeEventRepository();

    await backfillCachedGamesForTeam(team: _arsenal, gamesCacheRepository: cache, eventRepository: events);
    await backfillCachedGamesForTeam(team: _arsenal, gamesCacheRepository: cache, eventRepository: events);

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

    await backfillCachedGamesForTeam(team: _arsenal, gamesCacheRepository: cache, eventRepository: events);

    final saved = (await events.watchEvents().first).single;
    expect(saved.tag, 'work');
  });
}
