import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/sftp_provider.dart';
import '../../../data/models/server_profile.dart';
import '../../../infrastructure/sftp/sftp_client_service.dart';
import '../../../infrastructure/sftp/remote_file_actions.dart';

class RemoteFileBatchResultsDialog extends ConsumerStatefulWidget {
  final List<RemoteFileResult> results;
  final RemoteFileAction? action;
  final List<SftpFileItem>? originalItems;
  final ServerProfile? expectedServer;
  final String? targetDirectory;
  final ValueChanged<List<RemoteFileResult>>? onResultsUpdated;

  const RemoteFileBatchResultsDialog({
    super.key,
    required this.results,
    this.action,
    this.originalItems,
    this.expectedServer,
    this.targetDirectory,
    this.onResultsUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required List<RemoteFileResult> results,
    RemoteFileAction? action,
    List<SftpFileItem>? originalItems,
    ServerProfile? expectedServer,
    String? targetDirectory,
    ValueChanged<List<RemoteFileResult>>? onResultsUpdated,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => RemoteFileBatchResultsDialog(
        results: results,
        action: action,
        originalItems: originalItems,
        expectedServer: expectedServer,
        targetDirectory: targetDirectory,
        onResultsUpdated: onResultsUpdated,
      ),
    );
  }

  @override
  ConsumerState<RemoteFileBatchResultsDialog> createState() =>
      _RemoteFileBatchResultsDialogState();
}

class _RemoteFileBatchResultsDialogState
    extends ConsumerState<RemoteFileBatchResultsDialog> {
  late List<RemoteFileResult> _results;
  bool _isRetrying = false;
  int? _retryCompleted;
  int? _retryTotal;

  @override
  void initState() {
    super.initState();
    _results = List.of(widget.results);
  }

  Future<void> _handleRetryFailed() async {
    if (_isRetrying ||
        widget.action == null ||
        widget.originalItems == null ||
        widget.expectedServer == null) {
      return;
    }
    final failedSet = _results
        .where((r) => r.outcome == RemoteFileOutcome.failed)
        .map((r) => r.path)
        .toSet();
    if (failedSet.isEmpty) return;

    setState(() {
      _isRetrying = true;
      _retryCompleted = 0;
      _retryTotal = failedSet.length;
    });

    try {
      final retriedResults = await ref
          .read(sftpProvider.notifier)
          .retryFailedBatch(
            widget.action!,
            widget.originalItems!,
            _results,
            expectedServer: widget.expectedServer!,
            targetDirectory: widget.targetDirectory,
            onProgress: (c, t) {
              if (mounted) {
                setState(() {
                  _retryCompleted = c;
                  _retryTotal = t;
                });
              }
            },
          );

      if (!mounted) return;

      // Merge retry results by path, preserving previous successes
      final map = {for (final r in _results) r.path: r};
      for (final r in retriedResults) {
        map[r.path] = r;
      }
      final merged = map.values.toList();
      setState(() {
        _results = merged;
      });
      widget.onResultsUpdated?.call(merged);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: context.vDanger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
          _retryCompleted = null;
          _retryTotal = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final failureCount = _results
        .where(
          (r) =>
              r.outcome == RemoteFileOutcome.failed ||
              r.outcome == RemoteFileOutcome.skipped,
        )
        .length;
    final retryableCount = _results
        .where((r) => r.outcome == RemoteFileOutcome.failed)
        .length;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            failureCount > 0
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            color: failureCount > 0 ? context.vWarning : context.vSuccess,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.sftpBatchResultsTitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _results.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final result = _results[index];
              final Color outcomeColor;
              final IconData outcomeIcon;
              final String outcomeLabel;

              switch (result.outcome) {
                case RemoteFileOutcome.completed:
                  outcomeColor = context.vSuccess;
                  outcomeIcon = Icons.check_circle_rounded;
                  outcomeLabel = context.l10n.transferStatusCompleted;
                  break;
                case RemoteFileOutcome.queued:
                  outcomeColor = context.vInfo;
                  outcomeIcon = Icons.schedule_rounded;
                  outcomeLabel = context.l10n.transferStatusQueued;
                  break;
                case RemoteFileOutcome.skipped:
                  outcomeColor = context.vWarning;
                  outcomeIcon = Icons.remove_circle_outline_rounded;
                  outcomeLabel = context.l10n.sftpBatchOutcomeSkipped;
                  break;
                case RemoteFileOutcome.failed:
                  outcomeColor = context.vDanger;
                  outcomeIcon = Icons.error_outline_rounded;
                  outcomeLabel = context.l10n.transferStatusFailed;
                  break;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(outcomeIcon, size: 18, color: outcomeColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  result.path,
                                  style: monoTextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: outcomeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    VRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  outcomeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: outcomeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (result.error != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              result.error!,
                              style: monoTextStyle(
                                fontSize: 11,
                                color: outcomeColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      actions: [
        if (retryableCount > 0 &&
            widget.action != null &&
            widget.originalItems != null &&
            widget.expectedServer != null)
          FilledButton.icon(
            key: const Key('sftp_retry_failed_batch_button'),
            icon: _isRetrying
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: Text(
              _isRetrying && _retryCompleted != null && _retryTotal != null
                  ? '${context.sftpRetryFailedLabel} ($_retryCompleted/$_retryTotal)'
                  : '${context.sftpRetryFailedLabel} ($retryableCount)',
            ),
            onPressed: _isRetrying ? null : _handleRetryFailed,
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cmdClose),
        ),
      ],
    );
  }
}

extension on BuildContext {
  String get sftpRetryFailedLabel {
    final loc = l10n.localeName.split('_').first;
    return switch (loc) {
      'zh' => l10n.localeName.contains('Hant') ? '重試失敗項目' : '重试失败项',
      'de' => 'Fehlgeschlagene wiederholen',
      'fr' => 'Réessayer les échecs',
      'es' => 'Reintentar fallidos',
      'pt' => 'Repetir com falha',
      'it' => 'Riprova non riusciti',
      'id' => 'Ulangi yang Gagal',
      'ja' => '失敗項目を再試行',
      'ko' => '실패 항목 다시 시도',
      'ru' => 'Повторить неудачные',
      'ar' => 'إعادة محاولة العمليات الفاشلة',
      'hi' => 'विफल पुन: प्रयास करें',
      'tr' => 'Başarısızları Yeniden Dene',
      'vi' => 'Thử lại mục thất bại',
      'th' => 'ลองใหม่รายการที่ล้มเหลว',
      _ => 'Retry Failed',
    };
  }
}
