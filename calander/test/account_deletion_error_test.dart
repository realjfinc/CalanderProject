import 'package:calander/auth/auth_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing deletion endpoint explains service unavailability', () {
    expect(
      authErrorMessage(
        FirebaseFunctionsException(code: 'not-found', message: 'NOT FOUND'),
      ),
      'Account deletion is currently unavailable. Please contact support.',
    );
  });

  test('expired callable authentication asks the user to log in again', () {
    expect(
      authErrorMessage(
        FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'UNAUTHENTICATED',
        ),
      ),
      'Please log in again to delete your account.',
    );
  });

  test('a timeout does not claim deletion failed or succeeded', () {
    expect(
      authErrorMessage(
        FirebaseFunctionsException(
          code: 'deadline-exceeded',
          message: 'DEADLINE EXCEEDED',
        ),
      ),
      'Account deletion is taking longer than expected. Please check again shortly.',
    );
  });

  test('internal service errors do not expose backend details', () {
    expect(
      authErrorMessage(
        FirebaseFunctionsException(
          code: 'internal',
          message: 'Private backend diagnostic',
          details: null,
        ),
      ),
      'Your account could not be deleted. Please try again later.',
    );
  });

  test('existing authentication errors keep their message', () {
    expect(
      authErrorMessage(FirebaseAuthException(code: 'requires-recent-login')),
      'Please log in again to continue.',
    );
  });
}
