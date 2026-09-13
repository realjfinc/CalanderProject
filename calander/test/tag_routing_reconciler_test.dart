import 'dart:async';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/models/tag_rule.dart';
import 'package:calander/services/event_repository.dart';
import 'package:calander/services/tag_routing_reconciler.dart';
import 'package:calander/services/tag_routing_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEventRepository implements EventRepository {
  final Map<String, CalendarEvent> _events = {};
  final _controller = StreamController<List<CalendarEvent>>.broadcast();
  final List<(String, String?)> setTagCalls = [];

  void seed(CalendarEvent event) {
    _events[event.id] = event;
    _emit();
  }

  void _emit() => _controller.add(_events.values.toList());

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
    _emit();
    return event.id;
  }

  @override
  Future<void> updateEvent(CalendarEvent event) async {
    final existing = _events[event.id];
    if (existing != null && existing.tag != event.tag) {
      setTagCalls.add((event.id, event.tag));
    }
    _events[event.id] = event;
    _emit();
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    _events.remove(eventId);
    _emit();
  }
}

class _FakeTagRoutingRepository implements TagRoutingRepository {
  final _controller = StreamController<TagRoutingSettings>.broadcast();
  TagRoutingSettings _current = const TagRoutingSettings();

  void seed(TagRoutingSettings settings) {
    _current = settings;
    _controller.add(settings);
  }

  @override
  Stream<TagRoutingSettings> watchSettings() {
    late StreamController<TagRoutingSettings> perListener;
    StreamSubscription<TagRoutingSettings>? upstream;
    perListener = StreamController<TagRoutingSettings>(
      onListen: () {
        perListener.add(_current);
        upstream = _controller.stream.listen(perListener.add);
      },
      onCancel: () => upstream?.cancel(),
    );
    return perListener.stream;
  }

  @override
  Future<void> updateSettings(TagRoutingSettings settings) async {
    seed(settings);
  }
}

CalendarEvent _event({
  String id = 'e1',
  String title = 'Standup',
  String? tag,
  EventStatus status = EventStatus.active,
}) {
  final now = DateTime.utc(2026);
  return CalendarEvent(
    id: id,
    title: title,
    tag: tag,
    status: status,
    start: now,
    end: now.add(const Duration(hours: 1)),
    source: EventSource.manual,
  );
}

void main() {
  test('assigns a tag to a matching untagged event once auto-tagging is enabled', () async {
    final events = _FakeEventRepository();
    final routing = _FakeTagRoutingRepository();
    final reconciler = TagRoutingReconciler(events: events, routing: routing);

    routing.seed(TagRoutingSettings(
      autoTagEnabled: true,
      tagRules: [
        const TagRule(field: RuleField.title, operator: RuleOperator.contains, value: 'standup', tag: 'work'),
      ],
    ));
    events.seed(_event());
    reconciler.start();
    await Future<void>.delayed(Duration.zero);

    expect(events.setTagCalls, [('e1', 'work')]);
  });

  test('does nothing while auto-tagging is disabled', () async {
    final events = _FakeEventRepository();
    final routing = _FakeTagRoutingRepository();
    final reconciler = TagRoutingReconciler(events: events, routing: routing);

    routing.seed(TagRoutingSettings(
      autoTagEnabled: false,
      tagRules: [
        const TagRule(field: RuleField.title, operator: RuleOperator.contains, value: 'standup', tag: 'work'),
      ],
    ));
    events.seed(_event());
    reconciler.start();
    await Future<void>.delayed(Duration.zero);

    expect(events.setTagCalls, isEmpty);
  });

  test('never re-tags an event that already has a tag (user override is permanent)', () async {
    final events = _FakeEventRepository();
    final routing = _FakeTagRoutingRepository();
    final reconciler = TagRoutingReconciler(events: events, routing: routing);

    routing.seed(TagRoutingSettings(
      autoTagEnabled: true,
      tagRules: [
        const TagRule(field: RuleField.title, operator: RuleOperator.contains, value: 'standup', tag: 'work'),
      ],
    ));
    // The user already tagged this event manually with something the rule
    // would NOT have chosen -- the reconciler must leave it alone.
    events.seed(_event(tag: 'personal'));
    reconciler.start();
    await Future<void>.delayed(Duration.zero);

    expect(events.setTagCalls, isEmpty);
  });

  test('skips pending_conflict events', () async {
    final events = _FakeEventRepository();
    final routing = _FakeTagRoutingRepository();
    final reconciler = TagRoutingReconciler(events: events, routing: routing);

    routing.seed(TagRoutingSettings(
      autoTagEnabled: true,
      tagRules: [
        const TagRule(field: RuleField.title, operator: RuleOperator.contains, value: 'standup', tag: 'work'),
      ],
    ));
    events.seed(_event(status: EventStatus.pendingConflict));
    reconciler.start();
    await Future<void>.delayed(Duration.zero);

    expect(events.setTagCalls, isEmpty);
  });

  test('a newly added rule is applied to an existing untagged event once settings change', () async {
    final events = _FakeEventRepository();
    final routing = _FakeTagRoutingRepository();
    final reconciler = TagRoutingReconciler(events: events, routing: routing);

    routing.seed(const TagRoutingSettings(autoTagEnabled: true, tagRules: []));
    events.seed(_event());
    reconciler.start();
    await Future<void>.delayed(Duration.zero);
    expect(events.setTagCalls, isEmpty);

    routing.seed(TagRoutingSettings(
      autoTagEnabled: true,
      tagRules: [
        const TagRule(field: RuleField.title, operator: RuleOperator.contains, value: 'standup', tag: 'work'),
      ],
    ));
    await Future<void>.delayed(Duration.zero);

    expect(events.setTagCalls, [('e1', 'work')]);
  });

  test('stop() prevents further reconciliation', () async {
    final events = _FakeEventRepository();
    final routing = _FakeTagRoutingRepository();
    final reconciler = TagRoutingReconciler(events: events, routing: routing);

    routing.seed(TagRoutingSettings(
      autoTagEnabled: true,
      tagRules: [
        const TagRule(field: RuleField.title, operator: RuleOperator.contains, value: 'standup', tag: 'work'),
      ],
    ));
    reconciler.start();
    await reconciler.stop();
    events.seed(_event());
    await Future<void>.delayed(Duration.zero);

    expect(events.setTagCalls, isEmpty);
  });
}
