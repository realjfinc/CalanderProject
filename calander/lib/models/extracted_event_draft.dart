/// A proposed event from the extraction pipeline, shown in the
/// confirm-before-commit UI. Not a [CalendarEvent] — it carries only the
/// fields extraction can plausibly determine, is editable before the user
/// confirms it, and nothing here is saved until they do.
class ExtractedEventDraft {
  const ExtractedEventDraft({
    required this.title,
    required this.location,
    required this.startUtc,
    required this.endUtc,
    required this.notes,
  });

  factory ExtractedEventDraft.fromCallableResult(Map<Object?, Object?> result) {
    return ExtractedEventDraft(
      title: result['title'] as String? ?? 'Untitled event',
      location: result['location'] as String?,
      startUtc: DateTime.parse(result['startUtc'] as String).toUtc(),
      endUtc: DateTime.parse(result['endUtc'] as String).toUtc(),
      notes: result['notes'] as String?,
    );
  }

  final String title;
  final String? location;
  final DateTime startUtc;
  final DateTime endUtc;
  final String? notes;

  ExtractedEventDraft copyWith({
    String? title,
    String? location,
    DateTime? startUtc,
    DateTime? endUtc,
    String? notes,
  }) {
    return ExtractedEventDraft(
      title: title ?? this.title,
      location: location ?? this.location,
      startUtc: startUtc ?? this.startUtc,
      endUtc: endUtc ?? this.endUtc,
      notes: notes ?? this.notes,
    );
  }
}
