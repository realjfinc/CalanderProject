import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/calendar_event.dart';
import 'event_repository.dart';

/// Firestore-backed [EventRepository], scoped to a single user's
/// `users/{uid}/events` collection.
class FirestoreEventRepository implements EventRepository {
  factory FirestoreEventRepository({required String uid, FirebaseFirestore? firestore}) {
    return FirestoreEventRepository._(uid, firestore ?? FirebaseFirestore.instance);
  }

  FirestoreEventRepository._(this._uid, this._firestore);

  final String _uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _eventsRef =>
      _firestore.collection('users').doc(_uid).collection('events');

  @override
  Stream<List<CalendarEvent>> watchEvents() {
    return _eventsRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => CalendarEvent.fromMap(doc.id, doc.data())).toList();
    });
  }

  @override
  Future<String> addEvent(CalendarEvent event) async {
    final docRef = await _eventsRef.add(event.toMap());
    return docRef.id;
  }

  @override
  Future<void> updateEvent(CalendarEvent event) {
    return _eventsRef.doc(event.id).update(event.toMap());
  }

  @override
  Future<void> deleteEvent(String eventId) {
    return _eventsRef.doc(eventId).delete();
  }
}
