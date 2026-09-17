"""Standalone, hourly sports-game poller -- a Python alternative to
deploying `functions/src/index.ts`'s `pollSportsEvents` as a paid,
2nd-generation Firebase Cloud Function (which requires the Blaze plan to
deploy at all). This script does the identical job -- for every user, for
every team they follow, fetch upcoming games from TheSportsDB and ingest
each one through the same shared dedup/conflict utility every other source
funnels through -- but runs anywhere Python does, on whatever schedule you
point at it (see `.github/workflows/poll-sports-events.yml` for an hourly
GitHub Actions cron, which costs nothing to run).

Usage:
    python poll_sports_events.py --credentials /path/to/service-account.json

Or with the credentials JSON in an environment variable (as the GitHub
Actions workflow does, from a repo secret):
    FIREBASE_SERVICE_ACCOUNT_JSON='{...}' python poll_sports_events.py
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import random
import sys
from dataclasses import dataclass
from typing import Callable, Optional

import firebase_admin
import requests
from firebase_admin import credentials, firestore

from canonical_event import CanonicalEvent
from event_repository import EventRepository, FirestoreEventRepository
from ingest_provider_event import ingest_provider_event
from sports_cache_repository import FirestoreSportsCacheRepository, SportsCacheRepository
from team_catalog import list_all_team_ids
from thesportsdb_client import (
    OTHER_CATALOG_SPORTS,
    fetch_all_leagues,
    fetch_leagues_for_sport,
    fetch_team_ids_for_league,
    fetch_upcoming_events_raw,
    map_sports_db_event,
)

logger = logging.getLogger("poll_sports_events")


@dataclass
class PollResult:
    users_polled: int = 0
    teams_polled: int = 0
    events_ingested: int = 0


@dataclass
class CacheResult:
    teams_cached: int = 0
    games_cached: int = 0


def poll_upcoming_games(
    *,
    list_user_ids: Callable[[], list[str]],
    list_followed_team_ids: Callable[[str], list[str]],
    fetch_upcoming_events_raw_fn: Callable[[str], list[dict]],
    make_event_repository: Callable[[str], EventRepository],
) -> PollResult:
    """The scheduled poll, with every dependency injected -- the same seam
    `functions/src/sports/pollUpcomingGames.ts` uses, so this is fully
    unit-testable with fakes, no real Firestore or network call needed.
    A user with no followed teams is skipped without a wasted Firestore
    read for their events.
    """
    result = PollResult()

    for uid in list_user_ids():
        team_ids = list_followed_team_ids(uid)
        if not team_ids:
            continue

        result.users_polled += 1
        repository = make_event_repository(uid)
        current_events: list[CanonicalEvent] = repository.list_events()

        for team_id in team_ids:
            result.teams_polled += 1
            try:
                raw_games = fetch_upcoming_events_raw_fn(team_id)
            except Exception:
                # One team's request failing (a transient TheSportsDB
                # blip, a bad team id) shouldn't stop the rest of this
                # user's teams, let alone every other user's -- the next
                # hourly run will retry this team anyway.
                logger.exception("Failed to fetch upcoming games for team %s; skipping it", team_id)
                continue

            for raw_game in raw_games:
                mapped = map_sports_db_event(raw_game)
                if mapped is None:
                    continue

                ingested = ingest_provider_event(
                    repository=repository,
                    incoming=mapped,
                    current_events=current_events,
                )
                result.events_ingested += 1
                current_events = [e for e in current_events if e.id != ingested.id] + [ingested]

    return result


def cache_all_team_games(
    *,
    list_all_team_ids: Callable[[], list[str]],
    fetch_upcoming_events_raw_fn: Callable[[str], list[dict]],
    make_cache_repository: Callable[[str], SportsCacheRepository],
    shuffle: Callable[[list], None] = random.shuffle,
) -> CacheResult:
    """Populates the global games cache (`sportsTeamGames/{teamId}/games`,
    see `sports_cache_repository.py`) for every team in the catalog -- not
    just teams someone follows -- so a newly followed team's games are
    already in Firestore the moment someone follows it, instead of only
    appearing after that team's first hourly poll.

    Confirmed against the real API: this free key's shared rate limit
    kicks in before every team in a full catalog gets its games fetched
    in one run. `list_all_team_ids()` always returns the catalog sorted,
    so processing it in that same order every run would mean the same
    early teams always get cached and the same later ones never do --
    shuffled here (an injectable no-op in tests) so a different subset
    gets through each run instead.
    """
    result = CacheResult()

    team_ids = list(list_all_team_ids())
    shuffle(team_ids)
    for team_id in team_ids:
        result.teams_cached += 1
        try:
            raw_games = fetch_upcoming_events_raw_fn(team_id)
        except Exception:
            # Same reasoning as poll_upcoming_games: one team's request
            # failing shouldn't cost every other team's cache refresh, and
            # the next hourly run retries it anyway.
            logger.exception("Failed to fetch upcoming games for team %s while caching; skipping it", team_id)
            continue

        repository = make_cache_repository(team_id)
        for raw_game in raw_games:
            mapped = map_sports_db_event(raw_game)
            if mapped is None:
                continue
            repository.upsert_game(mapped)
            result.games_cached += 1

    return result


def _load_credentials(path: Optional[str]) -> credentials.Base:
    if path:
        return credentials.Certificate(path)

    raw_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
    if raw_json:
        return credentials.Certificate(json.loads(raw_json))

    raise SystemExit(
        "No Firebase credentials found. Pass --credentials <path-to-service-account.json>, "
        "or set the FIREBASE_SERVICE_ACCOUNT_JSON environment variable."
    )


def run(credentials_path: Optional[str] = None) -> tuple[PollResult, CacheResult]:
    app = firebase_admin.initialize_app(_load_credentials(credentials_path))
    db = firestore.client(app)
    http_session = requests.Session()

    poll_result = poll_upcoming_games(
        # Not `db.collection("users").stream()`: the app never writes a
        # document directly at `users/{uid}` -- only to subcollections
        # under it (events, tags, followedTeams, ...). Firestore only
        # returns documents that actually exist from a collection query, so
        # that would silently enumerate zero users even with real data
        # underneath, and this poll would find nothing to do every run.
        # Querying the `followedTeams` collection group and taking each
        # document's grandparent id finds exactly the users who have at
        # least one followed team -- which is also the only users this poll
        # does anything for anyway.
        list_user_ids=lambda: sorted(
            {doc.reference.parent.parent.id for doc in db.collection_group("followedTeams").stream()}
        ),
        list_followed_team_ids=lambda uid: [
            doc.id for doc in db.collection("users").document(uid).collection("followedTeams").stream()
        ],
        fetch_upcoming_events_raw_fn=lambda team_id: fetch_upcoming_events_raw(
            team_id, session=http_session
        ),
        make_event_repository=lambda uid: FirestoreEventRepository(db, uid),
    )

    logger.info(
        "poll_sports_events complete: users_polled=%d teams_polled=%d events_ingested=%d",
        poll_result.users_polled,
        poll_result.teams_polled,
        poll_result.events_ingested,
    )

    cache_result = cache_all_team_games(
        list_all_team_ids=lambda: list_all_team_ids(
            fetch_all_leagues=lambda: fetch_all_leagues(session=http_session),
            fetch_leagues_for_sport=lambda sport: fetch_leagues_for_sport(sport, session=http_session),
            fetch_team_ids_for_league=lambda league_name: fetch_team_ids_for_league(
                league_name, session=http_session
            ),
            other_sports=OTHER_CATALOG_SPORTS,
        ),
        fetch_upcoming_events_raw_fn=lambda team_id: fetch_upcoming_events_raw(
            team_id, session=http_session
        ),
        make_cache_repository=lambda team_id: FirestoreSportsCacheRepository(db, team_id),
    )

    logger.info(
        "cache_all_team_games complete: teams_cached=%d games_cached=%d",
        cache_result.teams_cached,
        cache_result.games_cached,
    )

    return poll_result, cache_result


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--credentials",
        help="Path to a Firebase service account JSON key file. "
        "Falls back to the FIREBASE_SERVICE_ACCOUNT_JSON env var if omitted.",
    )
    args = parser.parse_args()

    try:
        run(args.credentials)
    except Exception:
        logger.exception("poll_sports_events failed")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
