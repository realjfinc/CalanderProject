import 'package:cloud_firestore/cloud_firestore.dart';

/// A user-defined label that can be attached to a calendar event.
///
/// Tags live under `users/{uid}/tags/{tagId}` in Firestore. Only direct user
/// action or the Step 5 tag-routing logic may ever assign a tag to an event;
/// this model itself carries no event data.
class EventTag {
  const EventTag({
    required this.id,
    required this.name,
    required this.colorValue,
    this.isDefault = false,
    this.createdAt,
  });

  final String id;
  final String name;

  /// ARGB color value (`Color.value`) used to render this tag.
  final int colorValue;

  /// Whether this tag was created by the default-tag initializer
  /// (Work / Personal / School) rather than by the user.
  final bool isDefault;
  final DateTime? createdAt;

  factory EventTag.fromMap(String id, Map<String, dynamic> map) {
    final rawTimestamp = map['createdAt'];
    return EventTag(
      id: id,
      name: map['name'] as String? ?? '',
      colorValue: map['colorValue'] as int? ?? 0xFF9E9E9E,
      isDefault: map['isDefault'] as bool? ?? false,
      createdAt: rawTimestamp is Timestamp ? rawTimestamp.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'colorValue': colorValue,
      'isDefault': isDefault,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  EventTag copyWith({String? name, int? colorValue}) {
    return EventTag(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault,
      createdAt: createdAt,
    );
  }
}
