import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../models/calendar_event.dart';
import '../../models/event_tag.dart';
import '../../services/event_repository.dart';
import '../../services/firestore_event_repository.dart';
import '../../services/firestore_tag_repository.dart';
import '../../services/tag_repository.dart';
import '../tags/tag_management_screen.dart';
import '../sync/provider_sync_screen.dart';
import 'calendar_widgets.dart';
import 'event_editor_screen.dart';
import 'event_detail_screen.dart';

/// A nested navigator belongs to this login session. Signing out removes its
/// event forms and detail routes along with their user-scoped subscriptions.
class CalendarHomeScreen extends StatefulWidget {
  const CalendarHomeScreen({
    super.key,
    required this.auth,
    this.events,
    this.tags,
  });
  final AuthService auth;
  final CalendarEventRepository? events;
  final TagRepository? tags;
  @override
  State<CalendarHomeScreen> createState() => _CalendarHomeScreenState();
}

class _CalendarHomeScreenState extends State<CalendarHomeScreen> {
  final _navigator = GlobalKey<NavigatorState>();
  late final CalendarEventRepository _events =
      widget.events ?? FirestoreEventRepository(uid: widget.auth.account!.uid);
  late final TagRepository _tags =
      widget.tags ?? FirestoreTagRepository(uid: widget.auth.account!.uid);
  @override
  Widget build(BuildContext context) => NavigatorPopHandler<Object?>(
    onPopWithResult: (result) =>
        unawaited(_navigator.currentState!.maybePop(result)),
    child: Navigator(
      key: _navigator,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) =>
            _CalendarDashboard(auth: widget.auth, events: _events, tags: _tags),
      ),
    ),
  );
}

enum CalendarMode { month, week, day }

class _CalendarDashboard extends StatefulWidget {
  const _CalendarDashboard({
    required this.auth,
    required this.events,
    required this.tags,
  });
  final AuthService auth;
  final CalendarEventRepository events;
  final TagRepository tags;
  @override
  State<_CalendarDashboard> createState() => _CalendarDashboardState();
}

class _CalendarDashboardState extends State<_CalendarDashboard> {
  late Stream<EventSnapshot> _eventStream;
  late final Stream<List<EventTag>> _tagStream;
  final _search = TextEditingController();
  CalendarMode _mode = CalendarMode.month;
  DateTime _selected = dateOnly(DateTime.now());
  int _tab = 0;
  String? _filter;
  String? _tagError;

  @override
  void initState() {
    super.initState();
    _eventStream = widget.events.watchSnapshots();
    _tagStream = widget.tags.watchTags();
    _initializeTags();
  }

  Future<void> _initializeTags() async {
    try {
      await widget.tags.ensureDefaultTagsInitialized();
    } catch (_) {
      if (mounted) {
        setState(
          () => _tagError = 'Tags could not be loaded. Events can still be saved without a tag.',
        );
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _shift(int amount) {
    setState(() {
      _selected = switch (_mode) {
        CalendarMode.month => DateTime(
          _selected.year,
          _selected.month + amount,
          math.min(
            _selected.day,
            DateTime(_selected.year, _selected.month + amount + 1, 0).day,
          ),
        ),
        CalendarMode.week => DateTime(
          _selected.year,
          _selected.month,
          _selected.day + 7 * amount,
        ),
        CalendarMode.day => DateTime(
          _selected.year,
          _selected.month,
          _selected.day + amount,
        ),
      };
      if (_selected.year < 1900) _selected = DateTime(1900);
      if (_selected.year > 2200) _selected = DateTime(2200, 12, 31);
    });
  }

  Future<void> _pickDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
    );
    if (day != null && mounted) setState(() => _selected = day);
  }

  Future<void> _create() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventEditorScreen(
          events: widget.events,
          tags: widget.tags,
          initialDate: _selected,
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event saved to your calendar.')),
      );
    }
  }

  void _detail(CalendarEvent event) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => EventDetailScreen(
        eventId: event.id,
        events: widget.events,
        tags: widget.tags,
      ),
    ),
  );

  void _destination(int value) {
    if (value == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TagManagementScreen(repository: widget.tags),
        ),
      );
    } else if (value == 3) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _CalendarSettings(
            auth: widget.auth,
            tags: widget.tags,
            events: widget.events,
          ),
        ),
      );
    } else {
      setState(() => _tab = value);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<EventTag>>(
    stream: _tagStream,
    builder: (context, tagSnapshot) => StreamBuilder<EventSnapshot>(
      stream: _eventStream,
      builder: (context, snapshot) {
        final tags = tagSnapshot.data ?? <EventTag>[];
        final events = snapshot.data?.events ?? <CalendarEvent>[];
        final dayEvents = events.where((e) => e.occursOn(_selected)).toList()
          ..sort(
            (a, b) => a.allDay != b.allDay
                ? (a.allDay ? -1 : 1)
                : a.localStart.compareTo(b.localStart),
          );
        final weekStart = DateTime(
          _selected.year,
          _selected.month,
          _selected.day - _selected.weekday + 1,
        );
        final weekEnd = DateTime(
          weekStart.year,
          weekStart.month,
          weekStart.day + 6,
        );
        final title = _tab == 1
            ? 'Search calendar'
            : switch (_mode) {
                CalendarMode.month => monthLabel(_selected),
                CalendarMode.week => 'Your week',
                CalendarMode.day => dayLabel(_selected),
              };
        final subtitle = _tab == 1
            ? 'Find your next moment.'
            : switch (_mode) {
                CalendarMode.month => 'A little structure. More possibility.',
                CalendarMode.week =>
                  '${dateLabel(weekStart)} – ${dateLabel(weekEnd)}',
                CalendarMode.day =>
                  '${dayEvents.length} ${dayEvents.length == 1 ? 'event' : 'events'} · Time for what matters',
              };
        final sync = snapshot.hasError
            ? 'Connection needs attention'
            : snapshot.data?.pending == true
            ? 'Syncing changes…'
            : snapshot.data?.fromCache == true
            ? 'Showing cached events · Connecting…'
            : snapshot.hasData
            ? 'Up to date'
            : 'Connecting…';
        return CalendarPage(
          title: title,
          subtitle: subtitle,
          actions: [
            IconButton(
              tooltip: 'Search calendar',
              onPressed: () => setState(() => _tab = 1),
              icon: const Icon(Icons.search),
            ),
          ],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: _destination,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Calendar',
              ),
              NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
              NavigationDestination(
                icon: Icon(Icons.sell_outlined),
                label: 'Tags',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                label: 'Settings',
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(
                    snapshot.data?.fromCache == true
                        ? Icons.cloud_off_outlined
                        : Icons.cloud_done_outlined,
                    size: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      sync,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (_tab == 0) ...[
              Row(
                children: [
                  for (final mode in CalendarMode.values) ...[
                    if (mode != CalendarMode.month) const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        selected: _mode == mode,
                        child: _mode == mode
                            ? FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () => setState(() => _mode = mode),
                                child: Text(
                                  mode.name[0].toUpperCase() +
                                      mode.name.substring(1),
                                ),
                              )
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () => setState(() => _mode = mode),
                                child: Text(
                                  mode.name[0].toUpperCase() +
                                      mode.name.substring(1),
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Previous ${_mode.name}',
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: _pickDate,
                      child: Text(
                        _mode == CalendarMode.month
                            ? monthLabel(_selected)
                            : dateLabel(_selected),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _selected = dateOnly(DateTime.now())),
                    child: const Text('Today'),
                  ),
                  IconButton(
                    tooltip: 'Next ${_mode.name}',
                    onPressed: () => _shift(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              if (_mode == CalendarMode.month)
                _MonthGrid(
                  selected: _selected,
                  events: events,
                  onSelect: (day) => setState(() => _selected = day),
                ),
              if (_mode == CalendarMode.week)
                _WeekGrid(
                  selected: _selected,
                  events: events,
                  tags: tags,
                  onSelect: (day) => setState(() => _selected = day),
                  onEvent: _detail,
                ),
              const SizedBox(height: 20),
            ] else ...[
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Event name, location or tag',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _search.clear()),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  for (final tag in tags)
                    ChoiceChip(
                      label: Text(tag.name),
                      selected: _filter == tag.id,
                      onSelected: (_) => setState(() => _filter = tag.id),
                    ),
                  if (_filter != null && findTag(tags, _filter) == null)
                    InputChip(
                      label: const Text('Deleted tag'),
                      onDeleted: () => setState(() => _filter = null),
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            if (snapshot.hasError)
              CalendarPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(calendarError(snapshot.error!)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(
                        () => _eventStream = widget.events.watchSnapshots(),
                      ),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (!snapshot.hasData)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_tab == 1)
              ..._searchResults(events, tags)
            else ...[
              Text(
                '${weekdayNames[_selected.weekday - 1]} ${_selected.day} · ${dayEvents.length} ${dayEvents.length == 1 ? 'event' : 'events'}',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (dayEvents.isEmpty)
                CalendarPanel(
                  tint: Theme.of(context).colorScheme.primaryContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        events.isEmpty
                            ? 'A fresh start'
                            : 'A little breathing room',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        events.isEmpty
                            ? 'A blank page for a good day. Add your first event and make it yours.'
                            : 'Nothing planned for this day. Make time for what matters.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              for (final event in dayEvents)
                EventCard(
                  event: event,
                  tags: tags,
                  onTap: () => _detail(event),
                ),
            ],
            if (_tagError != null || tagSnapshot.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _tagError ?? 'Your tags could not be loaded.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                snapshot.hasData && events.isEmpty
                    ? 'Create my first event'
                    : 'New event',
              ),
            ),
          ],
        );
      },
    ),
  );

  List<Widget> _searchResults(List<CalendarEvent> events, List<EventTag> tags) {
    final query = _search.text.trim().toLowerCase();
    final results = events
        .where(
          (event) =>
              (_filter == null || event.tagId == _filter) &&
              '${event.title} ${event.location} ${event.notes} ${findTag(tags, event.tagId)?.name ?? ''}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return [
      Text(
        '${results.length} ${results.length == 1 ? 'result' : 'results'}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      if (results.isEmpty)
        const CalendarPanel(
          child: Text(
            'No events found. Try another event name, location or tag.',
          ),
        ),
      for (final event in results)
        EventCard(
          event: event,
          tags: tags,
          withDate: true,
          onTap: () => _detail(event),
        ),
    ];
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.selected,
    required this.events,
    required this.onSelect,
  });
  final DateTime selected;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onSelect;
  @override
  Widget build(BuildContext context) {
    final first = DateTime(selected.year, selected.month);
    final cells =
        ((first.weekday - 1 + DateTime(first.year, first.month + 1, 0).day) / 7)
            .ceil() *
        7;
    final scheme = Theme.of(context).colorScheme;
    return CalendarPanel(
      padding: 10,
      child: Column(
        children: [
          Row(
            children: [
              for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 48,
            ),
            itemBuilder: (context, index) {
              final day = DateTime(
                first.year,
                first.month,
                index - first.weekday + 2,
              );
              final count = events.where((event) => event.occursOn(day)).length;
              final active = sameDay(day, selected);
              final today = sameDay(day, DateTime.now());
              return Semantics(
                label: '${dateLabel(day)}, $count events',
                selected: active,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelect(day),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: active ? scheme.primary : null,
                      borderRadius: BorderRadius.circular(12),
                      border: today && !active
                          ? Border.all(color: scheme.primary)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: active
                                ? scheme.onPrimary
                                : day.month == selected.month
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant.withValues(alpha: .5),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            math.min(3, count),
                            (_) => Container(
                              width: 3,
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: active
                                    ? scheme.onPrimary
                                    : scheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.selected,
    required this.events,
    required this.tags,
    required this.onSelect,
    required this.onEvent,
  });
  final DateTime selected;
  final List<CalendarEvent> events;
  final List<EventTag> tags;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<CalendarEvent> onEvent;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(
      selected.year,
      selected.month,
      selected.day - selected.weekday + 1,
    );
    final scheme = Theme.of(context).colorScheme;
    return CalendarPanel(
      padding: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(
                350,
                math.min(640, MediaQuery.sizeOf(context).width - 68),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 26,
                    child: Column(
                      children: [
                        const SizedBox(height: 72),
                        for (final hour in ['00', '06', '12', '18'])
                          SizedBox(
                            height: 72,
                            child: Text(
                              hour,
                              style: TextStyle(
                                fontSize: 9,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (var index = 0; index < 7; index++)
                    Expanded(
                      child: _weekDay(
                        context,
                        DateTime(first.year, first.month, first.day + index),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'All times local · Tap an event for details',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _weekDay(BuildContext context, DateTime day) {
    final scheme = Theme.of(context).colorScheme;
    final items = events.where((e) => e.occursOn(day)).toList();
    final timed = items.where((e) => !e.allDay).toList()
      ..sort((a, b) => a.localStart.compareTo(b.localStart));
    final laneEnds = <DateTime>[];
    final lanes = <String, int>{};
    for (final event in timed) {
      var lane = laneEnds.indexWhere((end) => !end.isAfter(event.localStart));
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(event.localEnd);
      } else {
        laneEnds[lane] = event.localEnd;
      }
      lanes[event.id] = lane;
    }
    final laneCount = math.max(1, laneEnds.length);
    double minute(DateTime value) => sameDay(value, day)
        ? value.hour * 60.0 + value.minute
        : value.isBefore(day)
        ? 0
        : 1440;
    return Column(
      children: [
        InkWell(
          onTap: () => onSelect(day),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: sameDay(day, selected) ? scheme.primaryContainer : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '${weekdayNames[day.weekday - 1][0]} ${day.day}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 28,
          child: items.any((e) => e.allDay)
              ? InkWell(
                  onTap: () => onSelect(day),
                  child: Center(
                    child: Text(
                      'All day',
                      style: TextStyle(fontSize: 9, color: scheme.primary),
                    ),
                  ),
                )
              : null,
        ),
        SizedBox(
          height: 288,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: sameDay(day, selected)
                          ? scheme.primaryContainer
                          : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                for (var hour = 0; hour < 24; hour += 6)
                  Positioned(
                    top: hour * 12,
                    left: 0,
                    right: 0,
                    child: Divider(
                      height: 1,
                      color: scheme.outline.withValues(alpha: .4),
                    ),
                  ),
                for (final event in timed)
                  Positioned(
                    top: minute(event.localStart) / 5,
                    height: math.min(
                      288 - minute(event.localStart) / 5,
                      math.max(
                        8.0,
                        (minute(event.localEnd) - minute(event.localStart)) / 5,
                      ),
                    ),
                    left:
                        lanes[event.id]! * constraints.maxWidth / laneCount + 1,
                    width: math.max(1.0, constraints.maxWidth / laneCount - 2),
                    child: Tooltip(
                      message: '${event.title} · ${eventTime(context, event)}',
                      child: Semantics(
                        button: true,
                        label: '${event.title}, ${eventTime(context, event)}',
                        child: Material(
                          color: Color(
                            findTag(tags, event.tagId)?.colorValue ??
                                0xFF285BE0,
                          ).withValues(alpha: .8),
                          borderRadius: BorderRadius.circular(4),
                          child: InkWell(
                            onTap: () => onEvent(event),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Text(
                                event.title,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarSettings extends StatefulWidget {
  const _CalendarSettings({
    required this.auth,
    required this.tags,
    required this.events,
  });
  final CalendarEventRepository events;
  final AuthService auth;
  final TagRepository tags;
  @override
  State<_CalendarSettings> createState() => _CalendarSettingsState();
}

class _CalendarSettingsState extends State<_CalendarSettings> {
  bool _busy = false;
  String? _error;
  Future<void> _logout() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.logOut();
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CalendarPage(
    title: 'Settings',
    subtitle: 'A little more you.',
    onBack: () => Navigator.pop(context),
    children: [
      CalendarPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your account',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(widget.auth.account?.email ?? ''),
            const SizedBox(height: 12),
            const Text(
              'Your calendar is private and syncs with this account across devices.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      CalendarPanel(
        padding: 0,
        child: ListTile(
          title: const Text('Manage Tags'),
          subtitle: const Text('Make your calendar your own'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TagManagementScreen(repository: widget.tags),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      CalendarPanel(
        padding: 0,
        child: ListTile(
          title: const Text('Provider Sync'),
          subtitle: const Text('Connect calendars and resolve conflicts'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProviderSyncScreen(eventRepository: widget.events),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const CalendarPanel(
        child: Text('Appearance follows your device’s light or dark setting.'),
      ),
      const SizedBox(height: 24),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      FilledButton(
        onPressed: _busy ? null : _logout,
        child: Text(_busy ? 'Logging out…' : 'Log out'),
      ),
    ],
  );
}
