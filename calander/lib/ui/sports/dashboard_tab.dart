import 'package:flutter/material.dart';

import '../../models/calendar_event.dart';
import '../../models/followed_team.dart';
import '../../services/event_repository.dart';
import '../../services/followed_teams_repository.dart';

/// Shows each followed team's next game.
///
/// Deliberately makes no TheSportsDB call of its own -- game data comes
/// entirely from this user's already-synced calendar events. Keeping
/// those current is the scheduled poller's job (`functions/`'s
/// `pollSportsEvents` or `scripts/sports_poller/`'s Python equivalent),
/// not something a person has to remember to trigger from here.
class DashboardTab extends StatelessWidget {
  const DashboardTab({
    super.key,
    required this.followedTeamsRepository,
    required this.eventRepository,
  });

  final FollowedTeamsRepository followedTeamsRepository;
  final EventRepository eventRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FollowedTeam>>(
      stream: followedTeamsRepository.watchFollowedTeams(),
      builder: (context, teamsSnapshot) {
        final teams = teamsSnapshot.data ?? const [];
        if (teams.isEmpty) {
          return const Center(child: Text('Follow a team to see it here.'));
        }
        return StreamBuilder<List<CalendarEvent>>(
          stream: eventRepository.watchEvents(),
          builder: (context, eventsSnapshot) {
            final events = eventsSnapshot.data ?? const [];
            return ListView.builder(
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index];
                final nextGame = nextGameForTeam(team, events);
                return ListTile(
                  title: Text(team.name),
                  subtitle: Text(
                    nextGame == null
                        ? 'No upcoming games synced yet'
                        : '${nextGame.title} — ${nextGame.start.toLocal()}',
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// The earliest still-upcoming synced game whose title mentions this
/// team, or null if none. The canonical event schema doesn't carry a
/// team id (only `notes` = league name), so this matches the same way a
/// person reading the title would -- `mapSportsDbEvent`'s title is always
/// `"$home vs $away"` when both team names are known, so a followed
/// team's own name reliably appears in its games' titles.
CalendarEvent? nextGameForTeam(FollowedTeam team, List<CalendarEvent> events) {
  final now = DateTime.now().toUtc();
  final teamName = team.name.toLowerCase();
  final upcoming =
      events.where((event) {
          if (event.source != EventSource.sports) return false;
          if (!event.start.isAfter(now)) return false;
          return event.title.toLowerCase().contains(teamName);
        }).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  return upcoming.isEmpty ? null : upcoming.first;
}
