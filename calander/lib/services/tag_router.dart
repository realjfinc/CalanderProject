import '../models/calendar_event.dart';
import '../models/tag_rule.dart';

/// Pure rule-matching logic: decides which tag (if any) an event's current
/// content resolves to under the user's tag-routing settings.
///
/// This is the ONLY place auto-tagging logic lives, and it never runs when
/// `autoTagEnabled` is false. It only ever *proposes* a tag for events that
/// don't already have one — callers must not use this to overwrite an
/// existing tag (manual or previously auto-assigned), since the user must
/// always be able to override an automatic assignment.
String? resolveAutoTag(CalendarEvent event, TagRoutingSettings settings) {
  if (!settings.autoTagEnabled) return null;

  for (final rule in settings.tagRules) {
    if (_matches(event, rule)) return rule.tag;
  }
  return null;
}

bool _matches(CalendarEvent event, TagRule rule) {
  final fieldValue = switch (rule.field) {
    RuleField.title => event.title,
    RuleField.location => event.location ?? '',
    RuleField.notes => event.notes ?? '',
  };

  final haystack = fieldValue.toLowerCase();
  final needle = rule.value.toLowerCase();
  if (needle.isEmpty) return false;

  return switch (rule.operator) {
    RuleOperator.contains => haystack.contains(needle),
    RuleOperator.equals => haystack == needle,
  };
}
