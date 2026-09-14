import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/models/followed_team.dart';
import 'package:calander/services/event_repository.dart';
import 'package:calander/services/followed_teams_repository.dart';
import 'package:calander/services/sports_onboarding_repository.dart';
import 'package:calander/services/thesportsdb_client.dart';
import 'package:calander/ui/sports/sports_mode_screen.dart';

class _FakeFollowedTeamsRepository implements FollowedTeamsRepository {
  @override
  Stream<List<FollowedTeam>> watchFollowedTeams() => Stream.value(const []);

  @override
  Future<void> followTeam(FollowedTeam team) async {}

  @override
  Future<void> unfollowTeam(String teamId) async {}
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
  _FakeOnboardingRepository(this._completed);
  bool _completed;

  @override
  Future<bool> hasCompletedOnboarding() async => _completed;

  @override
  Future<void> completeOnboarding() async => _completed = true;
}

TheSportsDbClient _emptyResultsClient() {
  final client = MockClient((request) async => http.Response(jsonEncode({'teams': []}), 200));
  return TheSportsDbClient(httpClient: client);
}

/// The onboarding screen has two perpetually-looping AnimationControllers,
/// so `pumpAndSettle()` never returns there -- bounded pumps instead.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('first-time visitor sees the onboarding screen, not the tabs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SportsModeScreen(
          followedTeamsRepository: _FakeFollowedTeamsRepository(),
          eventRepository: _FakeEventRepository(),
          onboardingRepository: _FakeOnboardingRepository(false),
          apiClient: _emptyResultsClient(),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Never miss a game.'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('a returning user goes straight to the Dashboard/Follow Teams tabs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SportsModeScreen(
          followedTeamsRepository: _FakeFollowedTeamsRepository(),
          eventRepository: _FakeEventRepository(),
          onboardingRepository: _FakeOnboardingRepository(true),
          apiClient: _emptyResultsClient(),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Never miss a game.'), findsNothing);
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Follow Teams'), findsOneWidget);
  });

  testWidgets('finishing onboarding swaps straight to the tabs in the same session', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SportsModeScreen(
          followedTeamsRepository: _FakeFollowedTeamsRepository(),
          eventRepository: _FakeEventRepository(),
          onboardingRepository: _FakeOnboardingRepository(false),
          apiClient: _emptyResultsClient(),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Never miss a game.'), findsOneWidget);

    await tester.tap(find.text('Skip for now'));
    await _settle(tester);

    expect(find.text('Never miss a game.'), findsNothing);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
