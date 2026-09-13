import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/models/event_tag.dart';
import 'package:calander/services/tag_repository.dart';
import 'package:calander/ui/tags/tag_management_screen.dart';

/// In-memory [TagRepository] for widget tests, independent of Firestore.
class _InMemoryTagRepository implements TagRepository {
  final Map<String, EventTag> _tags = {};
  final _controller = StreamController<List<EventTag>>.broadcast();
  bool defaultsInitialized = false;
  int _nextId = 0;

  void _emit() => _controller.add(_tags.values.toList());

  @override
  Stream<List<EventTag>> watchTags() {
    // Mirrors Firestore's snapshots() semantics: every new subscriber gets
    // the current state immediately, then subsequent updates.
    late StreamController<List<EventTag>> perListenerController;
    StreamSubscription<List<EventTag>>? upstreamSub;
    perListenerController = StreamController<List<EventTag>>(
      onListen: () {
        perListenerController.add(_tags.values.toList());
        upstreamSub = _controller.stream.listen(perListenerController.add);
      },
      onCancel: () => upstreamSub?.cancel(),
    );
    return perListenerController.stream;
  }

  @override
  Future<void> ensureDefaultTagsInitialized() async {
    if (defaultsInitialized) return;
    defaultsInitialized = true;
    for (final name in kDefaultTagNames) {
      final id = 'default_${name.toLowerCase()}';
      _tags[id] = EventTag(id: id, name: name, colorValue: 0xFF000000, isDefault: true);
    }
    _emit();
  }

  @override
  Future<EventTag> addTag({required String name, required int colorValue}) async {
    final id = 'tag_${_nextId++}';
    final tag = EventTag(id: id, name: name, colorValue: colorValue);
    _tags[id] = tag;
    _emit();
    return tag;
  }

  @override
  Future<void> updateTag(String tagId, {String? name, int? colorValue}) async {
    final existing = _tags[tagId];
    if (existing == null) return;
    _tags[tagId] = existing.copyWith(name: name, colorValue: colorValue);
    _emit();
  }

  @override
  Future<void> deleteTag(String tagId) async {
    _tags.remove(tagId);
    _emit();
  }
}

void main() {
  testWidgets('shows default tags after initialization', (tester) async {
    final repo = _InMemoryTagRepository();
    await tester.pumpWidget(MaterialApp(home: TagManagementScreen(repository: repo)));
    await tester.pumpAndSettle();

    for (final name in kDefaultTagNames) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('adding a tag shows it in the list', (tester) async {
    final repo = _InMemoryTagRepository();
    await tester.pumpWidget(MaterialApp(home: TagManagementScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Fitness');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Fitness'), findsOneWidget);
  });

  testWidgets('editing a tag renames it', (tester) async {
    final repo = _InMemoryTagRepository();
    await tester.pumpWidget(MaterialApp(home: TagManagementScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Renamed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Renamed'), findsOneWidget);
  });

  testWidgets('deleting a tag requires confirmation and removes it', (tester) async {
    final repo = _InMemoryTagRepository();
    await tester.pumpWidget(MaterialApp(home: TagManagementScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Delete tag?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsNothing);
  });
}
