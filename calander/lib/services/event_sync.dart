import '../models/calendar_event.dart';
import 'event_repository.dart';

/// The one shared place dedup and cross-source conflict detection happen,
/// so no provider adapter has to (or gets to) implement this itself.
///
/// Call this once per event a provider adapter fetches, passing the
/// current snapshot of the user's events (so repeated calls in one sync
/// pass see each other's effects without re-querying Firestore every
/// time — see `syncProvider` in `provider_sync.dart`, which keeps that
/// snapshot updated using this function's return value).
///
/// [incoming] must have `tag == null` and `status == EventStatus.active` —
/// those are exactly the two fields this function (and provider adapters)
/// must never be the one to set to anything else; asserting it here keeps
/// that invariant enforced at the one chokepoint everything funnels
/// through, not just by convention in each adapter.
///
/// Returns the event as it now exists in the repository (with its real
/// id), so a caller processing several incoming events in one pass can
/// fold it into its own snapshot for the next call.
Future<CalendarEvent> ingestProviderEvent({
  required EventRepository repository,
  required CalendarEvent incoming,
  required List<CalendarEvent> currentEvents,
}) async {
  assert(incoming.tag == null, 'A provider adapter must never set tag.');
  assert(incoming.status == EventStatus.active, 'An incoming event starts out active.');

  // 1. Dedup: (source, sourceId) identifies "the same provider event" no
  // matter how its content changed since the last sync.
  CalendarEvent? existingBySourceId;
  for (final event in currentEvents) {
    if (event.source == incoming.source && event.sourceId == incoming.sourceId) {
      existingBySourceId = event;
      break;
    }
  }

  if (existingBySourceId != null) {
    final updated = incoming.copyWith(
      id: existingBySourceId.id,
      // Never overwrite tag or an existing conflict with the provider's
      // (always-null/always-active) values.
      tag: existingBySourceId.tag,
      status: existingBySourceId.status,
      conflictGroupId: existingBySourceId.conflictGroupId,
    );
    await repository.updateEvent(updated);
    return updated;
  }

  // 2. Cross-source conflict: an active event from a DIFFERENT source with
  // a similar title and a close start time. Never auto-merge or overwrite
  // it -- both sides become pendingConflict, linked so the resolution UI
  // can offer Keep original / Keep new / Keep both.
  CalendarEvent? conflictingEvent;
  for (final event in currentEvents) {
    if (event.source != incoming.source &&
        event.status == EventStatus.active &&
        _looksLikeTheSameEvent(event, incoming)) {
      conflictingEvent = event;
      break;
    }
  }

  if (conflictingEvent != null) {
    final conflictGroupId = '${conflictingEvent.id}-${incoming.source.name}-${incoming.sourceId}';
    await repository.updateEvent(
      conflictingEvent.copyWith(
        status: EventStatus.pendingConflict,
        conflictGroupId: conflictGroupId,
        conflictRole: 'original',
      ),
    );
    final newEvent = incoming.copyWith(
      status: EventStatus.pendingConflict,
      conflictGroupId: conflictGroupId,
      conflictRole: 'new',
    );
    final newId = await repository.addEvent(newEvent);
    return newEvent.copyWith(id: newId);
  }

  // 3. Neither: a genuinely new event.
  final newId = await repository.addEvent(incoming);
  return incoming.copyWith(id: newId);
}

const _titleMatchThreshold = Duration(minutes: 15);

bool _looksLikeTheSameEvent(CalendarEvent a, CalendarEvent b) {
  final sameTitle = a.title.trim().toLowerCase() == b.title.trim().toLowerCase();
  if (!sameTitle || a.title.trim().isEmpty) return false;

  final startDelta = a.start.difference(b.start).abs();
  return startDelta <= _titleMatchThreshold;
}
