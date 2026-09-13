import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/followed_team.dart';
import 'followed_teams_repository.dart';

/// Firestore-backed [FollowedTeamsRepository], stored at
/// `users/{uid}/followedTeams/{teamId}` (keyed by the sports API's own
/// team id, so following the same team twice is naturally idempotent).
class FirestoreFollowedTeamsRepository implements FollowedTeamsRepository {
  factory FirestoreFollowedTeamsRepository({required String uid, FirebaseFirestore? firestore}) {
    return FirestoreFollowedTeamsRepository._(uid, firestore ?? FirebaseFirestore.instance);
  }

  FirestoreFollowedTeamsRepository._(this._uid, this._firestore);

  final String _uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _teamsRef =>
      _firestore.collection('users').doc(_uid).collection('followedTeams');

  @override
  Stream<List<FollowedTeam>> watchFollowedTeams() {
    return _teamsRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => FollowedTeam.fromMap(doc.data())).toList();
    });
  }

  @override
  Future<void> followTeam(FollowedTeam team) {
    return _teamsRef.doc(team.id).set(team.toMap());
  }

  @override
  Future<void> unfollowTeam(String teamId) {
    return _teamsRef.doc(teamId).delete();
  }
}
