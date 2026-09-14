import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/models/followed_team.dart';
import 'package:calander/services/event_repository.dart';
import 'package:calander/services/followed_teams_repository.dart';
import 'package:calander/ui/sports/dashboard_tab.dart';

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

class _FakeEventRepository implements EventRepository {
  _FakeEventRepository(this._events);
  final List<CalendarEvent> _events;

  @override
  Stream<List<CalendarEvent>> watchEvents() => Stream.value(_events);

  @override
  Future<String> addEvent(CalendarEvent event) async => 'id';

  @override
  Future<void> updateEvent(CalendarEvent event) async {}

  @override
  Future<void> deleteEvent(String eventId) async {}
}

CalendarEvent _game({
  required String id,
  required String title,
  required DateTime start,
  EventSource source = EventSource.sports,
}) {
  return CalendarEvent(
    id: id,
    title: title,
    start: start,
    end: start.add(const Duration(hours: 2)),
    source: source,
    sourceId: id,
  );
}

void main() {
  group('nextGameForTeam', () {
    final team = const FollowedTeam(id: 't1', name: 'Arsenal', league: 'EPL');
    final now = DateTime.now().toUtc();

    test('picks the earliest upcoming sports game whose title mentions the team', () {
      final events = [
        _game(id: 'e1', title: 'Arsenal vs Chelsea', start: now.add(const Duration(days: 5))),
        _game(id: 'e2', title: 'Arsenal vs Liverpool', start: now.add(const Duration(days: 2))),
      ];

      final next = nextGameForTeam(team, events);

      expect(next?.id, 'e2');
    });

    test('ignores games that have already started', () {
      final events = [
        _game(id: 'e1', title: 'Arsenal vs Chelsea', start: now.subtract(const Duration(days: 1))),
      ];

      expect(nextGameForTeam(team, events), isNull);
    });

    test('ignores events from a source other than sports', () {
      final events = [
        _game(
          id: 'e1',
          title: 'Arsenal vs Chelsea',
          start: now.add(const Duration(days: 1)),
          source: EventSource.manual,
        ),
      ];

      expect(nextGameForTeam(team, events), isNull);
    });

    test('ignores games for a different team', () {
      final events = [
        _game(id: 'e1', title: 'Chelsea vs Liverpool', start: now.add(const Duration(days: 1))),
      ];

      expect(nextGameForTeam(team, events), isNull);
    });

    test('returns null when there are no games at all', () {
      expect(nextGameForTeam(team, const []), isNull);
    });
  });

  testWidgets('shows a followed team\'s next synced game without calling any API', (tester) async {
    final team = const FollowedTeam(id: 't1', name: 'Arsenal', league: 'EPL');
    final start = DateTime.now().toUtc().add(const Duration(days: 3));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardTab(
            followedTeamsRepository: _FakeFollowedTeamsRepository([team]),
            eventRepository: _FakeEventRepository([
              _game(id: 'e1', title: 'Arsenal vs Chelsea', start: start),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arsenal'), findsOneWidget);
    expect(find.textContaining('Arsenal vs Chelsea'), findsOneWidget);
  });

  testWidgets('shows a placeholder when a followed team has no synced games yet', (tester) async {
    final team = const FollowedTeam(id: 't1', name: 'Arsenal', league: 'EPL');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardTab(
            followedTeamsRepository: _FakeFollowedTeamsRepository([team]),
            eventRepository: _FakeEventRepository(const []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No upcoming games synced yet'), findsOneWidget);
  });

  testWidgets('shows a prompt to follow a team when none are followed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardTab(
            followedTeamsRepository: _FakeFollowedTeamsRepository(const []),
            eventRepository: _FakeEventRepository(const []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your teams. Your calendar.'), findsOneWidget);
    expect(find.text('Find teams'), findsOneWidget);
  });
}
