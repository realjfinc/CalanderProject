import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_write_limiter.dart';

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);
  final String message;
}

class AccountDeletionService {
  static const _collections = ['followedTeams', 'settings', 'events', 'tags', 'meta'];
  AccountDeletionService({FirebaseFirestore? firestore})
    : _injectedFirestore = firestore;

  final FirebaseFirestore? _injectedFirestore;
  late final FirebaseFirestore _firestore =
      _injectedFirestore ?? FirebaseFirestore.instance;

  // These are all of the collections currently stored under users/{uid}.
  // Firestore does not delete subcollections when their parent is deleted.
  Future<void> _deleteFirestoreData(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);
    for (final name in _collections) {
      while (true) {
        final page = await userRef.collection(name).limit(200).get(
          const GetOptions(source: Source.server),
        );
        if (page.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    await userRef.delete();
    // Keep the login if a writer on another device has repopulated a collection.
    for (final name in _collections) {
      final remaining = await userRef.collection(name).limit(1).get(
        const GetOptions(source: Source.server),
      );
      if (remaining.docs.isNotEmpty) {
        throw AccountDeletionException(
          'Some saved data is still syncing. Close this account on other devices and try deleting again. Your login has not been deleted.',
        );
      }
    }
    await _firestore.collection('clientWriteLimits').doc(uid).delete();
  }

  Future<void> delete(User user, String password) async {
    if (password.isEmpty || user.email == null) {
      throw const AccountDeletionException(
        'Enter your password to delete your account.',
      );
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
    await user.getIdToken(true);
    await FirestoreWriteLimiter.pauseForAccountDeletion(user.uid);
    try {
      try {
        await _firestore.waitForPendingWrites();
        await _deleteFirestoreData(user.uid);
      } on FirebaseException catch (error) {
        throw AccountDeletionException(
          error.code == 'permission-denied'
              ? 'Your saved data could not be deleted. The Firestore deletion rules need to be updated. Your login has not been deleted.'
              : 'Couldn’t finish deleting your saved data. Check your connection and try again. Your login has not been deleted.',
        );
      }
      await user.delete();
    } catch (_) {
      FirestoreWriteLimiter.resumeAfterFailedDeletion(user.uid);
      rethrow;
    }
  }
}
