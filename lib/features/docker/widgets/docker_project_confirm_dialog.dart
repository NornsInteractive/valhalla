import 'package:flutter/material.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../infrastructure/docker/docker_cli_service.dart';
import '../../../widgets/status_badge.dart';

class DockerProjectConfirmDialog extends StatelessWidget {
  final String project;
  final String action;
  final List<DockerContainer> containers;

  const DockerProjectConfirmDialog({
    super.key,
    required this.project,
    required this.action,
    required this.containers,
  });

  static Future<bool> show(
    BuildContext context, {
    required String project,
    required String action,
    required List<DockerContainer> containers,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => DockerProjectConfirmDialog(
        project: project,
        action: action,
        containers: containers,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isStop = action == 'stop';
    final actionColor = isStop ? context.vWarning : context.vInfo;
    final title = isStop
        ? context.l10n.dockerProjectConfirmStopTitle
        : (action == 'restart'
              ? context.l10n.dockerProjectConfirmRestartTitle
              : context.l10n.dockerProjectActionStart);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isStop ? Icons.warning_amber_rounded : Icons.replay_rounded,
            color: actionColor,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.dockerProjectConfirmMessage(
                    action,
                    project,
                    containers.length,
                  ),
                  style: context.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: containers.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final container = containers[index];
                    final serviceName =
                        container.composeService ?? container.name;
                    final shortId = container.id.length > 12
                        ? container.id.substring(0, 12)
                        : container.id;

                    StatusType statusType;
                    switch (container.state) {
                      case DockerContainerState.running:
                        statusType = StatusType.online;
                        break;
                      case DockerContainerState.exited:
                        statusType = StatusType.offline;
                        break;
                      case DockerContainerState.paused:
                        statusType = StatusType.warning;
                        break;
                      default:
                        statusType = StatusType.running;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      serviceName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (container.composeService != null)
                                      Text(
                                        '(${container.name})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: context.colorScheme.outline,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$shortId • ${container.image}',
                                  style: monoTextStyle(
                                    fontSize: 11,
                                    color: context.colorScheme.outline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            label: container.state.name.toUpperCase(),
                            type: statusType,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: actionColor,
            foregroundColor: context.colorScheme.surface,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.confirm),
        ),
      ],
    );
  }
}
