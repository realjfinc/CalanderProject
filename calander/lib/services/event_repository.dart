import '../models/calendar_event.dart';

/// Write access to a user's events, for features that create events (like
/// upload extraction) without owning the full event-management surface.
///
/// Event editing/deletion/listing UI is out of scope here — this
/// intentionally exposes only what Step 3 needs: saving a
/// user-confirmed event.
abstract class EventRepository {
  /// Saves a new event and returns its generated id.
  Future<String> addEvent(CalendarEvent event);
}
