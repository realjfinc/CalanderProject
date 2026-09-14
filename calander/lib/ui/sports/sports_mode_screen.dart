import 'package:flutter/material.dart';

import '../../services/event_repository.dart';
import '../../services/followed_teams_repository.dart';
import '../../services/thesportsdb_client.dart';
import 'dashboard_tab.dart';
import 'follow_team_tab.dart';

/// Entry point for Step 7: a dashboard of followed teams' upcoming games,
/// and a tab to find and follow/unfollow teams.
class SportsModeScreen extends StatelessWidget {
  const SportsModeScreen({
    super.key,
    required this.followedTeamsRepository,
    required this.eventRepository,
    this.apiClient,
    this.bottomNavigationBar,
  });

  final FollowedTeamsRepository followedTeamsRepository;
  final EventRepository eventRepository;
  final TheSportsDbClient? apiClient;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final apiClient = this.apiClient ?? TheSportsDbClient();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        bottomNavigationBar: bottomNavigationBar,
        appBar: AppBar(
          automaticallyImplyLeading: bottomNavigationBar == null,
          title: const Text('Sports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Follow Teams'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DashboardTab(
              followedTeamsRepository: followedTeamsRepository,
              eventRepository: eventRepository,
            ),
            FollowTeamTab(
              repository: followedTeamsRepository,
              apiClient: apiClient,
            ),
          ],
        ),
      ),
    );
  }
}
