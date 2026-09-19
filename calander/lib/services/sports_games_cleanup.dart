import '../models/calendar_event.dart';
import '../models/followed_team.dart';
import 'event_repository.dart';

/// Removes every synced game belonging to [team] from the user's own
/// calendar -- the reverse of `sports_games_backfill.dart`'s
/// `backfillCachedGamesForTeam`, called on unfollow so an unfollowed
/// team's games don't linger as orphaned events.
///
/// The canonical event schema carries no team id, only a title of the
/// form `"$home vs $away"` (see `mapSportsDbEvent`) -- the same signal
/// `dashboard_tab.dart`'s `nextGameForTeam` already uses to find a
/// team's games, reused here so "what counts as this team's game" stays
/// consistent between showing it and removing it. A game between two
/// teams the user follows both of is a known edge case this can't
/// distinguish -- unfollowing either side removes it, same as neither
/// side being tracked as "belongs to team X" anywhere in the schema.
Future<void> removeTeamGamesFromCalendar({
  required FollowedTeam team,
  required EventRepository eventRepository,
}) async {
  final events = await eventRepository.watchEvents().first;
  final teamName = team.name.toLowerCase();
  // Materialized before the delete loop below -- some EventRepository
  // implementations (e.g. an in-memory fake backed by the same list this
  // stream reads from) would otherwise have this lazy filter re-evaluate
  // against a list that's shrinking out from under it mid-iteration,
  // silently skipping matches as indices shift.
  final matches = events
      .where((event) => event.source == EventSource.sports && event.title.toLowerCase().contains(teamName))
      .toList();
  for (final event in matches) {
    await eventRepository.deleteEvent(event.id);
  }
}
