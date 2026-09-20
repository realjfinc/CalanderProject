import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'app.dart';
import 'auth/auth_service.dart';
import 'firebase_configuration.dart';
import 'services/flutter_local_notifier.dart';
import 'services/notifications_bootstrap.dart';
import 'services/push_notification_service.dart';
import 'services/tag_routing_bootstrap.dart';

/// Runs in its own isolate when a push arrives while the app is
/// backgrounded/terminated, so it needs its own Firebase init.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: FirebaseConfiguration.currentPlatform);
  await PushNotificationService(notifier: FlutterLocalNotifier()).handleMessage(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Needed by the iCloud CalDAV adapter (Step 6) to resolve a VEVENT's
  // TZID to a UTC offset; harmless to always initialize.
  tz_data.initializeTimeZones();
  try {
    await Firebase.initializeApp(
      options: FirebaseConfiguration.currentPlatform,
    );
    // Silences "No AppCheckProvider installed" (harmless on its own, but
    // required the moment App Check enforcement is ever turned on for
    // Firestore/Storage/Functions in the Firebase console). The debug
    // provider's token only has to be registered with the project if/when
    // that happens -- it logs itself to the console on first run.
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final auth = FirebaseAuthService();
    final notifications = NotificationsBootstrap(auth: auth);
    auth.addListener(notifications.onAuthChanged);
    notifications.onAuthChanged();

    final tagRouting = TagRoutingBootstrap(auth: auth);
    auth.addListener(tagRouting.onAuthChanged);
    tagRouting.onAuthChanged();

    runApp(CalanderApp(auth: auth));
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
    runApp(const FirebaseSetupApp());
  }
}
