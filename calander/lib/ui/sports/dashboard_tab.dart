import 'package:flutter/material.dart';

import '../../models/calendar_event.dart';
import '../../models/followed_team.dart';
import '../../services/event_repository.dart';
import '../../services/followed_teams_repository.dart';
import '../../services/provider_sync.dart';
import '../../services/sports_adapter.dart';
import '../../services/thesportsdb_client.dart';

/// Shows followed teams and their next game, and a button to sync upcoming
/// games into the calendar (same dedup/conflict pipeline as Step 6).
class DashboardTab extends StatefulWidget {
  const DashboardTab({
    super.key,
    required this.followedTeamsRepository,
    required this.apiClient,
    required this.eventRepository,
  });

  final FollowedTeamsRepository followedTeamsRepository;
  final TheSportsDbClient apiClient;
  final EventRepository eventRepository;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _syncing = false;
  String? _status;

  Future<void> _syncToCalendar() async {
    setState(() {
      _syncing = true;
      _status = null;
    });
    try {
      await syncProvider(
        adapter: SportsAdapter(
          followedTeamsRepository: widget.followedTeamsRepository,
          apiClient: widget.apiClient,
        ),
        repository: widget.eventRepository,
      );
      setState(() => _status = 'Synced upcoming games to your calendar.');
    } catch (error) {
      setState(() => _status = 'Sync failed: $error');
    } finally {
      setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FollowedTeam>>(
      stream: widget.followedTeamsRepository.watchFollowedTeams(),
      builder: (context, snapshot) {
        final teams = snapshot.data ?? const [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: _syncing ? null : _syncToCalendar,
                    child: _syncing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
                        : const Text('Sync Upcoming Games to Calendar'),
                  ),
                  if (_status != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status!)),
                ],
              ),
            ),
            Expanded(
              child: teams.isEmpty
                  ? const Center(child: Text('Follow a team to see it here.'))
                  : ListView.builder(
                      itemCount: teams.length,
                      itemBuilder: (context, index) => _TeamTile(team: teams[index], apiClient: widget.apiClient),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({required this.team, required this.apiClient});

  final FollowedTeam team;
  final TheSportsDbClient apiClient;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CalendarEvent>>(
      future: apiClient.fetchUpcomingEventsRaw(team.id).then(
        (raw) => raw.map(mapSportsDbEvent).whereType<CalendarEvent>().toList(),
      ),
      builder: (context, snapshot) {
        final games = snapshot.data ?? const [];
        final nextGame = games.isEmpty ? null : games.first;
        return ListTile(
          title: Text(team.name),
          subtitle: Text(
            nextGame == null
                ? (snapshot.connectionState == ConnectionState.waiting ? 'Loading…' : 'No upcoming games')
                : '${nextGame.title} — ${nextGame.start.toLocal()}',
          ),
        );
      },
    );
  }
}
