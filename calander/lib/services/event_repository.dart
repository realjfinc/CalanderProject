import '../models/calendar_event.dart';

/// Access to a user's events for provider/source sync: reading them (to
/// dedup and detect conflicts against), inserting a new one, and updating
/// an existing one in place.
///
/// The "no source adapter may write tag" rule is a discipline enforced by
/// the dedup/conflict utility in `event_sync.dart`, which is the only code
/// that calls [updateEvent] from a sync path and always carries the
/// existing event's `tag` forward untouched — never the incoming source
/// event's (which is always null; see [ProviderAdapter]).
abstract class EventRepository {
  Stream<List<CalendarEvent>> watchEvents();

  Future<String> addEvent(CalendarEvent event);

  Future<void> updateEvent(CalendarEvent event);

  Future<void> deleteEvent(String eventId);
}
