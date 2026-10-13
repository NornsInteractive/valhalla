import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/application_center_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/application_center.dart';
import '../../../widgets/valhalla_card.dart';
import 'app_center_error_resolver.dart';

class AppUninstallDialog extends ConsumerStatefulWidget {
  final ApplicationDeployment? deployment;
  final ApplicationTask? retryTask;

  const AppUninstallDialog({super.key, this.deployment, this.retryTask})
    : assert(
        (deployment != null) ^ (retryTask != null),
        'Provide exactly one of deployment or retryTask',
      );

  static Future<ApplicationTask?> show(
    BuildContext context, {
    required ApplicationDeployment deployment,
  }) {
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;
    if (isCompact) {
      return Navigator.push<ApplicationTask?>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AppUninstallDialog(deployment: deployment),
        ),
      );
    }
    return showDialog<ApplicationTask?>(
      context: context,
      builder: (_) => AppUninstallDialog(deployment: deployment),
    );
  }

  static Future<ApplicationTask?> showRetry(
    BuildContext context, {
    required ApplicationTask task,
  }) {
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;
    if (isCompact) {
      return Navigator.push<ApplicationTask?>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AppUninstallDialog(retryTask: task),
        ),
      );
    }
    return showDialog<ApplicationTask?>(
      context: context,
      builder: (_) => AppUninstallDialog(retryTask: task),
    );
  }

  @override
  ConsumerState<AppUninstallDialog> createState() => _AppUninstallDialogState();
}

class _AppUninstallDialogState extends ConsumerState<AppUninstallDialog> {
  Object? _capturedKey;
  bool _isLoading = true;
  bool _isOperating = false;
  String? _errorMessage;
  ApplicationUninstallPreview? _preview;
  int _step = 1;

  final Set<String> _selectedKeys = {};
  final Set<String> _acknowledgedRiskKeys = {};
  final TextEditingController _nameController = TextEditingController();

  bool get _isRetryMode => widget.retryTask != null;

  String get _appName =>
      _preview?.deployment.name ??
      widget.deployment?.name ??
      widget.retryTask?.name ??
      '';

  bool _isValidRetryTask(ApplicationTask task) {
    if (task.operation != ApplicationOperation.uninstall) return false;
    if (task.stage != ApplicationTaskStage.failed) return false;
    if (!task.uninstallCompleted) return false;
    final serverKey = ref.read(applicationCenterProvider.notifier).serverKey;
    if (serverKey == null || task.serverKey != serverKey) return false;
    return task.cleanupResults.any(
      (r) =>
          r.outcome != ApplicationCleanupOutcome.removed &&
          r.outcome != ApplicationCleanupOutcome.alreadyAbsent,
    );
  }

  @override
  void initState() {
    super.initState();
    _capturedKey = ref.read(activeServerProvider)?.connectionKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inspect();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _isAlive() {
    if (!mounted) return false;
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    final currentKey = ref.read(activeServerProvider)?.connectionKey;
    if (currentKey != _capturedKey) return false;
    if (!ref.read(serverConnectionProvider).isConnected) return false;
    return true;
  }

  bool _isExpired(ApplicationUninstallPreview? p) {
    if (p == null) return true;
    return DateTime.now().difference(p.createdAt).inMinutes >= 5;
  }

  void _resetLocalState({String? error}) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isOperating = false;
      _preview = null;
      _selectedKeys.clear();
      _acknowledgedRiskKeys.clear();
      _nameController.clear();
      _step = 1;
      if (error != null) {
        _errorMessage = error;
      }
    });
  }

  Future<void> _inspect() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _preview = null;
      _selectedKeys.clear();
      _acknowledgedRiskKeys.clear();
      _nameController.clear();
      _step = 1;
    });

    if (_isRetryMode && !_isValidRetryTask(widget.retryTask!)) {
      setState(() {
        _isLoading = false;
        _errorMessage = context.l10n.appCenterCleanupRetryUnavailable;
      });
      return;
    }

    try {
      final notifier = ref.read(applicationCenterProvider.notifier);
      final p = _isRetryMode
          ? await notifier.inspectCleanupRetry(
              widget.retryTask!,
              allowAdvancedCleanup: true,
            )
          : await notifier.inspectUninstall(
              widget.deployment!,
              allowAdvancedCleanup: true,
            );
      if (!mounted) return;
      if (!_isAlive()) {
        _resetLocalState();
        return;
      }
      setState(() {
        _preview = p;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!_isAlive()) {
        _resetLocalState();
        return;
      }
      final msg = e is ApplicationCenterException
          ? resolveAppCenterErrorMessage(context, e.code, e.detail)
          : (_isRetryMode
                ? context.l10n.appCenterCleanupRetryUnavailable
                : context.l10n.appCenterUninstallInspectionFailedWarning);
      _resetLocalState(error: msg);
    }
  }

  Future<void> _performUninstall() async {
    if (_isOperating) return;
    if (!_isAlive()) {
      _resetLocalState();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.appCenterErrorTargetChanged),
          backgroundColor: context.vDanger,
        ),
      );
      return;
    }

    if (_isRetryMode &&
        (_selectedKeys.isEmpty ||
            _preview == null ||
            !_isValidRetryTask(widget.retryTask!))) {
      return;
    }

    final deployment = _preview?.deployment ?? widget.deployment;
    if (deployment == null) return;

    final isSelective = _selectedKeys.isNotEmpty;
    if (isSelective) {
      if (_nameController.text != deployment.name) return;
      final risky =
          _preview?.targets.where(
            (t) =>
                _selectedKeys.contains(t.key) && t.requiresRiskAcknowledgement,
          ) ??
          const [];
      if (!risky.every((t) => _acknowledgedRiskKeys.contains(t.key))) {
        return;
      }
      if (_isExpired(_preview)) {
        _resetLocalState(error: context.l10n.appCenterErrorPlanExpired);
        return;
      }
    }

    setState(() => _isOperating = true);

    // Consume single-use preview immediately before validation/prepare
    final preview = _preview;
    _preview = null;

    try {
      final notifier = ref.read(applicationCenterProvider.notifier);
      final selection = (isSelective && preview != null)
          ? ApplicationUninstallSelection(
              previewId: preview.id,
              selectedKeys: Set.unmodifiable(_selectedKeys),
              acknowledgedRiskKeys: Set.unmodifiable(_acknowledgedRiskKeys),
              confirmationName: _nameController.text,
            )
          : null;

      final plan = await notifier.prepare(
        ApplicationOperation.uninstall,
        deployment: deployment,
        uninstallSelection: selection,
      );

      if (!mounted) return;
      if (!_isAlive()) {
        _resetLocalState();
        return;
      }

      final task = await notifier.execute(plan);
      if (!mounted) return;
      if (_isAlive()) {
        Navigator.of(context).pop(task);
      } else {
        _resetLocalState();
      }
    } catch (e) {
      if (!mounted) return;
      if (!_isAlive()) {
        _resetLocalState();
        return;
      }
      final msg = e is ApplicationCenterException
          ? resolveAppCenterErrorMessage(context, e.code, e.detail)
          : context.l10n.appCenterCleanupUnconfirmed;
      _resetLocalState(error: msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: context.vDanger),
      );
    }
  }

  Widget _buildStep1Content(BuildContext context, {required bool isBlocked}) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final cleanupDisabled =
        _preview?.inspectionError != null ||
        _errorMessage != null ||
        (_isRetryMode && !_isValidRetryTask(widget.retryTask!));
    final defaultWarning = _isRetryMode
        ? l10n.appCenterCleanupRetryUnavailable
        : l10n.appCenterUninstallInspectionFailedWarning;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_preview?.inspectionError != null || _errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(VRadius.card),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _preview?.inspectionError != null
                          ? '$defaultWarning\n${resolveAppCenterErrorMessage(context, _preview!.inspectionError!)}'
                          : (_errorMessage ?? defaultWarning),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(VRadius.card),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isRetryMode
                        ? l10n.appCenterCleanupRetryDescription
                        : l10n.appCenterUninstallDefaultPreservedHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                l10n.appCenterUninstallDirectoriesTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_preview != null && _preview!.targets.isNotEmpty) ...[
                    Text(
                      '${_selectedKeys.length}/${_preview!.targets.where((t) => t.selectable && !cleanupDisabled).length}',
                      style: monoTextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  OutlinedButton.icon(
                    key: const Key('app_uninstall_recheck_button'),
                    icon: const Icon(Icons.refresh, size: 14),
                    label: Text(l10n.appCenterRecheck),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: (_isLoading || _isOperating || isBlocked)
                        ? null
                        : _inspect,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.appCenterUninstallInspecting,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_preview == null || _preview!.targets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _isRetryMode
                    ? l10n.appCenterCleanupRetryDescription
                    : l10n.appCenterUninstallNoDirectories,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            )
          else ...[
            Builder(
              builder: (context) {
                final sortedTargets =
                    List<ApplicationCleanupTarget>.from(_preview!.targets)
                      ..sort((a, b) {
                        if (a.isDataRoot != b.isDataRoot) {
                          return a.isDataRoot ? -1 : 1;
                        }
                        return a.source.compareTo(b.source);
                      });

                final selectedParentSources = sortedTargets
                    .where(
                      (t) => t.kind == 'bind' && _selectedKeys.contains(t.key),
                    )
                    .map(
                      (t) => t.source.endsWith('/') ? t.source : '${t.source}/',
                    )
                    .toList();

                return Column(
                  children: sortedTargets.map((target) {
                    final targetPrefix = target.source.endsWith('/')
                        ? target.source
                        : '${target.source}/';
                    final isCoveredByParent =
                        target.kind == 'bind' &&
                        selectedParentSources.any(
                          (parent) =>
                              target.source.startsWith(parent) &&
                              target.source != parent &&
                              target.source !=
                                  parent.substring(0, parent.length - 1),
                        );
                    final isSelectable =
                        target.selectable &&
                        !cleanupDisabled &&
                        !isBlocked &&
                        !isCoveredByParent;
                    final isChecked = _selectedKeys.contains(target.key);
                    final displayChecked = isCoveredByParent || isChecked;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ValhallaCard(
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(VRadius.card),
                          onTap: (isSelectable && !_isOperating)
                              ? () {
                                  setState(() {
                                    if (isChecked) {
                                      _selectedKeys.remove(target.key);
                                      _acknowledgedRiskKeys.remove(target.key);
                                    } else {
                                      _selectedKeys.add(target.key);
                                      final childKeys = sortedTargets
                                          .where(
                                            (t) =>
                                                target.kind == 'bind' &&
                                                t.kind == 'bind' &&
                                                t.key != target.key &&
                                                t.source.startsWith(
                                                  targetPrefix,
                                                ),
                                          )
                                          .map((t) => t.key)
                                          .toList();
                                      for (final k in childKeys) {
                                        _selectedKeys.remove(k);
                                        _acknowledgedRiskKeys.remove(k);
                                      }
                                    }
                                  });
                                }
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: displayChecked,
                                  onChanged: (isSelectable && !_isOperating)
                                      ? (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedKeys.add(target.key);
                                              final childKeys = sortedTargets
                                                  .where(
                                                    (t) =>
                                                        target.kind == 'bind' &&
                                                        t.kind == 'bind' &&
                                                        t.key != target.key &&
                                                        t.source.startsWith(
                                                          targetPrefix,
                                                        ),
                                                  )
                                                  .map((t) => t.key)
                                                  .toList();
                                              for (final k in childKeys) {
                                                _selectedKeys.remove(k);
                                                _acknowledgedRiskKeys.remove(k);
                                              }
                                            } else {
                                              _selectedKeys.remove(target.key);
                                              _acknowledgedRiskKeys.remove(
                                                target.key,
                                              );
                                            }
                                          });
                                        }
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SelectableText(
                                        target.source,
                                        style: monoTextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isSelectable
                                              ? theme.colorScheme.onSurface
                                              : theme.colorScheme.outline,
                                        ),
                                      ),
                                      if (target.isDataRoot) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          l10n.appCenterUninstallWholeDataRootWarning,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: context.vWarning,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (target.isDataRoot)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      VRadius.pill,
                                                    ),
                                              ),
                                              child: Text(
                                                l10n.appCenterUninstallWholeDataRoot,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme
                                                      .colorScheme
                                                      .onPrimaryContainer,
                                                ),
                                              ),
                                            ),
                                          if (isCoveredByParent)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      VRadius.pill,
                                                    ),
                                              ),
                                              child: Text(
                                                l10n.appCenterUninstallCoveredByParent,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      theme.colorScheme.outline,
                                                ),
                                              ),
                                            ),
                                          if (target.readOnly)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      VRadius.pill,
                                                    ),
                                              ),
                                              child: Text(
                                                l10n.appCenterMountReadOnly,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          if (target.serviceTargets.isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      VRadius.pill,
                                                    ),
                                              ),
                                              child: Text(
                                                target.serviceTargets.join(
                                                  ', ',
                                                ),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                          for (final risk in target.risks)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: context.vWarning
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      VRadius.pill,
                                                    ),
                                              ),
                                              child: Text(
                                                _resolveRiskLabel(
                                                  context,
                                                  risk,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: context.vWarning,
                                                ),
                                              ),
                                            ),
                                          if (!target.selectable)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .errorContainer
                                                    .withValues(alpha: 0.5),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      VRadius.pill,
                                                    ),
                                              ),
                                              child: Text(
                                                resolveAppCenterErrorMessage(
                                                  context,
                                                  target.blockedReason ??
                                                      'APP_CENTER_CLEANUP_PROTECTED_PATH',
                                                ),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      theme.colorScheme.error,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep2Content(BuildContext context, {required bool isBlocked}) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final selectedTargets =
        _preview?.targets
            .where((t) => _selectedKeys.contains(t.key))
            .toList() ??
        [];
    final riskyTargets = selectedTargets
        .where((t) => t.requiresRiskAcknowledgement)
        .toList();
    final deployment = _preview?.deployment ?? widget.deployment;
    final expectedName = deployment?.name ?? _appName;
    final nameMatches = _nameController.text == expectedName;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(VRadius.card),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_rounded,
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.appCenterUninstallPermanentLossWarning,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.appCenterUninstallSelectedPathsTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(VRadius.input),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final t in selectedTargets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SelectableText(
                      t.source,
                      style: monoTextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (riskyTargets.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final rt in riskyTargets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ValhallaCard(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acknowledgedRiskKeys.contains(rt.key),
                          onChanged: (_isOperating || isBlocked)
                              ? null
                              : (val) {
                                  setState(() {
                                    if (val == true) {
                                      _acknowledgedRiskKeys.add(rt.key);
                                    } else {
                                      _acknowledgedRiskKeys.remove(rt.key);
                                    }
                                  });
                                },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                rt.source,
                                style: monoTextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.appCenterUninstallRiskAck,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                children: [
                                  for (final risk in rt.risks)
                                    Text(
                                      '• ${_resolveRiskLabel(context, risk)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: context.vWarning,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.appCenterUninstallTypeAppNameHint(expectedName),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            enabled: !_isOperating && !isBlocked,
            decoration: InputDecoration(
              hintText: expectedName,
              border: const OutlineInputBorder(),
              isDense: true,
              errorText: _nameController.text.isNotEmpty && !nameMatches
                  ? l10n.appCenterUninstallTypeAppNameHint(expectedName)
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  String _resolveRiskLabel(BuildContext context, String risk) {
    final l10n = context.l10n;
    switch (risk.toLowerCase()) {
      case 'legacy':
        return l10n.appCenterUninstallRiskLegacy;
      case 'external':
        return l10n.appCenterUninstallRiskExternal;
      case 'media':
        return l10n.appCenterUninstallRiskMedia;
      case 'system':
        return l10n.appCenterUninstallRiskSystem;
      case 'shared':
        return l10n.appCenterUninstallRiskShared;
      case 'volume':
        return l10n.appCenterUninstallRiskVolume;
      default:
        return l10n.appCenterUninstallPermanentLossWarning;
    }
  }

  List<Widget> _buildActions(BuildContext context, {required bool isBlocked}) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final retryInvalid = _isRetryMode && !_isValidRetryTask(widget.retryTask!);

    if (_step == 1) {
      final isSelective = _selectedKeys.isNotEmpty;
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        if (isSelective)
          FilledButton.icon(
            key: const Key('app_uninstall_next_button'),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(l10n.appCenterNext),
            onPressed: (_isOperating || isBlocked || retryInvalid)
                ? null
                : () => setState(() => _step = 2),
          )
        else if (!_isRetryMode)
          FilledButton(
            key: const Key('app_uninstall_submit_button'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: (_isLoading || _isOperating || isBlocked)
                ? null
                : _performUninstall,
            child: _isOperating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(l10n.appCenterUninstallKeepData),
          ),
      ];
    }

    final riskyTargets =
        _preview?.targets
            .where(
              (t) =>
                  _selectedKeys.contains(t.key) &&
                  t.requiresRiskAcknowledgement,
            )
            .toList() ??
        [];
    final deployment = _preview?.deployment ?? widget.deployment;
    final expectedName = deployment?.name ?? _appName;
    final nameMatches = _nameController.text == expectedName;
    final allRisksAcked = riskyTargets.every(
      (t) => _acknowledgedRiskKeys.contains(t.key),
    );
    final canConfirm =
        nameMatches &&
        allRisksAcked &&
        !_isOperating &&
        !isBlocked &&
        !retryInvalid &&
        (!_isRetryMode || _selectedKeys.isNotEmpty);

    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.cancel),
      ),
      TextButton.icon(
        icon: const Icon(Icons.arrow_back, size: 16),
        label: Text(l10n.appCenterBack),
        onPressed: _isOperating ? null : () => setState(() => _step = 1),
      ),
      FilledButton(
        key: const Key('app_uninstall_confirm_delete_button'),
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
        ),
        onPressed: canConfirm ? _performUninstall : null,
        child: _isOperating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _isRetryMode
                    ? l10n.appCenterCleanupRetrySelected
                    : l10n.appCenterUninstallDeleteSelected,
              ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;

    final activeServer = ref.watch(activeServerProvider);
    final isConnected = ref.watch(
      serverConnectionProvider.select((s) => s.isConnected),
    );
    final targetChanged = activeServer?.connectionKey != _capturedKey;
    final notConnected = !isConnected;
    final isBlocked = targetChanged || notConnected;

    final title = _isRetryMode
        ? l10n.appCenterCleanupRetryTitle(_appName)
        : l10n.appCenterUninstallConfirmTitle(_appName);
    final body = _step == 1
        ? _buildStep1Content(context, isBlocked: isBlocked)
        : _buildStep2Content(context, isBlocked: isBlocked);
    final actions = _buildActions(context, isBlocked: isBlocked);

    final connectionWarning = isBlocked
        ? Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(VRadius.card),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    targetChanged
                        ? l10n.appCenterErrorTargetChanged
                        : l10n.appCenterErrorNotConnected,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        : null;

    final compositeBody = connectionWarning != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              connectionWarning,
              Flexible(child: body),
            ],
          )
        : body;

    if (isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: compositeBody,
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: actions,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: 520,
        ),
        child: SizedBox(width: double.maxFinite, child: compositeBody),
      ),
      actions: actions,
    );
  }
}
