import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/terminal_settings_provider.dart';

/// Dialog for customizing and reordering pinned accessory keys in the terminal.
class CustomizePinnedKeysDialog extends ConsumerStatefulWidget {
  const CustomizePinnedKeysDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const CustomizePinnedKeysDialog(),
    );
  }

  @override
  ConsumerState<CustomizePinnedKeysDialog> createState() =>
      _CustomizePinnedKeysDialogState();
}

class _CustomizePinnedKeysDialogState
    extends ConsumerState<CustomizePinnedKeysDialog> {
  late List<String> _pinnedKeys;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pinnedKeys = List.of(ref.read(terminalSettingsProvider).pinnedKeys);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _pinnedKeys.removeAt(oldIndex);
      _pinnedKeys.insert(newIndex, item);
    });
  }

  void _removeKey(String key) {
    setState(() {
      _pinnedKeys.remove(key);
    });
  }

  void _addKey(String key) {
    setState(() {
      if (!_pinnedKeys.contains(key)) {
        _pinnedKeys.add(key);
      }
    });
  }

  void _resetToDefault() {
    setState(() {
      _pinnedKeys = List.of(TerminalSettings.defaultPinnedKeys);
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(terminalSettingsProvider.notifier)
          .setPinnedKeys(_pinnedKeys);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save pinned keys: $e'),
            backgroundColor: context.colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unpinnedKeys = TerminalSettings.availableKeys
        .where((k) => !_pinnedKeys.contains(k))
        .toList();
    final dialogWidth = (MediaQuery.sizeOf(context).width - 48).clamp(
      280.0,
      480.0,
    );

    return AlertDialog(
      title: Text(context.l10n.settingsTerminalPinnedKeys),
      content: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 540),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.settingsTerminalPinnedKeysSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 12),
                // Current pinned keys list
                Text(
                  'Pinned (${_pinnedKeys.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.colorScheme.outlineVariant,
                    ),
                  ),
                  child: _pinnedKeys.isEmpty
                      ? Center(
                          child: Text(
                            'No pinned keys',
                            style: TextStyle(
                              color: context.colorScheme.outline,
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          itemCount: _pinnedKeys.length,
                          onReorder: _onReorder,
                          buildDefaultDragHandles: false,
                          itemBuilder: (context, index) {
                            final keyName = _pinnedKeys[index];
                            return ListTile(
                              key: ValueKey('pinned_$keyName'),
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              leading: ReorderableDragStartListener(
                                index: index,
                                child: const SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: Icon(Icons.drag_handle, size: 20),
                                  ),
                                ),
                              ),
                              title: Text(
                                keyName,
                                style: monoTextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: SizedBox(
                                width: 44,
                                height: 44,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    size: 18,
                                  ),
                                  color: context.colorScheme.error,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _removeKey(keyName),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                // Unpinned available keys
                if (unpinnedKeys.isNotEmpty) ...[
                  Text(
                    'Available to Add (${unpinnedKeys.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: unpinnedKeys.map((k) {
                      return ActionChip(
                        avatar: const Icon(Icons.add, size: 14),
                        label: Text(
                          k,
                          style: monoTextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _addKey(k),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : _resetToDefault,
          child: Text(context.l10n.terminalResetPinnedKeys),
        ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('terminal_save_pinned_keys_button'),
          onPressed: _isSaving ? null : _save,
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}
