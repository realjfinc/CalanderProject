import '../models/calendar_event.dart';

/// A source of events from an external calendar provider.
///
/// Every implementation must, per the hard contract:
/// - use the provider's own event id as `sourceId`
/// - normalize timestamps to UTC before returning
/// - leave `tag` null (only direct user action or Step 5's routing logic
///   may ever assign it)
/// - leave `status` as `active` — [ProviderAdapter] implementations don't
///   decide conflicts; `ingestProviderEvent` (see `event_sync.dart`) does
abstract class ProviderAdapter {
  EventSource get source;

  Future<List<CalendarEvent>> fetchEvents();
}
