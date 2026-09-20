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
    return _unfollowAndRemoveGames(teamId);
  }

  Future<void> _unfollowAndRemoveGames(String teamId) async {
    final teamRef = _teamsRef.doc(teamId);
    final team = await teamRef.get();
    final teamName = team.data()?['name'] as String?;
    final events = _firestore.collection('users').doc(_uid).collection('events');

    // Keep fetching until every matching game is handled. Each transaction
    // stays within the 20-document client write limit.
    while (true) {
      final snapshot = await events.where('source', isEqualTo: 'sports').get();
      final matching = snapshot.docs.where((event) {
        final data = event.data();
        final sportsTeamIds = (data['sportsTeamIds'] as List?)?.cast<String>();
        if (sportsTeamIds?.contains(teamId) ?? false) return true;

        // Events written before sportsTeamIds existed have no durable team
        // link. Their sports title is "Home vs Away", so this safely clears
        // those legacy records for the team being unfollowed as well.
        final title = data['title'] as String? ?? '';
        return sportsTeamIds == null &&
            teamName != null &&
            teamName.trim().isNotEmpty &&
            title.toLowerCase().contains(teamName.toLowerCase());
      }).take(19).toList();

      if (matching.isEmpty) break;
      await _limiter.commit(
        matching.map((event) => event.reference.path).toList(),
        (transaction) {
          for (final event in matching) {
            final sportsTeamIds =
                (event.data()['sportsTeamIds'] as List?)?.cast<String>();
            final remainingTeamIds = sportsTeamIds
                ?.where((id) => id != teamId)
                .toList();
            if (remainingTeamIds != null && remainingTeamIds.isNotEmpty) {
              transaction.update(event.reference, {'sportsTeamIds': remainingTeamIds});
            } else {
              transaction.delete(event.reference);
            }
          }
        },
      );
    }

    await _limiter.commit([teamRef.path], (transaction) => transaction.delete(teamRef));
  }
}
