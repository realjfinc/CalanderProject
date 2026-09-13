import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/calendar_event.dart';
import '../../models/event_tag.dart';
import '../../services/event_repository.dart';
import '../../services/tag_repository.dart';
import 'calendar_widgets.dart';

class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({
    super.key,
    required this.events,
    required this.tags,
    required this.initialDate,
    this.existing,
  });
  final CalendarEventRepository events;
  final TagRepository tags;
  final DateTime initialDate;
  final CalendarEvent? existing;
  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  late final Stream<List<EventTag>> _tagStream;
  late final String _id;
  late DateTime _start;
  late DateTime _end;
  bool _allDay = false;
  bool _flexible = false;
  bool _options = false;
  bool _busy = false;
  bool _slow = false;
  bool _dirty = false;
  String? _tagId;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final event = widget.existing;
    _id = event?.id ?? widget.events.newId();
    _title = TextEditingController(text: event?.title ?? '');
    _location = TextEditingController(text: event?.location ?? '');
    _notes = TextEditingController(text: event?.notes ?? '');
    _start =
        event?.localStart ??
        DateTime(
          widget.initialDate.year,
          widget.initialDate.month,
          widget.initialDate.day,
          9,
        );
    _end = event?.localEnd ?? _start.add(const Duration(hours: 1));
    _allDay = event?.allDay ?? false;
    _flexible = event?.flexible ?? false;
    _tagId = event?.tagId;
    _tagStream = widget.tags.watchTags();
    for (final controller in [_title, _location, _notes]) {
      controller.addListener(() => _dirty = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_busy) return;
    if (_options) {
      setState(() => _options = false);
      return;
    }
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your changes haven’t been saved yet.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _date(bool start) async {
    final current = start
        ? _start
        : (_allDay ? DateTime(_end.year, _end.month, _end.day - 1) : _end);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dirty = true;
      if (start) {
        final old = _start;
        _start = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _start.hour,
          _start.minute,
        );
        if (_allDay) {
          final days = DateTime.utc(
            _end.year,
            _end.month,
            _end.day,
          ).difference(DateTime.utc(old.year, old.month, old.day)).inDays;
          _end = DateTime(picked.year, picked.month, picked.day + days);
        } else {
          _end = _start.add(_end.difference(old));
        }
      } else {
        _end = _allDay
            ? DateTime(picked.year, picked.month, picked.day + 1)
            : DateTime(
                picked.year,
                picked.month,
                picked.day,
                _end.hour,
                _end.minute,
              );
      }
    });
  }

  Future<void> _time(bool start) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dirty = true;
      final value = DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      );
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  void _next() {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'Choose an end after the event starts.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _options = true;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _slow = false;
      _error = null;
    });
    _timer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _slow = true);
    });
    try {
      DateTime stored(DateTime date) => _allDay
          ? DateTime.utc(date.year, date.month, date.day)
          : date.toUtc();
      final event =
          (widget.existing ??
                  CalendarEvent(
                    id: _id,
                    title: _title.text,
                    start: stored(_start),
                    end: stored(_end),
                  ))
              .copyWith(
                title: _title.text,
                start: stored(_start),
                end: stored(_end),
                location: _location.text,
                notes: _notes.text,
                tag: _tagId,
                allDay: _allDay,
                importance: _flexible
                    ? EventImportance.flexible
                    : EventImportance.locked,
              );
      await widget.events.save(event, isNew: widget.existing == null);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = calendarError(error));
      } else if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'An event change couldn’t sync. Please check your calendar.',
            ),
          ),
        );
      }
    } finally {
      _timer?.cancel();
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int lines = 1,
    int max = 200,
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: !_busy,
          maxLines: lines,
          maxLength: max,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: label, counterText: ''),
          validator: required
              ? (value) => (value?.trim().isEmpty ?? true)
                    ? 'Give your event a name.'
                    : null
              : null,
        ),
      ],
    ),
  );

  Widget _choice(
    String title,
    String value,
    VoidCallback tap, {
    IconData icon = Icons.chevron_right,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: CalendarPanel(
      padding: 0,
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(value),
        trailing: Icon(icon, size: 18),
        onTap: _busy ? null : tap,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: CalendarPage(
      title: _options
          ? 'Event options'
          : widget.existing == null
          ? 'New event'
          : 'Edit event',
      subtitle: _options
          ? 'Make this event work for you.'
          : 'Start with the essentials.',
      onBack: _busy ? null : _leave,
      children: [
        if (!_options)
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field('Event name', _title, required: true),
                _field('Location', _location, max: 300),
                CalendarPanel(
                  padding: 0,
                  child: SwitchListTile.adaptive(
                    title: const Text('All day'),
                    value: _allDay,
                    onChanged: (value) => setState(() {
                      _dirty = true;
                      _allDay = value;
                      if (value) {
                        _start = dateOnly(_start);
                        _end = DateTime(
                          _start.year,
                          _start.month,
                          _start.day + 1,
                        );
                      } else {
                        _start = DateTime(
                          _start.year,
                          _start.month,
                          _start.day,
                          9,
                        );
                        _end = _start.add(const Duration(hours: 1));
                      }
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                _choice(
                  'Starts',
                  dateLabel(_start),
                  () => _date(true),
                  icon: Icons.calendar_today_outlined,
                ),
                _choice(
                  'Ends',
                  dateLabel(
                    _allDay
                        ? DateTime(_end.year, _end.month, _end.day - 1)
                        : _end,
                  ),
                  () => _date(false),
                  icon: Icons.calendar_today_outlined,
                ),
                if (!_allDay)
                  Row(
                    children: [
                      Expanded(
                        child: _choice(
                          'Start time',
                          TimeOfDay.fromDateTime(_start).format(context),
                          () => _time(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _choice(
                          'End time',
                          TimeOfDay.fromDateTime(_end).format(context),
                          () => _time(false),
                        ),
                      ),
                    ],
                  ),
                StreamBuilder<List<EventTag>>(
                  stream: _tagStream,
                  builder: (context, snapshot) => _choice(
                    'Tag',
                    findTag(snapshot.data ?? [], _tagId)?.name ??
                        (_tagId == null ? 'No tag' : 'Unavailable tag'),
                    () async {
                      final tags = snapshot.data ?? [];
                      final result = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => SafeArea(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.sizeOf(context).height * .7,
                            ),
                            child: ListView(
                              shrinkWrap: true,
                              children: [
                                const ListTile(title: Text('Choose a tag')),
                                ListTile(
                                  title: const Text('No tag'),
                                  onTap: () => Navigator.pop(context, ''),
                                ),
                                if (snapshot.hasError)
                                  const ListTile(
                                    title: Text(
                                      'Tags could not be loaded. You can save without a tag.',
                                    ),
                                  ),
                                for (final tag in tags)
                                  ListTile(
                                    title: Text(tag.name),
                                    leading: CircleAvatar(
                                      radius: 8,
                                      backgroundColor: Color(tag.colorValue),
                                    ),
                                    trailing: _tagId == tag.id
                                        ? const Icon(Icons.check)
                                        : null,
                                    onTap: () => Navigator.pop(context, tag.id),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                      if (result != null && mounted) {
                        setState(() {
                          _tagId = result.isEmpty ? null : result;
                          _dirty = true;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          )
        else ...[
          CalendarPanel(
            tint: Theme.of(context).colorScheme.primaryContainer,
            child: const Text(
              'Your plans stay private. Only you can see and edit this event.',
            ),
          ),
          const SizedBox(height: 20),
          _choice(
            'Importance',
            _flexible
                ? 'Flexible · Plans with room to move'
                : 'Fixed · Keep this time protected',
            () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (context) => _ImportanceScreen(flexible: _flexible),
                ),
              );
              if (result != null && mounted) {
                setState(() {
                  _flexible = result;
                  _dirty = true;
                });
              }
            },
          ),
          _field('Notes', _notes, lines: 4, max: 5000),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_slow && _busy)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Your change is waiting to sync. You can return to the calendar while it finishes. It will appear on other devices after syncing.',
            ),
          ),
        if (_slow && _busy)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Return to calendar'),
          ),
        FilledButton(
          onPressed: _busy
              ? null
              : _options
              ? _save
              : _next,
          child: Text(
            _busy
                ? 'Saving to your calendar…'
                : _options
                ? (widget.existing == null ? 'Create event' : 'Save changes')
                : 'Next: event options',
          ),
        ),
      ],
    ),
  );
}

class _ImportanceScreen extends StatefulWidget {
  const _ImportanceScreen({required this.flexible});
  final bool flexible;
  @override
  State<_ImportanceScreen> createState() => _ImportanceScreenState();
}

class _ImportanceScreenState extends State<_ImportanceScreen> {
  late bool _flexible = widget.flexible;
  @override
  Widget build(BuildContext context) => CalendarPage(
    title: 'Event importance',
    subtitle: 'Protect plans. Keep room to move.',
    onBack: () => Navigator.pop(context),
    children: [
      for (final flexible in [false, true])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CalendarPanel(
            padding: 0,
            child: ListTile(
              title: Text(flexible ? 'Flexible' : 'Fixed'),
              subtitle: Text(
                flexible
                    ? 'Plans with room to move'
                    : 'Work, classes and appointments',
              ),
              trailing: Icon(
                flexible == _flexible
                    ? Icons.check_circle
                    : Icons.circle_outlined,
              ),
              onTap: () => setState(() => _flexible = flexible),
            ),
          ),
        ),
      const SizedBox(height: 12),
      CalendarPanel(
        tint: Theme.of(context).colorScheme.primaryContainer,
        child: const Text(
          'You stay in control. Events only move when you edit them.',
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: () => Navigator.pop(context, _flexible),
        child: const Text('Save importance'),
      ),
    ],
  );
}
