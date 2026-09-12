/// Which event field a [TagRule] inspects.
enum RuleField { title, location, notes }

/// How a [TagRule] compares its field's value against [TagRule.value].
enum RuleOperator { contains, equals }

/// One `match: {...}` entry from the per-user tag-routing settings:
/// "if `field` `operator` `value`, assign `tag`".
class TagRule {
  const TagRule({required this.field, required this.operator, required this.value, required this.tag});

  final RuleField field;
  final RuleOperator operator;
  final String value;

  /// The tag id (from the user's tag collection) to assign on a match.
  final String tag;

  factory TagRule.fromMap(Map<String, dynamic> map) {
    final match = (map['match'] as Map?)?.cast<String, dynamic>() ?? const {};
    return TagRule(
      field: RuleField.values.firstWhere((f) => f.name == match['field'], orElse: () => RuleField.title),
      operator: RuleOperator.values.firstWhere(
        (o) => o.name == match['operator'],
        orElse: () => RuleOperator.contains,
      ),
      value: match['value'] as String? ?? '',
      tag: map['tag'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'match': {'field': field.name, 'operator': operator.name, 'value': value},
      'tag': tag,
    };
  }
}

/// Per-user tag-routing settings, stored as a single document.
class TagRoutingSettings {
  const TagRoutingSettings({this.autoTagEnabled = false, this.tagRules = const []});

  final bool autoTagEnabled;
  final List<TagRule> tagRules;

  factory TagRoutingSettings.fromMap(Map<String, dynamic> map) {
    return TagRoutingSettings(
      autoTagEnabled: map['autoTagEnabled'] as bool? ?? false,
      tagRules: (map['tagRules'] as List?)
              ?.map((r) => TagRule.fromMap((r as Map).cast<String, dynamic>()))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autoTagEnabled': autoTagEnabled,
      'tagRules': tagRules.map((r) => r.toMap()).toList(),
    };
  }

  TagRoutingSettings copyWith({bool? autoTagEnabled, List<TagRule>? tagRules}) {
    return TagRoutingSettings(
      autoTagEnabled: autoTagEnabled ?? this.autoTagEnabled,
      tagRules: tagRules ?? this.tagRules,
    );
  }
}
