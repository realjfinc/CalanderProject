import assert from "node:assert/strict";
import { test } from "node:test";

import { pollUpcomingGames } from "../src/sports/pollUpcomingGames";
import type { CanonicalEvent, CanonicalEventData } from "../src/shared/canonicalEvent";
import type { EventRepository } from "../src/shared/eventRepository";

class FakeEventRepository implements EventRepository {
  events: CanonicalEvent[] = [];
  private nextId = 1;

  async listEvents(): Promise<CanonicalEvent[]> {
    return [...this.events];
  }

  async addEvent(event: CanonicalEventData): Promise<string> {
    const id = `id-${this.nextId++}`;
    this.events.push({ ...event, id });
    return id;
  }

  async updateEvent(event: CanonicalEvent): Promise<void> {
    const index = this.events.findIndex((e) => e.id === event.id);
    if (index === -1) throw new Error(`no event with id ${event.id}`);
    this.events[index] = event;
  }
}

function rawGame(id: string, home = "A", away = "B") {
  return {
    idEvent: id,
    strHomeTeam: home,
    strAwayTeam: away,
    strTimestamp: "2026-03-01 15:00:00",
  };
}

test("ingests every followed team's upcoming games, per user", async () => {
  const repos = new Map<string, FakeEventRepository>();
  const requestedTeamIds: string[] = [];

  const result = await pollUpcomingGames({
    listUserIds: async () => ["user-1", "user-2"],
    listFollowedTeamIds: async (uid) => (uid === "user-1" ? ["t1", "t2"] : ["t3"]),
    fetchUpcomingEventsRaw: async (teamId) => {
      requestedTeamIds.push(teamId);
      if (teamId === "t1") return [rawGame("g1")];
      if (teamId === "t2") return [rawGame("g2"), rawGame("g3")];
      if (teamId === "t3") return [rawGame("g4")];
      return [];
    },
    makeEventRepository: (uid) => {
      const repo = new FakeEventRepository();
      repos.set(uid, repo);
      return repo;
    },
  });

  assert.deepEqual(requestedTeamIds.sort(), ["t1", "t2", "t3"]);
  assert.equal(result.usersPolled, 2);
  assert.equal(result.teamsPolled, 3);
  assert.equal(result.eventsIngested, 4);

  const user1Events = repos.get("user-1")!.events;
  assert.equal(user1Events.length, 3);
  assert.ok(user1Events.every((e) => e.source === "sports" && e.tag === null));

  const user2Events = repos.get("user-2")!.events;
  assert.equal(user2Events.length, 1);
});

test("skips a user with no followed teams without touching their events", async () => {
  let repositoryCreated = false;

  const result = await pollUpcomingGames({
    listUserIds: async () => ["user-1"],
    listFollowedTeamIds: async () => [],
    fetchUpcomingEventsRaw: async () => {
      throw new Error("should never fetch games for a user with no followed teams");
    },
    makeEventRepository: () => {
      repositoryCreated = true;
      return new FakeEventRepository();
    },
  });

  assert.equal(repositoryCreated, false);
  assert.equal(result.usersPolled, 0);
  assert.equal(result.eventsIngested, 0);
});

test("re-polling the same games updates existing rows instead of duplicating them", async () => {
  const repo = new FakeEventRepository();

  const pollOnce = () =>
    pollUpcomingGames({
      listUserIds: async () => ["user-1"],
      listFollowedTeamIds: async () => ["t1"],
      fetchUpcomingEventsRaw: async () => [rawGame("g1")],
      makeEventRepository: () => repo,
    });

  await pollOnce();
  await pollOnce();

  assert.equal(repo.events.length, 1);
});

test("skips malformed games from the API rather than crashing the whole poll", async () => {
  const repo = new FakeEventRepository();

  const result = await pollUpcomingGames({
    listUserIds: async () => ["user-1"],
    listFollowedTeamIds: async () => ["t1"],
    fetchUpcomingEventsRaw: async () => [rawGame("g1"), { strHomeTeam: "No id" }],
    makeEventRepository: () => repo,
  });

  assert.equal(result.eventsIngested, 1);
  assert.equal(repo.events.length, 1);
  assert.equal(repo.events[0].sourceId, "g1");
});
