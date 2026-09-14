import 'package:flutter/material.dart';

import '../calendar/calendar_widgets.dart';

import '../../models/calendar_event.dart';
import '../../models/event_tag.dart';
import '../../services/event_repository.dart';
import '../../services/tag_repository.dart';

/// Lets the user assign a tag to an untagged event, or change/clear any
/// event's current tag — direct user action always wins, whether or not
/// the tag currently showing was set automatically.
class EventTagsTab extends StatelessWidget {
  const EventTagsTab({
    super.key,
    required this.eventRepository,
    required this.tagRepository,
  });

  final EventRepository eventRepository;
  final TagRepository tagRepository;

  Future<void> _pickTag(
    BuildContext context,
    CalendarEvent event,
    List<EventTag> tags,
  ) async {
    final selected = await showModalBottomSheet<_TagChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('No tag'),
              onTap: () => Navigator.of(context).pop(const _TagChoice(null)),
            ),
            for (final tag in tags)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(tag.colorValue),
                  radius: 10,
                ),
                title: Text(tag.name),
                onTap: () => Navigator.of(context).pop(_TagChoice(tag.id)),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      if (!context.mounted) return;
      await runCalendarAction(
        context,
        () => eventRepository.updateEvent(event.copyWith(tag: selected.tagId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventTag>>(
      stream: tagRepository.watchTags(),
      builder: (context, tagSnapshot) {
        final tags = tagSnapshot.data ?? const [];
        final tagsById = {for (final tag in tags) tag.id: tag};

        return StreamBuilder<List<CalendarEvent>>(
          stream: eventRepository.watchEvents(),
          builder: (context, eventSnapshot) {
            if (!eventSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final events = eventSnapshot.data!;
            if (events.isEmpty) {
              return const Center(child: Text('No events yet.'));
            }
            return ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final tag = event.tag == null ? null : tagsById[event.tag];
                return ListTile(
                  key: ValueKey(event.id),
                  title: Text(event.title),
                  trailing: ActionChip(
                    avatar: tag == null
                        ? null
                        : CircleAvatar(
                            backgroundColor: Color(tag.colorValue),
                            radius: 8,
                          ),
                    label: Text(tag?.name ?? 'Untagged'),
                    onPressed: () => _pickTag(context, event, tags),
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

class _TagChoice {
  const _TagChoice(this.tagId);
  final String? tagId;
}
