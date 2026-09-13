import '../models/followed_team.dart';

/// Per-user list of followed teams for Sports Mode.
abstract class FollowedTeamsRepository {
  Stream<List<FollowedTeam>> watchFollowedTeams();

  Future<void> followTeam(FollowedTeam team);

  Future<void> unfollowTeam(String teamId);
}
