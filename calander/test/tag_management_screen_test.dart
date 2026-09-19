import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/models/event_tag.dart';
import 'package:calander/models/tag_rule.dart';
import 'package:calander/services/event_repository.dart';
import 'package:calander/services/tag_repository.dart';
import 'package:calander/services/tag_routing_repository.dart';
import 'package:calander/ui/tags/tag_management_screen.dart';

/// Minimal fake -- these tests only exercise the "My Tags" tab, so the
/// "Events" and "Auto-Tag Rules" tabs this screen now also hosts just need
/// something that satisfies the interface, not real behavior.
class _EmptyEventRepository implements EventRepository {
  @override
  Stream<List<CalendarEvent>> watchEvents() => Stream.value(const []);
  @override
  Future<String> addEvent(CalendarEvent event) async => 'id';
  @override
  Future<void> updateEvent(CalendarEvent event) async {}
  @override
  Future<void> deleteEvent(String eventId) async {}
}

/// Minimal fake -- see [_EmptyEventRepository].
class _DefaultTagRoutingRepository implements TagRoutingRepository {
  @override
  Stream<TagRoutingSettings> watchSettings() => Stream.value(const TagRoutingSettings());
  @override
  Future<void> updateSettings(TagRoutingSettings settings) async {}
}

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
    await tester.pumpWidget(MaterialApp(home: TagManagementScreen(repository: repo, eventRepository: _EmptyEventRepository(), routingRepository: _DefaultTagRoutingRepository())));
    await tester.pumpAndSettle();

    for (final name in kDefaultTagNames) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('adding a tag shows it in the list', (tester) async {
    final repo = _InMemoryTagRepository();
    await tester.pumpWidget(MaterialApp(home: TagManagementScreen(repository: repo, eventRepository: _EmptyEventRepository(), routingRepository: _DefaultTagRoutingRepository())));
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
    await tester.pumpWidget(MaterialApp(home: TagManagementScreen(repository: repo, eventRepository: _EmptyEventRepository(), routingRepository: _DefaultTagRoutingRepository())));
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
    await tester.pumpWidget(MaterialApp(home: TagManagementScreen(repository: repo, eventRepository: _EmptyEventRepository(), routingRepository: _DefaultTagRoutingRepository())));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Delete tag?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsNothing);
  });

  testWidgets(
    'hosts My Tags, Events, and Auto-Tag Rules as tabs, with an add-something FAB on My Tags and Auto-Tag Rules but not Events',
    (tester) async {
      final repo = _InMemoryTagRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: TagManagementScreen(
            repository: repo,
            eventRepository: _EmptyEventRepository(),
            routingRepository: _DefaultTagRoutingRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Tags'), findsOneWidget);
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Auto-Tag Rules'), findsOneWidget);
      expect(find.byTooltip('Add tag'), findsOneWidget);

      await tester.tap(find.text('Events'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.add), findsNothing);

      await tester.tap(find.text('Auto-Tag Rules'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add rule'), findsOneWidget);

      await tester.tap(find.text('My Tags'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add tag'), findsOneWidget);
    },
  );

  testWidgets('the Auto-Tag Rules FAB actually opens the add-rule dialog', (tester) async {
    final repo = _InMemoryTagRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: TagManagementScreen(
          repository: repo,
          eventRepository: _EmptyEventRepository(),
          routingRepository: _DefaultTagRoutingRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Auto-Tag Rules'));
    await tester.pumpAndSettle();
    expect(find.text('No rules yet. Tap + to add one.'), findsOneWidget);

    await tester.tap(find.byTooltip('Add rule'));
    await tester.pumpAndSettle();

    expect(find.text('Add rule'), findsWidgets);
    expect(find.text('Field'), findsOneWidget);
    expect(find.text('Assign tag'), findsOneWidget);
  });
}
