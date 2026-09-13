import type { CanonicalEvent, CanonicalEventData } from "./canonicalEvent";
import type { EventRepository } from "./eventRepository";

/**
 * Server-side port of the Flutter client's `ingestProviderEvent`
 * (`lib/services/event_sync.dart`) -- the one place dedup and cross-source
 * conflict detection happen. Kept field-for-field identical so a Firestore
 * document produced by a scheduled poll here is indistinguishable from one
 * produced by a client-side provider sync: same `(source, sourceId)` dedup
 * key, same conflict fields, same rule that a source adapter (this poller
 * included) never writes `tag`.
 *
 * Call once per event a source fetches, passing the current snapshot of
 * the user's events so repeated calls within one poll pass see each
 * other's effects without re-querying Firestore every time (see
 * `pollUpcomingGames.ts`, which folds each call's result back into its own
 * snapshot for the next call).
 */
export async function ingestProviderEvent({
  repository,
  incoming,
  currentEvents,
}: {
  repository: EventRepository;
  incoming: CanonicalEventData;
  currentEvents: CanonicalEvent[];
}): Promise<CanonicalEvent> {
  if (incoming.tag !== null) {
    throw new Error("A source adapter must never set tag.");
  }
  if (incoming.status !== "active") {
    throw new Error("An incoming event starts out active.");
  }

  // 1. Dedup: (source, sourceId) identifies "the same source event" no
  // matter how its content changed since the last poll.
  const existingBySourceId = currentEvents.find(
    (event) => event.source === incoming.source && event.sourceId === incoming.sourceId,
  );

  if (existingBySourceId) {
    const updated: CanonicalEvent = {
      ...incoming,
      id: existingBySourceId.id,
      // Never overwrite tag or an existing conflict with the source's
      // (always-null/always-active) values.
      tag: existingBySourceId.tag,
      status: existingBySourceId.status,
      conflictGroupId: existingBySourceId.conflictGroupId,
      conflictRole: existingBySourceId.conflictRole,
    };
    await repository.updateEvent(updated);
    return updated;
  }

  // 2. Cross-source conflict: an active event from a DIFFERENT source with
  // a similar title and a close start time. Never auto-merge or overwrite
  // it -- both sides become pendingConflict, linked so a resolution UI can
  // offer Keep original / Keep new / Keep both (see Step 6).
  const conflictingEvent = currentEvents.find(
    (event) =>
      event.source !== incoming.source &&
      event.status === "active" &&
      looksLikeTheSameEvent(event, incoming),
  );

  if (conflictingEvent) {
    const conflictGroupId = `${conflictingEvent.id}-${incoming.source}-${incoming.sourceId}`;
    await repository.updateEvent({
      ...conflictingEvent,
      status: "pendingConflict",
      conflictGroupId,
      conflictRole: "original",
    });
    const newId = await repository.addEvent({
      ...incoming,
      status: "pendingConflict",
      conflictGroupId,
      conflictRole: "new",
    });
    return {
      ...incoming,
      id: newId,
      status: "pendingConflict",
      conflictGroupId,
      conflictRole: "new",
    };
  }

  // 3. Neither: a genuinely new event.
  const newId = await repository.addEvent(incoming);
  return { ...incoming, id: newId };
}

const TITLE_MATCH_THRESHOLD_MS = 15 * 60 * 1000;

function looksLikeTheSameEvent(
  a: Pick<CanonicalEvent, "title" | "start">,
  b: Pick<CanonicalEventData, "title" | "start">,
): boolean {
  const titleA = a.title.trim().toLowerCase();
  const titleB = b.title.trim().toLowerCase();
  if (titleA !== titleB || titleA === "") return false;

  const startDelta = Math.abs(new Date(a.start).getTime() - new Date(b.start).getTime());
  return startDelta <= TITLE_MATCH_THRESHOLD_MS;
}
