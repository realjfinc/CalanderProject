import 'package:flutter/material.dart';

import '../../services/event_repository.dart';
import 'conflicts_tab.dart';
import 'connected_accounts_tab.dart';

/// Entry point for Step 6: connect/sync provider calendars, and resolve
/// any cross-source conflicts sync detected.
class ProviderSyncScreen extends StatelessWidget {
  const ProviderSyncScreen({super.key, required this.eventRepository});

  final EventRepository eventRepository;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Provider Sync'),
          bottom: const TabBar(tabs: [Tab(text: 'Connected Accounts'), Tab(text: 'Conflicts')]),
        ),
        body: TabBarView(
          children: [
            ConnectedAccountsTab(eventRepository: eventRepository),
            ConflictsTab(eventRepository: eventRepository),
          ],
        ),
      ),
    );
  }
}
