import 'package:flutter/material.dart';

import 'auth/auth_screens.dart';
import 'auth/auth_service.dart';
import 'auth/auth_widgets.dart';
import 'services/firestore_event_repository.dart';
import 'services/firestore_tag_repository.dart';
import 'services/firestore_tag_routing_repository.dart';
import 'theme.dart';
import 'ui/tags/tag_management_screen.dart';
import 'ui/tags/tag_routing_screen.dart';

class CalanderApp extends StatelessWidget {
  const CalanderApp({
    super.key,
    required this.auth,
    this.themeMode = ThemeMode.system,
  });
  final AuthService auth;
  final ThemeMode themeMode;
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
        return TestHomePage(key: ValueKey('home-${account.uid}'), auth: auth);
      },
    ),
  );
}

class TestHomePage extends StatefulWidget {
  const TestHomePage({super.key, required this.auth});
  final AuthService auth;
  @override
  State<TestHomePage> createState() => _TestHomePageState();
}

class _TestHomePageState extends State<TestHomePage> {
  bool _busy = false;
  String? _error;
  Future<void> _logout() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.logOut();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openTagManagement() {
    final uid = widget.auth.account!.uid;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TagManagementScreen(
          repository: FirestoreTagRepository(uid: uid),
        ),
      ),
    );
  }

  void _openTagRouting() {
    final uid = widget.auth.account!.uid;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TagRoutingScreen(
          eventRepository: FirestoreEventRepository(uid: uid),
          tagRepository: FirestoreTagRepository(uid: uid),
          routingRepository: FirestoreTagRoutingRepository(uid: uid),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 342),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AuthMessage(_error),
                AuthButton('Manage Tags', onPressed: _openTagManagement, busy: _busy),
                const SizedBox(height: 12),
                AuthButton('Tag Routing', onPressed: _openTagRouting, busy: _busy),
                const SizedBox(height: 12),
                AuthButton('Log out', onPressed: _logout, busy: _busy),
              ],
            ),
          ),
        ),
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
