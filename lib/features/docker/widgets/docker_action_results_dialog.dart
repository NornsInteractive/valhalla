import 'package:flutter/material.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../infrastructure/docker/docker_cli_service.dart';

class DockerActionResultsDialog extends StatelessWidget {
  final String title;
  final List<DockerActionResult> results;

  const DockerActionResultsDialog({
    super.key,
    required this.title,
    required this.results,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<DockerActionResult> results,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => DockerActionResultsDialog(title: title, results: results),
    );
  }

  @override
  Widget build(BuildContext context) {
    final failureCount = results.where((r) => !r.success).length;

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
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: results.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final result = results[index];
              final shortId = result.containerId.length > 12
                  ? result.containerId.substring(0, 12)
                  : result.containerId;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      result.success
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      size: 18,
                      color: result.success
                          ? context.vSuccess
                          : context.vDanger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                result.containerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                shortId,
                                style: monoTextStyle(
                                  fontSize: 11,
                                  color: context.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                          if (result.error != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              result.error!,
                              style: monoTextStyle(
                                fontSize: 11,
                                color: context.vDanger,
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
