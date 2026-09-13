import 'package:flutter/material.dart';

import '../../models/calendar_event.dart';
import '../../models/event_tag.dart';
import '../../services/event_repository.dart';
import '../../services/tag_repository.dart';
import 'calendar_widgets.dart';
import 'event_editor_screen.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.eventId,
    required this.events,
    required this.tags,
  });
  final String eventId;
  final CalendarEventRepository events;
  final TagRepository tags;
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late final Stream<EventSnapshot> _events = widget.events.watchSnapshots();
  late final Stream<List<EventTag>> _tags = widget.tags.watchTags();
  bool _deleting = false;
  String? _error;

  Future<void> _delete(CalendarEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(
          '“${event.title}” will be removed from your calendar on all your devices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep event'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete event'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.events.delete(event.id);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = calendarError(error));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<EventTag>>(
    stream: _tags,
    builder: (context, tagSnapshot) => StreamBuilder<EventSnapshot>(
      stream: _events,
      builder: (context, snapshot) {
        CalendarEvent? event;
        for (final item in snapshot.data?.events ?? <CalendarEvent>[]) {
          if (item.id == widget.eventId) event = item;
        }
        final current = event;
        final tag = findTag(tagSnapshot.data ?? [], current?.tagId);
        return CalendarPage(
          title: current?.title ?? 'Event details',
          subtitle: 'Time for what matters.',
          onBack: () => Navigator.pop(context),
          children: [
            if (snapshot.hasError)
              Text(calendarError(snapshot.error!))
            else if (!snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (current == null)
              Text(
                _deleting
                    ? 'Removing event…'
                    : 'This event is no longer in your calendar.',
              )
            else ...[
              CalendarPanel(
                tint: Theme.of(context).colorScheme.primaryContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventTime(context, current, withDate: true),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      current.allDay
                          ? 'All-day event'
                          : 'Times shown in this device’s local time zone.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _row(
                'Location',
                (current.location ?? '').isEmpty
                    ? 'No location'
                    : current.location!,
              ),
              _row(
                'Tag',
                tag?.name ?? (current.tagId == null ? 'No tag' : 'Deleted tag'),
              ),
              _row('Importance', current.flexible ? 'Flexible' : 'Fixed'),
              if ((current.notes ?? '').isNotEmpty)
                _row('Notes', current.notes!),
              _row('Visibility', 'Only you'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _deleting
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EventEditorScreen(
                            events: widget.events,
                            tags: widget.tags,
                            initialDate: current.localStart,
                            existing: current,
                          ),
                        ),
                      ),
                child: const Text('Edit event'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _deleting ? null : () => _delete(current),
                child: const Text('Delete event'),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _row(String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: CalendarPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value),
        ],
      ),
    ),
  );
}
