import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Registers this device's FCM token so a backend (e.g. a Cloud Function
/// reacting to a synced-provider event change, added in a later step) has
/// somewhere to send push notifications for this user.
///
/// Stored at `users/{uid}/meta/fcmToken`, which this branch's
/// `firestore.rules` scopes to the owning authenticated user via the
/// `meta/{metaId}` rule.
class FcmTokenRegistrar {
  factory FcmTokenRegistrar({
    required String uid,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) {
    return FcmTokenRegistrar._(
      uid,
      firestore ?? FirebaseFirestore.instance,
      messaging ?? FirebaseMessaging.instance,
    );
  }

  FcmTokenRegistrar._(this._uid, this._firestore, this._messaging);

  final String _uid;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  StreamSubscription<String>? _refreshSubscription;

  Future<void> start() async {
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
    _refreshSubscription ??= _messaging.onTokenRefresh.listen(_saveToken);
  }

  Future<void> _saveToken(String token) {
    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('meta')
        .doc('fcmToken')
        .set({'token': token, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> stop() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
  }
}
