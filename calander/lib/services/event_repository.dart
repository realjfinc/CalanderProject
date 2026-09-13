import '../models/calendar_event.dart';

/// Access to a user's events for provider sync: reading them (to dedup and
/// detect conflicts against), inserting a new one, and updating an existing
/// one in place.
///
/// There's no field-locked "setTag"-only method here like Step 5's — sync
/// genuinely needs to update several fields (status, times, conflict
/// linkage) as a provider's copy of an event changes. The "no source
/// adapter may write tag" rule is instead a discipline enforced by the
/// dedup/conflict utility in `event_sync.dart`, which is the only code that
/// calls [updateEvent] from a sync path and always carries the existing
/// event's `tag` forward untouched — never the incoming provider event's
/// (which is always null; see [ProviderAdapter]).
abstract class EventRepository {
  Stream<List<CalendarEvent>> watchEvents();

  Future<String> addEvent(CalendarEvent event);

  Future<void> updateEvent(CalendarEvent event);

  /// Used only by conflict resolution, to discard whichever side of a
  /// conflict the user didn't choose to keep (see `conflict_resolver.dart`).
  Future<void> deleteEvent(String eventId);
}

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

/// Calendar editing and sync metadata, in addition to the provider contract.
abstract class CalendarEventRepository implements EventRepository {
  Stream<EventSnapshot> watchSnapshots();
  String newId();
  Future<void> save(CalendarEvent event, {required bool isNew});
  Future<void> delete(String id);
}
