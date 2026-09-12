import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/firestore_event_repository.dart';

void main() {
  test('addEvent saves an upload-sourced event with sourceId and tag left null', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreEventRepository(uid: 'user-1', firestore: firestore);

    final id = await repo.addEvent(
      CalendarEvent(
        id: '',
        title: 'Block Party',
        location: 'Main St',
        start: DateTime.utc(2026, 7, 4, 23),
        end: DateTime.utc(2026, 7, 5, 2),
        source: EventSource.upload,
        sourceId: null,
        status: EventStatus.active,
        tag: null,
        notes: 'Bring snacks',
        attachments: const ['https://example.com/flyer.png'],
      ),
    );

    final doc = await firestore.collection('users').doc('user-1').collection('events').doc(id).get();
    final data = doc.data()!;
    expect(data['source'], 'upload');
    expect(data['sourceId'], isNull);
    expect(data['tag'], isNull);
    expect(data['title'], 'Block Party');
    expect(data['attachments'], ['https://example.com/flyer.png']);
  });

  test('events are scoped per-user', () async {
    final firestore = FakeFirebaseFirestore();
    final repoA = FirestoreEventRepository(uid: 'user-a', firestore: firestore);
    final repoB = FirestoreEventRepository(uid: 'user-b', firestore: firestore);

    await repoA.addEvent(
      CalendarEvent(
        id: '',
        title: 'A only',
        start: DateTime.utc(2026),
        end: DateTime.utc(2026, 1, 1, 1),
        source: EventSource.upload,
      ),
    );

    final bEvents = await firestore.collection('users').doc('user-b').collection('events').get();
    expect(bEvents.docs, isEmpty);
    // repoB is unused beyond establishing the second user's scope exists.
    expect(repoB, isNotNull);
  });
}
