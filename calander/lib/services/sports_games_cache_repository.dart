import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/calendar_event.dart';

/// Read-only access to the global, cross-user cache of a team's upcoming
/// games at `sportsTeamGames/{teamId}/games` -- populated for every team
/// the sports poller's catalog covers, not just teams someone follows (see
/// `scripts/sports_poller/sports_cache_repository.py` and its Firestore
/// rules). Lets following a new team show its games immediately, instead
/// of waiting for that team's first hourly poll.
abstract class SportsGamesCacheRepository {
  Future<List<CalendarEvent>> fetchCachedGames(String teamId);
}

class FirestoreSportsGamesCacheRepository implements SportsGamesCacheRepository {
  FirestoreSportsGamesCacheRepository({FirebaseFirestore? firestore}) : _injectedFirestore = firestore;

  final FirebaseFirestore? _injectedFirestore;
  // Deferred, not resolved in the constructor: `SportsModeScreen` builds
  // one of these unconditionally (so it's ready the moment someone taps
  // Follow), including in widget tests that never call fetchCachedGames --
  // eagerly touching FirebaseFirestore.instance there throws
  // `[core/no-app]` with no real Firebase app initialized.
  late final FirebaseFirestore _firestore = _injectedFirestore ?? FirebaseFirestore.instance;

  @override
  Future<List<CalendarEvent>> fetchCachedGames(String teamId) async {
    final snapshot = await _firestore
        .collection('sportsTeamGames')
        .doc(teamId)
        .collection('games')
        .get();
    return snapshot.docs.map((doc) => _fromCacheDoc(doc.id, doc.data())).toList();
  }
}

/// A cached game becomes an incoming [CalendarEvent] the same shape
/// `TheSportsDbClient`'s own upcoming-events call would produce -- `tag`
/// null, `status` active (the [CalendarEvent] constructor's own defaults),
/// so it can go straight through the same `ingestProviderEvent` dedup/
/// conflict pipeline every other source uses.
CalendarEvent _fromCacheDoc(String sourceId, Map<String, dynamic> data) {
  final start = data['start'];
  final end = data['end'];
  return CalendarEvent(
    id: '',
    title: data['title'] as String? ?? 'Game',
    location: data['location'] as String?,
    start: start is Timestamp ? start.toDate().toUtc() : DateTime.now().toUtc(),
    end: end is Timestamp ? end.toDate().toUtc() : DateTime.now().toUtc(),
    source: EventSource.sports,
    sourceId: sourceId,
    notes: data['league'] as String?,
  );
}
