import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/services/firestore_sports_onboarding_repository.dart';

void main() {
  test('a fresh account has not completed onboarding', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreSportsOnboardingRepository(uid: 'user-1', firestore: firestore);

    expect(await repo.hasCompletedOnboarding(), isFalse);
  });

  test('completeOnboarding is idempotent and sticks across repository instances', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreSportsOnboardingRepository(uid: 'user-1', firestore: firestore);

    await repo.completeOnboarding();
    await repo.completeOnboarding();

    expect(await repo.hasCompletedOnboarding(), isTrue);

    final anotherInstance = FirestoreSportsOnboardingRepository(uid: 'user-1', firestore: firestore);
    expect(await anotherInstance.hasCompletedOnboarding(), isTrue);
  });

  test('onboarding status is scoped per-user', () async {
    final firestore = FakeFirebaseFirestore();
    final userOne = FirestoreSportsOnboardingRepository(uid: 'user-1', firestore: firestore);
    final userTwo = FirestoreSportsOnboardingRepository(uid: 'user-2', firestore: firestore);

    await userOne.completeOnboarding();

    expect(await userOne.hasCompletedOnboarding(), isTrue);
    expect(await userTwo.hasCompletedOnboarding(), isFalse);
  });
}
