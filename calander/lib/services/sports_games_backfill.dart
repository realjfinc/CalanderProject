import '../models/followed_team.dart';
import 'event_repository.dart';
import 'provider_sync.dart';
import 'sports_games_cache_repository.dart';

/// Copies a newly followed team's already-cached upcoming games (see
/// [SportsGamesCacheRepository]) into the user's own events right away,
/// through the same dedup/conflict pipeline every other source uses --
/// instead of waiting for that team's next hourly poll. A no-op, not an
/// error, if the cache has nothing for this team yet (e.g. its first poll
/// hasn't run since it entered the catalog).
Future<void> backfillCachedGamesForTeam({
  required FollowedTeam team,
  required SportsGamesCacheRepository gamesCacheRepository,
  required EventRepository eventRepository,
}) async {
  final cachedGames = await gamesCacheRepository.fetchCachedGames(team.id);
  if (cachedGames.isEmpty) return;

  await ingestProviderEvents(incomingEvents: cachedGames, repository: eventRepository);
}
