import 'package:flutter/material.dart';

import 'auth/auth_screens.dart';
import 'auth/auth_service.dart';
import 'auth/auth_widgets.dart';
import 'services/event_repository.dart';
import 'services/tag_repository.dart';
import 'services/tag_routing_repository.dart';
import 'services/theme_preference.dart';
import 'theme.dart';
import 'ui/calendar/calendar_home_screen.dart';
import 'ui/not_found_screen.dart';

class CalanderApp extends StatefulWidget {
  const CalanderApp({
    super.key,
    required this.auth,
    this.themeMode,
    this.themeStore,
    this.events,
    this.tags,
    this.tagRouting,
  });
  final AuthService auth;

  /// Forces a specific appearance instead of loading (and letting Settings
  /// persist) the device's own saved preference -- used by tests/previews
  /// that need deterministic light/dark rendering. Production leaves this
  /// null so [SharedPreferencesThemeStore] (or [themeStore], for tests
  /// that want to fake persistence itself) decides.
  final ThemeMode? themeMode;
  final ThemePreferenceStore? themeStore;
  final CalendarEventRepository? events;
  final TagRepository? tags;
  final TagRoutingRepository? tagRouting;

  @override
  State<CalanderApp> createState() => _CalanderAppState();
}

class _CalanderAppState extends State<CalanderApp> {
  late final ThemePreferenceStore _store = widget.themeStore ?? SharedPreferencesThemeStore();
  late final ValueNotifier<ThemeMode> _themeMode = ValueNotifier(widget.themeMode ?? ThemeMode.system);

  @override
  void initState() {
    super.initState();
    if (widget.themeMode == null) {
      _store.load().then((mode) {
        if (mounted) _themeMode.value = mode;
      });
    }
  }

  Future<void> _changeThemeMode(ThemeMode mode) async {
    // Applying the choice is instant and never fails; persisting it for
    // next launch is best-effort, so a storage hiccup doesn't undo the
    // user's pick or throw them an error for what looked like it worked.
    _themeMode.value = mode;
    try {
      await _store.save(mode);
    } catch (_) {}
  }

  @override
  void dispose() {
    _themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: _themeMode,
    builder: (context, mode, _) => MaterialApp(
      title: 'Calander',
      debugShowCheckedModeBanner: false,
      theme: calanderTheme(Brightness.light),
      darkTheme: calanderTheme(Brightness.dark),
      themeMode: mode,
      onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (_) => const NotFoundScreen()),
      home: ListenableBuilder(
        listenable: widget.auth,
        builder: (context, _) {
          if (widget.auth.loading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final account = widget.auth.account;
          if (account == null) {
            return SignedOutFlow(
              key: const ValueKey('signed-out'),
              auth: widget.auth,
            );
          }
          if (!account.verified) {
            return VerificationScreen(
              key: ValueKey('verify-${account.uid}'),
              auth: widget.auth,
            );
          }
          return CalendarHomeScreen(
            key: ValueKey('home-${account.uid}'),
            auth: widget.auth,
            events: widget.events,
            tags: widget.tags,
            tagRouting: widget.tagRouting,
            themeMode: _themeMode,
            onThemeModeChanged: _changeThemeMode,
          );
        },
      ),
    ),
  );
}

class FirebaseSetupApp extends StatelessWidget {
  const FirebaseSetupApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Calander',
    debugShowCheckedModeBanner: false,
    theme: calanderTheme(Brightness.light),
    darkTheme: calanderTheme(Brightness.dark),
    home: const AuthLayout(
      title: 'Calander',
      subtitle: 'We couldn’t connect just yet.',
      children: [
        AuthCard(
          title: 'App setup needs attention',
          message: 'Firebase could not start. Check the app’s Firebase configuration and restart Calander.',
        ),
      ],
    ),
  );
}
