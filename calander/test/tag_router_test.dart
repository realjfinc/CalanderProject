import 'package:calander/models/calendar_event.dart';
import 'package:calander/models/tag_rule.dart';
import 'package:calander/services/tag_router.dart';
import 'package:flutter_test/flutter_test.dart';

CalendarEvent _event({
  String title = 'Standup',
  String? location,
  String? notes,
  EventStatus status = EventStatus.active,
}) {
  final now = DateTime.utc(2026);
  return CalendarEvent(
    id: 'e1',
    title: title,
    location: location,
    notes: notes,
    status: status,
    start: now,
    end: now.add(const Duration(hours: 1)),
    source: EventSource.manual,
  );
}

void main() {
  test('returns null when auto-tagging is disabled, even with a matching rule', () {
    final settings = TagRoutingSettings(
      autoTagEnabled: false,
      tagRules: [
        const TagRule(field: RuleField.title, operator: RuleOperator.contains, value: 'standup', tag: 'work'),
      ],
    );
    expect(resolveAutoTag(_event(), settings), isNull);
  });

  test('matches a "contains" rule on the title, case-insensitively', () {
    final settings = TagRoutingSettings(
      autoTagEnabled: true,
      tagRules: [
        const TagRule(field: RuleField.title, operator: RuleOperator.contains, value: 'STANDUP', tag: 'work'),
      ],
    );
    expect(resolveAutoTag(_event(title: 'Daily standup'), settings), 'work');
  });

  test('matches an "equals" rule exactly, not as a substring', () {
    final settings = TagRoutingSettings(
      autoTagEnabled: true,
      tagRules: [
        const TagRule(field: RuleField.title, operator: RuleOperator.equals, value: 'standup', tag: 'work'),
      ],
    );
    expect(resolveAutoTag(_event(title: 'Daily standup'), settings), isNull);
    expect(resolveAutoTag(_event(title: 'standup'), settings), 'work');
  });

  test('matches on location and notes fields too', () {
    final locationSettings = TagRoutingSettings(
      autoTagEnabled: true,
      tagRules: [
        const TagRule(field: RuleField.location, operator: RuleOperator.contains, value: 'gym', tag: 'health'),
      ],
    );
    expect(resolveAutoTag(_event(location: 'City Gym'), locationSettings), 'health');

    final notesSettings = TagRoutingSettings(
      autoTagEnabled: true,
      tagRules: [
        const TagRule(field: RuleField.notes, operator: RuleOperator.contains, value: 'invoice', tag: 'finance'),
      ],
    );
    expect(resolveAutoTag(_event(notes: 'send invoice after'), notesSettings), 'finance');
  });

  test('a null location/notes never matches (treated as empty, not a crash)', () {
    final settings = TagRoutingSettings(
      autoTagEnabled: true,
      tagRules: [
        const TagRule(field: RuleField.location, operator: RuleOperator.contains, value: 'gym', tag: 'health'),
      ],
    );
    expect(resolveAutoTag(_event(location: null), settings), isNull);
  });

  test('the first matching rule wins when multiple rules could match', () {
    final settings = TagRoutingSettings(
      autoTagEnabled: true,
      tagRules: [
        const TagRule(field: RuleField.title, operator: RuleOperator.contains, value: 'standup', tag: 'first'),
        const TagRule(field: RuleField.title, operator: RuleOperator.contains, value: 'standup', tag: 'second'),
      ],
    );
    expect(resolveAutoTag(_event(title: 'Daily standup'), settings), 'first');
  });

  test('returns null when no rule matches', () {
    final settings = TagRoutingSettings(
      autoTagEnabled: true,
      tagRules: [
        const TagRule(field: RuleField.title, operator: RuleOperator.contains, value: 'gym', tag: 'health'),
      ],
    );
    expect(resolveAutoTag(_event(title: 'Standup'), settings), isNull);
  });

  test('an empty rule value never matches anything', () {
    final settings = TagRoutingSettings(
      autoTagEnabled: true,
      tagRules: [const TagRule(field: RuleField.title, operator: RuleOperator.contains, value: '', tag: 'x')],
    );
    expect(resolveAutoTag(_event(title: 'anything'), settings), isNull);
  });
}
