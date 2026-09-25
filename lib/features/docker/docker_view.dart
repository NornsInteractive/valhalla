import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/layout_breakpoints.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/providers/infrastructure_providers.dart';
import '../../core/providers/server_provider.dart';
import '../../core/providers/storage_providers.dart';
import '../../infrastructure/docker/docker_cli_service.dart';
import '../../infrastructure/terminal/terminal_session_bridge.dart';
import '../../widgets/danger_confirm_dialog.dart';
import '../../widgets/state_views.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/valhalla_card.dart';
import '../terminal/widgets/shared_terminal_canvas.dart';
import 'docker_provider.dart';

class DockerView extends ConsumerStatefulWidget {
  final ValueChanged<DockerContainer?>? onSelectContainer;

  const DockerView({super.key, this.onSelectContainer});

  @override
  ConsumerState<DockerView> createState() => _DockerViewState();
}

class _DockerViewState extends ConsumerState<DockerView> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLifecycleAction(
    DockerContainer container,
    String action,
  ) async {
    if (ref.read(dockerProvider).pendingActions.containsKey(container.id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.dockerActionPending)));
      return;
    }

    final cmd = 'docker $action ${container.id}';
    final confirmed = await DangerConfirmDialog.show(
      context,
      command: cmd,
      title: action == 'rm'
          ? context.l10n.riskDangerTitle
          : context.l10n.riskWarningTitle,
    );

    if (!confirmed || !mounted) return;

    final capturedServerId = ref.read(activeServerProvider)?.id;
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(dockerProvider.notifier)
          .performLifecycle(action, container.id);
      if (!mounted) return;
      if (capturedServerId != null &&
          ref.read(activeServerProvider)?.id != capturedServerId) {
        return;
      }
      if (result.isSuccess) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.dockerActionSuccess(container.name, action),
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        final err = result.stderr.trim().isNotEmpty
            ? result.stderr.trim()
            : context.l10n.stateError;
        scaffold.showSnackBar(
          SnackBar(
            content: Text(context.l10n.dockerActionFailed(err)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (capturedServerId != null &&
          ref.read(activeServerProvider)?.id != capturedServerId) {
        return;
      }
      scaffold.showSnackBar(
        SnackBar(
          content: Text(context.l10n.dockerActionFailed(e.toString())),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _showLogsDialog(DockerContainer container) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${context.l10n.dockerLogsTitle} - ${container.name}',
                  style: const TextStyle(fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 700,
            height: 450,
            child: DockerLogsDialogContent(
              logStream: ref
                  .read(dockerProvider.notifier)
                  .streamLogs(container.id),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.confirm),
            ),
          ],
        );
      },
    );
  }

  void _showInspectModal(DockerContainer container) async {
    final capturedServerId = ref.read(activeServerProvider)?.id;
    final scaffold = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(
        maxWidth: LayoutBreakpoints.modalSheetWideMaxWidth,
      ),
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: ref
              .read(dockerProvider.notifier)
              .inspectContainer(container.id),
          builder: (ctx, snapshot) {
            return SafeArea(
              child: Container(
                height: MediaQuery.sizeOf(context).height * 0.75,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${context.l10n.dockerInspectTitle}: ${container.name}',
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: snapshot.connectionState == ConnectionState.waiting
                          ? const LoadingStateView()
                          : snapshot.hasError
                          ? ErrorStateView(message: snapshot.error.toString())
                          : Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F141C),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  const JsonEncoder.withIndent(
                                    '  ',
                                  ).convert(snapshot.data ?? {}),
                                  style: const TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 11,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).catchError((err) {
      if (!mounted) return;
      if (capturedServerId != null &&
          ref.read(activeServerProvider)?.id != capturedServerId) {
        return;
      }
      scaffold.showSnackBar(SnackBar(content: Text(err.toString())));
    });
  }

  Future<void> _openContainerTerminal(DockerContainer container) async {
    final activeServer = ref.read(activeServerProvider);
    if (activeServer == null) return;
    if (container.state != DockerContainerState.running) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.dockerTerminalNotRunning),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    final scaffold = ScaffoldMessenger.of(context);
    String? storedShell;
    try {
      final storage = ref.read(localStorageServiceProvider);
      storedShell = storage.getContainerShell(activeServer.id, container.name);
    } catch (_) {}
    final preferredShell = storedShell == 'sh'
        ? DockerTerminalShell.sh
        : DockerTerminalShell.bash;

    TerminalSessionBridge? bridge;
    try {
      final result = await ref
          .read(dockerCliServiceProvider)
          .openTerminal(
            activeServer.id,
            container,
            activeServer.name,
            preferredShell: preferredShell,
          );
      bridge = result.bridge;
      final actualShell = result.shell;
      await bridge.start();

      if (!mounted) {
        bridge.dispose();
        return;
      }

      if (preferredShell == DockerTerminalShell.bash &&
          actualShell == DockerTerminalShell.sh) {
        scaffold.showSnackBar(
          SnackBar(content: Text(context.l10n.dockerBashFallbackNotice)),
        );
      }

      await showDialog(
        context: context,
        useSafeArea: false,
        builder: (ctx) {
          final isCompact =
              MediaQuery.sizeOf(ctx).width < LayoutBreakpoints.compactMax;
          final titleWidget = Row(
            children: [
              const Icon(Icons.terminal_rounded, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${context.l10n.dockerTerminalTitle}: ${container.name}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          );

          if (isCompact) {
            return Dialog.fullscreen(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(
                    '${context.l10n.dockerTerminalTitle}: ${container.name}',
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                body: SafeArea(
                  child: SharedTerminalCanvas(
                    terminal: bridge!.terminal,
                    onKey: (key, {bool isCtrl = false, bool isAlt = false}) {
                      bridge!.sendKey(key, isCtrl: isCtrl, isAlt: isAlt);
                    },
                    onPaste: () => bridge!.pasteClipboard(),
                  ),
                ),
              ),
            );
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 600),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: titleWidget,
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(8),
                      ),
                      child: SharedTerminalCanvas(
                        terminal: bridge!.terminal,
                        onKey:
                            (key, {bool isCtrl = false, bool isAlt = false}) {
                              bridge!.sendKey(
                                key,
                                isCtrl: isCtrl,
                                isAlt: isAlt,
                              );
                            },
                        onPaste: () => bridge!.pasteClipboard(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      scaffold.showSnackBar(
        SnackBar(
          content: Text(context.l10n.dockerActionFailed(e.toString())),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      bridge?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final connState = ref.watch(serverConnectionProvider);
    if (!connState.isConnected) {
      return Scaffold(
        body: OfflineStateView(
          onConnect: () {
            ref.read(serverConnectionProvider.notifier).connect();
          },
        ),
      );
    }

    final dockerState = ref.watch(dockerProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: context.l10n.dockerSearchHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref
                                    .read(dockerProvider.notifier)
                                    .setSearchQuery('');
                              },
                            )
                          : null,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (val) {
                      ref.read(dockerProvider.notifier).setSearchQuery(val);
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: context.l10n.sftpRefresh,
                  onPressed: dockerState.isLoading
                      ? null
                      : () => ref.read(dockerProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: Text(context.l10n.dockerFilterAll),
                  selected: dockerState.filterState == null,
                  onSelected: (_) =>
                      ref.read(dockerProvider.notifier).setFilterState(null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(context.l10n.dockerFilterRunning),
                  selected:
                      dockerState.filterState == DockerContainerState.running,
                  onSelected: (val) => ref
                      .read(dockerProvider.notifier)
                      .setFilterState(
                        val ? DockerContainerState.running : null,
                      ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(context.l10n.dockerFilterExited),
                  selected:
                      dockerState.filterState == DockerContainerState.exited,
                  onSelected: (val) => ref
                      .read(dockerProvider.notifier)
                      .setFilterState(val ? DockerContainerState.exited : null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(context.l10n.dockerFilterPaused),
                  selected:
                      dockerState.filterState == DockerContainerState.paused,
                  onSelected: (val) => ref
                      .read(dockerProvider.notifier)
                      .setFilterState(val ? DockerContainerState.paused : null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody(context, dockerState)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, DockerState dockerState) {
    if (dockerState.isLoading && dockerState.containers.isEmpty) {
      return const LoadingStateView();
    }

    if (dockerState.errorMessage != null && dockerState.containers.isEmpty) {
      return ErrorStateView(
        message: dockerState.errorMessage,
        exitCode: dockerState.exitCode,
        onRetry: () => ref.read(dockerProvider.notifier).refresh(),
      );
    }

    final list = dockerState.filteredContainers;
    if (list.isEmpty) {
      return EmptyStateView(
        icon: Icons.directions_boat_outlined,
        title: context.l10n.dockerNoContainers,
        description: dockerState.searchQuery.isNotEmpty
            ? context.l10n.stateEmpty
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(dockerProvider.notifier).refresh(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < LayoutBreakpoints.compactMax) {
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: list.length,
              itemBuilder: (ctx, index) {
                final container = list[index];
                return _buildContainerCard(context, dockerState, container);
              },
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: LayoutBreakpoints.gridDockerCardMaxExtent,
              mainAxisExtent: 230,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: list.length,
            itemBuilder: (ctx, index) {
              final container = list[index];
              return _buildContainerCard(
                context,
                dockerState,
                container,
                isGrid: true,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContainerCard(
    BuildContext context,
    DockerState dockerState,
    DockerContainer container, {
    bool isGrid = false,
  }) {
    final pendingAction = dockerState.pendingActions[container.id];
    final isContainerBusy = pendingAction != null;
    final activeServer = ref.watch(activeServerProvider);
    String containerShell = 'bash';
    if (activeServer != null) {
      try {
        containerShell = ref
            .watch(localStorageServiceProvider)
            .getContainerShell(activeServer.id, container.name);
      } catch (_) {}
    }

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

    return ValhallaCard(
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      onTap: isContainerBusy
          ? null
          : () {
              ref.read(dockerProvider.notifier).selectContainer(container);
              if (widget.onSelectContainer != null) {
                widget.onSelectContainer!(container);
              } else {
                _showInspectModal(container);
              }
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            container.name,
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          key: Key('docker_shell_select_${container.id}'),
                          tooltip: context.l10n.dockerShellLabel,
                          enabled:
                              !isContainerBusy &&
                              container.state == DockerContainerState.running,
                          initialValue: containerShell,
                          onSelected: (val) async {
                            if (activeServer == null) return;
                            try {
                              await ref
                                  .read(localStorageServiceProvider)
                                  .setContainerShell(
                                    activeServer.id,
                                    container.name,
                                    val,
                                  );
                            } catch (_) {}
                            if (mounted) setState(() {});
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'bash',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (containerShell == 'bash')
                                    const Icon(Icons.check, size: 16)
                                  else
                                    const SizedBox(width: 16),
                                  const SizedBox(width: 8),
                                  Text(context.l10n.dockerShellBash),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'sh',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (containerShell == 'sh')
                                    const Icon(Icons.check, size: 16)
                                  else
                                    const SizedBox(width: 16),
                                  const SizedBox(width: 8),
                                  Text(context.l10n.dockerShellSh),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color:
                                    container.state ==
                                        DockerContainerState.running
                                    ? context.colorScheme.outlineVariant
                                    : context.colorScheme.outlineVariant
                                          .withValues(alpha: 0.5),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  containerShell.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        container.state ==
                                            DockerContainerState.running
                                        ? context.colorScheme.onSurface
                                        : context.colorScheme.outline,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 14,
                                  color:
                                      container.state ==
                                          DockerContainerState.running
                                      ? context.colorScheme.onSurfaceVariant
                                      : context.colorScheme.outline,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shortId,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: context.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: container.state.name.toUpperCase(),
                type: statusType,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.layers_outlined,
                size: 14,
                color: context.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  container.image,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (container.ports.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.input_rounded,
                  size: 14,
                  color: context.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    container.ports,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: context.colorScheme.outline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: context.colorScheme.outline,
              ),
              const SizedBox(width: 4),
              Text(
                container.status,
                style: TextStyle(
                  fontSize: 11,
                  color: context.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),
          IconButtonTheme(
            data: IconButtonThemeData(
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(32, 32),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  tooltip: context.l10n.dockerActionLogs,
                  onPressed: isContainerBusy
                      ? null
                      : () => _showLogsDialog(container),
                ),
                IconButton(
                  icon: pendingAction == 'inspect'
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.info_outline, size: 18),
                  tooltip: context.l10n.dockerActionInspect,
                  onPressed: isContainerBusy
                      ? null
                      : () => _showInspectModal(container),
                ),
                IconButton(
                  key: Key('docker_terminal_button_${container.id}'),
                  icon: const Icon(Icons.terminal_rounded, size: 18),
                  tooltip: context.l10n.dockerActionTerminal,
                  onPressed:
                      (isContainerBusy ||
                          container.state != DockerContainerState.running)
                      ? null
                      : () => _openContainerTerminal(container),
                ),
                if (container.state != DockerContainerState.running)
                  IconButton(
                    icon: pendingAction == 'start'
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF10B981),
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.play_arrow_rounded,
                            size: 20,
                            color: Color(0xFF10B981),
                          ),
                    tooltip: context.l10n.dockerActionStart,
                    onPressed: isContainerBusy
                        ? null
                        : () => _handleLifecycleAction(container, 'start'),
                  )
                else ...[
                  IconButton(
                    icon: pendingAction == 'stop'
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFF59E0B),
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.stop_rounded,
                            size: 20,
                            color: Color(0xFFF59E0B),
                          ),
                    tooltip: context.l10n.dockerActionStop,
                    onPressed: isContainerBusy
                        ? null
                        : () => _handleLifecycleAction(container, 'stop'),
                  ),
                  IconButton(
                    icon: pendingAction == 'restart'
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF0EA5E9),
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.replay_rounded,
                            size: 18,
                            color: Color(0xFF0EA5E9),
                          ),
                    tooltip: context.l10n.dockerActionRestart,
                    onPressed: isContainerBusy
                        ? null
                        : () => _handleLifecycleAction(container, 'restart'),
                  ),
                ],
                IconButton(
                  icon: pendingAction == 'rm'
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFEF4444),
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Color(0xFFEF4444),
                        ),
                  tooltip: context.l10n.dockerActionRm,
                  onPressed: isContainerBusy
                      ? null
                      : () => _handleLifecycleAction(container, 'rm'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DockerLogsDialogContent extends StatefulWidget {
  final Stream<String> logStream;
  final int maxBytes;

  const DockerLogsDialogContent({
    super.key,
    required this.logStream,
    this.maxBytes = 256 * 1024,
  });

  static String trimToUtf8MaxBytes(String text, int maxBytes) {
    if (maxBytes <= 0) return '';
    final encoded = utf8.encode(text);
    if (encoded.length <= maxBytes) return text;
    var start = encoded.length - maxBytes;
    while (start < encoded.length && (encoded[start] & 0xC0) == 0x80) {
      start++;
    }
    if (start >= encoded.length) return '';
    final trimmedBytes = encoded.sublist(start);
    return utf8.decode(trimmedBytes, allowMalformed: true);
  }

  @override
  State<DockerLogsDialogContent> createState() =>
      _DockerLogsDialogContentState();
}

class _DockerLogsDialogContentState extends State<DockerLogsDialogContent> {
  StreamSubscription<String>? _sub;
  String _logs = '';
  final ListQueue<String> _pending = ListQueue<String>();
  int _pendingBytes = 0;
  Timer? _flushTimer;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sub = widget.logStream.listen(
      (chunk) {
        final chunkBytes = utf8.encode(chunk).length;
        if (chunkBytes >= widget.maxBytes) {
          _pending.clear();
          final trimmed = DockerLogsDialogContent.trimToUtf8MaxBytes(
            chunk,
            widget.maxBytes,
          );
          _pending.add(trimmed);
          _pendingBytes = utf8.encode(trimmed).length;
        } else {
          while (_pending.isNotEmpty &&
              _pendingBytes + chunkBytes > widget.maxBytes) {
            final removed = _pending.removeFirst();
            _pendingBytes -= utf8.encode(removed).length;
          }
          _pending.add(chunk);
          _pendingBytes += chunkBytes;
        }
        _scheduleFlush();
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _error = err;
          _loading = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        _flush();
        setState(() {
          _loading = false;
        });
      },
    );
  }

  void _scheduleFlush() {
    if (_flushTimer?.isActive ?? false) return;
    _flushTimer = Timer(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      _flush();
      setState(() {
        _loading = false;
      });
    });
  }

  void _flush() {
    if (_pending.isEmpty) return;
    final incoming = _pending.join();
    _pending.clear();
    _pendingBytes = 0;
    final combined = _logs + incoming;
    _logs = DockerLogsDialogContent.trimToUtf8MaxBytes(
      combined,
      widget.maxBytes,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _flushTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _logs.isEmpty && _error == null) {
      return const LoadingStateView();
    }
    if (_error != null && _logs.isEmpty) {
      return ErrorStateView(message: _error.toString());
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F141C),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                _logs.isEmpty ? context.l10n.dockerNoLogs : _logs,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
