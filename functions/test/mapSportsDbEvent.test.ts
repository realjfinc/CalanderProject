import assert from "node:assert/strict";
import { test } from "node:test";

import { mapSportsDbEvent } from "../src/sports/mapSportsDbEvent";

test("maps a game using strTimestamp as the UTC start time", () => {
  const event = mapSportsDbEvent({
    idEvent: "e-1",
    strHomeTeam: "Arsenal",
    strAwayTeam: "Chelsea",
    strVenue: "Emirates Stadium",
    strLeague: "English Premier League",
    strTimestamp: "2026-03-01 15:00:00",
  });

  assert.ok(event);
  assert.equal(event!.source, "sports");
  assert.equal(event!.sourceId, "e-1");
  assert.equal(event!.title, "Arsenal vs Chelsea");
  assert.equal(event!.location, "Emirates Stadium");
  assert.equal(event!.notes, "English Premier League");
  assert.equal(event!.start, new Date(Date.UTC(2026, 2, 1, 15)).toISOString());
  assert.equal(event!.tag, null);
});

test("falls back to dateEvent + strTime when strTimestamp is absent", () => {
  const event = mapSportsDbEvent({
    idEvent: "e-2",
    strHomeTeam: "A",
    strAwayTeam: "B",
    dateEvent: "2026-03-01",
    strTime: "15:00:00",
  });

  assert.equal(event!.start, new Date(Date.UTC(2026, 2, 1, 15)).toISOString());
});

test("falls back to midnight when strTime is also absent (all-day-ish)", () => {
  const event = mapSportsDbEvent({
    idEvent: "e-3",
    strHomeTeam: "A",
    strAwayTeam: "B",
    dateEvent: "2026-03-01",
  });

  assert.equal(event!.start, new Date(Date.UTC(2026, 2, 1)).toISOString());
});

test("defaults a 3-hour duration since the API has no end time", () => {
  const event = mapSportsDbEvent({
    idEvent: "e-4",
    strHomeTeam: "A",
    strAwayTeam: "B",
    strTimestamp: "2026-03-01 15:00:00",
  });

  assert.equal(event!.end, new Date(Date.UTC(2026, 2, 1, 18)).toISOString());
});

test("falls back to strEvent for the title when team names are missing", () => {
  const event = mapSportsDbEvent({
    idEvent: "e-5",
    strEvent: "Cup Final",
    strTimestamp: "2026-03-01 15:00:00",
  });

  assert.equal(event!.title, "Cup Final");
});

test("returns null without an id or without any parseable time", () => {
  assert.equal(mapSportsDbEvent({ strTimestamp: "2026-03-01 15:00:00" }), null);
  assert.equal(mapSportsDbEvent({ idEvent: "e-6" }), null);
});

test("a newly mapped game never carries a tag or a conflict role", () => {
  const event = mapSportsDbEvent({
    idEvent: "e-7",
    strHomeTeam: "A",
    strAwayTeam: "B",
    strTimestamp: "2026-03-01 15:00:00",
  });

  assert.equal(event!.tag, null);
  assert.equal(event!.status, "active");
  assert.equal(event!.conflictGroupId, null);
  assert.equal(event!.conflictRole, null);
});
