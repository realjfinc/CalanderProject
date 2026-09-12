import '../models/calendar_event.dart';

/// Access to a user's events for tag routing: reading them (to find
/// untagged ones, and to evaluate rules) and assigning a tag.
///
/// [setEventTag] is deliberately the ONLY write this interface exposes —
/// per the hard contract, only direct user action or the tag-routing logic
/// in this step may ever assign an event's `tag` field, and neither needs
/// (or should have) a general-purpose "update the whole event" method to
/// do that.
abstract class EventRepository {
  Stream<List<CalendarEvent>> watchEvents();

  Future<void> setEventTag(String eventId, String? tag);
}
