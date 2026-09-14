import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_write_limiter.dart';
import 'sports_onboarding_repository.dart';

/// Firestore-backed [SportsOnboardingRepository], stored at
/// `users/{uid}/meta/sportsOnboarding` -- same `meta` collection and
/// owner-only rule (`../../firestore.rules`) already used by the tag-init
/// marker (Step 1) and the FCM token (Step 2). The write goes through
/// [FirestoreWriteLimiter] like every other write under `users/{uid}`,
/// since the account write-quota rules reject any write that doesn't
/// attach a matching quota update.
class FirestoreSportsOnboardingRepository implements SportsOnboardingRepository {
  factory FirestoreSportsOnboardingRepository({required String uid, FirebaseFirestore? firestore}) {
    return FirestoreSportsOnboardingRepository._(uid, firestore ?? FirebaseFirestore.instance);
  }

  FirestoreSportsOnboardingRepository._(this._uid, this._firestore);

  final String _uid;
  final FirebaseFirestore _firestore;
  late final _limiter = FirestoreWriteLimiter(firestore: _firestore, uid: _uid);

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('users').doc(_uid).collection('meta').doc('sportsOnboarding');

  @override
  Future<bool> hasCompletedOnboarding() async {
    final snapshot = await _doc.get();
    return snapshot.data()?['completed'] == true;
  }

  @override
  Future<void> completeOnboarding() {
    return _limiter.commit(
      [_doc.path],
      (transaction) => transaction.set(_doc, {'completed': true}, SetOptions(merge: true)),
    );
  }
}
