import 'package:calander/models/extracted_event_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromCallableResult parses a full callable response', () {
    final draft = ExtractedEventDraft.fromCallableResult({
      'title': 'Block Party',
      'location': 'Main St Park',
      'startUtc': '2026-07-04T23:00:00.000Z',
      'endUtc': '2026-07-05T02:00:00.000Z',
      'notes': 'Bring a dish to pass',
    });

    expect(draft.title, 'Block Party');
    expect(draft.location, 'Main St Park');
    expect(draft.startUtc, DateTime.utc(2026, 7, 4, 23));
    expect(draft.endUtc, DateTime.utc(2026, 7, 5, 2));
    expect(draft.notes, 'Bring a dish to pass');
  });

  test('fromCallableResult defaults a missing title and null optional fields', () {
    final draft = ExtractedEventDraft.fromCallableResult({
      'startUtc': '2026-01-01T00:00:00.000Z',
      'endUtc': '2026-01-01T01:00:00.000Z',
    });

    expect(draft.title, 'Untitled event');
    expect(draft.location, isNull);
    expect(draft.notes, isNull);
  });

  test('copyWith overrides only the given fields', () {
    final draft = ExtractedEventDraft(
      title: 'Original',
      location: 'Somewhere',
      startUtc: DateTime.utc(2026),
      endUtc: DateTime.utc(2026, 1, 1, 1),
      notes: null,
    );

    final updated = draft.copyWith(title: 'Renamed');

    expect(updated.title, 'Renamed');
    expect(updated.location, 'Somewhere');
    expect(updated.startUtc, draft.startUtc);
  });
}
