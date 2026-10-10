import 'package:flutter/material.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../infrastructure/sftp/remote_file_actions.dart';

class RemoteFileBatchResultsDialog extends StatelessWidget {
  final List<RemoteFileResult> results;

  const RemoteFileBatchResultsDialog({super.key, required this.results});

  static Future<void> show(
    BuildContext context, {
    required List<RemoteFileResult> results,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => RemoteFileBatchResultsDialog(results: results),
    );
  }

  @override
  Widget build(BuildContext context) {
    final failureCount = results
        .where(
          (r) =>
              r.outcome == RemoteFileOutcome.failed ||
              r.outcome == RemoteFileOutcome.skipped,
        )
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
            itemCount: results.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final result = results[index];
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cmdClose),
        ),
      ],
    );
  }
}
