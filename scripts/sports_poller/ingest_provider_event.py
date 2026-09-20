"""Python port of the shared dedup/conflict utility -- the same logic as
`calander/lib/services/event_sync.dart` (Dart) and
`functions/src/shared/ingestProviderEvent.ts` (the Cloud Function's TS
port), kept field-for-field identical so a game this poller ingests is
indistinguishable from one synced by the client or the scheduled Cloud
Function: same `(source, sourceId)` dedup key, same conflict fields, same
rule that a source adapter (this poller included) never writes `tag`.

Call once per event a source fetches, passing the current snapshot of the
user's events so repeated calls within one poll pass see each other's
effects without re-querying Firestore every time (see `poll_sports_events.py`,
which folds each call's result back into its own snapshot for the next
call).
"""

from __future__ import annotations

from dataclasses import replace
from datetime import datetime
from typing import Optional

from canonical_event import CanonicalEvent, CanonicalEventData
from event_repository import EventRepository

_TITLE_MATCH_THRESHOLD_SECONDS = 15 * 60


def _as_event(data: CanonicalEventData, event_id: str, **overrides) -> CanonicalEvent:
    fields = {**vars(data), **overrides, "id": event_id}
    return CanonicalEvent(**fields)


def ingest_provider_event(
    *,
    repository: EventRepository,
    incoming: CanonicalEventData,
    current_events: list[CanonicalEvent],
) -> CanonicalEvent:
    if incoming.tag is not None:
        raise ValueError("A source adapter must never set tag.")
    if incoming.status != "active":
        raise ValueError("An incoming event starts out active.")

    # 1. Dedup: (source, sourceId) identifies "the same source event" no
    # matter how its content changed since the last poll.
    existing_by_source_id = next(
        (
            event
            for event in current_events
            if event.source == incoming.source and event.source_id == incoming.source_id
        ),
        None,
    )

    if existing_by_source_id is not None:
        sports_team_ids = (
            list(dict.fromkeys((existing_by_source_id.sports_team_ids or []) + (incoming.sports_team_ids or [])))
            if incoming.source == "sports"
            else incoming.sports_team_ids
        )
        updated = _as_event(
            incoming,
            existing_by_source_id.id,
            # Never overwrite tag or an existing conflict with the
            # source's (always-null/always-active) values.
            tag=existing_by_source_id.tag,
            status=existing_by_source_id.status,
            conflict_group_id=existing_by_source_id.conflict_group_id,
            conflict_role=existing_by_source_id.conflict_role,
            sports_team_ids=sports_team_ids,
        )
        repository.update_event(updated)
        return updated

    # 2. Cross-source conflict: an active event from a DIFFERENT source
    # with a similar title and a close start time. Never auto-merge or
    # overwrite it -- both sides become pendingConflict, linked so a
    # resolution UI can offer Keep original / Keep new / Keep both.
    conflicting_event = next(
        (
            event
            for event in current_events
            if event.source != incoming.source
            and event.status == "active"
            and _looks_like_the_same_event(event, incoming)
        ),
        None,
    )

    if conflicting_event is not None:
        conflict_group_id = f"{conflicting_event.id}-{incoming.source}-{incoming.source_id}"
        repository.update_event(
            replace(
                conflicting_event,
                status="pendingConflict",
                conflict_group_id=conflict_group_id,
                conflict_role="original",
            )
        )
        new_id = repository.add_event(
            replace(
                incoming,
                status="pendingConflict",
                conflict_group_id=conflict_group_id,
                conflict_role="new",
            )
        )
        return _as_event(
            incoming,
            new_id,
            status="pendingConflict",
            conflict_group_id=conflict_group_id,
            conflict_role="new",
        )

    # 3. Neither: a genuinely new event.
    new_id = repository.add_event(incoming)
    return _as_event(incoming, new_id)


def _looks_like_the_same_event(a: CanonicalEvent, b: CanonicalEventData) -> bool:
    title_a = a.title.strip().lower()
    title_b = b.title.strip().lower()
    if title_a != title_b or title_a == "":
        return False

    start_delta = abs((_parse_iso(a.start) - _parse_iso(b.start)).total_seconds())
    return start_delta <= _TITLE_MATCH_THRESHOLD_SECONDS


def _parse_iso(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))
