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
  final incomingEvents = await adapter.fetchEvents();
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
