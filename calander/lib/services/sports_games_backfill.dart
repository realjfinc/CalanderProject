import '../models/calendar_event.dart';
import '../models/followed_team.dart';
import 'event_repository.dart';
import 'provider_sync.dart';
import 'sports_games_cache_repository.dart';
import 'thesportsdb_client.dart';

/// Copies a newly followed team's already-cached upcoming games (see
/// [SportsGamesCacheRepository]) into the user's own events right away,
/// through the same dedup/conflict pipeline every other source uses --
/// instead of waiting for that team's next hourly poll.
///
/// If nothing's cached yet for this team (it's outside what the poller's
/// catalog has reached so far -- e.g. a team just added to the API, or one
/// still waiting its turn behind this free key's rate limit), fetches it
/// live from TheSportsDB instead, writes it into the shared cache so the
/// next person who follows this team doesn't have to, then ingests it the
/// same way. A no-op, not an error, if the team genuinely has no upcoming
/// games right now (live fetch returns empty) or the live fetch itself
/// fails -- the next hourly poll retries regardless.
Future<void> backfillCachedGamesForTeam({
  required FollowedTeam team,
  required SportsGamesCacheRepository gamesCacheRepository,
  required EventRepository eventRepository,
  required TheSportsDbClient apiClient,
}) async {
  var games = await gamesCacheRepository.fetchCachedGames(team.id);

  if (games.isEmpty) {
    try {
      final raw = await apiClient.fetchUpcomingEventsRaw(team.id);
      games = raw.map(mapSportsDbEvent).whereType<CalendarEvent>().toList();
    } catch (_) {
      return;
    }
    if (games.isEmpty) return;

    try {
      await gamesCacheRepository.cacheGames(team.id, games);
    } catch (_) {
      // Best-effort: still ingest into this user's own events below even
      // if sharing the find with the cache failed (e.g. this account is
      // near its hourly write quota) -- the next poll backfills the cache.
    }
  }

  await ingestProviderEvents(
    incomingEvents: games
        .map((game) => game.copyWith(sportsTeamIds: [team.id]))
        .toList(),
    repository: eventRepository,
  );
}
