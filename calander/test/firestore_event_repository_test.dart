import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/firestore_event_repository.dart';
import 'package:calander/services/upload_storage.dart';

class _FakeUploadStorage implements UploadStorage {
  final deletedUrls = <String>[];

  @override
  Future<String> upload({required bytes, required String fileName, String? contentType}) async =>
      'https://example.com/uploads/$fileName';

  @override
  Future<void> deleteByUrl(String url) async => deletedUrls.add(url);
}

CalendarEvent _event({String sourceId = 'g-1', List<String>? attachments}) {
  final start = DateTime.utc(2026, 3, 1, 10);
  return CalendarEvent(
    id: '',
    title: 'Standup',
    start: start,
    end: start.add(const Duration(minutes: 30)),
    source: EventSource.google,
    sourceId: sourceId,
    attachments: attachments,
  );
}

void main() {
  test(
    'addEvent persists an event with sourceId and leaves tag null',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repo = FirestoreEventRepository(
        uid: 'user-1',
        firestore: firestore,
      );

      final id = await repo.addEvent(_event());

      final events = await repo.watchEvents().first;
      expect(events.single.id, id);
      expect(events.single.sourceId, 'g-1');
      expect(events.single.tag, isNull);
    },
  );

  test('updateEvent overwrites fields on an existing document', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreEventRepository(uid: 'user-1', firestore: firestore);
    final id = await repo.addEvent(_event());

    final events = await repo.watchEvents().first;
    await repo.updateEvent(
      events.single.copyWith(status: EventStatus.pendingConflict),
    );

    final updated = await repo.watchEvents().firstWhere(
      (events) => events.single.status == EventStatus.pendingConflict,
    );
    expect(updated.single.id, id);
    expect(updated.single.status, EventStatus.pendingConflict);
  });

  test('deleteEvent removes the document', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreEventRepository(uid: 'user-1', firestore: firestore);
    final id = await repo.addEvent(_event());

    await repo.deleteEvent(id);

    expect(await repo.watchEvents().first, isEmpty);
  });

  test('deleteEvent also deletes the event\'s attachments from storage', () async {
    final firestore = FakeFirebaseFirestore();
    final uploadStorage = _FakeUploadStorage();
    final repo = FirestoreEventRepository(uid: 'user-1', firestore: firestore, uploadStorage: uploadStorage);
    final id = await repo.addEvent(
      _event(attachments: ['https://example.com/uploads/a.png', 'https://example.com/uploads/b.pdf']),
    );

    await repo.deleteEvent(id);

    expect(uploadStorage.deletedUrls, [
      'https://example.com/uploads/a.png',
      'https://example.com/uploads/b.pdf',
    ]);
  });

  test('deleteEvent does not touch storage for an event with no attachments', () async {
    final firestore = FakeFirebaseFirestore();
    final uploadStorage = _FakeUploadStorage();
    final repo = FirestoreEventRepository(uid: 'user-1', firestore: firestore, uploadStorage: uploadStorage);
    final id = await repo.addEvent(_event());

    await repo.deleteEvent(id);

    expect(uploadStorage.deletedUrls, isEmpty);
  });

  test('events are scoped per-user', () async {
    final firestore = FakeFirebaseFirestore();
    await FirestoreEventRepository(
      uid: 'user-a',
      firestore: firestore,
    ).addEvent(_event());

    final repoB = FirestoreEventRepository(uid: 'user-b', firestore: firestore);
    expect(await repoB.watchEvents().first, isEmpty);
  });
}
