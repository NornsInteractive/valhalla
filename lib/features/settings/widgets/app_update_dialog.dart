import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/app_update_provider.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String localizeUpdateError(BuildContext context, String rawError) {
  final l10n = context.l10n;
  final lower = rawError.toLowerCase();
  if (rawError.contains('UPDATE_SIGNATURE_MISMATCH')) {
    return l10n.updateErrorSignatureMismatch;
  }
  if (rawError.contains('UPDATE_INSTALL_PERMISSION_REQUIRED')) {
    return l10n.updateErrorPermissionRequired;
  }
  if (rawError.contains('UPDATE_RATE_LIMITED') ||
      rawError.contains('403') ||
      rawError.contains('429')) {
    return l10n.updateErrorRateLimited;
  }
  if (rawError.contains('UPDATE_DOWNLOAD_INTEGRITY_FAILED') ||
      rawError.contains('UPDATE_ASSET_DIGEST_MISMATCH')) {
    return l10n.updateErrorIntegrity;
  }
  if (rawError.contains('UPDATE_MANIFEST_INVALID') ||
      rawError.contains('UPDATE_MANIFEST_FAILED') ||
      rawError.contains('UPDATE_RELEASE_INVALID')) {
    return l10n.updateErrorManifest;
  }
  if (rawError.contains('UPDATE_STORE_INSTALL')) {
    return l10n.updateErrorStoreInstall;
  }
  if (rawError.contains('UPDATE_PERMISSION_DENIED') ||
      lower.contains('permission denied')) {
    return l10n.updateErrorPermission;
  }
  if (rawError.contains('UPDATE_PACKAGE_PATH_INVALID') ||
      rawError.contains('UPDATE_PACKAGE_IDENTITY_INVALID')) {
    return l10n.updateErrorPackageInvalid;
  }
  if (rawError.contains('UPDATE_OPEN_FAILED') ||
      rawError.contains('UPDATE_PLATFORM_FAILED')) {
    return l10n.updateErrorPlatform;
  }
  if (rawError.contains('UPDATE_NETWORK_FAILED') ||
      rawError.contains('UPDATE_CHECK_FAILED') ||
      rawError.contains('UPDATE_DOWNLOAD_FAILED') ||
      lower.contains('socketexception') ||
      lower.contains('httpexception') ||
      lower.contains('handshakeexception') ||
      lower.contains('timeoutexception') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable') ||
      lower.contains('failed host lookup')) {
    return l10n.updateErrorNetwork;
  }
  return l10n.updateErrorGeneric;
}

class AppUpdateDialog extends ConsumerStatefulWidget {
  const AppUpdateDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const AppUpdateDialog(),
    );
  }

  @override
  ConsumerState<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends ConsumerState<AppUpdateDialog> {
  String? _actionError;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(() {
              _packageInfo = info;
            });
          }
        })
        .catchError((_) {
          // Keep null fallback, do not leak unhandled async error.
        });
  }

  void _clearActionError() {
    if (_actionError != null) {
      setState(() {
        _actionError = null;
      });
    }
  }

  Future<void> _handleOpenDownloaded() async {
    setState(() {
      _actionError = null;
    });
    try {
      await ref.read(appUpdateProvider.notifier).openDownloaded();
    } catch (error) {
      if (mounted) {
        setState(() {
          _actionError = error.toString();
        });
      }
    }
  }

  Future<void> _copyText(String text, String successMessage) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(appUpdateProvider);
    final notifier = ref.read(appUpdateProvider.notifier);
    final release = state.release;
    final currentVersion = _packageInfo != null
        ? 'v${_packageInfo!.version} (${_packageInfo!.buildNumber})'
        : context.l10n.privacyVersionUnknown;

    final effectiveError = _actionError ?? state.error;

    return Dialog(
      key: const Key('app_update_dialog'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VRadius.card),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.system_update_outlined,
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.updateDialogTitle,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          context.l10n.updateCurrentVersion(currentVersion),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  child: release == null
                      ? _buildNoReleaseContent(
                          context,
                          state,
                          notifier,
                          effectiveError,
                        )
                      : _buildReleaseContent(
                          context,
                          theme,
                          state,
                          notifier,
                          effectiveError,
                        ),
                ),
              ),

              const SizedBox(height: 16),
              // Bottom Action Buttons
              _buildBottomActions(context, state, notifier),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoReleaseContent(
    BuildContext context,
    AppUpdateState state,
    AppUpdateNotifier notifier,
    String? effectiveError,
  ) {
    final theme = Theme.of(context);
    if (state.checking) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                context.l10n.updateChecking,
                style: context.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (effectiveError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                localizeUpdateError(context, effectiveError),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.copy_outlined, size: 14),
                label: Text(
                  context.l10n.updateCopyErrorDetails,
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: () =>
                    _copyText(effectiveError, context.l10n.updateErrorCopied),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(context.l10n.updateRetry),
                onPressed: () {
                  _clearActionError();
                  notifier.check();
                },
              ),
            ],
          ),
        ),
      );
    }

    final hasChecked = state.checkedAt != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasChecked ? Icons.check_circle_outline : Icons.help_outline,
              size: 48,
              color: hasChecked ? context.vSuccess : theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              hasChecked
                  ? context.l10n.updateUpToDate
                  : context.l10n.updateNeverChecked,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(context.l10n.updateCheckNow),
              onPressed: () {
                _clearActionError();
                notifier.check();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReleaseContent(
    BuildContext context,
    ThemeData theme,
    AppUpdateState state,
    AppUpdateNotifier notifier,
    String? effectiveError,
  ) {
    final release = state.release!;
    final artifact = state.artifact;
    final boundedNotes = release.notes.length > 16384
        ? '${release.notes.substring(0, 16384)}...'
        : release.notes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Target Version & Commit info chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(VRadius.input),
              ),
              child: Text(
                context.l10n.updateTargetVersion(release.version) +
                    (release.buildNumber != null
                        ? ' (${context.l10n.updateBuildNumber(release.buildNumber.toString())})'
                        : ''),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            if (release.sourceCommit != null &&
                release.sourceCommit!.isNotEmpty)
              ActionChip(
                avatar: const Icon(Icons.commit, size: 16),
                label: Text(
                  release.sourceCommit!.length > 7
                      ? release.sourceCommit!.substring(0, 7)
                      : release.sourceCommit!,
                  style: monoTextStyle(fontSize: 11),
                ),
                tooltip: context.l10n.updateCommit(release.sourceCommit!),
                onPressed: () => _copyText(
                  release.sourceCommit!,
                  context.l10n.updateCommitCopied,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Artifact Info Card or Missing Artifact banner
        if (artifact != null) ...[
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(VRadius.input),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          artifact.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        context.l10n.updateArtifactSize(
                          formatBytes(artifact.size),
                        ),
                        style: context.textTheme.bodySmall,
                      ),
                      Text(
                        '${artifact.platform} (${artifact.architecture})',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'SHA-256: ${artifact.sha256.substring(0, 12)}...${artifact.sha256.substring(artifact.sha256.length - 8)}',
                          style: monoTextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_outlined, size: 14),
                        visualDensity: VisualDensity.compact,
                        tooltip: context.l10n.updateCopyHash,
                        onPressed: () => _copyText(
                          artifact.sha256,
                          context.l10n.updateHashCopied,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(VRadius.input),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.updateNoArtifactForPlatform,
                    style: context.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Release Notes
        Text(
          context.l10n.updateReleaseNotes,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
            borderRadius: BorderRadius.circular(VRadius.input),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(12),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: boundedNotes.trim().isNotEmpty
                  ? SelectableText(
                      boundedNotes,
                      style: context.textTheme.bodySmall?.copyWith(height: 1.4),
                    )
                  : Text(
                      context.l10n.updateNoReleaseNotes,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Download Progress / Status Display
        if (state.downloadStatus == AppUpdateDownloadStatus.downloading &&
            artifact != null) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: artifact.size > 0
                    ? (state.downloadedBytes / artifact.size).clamp(0.0, 1.0)
                    : null,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${formatBytes(state.downloadedBytes)} / ${formatBytes(artifact.size)}',
                    style: monoTextStyle(fontSize: 11),
                  ),
                  Text(
                    artifact.size > 0
                        ? '${((state.downloadedBytes / artifact.size) * 100).toStringAsFixed(1)}%'
                        : '',
                    style: monoTextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
        ] else if (state.downloadStatus == AppUpdateDownloadStatus.paused &&
            artifact != null) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: artifact.size > 0
                    ? (state.downloadedBytes / artifact.size).clamp(0.0, 1.0)
                    : null,
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.updateDownloadPaused,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${formatBytes(state.downloadedBytes)} / ${formatBytes(artifact.size)}',
                    style: monoTextStyle(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
        ] else if (state.downloadStatus ==
            AppUpdateDownloadStatus.completed) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.vSuccess.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(VRadius.input),
              border: Border.all(
                color: context.vSuccess.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: context.vSuccess,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.updateDownloadCompleted,
                        style: TextStyle(
                          color: context.vSuccess,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!Platform.isAndroid) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.updateDesktopInstructions,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Error message card (if error occurred)
        if (effectiveError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(VRadius.input),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        localizeUpdateError(context, effectiveError),
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.copy_outlined, size: 14),
                      label: Text(
                        context.l10n.updateCopyErrorDetails,
                        style: const TextStyle(fontSize: 11),
                      ),
                      onPressed: () => _copyText(
                        effectiveError,
                        context.l10n.updateErrorCopied,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    AppUpdateState state,
    AppUpdateNotifier notifier,
  ) {
    final release = state.release;
    final artifact = state.artifact;

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cmdClose),
        ),
        if (release != null) ...[
          if (state.downloadStatus == AppUpdateDownloadStatus.downloading) ...[
            FilledButton.tonalIcon(
              key: const Key('app_update_pause_button'),
              icon: const Icon(Icons.pause, size: 18),
              label: Text(context.l10n.updatePause),
              onPressed: () {
                _clearActionError();
                notifier.pauseDownload();
              },
            ),
          ] else if (state.downloadStatus ==
              AppUpdateDownloadStatus.paused) ...[
            FilledButton.icon(
              key: const Key('app_update_resume_button'),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(context.l10n.updateResume),
              onPressed: () {
                _clearActionError();
                notifier.download();
              },
            ),
          ] else if (state.downloadStatus ==
              AppUpdateDownloadStatus.failed) ...[
            FilledButton.icon(
              key: const Key('app_update_retry_button'),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.l10n.updateRetry),
              onPressed: () {
                _clearActionError();
                notifier.download();
              },
            ),
          ] else if (state.downloadStatus ==
              AppUpdateDownloadStatus.completed) ...[
            if (Platform.isAndroid) ...[
              FilledButton.icon(
                key: const Key('app_update_install_button'),
                icon: const Icon(Icons.system_update, size: 18),
                label: Text(
                  _actionError != null &&
                          _actionError!.contains(
                            'UPDATE_INSTALL_PERMISSION_REQUIRED',
                          )
                      ? context.l10n.updateRetryInstall
                      : context.l10n.updateInstall,
                ),
                onPressed: _handleOpenDownloaded,
              ),
            ] else if (Platform.isWindows) ...[
              FilledButton.icon(
                key: const Key('app_update_reveal_button'),
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(context.l10n.updateRevealInFolder),
                onPressed: _handleOpenDownloaded,
              ),
            ] else ...[
              FilledButton.icon(
                key: const Key('app_update_open_folder_button'),
                icon: const Icon(Icons.folder_open, size: 18),
                label: Text(context.l10n.updateOpenFolder),
                onPressed: _handleOpenDownloaded,
              ),
            ],
          ] else if (state.downloadStatus == AppUpdateDownloadStatus.idle) ...[
            if (artifact != null) ...[
              FilledButton.icon(
                key: const Key('app_update_download_button'),
                icon: const Icon(Icons.download, size: 18),
                label: Text(context.l10n.updateDownload),
                onPressed: () {
                  _clearActionError();
                  notifier.download();
                },
              ),
            ] else ...[
              FilledButton.icon(
                key: const Key('app_update_open_release_button'),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(context.l10n.updateOpenReleasePage),
                onPressed: notifier.openRelease,
              ),
            ],
          ],
        ],
      ],
    );
  }
}
