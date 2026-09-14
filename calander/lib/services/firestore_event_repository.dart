import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/calendar_event.dart';
import 'event_repository.dart';
import 'firestore_write_limiter.dart';

/// One user-scoped collection shared by calendar editing and provider sync.
class FirestoreEventRepository implements CalendarEventRepository {
  FirestoreEventRepository({required String uid, FirebaseFirestore? firestore})
    : _events = (firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(uid)
          .collection('events');
  final CollectionReference<Map<String, dynamic>> _events;
  late final _limiter = FirestoreWriteLimiter(
    firestore: _events.firestore,
    uid: _events.parent!.id,
  );

  // Do not order by one schema's timestamp field: that would silently omit
  // documents written by the other schema before this merge.
  @override
  Stream<EventSnapshot> watchSnapshots() =>
      _events.snapshots(includeMetadataChanges: true).map((snapshot) {
        final events =
            snapshot.docs
                .map((doc) => CalendarEvent.fromMap(doc.id, doc.data()))
                .toList()
              ..sort((a, b) => a.start.compareTo(b.start));
        return EventSnapshot(
          events,
          fromCache: snapshot.metadata.isFromCache,
          pending: snapshot.metadata.hasPendingWrites,
        );
      });

  @override
  Stream<List<CalendarEvent>> watchEvents() =>
      watchSnapshots().map((snapshot) => snapshot.events);
  @override
  String newId() => _events.doc().id;

  @override
  Future<void> save(CalendarEvent event, {required bool isNew}) async {
    if (event.title.trim().isEmpty || !event.end.isAfter(event.start)) {
      throw ArgumentError('An event needs a title and an end after its start.');
    }
    final data = event.toMap();
    if (isNew) {
      data['createdAt'] = FieldValue.serverTimestamp();
      final ref = _events.doc(event.id);
      await _limiter.commit([
        ref.path,
      ], (transaction) => transaction.set(ref, data));
    } else {
      // Update preserves existing creation timestamps and cannot resurrect a
      // remotely deleted event. Legacy provider records may lack createdAt.
      final ref = _events.doc(event.id);
      await _limiter.commit([
        ref.path,
      ], (transaction) => transaction.update(ref, data));
    }
  }

  @override
  Future<String> addEvent(CalendarEvent event) async {
    final id = newId();
    await save(event.copyWith(id: id), isNew: true);
    return id;
  }

  @override
  Future<void> updateEvent(CalendarEvent event) => save(event, isNew: false);
  @override
  Future<void> deleteEvent(String eventId) {
    final ref = _events.doc(eventId);
    return _limiter.commit([
      ref.path,
    ], (transaction) => transaction.delete(ref));
  }

  @override
  Future<void> delete(String id) => deleteEvent(id);
}
