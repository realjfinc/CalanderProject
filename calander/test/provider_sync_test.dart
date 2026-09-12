import 'package:calander/models/calendar_event.dart';
import 'package:calander/services/event_repository.dart';
import 'package:calander/services/provider_adapter.dart';
import 'package:calander/services/provider_sync.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements ProviderAdapter {
  _FakeAdapter(this.events);
  final List<CalendarEvent> events;
  @override
  EventSource get source => EventSource.google;

  @override
  Future<List<CalendarEvent>> fetchEvents() async => events;
}

class _FakeEventRepository implements EventRepository {
  final Map<String, CalendarEvent> _events = {};
  int _nextId = 0;

  @override
  Stream<List<CalendarEvent>> watchEvents() => Stream.value(_events.values.toList());

  @override
  Future<String> addEvent(CalendarEvent event) async {
    final id = 'gen-${_nextId++}';
    _events[id] = event.copyWith(id: id);
    return id;
  }

  @override
  Future<void> updateEvent(CalendarEvent event) async {
    _events[event.id] = event;
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    _events.remove(eventId);
  }
}

CalendarEvent _googleEvent(String sourceId, {String title = 'Standup'}) {
  final start = DateTime.utc(2026, 3, 1, 10);
  return CalendarEvent(
    id: '',
    title: title,
    start: start,
    end: start.add(const Duration(minutes: 30)),
    source: EventSource.google,
    sourceId: sourceId,
  );
}

void main() {
  test('syncProvider ingests every event the adapter returns', () async {
    final repo = _FakeEventRepository();
    final adapter = _FakeAdapter([_googleEvent('g-1'), _googleEvent('g-2', title: 'Retro')]);

    await syncProvider(adapter: adapter, repository: repo);

    final events = await repo.watchEvents().first;
    expect(events, hasLength(2));
    expect(events.map((e) => e.sourceId), containsAll(['g-1', 'g-2']));
  });

  test('a second sync pass updates rather than duplicates', () async {
    final repo = _FakeEventRepository();
    await syncProvider(adapter: _FakeAdapter([_googleEvent('g-1')]), repository: repo);

    await syncProvider(adapter: _FakeAdapter([_googleEvent('g-1', title: 'Standup (renamed)')]), repository: repo);

    final events = await repo.watchEvents().first;
    expect(events, hasLength(1));
    expect(events.single.title, 'Standup (renamed)');
  });

  test('later events in the same pass see earlier ones\' effects (no false conflicts within one batch)', () async {
    final repo = _FakeEventRepository();
    // Two events from the SAME provider batch that happen to share a title
    // and time must not be treated as conflicting with each other -- only
    // cross-source pairs are conflicts, and this stays true across the
    // whole pass because syncProvider keeps its local snapshot updated.
    final start = DateTime.utc(2026, 3, 1, 10);
    final event1 = CalendarEvent(
      id: '',
      title: 'Standup',
      start: start,
      end: start.add(const Duration(minutes: 30)),
      source: EventSource.google,
      sourceId: 'g-1',
    );
    final event2 = CalendarEvent(
      id: '',
      title: 'Standup',
      start: start,
      end: start.add(const Duration(minutes: 30)),
      source: EventSource.google,
      sourceId: 'g-2',
    );

    await syncProvider(adapter: _FakeAdapter([event1, event2]), repository: repo);

    final events = await repo.watchEvents().first;
    expect(events, hasLength(2));
    expect(events.every((e) => e.status == EventStatus.active), isTrue);
  });
}
