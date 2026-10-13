import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/nas_provider.dart';
import '../../../core/providers/nas_sources_provider.dart';
import '../../../data/models/nas_media.dart';
import '../../../data/models/nas_source.dart';
import '../../../infrastructure/sftp/sftp_client_service.dart';
import 'nas_downloads_sheet.dart';
import 'nas_localizations.dart';
import 'nas_scan_config_dialog.dart';

class NasLibrarySettingsDialog extends ConsumerStatefulWidget {
  final NasSource? source;
  final String? sourceId;
  final NasOpenPolicy currentPolicy;
  final ValueChanged<NasOpenPolicy> onPolicyChanged;
  final NasScanConfig scanConfig;
  final FutureOr<void> Function(NasScanConfig) onSaveScanConfig;
  final bool isScanning;
  final VoidCallback onScan;
  final VoidCallback onCancelScan;
  final Map<NasMediaKind, NasOpenPolicy>? kindPolicies;
  final void Function(NasMediaKind kind, NasOpenPolicy policy)?
  onKindPolicyChanged;

  const NasLibrarySettingsDialog({
    super.key,
    this.source,
    this.sourceId,
    required this.currentPolicy,
    required this.onPolicyChanged,
    required this.scanConfig,
    required this.onSaveScanConfig,
    required this.isScanning,
    required this.onScan,
    required this.onCancelScan,
    this.kindPolicies,
    this.onKindPolicyChanged,
  });

  static Future<void> show(
    BuildContext context, {
    NasSource? source,
    String? sourceId,
    required NasOpenPolicy currentPolicy,
    required ValueChanged<NasOpenPolicy> onPolicyChanged,
    required NasScanConfig scanConfig,
    required FutureOr<void> Function(NasScanConfig) onSaveScanConfig,
    required bool isScanning,
    required VoidCallback onScan,
    required VoidCallback onCancelScan,
    Map<NasMediaKind, NasOpenPolicy>? kindPolicies,
    void Function(NasMediaKind kind, NasOpenPolicy policy)? onKindPolicyChanged,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => NasLibrarySettingsDialog(
        source: source,
        sourceId: sourceId,
        currentPolicy: currentPolicy,
        onPolicyChanged: onPolicyChanged,
        scanConfig: scanConfig,
        onSaveScanConfig: onSaveScanConfig,
        isScanning: isScanning,
        onScan: onScan,
        onCancelScan: onCancelScan,
        kindPolicies: kindPolicies,
        onKindPolicyChanged: onKindPolicyChanged,
      ),
    );
  }

  @override
  ConsumerState<NasLibrarySettingsDialog> createState() =>
      _NasLibrarySettingsDialogState();
}

class _NasLibrarySettingsDialogState
    extends ConsumerState<NasLibrarySettingsDialog> {
  late NasOpenPolicy _policy;
  late Map<NasMediaKind, NasOpenPolicy> _kindPolicies;
  NasMediaKind _selectedKind = NasMediaKind.video;
  int _budgetBytes = 128 * 1024 * 1024;
  Map<String, int> _cacheUsage = {'bytes': 0, 'count': 0};
  Map<String, int> _legacyUsage = {'bytes': 0, 'count': 0};
  bool _loadingUsage = true;
  bool _usageFailed = false;
  bool _clearingCache = false;
  bool _updatingBudget = false;
  String? _cacheError;

  String? get _sourceId {
    final id = widget.source?.id ?? widget.sourceId;
    return id == null || id.isEmpty ? null : id;
  }

  bool _isSourceCurrent() {
    if (!mounted) return false;
    final id = _sourceId;
    if (id != null && ref.read(nasProvider).serverId != id) return false;
    final source = widget.source;
    if (source == null) return true;
    final current = ref.read(nasSourcesProvider).selected;
    return current != null &&
        jsonEncode(current.toJson()) == jsonEncode(source.toJson());
  }

  @override
  void initState() {
    super.initState();
    _policy = widget.currentPolicy;
    _kindPolicies = widget.kindPolicies != null
        ? Map.from(widget.kindPolicies!)
        : {
            NasMediaKind.video: widget.currentPolicy,
            NasMediaKind.audio: widget.currentPolicy,
            NasMediaKind.image: widget.currentPolicy,
          };
    if (widget.kindPolicies != null) {
      _policy = _kindPolicies[_selectedKind] ?? widget.currentPolicy;
    }
    _budgetBytes = ref.read(nasProvider.notifier).thumbnailCacheBudget;
    _loadCacheUsage();
  }

  Future<void> _loadCacheUsage() async {
    if (!mounted) return;
    setState(() {
      _loadingUsage = true;
      _usageFailed = false;
      _cacheError = null;
    });
    try {
      final usage = await ref
          .read(nasProvider.notifier)
          .thumbnailCacheUsageBySource();
      if (!mounted) return;
      setState(() {
        _cacheUsage = usage[_sourceId] ?? {'bytes': 0, 'count': 0};
        _legacyUsage = usage[''] ?? {'bytes': 0, 'count': 0};
        _loadingUsage = false;
        _usageFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingUsage = false;
        _usageFailed = true;
        _cacheError = context.l10n.nasOperationFailed;
      });
    }
  }

  Future<void> _onBudgetChanged(int newBytes) async {
    if (_updatingBudget || _clearingCache || !_isSourceCurrent()) return;
    final priorBudget = _budgetBytes;
    setState(() {
      _updatingBudget = true;
      _budgetBytes = newBytes;
      _cacheError = null;
    });
    try {
      await ref.read(nasProvider.notifier).setThumbnailCacheBudget(newBytes);
      if (!mounted) return;
      _loadCacheUsage();
    } catch (e) {
      if (!mounted) return;
      final errorMsg = context.nasSanitizedError(e);
      setState(() {
        _budgetBytes = priorBudget;
        _cacheError = errorMsg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingBudget = false);
      }
    }
  }

  Future<void> _clearThumbnailCache({bool legacyOnly = false}) async {
    if (_clearingCache || _updatingBudget || !_isSourceCurrent()) return;
    final sourceId = _sourceId;
    if (!legacyOnly &&
        (sourceId == null || ref.read(nasProvider).serverId != sourceId)) {
      return;
    }
    final scope = legacyOnly
        ? context.l10n.nasCacheLegacy
        : (widget.source?.name ?? sourceId!);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.nasThumbnailCacheClear),
        content: Text(ctx.l10n.nasCacheClearConfirm(scope)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        _clearingCache ||
        _updatingBudget ||
        !_isSourceCurrent()) {
      return;
    }
    if (!legacyOnly &&
        (sourceId != _sourceId || ref.read(nasProvider).serverId != sourceId)) {
      return;
    }
    setState(() {
      _clearingCache = true;
      _cacheError = null;
    });
    try {
      await ref
          .read(nasProvider.notifier)
          .clearThumbnailCache(
            sourceId: legacyOnly ? null : sourceId,
            legacyOnly: legacyOnly,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.nasThumbnailCacheCleared)),
      );
      _loadCacheUsage();
    } catch (e) {
      if (!mounted) return;
      final errorMsg = context.nasSanitizedError(e);
      setState(() => _cacheError = errorMsg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _clearingCache = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact =
        MediaQuery.sizeOf(context).width < LayoutBreakpoints.compactMax;

    if (isCompact) {
      return Dialog.fullscreen(
        key: const Key('nas_library_settings_dialog'),
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.nasLibrarySettings),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildSettingsContent(context),
                  ),
                ),
                const Divider(height: 1),
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      key: const Key('nas_library_settings_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.nasLibrarySettings,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Settings options
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildSettingsContent(context),
              ),
            ),

            const Divider(height: 1),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsContent(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(nasProvider.select((s) => s.serverId));
    if (widget.source != null) ref.watch(nasSourcesProvider);
    final isCurrent = _isSourceCurrent();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Opening Policy Section
        Text(
          context.l10n.nasOpeningPolicy,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.kindPolicies != null) ...[
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const Key('nas_kind_chip_video'),
                label: Text(context.l10n.nasTabVideos),
                selected: _selectedKind == NasMediaKind.video,
                onSelected: (sel) {
                  if (sel) {
                    setState(() {
                      _selectedKind = NasMediaKind.video;
                      _policy =
                          _kindPolicies[NasMediaKind.video] ??
                          widget.currentPolicy;
                    });
                  }
                },
              ),
              ChoiceChip(
                key: const Key('nas_kind_chip_audio'),
                label: Text(context.l10n.nasTabMusic),
                selected: _selectedKind == NasMediaKind.audio,
                onSelected: (sel) {
                  if (sel) {
                    setState(() {
                      _selectedKind = NasMediaKind.audio;
                      _policy =
                          _kindPolicies[NasMediaKind.audio] ??
                          widget.currentPolicy;
                    });
                  }
                },
              ),
              ChoiceChip(
                key: const Key('nas_kind_chip_image'),
                label: Text(context.l10n.nasTabPhotos),
                selected: _selectedKind == NasMediaKind.image,
                onSelected: (sel) {
                  if (sel) {
                    setState(() {
                      _selectedKind = NasMediaKind.image;
                      _policy =
                          _kindPolicies[NasMediaKind.image] ??
                          widget.currentPolicy;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VRadius.card),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: RadioGroup<NasOpenPolicy>(
            groupValue: _policy,
            onChanged: (val) {
              if (val != null && _isSourceCurrent()) {
                setState(() {
                  _policy = val;
                  _kindPolicies[_selectedKind] = val;
                });
                widget.onPolicyChanged(val);
                widget.onKindPolicyChanged?.call(_selectedKind, val);
              }
            },
            child: Column(
              children: [
                RadioListTile<NasOpenPolicy>(
                  dense: true,
                  key: const Key('nas_policy_in_app'),
                  title: Text(
                    context.l10n.nasOpenPolicyInApp,
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: NasOpenPolicy.inApp,
                ),
                const Divider(height: 1),
                RadioListTile<NasOpenPolicy>(
                  dense: true,
                  key: const Key('nas_policy_external'),
                  title: Text(
                    context.l10n.nasOpenPolicyExternal,
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: NasOpenPolicy.external,
                ),
                const Divider(height: 1),
                RadioListTile<NasOpenPolicy>(
                  dense: true,
                  key: const Key('nas_policy_ask'),
                  title: Text(
                    context.l10n.nasOpenPolicyAsk,
                    style: const TextStyle(fontSize: 13),
                  ),
                  value: NasOpenPolicy.askEveryTime,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Scan Directories Section
        Text(
          context.l10n.nasConfigDialogTitle,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('nas_settings_open_scan_config_button'),
          icon: const Icon(Icons.folder_open, size: 18),
          label: Text(context.l10n.nasConfigureScanDirs),
          onPressed: () {
            if (!_isSourceCurrent()) return;
            NasScanConfigDialog.show(
              context,
              source: widget.source,
              sourceId: widget.sourceId,
              initialConfig: widget.scanConfig,
              onSave: (config) async {
                if (!_isSourceCurrent()) throw StateError('NAS_SOURCE_CHANGED');
                await widget.onSaveScanConfig(config);
              },
            );
          },
        ),
        const SizedBox(height: 16),

        // Manual Scan Action
        if (widget.isScanning)
          FilledButton.icon(
            key: const Key('nas_settings_cancel_scan_button'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            icon: const Icon(Icons.stop, size: 18),
            label: Text(context.l10n.nasScanCancelled),
            onPressed: () {
              if (!_isSourceCurrent()) return;
              widget.onCancelScan();
              Navigator.pop(context);
            },
          )
        else
          FilledButton.icon(
            key: const Key('nas_settings_start_scan_button'),
            icon: const Icon(Icons.radar, size: 18),
            label: Text(context.l10n.nasNotScanned),
            onPressed: () {
              if (!_isSourceCurrent()) return;
              widget.onScan();
              Navigator.pop(context);
            },
          ),
        const SizedBox(height: 24),

        // Thumbnail Cache Section
        Text(
          context.l10n.nasThumbnailCacheUsage,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VRadius.card),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loadingUsage || _clearingCache)
                  const LinearProgressIndicator(),
                const SizedBox(height: 8),
                if (_sourceId != null)
                  _buildCacheScope(
                    widget.source?.name ?? _sourceId!,
                    _cacheUsage,
                  )
                else
                  Text(context.l10n.nasCacheNoSource),
                const Divider(height: 24),
                _buildCacheScope(
                  context.l10n.nasCacheLegacy,
                  _legacyUsage,
                  legacyOnly: true,
                ),
                if (_cacheError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _cacheError!,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  if (_usageFailed)
                    TextButton.icon(
                      key: const Key('nas_cache_usage_retry'),
                      onPressed: _loadingUsage ? null : _loadCacheUsage,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.sftpRefresh),
                    ),
                ],
                const SizedBox(height: 12),
                Text(
                  context.l10n.nasCacheGlobalBudget,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      [
                        (0, context.l10n.nasThumbnailCacheOff),
                        (64 * 1024 * 1024, '64 MiB'),
                        (128 * 1024 * 1024, '128 MiB'),
                        (256 * 1024 * 1024, '256 MiB'),
                        (512 * 1024 * 1024, '512 MiB'),
                      ].map((pair) {
                        final bytes = pair.$1;
                        final label = pair.$2;
                        return ChoiceChip(
                          key: Key('nas_cache_budget_$bytes'),
                          label: Text(
                            label,
                            style: const TextStyle(fontSize: 12),
                          ),
                          selected: _budgetBytes == bytes,
                          onSelected: (_clearingCache || _updatingBudget)
                              ? null
                              : (sel) {
                                  if (sel) _onBudgetChanged(bytes);
                                },
                        );
                      }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildOfflineUsage(),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isCurrent)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              context.l10n.nasSourceChangedError,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        AbsorbPointer(absorbing: !isCurrent, child: content),
      ],
    );
  }

  Widget _buildCacheScope(
    String title,
    Map<String, int> usage, {
    bool legacyOnly = false,
  }) {
    final sourceAvailable =
        legacyOnly ||
        (_sourceId != null &&
            ref.watch(nasProvider.select((s) => s.serverId)) == _sourceId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          _loadingUsage || _usageFailed
              ? context.l10n.agentStatusUnknown
              : '${(usage['bytes'] ?? 0) == 0 ? '0 B' : SftpFileItem.formatBytes(usage['bytes']!)} · ${context.l10n.nasItemCount(usage['count'] ?? 0)}',
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: Key(
            legacyOnly
                ? 'nas_clear_legacy_cache_button'
                : 'nas_clear_thumbnail_cache_button',
          ),
          onPressed:
              !sourceAvailable ||
                  _clearingCache ||
                  _updatingBudget ||
                  _loadingUsage ||
                  _usageFailed
              ? null
              : () => _clearThumbnailCache(legacyOnly: legacyOnly),
          icon: const Icon(Icons.delete_outline),
          label: Text(context.l10n.nasThumbnailCacheClear),
        ),
      ],
    );
  }

  Widget _buildOfflineUsage() {
    final downloads = ref.watch(nasDownloadsProvider);
    final tasks = downloads.asData?.value;
    final sourceId = _sourceId;
    final bytes = tasks
        ?.where((task) => task.item.sourceId == sourceId)
        .fold<int>(
          0,
          (sum, task) => sum + (task.received > 0 ? task.received : 0),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.nasTabDownloads, style: context.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          context.l10n.nasOfflineRecordedBytes(
            bytes == null || sourceId == null
                ? context.l10n.agentStatusUnknown
                : bytes == 0
                ? '0 B'
                : SftpFileItem.formatBytes(bytes),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.l10n.nasOfflineRecordedHint,
          style: context.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('nas_source_downloads_button'),
          onPressed: sourceId == null
              ? null
              : () => NasDownloadsSheet.show(context, sourceId: sourceId),
          icon: const Icon(Icons.download_outlined),
          label: Text(context.nasTabDownloads),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          overflowSpacing: 8,
          children: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.confirm),
            ),
          ],
        ),
      ),
    );
  }
}
