/// Tracks whether this user has been through the first-time Sports Mode
/// "pick your teams" onboarding, so it's shown exactly once -- including
/// for a user who onboards and follows zero teams (skips), who must never
/// see it again just because `followedTeams` happens to be empty.
abstract class SportsOnboardingRepository {
  Future<bool> hasCompletedOnboarding();

  Future<void> completeOnboarding();
}
