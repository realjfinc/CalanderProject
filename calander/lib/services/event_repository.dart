import '../models/calendar_event.dart';

/// Read access to a user's events, for features (like reminder scheduling)
/// that need to react to event data without owning event creation/editing.
///
/// Event creation/editing UI is out of scope here (owned by Jonathan, or by
/// whichever later step introduces it — upload extraction, provider sync,
/// sports mode, etc.), so this intentionally exposes no write methods.
abstract class EventRepository {
  /// Streams every event for the current user, most recently changed first
  /// is not guaranteed — callers should not assume ordering.
  Stream<List<CalendarEvent>> watchEvents();
}
