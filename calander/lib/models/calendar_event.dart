import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical event schema — the hard contract every feature that creates or
/// reads events must respect. Timestamps are always normalized to UTC at
/// ingestion, `tag` may only be assigned by direct user action or Step 5's
/// tag-routing logic (never by a source adapter), and dedup/conflict rules
/// key off `(source, sourceId)`.
enum EventSource { manual, upload, screenshot, google, outlook, icloud, sports }

enum EventStatus { active, pendingConflict }

enum EventImportance { locked, flexible }

enum ReminderOffset {
  fiveMinutes,
  tenMinutes,
  fifteenMinutes,
  thirtyMinutes,
  oneHour,
  oneDay,
}

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
    this.source = EventSource.manual,
    this.allDay = false,
    this.sourceId,
    this.sportsTeamIds,
    this.status = EventStatus.active,
    this.tag,
    this.importance = EventImportance.flexible,
    this.notes,
    this.attachments,
    this.repeat,
    this.reminders,
    this.conflictGroupId,
    this.conflictRole,
  });

  final String id;
  final String title;
  final String? location;

  /// Always UTC. Normalize at ingestion; never store local time.
  final DateTime start;
  final DateTime end;

  final bool allDay;
  final EventSource source;
  String? get tagId => tag;
  bool get flexible => importance == EventImportance.flexible;
  DateTime get localStart => _displayDate(start);
  DateTime get localEnd => _displayDate(end);
  DateTime _displayDate(DateTime value) {
    if (!allDay) return value.toLocal();
    final utc = value.toUtc();
    return DateTime(utc.year, utc.month, utc.day);
  }

  bool occursOn(DateTime day) =>
      localStart.isBefore(DateTime(day.year, day.month, day.day + 1)) &&
      localEnd.isAfter(dateOnly(day));

  final String? sourceId;

  /// Sports API team ids whose schedules contributed this event. A game can
  /// belong to more than one followed team when they play each other.
  final List<String>? sportsTeamIds;
  final EventStatus status;
  final String? tag;
  final EventImportance importance;
  final String? notes;
  final List<String>? attachments;
  final Map<String, dynamic>? repeat;
  final List<ReminderOffset>? reminders;

  /// Links a `pendingConflict` event to the other side of the same
  /// cross-source conflict (see Step 6's dedup/conflict utility). Not part
  /// of the roadmap's baseline field list; a purely additive extension
  /// needed to implement "Keep original / Keep new / Keep both" without a
  /// separate conflicts collection. Null outside of an active conflict.
  final String? conflictGroupId;

  /// `'original'` (the event that was already active before the conflict
  /// was detected) or `'new'` (the just-synced event that triggered it).
  /// Only meaningful alongside [conflictGroupId]; lets the resolution UI
  /// implement the roadmap's exact "Keep original / Keep new / Keep both"
  /// choices without guessing from insertion order.
  final String? conflictRole;

  factory CalendarEvent.fromMap(String id, Map<String, dynamic> map) {
    final startTs = map['start'] ?? map['startAt'];
    final endTs = map['end'] ?? map['endAt'];
    return CalendarEvent(
      id: id,
      title: map['title'] as String? ?? '',
      location: map['location'] as String?,
      start: startTs is Timestamp
          ? startTs.toDate().toUtc()
          : DateTime.now().toUtc(),
      end: endTs is Timestamp ? endTs.toDate().toUtc() : DateTime.now().toUtc(),
      allDay: map['allDay'] as bool? ?? false,
      source: EventSource.values.firstWhere(
        (s) => s.name == map['source'],
        orElse: () => EventSource.manual,
      ),
      sourceId: map['sourceId'] as String?,
      sportsTeamIds: (map['sportsTeamIds'] as List?)?.cast<String>(),
      status: (map['status'] as String?) == 'pendingConflict'
          ? EventStatus.pendingConflict
          : EventStatus.active,
      tag: (map['tag'] ?? map['tagId']) as String?,
      importance:
          (map['importance'] as String?) == 'locked' ||
              (map['importance'] == null && map['flexible'] == false)
          ? EventImportance.locked
          : EventImportance.flexible,
      notes: map['notes'] as String?,
      attachments: (map['attachments'] as List?)?.cast<String>(),
      repeat: (map['repeat'] as Map?)?.cast<String, dynamic>(),
      reminders: (map['reminders'] as List?)
          ?.map((r) => ReminderOffset.values.firstWhere((o) => o.name == r))
          .toList(),
      conflictGroupId: map['conflictGroupId'] as String?,
      conflictRole: map['conflictRole'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'startAt': Timestamp.fromDate(start.toUtc()),
      'endAt': Timestamp.fromDate(end.toUtc()),
      'allDay': allDay,
      'tagId': tag,
      'flexible': flexible,
      'updatedAt': FieldValue.serverTimestamp(),
      'location': location ?? '',
      'start': Timestamp.fromDate(start.toUtc()),
      'end': Timestamp.fromDate(end.toUtc()),
      'source': source.name,
      'sourceId': sourceId,
      'sportsTeamIds': sportsTeamIds,
      'status': status == EventStatus.pendingConflict
          ? 'pendingConflict'
          : 'active',
      'tag': tag,
      'importance': importance == EventImportance.locked
          ? 'locked'
          : 'flexible',
      'notes': notes ?? '',
      'attachments': attachments,
      'repeat': repeat,
      'reminders': reminders?.map((r) => r.name).toList(),
      'conflictGroupId': conflictGroupId,
      'conflictRole': conflictRole,
    };
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    Object? location = _unset,
    DateTime? start,
    DateTime? end,
    EventSource? source,
    bool? allDay,
    Object? sourceId = _unset,
    Object? sportsTeamIds = _unset,
    EventStatus? status,
    Object? tag = _unset,
    EventImportance? importance,
    Object? notes = _unset,
    Object? attachments = _unset,
    Object? repeat = _unset,
    Object? reminders = _unset,
    Object? conflictGroupId = _unset,
    Object? conflictRole = _unset,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      location: identical(location, _unset)
          ? this.location
          : location as String?,
      start: start ?? this.start,
      end: end ?? this.end,
      source: source ?? this.source,
      allDay: allDay ?? this.allDay,
      sourceId: identical(sourceId, _unset)
          ? this.sourceId
          : sourceId as String?,
      sportsTeamIds: identical(sportsTeamIds, _unset)
          ? this.sportsTeamIds
          : sportsTeamIds as List<String>?,
      status: status ?? this.status,
      tag: identical(tag, _unset) ? this.tag : tag as String?,
      importance: importance ?? this.importance,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      attachments: identical(attachments, _unset)
          ? this.attachments
          : attachments as List<String>?,
      repeat: identical(repeat, _unset)
          ? this.repeat
          : repeat as Map<String, dynamic>?,
      reminders: identical(reminders, _unset)
          ? this.reminders
          : reminders as List<ReminderOffset>?,
      conflictGroupId: identical(conflictGroupId, _unset)
          ? this.conflictGroupId
          : conflictGroupId as String?,
      conflictRole: identical(conflictRole, _unset)
          ? this.conflictRole
          : conflictRole as String?,
    );
  }
}

/// Sentinel so [CalendarEvent.copyWith] can tell "not passed" apart from
/// "explicitly passed null" for nullable fields.
const _unset = Object();

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
bool sameDay(DateTime a, DateTime b) => dateOnly(a) == dateOnly(b);

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
String monthLabel(DateTime day) => '${monthNames[day.month - 1]} ${day.year}';
String dateLabel(DateTime day) =>
    '${monthNames[day.month - 1]} ${day.day}, ${day.year}';
String dayLabel(DateTime day) =>
    '${weekdayNames[day.weekday - 1]}, ${monthNames[day.month - 1]} ${day.day}';
