import assert from "node:assert/strict";
import { test } from "node:test";

import { ingestProviderEvent } from "../src/shared/ingestProviderEvent";
import { newSourceEvent, type CanonicalEvent } from "../src/shared/canonicalEvent";
import type { EventRepository } from "../src/shared/eventRepository";

class FakeEventRepository implements EventRepository {
  events: CanonicalEvent[] = [];
  private nextId = 1;

  async listEvents(): Promise<CanonicalEvent[]> {
    return this.events;
  }

  async addEvent(event: Parameters<EventRepository["addEvent"]>[0]): Promise<string> {
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

function game(overrides: Partial<Parameters<typeof newSourceEvent>[0]> = {}) {
  return newSourceEvent({
    title: "Arsenal vs Chelsea",
    location: "Emirates Stadium",
    start: "2026-03-01T15:00:00.000Z",
    end: "2026-03-01T18:00:00.000Z",
    source: "sports",
    sourceId: "g1",
    notes: "EPL",
    ...overrides,
  });
}

test("a genuinely new event is added as-is", async () => {
  const repository = new FakeEventRepository();
  const result = await ingestProviderEvent({ repository, incoming: game(), currentEvents: [] });

  assert.equal(result.title, "Arsenal vs Chelsea");
  assert.equal(result.tag, null);
  assert.equal(result.status, "active");
  assert.equal(repository.events.length, 1);
});

test("resyncing the same (source, sourceId) updates in place and preserves a manually-set tag", async () => {
  const repository = new FakeEventRepository();
  const first = await ingestProviderEvent({ repository, incoming: game(), currentEvents: [] });

  // Simulate the user (or Step 5's routing) tagging the event.
  const tagged: CanonicalEvent = { ...first, tag: "Sports" };
  await repository.updateEvent(tagged);

  const resynced = await ingestProviderEvent({
    repository,
    incoming: game({ location: "New Venue" }),
    currentEvents: [tagged],
  });

  assert.equal(resynced.id, first.id);
  assert.equal(resynced.tag, "Sports", "a source adapter must never clobber an existing tag");
  assert.equal(resynced.location, "New Venue", "non-tag fields still refresh from the source");
  assert.equal(repository.events.length, 1);
});

test("a similar title and close start time from a different source becomes a linked pending conflict", async () => {
  const repository = new FakeEventRepository();
  const existing = await ingestProviderEvent({
    repository,
    incoming: newSourceEvent({
      title: "Arsenal vs Chelsea",
      location: null,
      start: "2026-03-01T15:00:00.000Z",
      end: "2026-03-01T17:00:00.000Z",
      source: "google",
      sourceId: "cal-1",
      notes: null,
    }),
    currentEvents: [],
  });

  const incomingSportsGame = game();
  const result = await ingestProviderEvent({
    repository,
    incoming: incomingSportsGame,
    currentEvents: [existing],
  });

  assert.equal(result.status, "pendingConflict");
  assert.equal(result.conflictRole, "new");
  assert.ok(result.conflictGroupId);

  const updatedOriginal = repository.events.find((e) => e.id === existing.id)!;
  assert.equal(updatedOriginal.status, "pendingConflict");
  assert.equal(updatedOriginal.conflictRole, "original");
  assert.equal(updatedOriginal.conflictGroupId, result.conflictGroupId);
});

test("regression: resyncing both sides of a conflict repeatedly never loses conflictRole", async () => {
  // Guards the exact Step 6 bug: an early version of this copyWith/spread
  // omitted conflictRole, silently defaulting it to null on every resync
  // and corrupting the conflict pair (groupConflicts needs exactly one
  // 'original' + one 'new' per group).
  const repository = new FakeEventRepository();
  const original = await ingestProviderEvent({
    repository,
    incoming: newSourceEvent({
      title: "Arsenal vs Chelsea",
      location: null,
      start: "2026-03-01T15:00:00.000Z",
      end: "2026-03-01T17:00:00.000Z",
      source: "google",
      sourceId: "cal-1",
      notes: null,
    }),
    currentEvents: [],
  });

  let currentEvents = [original];
  let newSide = await ingestProviderEvent({ repository, incoming: game(), currentEvents });
  currentEvents = [repository.events.find((e) => e.id === original.id)!, newSide];

  for (let i = 0; i < 3; i++) {
    const originalNow = repository.events.find((e) => e.id === original.id)!;
    newSide = await ingestProviderEvent({
      repository,
      incoming: game(),
      currentEvents: [originalNow, newSide],
    });
    currentEvents = [originalNow, newSide];
  }

  const finalOriginal = repository.events.find((e) => e.id === original.id)!;
  const finalNew = repository.events.find((e) => e.id === newSide.id)!;
  assert.equal(finalOriginal.conflictRole, "original");
  assert.equal(finalNew.conflictRole, "new");
  assert.equal(finalOriginal.conflictGroupId, finalNew.conflictGroupId);
  assert.equal(repository.events.length, 2, "resyncing must never create duplicate rows");
});

test("throws if an incoming event already carries a tag", async () => {
  const repository = new FakeEventRepository();
  await assert.rejects(
    ingestProviderEvent({
      repository,
      incoming: { ...game(), tag: "Sports" },
      currentEvents: [],
    }),
  );
});
