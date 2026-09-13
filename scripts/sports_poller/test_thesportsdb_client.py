from datetime import datetime, timezone

from thesportsdb_client import map_sports_db_event


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
