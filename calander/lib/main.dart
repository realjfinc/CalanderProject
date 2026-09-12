import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'auth/auth_service.dart';
import 'firebase_configuration.dart';
import 'services/flutter_local_notifier.dart';
import 'services/notifications_bootstrap.dart';
import 'services/push_notification_service.dart';

/// Runs in its own isolate when a push arrives while the app is
/// backgrounded/terminated, so it needs its own Firebase init.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: FirebaseConfiguration.currentPlatform);
  await PushNotificationService(notifier: FlutterLocalNotifier()).handleMessage(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: FirebaseConfiguration.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final auth = FirebaseAuthService();
    final notifications = NotificationsBootstrap(auth: auth);
    auth.addListener(notifications.onAuthChanged);
    notifications.onAuthChanged();

    runApp(CalanderApp(auth: auth));
  } catch (error) {
    debugPrint('Firebase initialization failed: $error');
    runApp(const FirebaseSetupApp());
  }
}
