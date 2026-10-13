import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/nas_native_install_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/services/nas_native_install_service.dart';
import '../../../core/services/remote_browser_service.dart';
import '../../../data/models/server_profile.dart';
import '../../../widgets/remote_browser_dialog.dart';
import 'jellyfin_source_actions.dart';
import 'nas_localizations.dart';

class NasNativeInstallDialog extends ConsumerStatefulWidget {
  const NasNativeInstallDialog({super.key});

  static Future<void> show(BuildContext context) {
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;
    if (isCompact) {
      return Navigator.push<void>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const NasNativeInstallDialog(),
        ),
      );
    }
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NasNativeInstallDialog(),
    );
  }

  @override
  ConsumerState<NasNativeInstallDialog> createState() =>
      _NasNativeInstallDialogState();
}

class _NasNativeInstallDialogState
    extends ConsumerState<NasNativeInstallDialog> {
  final _mediaPathCtrl = TextEditingController(text: '/media');
  final _formKey = GlobalKey<FormState>();

  Object? _capturedConnectionKey;
  String? _capturedNativeKey;
  ServerProfile? _capturedServer;

  NasNativeInstallPlan? _currentPlan;
  bool _isFormEditMode = false;
  bool _isPreparing = false;
  bool _isExecuting = false;
  bool _isReconciling = false;
  bool _isCancelling = false;
  String? _localError;
  bool _isBrowsing = false;
  Timer? _elapsedTimer;

  bool get _isLocalBusy =>
      _isPreparing || _isExecuting || _isReconciling || _isCancelling;

  @override
  void initState() {
    super.initState();
    final activeServer = ref.read(activeServerProvider);
    _capturedServer = activeServer;
    _capturedConnectionKey = activeServer?.connectionKey;
    _capturedNativeKey = activeServer != null
        ? NasNativeInstallService.serverKey(activeServer)
        : null;

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _mediaPathCtrl.dispose();
    super.dispose();
  }

  bool _isAlive() {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final currentServer = ref.read(activeServerProvider);
    if (currentServer?.connectionKey != _capturedConnectionKey) return false;
    if (currentServer == null) return false;
    final currentNativeKey = NasNativeInstallService.serverKey(currentServer);
    if (currentNativeKey != _capturedNativeKey) return false;
    final isConnected = ref.read(
      serverConnectionProvider.select((s) => s.isConnected),
    );
    if (!isConnected) return false;
    return true;
  }

  void _resetLocalBusyState() {
    if (mounted) {
      setState(() {
        _isPreparing = false;
        _isExecuting = false;
        _isReconciling = false;
        _isCancelling = false;
      });
    }
  }

  Future<void> _browseMediaPath() async {
    if (!_isAlive() || _isLocalBusy || _isBrowsing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final original = _mediaPathCtrl.text;
    setState(() => _isBrowsing = true);
    try {
      final browser = ref
          .read(remoteBrowserFactoryProvider)
          .host(
            initialPath: original.trim().isEmpty ? '/' : original.trim(),
            isCurrent: () =>
                mounted &&
                _mediaPathCtrl.text == original &&
                ref.read(activeServerProvider)?.connectionKey ==
                    _capturedConnectionKey,
          );
      try {
        final path = await RemoteBrowserDialog.pickDirectory(context, browser);
        if (mounted && browser.isCurrent && path != null) {
          setState(() => _mediaPathCtrl.text = path);
        }
      } finally {
        await browser.dispose();
      }
    } catch (error) {
      if (mounted) setState(() => _localError = context.nasBrowserError(error));
    } finally {
      if (mounted) setState(() => _isBrowsing = false);
    }
  }

  Future<void> _handlePrepare() async {
    if (!_formKey.currentState!.validate()) return;
    final activeServer = ref.read(activeServerProvider);
    if (activeServer == null || !_isAlive()) return;

    setState(() {
      _isPreparing = true;
      _localError = null;
      _currentPlan = null;
    });

    try {
      final service = await ref.read(nasNativeInstallServiceProvider.future);
      if (!_isAlive()) {
        _resetLocalBusyState();
        return;
      }
      final request = NasNativeInstallRequest.forServer(
        activeServer,
        mediaPath: _mediaPathCtrl.text.trim(),
      );
      final plan = await service.prepare(request);
      if (!_isAlive()) {
        _resetLocalBusyState();
        return;
      }
      setState(() {
        _currentPlan = plan;
        _isFormEditMode = false;
      });
    } catch (e) {
      if (!_isAlive()) {
        _resetLocalBusyState();
        return;
      }
      setState(() {
        _localError = e is NasNativeInstallException ? e.code : e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isPreparing = false);
      }
    }
  }

  Future<void> _handleExecute(NasNativeInstallPlan plan) async {
    if (!plan.canInstall || !_isAlive()) return;

    setState(() {
      _isExecuting = true;
      _localError = null;
    });

    final token = plan.confirmationToken;
    try {
      final service = await ref.read(nasNativeInstallServiceProvider.future);
      if (!_isAlive()) {
        _resetLocalBusyState();
        return;
      }
      await service.execute(token);
      if (!_isAlive()) {
        _resetLocalBusyState();
        return;
      }
      setState(() {
        _currentPlan = null;
        _isFormEditMode = false;
      });
    } catch (e) {
      if (!_isAlive()) {
        _resetLocalBusyState();
        return;
      }
      setState(() {
        _currentPlan = null;
        _localError = e is NasNativeInstallException ? e.code : e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
      }
    }
  }

  Future<void> _handleReconcile(NasNativeInstallTask task) async {
    if (!_isAlive()) return;
    final capturedTaskId = task.id;
    final capturedServerKey = task.request.serverKey;

    setState(() {
      _isReconciling = true;
      _localError = null;
    });
    try {
      final service = await ref.read(nasNativeInstallServiceProvider.future);
      if (!_isAlive()) {
        _resetLocalBusyState();
        return;
      }
      if (service.state?.id != capturedTaskId ||
          service.state?.request.serverKey != capturedServerKey) {
        _resetLocalBusyState();
        return;
      }
      await service.reconcile();
      if (!_isAlive()) {
        _resetLocalBusyState();
        return;
      }
    } catch (e) {
      if (!_isAlive()) {
        _resetLocalBusyState();
        return;
      }
      setState(() {
        _localError = e is NasNativeInstallException ? e.code : e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isReconciling = false);
      }
    }
  }

  Future<void> _handleCancelRequest(NasNativeInstallTask task) async {
    if (!_isAlive()) return;
    final capturedTaskId = task.id;
    final capturedServerKey = task.request.serverKey;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.nasNativeInstallTitle),
        content: Text(context.l10n.nasNativeCancelExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !_isAlive()) return;

    setState(() {
      _isCancelling = true;
      _localError = null;
    });

    try {
      final service = await ref.read(nasNativeInstallServiceProvider.future);
      if (!_isAlive()) {
        _resetLocalBusyState();
        return;
      }
      if (service.state?.id != capturedTaskId ||
          service.state?.request.serverKey != capturedServerKey) {
        _resetLocalBusyState();
        return;
      }
      await service.requestCancel();
      if (!_isAlive()) {
        _resetLocalBusyState();
        return;
      }
    } catch (e) {
      if (!_isAlive()) {
        _resetLocalBusyState();
        return;
      }
      setState(() {
        _localError = e is NasNativeInstallException ? e.code : e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  void _copyLog(String log) {
    if (log.isEmpty) return;
    Clipboard.setData(ClipboardData(text: log));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.appCenterLogsCopied)));
  }

  String _resolveErrorMessage(BuildContext context, String code) {
    final l10n = context.l10n;
    switch (code) {
      case 'NAS_NATIVE_PATH_INVALID':
        return l10n.nasInstallBlockerMedia;
      case 'NAS_NATIVE_TARGET_CHANGED':
        return l10n.nasInstallBlockerConnectionChanged;
      case 'NAS_NATIVE_SSH_REQUIRED':
        return l10n.nasInstallBlockerSshRequired;
      case 'NAS_NATIVE_SUDO_REQUIRED':
        return l10n.nasNativeSudoRequired;
      case 'NAS_NATIVE_TOOLS_REQUIRED':
        return l10n.nasInstallBlockerTools;
      case 'NAS_NATIVE_TASK_PENDING':
        return l10n.nasInstallBlockerBusy;
      case 'NAS_NATIVE_CONFIRMATION_INVALID':
        return l10n.nasInstallBlockerPlanStale;
      case 'NAS_NATIVE_PORT_IN_USE':
      case 'NAS_NATIVE_PORT_BUSY':
      case 'PORT_BUSY':
        return l10n.nasInstallBlockerPort;
      case 'NAS_NATIVE_UNSUPPORTED_OS':
      case 'NAS_NATIVE_OS_UNSUPPORTED':
      case 'OS_UNSUPPORTED':
      case 'NAS_NATIVE_UNSUPPORTED_ARCH':
      case 'NAS_NATIVE_NO_SYSTEMD':
        return l10n.nasNativeSupportedRequirements;
      case 'NAS_NATIVE_ALREADY_INSTALLED':
        return l10n.nasNativeExistingInstallExplanation;
      case 'NAS_NATIVE_HEALTH_TIMEOUT':
        return l10n.nasInstallBlockerHealthTimeout;
      case 'NAS_NATIVE_PREFLIGHT_IN_PROGRESS':
        return l10n.nasInstallBlockerBusy;
      default:
        return l10n.nasInstallBlockerFailed;
    }
  }

  String _resolveStepLabel(BuildContext context, String step) {
    final l10n = context.l10n;
    switch (step) {
      case 'NAS_NATIVE_VERIFY_SIGNED_REPOSITORY':
        return l10n.nasNativeStepVerifyRepo;
      case 'NAS_NATIVE_PREVENT_AUTOSTART':
        return l10n.nasNativeStepPreventAutostart;
      case 'NAS_NATIVE_INSTALL_PINNED_PACKAGES':
        return l10n.nasNativeStepInstallPackages;
      case 'NAS_NATIVE_CONFIGURE_LOOPBACK':
        return l10n.nasNativeStepConfigureLoopback;
      case 'NAS_NATIVE_VERIFY_SERVICE':
        return l10n.nasInstallStepCheckHttp;
      default:
        return step;
    }
  }

  String _resolveGuidanceLabel(BuildContext context, String guidance) {
    final l10n = context.l10n;
    switch (guidance) {
      case 'NAS_NATIVE_SETUP_REQUIRED':
      case 'SETUP_REQUIRED':
        return l10n.nasInstallGuidanceSetup;
      case 'NAS_NATIVE_LOOPBACK_ONLY':
      case 'LOOPBACK_ONLY':
        return l10n.nasInstallGuidanceTunnel;
      case 'NAS_NATIVE_MEDIA_ACCESS_UNCHANGED':
      case 'MEDIA_ACCESS_UNCHANGED':
        return l10n.nasNativeGuidanceMediaAccess;
      case 'NAS_NATIVE_NO_AUTOMATIC_UPGRADE':
      case 'NO_AUTOMATIC_UPGRADE':
        return l10n.nasNativeGuidanceNoUpgrade;
      default:
        return guidance;
    }
  }

  String _resolveStageLabel(BuildContext context, NasNativeInstallStage stage) {
    final l10n = context.l10n;
    switch (stage) {
      case NasNativeInstallStage.preflight:
        return l10n.nasInstallStagePreflight;
      case NasNativeInstallStage.review:
        return l10n.nasInstallStageReview;
      case NasNativeInstallStage.installing:
        return l10n.nasNativeStageInstalling;
      case NasNativeInstallStage.configuring:
        return l10n.nasInstallStageWriting;
      case NasNativeInstallStage.starting:
        return l10n.nasNativeStageStarting;
      case NasNativeInstallStage.health:
        return l10n.nasInstallStageHealth;
      case NasNativeInstallStage.succeeded:
        return l10n.nasInstallStageSucceeded;
      case NasNativeInstallStage.failed:
        return l10n.nasInstallStageFailed;
      case NasNativeInstallStage.cancelled:
        return l10n.nasInstallStageCancelled;
      case NasNativeInstallStage.needsInspection:
        return l10n.nasInstallStageNeedsInspection;
      case NasNativeInstallStage.reconciling:
        return l10n.nasInstallStageReconciling;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeServer = ref.watch(activeServerProvider);
    final isConnected = ref.watch(
      serverConnectionProvider.select((s) => s.isConnected),
    );
    final targetChanged = activeServer?.connectionKey != _capturedConnectionKey;
    final isTargetBlocked = targetChanged || !isConnected;

    final taskAsync = ref.watch(nasNativeInstallTaskProvider);
    final rawTask = taskAsync.asData?.value;

    // Guard: Only display task if belonging to the exact captured native key
    final task =
        (rawTask != null &&
            _capturedNativeKey != null &&
            rawTask.request.serverKey == _capturedNativeKey)
        ? rawTask
        : null;

    final plan =
        (task?.stage == NasNativeInstallStage.review ? task?.plan : null) ??
        _currentPlan;

    // Mandatory task view: active operations or required reconciliation override form edit mode
    final isMandatoryTask =
        task != null && (task.isBusy || task.requiresReconciliation);
    final isReviewState =
        !isMandatoryTask &&
        !_isFormEditMode &&
        plan != null &&
        (task == null || task.stage == NasNativeInstallStage.review);
    final isGenericTaskState =
        !isMandatoryTask &&
        !_isFormEditMode &&
        task != null &&
        task.stage != NasNativeInstallStage.review;

    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;

    Widget body;
    if (isMandatoryTask) {
      body = _buildTaskView(context, task, isTargetBlocked);
    } else if (isReviewState) {
      body = _buildPlanView(context, plan, isTargetBlocked);
    } else if (isGenericTaskState) {
      body = _buildTaskView(context, task, isTargetBlocked);
    } else {
      body = _buildInitialForm(context, activeServer, isTargetBlocked);
    }

    final content = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Target change / disconnected warning banner
          if (isTargetBlocked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(VRadius.card),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: context.colorScheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      targetChanged
                          ? l10n.nasInstallBlockerConnectionChanged
                          : l10n.nasInstallBlockerSshRequired,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Local error message
          if (_localError != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colorScheme.errorContainer.withValues(
                  alpha: 0.7,
                ),
                borderRadius: BorderRadius.circular(VRadius.card),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: context.colorScheme.error,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _resolveErrorMessage(context, _localError!),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          body,
        ],
      ),
    );

    if (isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.nasNativeInstallTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: content,
          ),
        ),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.inventory_2_outlined, color: context.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.nasNativeInstallTitle,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: l10n.nasInstallClose,
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: 560,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: content),
        ),
      ),
    );
  }

  Widget _buildInitialForm(
    BuildContext context,
    ServerProfile? server,
    bool isTargetBlocked,
  ) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Server Identity Card
        if (server != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(VRadius.card),
              border: Border.all(
                color: context.colorScheme.outlineVariant.withValues(
                  alpha: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: 20,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${server.username}@${server.host}:${server.port}',
                        style: monoTextStyle(
                          fontSize: 11,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Supported Platform Requirements Notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(VRadius.card),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.nasNativeSupportedRequirements,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Media Path Input
        TextFormField(
          controller: _mediaPathCtrl,
          enabled: !_isLocalBusy && !isTargetBlocked,
          decoration: InputDecoration(
            labelText: l10n.nasNativeMediaPathLabel,
            hintText: l10n.nasNativeMediaPathHint,
            prefixIcon: const Icon(Icons.folder_outlined),
            suffixIcon: IconButton(
              key: const Key('nas_native_browse_media_path'),
              tooltip: l10n.remoteBrowserSelectDirectory,
              onPressed: _isLocalBusy || isTargetBlocked || _isBrowsing
                  ? null
                  : _browseMediaPath,
              icon: const Icon(Icons.folder_open_outlined),
            ),
            border: const OutlineInputBorder(),
          ),
          validator: (val) {
            final text = val?.trim() ?? '';
            if (text.isEmpty) return l10n.serverFieldRequired;
            if (!text.startsWith('/') || text == '/') {
              return l10n.nasInstallBlockerMedia;
            }
            if (text.split('/').any((p) => p == '.' || p == '..')) {
              return l10n.nasInstallBlockerMedia;
            }
            return null;
          },
        ),
        const SizedBox(height: 20),

        // Submit action
        FilledButton.icon(
          onPressed: (_isLocalBusy || isTargetBlocked) ? null : _handlePrepare,
          icon: _isPreparing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
          label: Text(l10n.nasInstallPreparePlan),
        ),
      ],
    );
  }

  Widget _buildPlanView(
    BuildContext context,
    NasNativeInstallPlan plan,
    bool isTargetBlocked,
  ) {
    final l10n = context.l10n;
    final displayedBlockers = plan.existingInstall
        ? plan.blockers
              .where((b) => b != 'NAS_NATIVE_ALREADY_INSTALLED')
              .toList()
        : plan.blockers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Target Environment & Pinned Versions
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            borderRadius: BorderRadius.circular(VRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.request.serverName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${plan.os} ${plan.osVersion} (${plan.architecture})',
                style: monoTextStyle(
                  fontSize: 11,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              if (plan.packageVersions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: plan.packageVersions.entries.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.colorScheme.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(VRadius.pill),
                      ),
                      child: Text(
                        '${e.key}: ${e.value}',
                        style: monoTextStyle(
                          fontSize: 10,
                          color: context.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Existing Install Detected Warning
        if (plan.existingInstall) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(VRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: context.colorScheme.onSecondaryContainer,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.nasNativeExistingInstallTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: context.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.nasNativeExistingInstallExplanation,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Blockers (if any)
        if (displayedBlockers.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(VRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.nasInstallBlockersTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: context.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 6),
                for (final b in displayedBlockers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.block,
                          size: 14,
                          color: context.colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _resolveErrorMessage(context, b),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Steps List
        Text(
          l10n.nasInstallStageReview,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < plan.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 9,
                  backgroundColor: context.colorScheme.primary.withValues(
                    alpha: 0.15,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _resolveStepLabel(context, plan.steps[i]),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),

        // Guidance Notes
        if (plan.guidance.isNotEmpty) ...[
          Text(
            l10n.nasInstallGuidanceNotes,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: context.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          for (final g in plan.guidance)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colorScheme.outline,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _resolveGuidanceLabel(context, g),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],

        // Action Buttons
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _isLocalBusy
                  ? null
                  : () {
                      setState(() {
                        _isFormEditMode = true;
                        _currentPlan = null;
                      });
                    },
              child: Text(l10n.nasInstallBackEdit),
            ),
            if (plan.canInstall && !plan.existingInstall)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: (_isLocalBusy || isTargetBlocked)
                    ? null
                    : () => _handleExecute(plan),
                icon: _isExecuting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 16),
                label: Text(l10n.nasInstallConfirmDeploy),
              ),
          ],
        ),
        if (plan.existingInstall && _capturedServer != null) ...[
          const SizedBox(height: 12),
          JellyfinSourceActions(
            key: ValueKey('native-existing-${plan.id}'),
            server: _capturedServer!,
            endpoint: plan.endpoint,
            showSuccessSummary: false,
          ),
        ],
      ],
    );
  }

  Widget _buildTaskView(
    BuildContext context,
    NasNativeInstallTask task,
    bool isTargetBlocked,
  ) {
    final l10n = context.l10n;
    final isSuccess =
        task.stage == NasNativeInstallStage.succeeded &&
        task.result?.healthy == true;
    final isFailed = task.stage == NasNativeInstallStage.failed;
    final isCancelled = task.stage == NasNativeInstallStage.cancelled;
    final isNeedsInspection =
        task.stage == NasNativeInstallStage.needsInspection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stage status header card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSuccess
                ? context.vSuccess.withValues(alpha: 0.1)
                : isFailed
                ? context.vDanger.withValues(alpha: 0.1)
                : isNeedsInspection
                ? context.vWarning.withValues(alpha: 0.1)
                : context.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
            borderRadius: BorderRadius.circular(VRadius.card),
            border: Border.all(
              color: isSuccess
                  ? context.vSuccess.withValues(alpha: 0.4)
                  : isFailed
                  ? context.vDanger.withValues(alpha: 0.4)
                  : isNeedsInspection
                  ? context.vWarning.withValues(alpha: 0.4)
                  : context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (task.isBusy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (isSuccess)
                    Icon(Icons.check_circle, color: context.vSuccess, size: 18)
                  else if (isFailed)
                    Icon(Icons.cancel, color: context.vDanger, size: 18)
                  else if (isCancelled)
                    Icon(
                      Icons.block,
                      color: context.colorScheme.outline,
                      size: 18,
                    )
                  else
                    Icon(Icons.help_outline, color: context.vWarning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _resolveStageLabel(context, task.stage),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSuccess
                            ? context.vSuccess
                            : isFailed
                            ? context.vDanger
                            : isNeedsInspection
                            ? context.vWarning
                            : context.colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    '${task.elapsed.inSeconds}s',
                    style: monoTextStyle(
                      fontSize: 11,
                      color: context.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              if (task.isBusy) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Error code banner
        if (task.errorCode != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(VRadius.card),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: context.colorScheme.error,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _resolveErrorMessage(context, task.errorCode!),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Success endpoint banner
        if (isSuccess && task.result != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.vSuccess.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(VRadius.card),
            ),
            child: Row(
              children: [
                Icon(Icons.link, color: context.vSuccess, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: SelectableText(
                    task.result!.endpoint.toString(),
                    style: monoTextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: context.vSuccess,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (isSuccess && task.result != null && _capturedServer != null) ...[
          JellyfinSourceActions(
            key: ValueKey('native-source-${task.id}'),
            server: _capturedServer!,
            endpoint: task.result!.endpoint,
          ),
          const SizedBox(height: 12),
        ],

        // Current command
        if (task.currentCommand.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(VRadius.card),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.terminal,
                  size: 14,
                  color: context.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SelectableText(
                    task.currentCommand,
                    style: monoTextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Log tail container (bounded, selectable, copyable)
        if (task.logTail.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(VRadius.card),
              border: Border.all(
                color: context.colorScheme.outlineVariant.withValues(
                  alpha: 0.4,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.appCenterLogsTitle('Jellyfin'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: context.colorScheme.outline,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 14),
                      onPressed: () => _copyLog(task.logTail),
                      tooltip: l10n.copy,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      task.logTail,
                      style: monoTextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Task Action Buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (task.canCancel)
              OutlinedButton.icon(
                onPressed: (!isTargetBlocked && !_isLocalBusy)
                    ? () => _handleCancelRequest(task)
                    : null,
                icon: _isCancelling
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined, size: 14),
                label: Text(l10n.cancel),
              ),
            if (task.requiresReconciliation ||
                task.stage == NasNativeInstallStage.needsInspection ||
                task.stage == NasNativeInstallStage.failed) ...[
              FilledButton.tonalIcon(
                onPressed: (!isTargetBlocked && !_isLocalBusy)
                    ? () => _handleReconcile(task)
                    : null,
                icon: _isReconciling
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 14),
                label: Text(l10n.appCenterRetry),
              ),
            ],
            if (!task.isBusy && !task.requiresReconciliation)
              TextButton(
                onPressed: _isLocalBusy
                    ? null
                    : () {
                        setState(() {
                          _isFormEditMode = true;
                          _currentPlan = null;
                        });
                      },
                child: Text(l10n.nasInstallNewDeployment),
              ),
          ],
        ),
      ],
    );
  }
}
