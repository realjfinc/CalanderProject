"""Builds the full catalog of team ids this free API key can see, across
every sport it has real league data for -- not just the teams someone
currently follows. Populating a global games cache from this catalog (see
`poll_sports_events.py`'s `cache_all_team_games`) means a newly followed
team already has its upcoming games in Firestore the moment someone
follows it, instead of waiting for the next hourly poll to fetch that one
team for the first time.
"""

from __future__ import annotations

import logging
import random
from typing import Callable

logger = logging.getLogger("team_catalog")

# Confirmed by hand against the live API: NBA, NFL, NHL, and MLB all have
# real team rosters and real upcoming-game data behind this free key --
# an earlier pass at this got that wrong by searching for team nicknames
# ("Lakers") instead of full official names ("Los Angeles Lakers"), which
# TheSportsDB's search doesn't match well. These four league ids just
# don't reliably turn up in search_all_leagues.php's 5-result-per-sport
# cap (that's a mostly-alphabetical sample, not "the biggest leagues"),
# so they're hardcoded here rather than left to chance.
MAJOR_US_LEAGUE_IDS = [
    "4387",  # NBA (Basketball)
    "4391",  # NFL (American Football)
    "4380",  # NHL (Ice Hockey)
    "4424",  # MLB (Baseball)
]


def list_all_team_ids(
    *,
    fetch_all_leagues: Callable[[], list[dict]],
    fetch_leagues_for_sport: Callable[[str], list[dict]],
    fetch_team_ids_for_league: Callable[[str], list[str]],
    other_sports: list[str],
    major_league_ids: list[str] = MAJOR_US_LEAGUE_IDS,
    shuffle: Callable[[list], None] = random.shuffle,
) -> list[str]:
    """Every team id across Soccer's full league list, the major US pro
    leagues, and up to 5 leagues for each of `other_sports`. A single
    sport's or league's lookup failing doesn't abort the rest -- this runs
    unattended on a schedule, and a transient TheSportsDB blip for one
    league shouldn't cost every other league's teams too.

    Confirmed against the real API: this free key's shared rate limit
    kicks in well before every league/team lookup a full run attempts
    succeeds. Processing sports and leagues in a fixed order would mean
    the same early ones always survive and the same later ones always
    get cut off, run after run, forever -- so the lower-value long tail
    (`other_sports`' capped, mostly-alphabetical leagues) is shuffled (an
    injectable no-op in tests, for deterministic assertions) to give a
    different subset a chance to get through each run, converging on full
    coverage over many runs instead of plateauing on one. Soccer and the
    major US leagues are worth attempting every run regardless, so they're
    not shuffled into that lottery.
    """
    league_ids: set[str] = set()

    try:
        for league in fetch_all_leagues():
            league_id = league.get("idLeague")
            if isinstance(league_id, str):
                league_ids.add(league_id)
    except Exception:
        logger.exception("Failed to fetch the full Soccer league list; skipping it")

    league_ids.update(major_league_ids)

    shuffled_sports = list(other_sports)
    shuffle(shuffled_sports)
    other_league_ids: set[str] = set()
    for sport in shuffled_sports:
        try:
            for league in fetch_leagues_for_sport(sport):
                league_id = league.get("idLeague")
                if isinstance(league_id, str):
                    other_league_ids.add(league_id)
        except Exception:
            logger.exception("Failed to fetch leagues for sport %s; skipping it", sport)

    # Soccer + the major leagues are always attempted, in that fixed
    # priority order; only the long tail competes for the shuffle.
    shuffled_other_league_ids = list(other_league_ids - league_ids)
    shuffle(shuffled_other_league_ids)
    all_league_ids = sorted(league_ids) + shuffled_other_league_ids

    team_ids: set[str] = set()
    for league_id in all_league_ids:
        try:
            team_ids.update(fetch_team_ids_for_league(league_id))
        except Exception:
            logger.exception("Failed to fetch teams for league %s; skipping it", league_id)

    return sorted(team_ids)
