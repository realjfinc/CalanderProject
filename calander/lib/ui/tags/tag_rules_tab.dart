import 'package:flutter/material.dart';

import '../../models/event_tag.dart';
import '../../models/tag_rule.dart';
import '../../services/tag_repository.dart';
import '../../services/tag_routing_repository.dart';

/// Lets the user turn auto-tagging on/off and manage the rules it uses.
/// Per spec, auto-tagging never runs while `autoTagEnabled` is false, and
/// this screen is the only thing (besides direct per-event tagging in
/// [EventTagsTab]) that ever writes here.
class TagRulesTab extends StatelessWidget {
  const TagRulesTab({super.key, required this.routingRepository, required this.tagRepository});

  final TagRoutingRepository routingRepository;
  final TagRepository tagRepository;

  Future<void> _addOrEditRule(
    BuildContext context,
    TagRoutingSettings settings,
    List<EventTag> tags, {
    int? editIndex,
  }) async {
    final result = await showDialog<TagRule>(
      context: context,
      builder: (context) => _TagRuleDialog(
        tags: tags,
        existing: editIndex == null ? null : settings.tagRules[editIndex],
      ),
    );
    if (result == null) return;

    final updatedRules = [...settings.tagRules];
    if (editIndex == null) {
      updatedRules.add(result);
    } else {
      updatedRules[editIndex] = result;
    }
    await routingRepository.updateSettings(settings.copyWith(tagRules: updatedRules));
  }

  Future<void> _deleteRule(TagRoutingSettings settings, int index) async {
    final updatedRules = [...settings.tagRules]..removeAt(index);
    await routingRepository.updateSettings(settings.copyWith(tagRules: updatedRules));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventTag>>(
      stream: tagRepository.watchTags(),
      builder: (context, tagSnapshot) {
        final tags = tagSnapshot.data ?? const [];
        final tagsById = {for (final tag in tags) tag.id: tag};

        return StreamBuilder<TagRoutingSettings>(
          stream: routingRepository.watchSettings(),
          builder: (context, settingsSnapshot) {
            if (!settingsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final settings = settingsSnapshot.data!;
            return Column(
              children: [
                SwitchListTile(
                  title: const Text('Auto-tag new events'),
                  subtitle: const Text('Apply the rules below to events that have no tag yet.'),
                  value: settings.autoTagEnabled,
                  onChanged: (value) =>
                      routingRepository.updateSettings(settings.copyWith(autoTagEnabled: value)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: settings.tagRules.isEmpty
                      ? const Center(child: Text('No rules yet. Tap + to add one.'))
                      : ListView.builder(
                          itemCount: settings.tagRules.length,
                          itemBuilder: (context, index) {
                            final rule = settings.tagRules[index];
                            final tag = tagsById[rule.tag];
                            return ListTile(
                              title: Text('${rule.field.name} ${rule.operator.name} "${rule.value}"'),
                              subtitle: Text('→ ${tag?.name ?? rule.tag}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () =>
                                        _addOrEditRule(context, settings, tags, editIndex: index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteRule(settings, index),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TagRuleDialog extends StatefulWidget {
  const _TagRuleDialog({required this.tags, this.existing});
  final List<EventTag> tags;
  final TagRule? existing;

  @override
  State<_TagRuleDialog> createState() => _TagRuleDialogState();
}

class _TagRuleDialogState extends State<_TagRuleDialog> {
  late RuleField _field;
  late RuleOperator _operator;
  late final TextEditingController _valueController;
  String? _selectedTagId;

  @override
  void initState() {
    super.initState();
    _field = widget.existing?.field ?? RuleField.title;
    _operator = widget.existing?.operator ?? RuleOperator.contains;
    _valueController = TextEditingController(text: widget.existing?.value ?? '');
    _selectedTagId = widget.existing?.tag ?? (widget.tags.isEmpty ? null : widget.tags.first.id);
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add rule' : 'Edit rule'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<RuleField>(
            initialValue: _field,
            decoration: const InputDecoration(labelText: 'Field'),
            items: RuleField.values
                .map((f) => DropdownMenuItem(value: f, child: Text(f.name)))
                .toList(),
            onChanged: (value) => setState(() => _field = value!),
          ),
          DropdownButtonFormField<RuleOperator>(
            initialValue: _operator,
            decoration: const InputDecoration(labelText: 'Operator'),
            items: RuleOperator.values
                .map((o) => DropdownMenuItem(value: o, child: Text(o.name)))
                .toList(),
            onChanged: (value) => setState(() => _operator = value!),
          ),
          TextField(controller: _valueController, decoration: const InputDecoration(labelText: 'Value')),
          DropdownButtonFormField<String>(
            initialValue: _selectedTagId,
            decoration: const InputDecoration(labelText: 'Assign tag'),
            items: widget.tags
                .map((tag) => DropdownMenuItem(value: tag.id, child: Text(tag.name)))
                .toList(),
            onChanged: (value) => setState(() => _selectedTagId = value),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final value = _valueController.text.trim();
            if (value.isEmpty || _selectedTagId == null) return;
            Navigator.of(context).pop(
              TagRule(field: _field, operator: _operator, value: value, tag: _selectedTagId!),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
