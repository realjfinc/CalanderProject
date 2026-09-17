import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/sports_games_cache_repository.dart';

void main() {
  test('maps a cached game doc to a CalendarEvent with tag null and status active', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('sportsTeamGames')
        .doc('133604')
        .collection('games')
        .doc('e-1')
        .set({
          'title': 'Arsenal vs Chelsea',
          'location': 'Emirates Stadium',
          'start': Timestamp.fromDate(DateTime.utc(2026, 3, 1, 15)),
          'end': Timestamp.fromDate(DateTime.utc(2026, 3, 1, 18)),
          'sourceId': 'e-1',
          'league': 'English Premier League',
        });
    final repository = FirestoreSportsGamesCacheRepository(uid: 'alice', firestore: firestore);

    final games = await repository.fetchCachedGames('133604');

    expect(games, hasLength(1));
    final game = games.single;
    expect(game.title, 'Arsenal vs Chelsea');
    expect(game.location, 'Emirates Stadium');
    expect(game.start, DateTime.utc(2026, 3, 1, 15));
    expect(game.end, DateTime.utc(2026, 3, 1, 18));
    expect(game.source, EventSource.sports);
    expect(game.sourceId, 'e-1');
    expect(game.notes, 'English Premier League');
    expect(game.tag, isNull);
    expect(game.status, EventStatus.active);
  });

  test('returns an empty list for a team with nothing cached yet', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreSportsGamesCacheRepository(uid: 'alice', firestore: firestore);

    expect(await repository.fetchCachedGames('no-such-team'), isEmpty);
  });

  test('cacheGames writes a game that fetchCachedGames can then read back', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreSportsGamesCacheRepository(uid: 'alice', firestore: firestore);
    final start = DateTime.utc(2026, 3, 1, 15);
    final game = CalendarEvent(
      id: '',
      title: 'Arsenal vs Chelsea',
      location: 'Emirates Stadium',
      start: start,
      end: start.add(const Duration(hours: 3)),
      source: EventSource.sports,
      sourceId: 'e-1',
      notes: 'English Premier League',
    );

    await repository.cacheGames('133604', [game]);

    final games = await repository.fetchCachedGames('133604');
    expect(games, hasLength(1));
    expect(games.single.title, 'Arsenal vs Chelsea');
    expect(games.single.sourceId, 'e-1');
  });

  test('cacheGames is a no-op for an empty list', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreSportsGamesCacheRepository(uid: 'alice', firestore: firestore);

    await repository.cacheGames('133604', const []);

    expect(await repository.fetchCachedGames('133604'), isEmpty);
  });
}
