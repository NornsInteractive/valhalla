import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../infrastructure/docker/docker_cli_service.dart';
import '../../../widgets/status_badge.dart';
import '../../../widgets/valhalla_card.dart';
import '../docker_provider.dart';

class DockerProjectCard extends StatefulWidget {
  final String project;
  final List<DockerContainer> containers;
  final DockerState dockerState;
  final bool isConnected;
  final void Function(DockerContainer container) onInspect;
  final void Function(DockerContainer container) onLogs;
  final void Function(DockerContainer container) onTerminal;
  final void Function(DockerContainer container, String action)
  onContainerLifecycle;
  final void Function(
    String project,
    String action,
    List<DockerContainer> containers,
  )
  onProjectLifecycle;

  const DockerProjectCard({
    super.key,
    required this.project,
    required this.containers,
    required this.dockerState,
    required this.isConnected,
    required this.onInspect,
    required this.onLogs,
    required this.onTerminal,
    required this.onContainerLifecycle,
    required this.onProjectLifecycle,
  });

  @override
  State<DockerProjectCard> createState() => _DockerProjectCardState();
}

class _DockerProjectCardState extends State<DockerProjectCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final containers = widget.containers;
    final runningCount = containers
        .where((c) => c.state == DockerContainerState.running)
        .length;
    final totalCount = containers.length;

    final projectContainerIds = containers.map((c) => c.id).toSet();
    final inFlightActions = <String>{};
    for (final id in projectContainerIds) {
      final action = widget.dockerState.pendingActions[id];
      if (action != null) inFlightActions.add(action);
    }
    final isProjectBusy = inFlightActions.isNotEmpty;
    final isRemoteDisabled = isProjectBusy || !widget.isConnected;

    final isStartPending = inFlightActions.contains('start');
    final isStopPending = inFlightActions.contains('stop');
    final isRestartPending = inFlightActions.contains('restart');

    return ValhallaCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 360;

              final titleSection = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(VRadius.input),
                    ),
                    child: Icon(
                      Icons.layers_rounded,
                      size: 18,
                      color: context.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.project,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '$runningCount/$totalCount ${context.l10n.dockerFilterRunning}',
                              style: TextStyle(
                                fontSize: 11,
                                color: runningCount > 0
                                    ? context.vSuccess
                                    : context.colorScheme.outline,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final toolbarSection = IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(32, 32),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: context.l10n.dockerProjectActionStart,
                      icon: isStartPending
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  context.vSuccess,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.play_arrow_rounded,
                              size: 20,
                              color: context.vSuccess,
                            ),
                      onPressed: isRemoteDisabled || runningCount == totalCount
                          ? null
                          : () => widget.onProjectLifecycle(
                              widget.project,
                              'start',
                              containers,
                            ),
                    ),
                    IconButton(
                      tooltip: context.l10n.dockerProjectActionStop,
                      icon: isStopPending
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  context.vWarning,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.stop_rounded,
                              size: 20,
                              color: context.vWarning,
                            ),
                      onPressed: isRemoteDisabled || runningCount == 0
                          ? null
                          : () => widget.onProjectLifecycle(
                              widget.project,
                              'stop',
                              containers,
                            ),
                    ),
                    IconButton(
                      tooltip: context.l10n.dockerProjectActionRestart,
                      icon: isRestartPending
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  context.vInfo,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.replay_rounded,
                              size: 18,
                              color: context.vInfo,
                            ),
                      onPressed: isRemoteDisabled
                          ? null
                          : () => widget.onProjectLifecycle(
                              widget.project,
                              'restart',
                              containers,
                            ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                    ),
                  ],
                ),
              );

              if (isVeryNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleSection,
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: toolbarSection,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleSection),
                  toolbarSection,
                ],
              );
            },
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: containers.length,
              separatorBuilder: (context, index) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Divider(height: 1),
              ),
              itemBuilder: (context, index) {
                final container = containers[index];
                return _buildServiceRow(context, container);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceRow(BuildContext context, DockerContainer container) {
    final pendingAction = widget.dockerState.pendingActions[container.id];
    final isContainerBusy = pendingAction != null;
    final isRemoteDisabled = isContainerBusy || !widget.isConnected;

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

    final shortId = container.id.length > 12
        ? container.id.substring(0, 12)
        : container.id;
    final serviceName = container.composeService ?? container.name;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            serviceName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (container.composeService != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '(${container.name})',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colorScheme.outline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          shortId,
                          style: monoTextStyle(
                            fontSize: 10,
                            color: context.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            container.image,
                            style: monoTextStyle(
                              fontSize: 10,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
          if (container.ports.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  Icons.input_rounded,
                  size: 12,
                  color: context.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    container.ports,
                    style: monoTextStyle(
                      fontSize: 10,
                      color: context.colorScheme.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          // Action buttons for this service
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(28, 28),
                  ),
                ),
                child: Wrap(
                  spacing: 2,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.receipt_long_outlined, size: 16),
                      tooltip: context.l10n.dockerActionLogs,
                      onPressed: isRemoteDisabled
                          ? null
                          : () => widget.onLogs(container),
                    ),
                    IconButton(
                      icon: pendingAction == 'inspect'
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.info_outline, size: 16),
                      tooltip: context.l10n.dockerActionInspect,
                      onPressed: isRemoteDisabled
                          ? null
                          : () => widget.onInspect(container),
                    ),
                    IconButton(
                      icon: const Icon(Icons.terminal_rounded, size: 16),
                      tooltip: context.l10n.dockerActionTerminal,
                      onPressed:
                          (isRemoteDisabled ||
                              container.state != DockerContainerState.running)
                          ? null
                          : () => widget.onTerminal(container),
                    ),
                    if (container.state != DockerContainerState.running)
                      IconButton(
                        icon: pendingAction == 'start'
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    context.vSuccess,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.play_arrow_rounded,
                                size: 18,
                                color: context.vSuccess,
                              ),
                        tooltip: context.l10n.dockerActionStart,
                        onPressed: isRemoteDisabled
                            ? null
                            : () => widget.onContainerLifecycle(
                                container,
                                'start',
                              ),
                      )
                    else ...[
                      IconButton(
                        icon: pendingAction == 'stop'
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    context.vWarning,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.stop_rounded,
                                size: 18,
                                color: context.vWarning,
                              ),
                        tooltip: context.l10n.dockerActionStop,
                        onPressed: isRemoteDisabled
                            ? null
                            : () => widget.onContainerLifecycle(
                                container,
                                'stop',
                              ),
                      ),
                      IconButton(
                        icon: pendingAction == 'restart'
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    context.vInfo,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.replay_rounded,
                                size: 16,
                                color: context.vInfo,
                              ),
                        tooltip: context.l10n.dockerActionRestart,
                        onPressed: isRemoteDisabled
                            ? null
                            : () => widget.onContainerLifecycle(
                                container,
                                'restart',
                              ),
                      ),
                    ],
                    IconButton(
                      icon: pendingAction == 'rm'
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  context.vDanger,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: context.vDanger,
                            ),
                      tooltip: context.l10n.dockerActionRm,
                      onPressed: isRemoteDisabled
                          ? null
                          : () => widget.onContainerLifecycle(container, 'rm'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
