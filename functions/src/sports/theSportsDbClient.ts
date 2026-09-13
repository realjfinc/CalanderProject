export class SportsApiError extends Error {}

/**
 * Node 20 (this project's pinned Functions runtime) has `fetch` built in
 * globally -- no extra HTTP dependency needed, matching the client's own
 * minimal-dependency choice of TheSportsDB specifically because it needs
 * no OAuth/API-key setup (see `lib/services/thesportsdb_client.dart`).
 */
export async function fetchUpcomingEventsRaw(
  teamId: string,
  apiKey = "3",
): Promise<Record<string, unknown>[]> {
  const url = `https://www.thesportsdb.com/api/v1/json/${apiKey}/eventsnext.php?id=${encodeURIComponent(teamId)}`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new SportsApiError(`Upcoming events request failed with status ${response.status}`);
  }
  const body = (await response.json()) as { events?: Record<string, unknown>[] | null };
  return body.events ?? [];
}
