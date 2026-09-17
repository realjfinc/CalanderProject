from canonical_event import CanonicalEvent
from poll_sports_events import cache_all_team_games, poll_upcoming_games


class FakeEventRepository:
    def __init__(self):
        self.events: list[CanonicalEvent] = []
        self._next_id = 1

    def list_events(self) -> list[CanonicalEvent]:
        return list(self.events)

    def add_event(self, event) -> str:
        event_id = f"id-{self._next_id}"
        self._next_id += 1
        self.events.append(CanonicalEvent(**vars(event), id=event_id))
        return event_id

    def update_event(self, event: CanonicalEvent) -> None:
        self.events = [event if e.id == event.id else e for e in self.events]


def _raw_game(event_id: str, home: str = "A", away: str = "B") -> dict:
    return {
        "idEvent": event_id,
        "strHomeTeam": home,
        "strAwayTeam": away,
        "strTimestamp": "2026-03-01 15:00:00",
    }


def test_ingests_every_followed_teams_upcoming_games_per_user():
    repos: dict[str, FakeEventRepository] = {}
    requested_team_ids: list[str] = []

    def fetch(team_id: str):
        requested_team_ids.append(team_id)
        return {
            "t1": [_raw_game("g1")],
            "t2": [_raw_game("g2"), _raw_game("g3")],
            "t3": [_raw_game("g4")],
        }.get(team_id, [])

    def make_repo(uid: str):
        repo = FakeEventRepository()
        repos[uid] = repo
        return repo

    result = poll_upcoming_games(
        list_user_ids=lambda: ["user-1", "user-2"],
        list_followed_team_ids=lambda uid: ["t1", "t2"] if uid == "user-1" else ["t3"],
        fetch_upcoming_events_raw_fn=fetch,
        make_event_repository=make_repo,
    )

    assert sorted(requested_team_ids) == ["t1", "t2", "t3"]
    assert result.users_polled == 2
    assert result.teams_polled == 3
    assert result.events_ingested == 4

    user1_events = repos["user-1"].events
    assert len(user1_events) == 3
    assert all(e.source == "sports" and e.tag is None for e in user1_events)

    assert len(repos["user-2"].events) == 1


def test_skips_a_user_with_no_followed_teams_without_touching_their_events():
    repository_created = False

    def make_repo(uid: str):
        nonlocal repository_created
        repository_created = True
        return FakeEventRepository()

    def fetch(team_id: str):
        raise AssertionError("should never fetch games for a user with no followed teams")

    result = poll_upcoming_games(
        list_user_ids=lambda: ["user-1"],
        list_followed_team_ids=lambda uid: [],
        fetch_upcoming_events_raw_fn=fetch,
        make_event_repository=make_repo,
    )

    assert repository_created is False
    assert result.users_polled == 0
    assert result.events_ingested == 0


def test_re_polling_the_same_games_updates_existing_rows_instead_of_duplicating_them():
    repo = FakeEventRepository()

    def poll_once():
        return poll_upcoming_games(
            list_user_ids=lambda: ["user-1"],
            list_followed_team_ids=lambda uid: ["t1"],
            fetch_upcoming_events_raw_fn=lambda team_id: [_raw_game("g1")],
            make_event_repository=lambda uid: repo,
        )

    poll_once()
    poll_once()

    assert len(repo.events) == 1


def test_skips_a_team_whose_fetch_fails_rather_than_aborting_the_whole_poll():
    repo = FakeEventRepository()

    def fetch(team_id: str):
        if team_id == "broken-team":
            raise RuntimeError("TheSportsDB is having a bad day")
        return [_raw_game("g1")]

    result = poll_upcoming_games(
        list_user_ids=lambda: ["user-1"],
        list_followed_team_ids=lambda uid: ["broken-team", "t1"],
        fetch_upcoming_events_raw_fn=fetch,
        make_event_repository=lambda uid: repo,
    )

    assert result.teams_polled == 2
    assert result.events_ingested == 1
    assert len(repo.events) == 1
    assert repo.events[0].source_id == "g1"


def test_skips_malformed_games_from_the_api_rather_than_crashing_the_whole_poll():
    repo = FakeEventRepository()

    result = poll_upcoming_games(
        list_user_ids=lambda: ["user-1"],
        list_followed_team_ids=lambda uid: ["t1"],
        fetch_upcoming_events_raw_fn=lambda team_id: [_raw_game("g1"), {"strHomeTeam": "No id"}],
        make_event_repository=lambda uid: repo,
    )

    assert result.events_ingested == 1
    assert len(repo.events) == 1
    assert repo.events[0].source_id == "g1"


class FakeSportsCacheRepository:
    def __init__(self):
        self.games = []

    def upsert_game(self, game) -> None:
        self.games.append(game)


def test_cache_all_team_games_caches_every_catalog_team_regardless_of_whether_anyone_follows_it():
    repos: dict[str, FakeSportsCacheRepository] = {}
    requested_team_ids: list[str] = []

    def fetch(team_id: str):
        requested_team_ids.append(team_id)
        return {
            "t1": [_raw_game("g1")],
            "t2": [_raw_game("g2"), _raw_game("g3")],
        }.get(team_id, [])

    def make_repo(team_id: str):
        repo = FakeSportsCacheRepository()
        repos[team_id] = repo
        return repo

    result = cache_all_team_games(
        list_all_team_ids=lambda: ["t1", "t2", "t3"],
        fetch_upcoming_events_raw_fn=fetch,
        make_cache_repository=make_repo,
    )

    assert sorted(requested_team_ids) == ["t1", "t2", "t3"]
    assert result.teams_cached == 3
    assert result.games_cached == 3
    assert len(repos["t1"].games) == 1
    assert len(repos["t2"].games) == 2
    assert len(repos["t3"].games) == 0


def test_cache_all_team_games_skips_a_team_whose_fetch_fails_rather_than_aborting_the_whole_run():
    def fetch(team_id: str):
        if team_id == "broken-team":
            raise RuntimeError("TheSportsDB is having a bad day")
        return [_raw_game("g1")]

    repos: dict[str, FakeSportsCacheRepository] = {}

    def make_repo(team_id: str):
        repo = FakeSportsCacheRepository()
        repos[team_id] = repo
        return repo

    result = cache_all_team_games(
        list_all_team_ids=lambda: ["broken-team", "t1"],
        fetch_upcoming_events_raw_fn=fetch,
        make_cache_repository=make_repo,
    )

    assert result.teams_cached == 2
    assert result.games_cached == 1
    assert "broken-team" not in repos
    assert len(repos["t1"].games) == 1


def test_cache_all_team_games_skips_malformed_games_from_the_api():
    repo = FakeSportsCacheRepository()

    result = cache_all_team_games(
        list_all_team_ids=lambda: ["t1"],
        fetch_upcoming_events_raw_fn=lambda team_id: [_raw_game("g1"), {"strHomeTeam": "No id"}],
        make_cache_repository=lambda team_id: repo,
    )

    assert result.games_cached == 1
    assert len(repo.games) == 1
    assert repo.games[0].source_id == "g1"
