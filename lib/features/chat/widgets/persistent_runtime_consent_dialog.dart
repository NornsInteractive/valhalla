import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/ai_chat_provider.dart';
import '../../../core/providers/server_provider.dart';

class PersistentRuntimeConsentDialog extends ConsumerStatefulWidget {
  const PersistentRuntimeConsentDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PersistentRuntimeConsentDialog(),
    );
  }

  @override
  ConsumerState<PersistentRuntimeConsentDialog> createState() =>
      _PersistentRuntimeConsentDialogState();
}

class _PersistentRuntimeConsentDialogState
    extends ConsumerState<PersistentRuntimeConsentDialog> {
  late final Object? _targetConnectionKey;
  late final String? _targetAgentProfileId;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _targetConnectionKey = ref.read(activeServerProvider)?.connectionKey;
    _targetAgentProfileId = ref.read(aiChatProvider).activeAgentProfile?.id;
  }

  void _closeDialog() {
    if (_closing) return;
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  bool get _isTargetCurrent {
    final currentKey = ref.read(activeServerProvider)?.connectionKey;
    final currentAgent = ref.read(aiChatProvider).activeAgentProfile?.id;
    return currentKey == _targetConnectionKey &&
        currentAgent == _targetAgentProfileId;
  }

  String _resolveSetupError(BuildContext context, String rawError) {
    if (rawError.contains('WORKSPACE_RUNTIME_UPGRADE_REQUIRED')) {
      return context.l10n.serverWorkspaceErrorRuntimeUpgradeRequired;
    }
    if (rawError.contains('ACP_RUNTIME_PYTHON_REQUIRED')) {
      return context.l10n.persistentRuntimeFeaturePythonDesc;
    }
    if (rawError.contains('ACP_RUNTIME_SETUP_FAILED') ||
        rawError.contains('ACP_RUNTIME_PATH_UNSAFE') ||
        rawError.contains('ACP_RUNTIME_ATTACH_FAILED') ||
        rawError.contains('ACP_RUNTIME_FAILED')) {
      return context.l10n.agentNotReadyError;
    }
    if (rawError.contains('SSH_DISCONNECTED') ||
        rawError.contains('DISCONNECTED')) {
      return context.l10n.sshDisconnectedError;
    }
    if (rawError.contains('AUTH_REQUIRED')) {
      return context.l10n.agentAuthRequiredError;
    }
    return rawError;
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final l10n = context.l10n;
    final isSettingUp = chatState.isSettingUpPersistentRuntime;
    final setupError = chatState.persistentRuntimeSetupError;

    ref.listen<bool>(
      aiChatProvider.select((s) => s.persistentRuntimeSetupRequired),
      (previous, next) {
        if (!next) {
          _closeDialog();
        }
      },
    );

    ref.listen<Object?>(activeServerProvider.select((s) => s?.connectionKey), (
      previous,
      next,
    ) {
      if (next != _targetConnectionKey) {
        _closeDialog();
      }
    });

    ref.listen<String?>(
      aiChatProvider.select((s) => s.activeAgentProfile?.id),
      (previous, next) {
        if (next != _targetAgentProfileId) {
          _closeDialog();
        }
      },
    );

    return PopScope(
      canPop: !isSettingUp,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _closing = true;
          if (_isTargetCurrent) {
            ref.read(aiChatProvider.notifier).dismissPersistentRuntimeSetup();
          }
        }
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VRadius.dialog),
        ),
        title: Row(
          children: [
            Icon(
              Icons.dns_outlined,
              color: context.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: VSpace.sm),
            Expanded(
              child: Text(
                l10n.persistentRuntimeDialogTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.persistentRuntimeDialogDescription,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: VSpace.lg),
                _FeatureRow(
                  icon: Icons.code,
                  title: l10n.persistentRuntimeFeaturePythonTitle,
                  description: l10n.persistentRuntimeFeaturePythonDesc,
                ),
                const SizedBox(height: VSpace.md),
                _FeatureRow(
                  icon: Icons.security_outlined,
                  title: l10n.persistentRuntimeFeatureSshTitle,
                  description: l10n.persistentRuntimeFeatureSshDesc,
                ),
                const SizedBox(height: VSpace.md),
                _FeatureRow(
                  icon: Icons.history_toggle_off,
                  title: l10n.persistentRuntimeFeatureRetentionTitle,
                  description: l10n.persistentRuntimeFeatureRetentionDesc,
                ),
                const SizedBox(height: VSpace.md),
                _FeatureRow(
                  icon: Icons.cloud_done_outlined,
                  title: l10n.persistentRuntimeFeatureDetachedTitle,
                  description: l10n.persistentRuntimeFeatureDetachedDesc,
                ),
                const SizedBox(height: VSpace.md),
                _FeatureRow(
                  icon: Icons.cloud_sync_outlined,
                  title: l10n.persistentRuntimeFeatureWorkspaceTitle,
                  description: l10n.persistentRuntimeFeatureWorkspaceDesc,
                ),
                if (setupError != null && setupError.isNotEmpty) ...[
                  const SizedBox(height: VSpace.lg),
                  Container(
                    padding: const EdgeInsets.all(VSpace.sm + 2),
                    decoration: BoxDecoration(
                      color: context.vDanger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(VRadius.input),
                      border: Border.all(
                        color: context.vDanger.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: context.vDanger,
                        ),
                        const SizedBox(width: VSpace.sm),
                        Expanded(
                          child: Text(
                            _resolveSetupError(context, setupError),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.vDanger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isSettingUp) ...[
                  const SizedBox(height: VSpace.lg),
                  const LinearProgressIndicator(),
                  const SizedBox(height: VSpace.xs),
                  Center(
                    child: Text(
                      l10n.persistentRuntimeSettingUp,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('persistentRuntimeCancelButton'),
            onPressed: isSettingUp
                ? null
                : () {
                    if (_isTargetCurrent) {
                      ref
                          .read(aiChatProvider.notifier)
                          .dismissPersistentRuntimeSetup();
                    }
                    _closeDialog();
                  },
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('persistentRuntimeEnableButton'),
            onPressed: isSettingUp
                ? null
                : () async {
                    if (!_isTargetCurrent) {
                      _closeDialog();
                      return;
                    }
                    await ref
                        .read(aiChatProvider.notifier)
                        .approvePersistentRuntime();
                  },
            child: Text(l10n.persistentRuntimeEnableAction),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: context.colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(VRadius.input),
          ),
          child: Icon(icon, size: 18, color: context.colorScheme.primary),
        ),
        const SizedBox(width: VSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
