import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/models/followed_team.dart';
import 'package:calander/services/firestore_followed_teams_repository.dart';

void main() {
  test('followTeam adds a team, and watchFollowedTeams reflects it', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreFollowedTeamsRepository(uid: 'user-1', firestore: firestore);

    await repo.followTeam(const FollowedTeam(id: 't1', name: 'Arsenal', league: 'EPL'));

    final teams = await repo.watchFollowedTeams().first;
    expect(teams, hasLength(1));
    expect(teams.single.name, 'Arsenal');
  });

  test('following the same team twice does not duplicate it', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreFollowedTeamsRepository(uid: 'user-1', firestore: firestore);

    await repo.followTeam(const FollowedTeam(id: 't1', name: 'Arsenal', league: 'EPL'));
    await repo.followTeam(const FollowedTeam(id: 't1', name: 'Arsenal', league: 'EPL'));

    final teams = await repo.watchFollowedTeams().first;
    expect(teams, hasLength(1));
  });

  test('unfollowTeam removes it', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreFollowedTeamsRepository(uid: 'user-1', firestore: firestore);
    await repo.followTeam(const FollowedTeam(id: 't1', name: 'Arsenal', league: 'EPL'));

    await repo.unfollowTeam('t1');

    expect(await repo.watchFollowedTeams().first, isEmpty);
  });

  test('followed teams are scoped per-user', () async {
    final firestore = FakeFirebaseFirestore();
    await FirestoreFollowedTeamsRepository(
      uid: 'user-a',
      firestore: firestore,
    ).followTeam(const FollowedTeam(id: 't1', name: 'Arsenal', league: 'EPL'));

    final repoB = FirestoreFollowedTeamsRepository(uid: 'user-b', firestore: firestore);
    expect(await repoB.watchFollowedTeams().first, isEmpty);
  });
}
