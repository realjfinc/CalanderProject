// Reproduces three reported bugs against the actual widget tree (fakes
// only, same conventions as the rest of the suite), asserts each is fixed,
// and captures real screenshots of the fixed state to
// build/ui-fixes-previews/ (gitignored):
//   1. The Sports bottom-nav tab uses a distinct scoreboard icon, not the
//      generic/ambiguous "sports" medal glyph.
//   2. Scrolling down on Settings, pushing a sub-screen, and popping back
//      leaves the back button reachable without scrolling back up.
//   3. Following a team in Follow Teams doesn't overflow/overlap its row
//      (the app-wide OutlinedButton theme forces a full-width, 52-tall
//      minimum size, which broke ListTile.trailing before this fix).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:calander/services/firestore_event_repository.dart';
import 'package:calander/services/firestore_followed_teams_repository.dart';
import 'package:calander/services/firestore_sports_onboarding_repository.dart';
import 'package:calander/services/firestore_tag_repository.dart';
import 'package:calander/services/sports_games_cache_repository.dart';
import 'package:calander/services/thesportsdb_client.dart';
import 'package:calander/theme.dart';
import 'package:calander/ui/calendar/calendar_home_screen.dart';
import 'package:calander/ui/sports/follow_team_tab.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'widget_test.dart' show TestAuth;

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/ui-fixes-previews/$name.png');
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

  testWidgets('Sports tab uses the scoreboard icon, not the ambiguous "sports" glyph', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final db = FakeFirebaseFirestore();
    final auth = TestAuth()..setUser(verified: true);
    final sportsOnboarding = FirestoreSportsOnboardingRepository(uid: 'test-user', firestore: db);
    await sportsOnboarding.completeOnboarding();
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: calanderTheme(Brightness.light),
        home: RepaintBoundary(
          key: key,
          child: CalendarHomeScreen(
            auth: auth,
            events: FirestoreEventRepository(uid: 'test-user', firestore: db),
            tags: FirestoreTagRepository(uid: 'test-user', firestore: db),
            followedTeams: FirestoreFollowedTeamsRepository(uid: 'test-user', firestore: db),
            sportsOnboarding: sportsOnboarding,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.scoreboard_outlined), findsOneWidget);
    expect(find.byIcon(Icons.sports_outlined), findsNothing);
    expect(find.byIcon(Icons.sports), findsNothing);
    await _capture(tester, key, 'bottom-nav-new-icon');
  });

  testWidgets(
    'Settings back button stays reachable after scrolling down, pushing a screen, and popping back',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final db = FakeFirebaseFirestore();
      final auth = TestAuth()..setUser(verified: true);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: calanderTheme(Brightness.light),
          home: RepaintBoundary(
            key: key,
            child: CalendarHomeScreen(
              auth: auth,
              events: FirestoreEventRepository(uid: 'test-user', firestore: db),
              tags: FirestoreTagRepository(uid: 'test-user', firestore: db),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Scroll down far enough that the back button (top of the page,
      // pinned or not) would be off the original viewport, then push a
      // sub-screen from near the bottom of the list.
      await tester.ensureVisible(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      // Pop back to Settings via its own back button.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Back on Settings: its back button must be visible near the top of
      // the viewport right away -- no extra scroll should be required.
      final backButton = find.byTooltip('Back');
      expect(backButton, findsOneWidget);
      final topLeft = tester.getTopLeft(backButton);
      expect(
        topLeft.dy,
        lessThan(100),
        reason: 'Back button should be pinned near the top, not scrolled out of view',
      );
      await _capture(tester, key, 'settings-back-button-after-scroll-and-pop');

      // And it should actually be tappable without any manual scrolling --
      // tapping it pops off Settings, back to the main calendar (the
      // "Settings" nav-bar label stays visible either way, so check the
      // page content instead).
      await tester.tap(backButton);
      await tester.pumpAndSettle();
      expect(find.text('A little more you.'), findsNothing);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
    },
  );

  testWidgets('following a team from search does not overflow or overlap its row', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'teams': [
            {
              'idTeam': '133604',
              'strTeam': 'Arsenal',
              'strLeague': 'English Premier League',
              'strBadge': 'https://example.com/arsenal.png',
              'strColour1': '#EF0107',
            },
          ],
        }),
        200,
      );
    });
    final db = FakeFirebaseFirestore();
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: calanderTheme(Brightness.light),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            appBar: AppBar(title: const Text('Follow Teams')),
            body: FollowTeamTab(
              repository: FirestoreFollowedTeamsRepository(uid: 'test-user', firestore: db),
              apiClient: TheSportsDbClient(httpClient: client),
              gamesCacheRepository: FirestoreSportsGamesCacheRepository(uid: 'test-user', firestore: db),
              eventRepository: FirestoreEventRepository(uid: 'test-user', firestore: db),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Arsenal');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Arsenal'), findsOneWidget);
    expect(find.text('English Premier League'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();

    // The trailing action flips to "Unfollow" -- confirm nothing overflowed
    // (an overflow renders as an exception caught during the pump/paint).
    expect(find.text('Unfollow'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
    expect(tester.takeException(), isNull);

    // The Unfollow button's own height should stay compact (well under the
    // theme's forced 52 for a standalone full-width button), proving the
    // override took effect rather than silently doing nothing.
    final buttonSize = tester.getSize(find.widgetWithText(OutlinedButton, 'Unfollow'));
    expect(buttonSize.height, lessThan(48));
    await _capture(tester, key, 'follow-team-no-overflow');
  });
}
