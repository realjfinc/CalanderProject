import '../models/calendar_event.dart';
import 'followed_teams_repository.dart';
import 'provider_adapter.dart';
import 'thesportsdb_client.dart';

/// A [ProviderAdapter] for Sports Mode: fetches upcoming games for every
/// team the user follows. Reuses the exact same [ingestProviderEvent]/
/// `syncProvider` pipeline Step 6's Google/Outlook/iCloud adapters use —
/// same shared dedup, same conflict detection, same canonical schema.
class SportsAdapter implements ProviderAdapter {
  SportsAdapter({required this.followedTeamsRepository, required this.apiClient});

  final FollowedTeamsRepository followedTeamsRepository;
  final TheSportsDbClient apiClient;

  @override
  EventSource get source => EventSource.sports;

  @override
  Future<List<CalendarEvent>> fetchEvents() async {
    final teams = await followedTeamsRepository.watchFollowedTeams().first;
    final events = <CalendarEvent>[];
    for (final team in teams) {
      final raw = await apiClient.fetchUpcomingEventsRaw(team.id);
      events.addAll(raw.map(mapSportsDbEvent).whereType<CalendarEvent>());
    }
    return events;
  }
}
