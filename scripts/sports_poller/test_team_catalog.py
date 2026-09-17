from team_catalog import list_all_team_ids


def test_combines_soccers_full_league_list_with_other_sports_capped_leagues():
    calls = []

    def fetch_all_leagues():
        return [{"idLeague": "4328"}, {"idLeague": "4329"}]

    def fetch_leagues_for_sport(sport):
        calls.append(sport)
        return [{"idLeague": f"{sport}-league"}]

    def fetch_team_ids_for_league(league_id):
        return [f"{league_id}-team-1", f"{league_id}-team-2"]

    team_ids = list_all_team_ids(
        fetch_all_leagues=fetch_all_leagues,
        fetch_leagues_for_sport=fetch_leagues_for_sport,
        fetch_team_ids_for_league=fetch_team_ids_for_league,
        other_sports=["Basketball", "Ice Hockey"],
        major_league_ids=[],  # isolate this test to soccer + other_sports
        shuffle=lambda items: None,  # deterministic order for this assertion
    )

    assert calls == ["Basketball", "Ice Hockey"]
    assert team_ids == sorted(
        [
            "4328-team-1",
            "4328-team-2",
            "4329-team-1",
            "4329-team-2",
            "Basketball-league-team-1",
            "Basketball-league-team-2",
            "Ice Hockey-league-team-1",
            "Ice Hockey-league-team-2",
        ]
    )


def test_dedupes_a_team_id_shared_across_leagues():
    team_ids = list_all_team_ids(
        fetch_all_leagues=lambda: [{"idLeague": "a"}, {"idLeague": "b"}],
        fetch_leagues_for_sport=lambda sport: [],
        fetch_team_ids_for_league=lambda league_id: ["shared-team", f"{league_id}-only"],
        other_sports=[],
        major_league_ids=[],
    )

    assert team_ids == sorted(["shared-team", "a-only", "b-only"])


def test_a_failing_leagues_lookup_for_one_sport_does_not_lose_the_others():
    def fetch_leagues_for_sport(sport):
        if sport == "Cricket":
            raise RuntimeError("TheSportsDB is having a bad day")
        return [{"idLeague": f"{sport}-league"}]

    team_ids = list_all_team_ids(
        fetch_all_leagues=lambda: [],
        fetch_leagues_for_sport=fetch_leagues_for_sport,
        fetch_team_ids_for_league=lambda league_id: [f"{league_id}-team"],
        other_sports=["Cricket", "Tennis"],
        major_league_ids=[],
    )

    assert team_ids == ["Tennis-league-team"]


def test_a_failing_team_lookup_for_one_league_does_not_lose_the_others():
    def fetch_team_ids_for_league(league_id):
        if league_id == "broken-league":
            raise RuntimeError("TheSportsDB is having a bad day")
        return [f"{league_id}-team"]

    team_ids = list_all_team_ids(
        fetch_all_leagues=lambda: [{"idLeague": "broken-league"}, {"idLeague": "good-league"}],
        fetch_leagues_for_sport=lambda sport: [],
        fetch_team_ids_for_league=fetch_team_ids_for_league,
        other_sports=[],
        major_league_ids=[],
    )

    assert team_ids == ["good-league-team"]


def test_shuffles_the_long_tail_but_always_attempts_soccer_and_major_us_leagues():
    """Confirmed against the real API: this free key's rate limit kicks in
    before every league/team lookup a full run attempts succeeds, and a
    fixed processing order would mean the same early ones always survive
    while the same later ones always get cut off -- forever. Shuffling
    other_sports' long tail (not just relying on the final sorted() return
    value, which says nothing about which requests were even attempted)
    is what lets different teams get through across different runs.
    Soccer and the major US leagues are worth attempting every single run
    regardless, so they're excluded from that lottery.
    """
    shuffle_calls = []

    def shuffle(items):
        shuffle_calls.append(list(items))
        items.reverse()  # a real shuffle, but deterministic for the test

    requested_league_ids = []

    def fetch_team_ids_for_league(league_id):
        requested_league_ids.append(league_id)
        return [f"{league_id}-team"]

    team_ids = list_all_team_ids(
        fetch_all_leagues=lambda: [{"idLeague": "4328"}],
        fetch_leagues_for_sport=lambda sport: [{"idLeague": f"{sport}-league"}],
        fetch_team_ids_for_league=fetch_team_ids_for_league,
        other_sports=["Basketball", "Ice Hockey", "Baseball"],
        major_league_ids=["nba-id", "nfl-id"],
        shuffle=shuffle,
    )

    # Once for the sport order, once for the long-tail league ids -- never
    # for soccer or the major leagues, which are always attempted.
    assert len(shuffle_calls) == 2
    assert shuffle_calls[0] == ["Basketball", "Ice Hockey", "Baseball"]
    assert sorted(shuffle_calls[1]) == sorted(["Basketball-league", "Ice Hockey-league", "Baseball-league"])
    # Soccer and the major leagues come first, in that fixed order, ahead
    # of whatever the shuffled long tail happens to land on.
    assert requested_league_ids[:3] == ["4328", "nba-id", "nfl-id"]
    assert team_ids == sorted(
        [
            "4328-team",
            "nba-id-team",
            "nfl-id-team",
            "Basketball-league-team",
            "Ice Hockey-league-team",
            "Baseball-league-team",
        ]
    )


def test_a_failing_soccer_leagues_lookup_does_not_prevent_other_sports_from_being_cataloged():
    def fetch_all_leagues():
        raise RuntimeError("TheSportsDB is having a bad day")

    team_ids = list_all_team_ids(
        fetch_all_leagues=fetch_all_leagues,
        fetch_leagues_for_sport=lambda sport: [{"idLeague": f"{sport}-league"}],
        fetch_team_ids_for_league=lambda league_id: [f"{league_id}-team"],
        other_sports=["Basketball"],
        major_league_ids=[],
    )

    assert team_ids == ["Basketball-league-team"]


def test_includes_the_major_us_leagues_by_default():
    """The actual point of this feature: following "Los Angeles Lakers" or
    "Dallas Cowboys" (searched by full official name -- TheSportsDB's
    search doesn't match well on nicknames like "Lakers") should already
    have cached data waiting, not just work via the live-fallback path.
    """
    requested_league_ids = []

    team_ids = list_all_team_ids(
        fetch_all_leagues=lambda: [],
        fetch_leagues_for_sport=lambda sport: [],
        fetch_team_ids_for_league=lambda league_id: requested_league_ids.append(league_id)
        or [f"{league_id}-team"],
        other_sports=[],
    )

    assert sorted(requested_league_ids) == sorted(["4387", "4391", "4380", "4424"])
    assert team_ids == sorted([f"{league_id}-team" for league_id in requested_league_ids])
