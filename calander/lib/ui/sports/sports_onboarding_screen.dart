import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/followed_team.dart';
import '../../services/event_repository.dart';
import '../../services/followed_teams_repository.dart';
import '../../services/sports_games_backfill.dart';
import '../../services/sports_games_cache_repository.dart';
import '../../services/sports_onboarding_repository.dart';
import '../../services/thesportsdb_client.dart';
import '../calendar/calendar_widgets.dart';
import 'sports_style.dart';

/// A handful of well-known teams across different sports/leagues, verified
/// against TheSportsDB's real search API -- tapping one runs the same real
/// search a manual query would, just pre-filled, so this list is a
/// shortcut into real data, never a hardcoded substitute for it.
const List<String> _quickPickNames = [
  'Arsenal',
  'Real Madrid',
  'Manchester United',
  'Barcelona',
  'Liverpool',
  'Los Angeles Lakers',
  'Golden State Warriors',
  'Boston Celtics',
  'Chicago Bulls',
  'New York Yankees',
  'Dallas Cowboys',
  'Kansas City Chiefs',
];

/// First-time Sports Mode experience: pick a few teams before landing on
/// the dashboard, instead of opening onto an empty "follow a team" prompt.
/// Shown exactly once per account (see [SportsOnboardingRepository]);
/// picking zero teams and tapping "Skip" still counts as done.
class SportsOnboardingScreen extends StatefulWidget {
  const SportsOnboardingScreen({
    super.key,
    required this.followedTeamsRepository,
    required this.onboardingRepository,
    required this.apiClient,
    required this.gamesCacheRepository,
    required this.eventRepository,
    required this.onDone,
  });

  final FollowedTeamsRepository followedTeamsRepository;
  final SportsOnboardingRepository onboardingRepository;
  final TheSportsDbClient apiClient;
  final SportsGamesCacheRepository gamesCacheRepository;
  final EventRepository eventRepository;
  final VoidCallback onDone;

  @override
  State<SportsOnboardingScreen> createState() => _SportsOnboardingScreenState();
}

class _SportsOnboardingScreenState extends State<SportsOnboardingScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final Map<String, FollowedTeam> _selected = {}; // keyed by team id
  final Map<String, FollowedTeam> _resolvedQuickPicks = {}; // keyed by chip name
  final Set<String> _loadingQuickPicks = {};

  List<FollowedTeam>? _searchResults;
  bool _searching = false;
  String? _searchError;
  bool _finishing = false;

  late final AnimationController _breathController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _breathController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleTeam(FollowedTeam team) {
    setState(() {
      if (_selected.containsKey(team.id)) {
        _selected.remove(team.id);
      } else {
        _selected[team.id] = team;
      }
    });
  }

  Future<void> _tapQuickPick(String name) async {
    final existing = _resolvedQuickPicks[name];
    if (existing != null) {
      _toggleTeam(existing);
      return;
    }
    setState(() => _loadingQuickPicks.add(name));
    try {
      final results = await widget.apiClient.searchTeams(name);
      if (!mounted) return;
      if (results.isEmpty) {
        setState(() => _loadingQuickPicks.remove(name));
        return;
      }
      final team = results.first;
      setState(() {
        _resolvedQuickPicks[name] = team;
        _selected[team.id] = team;
        _loadingQuickPicks.remove(name);
      });
    } catch (_) {
      if (mounted) setState(() => _loadingQuickPicks.remove(name));
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await widget.apiClient.searchTeams(query);
      if (mounted) setState(() => _searchResults = results);
    } catch (error) {
      if (mounted) setState(() => _searchError = 'Search failed: $error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      for (final team in _selected.values) {
        await widget.followedTeamsRepository.followTeam(team);
        // Best-effort: the hourly poller will pick this team up regardless,
        // so a cache read/ingest hiccup here shouldn't block onboarding.
        try {
          await backfillCachedGamesForTeam(
            team: team,
            gamesCacheRepository: widget.gamesCacheRepository,
            eventRepository: widget.eventRepository,
          );
        } catch (_) {
          // Ignored -- see above.
        }
      }
      await widget.onboardingRepository.completeOnboarding();
      widget.onDone();
    } catch (error) {
      if (mounted) {
        setState(() => _finishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(calendarError(error))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(breath: _breathController),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                children: [
                  Text(
                    'Popular teams',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to follow — their schedule starts syncing right away.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final name in _quickPickNames)
                        _QuickPickChip(
                          name: name,
                          team: _resolvedQuickPicks[name],
                          loading: _loadingQuickPicks.contains(name),
                          selected: _resolvedQuickPicks[name] != null &&
                              _selected.containsKey(_resolvedQuickPicks[name]!.id),
                          onTap: () => _tapQuickPick(name),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Search for another team',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(hintText: 'Any team, any sport'),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _searching ? null : _search,
                        icon: _searching
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.search),
                      ),
                    ],
                  ),
                  if (_searchError != null) ...[
                    const SizedBox(height: 8),
                    Text(_searchError!, style: TextStyle(color: scheme.error)),
                  ],
                  if (_searchResults != null) ...[
                    const SizedBox(height: 12),
                    if (_searchResults!.isEmpty)
                      const Text('No teams matched that search.')
                    else
                      for (final team in _searchResults!)
                        _SearchResultTile(
                          team: team,
                          selected: _selected.containsKey(team.id),
                          onTap: () => _toggleTeam(team),
                        ),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        selected: _selected.values.toList(),
        finishing: _finishing,
        pulse: _pulseController,
        onRemove: (team) => _toggleTeam(team),
        onContinue: _finish,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.breath});

  final Animation<double> breath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: breath,
      builder: (context, child) {
        final t = breath.value;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(scheme.primary, const Color(0xFF7C3AED), t * 0.5)!,
                Color.lerp(const Color(0xFF0EA5E9), scheme.primary, t)!,
              ],
            ),
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TicketStack(),
          const SizedBox(height: 18),
          Text(
            'Never miss a game.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Follow your teams and their schedule lands straight on your calendar — no digging, no checking scores by hand.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: .88)),
          ),
        ],
      ),
    );
  }
}

/// A little fanned-out "ticket stack" built from plain rotated rounded
/// rectangles -- no image assets, just a bit of motif to set the scene.
class _TicketStack extends StatelessWidget {
  const _TicketStack();

  @override
  Widget build(BuildContext context) {
    Widget card(double angle, double dx, Color color) => Transform.translate(
      offset: Offset(dx, 0),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 46,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
          ),
        ),
      ),
    );
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          card(-0.22, 0, Colors.white.withValues(alpha: .55)),
          card(-0.05, 18, Colors.white.withValues(alpha: .75)),
          card(0.14, 36, Colors.white),
        ],
      ),
    );
  }
}

class _QuickPickChip extends StatelessWidget {
  const _QuickPickChip({
    required this.name,
    required this.team,
    required this.loading,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final FollowedTeam? team;
  final bool loading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = parseHexColor(team?.accentColorHex) ?? scheme.primary;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedScale(
        scale: selected ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: .14) : scheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? accent : scheme.outline, width: selected ? 1.6 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (team != null)
                TeamBadge(name: team!.name, badgeUrl: team!.badgeUrl, color: accent, size: 20)
              else
                Icon(Icons.add_circle_outline, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                team?.name ?? name,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : null,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle, size: 16, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.team, required this.selected, required this.onTap});

  final FollowedTeam team;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = parseHexColor(team.accentColorHex) ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                TeamBadge(name: team.name, badgeUrl: team.badgeUrl, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(team.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(team.league, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: selected
                      ? Icon(Icons.check_circle, color: accent, key: const ValueKey('on'))
                      : Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.onSurfaceVariant, key: const ValueKey('off')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.selected,
    required this.finishing,
    required this.pulse,
    required this.onRemove,
    required this.onContinue,
  });

  final List<FollowedTeam> selected;
  final bool finishing;
  final Animation<double> pulse;
  final ValueChanged<FollowedTeam> onRemove;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSelection = selected.isNotEmpty;
    return Material(
      color: scheme.surface,
      shape: Border(top: BorderSide(color: scheme.outline)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: hasSelection
                    ? SizedBox(
                        height: 46,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: selected.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final team = selected[index];
                            return TweenAnimationBuilder<double>(
                              key: ValueKey(team.id),
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutBack,
                              builder: (context, value, child) => Transform.scale(scale: value, child: child),
                              child: InputChip(
                                avatar: TeamBadge(name: team.name, badgeUrl: team.badgeUrl, size: 22),
                                label: Text(team.name),
                                onDeleted: () => onRemove(team),
                              ),
                            );
                          },
                        ),
                      )
                    : const SizedBox(height: 8),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: finishing ? null : onContinue,
                      child: Text(hasSelection ? 'Skip the rest' : 'Skip for now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AnimatedBuilder(
                      animation: pulse,
                      builder: (context, child) {
                        final scale = hasSelection ? 1.0 + pulse.value * 0.02 : 1.0;
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: FilledButton(
                        onPressed: finishing ? null : onContinue,
                        child: finishing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                hasSelection
                                    ? 'Continue with ${selected.length} ${selected.length == 1 ? 'team' : 'teams'}'
                                    : 'Continue',
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
