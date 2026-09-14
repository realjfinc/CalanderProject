import 'package:calander/services/firestore_event_repository.dart';
import 'package:calander/services/firestore_tag_repository.dart';
import 'package:calander/services/firestore_followed_teams_repository.dart';
import 'package:calander/services/firestore_sports_onboarding_repository.dart';
import 'package:calander/ui/calendar/calendar_home_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show TestAuth;

void main() {
  testWidgets(
    'Sports is a bottom tab, retains navigation, and is absent from Settings',
    (tester) async {
      final db = FakeFirebaseFirestore();
      final auth = TestAuth()..setUser(verified: true);
      // This test is about bottom-nav structure, not the first-time
      // onboarding gate (covered separately in sports_mode_screen_test.dart
      // and sports_onboarding_screen_test.dart) -- pre-complete it so
      // tapping "Sports" goes straight to the tabs, same as any returning
      // user.
      final sportsOnboarding = FirestoreSportsOnboardingRepository(uid: 'test-user', firestore: db);
      await sportsOnboarding.completeOnboarding();
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarHomeScreen(
            auth: auth,
            events: FirestoreEventRepository(uid: 'test-user', firestore: db),
            tags: FirestoreTagRepository(uid: 'test-user', firestore: db),
            followedTeams: FirestoreFollowedTeamsRepository(
              uid: 'test-user',
              firestore: db,
            ),
            sportsOnboarding: sportsOnboarding,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sports'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(find.text('Follow Teams'), findsOneWidget);
      await tester.tap(find.text('Follow Teams'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'Search for a team'),
        findsOneWidget,
      );
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.text('Search calendar'), findsWidgets);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Sports Mode'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
