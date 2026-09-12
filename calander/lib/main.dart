import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/current_user.dart';
import 'services/firestore_tag_repository.dart';
import 'ui/tags/tag_management_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CalanderApp());
}

class CalanderApp extends StatelessWidget {
  const CalanderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calander',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const HomeScreen(),
    );
  }
}

/// App shell. The full calendar UI is out of scope for the current step;
/// this exposes an entry point into the features being built step by step.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _openTagManagement(BuildContext context) async {
    final uid = await resolveCurrentUid();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TagManagementScreen(
          repository: FirestoreTagRepository(uid: uid),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calander')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () => _openTagManagement(context),
          icon: const Icon(Icons.label_outline),
          label: const Text('Manage Tags'),
        ),
      ),
    );
  }
}
