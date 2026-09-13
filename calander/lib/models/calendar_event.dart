import 'package:cloud_firestore/cloud_firestore.dart';

/// Timed events are instants; all-day events are calendar dates in every zone.
/// The end is exclusive, including the day after the last all-day date.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.location = '',
    this.notes = '',
    this.tagId,
    this.allDay = false,
    this.flexible = false,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String location;
  final String notes;
  final String? tagId;
  final bool allDay;
  final bool flexible;

  factory CalendarEvent.fromMap(String id, Map<String, dynamic> data) {
    final allDay = data['allDay'] as bool;
    DateTime decode(String key) {
      final instant = (data[key] as Timestamp).toDate();
      if (!allDay) return instant.toLocal();
      final utc = instant.toUtc();
      return DateTime(utc.year, utc.month, utc.day);
    }

    return CalendarEvent(
      id: id,
      title: data['title'] as String,
      start: decode('startAt'),
      end: decode('endAt'),
      location: data['location'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      tagId: data['tagId'] as String?,
      allDay: allDay,
      flexible: data['flexible'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    Timestamp encode(DateTime date) => Timestamp.fromDate(
      allDay ? DateTime.utc(date.year, date.month, date.day) : date.toUtc(),
    );
    return {
      'title': title.trim(),
      'location': location.trim(),
      'notes': notes.trim(),
      'startAt': encode(start),
      'endAt': encode(end),
      'allDay': allDay,
      'flexible': flexible,
      'tagId': tagId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  bool occursOn(DateTime day) {
    final from = dateOnly(day);
    final until = DateTime(day.year, day.month, day.day + 1);
    return start.isBefore(until) && end.isAfter(from);
  }
}

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
