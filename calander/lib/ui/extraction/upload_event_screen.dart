import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../models/extraction_input.dart';
import '../../services/event_extraction_service.dart';
import '../../services/event_repository.dart';
import '../../services/upload_storage.dart';
import 'extraction_confirm_screen.dart';

/// Entry point for Step 3: pick an image, a PDF, or paste a link, run it
/// through extraction, then hand off to the confirm-before-commit screen.
/// Nothing is saved from here directly.
class UploadEventScreen extends StatefulWidget {
  const UploadEventScreen({
    super.key,
    required this.extractionService,
    required this.eventRepository,
    required this.uploadStorage,
  });

  final EventExtractionService extractionService;
  final EventRepository eventRepository;
  final UploadStorage uploadStorage;

  @override
  State<UploadEventScreen> createState() => _UploadEventScreenState();
}

class _UploadEventScreenState extends State<UploadEventScreen> {
  final _linkController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _runExtraction(
    ExtractionInput input, {
    List<int>? attachmentBytes,
    String? attachmentFileName,
    String? attachmentContentType,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await widget.extractionService.extract(input);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ExtractionConfirmScreen(
            draft: draft,
            eventRepository: widget.eventRepository,
            uploadStorage: widget.uploadStorage,
            attachmentBytes: attachmentBytes,
            attachmentFileName: attachmentFileName,
            attachmentContentType: attachmentContentType,
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not extract an event: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final mimeType = lookupMimeType(file.name) ?? 'image/jpeg';
    await _runExtraction(
      ImageExtractionInput(bytes: bytes, mimeType: mimeType, fileName: file.name),
      attachmentBytes: bytes,
      attachmentFileName: file.name,
      attachmentContentType: mimeType,
    );
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();

    final extension = (picked.extension ?? '').toLowerCase();
    final input = extension == 'pdf'
        ? PdfExtractionInput(bytes: bytes, fileName: picked.name)
        : ImageExtractionInput(
            bytes: bytes,
            mimeType: lookupMimeType(picked.name) ?? 'image/jpeg',
            fileName: picked.name,
          );
    await _runExtraction(
      input,
      attachmentBytes: bytes,
      attachmentFileName: picked.name,
      attachmentContentType: lookupMimeType(picked.name),
    );
  }

  Future<void> _submitLink() async {
    final url = _linkController.text.trim();
    if (url.isEmpty) return;
    await _runExtraction(LinkExtractionInput(url: url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Event from Upload')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              if (_busy) const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Photo Library'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take Photo'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Choose File (PDF or image)'),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _linkController,
                decoration: const InputDecoration(labelText: 'Or paste a link', hintText: 'https://...'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _submitLink,
                icon: const Icon(Icons.link),
                label: const Text('Extract from Link'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
