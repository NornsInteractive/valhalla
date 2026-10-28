import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/remote_workspace_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/server_profile.dart';

class RemoteWorkspaceDialog extends ConsumerStatefulWidget {
  const RemoteWorkspaceDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const RemoteWorkspaceDialog(),
    );
  }

  @override
  ConsumerState<RemoteWorkspaceDialog> createState() =>
      _RemoteWorkspaceDialogState();
}

class _RemoteWorkspaceDialogState extends ConsumerState<RemoteWorkspaceDialog> {
  bool _isActionInProgress = false;
  bool _isLoadingMoreDrafts = false;
  bool _isRefreshingDrafts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ref.read(remoteWorkspaceProvider);
      final conn = ref.read(serverConnectionProvider);
      if (state.enabled && conn.isConnected) {
        _handleLoadDrafts(append: false);
      }
    });
  }

  Future<void> _handleLoadDrafts({bool append = false}) async {
    if (!mounted) return;
    final initialServerId = ref.read(activeServerProvider)?.id;
    if (initialServerId == null) return;

    if (append) {
      if (_isLoadingMoreDrafts) return;
      setState(() => _isLoadingMoreDrafts = true);
    } else {
      if (_isRefreshingDrafts) return;
      setState(() => _isRefreshingDrafts = true);
    }

    try {
      await ref
          .read(remoteWorkspaceProvider.notifier)
          .loadDeviceDrafts(append: append);
    } catch (e) {
      if (mounted && context.mounted) {
        final currentServerId = ref.read(activeServerProvider)?.id;
        if (currentServerId == initialServerId) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_resolveWorkspaceError(context, e.toString())),
              backgroundColor: context.vDanger,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          if (append) {
            _isLoadingMoreDrafts = false;
          } else {
            _isRefreshingDrafts = false;
          }
        });
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  String _resolveWorkspaceError(BuildContext context, String? code) {
    final l10n = context.l10n;
    if (code == null || code.isEmpty) return '';
    switch (code) {
      case 'WORKSPACE_SETUP_FAILED':
        return l10n.serverWorkspaceErrorSetupFailed;
      case 'WORKSPACE_PYTHON_REQUIRED':
        return l10n.serverWorkspaceErrorPythonRequired;
      case 'WORKSPACE_PATH_UNSAFE':
        return l10n.serverWorkspaceErrorPathUnsafe;
      case 'WORKSPACE_CONFLICT':
        return l10n.serverWorkspaceErrorConflict;
      case 'WORKSPACE_CONTROL_HELD':
      case 'WORKSPACE_CONTROL_REQUIRED':
        return l10n.serverWorkspaceErrorControlHeld;
      case 'WORKSPACE_RESPONSE_TOO_LARGE':
        return l10n.serverWorkspaceErrorResponseTooLarge;
      case 'WORKSPACE_RUNTIME_UPGRADE_REQUIRED':
        return l10n.serverWorkspaceErrorRuntimeUpgradeRequired;
      case 'WORKSPACE_NOT_ENABLED':
        return l10n.serverWorkspaceErrorNotEnabled;
      case 'WORKSPACE_PENDING_CHANGES':
        return l10n.serverWorkspaceErrorPendingChanges;
      case 'WORKSPACE_OFFLINE':
        return l10n.serverWorkspacePhaseOffline;
      default:
        return l10n.serverWorkspaceErrorGeneric(code);
    }
  }

  Future<void> _handleEnable(BuildContext context) async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);

    try {
      final preview =
          await ref.read(remoteWorkspaceProvider.notifier).migrationPreview();
      if (!mounted || !context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final l10n = ctx.l10n;
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.cloud_sync_outlined, color: ctx.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.serverWorkspaceEnableDialogTitle)),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.serverWorkspaceEnableDialogMessage),
                    const SizedBox(height: 16),
                    Text(
                      l10n.serverWorkspaceMigrationPreviewTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (preview.isEmpty)
                      Text(
                        l10n.serverWorkspaceNoDataToMigrate,
                        style: TextStyle(color: ctx.colorScheme.outline),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ctx.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(VRadius.input),
                        ),
                        child: Column(
                          children: preview.entries.map((e) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    e.key,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  Text(
                                    '${e.value}',
                                    style: monoTextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.serverWorkspaceEnableConfirm),
              ),
            ],
          );
        },
      );

      if (confirmed == true && mounted && context.mounted) {
        await ref.read(remoteWorkspaceProvider.notifier).enable();
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _handleDisable(BuildContext context) async {
    if (_isActionInProgress) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return AlertDialog(
          title: Text(l10n.serverWorkspaceDisableDialogTitle),
          content: Text(l10n.serverWorkspaceDisableDialogMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ctx.vDanger),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.serverWorkspaceDisableConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted && context.mounted) {
      setState(() => _isActionInProgress = true);
      try {
        await ref.read(remoteWorkspaceProvider.notifier).disable();
      } finally {
        if (mounted) setState(() => _isActionInProgress = false);
      }
    }
  }

  Future<void> _handleRestoreDraft(
    BuildContext context,
    WorkspaceDraft draft,
  ) async {
    if (_isActionInProgress) return;
    final initialServer = ref.read(activeServerProvider);
    if (initialServer == null) return;
    final initialServerId = initialServer.id;
    final initialWorkspaceId = ref.read(remoteWorkspaceProvider).workspaceId;

    final isFileDraft = draft.value['type'] == 'file';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return AlertDialog(
          title: Text(isFileDraft
              ? l10n.serverWorkspaceRestoreFileDraftConfirmTitle
              : l10n.serverWorkspaceRestoreDraftConfirmTitle),
          content: Text(isFileDraft
              ? l10n.serverWorkspaceRestoreFileDraftConfirmMessage
              : l10n.serverWorkspaceRestoreDraftConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.serverWorkspaceRestoreDraftConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted && context.mounted) {
      final currentServer = ref.read(activeServerProvider);
      final currentWorkspaceState = ref.read(remoteWorkspaceProvider);
      if (currentServer?.id != initialServerId) {
        // Server switched during confirmation dialog: abort restore
        return;
      }
      if (initialWorkspaceId != null &&
          currentWorkspaceState.workspaceId != initialWorkspaceId) {
        // Workspace changed: abort restore
        return;
      }

      setState(() => _isActionInProgress = true);
      try {
        await ref.read(remoteWorkspaceProvider.notifier).restoreDraft(draft);
      } catch (e) {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_resolveWorkspaceError(context, e.toString())),
              backgroundColor: context.vDanger,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isActionInProgress = false);
      }
    }
  }

  Future<void> _handleClearCache(BuildContext context) async {
    if (_isActionInProgress) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return AlertDialog(
          title: Text(l10n.serverWorkspaceClearCacheConfirmTitle),
          content: Text(l10n.serverWorkspaceClearCacheConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ctx.vDanger),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.serverWorkspaceClearCacheConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted && context.mounted) {
      setState(() => _isActionInProgress = true);
      try {
        await ref.read(remoteWorkspaceProvider.notifier).clearLocalCache();
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.serverWorkspaceCacheCleared),
              backgroundColor: context.vSuccess,
            ),
          );
        }
      } catch (e) {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_resolveWorkspaceError(context, e.toString())),
              backgroundColor: context.vDanger,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isActionInProgress = false);
      }
    }
  }

  Widget _buildPhaseBadge(BuildContext context, WorkspacePhase phase) {
    final l10n = context.l10n;
    Color bg;
    Color fg;
    String label;
    bool showSpinner = false;

    switch (phase) {
      case WorkspacePhase.local:
        bg = context.colorScheme.surfaceContainerHighest;
        fg = context.colorScheme.onSurfaceVariant;
        label = l10n.serverWorkspacePhaseLocal;
      case WorkspacePhase.discovering:
        bg = context.vInfo.withValues(alpha: 0.15);
        fg = context.vInfo;
        label = l10n.serverWorkspacePhaseDiscovering;
        showSpinner = true;
      case WorkspacePhase.available:
        bg = context.colorScheme.primaryContainer;
        fg = context.colorScheme.onPrimaryContainer;
        label = l10n.serverWorkspacePhaseAvailable;
      case WorkspacePhase.syncing:
        bg = context.vWarning.withValues(alpha: 0.15);
        fg = context.vWarning;
        label = l10n.serverWorkspacePhaseSyncing;
        showSpinner = true;
      case WorkspacePhase.ready:
        bg = context.vSuccess.withValues(alpha: 0.15);
        fg = context.vSuccess;
        label = l10n.serverWorkspacePhaseReady;
      case WorkspacePhase.offline:
        bg = context.colorScheme.surfaceContainerHighest;
        fg = context.colorScheme.outline;
        label = l10n.serverWorkspacePhaseOffline;
      case WorkspacePhase.error:
        bg = context.vDanger.withValues(alpha: 0.15);
        fg = context.vDanger;
        label = l10n.serverWorkspacePhaseError;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(VRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(fg),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginCard(
    BuildContext context,
    ServerProfile? server,
    ServerConnectionState connection,
    RemoteWorkspaceState state,
  ) {
    final l10n = context.l10n;
    if (server == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(VRadius.card),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: context.colorScheme.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.serverWorkspaceNoActiveServer,
                style: TextStyle(color: context.colorScheme.outline),
              ),
            ),
          ],
        ),
      );
    }

    final isConnected = connection.isConnected;
    final statusColor = isConnected ? context.vSuccess : context.vWarning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(VRadius.card),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  server.name,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isConnected ? l10n.serverConnected : l10n.serverDisconnected,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${state.user ?? server.username}@${server.host}:${server.port}',
            style: monoTextStyle(
              fontSize: 12,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          if (state.workspaceId != null) ...[
            const SizedBox(height: 4),
            Text(
              'ID: ${state.workspaceId}',
              style: monoTextStyle(
                fontSize: 11,
                color: context.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusSection(
    BuildContext context,
    RemoteWorkspaceState state,
  ) {
    final l10n = context.l10n;
    final lastSyncedText = state.lastSyncedAt != null
        ? l10n.serverWorkspaceLastSynced(_formatDateTime(state.lastSyncedAt!))
        : l10n.serverWorkspaceNeverSynced;

    final pendingText = state.pendingCount > 0
        ? l10n.serverWorkspacePendingChanges(state.pendingCount)
        : l10n.serverWorkspaceNoPendingChanges;

    final errorMessage = (state.error != null && state.error!.isNotEmpty)
        ? _resolveWorkspaceError(context, state.error)
        : (state.phase == WorkspacePhase.error
            ? l10n.serverWorkspacePhaseError
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.serviceStatus,
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildPhaseBadge(context, state.phase),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.history, size: 16, color: context.colorScheme.outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lastSyncedText,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.pending_actions_outlined,
              size: 16,
              color: state.pendingCount > 0
                  ? context.vWarning
                  : context.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pendingText,
                style: TextStyle(
                  fontSize: 13,
                  color: state.pendingCount > 0 ? context.vWarning : null,
                ),
              ),
            ),
          ],
        ),
        if (state.migrationPending) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(VRadius.input),
              border: Border.all(
                color: context.colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sync_outlined,
                  size: 16,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.serverWorkspaceMigrationPendingHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.vDanger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(VRadius.input),
              border: Border.all(
                color: context.vDanger.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 18, color: context.vDanger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.vDanger,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildControlsSection(
    BuildContext context,
    ServerProfile? server,
    ServerConnectionState connection,
    RemoteWorkspaceState state,
  ) {
    final l10n = context.l10n;
    final isConnected = connection.isConnected;
    final isBusy = state.isBusy || _isActionInProgress;

    if (!state.enabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.serverWorkspaceEnableDialogMessage,
            style: TextStyle(
              fontSize: 13,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(l10n.serverWorkspaceEnable),
            onPressed: isConnected && !isBusy && server != null
                ? () => _handleEnable(context)
                : null,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.sync),
                label: Text(l10n.serverWorkspaceSyncNow),
                onPressed: isConnected && !isBusy
                    ? () => ref.read(remoteWorkspaceProvider.notifier).syncNow()
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.sync_disabled),
              label: Text(l10n.serverWorkspaceDisable),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.vDanger,
              ),
              onPressed: !isBusy ? () => _handleDisable(context) : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
          title: Text(
            l10n.serverWorkspacePreferenceSource,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            l10n.serverWorkspacePreferenceSourceDesc,
            style: TextStyle(
              fontSize: 12,
              color: context.colorScheme.outline,
            ),
          ),
          value: state.isPreferenceSource,
          contentPadding: EdgeInsets.zero,
          onChanged: isConnected && !isBusy && server != null
              ? (_) => ref
                  .read(remoteWorkspaceProvider.notifier)
                  .useAsPreferenceSource()
              : null,
        ),
      ],
    );
  }

  Widget _buildConflictsSection(
    BuildContext context,
    RemoteWorkspaceState state,
  ) {
    if (state.conflicts.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 18, color: context.vWarning),
            const SizedBox(width: 6),
            Text(
              l10n.serverWorkspaceConflictsTitle(state.conflicts.length),
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.vWarning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...state.conflicts.map((conflict) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(VRadius.input),
              border: Border.all(
                color: context.vWarning.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${conflict.kind}: ${conflict.id}',
                  style: monoTextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => ref
                          .read(remoteWorkspaceProvider.notifier)
                          .resolveConflict(conflict, keepLocal: true),
                      child: Text(l10n.serverWorkspaceConflictKeepLocal),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => ref
                          .read(remoteWorkspaceProvider.notifier)
                          .resolveConflict(conflict, keepLocal: false),
                      child: Text(l10n.serverWorkspaceConflictKeepServer),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDraftCard(
    BuildContext context,
    WorkspaceDraft draft,
    bool isBusy,
  ) {
    final l10n = context.l10n;
    final isFileDraft = draft.value['type'] == 'file';
    final draftTypeLabel = isFileDraft
        ? l10n.serverWorkspaceDraftTypeFile
        : l10n.serverWorkspaceDraftTypeChat;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(VRadius.input),
      ),
      child: Row(
        children: [
          Icon(
            isFileDraft
                ? Icons.description_outlined
                : Icons.chat_bubble_outline,
            size: 16,
            color: isFileDraft
                ? context.colorScheme.tertiary
                : context.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: (isFileDraft
                                ? context.colorScheme.tertiaryContainer
                                : context.colorScheme.primaryContainer)
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        draftTypeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isFileDraft
                              ? context.colorScheme.onTertiaryContainer
                              : context.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        draft.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (draft.deviceId.isNotEmpty)
                  Text(
                    draft.deviceId,
                    style: monoTextStyle(
                      fontSize: 11,
                      color: context.colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.restore, size: 16),
            label: Text(l10n.serverWorkspaceRestoreDraft),
            onPressed: !isBusy
                ? () => _handleRestoreDraft(context, draft)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsSection(
    BuildContext context,
    ServerConnectionState connection,
    RemoteWorkspaceState state,
  ) {
    final l10n = context.l10n;
    final isConnected = connection.isConnected;
    final isBusy = state.isBusy || _isActionInProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.serverWorkspaceDeviceDraftsTitle,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: _isRefreshingDrafts
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
              tooltip: l10n.sftpRefresh,
              onPressed: isConnected &&
                      !isBusy &&
                      state.enabled &&
                      !_isRefreshingDrafts &&
                      !_isLoadingMoreDrafts
                  ? () => _handleLoadDrafts(append: false)
                  : null,
            ),
          ],
        ),
        if (state.devicesDrafts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.serverWorkspaceNoDeviceDrafts,
              style: TextStyle(
                fontSize: 13,
                color: context.colorScheme.outline,
              ),
            ),
          )
        else ...[
          SizedBox(
            height: (state.devicesDrafts.length * 64.0).clamp(64.0, 280.0),
            child: ListView.builder(
              key: const Key('workspace_device_drafts_list'),
              padding: EdgeInsets.zero,
              primary: false,
              itemCount: state.devicesDrafts.length,
              itemBuilder: (context, index) {
                final draft = state.devicesDrafts[index];
                return _buildDraftCard(context, draft, isBusy);
              },
            ),
          ),
        ],
        if (state.draftsHaveMore) ...[
          const SizedBox(height: 8),
          Center(
            child: _isLoadingMoreDrafts
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.serverWorkspaceLoadingDrafts,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : TextButton.icon(
                    key: const Key('workspace_load_more_drafts_button'),
                    icon: const Icon(Icons.expand_more, size: 16),
                    label: Text(l10n.serverWorkspaceLoadMoreDrafts),
                    onPressed: isConnected &&
                            !isBusy &&
                            state.enabled &&
                            !_isLoadingMoreDrafts &&
                            !_isRefreshingDrafts
                        ? () => _handleLoadDrafts(append: true)
                        : null,
                  ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(activeServerProvider);
    final connection = ref.watch(serverConnectionProvider);
    final state = ref.watch(remoteWorkspaceProvider);
    final l10n = context.l10n;

    ref.listen<ServerProfile?>(activeServerProvider, (previous, next) {
      if (next?.id != previous?.id && next != null) {
        final currentWsState = ref.read(remoteWorkspaceProvider);
        final conn = ref.read(serverConnectionProvider);
        if (currentWsState.enabled && conn.isConnected) {
          _handleLoadDrafts(append: false);
        }
      }
    });

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VRadius.dialog),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 540,
          maxHeight: 680,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(VRadius.dialog),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_sync_outlined,
                      size: 24,
                      color: context.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.serverWorkspaceTitle,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildOriginCard(context, server, connection, state),
                      const SizedBox(height: 16),
                      _buildStatusSection(context, state),
                      const SizedBox(height: 16),
                      _buildControlsSection(context, server, connection, state),
                      _buildConflictsSection(context, state),
                      if (state.enabled)
                        _buildDraftsSection(context, connection, state),
                      const Divider(height: 24),
                      Center(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cleaning_services_outlined,
                              size: 16),
                          label: Text(l10n.serverWorkspaceClearCache),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.colorScheme.outline,
                          ),
                          onPressed: !state.isBusy && !_isActionInProgress
                              ? () => _handleClearCache(context)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
