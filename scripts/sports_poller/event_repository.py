"""Server-side counterpart to the Flutter client's `EventRepository` and
the Cloud Function's TS `EventRepository` -- same shape, so
`ingest_provider_event` stays identical in behavior across all three.
"""

from __future__ import annotations

from datetime import datetime
from typing import Protocol
from google.cloud.firestore import transactional

from canonical_event import CanonicalEvent, CanonicalEventData


class EventRepository(Protocol):
    def list_events(self) -> list[CanonicalEvent]: ...

    def add_event(self, event: CanonicalEventData) -> str: ...

    def update_event(self, event: CanonicalEvent) -> None: ...


def parse_iso(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _to_firestore_data(event: CanonicalEventData) -> dict:
    # Not raw ISO strings: the Firestore client only turns a real
    # `datetime` into a native Timestamp field on write (matching the
    # Cloud Function's TS `new Date(event.start)`). The Flutter client's
    # `CalendarEvent.fromMap()` only accepts a Timestamp for `start`/`end`
    # -- anything else (including a string) silently falls back to
    # `DateTime.now()`, which is why a poll-written game would render with
    # today's time and never show up as "upcoming" in the Sports dashboard.
    return {
        "title": event.title,
        "location": event.location,
        "start": parse_iso(event.start),
        "end": parse_iso(event.end),
        "source": event.source,
        "sourceId": event.source_id,
        "sportsTeamIds": event.sports_team_ids,
        "status": event.status,
        "tag": event.tag,
        "importance": event.importance,
        "notes": event.notes,
        "attachments": event.attachments,
        "repeat": event.repeat,
        "reminders": event.reminders,
        "conflictGroupId": event.conflict_group_id,
        "conflictRole": event.conflict_role,
    }


def _from_firestore_doc(doc_id: str, data: dict) -> CanonicalEvent:
    # `start`/`end` may be either an ISO string (written by this script) or
    # a Firestore Timestamp/datetime (written by the client or the Cloud
    # Function) -- both `google.cloud.firestore` returns as a
    # timezone-aware `datetime`, so normalize either shape to an ISO string
    # for the pure dedup/conflict logic to compare.
    start = data.get("start")
    end = data.get("end")

    return CanonicalEvent(
        id=doc_id,
        title=data.get("title") or "",
        location=data.get("location"),
        start=start.isoformat() if hasattr(start, "isoformat") else start,
        end=end.isoformat() if hasattr(end, "isoformat") else end,
        source=data.get("source") or "manual",
        source_id=data.get("sourceId"),
        sports_team_ids=data.get("sportsTeamIds"),
        status="pendingConflict" if data.get("status") == "pendingConflict" else "active",
        tag=data.get("tag"),
        importance="locked" if data.get("importance") == "locked" else "flexible",
        notes=data.get("notes"),
        attachments=data.get("attachments"),
        repeat=data.get("repeat"),
        reminders=data.get("reminders"),
        conflict_group_id=data.get("conflictGroupId"),
        conflict_role=data.get("conflictRole"),
    )


class FirestoreEventRepository:
    """Firestore-backed `EventRepository`, scoped to `users/{uid}/events`."""

    def __init__(self, firestore_client, uid: str, *, require_followed_team: bool = False):
        self._db = firestore_client
        self._require_followed_team = require_followed_team
        self._followed_teams = firestore_client.collection('users').document(uid).collection('followedTeams')
        self._events_ref = firestore_client.collection("users").document(uid).collection("events")

    def list_events(self) -> list[CanonicalEvent]:
        return [_from_firestore_doc(doc.id, doc.to_dict()) for doc in self._events_ref.stream()]

    def add_event(self, event: CanonicalEventData) -> str:
        doc_ref = self._events_ref.document()
        self._write(doc_ref, _to_firestore_data(event), update=False)
        return doc_ref.id

    def update_event(self, event: CanonicalEvent) -> None:
        self._write(self._events_ref.document(event.id), _to_firestore_data(event), update=True)

    def _write(self, ref, data, *, update):
        if not self._require_followed_team:
            if update:
                ref.update(data)
            else:
                ref.set(data)
            return

        @transactional
        def write_if_still_following(transaction):
            # Account deletion removes followedTeams first. Query inside the
            # write transaction so a poll already in progress cannot recreate
            # events after the final followed team has been deleted.
            if not self._followed_teams.limit(1).get(transaction=transaction):
                return
            if update:
                transaction.update(ref, data)
            else:
                transaction.set(ref, data)

        write_if_still_following(self._db.transaction())
