import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tag_rule.dart';
import 'tag_routing_repository.dart';
import 'firestore_write_limiter.dart';

/// Firestore-backed [TagRoutingRepository], stored as a single document at
/// `users/{uid}/settings/tagRouting`. A fresh account has no such document
/// yet, which is treated as the default settings (auto-tagging off, no
/// rules) rather than an error.
class FirestoreTagRoutingRepository implements TagRoutingRepository {
  factory FirestoreTagRoutingRepository({
    required String uid,
    FirebaseFirestore? firestore,
  }) {
    return FirestoreTagRoutingRepository._(
      uid,
      firestore ?? FirebaseFirestore.instance,
    );
  }

  FirestoreTagRoutingRepository._(this._uid, this._firestore);

  final String _uid;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _settingsRef => _firestore
      .collection('users')
      .doc(_uid)
      .collection('settings')
      .doc('tagRouting');

  @override
  Stream<TagRoutingSettings> watchSettings() {
    return _settingsRef.snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null
          ? const TagRoutingSettings()
          : TagRoutingSettings.fromMap(data);
    });
  }

  @override
  Future<void> updateSettings(TagRoutingSettings settings) {
    return FirestoreWriteLimiter(firestore: _firestore, uid: _uid).commit([
      _settingsRef.path,
    ], (transaction) => transaction.set(_settingsRef, settings.toMap()));
  }
}
