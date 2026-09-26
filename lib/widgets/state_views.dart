import 'package:flutter/material.dart';
import '../core/design/motion_widgets.dart';
import '../core/design/tokens.dart';
import '../core/extensions/context_extensions.dart';

/// 全局状态视图: 加载 (骨架) / 空 / 离线 / 错误。
///
/// 全部带 [Entrance] 入场编排; 图标容器统一 16 圆角色块 (形状一致性)。
class LoadingStateView extends StatelessWidget {
  final String? message;

  const LoadingStateView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Entrance(
      index: 0,
      offset: const Offset(0, 10),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Shimmer(
              child: Column(
                children: [
                  SkeletonBox(width: 120, height: 120, radius: VRadius.cardLarge),
                  const SizedBox(height: VSpace.xxl),
                  SkeletonBox(width: 160, height: 14),
                  const SizedBox(height: VSpace.md),
                  SkeletonBox(width: 100, height: 11),
                ],
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: VSpace.xxl),
              Text(
                message!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 组合骨架: 卡片网格加载态 (用于指标网格等)。
class SkeletonMetricGrid extends StatelessWidget {
  const SkeletonMetricGrid({super.key, this.columns = 2, this.rows = 2});

  final int columns;
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var r = 0; r < rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: VSpace.lg),
              child: Row(
                children: [
                  for (var c = 0; c < columns; c++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: c == columns - 1 ? 0 : VSpace.lg,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(VSpace.lg),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(VRadius.card),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 64, height: 11),
                              const SizedBox(height: VSpace.lg),
                              SkeletonBox(width: 84, height: 22, radius: 6),
                              const SizedBox(height: VSpace.md),
                              SkeletonBox(width: double.infinity, height: 5, radius: 3),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  const EmptyStateView({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Center(
      child: Entrance(
        offset: const Offset(0, 18),
        child: Padding(
          padding: const EdgeInsets.all(VSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(VRadius.card),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: VSpace.xl),
              Text(
                title,
                style: context.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              if (description != null) ...[
                const SizedBox(height: VSpace.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Text(
                    description!,
                    style: context.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: VSpace.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OfflineStateView extends StatelessWidget {
  final VoidCallback? onConnect;

  const OfflineStateView({super.key, this.onConnect});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Center(
      child: Entrance(
        offset: const Offset(0, 18),
        child: Padding(
          padding: const EdgeInsets.all(VSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(VRadius.card),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(
                  Icons.link_off_rounded,
                  size: 30,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: VSpace.xl),
              Text(
                context.l10n.stateOffline,
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: VSpace.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  context.l10n.stateOfflineDesc,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall,
                ),
              ),
              if (onConnect != null) ...[
                const SizedBox(height: VSpace.xxl),
                FilledButton.icon(
                  icon: const Icon(Icons.link, size: 16),
                  label: Text(context.l10n.connectNow),
                  onPressed: onConnect,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  final String? message;
  final int? exitCode;
  final VoidCallback? onRetry;

  const ErrorStateView({super.key, this.message, this.exitCode, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final danger = context.vDanger;
    return Center(
      child: Entrance(
        offset: const Offset(0, 18),
        child: Padding(
          padding: const EdgeInsets.all(VSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(VRadius.card),
                  border: Border.all(color: danger.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 30,
                  color: danger,
                ),
              ),
              const SizedBox(height: VSpace.xl),
              Text(
                context.l10n.stateError,
                style: context.textTheme.titleMedium?.copyWith(color: danger),
              ),
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: VSpace.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodySmall,
                  ),
                ),
              ],
              if (exitCode != null) ...[
                const SizedBox(height: VSpace.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(VRadius.input),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    context.l10n.stateExitCode(exitCode!),
                    style: monoTextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: VSpace.xxl),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(context.l10n.stateRetry),
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 交错入场列表包装: 常用于分节内容 (标题 + 卡片组)。
/// 子项各自包 [Entrance] 时无需此组件。
class StaggeredColumn extends StatelessWidget {
  const StaggeredColumn({
    super.key,
    required this.children,
    this.startIndex = 0,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final List<Widget> children;
  final int startIndex;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (var i = 0; i < children.length; i++)
          Entrance(
            index: startIndex + i,
            offset: const Offset(0, 14),
            child: children[i],
          ),
      ],
    );
  }
}
