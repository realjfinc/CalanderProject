import '../models/calendar_event.dart';
import 'event_repository.dart';

/// The three choices the roadmap's conflict-resolution UI offers. Never
/// auto-merges: each choice keeps one or both sides exactly as they are,
/// just clearing `pendingConflict`.
enum ConflictResolution { keepOriginal, keepNew, keepBoth }

/// Applies the user's choice for one conflict (a pair of events sharing a
/// `conflictGroupId`, one `conflictRole: 'original'` and one `'new'`).
Future<void> resolveConflict({
  required EventRepository repository,
  required CalendarEvent original,
  required CalendarEvent newEvent,
  required ConflictResolution resolution,
}) async {
  switch (resolution) {
    case ConflictResolution.keepOriginal:
      await repository.updateEvent(
        original.copyWith(status: EventStatus.active, conflictGroupId: null, conflictRole: null),
      );
      await repository.deleteEvent(newEvent.id);

    case ConflictResolution.keepNew:
      await repository.updateEvent(
        newEvent.copyWith(status: EventStatus.active, conflictGroupId: null, conflictRole: null),
      );
      await repository.deleteEvent(original.id);

    case ConflictResolution.keepBoth:
      await repository.updateEvent(
        original.copyWith(status: EventStatus.active, conflictGroupId: null, conflictRole: null),
      );
      await repository.updateEvent(
        newEvent.copyWith(status: EventStatus.active, conflictGroupId: null, conflictRole: null),
      );
  }
}

/// Groups a list of events' `pendingConflict` entries into resolvable
/// pairs, one per `conflictGroupId`. Ignores anything malformed (a group
/// missing either role, or with more than two members) rather than
/// guessing — that shouldn't happen given how `event_sync.dart` creates
/// these groups, but a resolution UI silently mismatching two unrelated
/// events would be worse than just not showing a broken group.
List<ConflictPair> groupConflicts(List<CalendarEvent> events) {
  final byGroup = <String, List<CalendarEvent>>{};
  for (final event in events) {
    final groupId = event.conflictGroupId;
    if (event.status != EventStatus.pendingConflict || groupId == null) continue;
    byGroup.putIfAbsent(groupId, () => []).add(event);
  }

  final pairs = <ConflictPair>[];
  for (final group in byGroup.values) {
    if (group.length != 2) continue;
    final original = group.where((e) => e.conflictRole == 'original').toList();
    final newEvents = group.where((e) => e.conflictRole == 'new').toList();
    if (original.length != 1 || newEvents.length != 1) continue;
    pairs.add(ConflictPair(original: original.single, newEvent: newEvents.single));
  }
  return pairs;
}

class ConflictPair {
  const ConflictPair({required this.original, required this.newEvent});
  final CalendarEvent original;
  final CalendarEvent newEvent;
}
