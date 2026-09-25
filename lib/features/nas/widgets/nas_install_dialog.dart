import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/providers/nas_install_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/services/nas_install_service.dart';
import '../../../data/models/server_profile.dart';
import 'nas_localizations.dart';

class NasInstallDialog extends ConsumerStatefulWidget {
  const NasInstallDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const NasInstallDialog(),
    );
  }

  @override
  ConsumerState<NasInstallDialog> createState() => _NasInstallDialogState();
}

class _NasInstallDialogState extends ConsumerState<NasInstallDialog> {
  NasInstallProduct _product = NasInstallProduct.jellyfin;
  String? _selectedServerId;
  final _mediaPathCtrl = TextEditingController(text: '/media');
  final _dataRootCtrl = TextEditingController(
    text: '/var/lib/valhalla-nas/jellyfin',
  );
  final _portCtrl = TextEditingController(text: '8096');
  final _bindAddressCtrl = TextEditingController(text: '127.0.0.1');
  final _webdavUserCtrl = TextEditingController(text: 'nas');
  final _webdavPasswordCtrl = TextEditingController();

  bool _isSubmitting = false;
  bool _isCancelling = false;
  bool _isReconciling = false;
  String? _localError;
  bool _forceNewDeployment = false;
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    // UI-local timer only updates elapsed display; cancelling timer must never cancel installation.
    _elapsedTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _mediaPathCtrl.dispose();
    _dataRootCtrl.dispose();
    _portCtrl.dispose();
    _bindAddressCtrl.dispose();
    _webdavUserCtrl.dispose();
    _webdavPasswordCtrl.dispose();
    super.dispose();
  }

  void _onProductChanged(NasInstallProduct product) {
    setState(() {
      _product = product;
      _dataRootCtrl.text = '/var/lib/valhalla-nas/${product.name}';
      _portCtrl.text = product == NasInstallProduct.webdav ? '8080' : '8096';
      _localError = null;
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _preparePlan(
    NasInstallService service,
    List<ServerProfile> servers,
    ServerProfile? activeServer,
  ) async {
    setState(() => _localError = null);

    // Target server resolution: NO silent fallback to a different active server!
    final ServerProfile? targetServer;
    if (_selectedServerId != null) {
      targetServer = servers
          .where((s) => s.id == _selectedServerId)
          .firstOrNull;
      if (targetServer == null) {
        setState(() => _localError = context.nasInstallServerNotFound);
        return;
      }
    } else if (activeServer != null &&
        servers.any((s) => s.id == activeServer.id)) {
      targetServer = activeServer;
    } else if (servers.isNotEmpty) {
      targetServer = servers.first;
    } else {
      targetServer = null;
    }

    if (targetServer == null) {
      setState(() => _localError = context.nasInstallServerNotFound);
      return;
    }

    // Strict port parsing & range validation
    final rawPort = _portCtrl.text.trim();
    final parsedPort = int.tryParse(rawPort);
    if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
      setState(() => _localError = context.nasInstallPortRangeError);
      return;
    }

    // Immutable captured form before async work
    final req = NasInstallRequest(
      serverId: targetServer.id,
      serverName: targetServer.name,
      product: _product,
      mediaPath: _mediaPathCtrl.text.trim(),
      dataRoot: _dataRootCtrl.text.trim(),
      bindAddress: _bindAddressCtrl.text.trim(),
      port: parsedPort,
      webdavUser: _webdavUserCtrl.text.trim(),
    );

    setState(() {
      _isSubmitting = true;
      _forceNewDeployment = false;
    });

    try {
      await service.prepare(
        req,
        webdavPassword: _product == NasInstallProduct.webdav
            ? _webdavPasswordCtrl.text.trim()
            : null,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _localError = context.nasSanitizedError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _confirmInstall(
    NasInstallService service,
    NasInstallPlan plan,
  ) async {
    if (!plan.canInstall || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _localError = null;
    });

    try {
      await service.install(plan, confirmationToken: plan.confirmationToken);
    } catch (e) {
      if (mounted) {
        setState(() {
          _localError = context.nasSanitizedError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleCancel(NasInstallService service) async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);
    try {
      await service.cancel();
    } catch (e) {
      if (mounted) {
        setState(() => _localError = context.nasSanitizedError(e));
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _handleReconcile(NasInstallService service) async {
    if (_isReconciling) return;
    setState(() => _isReconciling = true);
    try {
      await service.reconcile();
    } catch (e) {
      if (mounted) {
        setState(() => _localError = context.nasSanitizedError(e));
      }
    } finally {
      if (mounted) setState(() => _isReconciling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servers = ref.watch(serverListProvider);
    final activeServer = ref.watch(activeServerProvider);

    final serviceAsync = ref.watch(nasInstallServiceProvider);
    final service = serviceAsync.asData?.value;

    final taskAsync = ref.watch(nasInstallTaskProvider);
    final task = _forceNewDeployment
        ? null
        : (taskAsync.asData?.value ?? service?.state);

    return Dialog(
      key: const Key('nas_install_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: 750,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.rocket_launch_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task != null
                          ? context.nasInstallTaskTitle
                          : context.nasInstallTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 12),

              // Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (task != null &&
                          task.stage == NasInstallStage.review &&
                          task.plan != null)
                        _buildPlanReviewView(context, task, task.plan!)
                      else if (task != null &&
                          (task.isBusy ||
                              task.stage == NasInstallStage.succeeded ||
                              task.stage == NasInstallStage.failed ||
                              task.stage == NasInstallStage.cancelled ||
                              task.stage == NasInstallStage.needsInspection ||
                              task.stage == NasInstallStage.reconciling))
                        _buildTaskProgressView(context, task, service)
                      else
                        _buildFormView(context, servers, activeServer, service),
                    ],
                  ),
                ),
              ),

              // Fixed visible error outside scrollable body
              if (_localError != null) ...[
                const SizedBox(height: 8),
                Container(
                  key: const Key('nas_install_local_error'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _localError!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 8),
              // Footer Action Buttons
              _buildFooterActions(
                context,
                task,
                service,
                servers,
                activeServer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActions(
    BuildContext context,
    NasInstallTask? task,
    NasInstallService? service,
    List<ServerProfile> servers,
    ServerProfile? activeServer,
  ) {
    if (task != null &&
        task.stage == NasInstallStage.review &&
        task.plan != null) {
      return Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            key: const Key('nas_install_discard_button'),
            onPressed: (_isSubmitting || service == null)
                ? null
                : () {
                    service.discard(task.plan!);
                    setState(() {
                      _forceNewDeployment = true;
                      _localError = null;
                    });
                  },
            child: Text(context.nasInstallBackEdit),
          ),
          FilledButton.icon(
            key: const Key('nas_install_confirm_button'),
            onPressed:
                (_isSubmitting || !task.plan!.canInstall || service == null)
                ? null
                : () => _confirmInstall(service, task.plan!),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 16),
            label: Text(context.nasInstallConfirmDeploy),
          ),
        ],
      );
    }

    if (task != null &&
        (task.isBusy ||
            task.stage == NasInstallStage.succeeded ||
            task.stage == NasInstallStage.failed ||
            task.stage == NasInstallStage.cancelled ||
            task.stage == NasInstallStage.needsInspection ||
            task.stage == NasInstallStage.reconciling)) {
      return Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (task.canCancel && service != null)
            OutlinedButton.icon(
              key: const Key('nas_install_cancel_task_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: _isCancelling ? null : () => _handleCancel(service),
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: Text(context.nasInstallCancel),
            ),
          if ((task.requiresReconciliation ||
                  task.stage == NasInstallStage.needsInspection) &&
              service != null)
            FilledButton.tonalIcon(
              key: const Key('nas_install_reconcile_button'),
              onPressed: _isReconciling
                  ? null
                  : () => _handleReconcile(service),
              icon: const Icon(Icons.sync_problem_outlined, size: 16),
              label: Text(context.nasInstallReconcile),
            ),
          if (!task.isBusy)
            OutlinedButton(
              key: const Key('nas_install_new_deployment_button'),
              onPressed:
                  (task.requiresReconciliation ||
                      _isSubmitting ||
                      _isReconciling)
                  ? null
                  : () {
                      setState(() {
                        _forceNewDeployment = true;
                        _localError = null;
                      });
                    },
              child: Text(context.nasInstallNewDeployment),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.nasInstallClose),
          ),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.nasInstallClose),
        ),
        FilledButton.icon(
          key: const Key('nas_install_prepare_button'),
          onPressed: (_isSubmitting || service == null)
              ? null
              : () => _preparePlan(service, servers, activeServer),
          icon: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward, size: 16),
          label: Text(context.nasInstallPreparePlan),
        ),
      ],
    );
  }

  Widget _buildFormView(
    BuildContext context,
    List<ServerProfile> servers,
    ServerProfile? activeServer,
    NasInstallService? service,
  ) {
    final validServerSelected =
        _selectedServerId == null ||
        servers.any((s) => s.id == _selectedServerId);
    final initialServerId = validServerSelected
        ? (_selectedServerId ??
              (servers.any((s) => s.id == activeServer?.id)
                  ? activeServer?.id
                  : servers.firstOrNull?.id))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Product Selection
        Text(
          context.nasInstallProduct,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SegmentedButton<NasInstallProduct>(
          segments: const [
            ButtonSegment(
              value: NasInstallProduct.jellyfin,
              label: Text('Jellyfin'),
              icon: Icon(Icons.tv),
            ),
            ButtonSegment(
              value: NasInstallProduct.emby,
              label: Text('Emby'),
              icon: Icon(Icons.live_tv),
            ),
            ButtonSegment(
              value: NasInstallProduct.webdav,
              label: Text('WebDAV'),
              icon: Icon(Icons.cloud_outlined),
            ),
          ],
          selected: {_product},
          onSelectionChanged: _isSubmitting
              ? null
              : (val) => _onProductChanged(val.first),
        ),
        const SizedBox(height: 14),

        // Target Server
        Text(
          context.nasSshServer,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: const Key('nas_install_server_selector'),
          isExpanded: true,
          initialValue: initialServerId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: servers.map((s) {
            return DropdownMenuItem<String>(
              value: s.id,
              child: Text(
                '${s.name} (${s.username}@${s.host}:${s.port})',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: _isSubmitting
              ? null
              : (val) => setState(() {
                  _selectedServerId = val;
                  _localError = null;
                }),
        ),
        const SizedBox(height: 14),

        // Media Path
        TextField(
          key: const Key('nas_install_media_path_field'),
          controller: _mediaPathCtrl,
          enabled: !_isSubmitting,
          decoration: InputDecoration(
            labelText: context.nasInstallMediaPath,
            helperText: context.nasInstallMediaPathHint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),

        // Data Root
        TextField(
          key: const Key('nas_install_data_root_field'),
          controller: _dataRootCtrl,
          enabled: !_isSubmitting,
          decoration: InputDecoration(
            labelText: context.nasInstallDataRoot,
            helperText: context.nasInstallDataRootHint,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 14),

        // Bind Address & Port
        LayoutBuilder(
          builder: (ctx, constraints) {
            final isNarrow = constraints.maxWidth < 340;
            if (isNarrow) {
              return Column(
                children: [
                  TextField(
                    key: const Key('nas_install_bind_address_field'),
                    controller: _bindAddressCtrl,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      labelText: context.nasInstallBindAddress,
                      helperText: context.nasInstallBindAddressHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('nas_install_port_field'),
                    controller: _portCtrl,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.nasInstallPort,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: const Key('nas_install_bind_address_field'),
                    controller: _bindAddressCtrl,
                    enabled: !_isSubmitting,
                    decoration: InputDecoration(
                      labelText: context.nasInstallBindAddress,
                      helperText: context.nasInstallBindAddressHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: const Key('nas_install_port_field'),
                    controller: _portCtrl,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.nasInstallPort,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        if (_product == NasInstallProduct.webdav) ...[
          const SizedBox(height: 14),
          TextField(
            key: const Key('nas_install_webdav_user_field'),
            controller: _webdavUserCtrl,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              labelText: context.nasInstallWebdavUser,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('nas_install_webdav_password_field'),
            controller: _webdavPasswordCtrl,
            enabled: !_isSubmitting,
            obscureText: true,
            decoration: InputDecoration(
              labelText: context.nasInstallWebdavPassword,
              helperText: context.nasInstallWebdavPasswordHint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlanReviewView(
    BuildContext context,
    NasInstallTask task,
    NasInstallPlan plan,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              plan.canInstall
                  ? Icons.verified_outlined
                  : Icons.warning_amber_rounded,
              color: plan.canInstall ? const Color(0xFF10B981) : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.nasInstallPlanTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Blockers (if any)
        if (plan.blockers.isNotEmpty) ...[
          Text(
            context.nasInstallBlockersTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.error),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.blockers.map((b) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cancel,
                        size: 14,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.nasInstallBlockerText(b),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Target Details: explicit target name, product, paths, image
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _detailRow(
                context,
                context.nasInstallTargetServer,
                task.request.serverName,
              ),
              _detailRow(
                context,
                context.nasInstallProduct,
                task.request.product.name.toUpperCase(),
              ),
              _detailRow(
                context,
                context.nasInstallTargetImage,
                plan.pinnedImage,
              ),
              _detailRow(
                context,
                context.nasInstallContainerName,
                plan.containerName,
              ),
              _detailRow(
                context,
                context.nasInstallMediaPath,
                plan.request.mediaPath,
              ),
              _detailRow(
                context,
                context.nasInstallDataRoot,
                plan.request.dataRoot,
              ),
              _detailRow(
                context,
                context.nasInstallBindAndPort,
                '${plan.request.bindAddress}:${plan.request.port}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Technical Compose Preview Box
        Text(
          context.nasInstallComposePreview,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          key: const Key('nas_install_compose_preview'),
          width: double.infinity,
          height: 150,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Text(
              plan.composePreview,
              style: const TextStyle(
                color: Color(0xFF6EE7B7),
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Steps
        Text(
          context.nasInstallPlannedSteps,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 6),
        ...plan.steps.map((st) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.nasInstallStepText(st),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }),

        // Guidance Notes
        if (plan.guidance.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.nasInstallGuidanceNotes,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          ...plan.guidance.map((g) {
            final isUrl = g.startsWith('http://') || g.startsWith('https://');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    isUrl ? Icons.link : Icons.info_outline,
                    size: 14,
                    color: isUrl
                        ? Colors.blueAccent
                        : theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isUrl ? g : context.nasInstallGuidanceText(g),
                      style: TextStyle(
                        fontSize: 11,
                        color: isUrl
                            ? Colors.blueAccent
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildTaskProgressView(
    BuildContext context,
    NasInstallTask task,
    NasInstallService? service,
  ) {
    final theme = Theme.of(context);
    final stageText = context.nasInstallStageText(task.stage);
    final isSuccess = task.stage == NasInstallStage.succeeded;
    final isFailed = task.stage == NasInstallStage.failed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header card with stage & elapsed
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSuccess
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : (isFailed
                      ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                      : theme.colorScheme.surfaceContainerHighest),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSuccess
                  ? const Color(0xFF10B981)
                  : (isFailed
                        ? theme.colorScheme.error
                        : theme.colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (task.isBusy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  else if (isSuccess)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF10B981),
                      size: 20,
                    )
                  else if (isFailed)
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    )
                  else
                    const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stageText,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    context.nasInstallElapsedTime(
                      _formatDuration(task.elapsed),
                    ),
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${task.request.product.name.toUpperCase()} on ${task.request.serverName}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Error & cleanup outcome near status
        if (task.errorCode != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.nasInstallBlockerText(task.errorCode!),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (task.cleanupComplete != null && !isSuccess) ...[
          Text(
            task.cleanupComplete!
                ? context.nasInstallCleanupCompleted
                : context.nasInstallCleanupIncomplete,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: task.cleanupComplete!
                  ? theme.colorScheme.outline
                  : theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Success result details
        if (isSuccess && task.result != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _detailRow(
                  context,
                  context.nasInstallEndpoint,
                  task.result!.endpoint.toString(),
                ),
                _detailRow(
                  context,
                  context.nasInstallContainerId,
                  task.result!.containerId.length > 12
                      ? task.result!.containerId.substring(0, 12)
                      : task.result!.containerId,
                ),
                _detailRow(
                  context,
                  context.nasInstallDataRoot,
                  task.result!.dataRoot,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Log tail box
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.nasInstallLogTail,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          key: const Key('nas_install_log_tail'),
          height: 180,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F141C),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            reverse: true,
            child: SelectableText(
              task.logTail.isEmpty
                  ? '(${context.nasInstallNoLogsYet})'
                  : task.logTail,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                height: 1.4,
                color: Color(0xFFE2E8F0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 80, maxWidth: 120),
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'JetBrains Mono',
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
