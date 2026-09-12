import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/auth_service.dart';
import 'firebase_configuration.dart';
import 'services/tag_routing_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: FirebaseConfiguration.currentPlatform,
    );

    final auth = FirebaseAuthService();
    final tagRouting = TagRoutingBootstrap(auth: auth);
    auth.addListener(tagRouting.onAuthChanged);
    tagRouting.onAuthChanged();

    runApp(CalanderApp(auth: auth));
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
    runApp(const FirebaseSetupApp());
  }
}
