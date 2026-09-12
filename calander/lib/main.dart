import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'app.dart';
import 'auth/auth_service.dart';
import 'firebase_configuration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Needed by the iCloud CalDAV adapter (Step 6) to resolve a VEVENT's
  // TZID to a UTC offset; harmless to always initialize.
  tz_data.initializeTimeZones();
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
