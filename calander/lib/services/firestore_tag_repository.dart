import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_tag.dart';
import 'tag_repository.dart';

/// Default color values (ARGB) assigned to the built-in tags, in the same
/// order as [kDefaultTagNames].
const List<int> _kDefaultTagColors = [
  0xFF1E88E5, // Work - blue
  0xFF43A047, // Personal - green
  0xFFFB8C00, // School - orange
];

/// Fixed document IDs for the default tags, so re-running initialization is
/// naturally idempotent and never creates duplicates.
const List<String> _kDefaultTagIds = [
  'default_work',
  'default_personal',
  'default_school',
];

/// Firestore-backed [TagRepository] scoped to a single user.
///
/// Data model:
///   users/{uid}/tags/{tagId}        -> tag documents
///   users/{uid}/meta/tagInit        -> { initialized: bool } marker so
///                                      default-tag creation runs exactly
///                                      once per account.
class FirestoreTagRepository implements TagRepository {
  factory FirestoreTagRepository({required String uid, FirebaseFirestore? firestore}) {
    return FirestoreTagRepository._(uid, firestore ?? FirebaseFirestore.instance);
  }

  FirestoreTagRepository._(this._uid, this._firestore);

  final String _uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tagsRef =>
      _firestore.collection('users').doc(_uid).collection('tags');

  DocumentReference<Map<String, dynamic>> get _tagInitMetaRef =>
      _firestore.collection('users').doc(_uid).collection('meta').doc('tagInit');

  @override
  Stream<List<EventTag>> watchTags() {
    return _tagsRef.orderBy('createdAt').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => EventTag.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  @override
  Future<void> ensureDefaultTagsInitialized() async {
    final metaSnapshot = await _tagInitMetaRef.get();
    if (metaSnapshot.exists &&
        (metaSnapshot.data()?['initialized'] as bool? ?? false)) {
      return;
    }

    final batch = _firestore.batch();
    for (var i = 0; i < kDefaultTagNames.length; i++) {
      final tagRef = _tagsRef.doc(_kDefaultTagIds[i]);
      batch.set(
        tagRef,
        EventTag(
          id: _kDefaultTagIds[i],
          name: kDefaultTagNames[i],
          colorValue: _kDefaultTagColors[i],
          isDefault: true,
        ).toMap(),
        SetOptions(merge: true),
      );
    }
    batch.set(_tagInitMetaRef, {
      'initialized': true,
      'initializedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  @override
  Future<EventTag> addTag({required String name, required int colorValue}) async {
    final docRef = await _tagsRef.add(
      EventTag(id: '', name: name, colorValue: colorValue).toMap(),
    );
    return EventTag(id: docRef.id, name: name, colorValue: colorValue);
  }

  @override
  Future<void> updateTag(String tagId, {String? name, int? colorValue}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (colorValue != null) updates['colorValue'] = colorValue;
    if (updates.isEmpty) return;
    await _tagsRef.doc(tagId).update(updates);
  }

  @override
  Future<void> deleteTag(String tagId) async {
    await _tagsRef.doc(tagId).delete();
  }
}
