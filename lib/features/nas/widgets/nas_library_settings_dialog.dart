import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/nas_provider.dart';
import '../../../data/models/nas_media.dart';
import '../../../data/models/nas_source.dart';
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
  bool _loadingUsage = true;
  bool _usageFailed = false;
  bool _clearingCache = false;
  bool _updatingBudget = false;
  String? _cacheError;

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
    });
    try {
      final usage = await ref.read(nasProvider.notifier).thumbnailCacheUsage();
      if (!mounted) return;
      setState(() {
        _cacheUsage = usage;
        _loadingUsage = false;
        _usageFailed = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingUsage = false;
        _usageFailed = true;
        _cacheError = context.nasSanitizedError(e);
      });
    }
  }

  Future<void> _onBudgetChanged(int newBytes) async {
    if (_updatingBudget || _clearingCache) return;
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

  Future<void> _clearThumbnailCache() async {
    if (_clearingCache || _updatingBudget) return;
    setState(() {
      _clearingCache = true;
      _cacheError = null;
    });
    try {
      await ref.read(nasProvider.notifier).clearThumbnailCache();
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
                child: Column(
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
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: RadioGroup<NasOpenPolicy>(
                        groupValue: _policy,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _policy = val;
                              _kindPolicies[_selectedKind] = val;
                            });
                            widget.onPolicyChanged(val);
                            widget.onKindPolicyChanged?.call(
                              _selectedKind,
                              val,
                            );
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
                        Navigator.pop(context);
                        NasScanConfigDialog.show(
                          context,
                          source: widget.source,
                          sourceId: widget.sourceId,
                          initialConfig: widget.scanConfig,
                          onSave: widget.onSaveScanConfig,
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
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _loadingUsage
                                        ? '...'
                                        : (_usageFailed
                                              ? '—'
                                              : '${((_cacheUsage['bytes'] ?? 0) / (1024 * 1024)).toStringAsFixed(1)} MB (${_cacheUsage['count'] ?? 0})'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _usageFailed
                                          ? theme.colorScheme.error
                                          : null,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  key: const Key(
                                    'nas_clear_thumbnail_cache_button',
                                  ),
                                  icon: _clearingCache
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                        ),
                                  label: Text(
                                    context.l10n.nasThumbnailCacheClear,
                                  ),
                                  onPressed: (_clearingCache || _updatingBudget)
                                      ? null
                                      : _clearThumbnailCache,
                                ),
                              ],
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
                            ],
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.nasThumbnailCacheBudget,
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
                                      onSelected:
                                          (_clearingCache || _updatingBudget)
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
                  ],
                ),
              ),
            ),

            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.confirm),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
