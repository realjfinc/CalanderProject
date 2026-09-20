"""Canonical event schema, in Python.

A field-for-field port of the Dart client's `lib/models/calendar_event.dart`
and its TypeScript counterpart `functions/src/shared/canonicalEvent.ts` --
kept in sync with both so a Firestore document this poller writes is
indistinguishable from one either of those write. Timestamps are ISO-8601
UTC strings; conversion to/from Firestore's native timestamp type happens
at the repository boundary (`event_repository.py`), not here, so this stays
a plain, easily-testable data shape.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class CanonicalEventData:
    title: str
    location: Optional[str]
    # Always UTC, ISO-8601. Normalize at ingestion; never store local time.
    start: str
    end: str
    source: str
    source_id: Optional[str]
    sports_team_ids: Optional[list[str]]
    status: str
    # Only direct user action or Step 5's routing logic may ever set this.
    tag: Optional[str]
    importance: str
    notes: Optional[str]
    attachments: Optional[list]
    repeat: Optional[dict]
    reminders: Optional[list]
    conflict_group_id: Optional[str]
    conflict_role: Optional[str]


@dataclass(frozen=True)
class CanonicalEvent(CanonicalEventData):
    id: str


def new_source_event(
    *,
    title: str,
    location: Optional[str],
    start: str,
    end: str,
    source: str,
    source_id: Optional[str],
    notes: Optional[str],
    sports_team_ids: Optional[list[str]] = None,
) -> CanonicalEventData:
    """Defaults for fields a source adapter (this poller included) never sets."""
    return CanonicalEventData(
        title=title,
        location=location,
        start=start,
        end=end,
        source=source,
        source_id=source_id,
        sports_team_ids=sports_team_ids,
        status="active",
        tag=None,
        importance="flexible",
        notes=notes,
        attachments=None,
        repeat=None,
        reminders=None,
        conflict_group_id=None,
        conflict_role=None,
    )
