import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/firestore_event_repository.dart';

void main() {
  test('setEventTag assigns a tag to an existing event', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreEventRepository(uid: 'user-1', firestore: firestore);
    final docRef = await firestore
        .collection('users')
        .doc('user-1')
        .collection('events')
        .add(
          CalendarEvent(
            id: '',
            title: 'Standup',
            start: DateTime.utc(2026),
            end: DateTime.utc(2026, 1, 1, 1),
            source: EventSource.manual,
          ).toMap(),
        );

    await repo.setEventTag(docRef.id, 'work');

    final events = await repo.watchEvents().first;
    expect(events.single.tag, 'work');
  });

  test('setEventTag can clear a tag by passing null', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreEventRepository(uid: 'user-1', firestore: firestore);
    final docRef = await firestore
        .collection('users')
        .doc('user-1')
        .collection('events')
        .add(
          CalendarEvent(
            id: '',
            title: 'Standup',
            start: DateTime.utc(2026),
            end: DateTime.utc(2026, 1, 1, 1),
            source: EventSource.manual,
            tag: 'work',
          ).toMap(),
        );

    await repo.setEventTag(docRef.id, null);

    final events = await repo.watchEvents().first;
    expect(events.single.tag, isNull);
  });

  test('watchEvents is scoped per-user', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('users')
        .doc('user-a')
        .collection('events')
        .add(
          CalendarEvent(
            id: '',
            title: 'A only',
            start: DateTime.utc(2026),
            end: DateTime.utc(2026, 1, 1, 1),
            source: EventSource.manual,
          ).toMap(),
        );

    final repoB = FirestoreEventRepository(uid: 'user-b', firestore: firestore);
    final events = await repoB.watchEvents().first;
    expect(events, isEmpty);
  });
}
