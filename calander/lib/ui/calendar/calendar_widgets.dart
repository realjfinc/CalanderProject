import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/calendar_event.dart';
import '../../models/event_tag.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.actions = const [],
    this.bottomNavigationBar,
    this.onBack,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  final Widget? bottomNavigationBar;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: bottomNavigationBar,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (onBack != null)
                        IconButton(
                          onPressed: onBack,
                          tooltip: 'Back',
                          icon: const Icon(Icons.chevron_left),
                        ),
                      Text(
                        'CALANDER',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      ...actions,
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class CalendarPanel extends StatelessWidget {
  const CalendarPanel({
    super.key,
    required this.child,
    this.tint,
    this.padding = 16,
  });
  final Widget child;
  final Color? tint;
  final double padding;
  @override
  Widget build(BuildContext context) => Material(
    color: tint ?? Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: EdgeInsets.all(padding),
      child: child,
    ),
  );
}

EventTag? findTag(List<EventTag> tags, String? id) {
  for (final tag in tags) {
    if (tag.id == id) return tag;
  }
  return null;
}

String eventTime(
  BuildContext context,
  CalendarEvent event, {
  bool withDate = false,
}) {
  if (event.allDay) {
    final last = DateTime(
      event.localEnd.year,
      event.localEnd.month,
      event.localEnd.day - 1,
    );
    return sameDay(event.localStart, last)
        ? (withDate ? '${dateLabel(event.localStart)} · All day' : 'All day')
        : '${dateLabel(event.localStart)} – ${dateLabel(last)} · All day';
  }
  final from = TimeOfDay.fromDateTime(event.localStart).format(context);
  final to = TimeOfDay.fromDateTime(event.localEnd).format(context);
  if (!sameDay(event.localStart, event.localEnd)) {
    return '${dateLabel(event.localStart)}, $from – ${dateLabel(event.localEnd)}, $to';
  }
  return '${withDate ? '${dateLabel(event.localStart)} · ' : ''}$from – $to';
}

class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.tags,
    required this.onTap,
    this.withDate = false,
  });
  final CalendarEvent event;
  final List<EventTag> tags;
  final VoidCallback onTap;
  final bool withDate;
  @override
  Widget build(BuildContext context) {
    final tag = findTag(tags, event.tagId);
    final scheme = Theme.of(context).colorScheme;
    final color = tag == null ? scheme.primary : Color(tag.colorValue);
    final tint = Color.alphaBlend(color.withValues(alpha: .12), scheme.surface);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: tint,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '${eventTime(context, event, withDate: withDate)}${(event.location ?? '').isEmpty ? '' : ' · ${event.location}'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${tag?.name ?? (event.tagId == null ? 'Untagged' : 'Deleted tag')} · ${event.flexible ? 'Flexible' : 'Fixed'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String calendarError(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'Your calendar could not be accessed. Check that you’re signed in and try again.',
      'unavailable' || 'deadline-exceeded' =>
        'Couldn’t reach your calendar. Check your connection and try again.',
      'not-found' => 'This event was deleted on another device. Return to your calendar to refresh.',
      _ => 'Couldn’t save that change. Please try again.',
    };
  }
  return 'Something went wrong. Please try again.';
}
