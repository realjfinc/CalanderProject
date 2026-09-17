import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/models/followed_team.dart';
import 'package:calander/services/event_repository.dart';
import 'package:calander/services/followed_teams_repository.dart';
import 'package:calander/services/sports_games_cache_repository.dart';
import 'package:calander/services/sports_onboarding_repository.dart';
import 'package:calander/services/thesportsdb_client.dart';
import 'package:calander/ui/sports/sports_onboarding_screen.dart';

class _FakeFollowedTeamsRepository implements FollowedTeamsRepository {
  final followed = <FollowedTeam>[];

  @override
  Stream<List<FollowedTeam>> watchFollowedTeams() => Stream.value(const []);

  @override
  Future<void> followTeam(FollowedTeam team) async => followed.add(team);

  @override
  Future<void> unfollowTeam(String teamId) async {}
}

class _FakeGamesCacheRepository implements SportsGamesCacheRepository {
  @override
  Future<List<CalendarEvent>> fetchCachedGames(String teamId) async => const [];
}

class _FakeEventRepository implements EventRepository {
  @override
  Stream<List<CalendarEvent>> watchEvents() => Stream.value(const []);

  @override
  Future<String> addEvent(CalendarEvent event) async => 'id';

  @override
  Future<void> updateEvent(CalendarEvent event) async {}

  @override
  Future<void> deleteEvent(String eventId) async {}
}

class _FakeOnboardingRepository implements SportsOnboardingRepository {
  bool completed = false;

  @override
  Future<bool> hasCompletedOnboarding() async => completed;

  @override
  Future<void> completeOnboarding() async => completed = true;
}

Map<String, dynamic> _team(String id, String name, {String league = 'Test League'}) => {
  'idTeam': id,
  'strTeam': name,
  'strLeague': league,
  'strBadge': 'https://example.com/$id.png',
  'strColour1': '#123456',
};

TheSportsDbClient _fakeClient() {
  final client = MockClient((request) async {
    final query = request.url.queryParameters['t'] ?? '';
    final byQuery = {
      'Arsenal': [_team('133604', 'Arsenal')],
      'Los Angeles Lakers': [_team('134867', 'Los Angeles Lakers')],
      'Real Madrid': [_team('133738', 'Real Madrid')],
      'Manchester United': [_team('133612', 'Manchester United')],
      'Barcelona': [_team('133739', 'Barcelona')],
      'Liverpool': [_team('133602', 'Liverpool')],
      'Golden State Warriors': [_team('134865', 'Golden State Warriors')],
      'Boston Celtics': [_team('134860', 'Boston Celtics')],
      'Chicago Bulls': [_team('134870', 'Chicago Bulls')],
      'New York Yankees': [_team('135260', 'New York Yankees')],
      'Dallas Cowboys': [_team('134934', 'Dallas Cowboys')],
      'Kansas City Chiefs': [_team('134931', 'Kansas City Chiefs')],
      'Nonexistent Team Zzz': <Map<String, dynamic>>[],
    };
    return http.Response(jsonEncode({'teams': byQuery[query] ?? []}), 200);
  });
  return TheSportsDbClient(httpClient: client);
}

/// The screen has two perpetually-looping AnimationControllers (the header's
/// "breathing" gradient, the Continue button's pulse), so `pumpAndSettle()`
/// never returns -- these bounded pumps let one-shot animations (chip
/// select/deselect, the tray) finish instead, without waiting forever on
/// the ones that never do.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required _FakeFollowedTeamsRepository teams,
    required _FakeOnboardingRepository onboarding,
    required VoidCallback onDone,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SportsOnboardingScreen(
          followedTeamsRepository: teams,
          onboardingRepository: onboarding,
          apiClient: _fakeClient(),
          gamesCacheRepository: _FakeGamesCacheRepository(),
          eventRepository: _FakeEventRepository(),
          onDone: onDone,
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('tapping a quick-pick chip selects it and adds it to the tray', (tester) async {
    final teams = _FakeFollowedTeamsRepository();
    final onboarding = _FakeOnboardingRepository();
    await pump(tester, teams: teams, onboarding: onboarding, onDone: () {});

    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Arsenal').first);
    await _settle(tester);

    expect(find.text('Continue with 1 team'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsWidgets);
  });

  testWidgets('tapping an already-selected chip deselects it', (tester) async {
    final teams = _FakeFollowedTeamsRepository();
    final onboarding = _FakeOnboardingRepository();
    await pump(tester, teams: teams, onboarding: onboarding, onDone: () {});

    await tester.tap(find.text('Arsenal').first);
    await _settle(tester);
    expect(find.text('Continue with 1 team'), findsOneWidget);

    await tester.tap(find.text('Arsenal').first);
    await _settle(tester);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('continuing follows every selected team and completes onboarding', (tester) async {
    final teams = _FakeFollowedTeamsRepository();
    final onboarding = _FakeOnboardingRepository();
    var done = false;
    await pump(tester, teams: teams, onboarding: onboarding, onDone: () => done = true);

    await tester.tap(find.text('Arsenal').first);
    await _settle(tester);
    await tester.tap(find.text('Los Angeles Lakers').first);
    await _settle(tester);

    await tester.tap(find.text('Continue with 2 teams'));
    await _settle(tester);

    expect(teams.followed.map((t) => t.name), containsAll(['Arsenal', 'Los Angeles Lakers']));
    expect(onboarding.completed, isTrue);
    expect(done, isTrue);
  });

  testWidgets('skip for now completes onboarding without following anything', (tester) async {
    final teams = _FakeFollowedTeamsRepository();
    final onboarding = _FakeOnboardingRepository();
    var done = false;
    await pump(tester, teams: teams, onboarding: onboarding, onDone: () => done = true);

    await tester.tap(find.text('Skip for now'));
    await _settle(tester);

    expect(teams.followed, isEmpty);
    expect(onboarding.completed, isTrue);
    expect(done, isTrue);
  });

  testWidgets('manual search finds and selects a team not in the quick-pick list', (tester) async {
    final teams = _FakeFollowedTeamsRepository();
    final onboarding = _FakeOnboardingRepository();
    await pump(tester, teams: teams, onboarding: onboarding, onDone: () {});

    // The search field sits below the quick-pick grid, off the default
    // test viewport -- scroll it into view before interacting with it,
    // same as a real user would on a small phone.
    await tester.ensureVisible(find.byType(TextField, skipOffstage: false));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'Real Madrid');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(find.text('Real Madrid'), findsWidgets);

    await tester.tap(find.text('Real Madrid').last);
    await _settle(tester);

    expect(find.text('Continue with 1 team'), findsOneWidget);
  });

  testWidgets('search with no results shows a friendly message', (tester) async {
    final teams = _FakeFollowedTeamsRepository();
    final onboarding = _FakeOnboardingRepository();
    await pump(tester, teams: teams, onboarding: onboarding, onDone: () {});

    await tester.ensureVisible(find.byType(TextField, skipOffstage: false));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'Nonexistent Team Zzz');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(find.text('No teams matched that search.'), findsOneWidget);
  });
}
