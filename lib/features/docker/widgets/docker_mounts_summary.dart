import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';

class DockerMountsSummary extends StatelessWidget {
  final List<dynamic>? mounts;

  const DockerMountsSummary({super.key, required this.mounts});

  @override
  Widget build(BuildContext context) {
    if (mounts == null || mounts!.isEmpty) {
      return const SizedBox.shrink();
    }

    final parsedMounts = mounts!.whereType<Map<String, dynamic>>().toList();
    if (parsedMounts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.folder_shared_outlined, size: 16),
            const SizedBox(width: 6),
            Text(
              context.l10n.dockerMountsTitle,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: context.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(VRadius.pill),
              ),
              child: Text(
                '${parsedMounts.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: parsedMounts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final mount = parsedMounts[index];
            final type = (mount['Type'] as String? ?? 'mount').toLowerCase();
            final isRw =
                mount['RW'] == true ||
                (mount['Mode'] as String? ?? '').contains('rw');
            final source =
                mount['Source'] as String? ?? mount['Name'] as String? ?? '-';
            final destination = mount['Destination'] as String? ?? '-';

            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(VRadius.input),
                border: Border.all(
                  color: context.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: context.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(VRadius.pill),
                        ),
                        child: Text(
                          type.toUpperCase(),
                          style: monoTextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: context.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isRw
                              ? context.vSuccess.withValues(alpha: 0.15)
                              : context.vWarning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(VRadius.pill),
                        ),
                        child: Text(
                          isRw
                              ? context.l10n.dockerMountReadWrite
                              : context.l10n.dockerMountReadOnly,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isRw ? context.vSuccess : context.vWarning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.computer_outlined,
                        size: 13,
                        color: context.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          source,
                          style: monoTextStyle(
                            fontSize: 11,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 13,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          destination,
                          style: monoTextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: context.colorScheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
