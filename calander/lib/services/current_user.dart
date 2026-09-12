import 'package:firebase_auth/firebase_auth.dart';

/// Resolves the current signed-in user's uid.
///
/// Real sign-in (Google/Apple, account UI) is owned by Jonathan's auth work
/// and is intentionally not built here. Until that lands, this falls back to
/// anonymous auth purely so per-user Firestore data (like tags) has a stable
/// uid to scope itself to in dev/testing. Once Jonathan's sign-in flow is in
/// place, `FirebaseAuth.instance.currentUser` will already be a real user by
/// the time this runs and the anonymous fallback will simply never trigger.
Future<String> resolveCurrentUid({FirebaseAuth? auth}) async {
  final firebaseAuth = auth ?? FirebaseAuth.instance;
  final existing = firebaseAuth.currentUser;
  if (existing != null) return existing.uid;

  final credential = await firebaseAuth.signInAnonymously();
  final user = credential.user;
  if (user == null) {
    throw StateError('Anonymous sign-in did not return a user.');
  }
  return user.uid;
}
