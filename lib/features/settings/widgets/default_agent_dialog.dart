import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/security_settings_provider.dart';
import '../../../core/providers/storage_providers.dart';
import '../../../data/models/server_profile.dart';

class DefaultAgentDialog extends ConsumerStatefulWidget {
  final ServerProfile server;
  final bool isCli;

  const DefaultAgentDialog({
    super.key,
    required this.server,
    required this.isCli,
  });

  static Future<void> show(
    BuildContext context, {
    required ServerProfile server,
    required bool isCli,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => DefaultAgentDialog(server: server, isCli: isCli),
    );
  }

  @override
  ConsumerState<DefaultAgentDialog> createState() => _DefaultAgentDialogState();
}

class _DefaultAgentDialogState extends ConsumerState<DefaultAgentDialog> {
  bool _isSaving = false;
  String? _errorMessage;

  Future<void> _selectAgent(String? agentId) async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(securitySettingsProvider)
          .setDefaultAgent(
            agentId,
            cli: widget.isCli,
            expectedServerId: widget.server.id,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = context.l10n.settingsDefaultAgentSaveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultMap = ref.watch(defaultAgentSettingsProvider);
    final currentDefaultId = widget.isCli
        ? defaultMap['cli']
        : defaultMap['acp'];
    final allAgents = ref
        .watch(agentRepositoryProvider)
        .getAll(widget.server.id);
    final eligibleAgents = widget.isCli
        ? allAgents
        : allAgents
              .where((a) => a.acpCommand?.trim().isNotEmpty ?? false)
              .toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.isCli ? Icons.forum : Icons.psychology,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.isCli
                  ? context.l10n.settingsDefaultCliAgent
                  : context.l10n.settingsDefaultAcpAgent,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: RadioGroup<String?>(
                  groupValue: currentDefaultId,
                  onChanged: (val) {
                    if (!_isSaving) {
                      _selectAgent(val);
                    }
                  },
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      RadioListTile<String?>(
                        enabled: !_isSaving,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          context.l10n.settingsDefaultAgentAutomatic,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          widget.server.name,
                          style: monoTextStyle(
                            fontSize: 11,
                            color: context.colorScheme.outline,
                          ),
                        ),
                        value: null,
                      ),
                      const Divider(height: 1),
                      if (eligibleAgents.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              context.l10n.settingsDefaultAgentNoAgents,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colorScheme.outline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ...eligibleAgents.map((agent) {
                          final isSelected = agent.id == currentDefaultId;
                          return RadioListTile<String?>(
                            key: Key('default_agent_${agent.id}'),
                            enabled: !_isSaving,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              agent.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              agent.description.isNotEmpty
                                  ? agent.description
                                  : (widget.isCli
                                        ? agent.cliCommand
                                        : (agent.acpCommand ?? '')),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colorScheme.outline,
                              ),
                            ),
                            value: agent.id,
                          );
                        }),
                    ],
                  ),
                ),
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
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
      ],
    );
  }
}
