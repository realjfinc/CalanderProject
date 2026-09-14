// Renders real screenshots of Sports Mode's first-time onboarding and the
// redesigned dashboard for visual review, the same RepaintBoundary
// technique as `widget_test.dart`'s welcome/login/calendar previews (see
// the root README's Screenshots section) -- no browser or emulator, and no
// real network call (a MockClient stands in for TheSportsDB here, same as
// `sports_onboarding_screen_test.dart`). Output lands in
// `build/sports-previews/` (gitignored).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:calander/models/calendar_event.dart';
import 'package:calander/models/followed_team.dart';
import 'package:calander/services/event_repository.dart';
import 'package:calander/services/followed_teams_repository.dart';
import 'package:calander/services/sports_onboarding_repository.dart';
import 'package:calander/services/thesportsdb_client.dart';
import 'package:calander/theme.dart';
import 'package:calander/ui/sports/dashboard_tab.dart';
import 'package:calander/ui/sports/sports_onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeFollowedTeamsRepository implements FollowedTeamsRepository {
  _FakeFollowedTeamsRepository([this._teams = const []]);
  final List<FollowedTeam> _teams;

  @override
  Stream<List<FollowedTeam>> watchFollowedTeams() => Stream.value(_teams);

  @override
  Future<void> followTeam(FollowedTeam team) async {}

  @override
  Future<void> unfollowTeam(String teamId) async {}
}

class _FakeEventRepository implements EventRepository {
  _FakeEventRepository([this._events = const []]);
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

class _FakeOnboardingRepository implements SportsOnboardingRepository {
  @override
  Future<bool> hasCompletedOnboarding() async => false;

  @override
  Future<void> completeOnboarding() async {}
}

Map<String, dynamic> _team(String id, String name, String league, String colorHex) => {
  'idTeam': id,
  'strTeam': name,
  'strLeague': league,
  'strColour1': colorHex,
};

TheSportsDbClient _fakeClient() {
  final client = MockClient((request) async {
    final query = request.url.queryParameters['t'] ?? '';
    final byQuery = {
      'Arsenal': [_team('133604', 'Arsenal', 'English Premier League', '#EF0107')],
      'Los Angeles Lakers': [_team('134867', 'Los Angeles Lakers', 'NBA', '#FDB927')],
    };
    return http.Response(jsonEncode({'teams': byQuery[query] ?? []}), 200);
  });
  return TheSportsDbClient(httpClient: client);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/sports-previews/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final iconFontFile = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (iconFontFile.existsSync()) {
        final iconFont = FontLoader('MaterialIcons')
          ..addFont(iconFontFile.readAsBytes().then(ByteData.sublistView));
        await iconFont.load();
      }
    }
  });

  testWidgets('onboarding screen, before and after picking teams', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: calanderTheme(Brightness.light),
        home: RepaintBoundary(
          key: key,
          child: SportsOnboardingScreen(
            followedTeamsRepository: _FakeFollowedTeamsRepository(),
            onboardingRepository: _FakeOnboardingRepository(),
            apiClient: _fakeClient(),
            onDone: () {},
          ),
        ),
      ),
    );
    await _settle(tester);
    await _capture(tester, key, 'onboarding-empty');

    await tester.tap(find.text('Arsenal').first);
    await _settle(tester);
    await tester.tap(find.text('Los Angeles Lakers').first);
    await _settle(tester);
    await _capture(tester, key, 'onboarding-two-selected');
  });

  testWidgets('redesigned dashboard with team-colored match cards', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now().toUtc();
    final teams = _FakeFollowedTeamsRepository([
      const FollowedTeam(
        id: '133604',
        name: 'Arsenal',
        league: 'English Premier League',
        accentColorHex: '#EF0107',
      ),
      const FollowedTeam(
        id: '134867',
        name: 'Los Angeles Lakers',
        league: 'NBA',
        accentColorHex: '#FDB927',
      ),
      const FollowedTeam(id: '133602', name: 'Liverpool', league: 'English Premier League'),
    ]);
    final events = _FakeEventRepository([
      CalendarEvent(
        id: 'e1',
        title: 'Ipswich Town vs Arsenal',
        location: 'Portman Road',
        start: now.add(const Duration(days: 1, hours: 3)),
        end: now.add(const Duration(days: 1, hours: 6)),
        source: EventSource.sports,
        sourceId: 'e1',
        notes: 'EFL Cup',
      ),
      CalendarEvent(
        id: 'e2',
        title: 'Sacramento Kings vs Los Angeles Lakers',
        location: 'Golden 1 Center',
        start: now.add(const Duration(days: 21)),
        end: now.add(const Duration(days: 21, hours: 3)),
        source: EventSource.sports,
        sourceId: 'e2',
        notes: 'NBA',
      ),
    ]);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: calanderTheme(Brightness.light),
          darkTheme: calanderTheme(Brightness.dark),
          themeMode: mode,
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              appBar: AppBar(title: const Text('Sports Mode')),
              body: DashboardTab(followedTeamsRepository: teams, eventRepository: events),
            ),
          ),
        ),
      );
      await _settle(tester);
      await _capture(tester, key, 'dashboard-${mode.name}');
    }
  });
}
