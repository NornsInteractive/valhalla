import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/security_settings_provider.dart';
import '../../../core/providers/server_provider.dart';

class ClearCredentialsDialog extends ConsumerStatefulWidget {
  const ClearCredentialsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ClearCredentialsDialog(),
    );
  }

  @override
  ConsumerState<ClearCredentialsDialog> createState() =>
      _ClearCredentialsDialogState();
}

class _ClearCredentialsDialogState
    extends ConsumerState<ClearCredentialsDialog> {
  final Set<String> _selectedServerIds = {};
  bool _isClearing = false;
  String? _errorMessage;

  Future<void> _handleClear(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.settingsClearStorageConfirmTitle),
        content: Text(ctx.l10n.settingsClearStorageConfirmMessage(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.vDanger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.settingsClearStorage),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isClearing = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(securitySettingsProvider)
          .clearServerCredentials(_selectedServerIds.toList());
      if (mounted && context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.settingsClearStorageSuccess)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isClearing = false;
          _errorMessage = context.l10n.settingsClearStorageError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(serverListProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock_reset, color: context.vDanger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.settingsClearStorageDialogTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: servers.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.dns_outlined,
                        size: 48,
                        color: context.colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.settingsClearStorageNoServers,
                        style: TextStyle(color: context.colorScheme.outline),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.l10n.settingsClearStorageDesc,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final countText = Text(
                            '${_selectedServerIds.length}/${servers.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.colorScheme.primary,
                            ),
                          );

                          final toggleButton = TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: _isClearing
                                ? null
                                : () {
                                    setState(() {
                                      if (_selectedServerIds.length ==
                                          servers.length) {
                                        _selectedServerIds.clear();
                                      } else {
                                        _selectedServerIds.addAll(
                                          servers.map((s) => s.id),
                                        );
                                      }
                                    });
                                  },
                            child: Text(
                              _selectedServerIds.length == servers.length
                                  ? context.l10n.settingsClearStorageDeselectAll
                                  : context.l10n.settingsClearStorageSelectAll,
                            ),
                          );

                          if (constraints.maxWidth < 320) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                countText,
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: toggleButton,
                                ),
                              ],
                            );
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [countText, toggleButton],
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: servers.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (ctx, index) {
                          final server = servers[index];
                          final isSelected = _selectedServerIds.contains(
                            server.id,
                          );
                          return CheckboxListTile(
                            key: Key('server_credential_${server.id}'),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              server.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${server.username}@${server.host}:${server.port}',
                              style: monoTextStyle(fontSize: 11),
                            ),
                            value: isSelected,
                            onChanged: _isClearing
                                ? null
                                : (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedServerIds.add(server.id);
                                      } else {
                                        _selectedServerIds.remove(server.id);
                                      }
                                    });
                                  },
                          );
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.vDanger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(VRadius.input),
                            border: Border.all(
                              color: context.vDanger.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: context.vDanger,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: context.vDanger,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isClearing ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        if (servers.isNotEmpty)
          FilledButton(
            key: const Key('clear_credentials_confirm_button'),
            style: FilledButton.styleFrom(
              backgroundColor: context.vDanger,
              foregroundColor: Colors.white,
            ),
            onPressed: (_selectedServerIds.isEmpty || _isClearing)
                ? null
                : () => _handleClear(_selectedServerIds.length),
            child: _isClearing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    context.l10n.settingsClearStorageAction(
                      _selectedServerIds.length,
                    ),
                  ),
          ),
      ],
    );
  }
}
