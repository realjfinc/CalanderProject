import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/conflict_resolver.dart';
import 'package:calander/services/event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEventRepository implements EventRepository {
  final Map<String, CalendarEvent> events = {};

  @override
  Stream<List<CalendarEvent>> watchEvents() => Stream.value(events.values.toList());

  @override
  Future<String> addEvent(CalendarEvent event) async {
    events[event.id] = event;
    return event.id;
  }

  @override
  Future<void> updateEvent(CalendarEvent event) async {
    events[event.id] = event;
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    events.remove(eventId);
  }
}

CalendarEvent _conflictEvent({
  required String id,
  required EventSource source,
  required String conflictRole,
  String conflictGroupId = 'group-1',
}) {
  final start = DateTime.utc(2026, 3, 1, 10);
  return CalendarEvent(
    id: id,
    title: 'Team Sync',
    start: start,
    end: start.add(const Duration(hours: 1)),
    source: source,
    sourceId: '$source-id',
    status: EventStatus.pendingConflict,
    conflictGroupId: conflictGroupId,
    conflictRole: conflictRole,
  );
}

void main() {
  group('groupConflicts', () {
    test('pairs up an original and a new event sharing a conflictGroupId', () {
      final original = _conflictEvent(id: 'o', source: EventSource.outlook, conflictRole: 'original');
      final newEvent = _conflictEvent(id: 'n', source: EventSource.google, conflictRole: 'new');

      final pairs = groupConflicts([original, newEvent]);

      expect(pairs, hasLength(1));
      expect(pairs.single.original.id, 'o');
      expect(pairs.single.newEvent.id, 'n');
    });

    test('ignores active events entirely', () {
      final active = CalendarEvent(
        id: 'a',
        title: 'Not a conflict',
        start: DateTime.utc(2026),
        end: DateTime.utc(2026, 1, 1, 1),
        source: EventSource.manual,
      );
      expect(groupConflicts([active]), isEmpty);
    });

    test('ignores a group missing its "new" half', () {
      final original = _conflictEvent(id: 'o', source: EventSource.outlook, conflictRole: 'original');
      expect(groupConflicts([original]), isEmpty);
    });

    test('ignores a malformed group with more than two members', () {
      final a = _conflictEvent(id: 'a', source: EventSource.outlook, conflictRole: 'original');
      final b = _conflictEvent(id: 'b', source: EventSource.google, conflictRole: 'new');
      final c = _conflictEvent(id: 'c', source: EventSource.icloud, conflictRole: 'new');
      expect(groupConflicts([a, b, c]), isEmpty);
    });

    test('keeps separate conflict groups separate', () {
      final o1 = _conflictEvent(id: 'o1', source: EventSource.outlook, conflictRole: 'original', conflictGroupId: 'g1');
      final n1 = _conflictEvent(id: 'n1', source: EventSource.google, conflictRole: 'new', conflictGroupId: 'g1');
      final o2 = _conflictEvent(id: 'o2', source: EventSource.outlook, conflictRole: 'original', conflictGroupId: 'g2');
      final n2 = _conflictEvent(id: 'n2', source: EventSource.icloud, conflictRole: 'new', conflictGroupId: 'g2');

      final pairs = groupConflicts([o1, n1, o2, n2]);
      expect(pairs, hasLength(2));
    });
  });

  group('resolveConflict', () {
    test('keepOriginal reactivates the original and deletes the new event', () async {
      final repo = _FakeEventRepository();
      final original = _conflictEvent(id: 'o', source: EventSource.outlook, conflictRole: 'original');
      final newEvent = _conflictEvent(id: 'n', source: EventSource.google, conflictRole: 'new');
      repo.events.addAll({'o': original, 'n': newEvent});

      await resolveConflict(
        repository: repo,
        original: original,
        newEvent: newEvent,
        resolution: ConflictResolution.keepOriginal,
      );

      expect(repo.events.containsKey('n'), isFalse);
      final kept = repo.events['o']!;
      expect(kept.status, EventStatus.active);
      expect(kept.conflictGroupId, isNull);
      expect(kept.conflictRole, isNull);
    });

    test('keepNew reactivates the new event and deletes the original', () async {
      final repo = _FakeEventRepository();
      final original = _conflictEvent(id: 'o', source: EventSource.outlook, conflictRole: 'original');
      final newEvent = _conflictEvent(id: 'n', source: EventSource.google, conflictRole: 'new');
      repo.events.addAll({'o': original, 'n': newEvent});

      await resolveConflict(
        repository: repo,
        original: original,
        newEvent: newEvent,
        resolution: ConflictResolution.keepNew,
      );

      expect(repo.events.containsKey('o'), isFalse);
      final kept = repo.events['n']!;
      expect(kept.status, EventStatus.active);
      expect(kept.conflictGroupId, isNull);
    });

    test('keepBoth reactivates both and deletes neither -- no automatic merge', () async {
      final repo = _FakeEventRepository();
      final original = _conflictEvent(id: 'o', source: EventSource.outlook, conflictRole: 'original');
      final newEvent = _conflictEvent(id: 'n', source: EventSource.google, conflictRole: 'new');
      repo.events.addAll({'o': original, 'n': newEvent});

      await resolveConflict(
        repository: repo,
        original: original,
        newEvent: newEvent,
        resolution: ConflictResolution.keepBoth,
      );

      expect(repo.events.containsKey('o'), isTrue);
      expect(repo.events.containsKey('n'), isTrue);
      expect(repo.events['o']!.status, EventStatus.active);
      expect(repo.events['n']!.status, EventStatus.active);
      // Still two distinct events with their own original fields -- nothing
      // was combined into one.
      expect(repo.events['o']!.source, EventSource.outlook);
      expect(repo.events['n']!.source, EventSource.google);
    });
  });
}
