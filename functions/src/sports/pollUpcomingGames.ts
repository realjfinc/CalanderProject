import { ingestProviderEvent } from "../shared/ingestProviderEvent";
import type { CanonicalEvent } from "../shared/canonicalEvent";
import type { EventRepository } from "../shared/eventRepository";
import { mapSportsDbEvent } from "./mapSportsDbEvent";

/**
 * Dependencies `pollUpcomingGames` needs, injected rather than reached for
 * directly -- the same seam Step 3's `extractEvent` used (a fake
 * `LlmClient`, a stubbed `fetch`) to keep this fully unit-testable with no
 * Firestore emulator and no real network call.
 */
export interface PollUpcomingGamesDeps {
  listUserIds(): Promise<string[]>;
  listFollowedTeamIds(uid: string): Promise<string[]>;
  fetchUpcomingEventsRaw(teamId: string): Promise<Record<string, unknown>[]>;
  makeEventRepository(uid: string): EventRepository;
}

export interface PollUpcomingGamesResult {
  usersPolled: number;
  teamsPolled: number;
  eventsIngested: number;
}

/**
 * The scheduled poll: for every user, for every team they follow, fetch
 * that team's upcoming games from TheSportsDB and ingest each one through
 * the same shared dedup/conflict utility every other source funnels
 * through. A user with no followed teams is skipped without a wasted
 * Firestore read for their events.
 */
export async function pollUpcomingGames(deps: PollUpcomingGamesDeps): Promise<PollUpcomingGamesResult> {
  const result: PollUpcomingGamesResult = { usersPolled: 0, teamsPolled: 0, eventsIngested: 0 };

  const userIds = await deps.listUserIds();
  for (const uid of userIds) {
    const teamIds = await deps.listFollowedTeamIds(uid);
    if (teamIds.length === 0) continue;

    result.usersPolled += 1;
    const repository = deps.makeEventRepository(uid);
    let currentEvents: CanonicalEvent[] = await repository.listEvents();

    for (const teamId of teamIds) {
      result.teamsPolled += 1;
      const rawGames = await deps.fetchUpcomingEventsRaw(teamId);
      for (const raw of rawGames) {
        const mapped = mapSportsDbEvent(raw);
        if (mapped === null) continue;

        const ingested = await ingestProviderEvent({
          repository,
          incoming: { ...mapped, sportsTeamIds: [teamId] },
          currentEvents,
        });
        result.eventsIngested += 1;
        currentEvents = [...currentEvents.filter((event) => event.id !== ingested.id), ingested];
      }
    }
  }

  return result;
}
