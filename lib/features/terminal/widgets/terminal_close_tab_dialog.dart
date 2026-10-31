import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/providers/terminal_provider.dart';
import '../../../infrastructure/terminal/terminal_session_bridge.dart';

enum TerminalCloseChoice {
  cancel,
  preserve,
  destroy,
}

bool _isCloseTabDialogShowing = false;

/// 弹出终端标签页关闭确认流程。
///
/// 适用于所有关闭入口（标签页选项栏、历史抽屉打开项菜单、抽屉打开标签项菜单），
/// 保证统一的三项选择（取消 / 保留远程会话并关闭 [默认] / 销毁远程会话并关闭 [带警告]），
/// 并在前后严格核验目标服务器身份，防止并发重复弹窗。
Future<void> confirmAndCloseTerminalTab(
  BuildContext context,
  WidgetRef ref,
  TerminalTab tab, {
  String? expectedTargetKey,
}) async {
  if (_isCloseTabDialogShowing) return;

  final initialServer = ref.read(activeServerProvider);
  final targetKey = expectedTargetKey ??
      (initialServer == null
          ? null
          : TerminalHistoryRecord.targetFor(initialServer));
  if (targetKey == null) return;

  final tabs = ref.read(terminalProvider).tabs;
  if (!tabs.any((t) => t.id == tab.id)) return;

  _isCloseTabDialogShowing = true;
  try {
    final isTmux = tab.bridge.mode == TerminalSessionMode.tmux;
    final historyRecord = ref
        .read(terminalProvider)
        .history
        .where((r) => r.id == tab.id)
        .firstOrNull;
    final attachedClients = historyRecord?.attachedClients ?? 1;

    final choice = await showDialog<TerminalCloseChoice>(
      context: context,
      builder: (dialogCtx) {
        if (!isTmux) {
          return AlertDialog(
            title: Text(dialogCtx.l10n.terminalCloseTabConfirmTitle),
            content: Text(dialogCtx.l10n.terminalClosePlainConfirmMessage),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogCtx, TerminalCloseChoice.cancel),
                child: Text(dialogCtx.l10n.cancel),
              ),
              FilledButton(
                key: const Key('terminal_confirm_close_tab_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: dialogCtx.colorScheme.error,
                ),
                onPressed: () =>
                    Navigator.pop(dialogCtx, TerminalCloseChoice.destroy),
                child: Text(dialogCtx.l10n.terminalCloseActionTerminate),
              ),
            ],
          );
        }

        return AlertDialog(
          title: Text(dialogCtx.l10n.terminalCloseTabConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dialogCtx.l10n.terminalCloseTmuxConfirmMessage),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: dialogCtx.colorScheme.errorContainer.withValues(
                    alpha: 0.25,
                  ),
                  borderRadius: BorderRadius.circular(VRadius.card),
                  border: Border.all(
                    color: dialogCtx.colorScheme.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: dialogCtx.vDanger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        attachedClients > 1
                            ? dialogCtx.l10n.terminalTerminateClientsWarning(
                                attachedClients,
                              )
                            : '${dialogCtx.l10n.terminalHistoryTerminateConfirmMessage} ${attachedClients > 0 ? dialogCtx.l10n.terminalTerminateClientsWarning(attachedClients) : ""}'
                                  .trim(),
                        style: TextStyle(
                          fontSize: 12,
                          color: dialogCtx.colorScheme.onErrorContainer,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogCtx, TerminalCloseChoice.cancel),
              child: Text(dialogCtx.l10n.cancel),
            ),
            OutlinedButton(
              key: const Key('terminal_close_destroy_tab_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: dialogCtx.colorScheme.error,
                side: BorderSide(
                  color: dialogCtx.colorScheme.error.withValues(alpha: 0.5),
                ),
              ),
              onPressed: () =>
                  Navigator.pop(dialogCtx, TerminalCloseChoice.destroy),
              child: Text(dialogCtx.l10n.terminalCloseActionTerminate),
            ),
            FilledButton(
              key: const Key('terminal_confirm_close_tab_button'),
              style: FilledButton.styleFrom(
                backgroundColor: dialogCtx.colorScheme.primary,
              ),
              onPressed: () =>
                  Navigator.pop(dialogCtx, TerminalCloseChoice.preserve),
              child: Text(dialogCtx.l10n.terminalCloseActionDetach),
            ),
          ],
        );
      },
    );

    if (choice == null || choice == TerminalCloseChoice.cancel) {
      return;
    }

    if (!context.mounted) return;
    final freshServer = ref.read(activeServerProvider);
    final freshTargetKey = freshServer == null
        ? null
        : TerminalHistoryRecord.targetFor(freshServer);
    if (freshTargetKey != targetKey) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.stateError)),
        );
      }
      return;
    }

    if (!ref.read(terminalProvider).tabs.any((t) => t.id == tab.id)) {
      return;
    }

    final shouldDestroy = choice == TerminalCloseChoice.destroy;
    try {
      await ref.read(terminalProvider.notifier).closeTabById(
        tab.id,
        expectedTargetKey: targetKey,
        destroyRemote: shouldDestroy,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  } finally {
    _isCloseTabDialogShowing = false;
  }
}
