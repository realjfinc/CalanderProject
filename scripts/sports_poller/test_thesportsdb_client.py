from datetime import datetime, timezone

import pytest

from thesportsdb_client import (
    SportsApiError,
    fetch_all_leagues,
    fetch_leagues_for_sport,
    fetch_team_ids_for_league,
    map_sports_db_event,
)


class _FakeResponse:
    def __init__(self, status_code=200, body=None):
        self.status_code = status_code
        self._body = body or {}

    def json(self):
        return self._body


class _FakeSession:
    """Records every call and returns a canned response for its url."""

    def __init__(self, responses):
        self.responses = responses
        self.calls = []

    def get(self, url, params=None, timeout=None):
        self.calls.append((url, params))
        return self.responses[url]


class _FlakyRateLimitedSession:
    """Returns 429 for the first `fail_times` calls, then 200 -- simulates
    TheSportsDB's free key's observed behavior: brief, transient 429s that
    clear up within a couple of seconds, not a hard block.
    """

    def __init__(self, fail_times, body):
        self.fail_times = fail_times
        self.body = body
        self.call_count = 0

    def get(self, url, params=None, timeout=None):
        self.call_count += 1
        if self.call_count <= self.fail_times:
            return _FakeResponse(status_code=429)
        return _FakeResponse(body=self.body)


def test_fetch_team_ids_for_league_retries_through_a_transient_429(monkeypatch):
    import thesportsdb_client

    monkeypatch.setattr(thesportsdb_client.time, "sleep", lambda seconds: None)
    session = _FlakyRateLimitedSession(fail_times=2, body={"teams": [{"idTeam": "133604"}]})

    team_ids = fetch_team_ids_for_league("English Premier League", session=session)

    assert team_ids == ["133604"]
    assert session.call_count == 3


def test_fetch_team_ids_for_league_gives_up_after_repeated_429s(monkeypatch):
    import thesportsdb_client

    monkeypatch.setattr(thesportsdb_client.time, "sleep", lambda seconds: None)
    session = _FlakyRateLimitedSession(fail_times=99, body={"teams": []})

    with pytest.raises(SportsApiError):
        fetch_team_ids_for_league("English Premier League", session=session)


def test_fetch_all_leagues_returns_only_soccer_leagues():
    session = _FakeSession(
        {
            "https://www.thesportsdb.com/api/v1/json/3/all_leagues.php": _FakeResponse(
                body={
                    "leagues": [
                        {"idLeague": "4328", "strLeague": "English Premier League", "strSport": "Soccer"},
                        {"idLeague": "4380", "strLeague": "NBA", "strSport": "Basketball"},
                    ]
                }
            )
        }
    )

    leagues = fetch_all_leagues(session=session)

    assert [league["idLeague"] for league in leagues] == ["4328"]


def test_fetch_all_leagues_raises_on_a_non_200_status():
    session = _FakeSession(
        {"https://www.thesportsdb.com/api/v1/json/3/all_leagues.php": _FakeResponse(status_code=500)}
    )

    with pytest.raises(SportsApiError):
        fetch_all_leagues(session=session)


def test_fetch_leagues_for_sport_passes_the_sport_as_a_query_param():
    session = _FakeSession(
        {
            "https://www.thesportsdb.com/api/v1/json/3/search_all_leagues.php": _FakeResponse(
                body={"countries": [{"idLeague": "4734", "strLeague": "Argentine LNB"}]}
            )
        }
    )

    leagues = fetch_leagues_for_sport("Basketball", session=session)

    assert [league["idLeague"] for league in leagues] == ["4734"]
    assert session.calls[0][1] == {"s": "Basketball"}


def test_fetch_leagues_for_sport_returns_an_empty_list_when_the_api_has_none():
    session = _FakeSession(
        {"https://www.thesportsdb.com/api/v1/json/3/search_all_leagues.php": _FakeResponse(body={})}
    )

    assert fetch_leagues_for_sport("Curling", session=session) == []


def test_fetch_team_ids_for_league_returns_only_string_ids():
    session = _FakeSession(
        {
            "https://www.thesportsdb.com/api/v1/json/3/search_all_teams.php": _FakeResponse(
                body={
                    "teams": [
                        {"idTeam": "133604", "strTeam": "Arsenal"},
                        {"idTeam": None, "strTeam": "Malformed"},
                    ]
                }
            )
        }
    )

    team_ids = fetch_team_ids_for_league("English Premier League", session=session)

    assert team_ids == ["133604"]
    assert session.calls[0][1] == {"l": "English Premier League"}


def test_maps_a_game_using_str_timestamp_as_the_utc_start_time():
    event = map_sports_db_event(
        {
            "idEvent": "e-1",
            "strHomeTeam": "Arsenal",
            "strAwayTeam": "Chelsea",
            "strVenue": "Emirates Stadium",
            "strLeague": "English Premier League",
            "strTimestamp": "2026-03-01 15:00:00",
        }
    )

    assert event is not None
    assert event.source == "sports"
    assert event.source_id == "e-1"
    assert event.title == "Arsenal vs Chelsea"
    assert event.location == "Emirates Stadium"
    assert event.notes == "English Premier League"
    assert event.start == datetime(2026, 3, 1, 15, tzinfo=timezone.utc).isoformat().replace(
        "+00:00", "Z"
    )
    assert event.tag is None


def test_falls_back_to_date_event_plus_str_time_when_str_timestamp_is_absent():
    event = map_sports_db_event(
        {
            "idEvent": "e-2",
            "strHomeTeam": "A",
            "strAwayTeam": "B",
            "dateEvent": "2026-03-01",
            "strTime": "15:00:00",
        }
    )

    assert event.start == datetime(2026, 3, 1, 15, tzinfo=timezone.utc).isoformat().replace(
        "+00:00", "Z"
    )


def test_falls_back_to_midnight_when_str_time_is_also_absent():
    event = map_sports_db_event(
        {"idEvent": "e-3", "strHomeTeam": "A", "strAwayTeam": "B", "dateEvent": "2026-03-01"}
    )

    assert event.start == datetime(2026, 3, 1, tzinfo=timezone.utc).isoformat().replace(
        "+00:00", "Z"
    )


def test_defaults_a_3_hour_duration_since_the_api_has_no_end_time():
    event = map_sports_db_event(
        {
            "idEvent": "e-4",
            "strHomeTeam": "A",
            "strAwayTeam": "B",
            "strTimestamp": "2026-03-01 15:00:00",
        }
    )

    assert event.end == datetime(2026, 3, 1, 18, tzinfo=timezone.utc).isoformat().replace(
        "+00:00", "Z"
    )


def test_falls_back_to_str_event_for_the_title_when_team_names_are_missing():
    event = map_sports_db_event(
        {"idEvent": "e-5", "strEvent": "Cup Final", "strTimestamp": "2026-03-01 15:00:00"}
    )

    assert event.title == "Cup Final"


def test_returns_none_without_an_id_or_without_any_parseable_time():
    assert map_sports_db_event({"strTimestamp": "2026-03-01 15:00:00"}) is None
    assert map_sports_db_event({"idEvent": "e-6"}) is None


def test_a_newly_mapped_game_never_carries_a_tag_or_a_conflict_role():
    event = map_sports_db_event(
        {
            "idEvent": "e-7",
            "strHomeTeam": "A",
            "strAwayTeam": "B",
            "strTimestamp": "2026-03-01 15:00:00",
        }
    )

    assert event.tag is None
    assert event.status == "active"
    assert event.conflict_group_id is None
    assert event.conflict_role is None
