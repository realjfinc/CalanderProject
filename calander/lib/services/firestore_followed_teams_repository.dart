import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/followed_team.dart';
import 'followed_teams_repository.dart';
import 'firestore_write_limiter.dart';

/// Firestore-backed [FollowedTeamsRepository], stored at
/// `users/{uid}/followedTeams/{teamId}` (keyed by the sports API's own
/// team id, so following the same team twice is naturally idempotent).
class FirestoreFollowedTeamsRepository implements FollowedTeamsRepository {
  factory FirestoreFollowedTeamsRepository({
    required String uid,
    FirebaseFirestore? firestore,
  }) {
    return FirestoreFollowedTeamsRepository._(
      uid,
      firestore ?? FirebaseFirestore.instance,
    );
  }

  FirestoreFollowedTeamsRepository._(this._uid, this._firestore);

  final String _uid;
  final FirebaseFirestore _firestore;
  late final _limiter = FirestoreWriteLimiter(firestore: _firestore, uid: _uid);

  CollectionReference<Map<String, dynamic>> get _teamsRef =>
      _firestore.collection('users').doc(_uid).collection('followedTeams');

  @override
  Stream<List<FollowedTeam>> watchFollowedTeams() {
    return _teamsRef.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => FollowedTeam.fromMap(doc.data()))
          .toList();
    });
  }

  @override
  Future<void> followTeam(FollowedTeam team) {
    final ref = _teamsRef.doc(team.id);
    return _limiter.commit([
      ref.path,
    ], (transaction) => transaction.set(ref, team.toMap()));
  }

  @override
  Future<void> unfollowTeam(String teamId) {
    final ref = _teamsRef.doc(teamId);
    return _limiter.commit([
      ref.path,
    ], (transaction) => transaction.delete(ref));
  }
}
