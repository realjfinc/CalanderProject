import 'package:flutter/material.dart';

import 'auth/auth_screens.dart';
import 'auth/auth_service.dart';
import 'auth/auth_widgets.dart';
import 'services/event_repository.dart';
import 'services/tag_repository.dart';
import 'theme.dart';
import 'ui/calendar/calendar_home_screen.dart';

class CalanderApp extends StatelessWidget {
  const CalanderApp({
    super.key,
    required this.auth,
    this.themeMode = ThemeMode.system,
    this.events,
    this.tags,
  });
  final AuthService auth;
  final ThemeMode themeMode;
  final CalendarEventRepository? events;
  final TagRepository? tags;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Calander',
    debugShowCheckedModeBanner: false,
    theme: calanderTheme(Brightness.light),
    darkTheme: calanderTheme(Brightness.dark),
    themeMode: themeMode,
    home: ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        if (auth.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final account = auth.account;
        if (account == null) {
          return SignedOutFlow(key: const ValueKey('signed-out'), auth: auth);
        }
        if (!account.verified) {
          return VerificationScreen(
            key: ValueKey('verify-${account.uid}'),
            auth: auth,
          );
        }
        return CalendarHomeScreen(
          key: ValueKey('home-${account.uid}'),
          auth: auth,
          events: events,
          tags: tags,
        );
      },
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
