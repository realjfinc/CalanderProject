import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calander/models/calendar_event.dart';
import 'package:calander/models/extracted_event_draft.dart';
import 'package:calander/models/extraction_input.dart';
import 'package:calander/services/event_extraction_service.dart';
import 'package:calander/services/event_repository.dart';
import 'package:calander/services/upload_storage.dart';
import 'package:calander/ui/extraction/extraction_confirm_screen.dart';
import 'package:calander/ui/extraction/upload_event_screen.dart';

class _FakeExtractionService implements EventExtractionService {
  _FakeExtractionService({this.result, this.error});
  final ExtractedEventDraft? result;
  final Object? error;
  ExtractionInput? lastInput;

  @override
  Future<ExtractedEventDraft> extract(ExtractionInput input) async {
    lastInput = input;
    if (error != null) throw error!;
    return result!;
  }
}

class _NoopEventRepository implements EventRepository {
  @override
  Future<String> addEvent(CalendarEvent event) async => 'id';
}

class _NoopUploadStorage implements UploadStorage {
  @override
  Future<String> upload({required bytes, required String fileName, String? contentType}) async => 'url';
}

Widget _harness(EventExtractionService service) {
  return MaterialApp(
    home: UploadEventScreen(
      extractionService: service,
      eventRepository: _NoopEventRepository(),
      uploadStorage: _NoopUploadStorage(),
    ),
  );
}

void main() {
  testWidgets('extracting from a link sends a LinkExtractionInput and opens the confirm screen', (
    tester,
  ) async {
    final draft = ExtractedEventDraft(
      title: 'Fundraiser',
      location: null,
      startUtc: DateTime.utc(2026, 3, 1, 18),
      endUtc: DateTime.utc(2026, 3, 1, 20),
      notes: null,
    );
    final service = _FakeExtractionService(result: draft);
    await tester.pumpWidget(_harness(service));

    await tester.enterText(find.byType(TextField), 'https://example.com/event');
    await tester.tap(find.text('Extract from Link'));
    await tester.pumpAndSettle();

    expect(service.lastInput, isA<LinkExtractionInput>());
    expect((service.lastInput! as LinkExtractionInput).url, 'https://example.com/event');
    expect(find.byType(ExtractionConfirmScreen), findsOneWidget);
    expect(find.text('Fundraiser'), findsOneWidget);
  });

  testWidgets('does nothing when the link field is empty', (tester) async {
    final service = _FakeExtractionService(result: null);
    await tester.pumpWidget(_harness(service));

    await tester.tap(find.text('Extract from Link'));
    await tester.pumpAndSettle();

    expect(service.lastInput, isNull);
    expect(find.byType(ExtractionConfirmScreen), findsNothing);
  });

  testWidgets('shows an error message and stays on the upload screen when extraction fails', (
    tester,
  ) async {
    final service = _FakeExtractionService(error: Exception('boom'));
    await tester.pumpWidget(_harness(service));

    await tester.enterText(find.byType(TextField), 'https://example.com/event');
    await tester.tap(find.text('Extract from Link'));
    await tester.pumpAndSettle();

    expect(find.byType(ExtractionConfirmScreen), findsNothing);
    expect(find.textContaining('Could not extract an event'), findsOneWidget);
  });
}
