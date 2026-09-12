import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/models/extracted_event_draft.dart';
import 'package:calander/services/event_repository.dart';
import 'package:calander/services/upload_storage.dart';
import 'package:calander/ui/extraction/extraction_confirm_screen.dart';

class _RecordingEventRepository implements EventRepository {
  CalendarEvent? savedEvent;

  @override
  Future<String> addEvent(CalendarEvent event) async {
    savedEvent = event;
    return 'generated-id';
  }
}

class _FakeUploadStorage implements UploadStorage {
  bool called = false;

  @override
  Future<String> upload({required Uint8List bytes, required String fileName, String? contentType}) async {
    called = true;
    return 'https://example.com/uploads/$fileName';
  }
}

ExtractedEventDraft _draft() => ExtractedEventDraft(
  title: 'Block Party',
  location: 'Main St Park',
  startUtc: DateTime.utc(2026, 7, 4, 23),
  endUtc: DateTime.utc(2026, 7, 5, 1),
  notes: 'Bring snacks',
);

void main() {
  testWidgets('shows the extracted fields for review before saving anything', (tester) async {
    final repo = _RecordingEventRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ExtractionConfirmScreen(
          draft: _draft(),
          eventRepository: repo,
          uploadStorage: _FakeUploadStorage(),
        ),
      ),
    );

    expect(find.text('Block Party'), findsOneWidget);
    expect(find.text('Main St Park'), findsOneWidget);
    expect(find.text('Bring snacks'), findsOneWidget);
    expect(repo.savedEvent, isNull); // nothing saved just by displaying the draft
  });

  testWidgets('Save Event writes an event with source=upload, sourceId=null, tag=null', (tester) async {
    final repo = _RecordingEventRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ExtractionConfirmScreen(
          draft: _draft(),
          eventRepository: repo,
          uploadStorage: _FakeUploadStorage(),
        ),
      ),
    );

    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    final saved = repo.savedEvent;
    expect(saved, isNotNull);
    expect(saved!.source, EventSource.upload);
    expect(saved.sourceId, isNull);
    expect(saved.tag, isNull);
    expect(saved.title, 'Block Party');
    expect(saved.start, DateTime.utc(2026, 7, 4, 23));
  });

  testWidgets('editing the title before saving changes the saved event', (tester) async {
    final repo = _RecordingEventRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ExtractionConfirmScreen(
          draft: _draft(),
          eventRepository: repo,
          uploadStorage: _FakeUploadStorage(),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Renamed Party');
    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    expect(repo.savedEvent!.title, 'Renamed Party');
  });

  testWidgets('rejects saving with an empty title', (tester) async {
    final repo = _RecordingEventRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ExtractionConfirmScreen(
          draft: _draft(),
          eventRepository: repo,
          uploadStorage: _FakeUploadStorage(),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, 'Title'), '');
    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    expect(repo.savedEvent, isNull);
    expect(find.text('Title is required.'), findsOneWidget);
  });

  testWidgets('uploads the source file and attaches its URL when one was provided', (tester) async {
    final repo = _RecordingEventRepository();
    final storage = _FakeUploadStorage();
    await tester.pumpWidget(
      MaterialApp(
        home: ExtractionConfirmScreen(
          draft: _draft(),
          eventRepository: repo,
          uploadStorage: storage,
          attachmentBytes: [1, 2, 3],
          attachmentFileName: 'flyer.png',
          attachmentContentType: 'image/png',
        ),
      ),
    );

    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    expect(storage.called, isTrue);
    expect(repo.savedEvent!.attachments, ['https://example.com/uploads/flyer.png']);
  });

  testWidgets('an event with no attachment is saved with attachments left null', (tester) async {
    final repo = _RecordingEventRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ExtractionConfirmScreen(
          draft: _draft(),
          eventRepository: repo,
          uploadStorage: _FakeUploadStorage(),
        ),
      ),
    );

    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    expect(repo.savedEvent!.attachments, isNull);
  });
}
