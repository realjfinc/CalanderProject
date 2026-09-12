import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/services/firestore_tag_repository.dart';
import 'package:calander/services/tag_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreTagRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreTagRepository(uid: 'user-1', firestore: firestore);
  });

  test('ensureDefaultTagsInitialized creates Work/Personal/School once', () async {
    await repository.ensureDefaultTagsInitialized();

    final tags = await repository.watchTags().first;
    expect(tags.map((t) => t.name).toSet(), kDefaultTagNames.toSet());
    expect(tags.every((t) => t.isDefault), isTrue);
  });

  test('ensureDefaultTagsInitialized is idempotent', () async {
    await repository.ensureDefaultTagsInitialized();
    await repository.ensureDefaultTagsInitialized();

    final tags = await repository.watchTags().first;
    expect(tags.length, kDefaultTagNames.length);
  });

  test('ensureDefaultTagsInitialized does not resurrect a deleted default tag', () async {
    await repository.ensureDefaultTagsInitialized();
    var tags = await repository.watchTags().first;
    final work = tags.firstWhere((t) => t.name == 'Work');
    await repository.deleteTag(work.id);

    // Simulate a second app launch for the same (already-initialized) account.
    await repository.ensureDefaultTagsInitialized();

    tags = await repository.watchTags().first;
    expect(tags.any((t) => t.name == 'Work'), isFalse);
    expect(tags.length, kDefaultTagNames.length - 1);
  });

  test('addTag creates a custom tag', () async {
    final tag = await repository.addTag(name: 'Fitness', colorValue: 0xFF000000);

    final tags = await repository.watchTags().first;
    expect(tags.any((t) => t.id == tag.id && t.name == 'Fitness'), isTrue);
    expect(tags.firstWhere((t) => t.id == tag.id).isDefault, isFalse);
  });

  test('updateTag renames and recolors a tag', () async {
    final tag = await repository.addTag(name: 'Old', colorValue: 0xFF000000);
    await repository.updateTag(tag.id, name: 'New', colorValue: 0xFFFFFFFF);

    final tags = await repository.watchTags().first;
    final updated = tags.firstWhere((t) => t.id == tag.id);
    expect(updated.name, 'New');
    expect(updated.colorValue, 0xFFFFFFFF);
  });

  test('deleteTag removes a tag', () async {
    final tag = await repository.addTag(name: 'Temp', colorValue: 0xFF000000);
    await repository.deleteTag(tag.id);

    final tags = await repository.watchTags().first;
    expect(tags.any((t) => t.id == tag.id), isFalse);
  });

  test('tags are scoped per-user', () async {
    final otherUserRepo = FirestoreTagRepository(uid: 'user-2', firestore: firestore);
    await repository.ensureDefaultTagsInitialized();

    final otherUserTags = await otherUserRepo.watchTags().first;
    expect(otherUserTags, isEmpty);
  });

  test('watchTags emits updates as tags change', () async {
    final emissions = <int>[];
    final sub = repository.watchTags().listen((tags) => emissions.add(tags.length));

    await Future<void>.delayed(Duration.zero);
    await repository.addTag(name: 'A', colorValue: 0xFF000000);
    await Future<void>.delayed(Duration.zero);
    await repository.addTag(name: 'B', colorValue: 0xFF000000);
    await Future<void>.delayed(Duration.zero);

    expect(emissions, containsAllInOrder([0, 1, 2]));
    await sub.cancel();
  });
}
