import 'package:flutter/material.dart';

import '../../services/event_repository.dart';
import '../../services/tag_repository.dart';
import '../../services/tag_routing_repository.dart';
import 'event_tags_tab.dart';
import 'tag_rules_tab.dart';

/// Entry point for Step 5: assign/override tags on events, and manage the
/// auto-tagging rules that propose a tag for new untagged ones.
class TagRoutingScreen extends StatelessWidget {
  const TagRoutingScreen({
    super.key,
    required this.eventRepository,
    required this.tagRepository,
    required this.routingRepository,
  });

  final EventRepository eventRepository;
  final TagRepository tagRepository;
  final TagRoutingRepository routingRepository;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tag Routing'),
          bottom: const TabBar(tabs: [Tab(text: 'Events'), Tab(text: 'Auto-Tag Rules')]),
        ),
        body: TabBarView(
          children: [
            EventTagsTab(eventRepository: eventRepository, tagRepository: tagRepository),
            TagRulesTab(routingRepository: routingRepository, tagRepository: tagRepository),
          ],
        ),
      ),
    );
  }
}
