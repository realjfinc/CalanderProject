import { newSourceEvent, type CanonicalEventData } from "../shared/canonicalEvent";

/**
 * Server-side port of the Flutter client's `mapSportsDbEvent`
 * (`lib/services/thesportsdb_client.dart`) -- kept behaviorally identical
 * (same fallback order, same 3-hour default duration, same UTC trust in
 * TheSportsDB's documented-UTC fields) so a game ingested by this
 * scheduled poll is indistinguishable from one a client pulled via the
 * dashboard's manual "Sync Now" button.
 *
 * Returns null for a game with no id or no parseable time.
 */
export function mapSportsDbEvent(json: Record<string, unknown>): CanonicalEventData | null {
  const id = typeof json.idEvent === "string" ? json.idEvent : null;
  if (id === null) return null;

  const start = parseUtcStart(json);
  if (start === null) return null;
  // TheSportsDB doesn't provide an end time; a game's actual duration
  // varies by sport, so this is a documented, deliberately generous guess
  // rather than a claim of precision.
  const end = new Date(start.getTime() + 3 * 60 * 60 * 1000);

  const home = typeof json.strHomeTeam === "string" ? json.strHomeTeam : null;
  const away = typeof json.strAwayTeam === "string" ? json.strAwayTeam : null;
  const title =
    home !== null && away !== null
      ? `${home} vs ${away}`
      : typeof json.strEvent === "string"
        ? json.strEvent
        : "Game";

  return newSourceEvent({
    title,
    location: typeof json.strVenue === "string" ? json.strVenue : null,
    start: start.toISOString(),
    end: end.toISOString(),
    source: "sports",
    sourceId: id,
    notes: typeof json.strLeague === "string" ? json.strLeague : null,
  });
}

function parseUtcStart(json: Record<string, unknown>): Date | null {
  const timestamp = typeof json.strTimestamp === "string" ? json.strTimestamp.trim() : "";
  if (timestamp !== "") {
    const parsed = new Date(`${timestamp.replace(" ", "T")}Z`);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  const date = typeof json.dateEvent === "string" ? json.dateEvent.trim() : "";
  if (date === "") return null;
  const time = typeof json.strTime === "string" ? json.strTime.trim() : "";
  const timePart = time === "" ? "00:00:00" : time;
  const parsed = new Date(`${date}T${timePart}Z`);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}
