import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/terminal_settings_provider.dart';
import 'direction_key_color_dialog.dart';

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
  late TerminalDirectionPadMode _directionPadMode;
  int? _directionKeySeedColorValue;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(terminalSettingsProvider);
    _pinnedKeys = List.of(settings.pinnedKeys);
    _directionPadMode = settings.directionPadMode;
    _directionKeySeedColorValue = settings.directionKeySeedColorValue;
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (_isSaving) return;
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _pinnedKeys.removeAt(oldIndex);
      _pinnedKeys.insert(newIndex, item);
    });
  }

  void _removeKey(String key) {
    if (_isSaving) return;
    setState(() {
      _pinnedKeys.remove(key);
      if (key == 'ARROWS') {
        _directionPadMode = TerminalDirectionPadMode.hidden;
      }
    });
  }

  void _addKey(String key) {
    if (_isSaving) return;
    setState(() {
      if (!_pinnedKeys.contains(key)) {
        _pinnedKeys.add(key);
        if (key == 'ARROWS') {
          _directionPadMode = TerminalDirectionPadMode.fixed;
        }
      }
    });
  }

  void _resetToDefault() {
    if (_isSaving) return;
    setState(() {
      _pinnedKeys = List.of(TerminalSettings.defaultPinnedKeys);
      _directionPadMode = TerminalDirectionPadMode.fixed;
      _directionKeySeedColorValue = null;
    });
  }

  String _displayKeyLabel(BuildContext context, String key) {
    if (key == 'ARROWS') {
      return context.l10n.terminalKeyArrows;
    }
    return key;
  }

  Future<void> _openColorPicker() async {
    final result = await DirectionKeyColorDialog.show(
      context,
      initialColorValue: _directionKeySeedColorValue,
    );
    if (result != null && mounted) {
      setState(() {
        if (result.resetToTheme) {
          _directionKeySeedColorValue = null;
        } else if (result.colorValue != null) {
          _directionKeySeedColorValue = result.colorValue;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(terminalSettingsProvider.notifier)
          .setAccessorySettings(
            pinnedKeys: _pinnedKeys,
            directionPadMode: _directionPadMode,
            directionKeySeedColorValue: _directionKeySeedColorValue,
          );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.terminalAccessorySaveFailed),
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

    return PopScope(
      canPop: !_isSaving,
      child: AlertDialog(
        title: Text(context.l10n.settingsTerminalPinnedKeys),
        content: SizedBox(
          width: dialogWidth,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 560),
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

                  // 1. Direction pad mode selector (Wrap to prevent squeezing on narrow/2x font screens)
                  Text(
                    context.l10n.terminalDirectionPad,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        selected:
                            _directionPadMode == TerminalDirectionPadMode.fixed,
                        avatar: const Icon(Icons.push_pin_outlined, size: 16),
                        label: Text(context.l10n.terminalDirectionPadModeFixed),
                        onSelected: _isSaving
                            ? null
                            : (val) {
                                if (val) {
                                  setState(() {
                                    _directionPadMode =
                                        TerminalDirectionPadMode.fixed;
                                    if (!_pinnedKeys.contains('ARROWS')) {
                                      _pinnedKeys.add('ARROWS');
                                    }
                                  });
                                }
                              },
                      ),
                      ChoiceChip(
                        selected:
                            _directionPadMode == TerminalDirectionPadMode.flow,
                        avatar: const Icon(Icons.swap_horiz, size: 16),
                        label: Text(context.l10n.terminalDirectionPadModeFlow),
                        onSelected: _isSaving
                            ? null
                            : (val) {
                                if (val) {
                                  setState(() {
                                    _directionPadMode =
                                        TerminalDirectionPadMode.flow;
                                    if (!_pinnedKeys.contains('ARROWS')) {
                                      _pinnedKeys.add('ARROWS');
                                    }
                                  });
                                }
                              },
                      ),
                      ChoiceChip(
                        selected:
                            _directionPadMode ==
                            TerminalDirectionPadMode.hidden,
                        avatar: const Icon(
                          Icons.visibility_off_outlined,
                          size: 16,
                        ),
                        label: Text(
                          context.l10n.terminalDirectionPadModeHidden,
                        ),
                        onSelected: _isSaving
                            ? null
                            : (val) {
                                if (val) {
                                  setState(() {
                                    // Mode switches to hidden; keep ARROWS marker so original order in flow is not lost
                                    _directionPadMode =
                                        TerminalDirectionPadMode.hidden;
                                  });
                                }
                              },
                      ),
                    ],
                  ),

                  // 2. Direction key independent color setting
                  if (_directionPadMode != TerminalDirectionPadMode.hidden) ...[
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final maxAvailableWidth = constraints.maxWidth;
                        final swatch = _directionKeySeedColorValue != null
                            ? Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Color(_directionKeySeedColorValue!),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: context.colorScheme.outlineVariant,
                                  ),
                                ),
                              )
                            : null;

                        final button = ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxAvailableWidth,
                          ),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.palette_outlined, size: 14),
                            label: Text(
                              context.l10n.terminalDirectionKeyColor,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: _isSaving ? null : _openColorPicker,
                          ),
                        );

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxAvailableWidth,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    context.l10n.terminalDirectionKeyColor,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _directionKeySeedColorValue != null
                                        ? '#${(_directionKeySeedColorValue! & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'
                                        : context
                                              .l10n
                                              .terminalDirectionKeyColorDefault,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxAvailableWidth,
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [?swatch, button],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 14),

                  // 3. Current pinned keys list
                  Text(
                    context.l10n.terminalPinnedKeysCount(_pinnedKeys.length),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 190,
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
                              context.l10n.terminalNoPinnedKeys,
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
                                leading: _isSaving
                                    ? const SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Center(
                                          child: Icon(
                                            Icons.drag_handle,
                                            size: 20,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      )
                                    : ReorderableDragStartListener(
                                        index: index,
                                        child: const SizedBox(
                                          width: 44,
                                          height: 44,
                                          child: Center(
                                            child: Icon(
                                              Icons.drag_handle,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                title: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (keyName == 'ARROWS') ...[
                                      const Icon(Icons.open_with, size: 16),
                                      const SizedBox(width: 6),
                                    ],
                                    Flexible(
                                      child: Text(
                                        _displayKeyLabel(context, keyName),
                                        style: monoTextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
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
                                    onPressed: _isSaving
                                        ? null
                                        : () => _removeKey(keyName),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Unpinned available keys
                  if (unpinnedKeys.isNotEmpty) ...[
                    Text(
                      context.l10n.terminalAvailableKeysCount(
                        unpinnedKeys.length,
                      ),
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
                          avatar: Icon(
                            k == 'ARROWS' ? Icons.open_with : Icons.add,
                            size: 14,
                          ),
                          label: Text(
                            _displayKeyLabel(context, k),
                            style: monoTextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onPressed: _isSaving ? null : () => _addKey(k),
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
      ),
    );
  }
}
