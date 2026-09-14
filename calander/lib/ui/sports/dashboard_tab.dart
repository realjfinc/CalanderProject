import 'package:flutter/material.dart';

import '../../models/calendar_event.dart';
import '../../models/followed_team.dart';
import '../../services/event_repository.dart';
import '../../services/followed_teams_repository.dart';
import 'sports_style.dart';

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
        if (teamsSnapshot.hasError) {
          return const Center(
            child: Text('Unable to load your teams. Please try again later.'),
          );
        }
        if (!teamsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final teams = teamsSnapshot.data ?? const [];
        if (teams.isEmpty) {
          return const _EmptyState();
        }
        return StreamBuilder<List<CalendarEvent>>(
          stream: eventRepository.watchEvents(),
          builder: (context, eventsSnapshot) {
            if (eventsSnapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load upcoming games. Please try again later.',
                ),
              );
            }
            final events = eventsSnapshot.data ?? const [];
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index];
                final nextGame = nextGameForTeam(team, events);
                return _StaggeredEntrance(
                  key: ValueKey(team.id),
                  index: index,
                  child: _MatchCard(team: team, nextGame: nextGame),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Fades and slides a card in once, the first time its key appears in the
/// tree -- Flutter keeps this element (and its animation progress) alive
/// across later rebuilds at the same key, so a live stream update never
/// replays the entrance for cards that were already on screen.
class _StaggeredEntrance extends StatelessWidget {
  const _StaggeredEntrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, (1 - value) * 18), child: child),
      ),
      child: child,
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.team, required this.nextGame});

  final FollowedTeam team;
  final CalendarEvent? nextGame;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = parseHexColor(team.accentColorHex) ?? scheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TeamBadge(name: team.name, badgeUrl: team.badgeUrl, color: accent, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(team.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                if (team.league.isNotEmpty)
                                  Text(
                                    team.league,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (nextGame == null)
                        Text(
                          'No upcoming games synced yet',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        _NextGameStrip(accent: accent, game: nextGame!),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextGameStrip extends StatelessWidget {
  const _NextGameStrip({required this.accent, required this.game});

  final Color accent;
  final CalendarEvent game;

  @override
  Widget build(BuildContext context) {
    final when = relativeGameLabel(game.start);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(game.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  TimeOfDay.fromDateTime(game.start.toLocal()).format(context),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(999)),
            child: Text(
              when,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (context, value, child) => Transform.scale(scale: value, child: child),
              child: Icon(Icons.sports_soccer, size: 48, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Your teams. Your calendar.',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text('Follow a team to see it here.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => DefaultTabController.of(context).animateTo(1),
              child: const Text('Find teams'),
            ),
          ],
        ),
      ),
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
  final upcoming = events.where((event) {
    if (event.source != EventSource.sports) return false;
    if (!event.start.isAfter(now)) return false;
    return event.title.toLowerCase().contains(teamName);
  }).toList()..sort((a, b) => a.start.compareTo(b.start));
  return upcoming.isEmpty ? null : upcoming.first;
}
