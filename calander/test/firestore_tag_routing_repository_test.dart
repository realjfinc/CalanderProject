import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/models/tag_rule.dart';
import 'package:calander/services/firestore_tag_routing_repository.dart';

void main() {
  test('watchSettings returns defaults (auto-tag off, no rules) for a fresh account', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreTagRoutingRepository(
      uid: 'user-1',
      firestore: firestore,
    );

    final settings = await repo.watchSettings().first;

    expect(settings.autoTagEnabled, isFalse);
    expect(settings.tagRules, isEmpty);
  });

  test('updateSettings persists autoTagEnabled and rules, round-tripping correctly', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = FirestoreTagRoutingRepository(
      uid: 'user-1',
      firestore: firestore,
    );

    await repo.updateSettings(
      TagRoutingSettings(
        autoTagEnabled: true,
        tagRules: [
          const TagRule(
            field: RuleField.title,
            operator: RuleOperator.contains,
            value: 'standup',
            tag: 'work',
          ),
        ],
      ),
    );

    final settings = await repo.watchSettings().firstWhere(
      (settings) => settings.autoTagEnabled,
    );
    expect(settings.autoTagEnabled, isTrue);
    expect(settings.tagRules, hasLength(1));
    expect(settings.tagRules.single.field, RuleField.title);
    expect(settings.tagRules.single.operator, RuleOperator.contains);
    expect(settings.tagRules.single.value, 'standup');
    expect(settings.tagRules.single.tag, 'work');
  });

  test('settings are scoped per-user', () async {
    final firestore = FakeFirebaseFirestore();
    final repoA = FirestoreTagRoutingRepository(
      uid: 'user-a',
      firestore: firestore,
    );
    final repoB = FirestoreTagRoutingRepository(
      uid: 'user-b',
      firestore: firestore,
    );

    await repoA.updateSettings(const TagRoutingSettings(autoTagEnabled: true));

    final settingsB = await repoB.watchSettings().first;
    expect(settingsB.autoTagEnabled, isFalse);
  });
}
