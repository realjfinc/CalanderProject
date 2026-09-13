import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/calendar_event.dart';
import 'event_repository.dart';

/// Every path is derived from the authenticated user's UID, never an event form.
class FirestoreEventRepository implements EventRepository {
  FirestoreEventRepository({required String uid, FirebaseFirestore? firestore})
    : _events = (firestore ?? FirebaseFirestore.instance)
          .collection('users')
          .doc(uid)
          .collection('events');

  final CollectionReference<Map<String, dynamic>> _events;

  @override
  Stream<EventSnapshot> watchEvents() => _events
      .orderBy('startAt')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => EventSnapshot(
          snapshot.docs
              .map((doc) => CalendarEvent.fromMap(doc.id, doc.data()))
              .toList(),
          fromCache: snapshot.metadata.isFromCache,
          pending: snapshot.metadata.hasPendingWrites,
        ),
      );

  @override
  String newId() => _events.doc().id;

  @override
  Future<void> save(CalendarEvent event, {required bool isNew}) {
    if (event.title.trim().isEmpty || !event.end.isAfter(event.start)) {
      throw ArgumentError('An event needs a title and an end after its start.');
    }
    final data = event.toMap();
    if (isNew) {
      data['createdAt'] = FieldValue.serverTimestamp();
      return _events.doc(event.id).set(data);
    }
    // update fails if another device deleted the event instead of resurrecting it.
    return _events.doc(event.id).update(data);
  }

  @override
  Future<void> delete(String id) => _events.doc(id).delete();
}
