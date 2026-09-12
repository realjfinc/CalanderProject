import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical event schema — the hard contract every feature that creates or
/// reads events must respect. See project roadmap: timestamps are always
/// normalized to UTC at ingestion, `tag` may only be assigned by direct user
/// action or Step 5's tag-routing logic (never by a source adapter), and
/// dedup/conflict rules key off `(source, sourceId)`.
enum EventSource { manual, upload, screenshot, google, outlook, icloud, sports }

enum EventStatus { active, pendingConflict }

enum EventImportance { locked, flexible }

/// Matches the notification timing options Jonathan's settings UI offers.
/// The scheduling engine (Step 2) only needs to know how to turn one of
/// these into an offset before `start`; it does not own the UI that picks
/// them.
enum ReminderOffset { fiveMinutes, tenMinutes, fifteenMinutes, thirtyMinutes, oneHour, oneDay }

extension ReminderOffsetDuration on ReminderOffset {
  Duration get duration => switch (this) {
    ReminderOffset.fiveMinutes => const Duration(minutes: 5),
    ReminderOffset.tenMinutes => const Duration(minutes: 10),
    ReminderOffset.fifteenMinutes => const Duration(minutes: 15),
    ReminderOffset.thirtyMinutes => const Duration(minutes: 30),
    ReminderOffset.oneHour => const Duration(hours: 1),
    ReminderOffset.oneDay => const Duration(days: 1),
  };
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    this.location,
    required this.start,
    required this.end,
    required this.source,
    this.sourceId,
    this.status = EventStatus.active,
    this.tag,
    this.importance = EventImportance.flexible,
    this.notes,
    this.attachments,
    this.repeat,
    this.reminders,
  });

  final String id;
  final String title;
  final String? location;

  /// Always UTC. Normalize at ingestion; never store local time.
  final DateTime start;
  final DateTime end;

  final EventSource source;
  final String? sourceId;
  final EventStatus status;
  final String? tag;
  final EventImportance importance;
  final String? notes;
  final List<String>? attachments;
  final Map<String, dynamic>? repeat;
  final List<ReminderOffset>? reminders;

  factory CalendarEvent.fromMap(String id, Map<String, dynamic> map) {
    final startTs = map['start'];
    final endTs = map['end'];
    return CalendarEvent(
      id: id,
      title: map['title'] as String? ?? '',
      location: map['location'] as String?,
      start: startTs is Timestamp ? startTs.toDate().toUtc() : DateTime.now().toUtc(),
      end: endTs is Timestamp ? endTs.toDate().toUtc() : DateTime.now().toUtc(),
      source: EventSource.values.firstWhere(
        (s) => s.name == map['source'],
        orElse: () => EventSource.manual,
      ),
      sourceId: map['sourceId'] as String?,
      status: (map['status'] as String?) == 'pendingConflict'
          ? EventStatus.pendingConflict
          : EventStatus.active,
      tag: map['tag'] as String?,
      importance: (map['importance'] as String?) == 'locked'
          ? EventImportance.locked
          : EventImportance.flexible,
      notes: map['notes'] as String?,
      attachments: (map['attachments'] as List?)?.cast<String>(),
      repeat: (map['repeat'] as Map?)?.cast<String, dynamic>(),
      reminders: (map['reminders'] as List?)
          ?.map((r) => ReminderOffset.values.firstWhere((o) => o.name == r))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'location': location,
      'start': Timestamp.fromDate(start.toUtc()),
      'end': Timestamp.fromDate(end.toUtc()),
      'source': source.name,
      'sourceId': sourceId,
      'status': status == EventStatus.pendingConflict ? 'pendingConflict' : 'active',
      'tag': tag,
      'importance': importance == EventImportance.locked ? 'locked' : 'flexible',
      'notes': notes,
      'attachments': attachments,
      'repeat': repeat,
      'reminders': reminders?.map((r) => r.name).toList(),
    };
  }
}
