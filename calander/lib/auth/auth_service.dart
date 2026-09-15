import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

@immutable
class AuthAccount {
  const AuthAccount({
    required this.uid,
    required this.email,
    required this.verified,
  });
  final String uid;
  final String email;
  final bool verified;
}

abstract class AuthService extends ChangeNotifier {
  AuthAccount? get account;
  bool get loading;
  String? get notice;
  Future<void> createAccount(String name, String email, String password);
  Future<void> logIn(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> sendVerification();
  Future<void> refreshAccount();
  Future<void> logOut();

  /// Permanently deletes the signed-in user's account and all their data
  /// (see the `deleteAccount` Cloud Function), then signs them out. There's
  /// no undo -- callers are expected to confirm with the user first.
  Future<void> deleteAccount();
}

class FirebaseAuthService extends AuthService {
  FirebaseAuthService({FirebaseAuth? firebaseAuth, FirebaseFunctions? functions})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _functions = functions ?? FirebaseFunctions.instance {
    _subscription = _auth.userChanges().listen(
      (_) {
        if (!_creatingAccount) _publishAccount();
      },
      onError: (Object error) {
        if (_disposed) return;
        _loading = false;
        _notice = authErrorMessage(error);
        notifyListeners();
      },
    );
  }
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  late final StreamSubscription<User?> _subscription;
  AuthAccount? _account;
  bool _loading = true;
  bool _creatingAccount = false;
  bool _disposed = false;
  String? _notice;
  @override
  AuthAccount? get account => _account;
  @override
  bool get loading => _loading;
  @override
  String? get notice => _notice;

  void _publishAccount() {
    if (_disposed) return;
    final user = _auth.currentUser;
    _account = user == null
        ? null
        : AuthAccount(
            uid: user.uid,
            email: user.email ?? '',
            verified: user.emailVerified,
          );
    _loading = false;
    notifyListeners();
  }

  @override
  Future<void> createAccount(String name, String email, String password) async {
    _creatingAccount = true;
    _notice = null;
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = result.user!;
      try {
        await user.updateDisplayName(name.trim());
      } on FirebaseAuthException {
        _notice = 'Your account was created, but your name could not be saved.';
      }
      try {
        await user.sendEmailVerification();
      } on FirebaseAuthException {
        _notice = 'Your account was created. We couldn’t send the verification email. Please use Resend email.';
      }
    } finally {
      _creatingAccount = false;
      _publishAccount();
    }
  }

  @override
  Future<void> logIn(String email, String password) async {
    _notice = null;
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      // Match Firebase's email-enumeration protection for unknown addresses.
      if (error.code != 'user-not-found') rethrow;
    }
  }

  @override
  Future<void> sendVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    await user.sendEmailVerification();
    _notice = null;
    _publishAccount();
  }

  @override
  Future<void> refreshAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.reload();
      if (_auth.currentUser?.emailVerified ?? false) {
        await _auth.currentUser!.getIdToken(true);
      }
      _publishAccount();
    } on FirebaseAuthException catch (error) {
      if ([
        'user-disabled',
        'user-not-found',
        'user-token-expired',
        'invalid-user-token',
      ].contains(error.code)) {
        await logOut();
      }
      rethrow;
    }
  }

  @override
  Future<void> logOut() async {
    await _auth.signOut();
    _notice = null;
    _publishAccount();
  }

  @override
  Future<void> deleteAccount() async {
    await _functions.httpsCallable('deleteAccount').call<void>();
    await _auth.signOut();
    _notice = null;
    _publishAccount();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

String authErrorMessage(Object error) {
  if (error is! FirebaseAuthException) {
    return 'Something went wrong. Please try again.';
  }
  return switch (error.code) {
    'invalid-email' => 'Enter a valid email address.',
    'email-already-in-use' => 'This email already has an account. Try logging in or resetting your password.',
    'weak-password' => 'Choose a stronger password with at least 8 characters.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'The email or password is incorrect.',
    'user-disabled' => 'This account is disabled. Please contact support.',
    'too-many-requests' =>
      'Too many attempts. Please wait a little before trying again.',
    'network-request-failed' => 'Check your internet connection and try again.',
    'operation-not-allowed' =>
      'This login method is not enabled yet. Please contact the app owner.',
    'requires-recent-login' ||
    'user-token-expired' ||
    'invalid-user-token' => 'Please log in again to continue.',
    'popup-closed-by-user' ||
    'web-context-cancelled' ||
    'canceled' => 'Sign-in was cancelled.',
    'popup-blocked' =>
      'Allow the sign-in popup in your browser, then try again.',
    'account-exists-with-different-credential' =>
      'Use the login method you originally used for this email.',
    _ => 'We couldn’t complete that request. Please try again.',
  };
}
