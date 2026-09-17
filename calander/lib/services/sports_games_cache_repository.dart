import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/calendar_event.dart';
import 'firestore_write_limiter.dart';

/// Access to the global, cross-user cache of a team's upcoming games at
/// `sportsTeamGames/{teamId}/games` -- populated for every team the
/// sports poller's catalog covers, not just teams someone follows (see
/// `scripts/sports_poller/sports_cache_repository.py` and its Firestore
/// rules). Lets following a new team show its games immediately, instead
/// of waiting for that team's first hourly poll.
///
/// Reads are unrestricted for any signed-in client. [cacheGames] is a
/// narrow, quota-limited exception to "only the poller writes this" --
/// see `sports_games_backfill.dart`, which calls it only when a team the
/// poller hasn't reached yet has nothing cached.
abstract class SportsGamesCacheRepository {
  Future<List<CalendarEvent>> fetchCachedGames(String teamId);

  Future<void> cacheGames(String teamId, List<CalendarEvent> games);
}

class FirestoreSportsGamesCacheRepository implements SportsGamesCacheRepository {
  FirestoreSportsGamesCacheRepository({required this.uid, FirebaseFirestore? firestore})
    : _injectedFirestore = firestore;

  final String uid;
  final FirebaseFirestore? _injectedFirestore;
  // Deferred, not resolved in the constructor: `SportsModeScreen` builds
  // one of these unconditionally (so it's ready the moment someone taps
  // Follow), including in widget tests that never call fetchCachedGames --
  // eagerly touching FirebaseFirestore.instance there throws
  // `[core/no-app]` with no real Firebase app initialized.
  late final FirebaseFirestore _firestore = _injectedFirestore ?? FirebaseFirestore.instance;
  late final _limiter = FirestoreWriteLimiter(firestore: _firestore, uid: uid);

  CollectionReference<Map<String, dynamic>> _gamesRef(String teamId) =>
      _firestore.collection('sportsTeamGames').doc(teamId).collection('games');

  @override
  Future<List<CalendarEvent>> fetchCachedGames(String teamId) async {
    final snapshot = await _gamesRef(teamId).get();
    return snapshot.docs.map((doc) => _fromCacheDoc(doc.id, doc.data())).toList();
  }

  @override
  Future<void> cacheGames(String teamId, List<CalendarEvent> games) async {
    // A game an adapter fetched always carries its provider id (the whole
    // point of a source event); this is just the type system's own
    // nullability, not a real case to handle differently.
    final withSourceId = games.where((game) => game.sourceId != null).toList();
    if (withSourceId.isEmpty) return;

    final ref = _gamesRef(teamId);
    // The write-limiter caps a single commit at 20 documents; a team with
    // more upcoming games than that just caches its first 20 here -- the
    // next hourly poll (which writes via the Admin SDK, no such cap)
    // fills in the rest.
    final capped = withSourceId.take(20).toList();
    final refs = capped.map((game) => ref.doc(game.sourceId!)).toList();
    await _limiter.commit(
      refs.map((doc) => doc.path).toList(),
      (transaction) {
        for (var i = 0; i < capped.length; i++) {
          transaction.set(refs[i], _toCacheData(capped[i]), SetOptions(merge: true));
        }
      },
    );
  }
}

Map<String, dynamic> _toCacheData(CalendarEvent game) => {
  'title': game.title,
  'location': game.location,
  'start': Timestamp.fromDate(game.start.toUtc()),
  'end': Timestamp.fromDate(game.end.toUtc()),
  'sourceId': game.sourceId,
  'league': game.notes,
};

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
