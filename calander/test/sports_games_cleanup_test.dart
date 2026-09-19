import 'package:calander/models/calendar_event.dart';
import 'package:calander/models/followed_team.dart';
import 'package:calander/services/event_repository.dart';
import 'package:calander/services/sports_games_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEventRepository implements EventRepository {
  final Map<String, CalendarEvent> _events = {};

  void seed(CalendarEvent event) => _events[event.id] = event;

  @override
  Stream<List<CalendarEvent>> watchEvents() => Stream.value(_events.values.toList());

  @override
  Future<String> addEvent(CalendarEvent event) async {
    _events[event.id] = event;
    return event.id;
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

CalendarEvent _game(String id, {String title = 'Arsenal vs Chelsea', EventSource source = EventSource.sports}) {
  final start = DateTime.utc(2026, 3, 1, 15);
  return CalendarEvent(
    id: id,
    title: title,
    start: start,
    end: start.add(const Duration(hours: 3)),
    source: source,
    sourceId: id,
  );
}

const _arsenal = FollowedTeam(id: '133604', name: 'Arsenal', league: 'English Premier League');

void main() {
  test('deletes every sports event whose title mentions the team', () async {
    final events = _FakeEventRepository();
    events.seed(_game('e-1', title: 'Arsenal vs Chelsea'));
    events.seed(_game('e-2', title: 'Liverpool vs Arsenal'));

    await removeTeamGamesFromCalendar(team: _arsenal, eventRepository: events);

    expect(events._events, isEmpty);
  });

  test('leaves other teams\' games and non-sports events untouched', () async {
    final events = _FakeEventRepository();
    events.seed(_game('e-1', title: 'Arsenal vs Chelsea'));
    events.seed(_game('e-2', title: 'Liverpool vs Chelsea'));
    events.seed(_game('e-3', title: 'Arsenal book club', source: EventSource.manual));

    await removeTeamGamesFromCalendar(team: _arsenal, eventRepository: events);

    expect(events._events.keys, unorderedEquals(['e-2', 'e-3']));
  });

  test('is a no-op when the team has no synced games', () async {
    final events = _FakeEventRepository();
    events.seed(_game('e-1', title: 'Liverpool vs Chelsea'));

    await removeTeamGamesFromCalendar(team: _arsenal, eventRepository: events);

    expect(events._events, hasLength(1));
  });

  test('matches case-insensitively', () async {
    final events = _FakeEventRepository();
    events.seed(_game('e-1', title: 'arsenal vs CHELSEA'));

    await removeTeamGamesFromCalendar(team: _arsenal, eventRepository: events);

    expect(events._events, isEmpty);
  });
}
