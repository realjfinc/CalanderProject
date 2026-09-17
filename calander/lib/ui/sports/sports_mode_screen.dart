import 'package:flutter/material.dart';

import '../../services/event_repository.dart';
import '../../services/followed_teams_repository.dart';
import '../../services/sports_games_cache_repository.dart';
import '../../services/sports_onboarding_repository.dart';
import '../../services/thesportsdb_client.dart';
import 'dashboard_tab.dart';
import 'follow_team_tab.dart';
import 'sports_onboarding_screen.dart';

/// Entry point for Step 7. First-time visitors (per
/// [SportsOnboardingRepository]) see [SportsOnboardingScreen] to pick their
/// teams before anything else; everyone after that goes straight to the
/// usual dashboard of followed teams' upcoming games, and a tab to find and
/// follow/unfollow more.
class SportsModeScreen extends StatefulWidget {
  const SportsModeScreen({
    super.key,
    required this.followedTeamsRepository,
    required this.eventRepository,
    required this.onboardingRepository,
    this.apiClient,
    this.gamesCacheRepository,
    this.bottomNavigationBar,
  });

  final FollowedTeamsRepository followedTeamsRepository;
  final EventRepository eventRepository;
  final SportsOnboardingRepository onboardingRepository;
  final TheSportsDbClient? apiClient;
  final SportsGamesCacheRepository? gamesCacheRepository;
  final Widget? bottomNavigationBar;

  @override
  State<SportsModeScreen> createState() => _SportsModeScreenState();
}

class _SportsModeScreenState extends State<SportsModeScreen> {
  late final TheSportsDbClient _apiClient = widget.apiClient ?? TheSportsDbClient();
  late final SportsGamesCacheRepository _gamesCacheRepository =
      widget.gamesCacheRepository ?? FirestoreSportsGamesCacheRepository();
  late final Future<bool> _onboardedFuture = widget.onboardingRepository.hasCompletedOnboarding();
  bool _skipOnboardingGate = false;

  @override
  Widget build(BuildContext context) {
    if (_skipOnboardingGate) return _tabs();

    return FutureBuilder<bool>(
      future: _onboardedFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == true) return _tabs();
        return SportsOnboardingScreen(
          followedTeamsRepository: widget.followedTeamsRepository,
          onboardingRepository: widget.onboardingRepository,
          apiClient: _apiClient,
          gamesCacheRepository: _gamesCacheRepository,
          eventRepository: widget.eventRepository,
          onDone: () => setState(() => _skipOnboardingGate = true),
        );
      },
    );
  }

  Widget _tabs() {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        bottomNavigationBar: widget.bottomNavigationBar,
        appBar: AppBar(
          automaticallyImplyLeading: widget.bottomNavigationBar == null,
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
              followedTeamsRepository: widget.followedTeamsRepository,
              eventRepository: widget.eventRepository,
            ),
            FollowTeamTab(
              repository: widget.followedTeamsRepository,
              apiClient: _apiClient,
              gamesCacheRepository: _gamesCacheRepository,
              eventRepository: widget.eventRepository,
            ),
          ],
        ),
      ),
    );
  }
}
