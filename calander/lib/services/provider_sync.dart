import '../models/calendar_event.dart';
import 'event_repository.dart';
import 'event_sync.dart';
import 'provider_adapter.dart';

/// Runs one full sync pass for a single provider: fetches its current
/// events and feeds each through the shared dedup/conflict utility.
///
/// Keeps a local, mutable snapshot of events (seeded from the repository
/// once) updated with each [ingestProviderEvent] result as it goes, so
/// later events in the same pass see earlier ones' effects without an
/// extra Firestore round-trip per event.
Future<void> syncProvider({required ProviderAdapter adapter, required EventRepository repository}) async {
  await ingestProviderEvents(incomingEvents: await adapter.fetchEvents(), repository: repository);
}

/// The shared loop body [syncProvider] runs per incoming event, pulled out
/// so a caller that already has a list of incoming events in hand (not
/// behind a [ProviderAdapter]'s `fetchEvents()` -- see
/// `sports_games_backfill.dart`, which reads them from a Firestore cache
/// instead of a live API call) can reuse it without re-fetching.
Future<void> ingestProviderEvents({
  required List<CalendarEvent> incomingEvents,
  required EventRepository repository,
}) async {
  final currentEvents = List<CalendarEvent>.of(await repository.watchEvents().first);

  for (final incoming in incomingEvents) {
    final result = await ingestProviderEvent(
      repository: repository,
      incoming: incoming,
      currentEvents: currentEvents,
    );
    final existingIndex = currentEvents.indexWhere((e) => e.id == result.id);
    if (existingIndex == -1) {
      currentEvents.add(result);
    } else {
      currentEvents[existingIndex] = result;
    }
  }
}
