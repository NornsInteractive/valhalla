import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/nas_provider.dart';
import '../../../core/providers/nas_sources_provider.dart';
import '../../../data/models/nas_media.dart';
import '../../../data/models/nas_source.dart';
import 'nas_localizations.dart';

class NasScanConfigDialog extends ConsumerStatefulWidget {
  final NasSource? source;
  final String? sourceId;
  final NasScanConfig initialConfig;
  final FutureOr<void> Function(NasScanConfig) onSave;

  const NasScanConfigDialog({
    super.key,
    this.source,
    this.sourceId,
    required this.initialConfig,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    NasSource? source,
    String? sourceId,
    required NasScanConfig initialConfig,
    required FutureOr<void> Function(NasScanConfig) onSave,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => NasScanConfigDialog(
        source: source,
        sourceId: sourceId,
        initialConfig: initialConfig,
        onSave: onSave,
      ),
    );
  }

  @override
  ConsumerState<NasScanConfigDialog> createState() =>
      _NasScanConfigDialogState();
}

class _NasScanConfigDialogState extends ConsumerState<NasScanConfigDialog> {
  late List<String> _includePaths;
  late List<String> _excludePaths;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final isMedia = widget.source?.isMediaServer == true;
    _includePaths = widget.initialConfig.includePaths
        .map((p) => isMedia && p.trim().toLowerCase() == 'all' ? '/' : p.trim())
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();
    _excludePaths = widget.initialConfig.excludePaths
        .map((p) => isMedia && p.trim().toLowerCase() == 'all' ? '/' : p.trim())
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _showAddPathDialog({required bool isInclude}) async {
    final isMedia = widget.source?.isMediaServer == true;
    final defaultInitial = isMedia ? '/' : '';
    final controller = TextEditingController(text: defaultInitial);

    final hint = switch (widget.source?.type) {
      NasSourceType.sftp => '/media',
      NasSourceType.webdav => 'media',
      NasSourceType.smb => '/media',
      NasSourceType.jellyfin || NasSourceType.emby => '/',
      _ => '/media',
    };

    final helper = isMedia
        ? context.nasLibraryIdHint
        : (widget.source?.type == NasSourceType.webdav
              ? context.nasScanPathRelativeHint(widget.source?.rootPath ?? '/')
              : (widget.source?.type == NasSourceType.sftp
                    ? '/media, /mnt/storage'
                    : null));

    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isInclude ? ctx.l10n.nasAddIncludePath : ctx.l10n.nasAddExcludePath,
        ),
        content: TextField(
          key: Key(
            isInclude ? 'nas_include_path_input' : 'nas_exclude_path_input',
          ),
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            labelText: isMedia ? ctx.nasLibraryId : ctx.nasRootPath,
            helperText: helper,
          ),
          autofocus: true,
          onSubmitted: (val) => Navigator.pop(ctx, val.trim()),
        ),
        actions: [
          TextButton(
            key: const Key('nas_path_cancel_button'),
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            key: Key(
              isInclude
                  ? 'nas_confirm_include_path'
                  : 'nas_confirm_exclude_path',
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(ctx.l10n.save),
          ),
        ],
      ),
    );

    if (path != null && path.trim().isNotEmpty) {
      final raw = path.trim();
      final normalized = (isMedia && raw.toLowerCase() == 'all') ? '/' : raw;
      if (normalized.isNotEmpty) {
        setState(() {
          if (isInclude) {
            if (!_includePaths.contains(normalized)) {
              _includePaths.add(normalized);
            }
          } else {
            if (!_excludePaths.contains(normalized)) {
              _excludePaths.add(normalized);
            }
          }
        });
      }
    }
  }

  void _addIncludePath() => _showAddPathDialog(isInclude: true);

  void _addExcludePath() => _showAddPathDialog(isInclude: false);

  void _removeIncludePath(String path) {
    setState(() {
      _includePaths.remove(path);
    });
  }

  void _removeExcludePath(String path) {
    setState(() {
      _excludePaths.remove(path);
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final currentSource = ref.read(nasSourcesProvider).selected;
    final currentId = currentSource?.id ?? ref.read(nasProvider).serverId;
    if (widget.sourceId != null && currentId != widget.sourceId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.nasSourceChangedError),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final isMedia = widget.source?.isMediaServer == true;
      final cleanIncludes = _includePaths
          .map(
            (p) => isMedia && p.trim().toLowerCase() == 'all' ? '/' : p.trim(),
          )
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();
      final cleanExcludes = _excludePaths
          .map(
            (p) => isMedia && p.trim().toLowerCase() == 'all' ? '/' : p.trim(),
          )
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();

      await widget.onSave(
        NasScanConfig(includePaths: cleanIncludes, excludePaths: cleanExcludes),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.nasSanitizedError(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      key: const Key('nas_scan_config_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Column(
          children: [
            // Title Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.folder_special_rounded, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.nasConfigDialogTitle,
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

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  // Include Paths Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.nasIncludePaths,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      TextButton.icon(
                        key: const Key('nas_add_include_path_button'),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(context.l10n.nasAddIncludePath),
                        onPressed: _addIncludePath,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (_includePaths.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(VRadius.input),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        context.l10n.nasNoIncludePaths,
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    )
                  else
                    ..._includePaths.map((incPath) {
                      // Sub-excluded paths under this include path
                      final nestedExcludes = _excludePaths
                          .where((exc) => exc.startsWith(incPath))
                          .toList();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(VRadius.input),
                          color: theme.colorScheme.surfaceContainerLowest,
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.folder,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(
                                        VRadius.pill,
                                      ),
                                    ),
                                    child: Text(
                                      context.l10n.nasScopeBadge,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      incPath,
                                      style: monoTextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    key: Key('delete_include_path_$incPath'),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    tooltip: context.l10n.delete,
                                    onPressed: () =>
                                        _removeIncludePath(incPath),
                                  ),
                                ],
                              ),
                            ),
                            if (nestedExcludes.isNotEmpty) ...[
                              const Divider(height: 1),
                              ...nestedExcludes.map(
                                (excPath) => Padding(
                                  padding: const EdgeInsets.only(
                                    left: 28,
                                    right: 12,
                                    top: 4,
                                    bottom: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.subdirectory_arrow_right,
                                        size: 16,
                                        color: theme.colorScheme.error,
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              theme.colorScheme.errorContainer,
                                          borderRadius: BorderRadius.circular(
                                            VRadius.pill,
                                          ),
                                        ),
                                        child: Text(
                                          context.l10n.nasExcludedBadge,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onErrorContainer,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          excPath,
                                          style: monoTextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: theme.colorScheme.error,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        key: Key(
                                          'delete_exclude_path_$excPath',
                                        ),
                                        icon: const Icon(Icons.close, size: 16),
                                        onPressed: () =>
                                            _removeExcludePath(excPath),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 16),

                  // Exclude Paths Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.nasExcludePaths,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      TextButton.icon(
                        key: const Key('nas_add_exclude_path_button'),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(context.l10n.nasAddExcludePath),
                        onPressed: _addExcludePath,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Builder(
                    builder: (context) {
                      final standaloneExcludes = _excludePaths
                          .where(
                            (exc) => !_includePaths.any(
                              (inc) => exc.startsWith(inc),
                            ),
                          )
                          .toList();

                      if (standaloneExcludes.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(VRadius.input),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            context.l10n.nasNoExcludePaths,
                            style: TextStyle(color: theme.colorScheme.outline),
                          ),
                        );
                      }

                      return Column(
                        children: standaloneExcludes.map((excPath) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(VRadius.input),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.folder_off_outlined,
                                  size: 18,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(
                                    VRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  context.l10n.nasExcludedBadge,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    excPath,
                                    style: monoTextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  key: Key(
                                    'delete_standalone_exclude_$excPath',
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  onPressed: () => _removeExcludePath(excPath),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Actions
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('nas_config_cancel_button'),
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('nas_config_save_button'),
                    onPressed: _isSaving ? null : _save,
                    child: Text(context.l10n.save),
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
