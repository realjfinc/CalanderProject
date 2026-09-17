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

import time
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

import requests

from canonical_event import CanonicalEventData, new_source_event

DEFAULT_API_KEY = "3"
_REQUEST_TIMEOUT_SECONDS = 15
_RATE_LIMIT_MAX_ATTEMPTS = 3
_RATE_LIMIT_BACKOFF_SECONDS = 1.5


class SportsApiError(Exception):
    pass


def _get(http, url: str, params: Optional[dict] = None):
    """GET with a couple of retries specifically on HTTP 429 -- observed in
    practice to be a transient, short-lived throttle on this free key
    rather than a hard block, so a brief backoff before giving up (which
    `cache_all_team_games`/`list_all_team_ids` would otherwise treat as
    "skip this team/league until next run") recovers most of them.
    """
    response = None
    for attempt in range(_RATE_LIMIT_MAX_ATTEMPTS):
        response = http.get(url, params=params, timeout=_REQUEST_TIMEOUT_SECONDS)
        if response.status_code != 429:
            return response
        if attempt < _RATE_LIMIT_MAX_ATTEMPTS - 1:
            time.sleep(_RATE_LIMIT_BACKOFF_SECONDS * (attempt + 1))
    return response


# Sports (besides Soccer) this free key actually returns real league data
# for via search_all_leagues.php -- confirmed by hand against the live API.
# That endpoint hard-caps at 5 leagues per sport regardless of how many
# really exist, so this is "everything the free key will show us", not a
# claim of full coverage. (NBA/NFL/NHL/MLB *do* have real data behind this
# key -- see team_catalog.MAJOR_US_LEAGUES -- they just don't reliably show
# up in this particular capped sample.)
OTHER_CATALOG_SPORTS = [
    "Basketball",
    "Ice Hockey",
    "Baseball",
    "American Football",
    "Rugby",
    "Cricket",
    "Tennis",
    "Motorsport",
    "Volleyball",
]


def fetch_all_leagues(
    api_key: str = DEFAULT_API_KEY, session: Optional[requests.Session] = None
) -> list[dict[str, Any]]:
    """Soccer's full, uncapped league list (`all_leagues.php`) -- the one
    endpoint this free key doesn't cap to a handful of results.
    """
    http = session or requests
    url = f"https://www.thesportsdb.com/api/v1/json/{api_key}/all_leagues.php"
    response = _get(http, url)
    if response.status_code != 200:
        raise SportsApiError(f"All-leagues request failed with status {response.status_code}")
    body = response.json() or {}
    return [league for league in (body.get("leagues") or []) if league.get("strSport") == "Soccer"]


def fetch_leagues_for_sport(
    sport: str, api_key: str = DEFAULT_API_KEY, session: Optional[requests.Session] = None
) -> list[dict[str, Any]]:
    """Up to 5 leagues for a non-Soccer sport (`search_all_leagues.php`) --
    this free key's hard cap on that endpoint, not a real total.
    """
    http = session or requests
    url = f"https://www.thesportsdb.com/api/v1/json/{api_key}/search_all_leagues.php"
    response = _get(http, url, params={"s": sport})
    if response.status_code != 200:
        raise SportsApiError(f"Search-leagues request failed with status {response.status_code}")
    body = response.json() or {}
    return body.get("countries") or []


def fetch_team_ids_for_league(
    league_name: str, api_key: str = DEFAULT_API_KEY, session: Optional[requests.Session] = None
) -> list[str]:
    """Every team's id in one league, by league name (`search_all_teams.php`).

    Confirmed by hand against the live API: `lookup_all_teams.php?id=<id>`
    doesn't work on this free test key at all -- it returns the exact same
    fixed sample of 24 English League One teams for *any* id, including a
    garbage id or no id at all. `search_all_teams.php?l=<league name>` is
    the endpoint that actually returns real, league-specific rosters on
    this key (capped at 10 teams per league -- still real data, just not
    a full roster).
    """
    http = session or requests
    url = f"https://www.thesportsdb.com/api/v1/json/{api_key}/search_all_teams.php"
    response = _get(http, url, params={"l": league_name})
    if response.status_code != 200:
        raise SportsApiError(f"Search-teams request failed with status {response.status_code}")
    body = response.json() or {}
    return [team["idTeam"] for team in (body.get("teams") or []) if isinstance(team.get("idTeam"), str)]


def fetch_upcoming_events_raw(
    team_id: str, api_key: str = DEFAULT_API_KEY, session: Optional[requests.Session] = None
) -> list[dict[str, Any]]:
    """Raw upcoming-events JSON for one team, as returned by the API --
    separated from `map_sports_db_event` so the mapping stays independently
    (and easily) unit-testable with fixture data.
    """
    http = session or requests
    url = f"https://www.thesportsdb.com/api/v1/json/{api_key}/eventsnext.php"
    response = _get(http, url, params={"id": team_id})
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
