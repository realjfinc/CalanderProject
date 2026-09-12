import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public Firebase app identifiers, not server credentials.
/// Registered in the Calander project (calander-1025b).
abstract final class FirebaseConfiguration {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
        'Calander is configured for Android, iOS, and web.',
      ),
    };
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyAnzpt8oW27tn7SfprL1FWrL09WnHlPnvg',
    appId: '1:736239283423:android:8fbc31393afb6138e2cd6a',
    messagingSenderId: '736239283423',
    projectId: 'calander-1025b',
    storageBucket: 'calander-1025b.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyBQ1EukCOlyrzJDhchtM2kpBaoCiUicAEc',
    appId: '1:736239283423:ios:1bcd2cd49cd1dac1e2cd6a',
    messagingSenderId: '736239283423',
    projectId: 'calander-1025b',
    storageBucket: 'calander-1025b.firebasestorage.app',
    iosBundleId: 'com.example.calander',
  );

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDyNZLiHtfAgssNzvEPVW_CH5rI9_PVU-g',
    appId: '1:736239283423:web:7f6e08f57adac1c5e2cd6a',
    messagingSenderId: '736239283423',
    projectId: 'calander-1025b',
    authDomain: 'calander-1025b.firebaseapp.com',
    storageBucket: 'calander-1025b.firebasestorage.app',
  );
}
