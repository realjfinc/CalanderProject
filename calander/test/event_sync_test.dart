import 'dart:async';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/event_repository.dart';
import 'package:calander/services/event_sync.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEventRepository implements EventRepository {
  final Map<String, CalendarEvent> _events = {};
  int _nextId = 0;
  final List<CalendarEvent> addedEvents = [];
  final List<CalendarEvent> updatedEvents = [];

  @override
  Stream<List<CalendarEvent>> watchEvents() => Stream.value(_events.values.toList());

  @override
  Future<String> addEvent(CalendarEvent event) async {
    final id = 'gen-${_nextId++}';
    final stored = event.copyWith(id: id);
    _events[id] = stored;
    addedEvents.add(stored);
    return id;
  }

  @override
  Future<void> updateEvent(CalendarEvent event) async {
    _events[event.id] = event;
    updatedEvents.add(event);
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    _events.remove(eventId);
  }
}

CalendarEvent _incoming({
  String title = 'Team Sync',
  String sourceId = 'g-1',
  EventSource source = EventSource.google,
  DateTime? start,
}) {
  final s = start ?? DateTime.utc(2026, 3, 1, 10);
  return CalendarEvent(
    id: '',
    title: title,
    start: s,
    end: s.add(const Duration(hours: 1)),
    source: source,
    sourceId: sourceId,
  );
}

void main() {
  test('inserts a genuinely new event as active with no conflict', () async {
    final repo = _FakeEventRepository();
    final result = await ingestProviderEvent(repository: repo, incoming: _incoming(), currentEvents: []);

    expect(result.status, EventStatus.active);
    expect(result.tag, isNull);
    expect(repo.addedEvents, hasLength(1));
    expect(repo.updatedEvents, isEmpty);
  });

  test('dedups by (source, sourceId): a second sync of the same provider event updates, not duplicates', () async {
    final repo = _FakeEventRepository();
    final first = await ingestProviderEvent(repository: repo, incoming: _incoming(), currentEvents: []);

    final second = await ingestProviderEvent(
      repository: repo,
      incoming: _incoming(title: 'Team Sync (renamed)'),
      currentEvents: [first],
    );

    expect(second.id, first.id);
    expect(second.title, 'Team Sync (renamed)');
    expect(repo.addedEvents, hasLength(1)); // still only the one insert
    expect(repo.updatedEvents, hasLength(1));
  });

  test('a resync never overwrites an existing tag with the provider\'s (always-null) one', () async {
    final repo = _FakeEventRepository();
    final existing = CalendarEvent(
      id: 'e1',
      title: 'Team Sync',
      start: DateTime.utc(2026, 3, 1, 10),
      end: DateTime.utc(2026, 3, 1, 11),
      source: EventSource.google,
      sourceId: 'g-1',
      tag: 'work',
    );

    final result = await ingestProviderEvent(
      repository: repo,
      incoming: _incoming(),
      currentEvents: [existing],
    );

    expect(result.tag, 'work');
  });

  test('a resync preserves an existing pendingConflict status rather than reverting it to active', () async {
    final repo = _FakeEventRepository();
    final existing = CalendarEvent(
      id: 'e1',
      title: 'Team Sync',
      start: DateTime.utc(2026, 3, 1, 10),
      end: DateTime.utc(2026, 3, 1, 11),
      source: EventSource.google,
      sourceId: 'g-1',
      status: EventStatus.pendingConflict,
      conflictGroupId: 'group-1',
    );

    final result = await ingestProviderEvent(
      repository: repo,
      incoming: _incoming(),
      currentEvents: [existing],
    );

    expect(result.status, EventStatus.pendingConflict);
    expect(result.conflictGroupId, 'group-1');
  });

  test('detects a cross-source conflict: similar title + close start time from a different source', () async {
    final repo = _FakeEventRepository();
    final existingFromOutlook = CalendarEvent(
      id: 'e1',
      title: 'Team Sync',
      start: DateTime.utc(2026, 3, 1, 10),
      end: DateTime.utc(2026, 3, 1, 11),
      source: EventSource.outlook,
      sourceId: 'o-1',
    );

    final result = await ingestProviderEvent(
      repository: repo,
      incoming: _incoming(source: EventSource.google, sourceId: 'g-1'),
      currentEvents: [existingFromOutlook],
    );

    expect(result.status, EventStatus.pendingConflict);
    expect(result.conflictRole, 'new');
    expect(repo.updatedEvents, hasLength(1));
    expect(repo.updatedEvents.single.id, 'e1');
    expect(repo.updatedEvents.single.status, EventStatus.pendingConflict);
    expect(repo.updatedEvents.single.conflictRole, 'original');
    expect(repo.updatedEvents.single.conflictGroupId, result.conflictGroupId);
    expect(repo.updatedEvents.single.title, 'Team Sync'); // never overwritten -- no auto-merge
  });

  test('does not treat two events from the SAME source as a conflict', () async {
    final repo = _FakeEventRepository();
    final existing = CalendarEvent(
      id: 'e1',
      title: 'Team Sync',
      start: DateTime.utc(2026, 3, 1, 10),
      end: DateTime.utc(2026, 3, 1, 11),
      source: EventSource.google,
      sourceId: 'g-OTHER', // different sourceId -- would only dedup-match on identical sourceId
    );

    final result = await ingestProviderEvent(
      repository: repo,
      incoming: _incoming(source: EventSource.google, sourceId: 'g-1'),
      currentEvents: [existing],
    );

    expect(result.status, EventStatus.active);
  });

  test('does not flag a conflict for a dissimilar title', () async {
    final repo = _FakeEventRepository();
    final existing = CalendarEvent(
      id: 'e1',
      title: 'Completely Different Meeting',
      start: DateTime.utc(2026, 3, 1, 10),
      end: DateTime.utc(2026, 3, 1, 11),
      source: EventSource.outlook,
      sourceId: 'o-1',
    );

    final result = await ingestProviderEvent(
      repository: repo,
      incoming: _incoming(),
      currentEvents: [existing],
    );

    expect(result.status, EventStatus.active);
  });

  test('does not flag a conflict when start times are far apart', () async {
    final repo = _FakeEventRepository();
    final existing = CalendarEvent(
      id: 'e1',
      title: 'Team Sync',
      start: DateTime.utc(2026, 3, 1, 14), // 4 hours later
      end: DateTime.utc(2026, 3, 1, 15),
      source: EventSource.outlook,
      sourceId: 'o-1',
    );

    final result = await ingestProviderEvent(
      repository: repo,
      incoming: _incoming(),
      currentEvents: [existing],
    );

    expect(result.status, EventStatus.active);
  });

  test('does not flag a conflict against an already-pendingConflict event', () async {
    final repo = _FakeEventRepository();
    final existing = CalendarEvent(
      id: 'e1',
      title: 'Team Sync',
      start: DateTime.utc(2026, 3, 1, 10),
      end: DateTime.utc(2026, 3, 1, 11),
      source: EventSource.outlook,
      sourceId: 'o-1',
      status: EventStatus.pendingConflict,
      conflictGroupId: 'other-group',
    );

    final result = await ingestProviderEvent(
      repository: repo,
      incoming: _incoming(),
      currentEvents: [existing],
    );

    expect(result.status, EventStatus.active); // a fresh, unrelated event, not folded into someone else's conflict
  });

  test('asserts if given an incoming event that already has a tag', () async {
    final repo = _FakeEventRepository();
    expect(
      () => ingestProviderEvent(
        repository: repo,
        incoming: _incoming().copyWith(tag: 'should-not-happen'),
        currentEvents: [],
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
