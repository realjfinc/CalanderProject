"""Global, cross-user cache of every catalog team's upcoming games, at
`sportsTeamGames/{teamId}/games/{sourceId}` -- populated by
`cache_all_team_games` in `poll_sports_events.py` for every team the free
API key can see (see `team_catalog.py`), not just teams someone follows.

This is a read-only cache for the client (see `../../firestore.rules`):
when a user follows a new team, the app can immediately copy that team's
already-cached games into the user's own `events` subcollection, rather
than waiting for the next hourly poll to fetch that team for the first
time. It carries no per-user fields (no `tag`, `status`, conflict fields)
since it isn't anyone's personal calendar -- just a shared schedule
lookup.
"""

from __future__ import annotations

from typing import Protocol

from canonical_event import CanonicalEventData
from event_repository import parse_iso


class SportsCacheRepository(Protocol):
    def upsert_game(self, game: CanonicalEventData) -> None: ...


def _to_cache_data(game: CanonicalEventData) -> dict:
    return {
        "title": game.title,
        "location": game.location,
        "start": parse_iso(game.start),
        "end": parse_iso(game.end),
        "sourceId": game.source_id,
        "league": game.notes,
    }


class FirestoreSportsCacheRepository:
    """Firestore-backed `SportsCacheRepository`, scoped to one team's games."""

    def __init__(self, firestore_client, team_id: str):
        self._games_ref = firestore_client.collection("sportsTeamGames").document(team_id).collection("games")

    def upsert_game(self, game: CanonicalEventData) -> None:
        self._games_ref.document(game.source_id).set(_to_cache_data(game), merge=True)
