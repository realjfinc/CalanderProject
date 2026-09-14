import 'package:flutter/material.dart';

import '../../models/followed_team.dart';
import '../../services/followed_teams_repository.dart';
import '../../services/thesportsdb_client.dart';
import '../calendar/calendar_widgets.dart';
import 'sports_style.dart';

/// Search for a team and follow/unfollow it.
class FollowTeamTab extends StatefulWidget {
  const FollowTeamTab({
    super.key,
    required this.repository,
    required this.apiClient,
  });

  final FollowedTeamsRepository repository;
  final TheSportsDbClient apiClient;

  @override
  State<FollowTeamTab> createState() => _FollowTeamTabState();
}

class _FollowTeamTabState extends State<FollowTeamTab> {
  final _queryController = TextEditingController();
  List<FollowedTeam>? _results;
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.apiClient.searchTeams(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (error) {
      if (mounted) setState(() => _error = 'Search failed: $error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FollowedTeam>>(
      stream: widget.repository.watchFollowedTeams(),
      builder: (context, followedSnapshot) {
        final followedIds = (followedSnapshot.data ?? const [])
            .map((t) => t.id)
            .toSet();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      decoration: const InputDecoration(
                        labelText: 'Search for a team',
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  IconButton(
                    icon: _searching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(),
                          )
                        : const Icon(Icons.search),
                    onPressed: _searching ? null : _search,
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
            Expanded(
              child: ListView(
                children: [
                  if (_results != null)
                    for (final team in _results!)
                      ListTile(
                        leading: TeamBadge(
                          name: team.name,
                          badgeUrl: team.badgeUrl,
                          color: parseHexColor(team.accentColorHex),
                          size: 36,
                        ),
                        title: Text(team.name),
                        subtitle: Text(team.league),
                        trailing: SizedBox(
                          // The app theme gives every OutlinedButton a
                          // full-width, 52-tall minimum size (right for a
                          // standalone primary action, wrong for a compact
                          // trailing action inside a ListTile -- left
                          // themed, it fights the tile's layout and paints
                          // an overflow artifact on top of the row).
                          // _compactButtonStyle overrides that here.
                          height: 36,
                          child: followedIds.contains(team.id)
                              ? OutlinedButton(
                                  style: _compactButtonStyle(context),
                                  onPressed: () => runCalendarAction(
                                    context,
                                    () => widget.repository.unfollowTeam(team.id),
                                  ),
                                  child: const Text('Unfollow'),
                                )
                              : ElevatedButton(
                                  style: _compactButtonStyle(context),
                                  onPressed: () => runCalendarAction(
                                    context,
                                    () => widget.repository.followTeam(team),
                                  ),
                                  child: const Text('Follow'),
                                ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A compact size for Follow/Unfollow's ListTile.trailing slot, overriding
/// the app theme's full-width-52 default (meant for standalone primary
/// buttons) which would otherwise overflow the row.
ButtonStyle _compactButtonStyle(BuildContext context) => ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
  textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.bodyMedium),
);
