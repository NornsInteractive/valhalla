import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/application_center_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/application_center.dart';
import 'app_cached_image.dart';
import 'app_center_error_resolver.dart';
import 'app_operation_wizard_dialog.dart';
import '../../../core/services/application_compose_service.dart';

class AppDetailsDialog extends ConsumerStatefulWidget {
  final CatalogApplication application;
  final void Function(int index)? onNavigateToTab;

  const AppDetailsDialog({
    super.key,
    required this.application,
    this.onNavigateToTab,
  });

  static Future<void> show(
    BuildContext context, {
    required CatalogApplication application,
    void Function(int index)? onNavigateToTab,
  }) {
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;
    if (isCompact) {
      return Navigator.push<void>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AppDetailsDialog(
            application: application,
            onNavigateToTab: onNavigateToTab,
          ),
        ),
      );
    }
    return showDialog<void>(
      context: context,
      builder: (_) => AppDetailsDialog(
        application: application,
        onNavigateToTab: onNavigateToTab,
      ),
    );
  }

  @override
  ConsumerState<AppDetailsDialog> createState() => _AppDetailsDialogState();
}

class _AppDetailsDialogState extends ConsumerState<AppDetailsDialog> {
  ApplicationTemplate? _template;
  bool _isLoading = true;
  String? _errorMessage;
  Object? _capturedServerKey;
  bool _jellyfinSoftwareMode = false;

  @override
  void initState() {
    super.initState();
    _capturedServerKey = ref.read(activeServerProvider)?.connectionKey;
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final t = await ref
          .read(applicationCenterProvider.notifier)
          .loadTemplate(widget.application);
      if (!mounted) return;
      if (ref.read(activeServerProvider)?.connectionKey != _capturedServerKey) {
        setState(() {
          _errorMessage = context.l10n.appCenterErrorTargetChanged;
        });
        return;
      }
      setState(() {
        _template = t;
      });
    } catch (e) {
      if (!mounted) return;
      if (ref.read(activeServerProvider)?.connectionKey != _capturedServerKey) {
        setState(() {
          _errorMessage = context.l10n.appCenterErrorTargetChanged;
        });
        return;
      }
      setState(() {
        _errorMessage = e is ApplicationCenterException
            ? resolveAppCenterErrorMessage(context, e.code, e.detail)
            : e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onInstallTapped() {
    if (!mounted) return;
    final currentKey = ref.read(activeServerProvider)?.connectionKey;
    if (currentKey != _capturedServerKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.appCenterErrorTargetChanged),
          backgroundColor: context.vDanger,
        ),
      );
      return;
    }

    Navigator.pop(context);
    AppOperationWizardDialog.show(
      context,
      operation: ApplicationOperation.install,
      catalogApp: widget.application,
      initialTemplate: _template,
      initialJellyfinSoftwareMode: _jellyfinSoftwareMode,
      onNavigateToTab: widget.onNavigateToTab,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final app = widget.application;
    final state = ref.watch(applicationCenterProvider);
    final isConnected = ref.watch(
      serverConnectionProvider.select((s) => s.isConnected),
    );
    final env = state.environment;
    final activeServer = ref.watch(activeServerProvider);
    final targetChanged = activeServer?.connectionKey != _capturedServerKey;

    final isInstalled = state.deployments.any(
      (d) => d.sourceId == app.sourceId && d.appId == app.id,
    );
    final archSupported =
        env == null ||
        app.architectures.isEmpty ||
        app.architectures.contains(env.architecture);

    final isJellyfinEligible = _template != null &&
        ApplicationComposeService.supportsJellyfinSoftwareMode(_template!);

    ApplicationTemplate? reducedTemplate;
    String? jellyfinProfileError;
    if (isJellyfinEligible) {
      try {
        reducedTemplate =
            ApplicationComposeService.jellyfinSoftwareTemplate(_template!);
      } on ApplicationCenterException catch (e) {
        jellyfinProfileError = e.code;
      } catch (_) {
        jellyfinProfileError = 'APP_CENTER_JELLYFIN_PROFILE_UNAVAILABLE';
      }
    }

    final description = _template?.description ?? app.summary;
    final screenshots = _template?.screenshots ?? const [];
    final effectiveTemplate =
        (_jellyfinSoftwareMode && reducedTemplate != null)
            ? reducedTemplate
            : _template;
    final blockers = effectiveTemplate?.blockers ?? const [];
    final hasBlockers = blockers.isNotEmpty ||
        !archSupported ||
        (_jellyfinSoftwareMode && reducedTemplate == null);
    final versionStr = app.version.isNotEmpty
        ? app.version
        : l10n.appCenterVersionLatest;

    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;

    final header = Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(VRadius.input),
          child: SizedBox(
            width: 44,
            height: 44,
            child: AppCachedImage(
              url: app.iconUrl,
              revision: app.contentHash,
              sourceId: app.sourceId,
              fit: BoxFit.cover,
              errorWidget: const Icon(Icons.apps, size: 32),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${app.category} · v$versionStr',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final body = _isLoading
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCompact) ...[header, const SizedBox(height: 16)],
                if (targetChanged) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(VRadius.card),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: context.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.appCenterErrorTargetChanged,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_errorMessage != null && !targetChanged) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(VRadius.card),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: context.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 16),
                          onPressed: _loadTemplate,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (app.summary.isNotEmpty) ...[
                  Text(app.summary, style: context.textTheme.bodyMedium),
                  const SizedBox(height: 12),
                ],
                if (!archSupported) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(VRadius.card),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: context.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.appCenterArchitectureBlocker,
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
                if (isJellyfinEligible) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(VRadius.card),
                      border: Border.all(
                        color: _jellyfinSoftwareMode
                            ? context.colorScheme.primary.withValues(alpha: 0.5)
                            : context.colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _jellyfinSoftwareMode = !_jellyfinSoftwareMode;
                            });
                          },
                          borderRadius: BorderRadius.circular(VRadius.input),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _jellyfinSoftwareMode,
                                onChanged: (v) {
                                  setState(() {
                                    _jellyfinSoftwareMode = v ?? false;
                                  });
                                },
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  l10n.appCenterJellyfinSoftwareTitle,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 44, end: 8, bottom: 4),
                          child: Text(
                            l10n.appCenterJellyfinSoftwareDesc,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (jellyfinProfileError != null) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 44, end: 8),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, size: 14, color: context.vDanger),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    l10n.appCenterJellyfinProfileUnavailable,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.vDanger,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_jellyfinSoftwareMode && reducedTemplate != null) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 44, end: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.appCenterJellyfinSoftwareChanges,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                for (final item in _deriveJellyfinDiff(_template!, reducedTemplate))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '• ',
                                          style: TextStyle(
                                            color: context.colorScheme.primary,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item,
                                            style: monoTextStyle(
                                              fontSize: 10,
                                              color: context.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (blockers.isNotEmpty) ...[
                  ...blockers.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 14, color: context.vDanger),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              resolveAppCenterBlockerMessage(context, b),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.vDanger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (screenshots.isNotEmpty) ...[
                  Text(
                    l10n.appCenterScreenshots,
                    style: context.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: screenshots.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(VRadius.card),
                          child: AppCachedImage(
                            url: screenshots[idx],
                            sourceId: app.sourceId,
                            fit: BoxFit.cover,
                            errorWidget: const SizedBox.shrink(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  l10n.appCenterDescription,
                  style: context.textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(description, style: context.textTheme.bodySmall),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (app.architectures.isNotEmpty)
                      ...app.architectures.map(
                        (arch) => Chip(
                          label: Text(arch),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );

    final actions = <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.cancel),
      ),
      FilledButton.icon(
        icon: Icon(isInstalled ? Icons.check : Icons.download),
        label: Text(
          isInstalled ? l10n.appCenterInstalledBadge : l10n.appCenterInstall,
        ),
        onPressed:
            (!isConnected ||
                state.busy ||
                hasBlockers ||
                targetChanged ||
                _isLoading)
            ? null
            : _onInstallTapped,
      ),
    ];

    if (isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(app.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(padding: const EdgeInsets.all(16), child: body),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: actions,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: header,
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: 520,
        ),
        child: SizedBox(width: double.maxFinite, child: body),
      ),
      actions: actions,
    );
  }

  bool _deepEquals(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) {
          return false;
        }
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  String _formatVolume(dynamic v) {
    if (v is String) return v;
    if (v is Map) {
      final src = v['source']?.toString() ?? '';
      final tgt = v['target']?.toString() ?? '';
      final ro = v['read_only'] == true ? ':ro' : '';
      if (src.isNotEmpty && tgt.isNotEmpty) {
        return '$src:$tgt$ro';
      }
      return jsonEncode(v);
    }
    return v.toString();
  }

  List<String> _deriveJellyfinDiff(
    ApplicationTemplate original,
    ApplicationTemplate reduced,
  ) {
    final diff = <String>[];
    final origServices = (original.compose['services'] as Map?) ?? const {};
    final redServices = (reduced.compose['services'] as Map?) ?? const {};
    for (final entry in origServices.entries) {
      final oSvc = entry.value as Map?;
      final rSvc = redServices[entry.key] as Map?;
      if (oSvc != null) {
        final oDevices = (oSvc['devices'] as List?) ?? const [];
        final rDevices = (rSvc?['devices'] as List?) ?? const [];
        for (final dev in oDevices) {
          if (!rDevices.any((r) => _deepEquals(dev, r))) {
            diff.add('- device: $dev');
          }
        }
        for (final dev in rDevices) {
          if (!oDevices.any((o) => _deepEquals(dev, o))) {
            diff.add('+ device: $dev');
          }
        }

        final oVolumes = (oSvc['volumes'] as List?) ?? const [];
        final rVolumes = (rSvc?['volumes'] as List?) ?? const [];
        for (final oVol in oVolumes) {
          if (!rVolumes.any((r) => _deepEquals(oVol, r))) {
            diff.add('- volume: ${_formatVolume(oVol)}');
          }
        }
        for (final rVol in rVolumes) {
          if (!oVolumes.any((o) => _deepEquals(rVol, o))) {
            diff.add('+ volume: ${_formatVolume(rVol)}');
          }
        }
      }
    }
    return diff;
  }
}
