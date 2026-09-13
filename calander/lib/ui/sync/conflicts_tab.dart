import 'package:flutter/material.dart';

import '../../models/calendar_event.dart';
import '../../services/conflict_resolver.dart';
import '../../services/event_repository.dart';

/// Lets the user resolve each cross-source conflict `event_sync.dart`
/// detected. Never auto-merges — every choice here is an explicit user
/// action.
class ConflictsTab extends StatelessWidget {
  const ConflictsTab({super.key, required this.eventRepository});

  final EventRepository eventRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CalendarEvent>>(
      stream: eventRepository.watchEvents(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pairs = groupConflicts(snapshot.data!);
        if (pairs.isEmpty) {
          return const Center(child: Text('No conflicts to resolve.'));
        }
        return ListView.builder(
          itemCount: pairs.length,
          itemBuilder: (context, index) => _ConflictCard(
            pair: pairs[index],
            onResolve: (resolution) => resolveConflict(
              repository: eventRepository,
              original: pairs[index].original,
              newEvent: pairs[index].newEvent,
              resolution: resolution,
            ),
          ),
        );
      },
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.pair, required this.onResolve});

  final ConflictPair pair;
  final Future<void> Function(ConflictResolution) onResolve;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EventSummary(label: 'Original (${pair.original.source.name})', event: pair.original),
            const Divider(),
            _EventSummary(label: 'New (${pair.newEvent.source.name})', event: pair.newEvent),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => onResolve(ConflictResolution.keepOriginal),
                  child: const Text('Keep original'),
                ),
                OutlinedButton(
                  onPressed: () => onResolve(ConflictResolution.keepNew),
                  child: const Text('Keep new'),
                ),
                OutlinedButton(
                  onPressed: () => onResolve(ConflictResolution.keepBoth),
                  child: const Text('Keep both'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventSummary extends StatelessWidget {
  const _EventSummary({required this.label, required this.event});

  final String label;
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(event.title, style: Theme.of(context).textTheme.titleMedium),
        Text(event.start.toLocal().toString()),
        if (event.location != null) Text(event.location!),
      ],
    );
  }
}
