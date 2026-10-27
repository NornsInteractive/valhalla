import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/commands_provider.dart';
import '../../../data/models/quick_command.dart';

typedef TerminalSavedCommandResult = ({String command, bool isDangerous});

/// 终端常用命令选择与参数预览执行对话框。
class TerminalSavedCommandsDialog extends ConsumerStatefulWidget {
  const TerminalSavedCommandsDialog({super.key});

  static Future<TerminalSavedCommandResult?> show(BuildContext context) {
    return showDialog<TerminalSavedCommandResult>(
      context: context,
      builder: (ctx) => const TerminalSavedCommandsDialog(),
    );
  }

  @override
  ConsumerState<TerminalSavedCommandsDialog> createState() =>
      _TerminalSavedCommandsDialogState();
}

class _TerminalSavedCommandsDialogState
    extends ConsumerState<TerminalSavedCommandsDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _previewController = TextEditingController();
  QuickCommand? _selectedCommand;
  final Map<String, TextEditingController> _paramControllers = {};
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _previewController.dispose();
    for (final c in _paramControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectCommand(QuickCommand cmd) {
    for (final c in _paramControllers.values) {
      c.dispose();
    }
    _paramControllers.clear();
    final params = cmd.extractParams();
    for (final p in params) {
      _paramControllers[p] = TextEditingController();
    }
    setState(() {
      _selectedCommand = cmd;
      _updatePreview();
    });
  }

  void _updatePreview() {
    if (_selectedCommand == null) return;
    final values = <String, String>{};
    for (final entry in _paramControllers.entries) {
      final val = entry.value.text.trim();
      if (val.isNotEmpty) {
        values[entry.key] = val;
      }
    }
    _previewController.text = _selectedCommand!.applyParams(values);
  }

  bool get _canSend {
    if (_selectedCommand == null) return false;
    final text = _previewController.text.trim();
    if (text.isEmpty) return false;
    final params = _selectedCommand!.extractParams();
    for (final p in params) {
      if ((_paramControllers[p]?.text.trim() ?? '').isEmpty) {
        return false;
      }
    }
    if (RegExp(r'\{\{[a-zA-Z0-9_-]+\}\}').hasMatch(text)) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final commandsState = ref.watch(commandsProvider);
    final allCommands = commandsState.allCommands;

    final filtered = allCommands.where((cmd) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return cmd.title.toLowerCase().contains(q) ||
          cmd.command.toLowerCase().contains(q) ||
          cmd.category.toLowerCase().contains(q) ||
          cmd.description.toLowerCase().contains(q);
    }).toList();

    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 400;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VRadius.dialog),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _selectedCommand != null
              ? _buildPreviewAndParams(context, _selectedCommand!)
              : _buildCommandsList(context, filtered, isCompact),
        ),
      ),
    );
  }

  Widget _buildCommandsList(
    BuildContext context,
    List<QuickCommand> commands,
    bool isCompact,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.playlist_play, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.terminalSavedCommandsTitle,
                style: context.textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, size: 18),
            hintText: context.l10n.chatSearchCommandsHint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VRadius.input),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: commands.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          size: 40,
                          color: scheme.outline.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.terminalSavedCommandsEmpty,
                          style: TextStyle(color: scheme.outline),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: commands.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final cmd = commands[index];
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      leading: Icon(
                        cmd.isDangerous
                            ? Icons.warning_amber_rounded
                            : Icons.terminal,
                        size: 20,
                        color: cmd.isDangerous
                            ? context.vWarning
                            : scheme.primary,
                      ),
                      title: Text(
                        cmd.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        cmd.description.isNotEmpty
                            ? cmd.description
                            : cmd.command,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cmd.requiresSudo) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'sudo',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          const Icon(Icons.chevron_right, size: 16),
                        ],
                      ),
                      onTap: () => _selectCommand(cmd),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPreviewAndParams(BuildContext context, QuickCommand cmd) {
    final scheme = Theme.of(context).colorScheme;
    final params = cmd.extractParams();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => setState(() => _selectedCommand = null),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                cmd.title,
                style: context.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        if (cmd.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            cmd.description,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 12),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (params.isNotEmpty) ...[
                  for (final p in params) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: _paramControllers[p],
                        decoration: InputDecoration(
                          labelText: p,
                          hintText: '{{$p}}',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(VRadius.input),
                          ),
                        ),
                        onChanged: (_) => setState(() {
                          _updatePreview();
                        }),
                      ),
                    ),
                  ],
                ],
                Text(
                  context.l10n.terminalSavedCommandsPreview,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _previewController,
                  maxLines: 4,
                  minLines: 1,
                  style: monoTextStyle(fontSize: 12, color: scheme.onSurface),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.all(10),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VRadius.card),
                      borderSide: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VRadius.card),
                      borderSide: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (cmd.isDangerous) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: context.vWarning,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          cmd.isDangerous ? context.l10n.cmdDangerous : '',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.vWarning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OverflowBar(
          spacing: 8,
          overflowSpacing: 8,
          alignment: MainAxisAlignment.end,
          overflowAlignment: OverflowBarAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _selectedCommand = null),
              child: Text(context.l10n.cancel, softWrap: true),
            ),
            FilledButton.icon(
              key: const Key('terminal_saved_commands_run_button'),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: Text(
                context.l10n.terminalSavedCommandsRun,
                softWrap: true,
              ),
              onPressed: _canSend
                  ? () => Navigator.of(context).pop((
                      command: _previewController.text,
                      isDangerous: cmd.isDangerous,
                    ))
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
