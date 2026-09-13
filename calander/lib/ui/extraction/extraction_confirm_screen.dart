import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/calendar_event.dart';
import '../../models/extracted_event_draft.dart';
import '../../services/event_repository.dart';
import '../../services/upload_storage.dart';

/// Lets the user review and edit an extracted event before it's saved.
/// Nothing is written to Firestore until "Save Event" is tapped — per the
/// spec, an extracted event is never committed automatically.
class ExtractionConfirmScreen extends StatefulWidget {
  const ExtractionConfirmScreen({
    super.key,
    required this.draft,
    required this.eventRepository,
    required this.uploadStorage,
    this.attachmentBytes,
    this.attachmentFileName,
    this.attachmentContentType,
  });

  final ExtractedEventDraft draft;
  final EventRepository eventRepository;
  final UploadStorage uploadStorage;
  final List<int>? attachmentBytes;
  final String? attachmentFileName;
  final String? attachmentContentType;

  @override
  State<ExtractionConfirmScreen> createState() => _ExtractionConfirmScreenState();
}

class _ExtractionConfirmScreenState extends State<ExtractionConfirmScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;
  late DateTime _startLocal;
  late DateTime _endLocal;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.draft.title);
    _locationController = TextEditingController(text: widget.draft.location ?? '');
    _notesController = TextEditingController(text: widget.draft.notes ?? '');
    _startLocal = widget.draft.startUtc.toLocal();
    _endLocal = widget.draft.endUtc.toLocal();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startLocal : _endLocal;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year - 1),
      lastDate: DateTime(initial.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;

    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startLocal = combined;
      } else {
        _endLocal = combined;
      }
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (!_endLocal.isAfter(_startLocal)) {
      setState(() => _error = 'End time must be after the start time.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      List<String>? attachments;
      final bytes = widget.attachmentBytes;
      if (bytes != null) {
        final url = await widget.uploadStorage.upload(
          bytes: Uint8List.fromList(bytes),
          fileName: widget.attachmentFileName ?? 'upload',
          contentType: widget.attachmentContentType,
        );
        attachments = [url];
      }

      final event = CalendarEvent(
        id: '',
        title: _titleController.text.trim(),
        location: _emptyToNull(_locationController.text),
        start: _startLocal.toUtc(),
        end: _endLocal.toUtc(),
        source: EventSource.upload,
        sourceId: null,
        status: EventStatus.active,
        tag: null,
        notes: _emptyToNull(_notesController.text),
        attachments: attachments,
      );
      await widget.eventRepository.addEvent(event);

      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not save the event: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) => value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Event')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Starts'),
              subtitle: Text(_startLocal.toString()),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _pickDateTime(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ends'),
              subtitle: Text(_endLocal.toString()),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _pickDateTime(isStart: false),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
                  : const Text('Save Event'),
            ),
          ],
        ),
      ),
    );
  }
}
