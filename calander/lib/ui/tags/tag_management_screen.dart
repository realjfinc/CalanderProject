import 'package:flutter/material.dart';

import '../../models/event_tag.dart';
import '../../services/tag_repository.dart';

/// Fixed palette offered when creating or editing a tag.
const List<int> kTagColorPalette = [
  0xFFE53935, // red
  0xFF1E88E5, // blue
  0xFF43A047, // green
  0xFFFB8C00, // orange
  0xFF8E24AA, // purple
  0xFF00897B, // teal
  0xFFFDD835, // yellow
  0xFF6D4C41, // brown
  0xFF546E7A, // blue grey
  0xFFD81B60, // pink
];

/// Lets the user view, add, rename, recolor, and delete their tags.
class TagManagementScreen extends StatefulWidget {
  const TagManagementScreen({super.key, required this.repository});

  final TagRepository repository;

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = widget.repository.ensureDefaultTagsInitialized();
  }

  Future<void> _openTagDialog({EventTag? existing}) async {
    final result = await showDialog<_TagDialogResult>(
      context: context,
      builder: (context) => _TagEditDialog(existing: existing),
    );
    if (result == null) return;

    if (existing == null) {
      await widget.repository.addTag(
        name: result.name,
        colorValue: result.colorValue,
      );
    } else {
      await widget.repository.updateTag(
        existing.id,
        name: result.name,
        colorValue: result.colorValue,
      );
    }
  }

  Future<void> _confirmDelete(EventTag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete tag?'),
        content: Text('Delete "${tag.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteTag(tag.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Tags')),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, initSnapshot) {
          if (initSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (initSnapshot.hasError) {
            return Center(child: Text('Failed to load tags: ${initSnapshot.error}'));
          }
          return StreamBuilder<List<EventTag>>(
            stream: widget.repository.watchTags(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final tags = snapshot.data!;
              if (tags.isEmpty) {
                return const Center(child: Text('No tags yet. Tap + to add one.'));
              }
              return ListView.builder(
                itemCount: tags.length,
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  return ListTile(
                    key: ValueKey(tag.id),
                    leading: CircleAvatar(
                      backgroundColor: Color(tag.colorValue),
                      radius: 12,
                    ),
                    title: Text(tag.name),
                    subtitle: tag.isDefault ? const Text('Default tag') : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit',
                          onPressed: () => _openTagDialog(existing: tag),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete',
                          onPressed: () => _confirmDelete(tag),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTagDialog(),
        tooltip: 'Add tag',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TagDialogResult {
  const _TagDialogResult(this.name, this.colorValue);
  final String name;
  final int colorValue;
}

class _TagEditDialog extends StatefulWidget {
  const _TagEditDialog({this.existing});
  final EventTag? existing;

  @override
  State<_TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<_TagEditDialog> {
  late final TextEditingController _nameController;
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _selectedColor = widget.existing?.colorValue ?? kTagColorPalette.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add tag' : 'Edit tag'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kTagColorPalette.map((colorValue) {
              final isSelected = colorValue == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = colorValue),
                child: CircleAvatar(
                  backgroundColor: Color(colorValue),
                  radius: 16,
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(_TagDialogResult(name, _selectedColor));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
