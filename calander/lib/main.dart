import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/auth_service.dart';
import 'firebase_configuration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: FirebaseConfiguration.currentPlatform,
    );
    runApp(CalanderApp(auth: FirebaseAuthService()));
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
    runApp(const FirebaseSetupApp());
  }
}
