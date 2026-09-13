import '../models/calendar_event.dart';

class EventSnapshot {
  const EventSnapshot(
    this.events, {
    this.fromCache = false,
    this.pending = false,
  });
  final List<CalendarEvent> events;
  final bool fromCache;
  final bool pending;
}

abstract class EventRepository {
  Stream<EventSnapshot> watchEvents();
  String newId();
  Future<void> save(CalendarEvent event, {required bool isNew});
  Future<void> delete(String id);
}
