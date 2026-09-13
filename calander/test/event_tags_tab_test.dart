import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/models/event_tag.dart';
import 'package:calander/services/event_repository.dart';
import 'package:calander/services/tag_repository.dart';
import 'package:calander/ui/tags/event_tags_tab.dart';

class _FakeEventRepository implements EventRepository {
  final Map<String, CalendarEvent> _events = {};
  final _controller = StreamController<List<CalendarEvent>>.broadcast();
  final List<(String, String?)> setTagCalls = [];

  void seed(CalendarEvent event) {
    _events[event.id] = event;
    _controller.add(_events.values.toList());
  }

  @override
  Stream<List<CalendarEvent>> watchEvents() {
    late StreamController<List<CalendarEvent>> perListener;
    StreamSubscription<List<CalendarEvent>>? upstream;
    perListener = StreamController<List<CalendarEvent>>(
      onListen: () {
        perListener.add(_events.values.toList());
        upstream = _controller.stream.listen(perListener.add);
      },
      onCancel: () => upstream?.cancel(),
    );
    return perListener.stream;
  }

  @override
  Future<String> addEvent(CalendarEvent event) async {
    _events[event.id] = event;
    _controller.add(_events.values.toList());
    return event.id;
  }

  @override
  Future<void> updateEvent(CalendarEvent event) async {
    final existing = _events[event.id];
    if (existing != null && existing.tag != event.tag) {
      setTagCalls.add((event.id, event.tag));
    }
    _events[event.id] = event;
    _controller.add(_events.values.toList());
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    _events.remove(eventId);
    _controller.add(_events.values.toList());
  }
}

class _FakeTagRepository implements TagRepository {
  _FakeTagRepository(this._tags);
  final List<EventTag> _tags;

  @override
  Stream<List<EventTag>> watchTags() => Stream.value(_tags);

  @override
  Future<void> ensureDefaultTagsInitialized() async {}

  @override
  Future<EventTag> addTag({required String name, required int colorValue}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateTag(String tagId, {String? name, int? colorValue}) async {}

  @override
  Future<void> deleteTag(String tagId) async {}
}

CalendarEvent _event({String id = 'e1', String title = 'Standup', String? tag}) {
  final now = DateTime.utc(2026);
  return CalendarEvent(
    id: id,
    title: title,
    tag: tag,
    start: now,
    end: now.add(const Duration(hours: 1)),
    source: EventSource.manual,
  );
}

const _tags = [
  EventTag(id: 'work', name: 'Work', colorValue: 0xFF0000FF),
  EventTag(id: 'personal', name: 'Personal', colorValue: 0xFF00FF00),
];

void main() {
  testWidgets('shows "Untagged" for an event with no tag', (tester) async {
    final events = _FakeEventRepository()..seed(_event());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EventTagsTab(eventRepository: events, tagRepository: _FakeTagRepository(_tags))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Untagged'), findsOneWidget);
  });

  testWidgets('shows the tag name for an already-tagged event', (tester) async {
    final events = _FakeEventRepository()..seed(_event(tag: 'work'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EventTagsTab(eventRepository: events, tagRepository: _FakeTagRepository(_tags))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Untagged'), findsNothing);
  });

  testWidgets('tapping an untagged event and picking a tag assigns it', (tester) async {
    final events = _FakeEventRepository()..seed(_event());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EventTagsTab(eventRepository: events, tagRepository: _FakeTagRepository(_tags))),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Untagged'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();

    expect(events.setTagCalls, [('e1', 'work')]);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('the user can override an already-assigned tag', (tester) async {
    final events = _FakeEventRepository()..seed(_event(tag: 'work'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EventTagsTab(eventRepository: events, tagRepository: _FakeTagRepository(_tags))),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal').last);
    await tester.pumpAndSettle();

    expect(events.setTagCalls, [('e1', 'personal')]);
    expect(find.text('Personal'), findsOneWidget);
  });

  testWidgets('picking "No tag" clears an event\'s tag', (tester) async {
    final events = _FakeEventRepository()..seed(_event(tag: 'work'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EventTagsTab(eventRepository: events, tagRepository: _FakeTagRepository(_tags))),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No tag'));
    await tester.pumpAndSettle();

    expect(events.setTagCalls, [('e1', null)]);
    expect(find.text('Untagged'), findsOneWidget);
  });
}
