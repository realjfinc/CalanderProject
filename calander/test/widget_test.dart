import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:calander/app.dart';
import 'package:calander/auth/auth_service.dart';
import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/firestore_event_repository.dart';
import 'package:calander/services/firestore_tag_repository.dart';
import 'package:calander/services/firestore_tag_routing_repository.dart';
import 'package:calander/ui/calendar/calendar_home_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class TestAuth extends AuthService {
  AuthAccount? user;
  int signups = 0;
  int resets = 0;
  int refreshes = 0;
  int resends = 0;
  int accountDeletions = 0;
  String? deletionPassword;
  bool verifyOnRefresh = false;
  Completer<void>? loginPending;
  @override
  AuthAccount? get account => user;
  @override
  bool get loading => false;
  @override
  String? get notice => null;
  void setUser({bool verified = false}) {
    user = AuthAccount(
      uid: 'test-user',
      email: 'test@example.com',
      verified: verified,
    );
    notifyListeners();
  }

  @override
  Future<void> createAccount(String name, String email, String password) async {
    signups++;
    setUser();
  }

  @override
  Future<void> logIn(String email, String password) async {
    if (loginPending != null) await loginPending!.future;
    setUser(verified: true);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resets++;
  }

  @override
  Future<void> sendVerification() async {
    resends++;
  }

  @override
  Future<void> refreshAccount() async {
    refreshes++;
    if (verifyOnRefresh) setUser(verified: true);
  }

  @override
  Future<void> logOut() async {
    user = null;
    notifyListeners();
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    deletionPassword = password;
    accountDeletions++;
    user = null;
    notifyListeners();
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> mount(
  WidgetTester tester,
  TestAuth auth, {
  ThemeMode mode = ThemeMode.light,
}) async {
  final firestore = FakeFirebaseFirestore();
  await tester.pumpWidget(
    CalanderApp(
      auth: auth,
      themeMode: mode,
      events: FirestoreEventRepository(uid: 'test-user', firestore: firestore),
      tags: FirestoreTagRepository(uid: 'test-user', firestore: firestore),
      tagRouting: FirestoreTagRoutingRepository(uid: 'test-user', firestore: firestore),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await font.load();

    // Icon glyphs render as tofu boxes under the test binding unless the
    // font is loaded explicitly; only used by the visual-preview tests
    // below, so skip quietly if the SDK cache isn't where expected.
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final iconFontFile = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (iconFontFile.existsSync()) {
        final iconFont = FontLoader('MaterialIcons')
          ..addFont(iconFontFile.readAsBytes().then(ByteData.sublistView));
        await iconFont.load();
      }
    }
  });
  testWidgets('Welcome uses Calander, with no non-functional social sign-in buttons', (
    tester,
  ) async {
    final auth = TestAuth();
    await mount(tester, auth);
    expect(find.text('Calander'), findsOneWidget);
    await tapText(tester, 'I already have an account');
    // Google/Apple sign-in aren't wired to anything real yet -- shipping a
    // button that just says "isn't available yet" reads as broken, so
    // there's nothing to tap until they're actually implemented.
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Continue with Apple'), findsNothing);
    expect(auth.account, isNull);
  });

  testWidgets('Signup validates fields, then gates the home on verification', (
    tester,
  ) async {
    final auth = TestAuth();
    await mount(tester, auth);
    await tapText(tester, 'Get started');
    await tapText(tester, 'Create account');
    expect(auth.signups, 0);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test User');
    await tester.enterText(fields.at(1), 'test@example.com');
    await tester.enterText(fields.at(2), 'testing123');
    await tester.enterText(fields.at(3), 'different123');
    await tapText(tester, 'Create account');
    expect(find.text('Your passwords don’t match.'), findsOneWidget);
    await tester.enterText(fields.at(3), 'testing123');
    await tapText(tester, 'Create account');
    expect(auth.signups, 1);
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
    await tapText(tester, 'I’ve verified my email');
    expect(find.text('Log out'), findsNothing);
    auth.verifyOnRefresh = true;
    await tapText(tester, 'I’ve verified my email');
    expect(find.byType(CalendarHomeScreen), findsOneWidget);
  });

  testWidgets(
    'Restored unverified session remains gated and resend is throttled',
    (tester) async {
      final auth = TestAuth()..setUser();
      await mount(tester, auth);
      expect(find.text('Log out'), findsNothing);
      await tapText(tester, 'Resend email');
      expect(auth.resends, 1);
      expect(find.text('Resend email in 60s'), findsOneWidget);
      await tapText(tester, 'Use a different account');
      expect(find.text('Welcome To Calander'), findsOneWidget);
    },
  );

  testWidgets(
    'Password reset shows a neutral confirmation and returns to login',
    (tester) async {
      final auth = TestAuth();
      await mount(tester, auth);
      await tapText(tester, 'I already have an account');
      await tapText(tester, 'Forgot password?');
      await tester.enterText(find.byType(TextFormField), 'unknown@example.com');
      await tapText(tester, 'Send reset link');
      expect(auth.resets, 1);
      expect(
        find.textContaining('If an account exists for unknown@example.com'),
        findsOneWidget,
      );
      await tapText(tester, 'Back to log in');
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );

  testWidgets(
    'Verified session shows calendar and settings logout clears all private routes',
    (tester) async {
      final auth = TestAuth()..setUser(verified: true);
      await mount(tester, auth);
      expect(find.byType(CalendarHomeScreen), findsOneWidget);
      await tapText(tester, 'Settings');
      // Tag management, tag routing, and upload/extraction now live under
      // the Tags nav destination and the Calendar tab, not Settings.
      expect(find.text('Manage Tags'), findsNothing);
      expect(find.text('Add Event from Upload'), findsNothing);
      expect(find.text('Tag Routing'), findsNothing);
      expect(find.text('Export Calendar'), findsOneWidget);
      expect(find.text('Provider Sync'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Sports Mode'), findsNothing);
      expect(find.text('Welcome'), findsNothing);
      await tapText(tester, 'Log out');
      expect(find.text('Welcome To Calander'), findsOneWidget);
      expect(find.text('Log out'), findsNothing);
    },
  );

  testWidgets(
    'The calendar tab offers extraction (photo/PDF/link) right alongside New Event, not just from Settings',
    (tester) async {
      final auth = TestAuth()..setUser(verified: true);
      await mount(tester, auth);

      expect(find.text('Add from a photo, PDF, or link'), findsOneWidget);
    },
  );

  testWidgets(
    'Tags nav destination hosts My Tags, Events, and Auto-Tag Rules as tabs',
    (tester) async {
      final auth = TestAuth()..setUser(verified: true);
      await mount(tester, auth);

      await tapText(tester, 'Tags');
      expect(find.text('My Tags'), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Auto-Tag Rules'), findsOneWidget);
    },
  );

  testWidgets(
    'Appearance picker in Settings switches the app between light, dark, and system',
    (tester) async {
      final auth = TestAuth()..setUser(verified: true);
      await mount(tester, auth, mode: ThemeMode.light);
      await tapText(tester, 'Settings');

      MaterialApp currentApp() => tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(currentApp().themeMode, ThemeMode.light);

      await tapText(tester, 'Dark');
      expect(currentApp().themeMode, ThemeMode.dark);

      await tapText(tester, 'System');
      expect(currentApp().themeMode, ThemeMode.system);
    },
  );

  testWidgets(
    'An unknown route shows the 404 screen instead of crashing',
    (tester) async {
      final auth = TestAuth()..setUser(verified: true);
      await mount(tester, auth);

      final context = tester.element(find.byType(CalendarHomeScreen));
      Navigator.of(context, rootNavigator: true).pushNamed('/this-route-does-not-exist');
      await tester.pumpAndSettle();

      expect(find.text('404'), findsOneWidget);
      expect(find.text('Back to Calander'), findsOneWidget);
    },
  );

  testWidgets(
    'Delete Account asks for confirmation, then signs out and clears the account',
    (tester) async {
      final auth = TestAuth()..setUser(verified: true);
      await mount(tester, auth);
      await tapText(tester, 'Settings');
      await tapText(tester, 'Delete Account');
      // The confirmation dialog is showing; the account isn't deleted yet.
      expect(find.text('Delete account?'), findsOneWidget);
      expect(auth.accountDeletions, 0);

      await tapText(tester, 'Cancel');
      expect(find.text('Delete account?'), findsNothing);
      expect(auth.accountDeletions, 0);
      expect(find.text('Export Calendar'), findsOneWidget);

      await tapText(tester, 'Delete Account');
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Delete')).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('delete-account-password')), 'test-password');
      await tester.pump();
      await tapText(tester, 'Delete');
      await tester.pumpAndSettle();
      expect(auth.accountDeletions, 1);
      expect(auth.deletionPassword, 'test-password');
      expect(find.text('Welcome To Calander'), findsOneWidget);
    },
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mode.name} screens fit narrow phones and larger text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await mount(tester, TestAuth(), mode: mode);
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Get started');
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Already have an account? Log in');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Render welcome and login previews for visual review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: CalanderApp(
            key: ValueKey(mode),
            auth: TestAuth(),
            themeMode: mode,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final screen in ['welcome', 'privacy', 'login']) {
        if (screen == 'privacy') {
          await tapText(tester, 'Privacy Policy');
        } else if (screen == 'login') {
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          await tapText(tester, 'I already have an account');
        }
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/auth-previews/$screen-${mode.name}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });

  testWidgets(
    'Render calendar and settings previews for visual review',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        final firestore = FakeFirebaseFirestore();
        final events = FirestoreEventRepository(uid: 'test-user', firestore: firestore);
        final now = DateTime.now().toUtc();
        await events.addEvent(
          CalendarEvent(
            id: 'preview-1',
            title: 'Design review',
            location: 'Studio',
            start: DateTime.utc(now.year, now.month, now.day, 14),
            end: DateTime.utc(now.year, now.month, now.day, 15),
          ),
        );
        await events.addEvent(
          CalendarEvent(
            id: 'preview-2',
            title: 'Jets game',
            source: EventSource.sports,
            start: DateTime.utc(now.year, now.month, now.day, 18),
            end: DateTime.utc(now.year, now.month, now.day, 21),
          ),
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: CalanderApp(
              key: ValueKey(mode),
              auth: TestAuth()..setUser(verified: true),
              themeMode: mode,
              events: events,
              tags: FirestoreTagRepository(uid: 'test-user', firestore: firestore),
              tagRouting: FirestoreTagRoutingRepository(uid: 'test-user', firestore: firestore),
            ),
          ),
        );
        await tester.pumpAndSettle();

        Future<void> capture(String screen) async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File('build/auth-previews/$screen-${mode.name}.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('calendar');

        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pumpAndSettle();
        await capture('calendar-scrolled');
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
        await tester.pumpAndSettle();

        await tapText(tester, 'Tags');
        await capture('tags');

        await tester.pageBack();
        await tester.pumpAndSettle();

        await tapText(tester, 'Settings');
        await capture('settings');

        final context = tester.element(find.byType(CalendarHomeScreen));
        Navigator.of(context, rootNavigator: true).pushNamed('/this-route-does-not-exist');
        await tester.pumpAndSettle();
        await capture('404');
      }
    },
  );
}
