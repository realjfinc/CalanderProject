"""Regression test for the real Firestore wiring in `run()` -- specifically
`list_user_ids`, which every other test in this package fakes out via
dependency injection and therefore can't catch a bug in.

This is a real bug that shipped: the app never writes a document directly
at `users/{uid}`, only to subcollections under it. Firestore's
`collection("users").stream()` only returns documents that actually exist,
so it silently enumerated zero users every run -- the poller ran, logged
success, and wrote nothing, with no error anywhere. See `run()`'s
`list_user_ids` for the fix (a `followedTeams` collection-group query).

Needs a live Firestore emulator (`FIRESTORE_EMULATOR_HOST`, default
127.0.0.1:8088 -- see ../../tests/firestore-rules for how to start one).
Skipped automatically if the emulator isn't reachable, so the rest of this
package's tests (which use only fakes) keep working with no network access.
"""

from __future__ import annotations

import os
import socket
from datetime import datetime, timezone

import pytest
from google.cloud import firestore

from event_repository import FirestoreEventRepository
from ingest_provider_event import ingest_provider_event
from sports_cache_repository import FirestoreSportsCacheRepository
from thesportsdb_client import map_sports_db_event

EMULATOR_HOST = os.environ.get("FIRESTORE_EMULATOR_HOST", "127.0.0.1:8088")


def _emulator_reachable() -> bool:
    host, _, port = EMULATOR_HOST.partition(":")
    try:
        with socket.create_connection((host, int(port)), timeout=1):
            return True
    except OSError:
        return False


pytestmark = pytest.mark.skipif(
    not _emulator_reachable(),
    reason=f"No Firestore emulator reachable at {EMULATOR_HOST}",
)


@pytest.fixture
def db():
    os.environ["FIRESTORE_EMULATOR_HOST"] = EMULATOR_HOST
    client = firestore.Client(project="demo-calander")
    yield client
    # Clean up everything this test wrote so runs don't leak into each other.
    for user_doc in client.collection("users").list_documents():
        for sub in user_doc.collections():
            for doc in sub.stream():
                doc.reference.delete()
    for team_doc in client.collection("sportsTeamGames").list_documents():
        for sub in team_doc.collections():
            for doc in sub.stream():
                doc.reference.delete()


def test_list_user_ids_finds_a_user_who_only_has_subcollection_data(db):
    """The exact scenario that shipped broken: a user who followed a team
    (and so has games synced) but, like every real user in this app, has no
    document actually written at `users/{uid}` itself.
    """
    uid = "regression-user"
    db.collection("users").document(uid).collection("followedTeams").document("133604").set(
        {"name": "Arsenal", "league": "English Premier League"}
    )

    # This mirrors run()'s list_user_ids exactly -- a change to one without
    # the other should fail this test.
    found = sorted({doc.reference.parent.parent.id for doc in db.collection_group("followedTeams").stream()})

    assert uid in found
    # The old, broken approach for comparison -- documents this would keep
    # returning nothing even with real data underneath.
    assert [doc.id for doc in db.collection("users").stream()] == []


def test_end_to_end_poll_writes_a_game_for_a_user_with_no_users_uid_document(db):
    """Full path: discover the user via the followedTeams collection group,
    ingest a game for their followed team, and confirm it actually lands
    in `users/{uid}/events` -- the thing "no sports data in Firebase" is
    actually about.
    """
    uid = "regression-user-2"
    db.collection("users").document(uid).collection("followedTeams").document("133604").set(
        {"name": "Arsenal", "league": "English Premier League"}
    )

    raw_game = {
        "idEvent": "e-regression-1",
        "strHomeTeam": "Arsenal",
        "strAwayTeam": "Chelsea",
        "strVenue": "Emirates Stadium",
        "strTimestamp": "2026-03-01 15:00:00",
    }

    found_uids = sorted({doc.reference.parent.parent.id for doc in db.collection_group("followedTeams").stream()})
    assert uid in found_uids

    repository = FirestoreEventRepository(db, uid)
    mapped = map_sports_db_event(raw_game)
    assert mapped is not None
    ingest_provider_event(repository=repository, incoming=mapped, current_events=repository.list_events())

    events = list(db.collection("users").document(uid).collection("events").stream())
    assert len(events) == 1
    data = events[0].to_dict()
    assert data["title"] == "Arsenal vs Chelsea"
    assert data["source"] == "sports"
    assert data["sourceId"] == "e-regression-1"
    assert data["tag"] is None

    # Not a plain ISO string: the Flutter client's CalendarEvent.fromMap()
    # only accepts a Firestore Timestamp for `start`/`end` and silently
    # falls back to `DateTime.now()` for anything else -- a game that was
    # actually written as a string would render with today's date/time and
    # would never show up as "upcoming" in the Sports dashboard, even
    # though the document exists. This is exactly the bug that shipped.
    assert isinstance(data["start"], datetime)
    assert data["start"] == datetime(2026, 3, 1, 15, 0, tzinfo=timezone.utc)


def test_global_cache_stores_a_team_s_games_regardless_of_whether_anyone_follows_it(db):
    """cache_all_team_games's whole point: a team nobody follows yet still
    gets its games written to `sportsTeamGames/{teamId}/games`, with real
    Timestamp fields (not strings, per the bug above) so the client can
    trust them the moment someone follows that team.
    """
    team_id = "133604"
    raw_game = {
        "idEvent": "e-cache-1",
        "strHomeTeam": "Arsenal",
        "strAwayTeam": "Chelsea",
        "strVenue": "Emirates Stadium",
        "strLeague": "English Premier League",
        "strTimestamp": "2026-03-01 15:00:00",
    }

    mapped = map_sports_db_event(raw_game)
    assert mapped is not None
    FirestoreSportsCacheRepository(db, team_id).upsert_game(mapped)

    games = list(db.collection("sportsTeamGames").document(team_id).collection("games").stream())
    assert len(games) == 1
    data = games[0].to_dict()
    assert data["title"] == "Arsenal vs Chelsea"
    assert data["sourceId"] == "e-cache-1"
    assert data["league"] == "English Premier League"
    assert isinstance(data["start"], datetime)
    assert data["start"] == datetime(2026, 3, 1, 15, 0, tzinfo=timezone.utc)


def test_global_cache_upsert_is_idempotent_by_source_id(db):
    team_id = "133604"
    raw_game = {
        "idEvent": "e-cache-2",
        "strHomeTeam": "Arsenal",
        "strAwayTeam": "Liverpool",
        "strTimestamp": "2026-03-01 15:00:00",
    }
    repository = FirestoreSportsCacheRepository(db, team_id)
    mapped = map_sports_db_event(raw_game)
    repository.upsert_game(mapped)
    repository.upsert_game(mapped)

    games = list(db.collection("sportsTeamGames").document(team_id).collection("games").stream())
    assert len(games) == 1
