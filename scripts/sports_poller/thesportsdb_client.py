"""Client for TheSportsDB's free v1 REST API, and pure mapping to the
canonical event schema -- a Python port of
`calander/lib/services/thesportsdb_client.dart` and
`functions/src/sports/mapSportsDbEvent.ts`, kept behaviorally identical
(same fallback order, same 3-hour default duration, same UTC trust in
TheSportsDB's documented-UTC fields).

`"3"` (the default API key) is TheSportsDB's own published test key for
their free tier -- not a real secret, and the reason Sports Mode needs no
account or credential setup of its own to run.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Optional

import requests

from canonical_event import CanonicalEventData, new_source_event

DEFAULT_API_KEY = "3"
_REQUEST_TIMEOUT_SECONDS = 15


class SportsApiError(Exception):
    pass


def fetch_upcoming_events_raw(
    team_id: str, api_key: str = DEFAULT_API_KEY, session: Optional[requests.Session] = None
) -> list[dict[str, Any]]:
    """Raw upcoming-events JSON for one team, as returned by the API --
    separated from `map_sports_db_event` so the mapping stays independently
    (and easily) unit-testable with fixture data.
    """
    http = session or requests
    url = f"https://www.thesportsdb.com/api/v1/json/{api_key}/eventsnext.php"
    response = http.get(url, params={"id": team_id}, timeout=_REQUEST_TIMEOUT_SECONDS)
    if response.status_code != 200:
        raise SportsApiError(f"Upcoming events request failed with status {response.status_code}")
    body = response.json() or {}
    return body.get("events") or []


def map_sports_db_event(raw: dict[str, Any]) -> Optional[CanonicalEventData]:
    """Pure mapping from a TheSportsDB event resource to the canonical
    schema. Returns None for an event with no id or no parseable time.
    """
    event_id = raw.get("idEvent")
    if not isinstance(event_id, str):
        return None

    start = _parse_utc_start(raw)
    if start is None:
        return None
    # TheSportsDB doesn't provide an end time; a game's actual duration
    # varies by sport, so this is a documented, deliberately generous guess
    # rather than a claim of precision.
    end = start + timedelta(hours=3)

    home = raw.get("strHomeTeam")
    away = raw.get("strAwayTeam")
    if isinstance(home, str) and isinstance(away, str):
        title = f"{home} vs {away}"
    else:
        title = raw.get("strEvent") if isinstance(raw.get("strEvent"), str) else "Game"

    venue = raw.get("strVenue")
    league = raw.get("strLeague")

    return new_source_event(
        title=title,
        location=venue if isinstance(venue, str) else None,
        start=_isoformat_z(start),
        end=_isoformat_z(end),
        source="sports",
        source_id=event_id,
        notes=league if isinstance(league, str) else None,
    )


def _parse_utc_start(raw: dict[str, Any]) -> Optional[datetime]:
    timestamp = raw.get("strTimestamp")
    if isinstance(timestamp, str) and timestamp.strip():
        return _parse_utc(timestamp.strip().replace(" ", "T"))

    date = raw.get("dateEvent")
    if not isinstance(date, str) or not date.strip():
        return None
    time = raw.get("strTime")
    time_part = time.strip() if isinstance(time, str) and time.strip() else "00:00:00"
    return _parse_utc(f"{date.strip()}T{time_part}")


def _parse_utc(naive_iso: str) -> Optional[datetime]:
    """TheSportsDB's documented-UTC fields carry no offset of their own --
    trusted the same way the Dart/TS ports do, by explicitly appending a
    UTC marker before parsing rather than letting a naive datetime default
    to local time.
    """
    try:
        return datetime.fromisoformat(naive_iso).replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def _isoformat_z(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
