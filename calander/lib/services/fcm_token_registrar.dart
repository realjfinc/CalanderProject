import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firestore_write_limiter.dart';

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
    try {
      await _messaging.requestPermission();
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(token);
      _refreshSubscription ??= _messaging.onTokenRefresh.listen(
        _saveToken,
        onError: (Object error) =>
            debugPrint('Push token refresh failed: $error'),
      );
    } catch (error) {
      debugPrint('Push token registration failed: $error');
    }
  }

  Future<void> _saveToken(String token) async {
    final ref = _firestore
        .collection('users')
        .doc(_uid)
        .collection('meta')
        .doc('fcmToken');
    try {
      await FirestoreWriteLimiter(firestore: _firestore, uid: _uid).commit(
        [ref.path],
        (transaction) => transaction.set(ref, {
          'token': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      );
    } catch (error) {
      debugPrint('Push token registration failed: $error');
    }
  }

  Future<void> stop() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
  }
}
