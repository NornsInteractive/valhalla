import 'package:flutter/material.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../infrastructure/sftp/remote_file_actions.dart';
import '../../../infrastructure/sftp/sftp_client_service.dart';

class BatchConfirmDialog extends StatelessWidget {
  final RemoteFileAction action;
  final List<SftpFileItem> items;
  final String? targetDirectory;

  const BatchConfirmDialog({
    super.key,
    required this.action,
    required this.items,
    this.targetDirectory,
  });

  static Future<bool> show(
    BuildContext context, {
    required RemoteFileAction action,
    required List<SftpFileItem> items,
    String? targetDirectory,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => BatchConfirmDialog(
        action: action,
        items: items,
        targetDirectory: targetDirectory,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDelete = action == RemoteFileAction.delete;
    final title = isDelete
        ? context.l10n.sftpBatchDeleteConfirmTitle
        : (action == RemoteFileAction.move
              ? context.l10n.sftpBatchMoveConfirmTitle
              : context.l10n.sftpBatchCopyConfirmTitle);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isDelete ? Icons.delete_forever_rounded : Icons.folder_copy_rounded,
            color: isDelete ? context.vDanger : context.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDelete
                    ? context.l10n.sftpBatchDeleteConfirmMessage(items.length)
                    : (action == RemoteFileAction.move
                          ? context.l10n.sftpBatchMoveConfirmMessage(
                              items.length,
                              targetDirectory ?? '',
                            )
                          : context.l10n.sftpBatchCopyConfirmMessage(
                              items.length,
                              targetDirectory ?? '',
                            )),
                style: context.textTheme.bodyMedium,
              ),
              if (isDelete) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.vWarning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(VRadius.input),
                    border: Border.all(
                      color: context.vWarning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: context.vWarning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.sftpBatchDeleteNonEmptyNotice,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.vWarning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            item.isDirectory
                                ? Icons.folder
                                : Icons.insert_drive_file_outlined,
                            size: 18,
                            color: item.isDirectory
                                ? context.colorScheme.primary
                                : context.colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.name,
                              style: monoTextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.formattedSize,
                            style: monoTextStyle(
                              fontSize: 11,
                              color: context.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          style: isDelete
              ? FilledButton.styleFrom(
                  backgroundColor: context.vDanger,
                  foregroundColor: context.colorScheme.surface,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(isDelete ? context.l10n.delete : context.l10n.confirm),
        ),
      ],
    );
  }
}
