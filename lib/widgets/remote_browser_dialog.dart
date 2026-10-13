import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/design/tokens.dart';
import '../core/extensions/context_extensions.dart';
import '../data/models/remote_browser.dart';
import 'remote_browser_view.dart';

class RemoteBrowserDialog extends StatefulWidget {
  final RemoteBrowserSource source;
  final RemoteBrowserMode mode;
  final String? title;
  final String? initialPath;
  final Set<String> initialSelectedIds;

  final bool Function(RemoteBrowserEntry entry)? canSelectEntry;
  final bool Function(String path)? isPathRestricted;
  final int? maxSelectCount;
  final Set<String> allowedExtensions;

  const RemoteBrowserDialog({
    super.key,
    required this.source,
    this.mode = RemoteBrowserMode.directory,
    this.title,
    this.initialPath,
    this.initialSelectedIds = const {},
    this.canSelectEntry,
    this.isPathRestricted,
    this.maxSelectCount,
    this.allowedExtensions = const {},
  });

  static Future<RemoteBrowserSelection?> show(
    BuildContext context, {
    required RemoteBrowserSource source,
    RemoteBrowserMode mode = RemoteBrowserMode.directory,
    String? title,
    String? initialPath,
    Set<String> initialSelectedIds = const {},
    bool Function(RemoteBrowserEntry entry)? canSelectEntry,
    bool Function(String path)? isPathRestricted,
    int? maxSelectCount,
    Set<String> allowedExtensions = const {},
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showDialog<RemoteBrowserSelection>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VRadius.dialog),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = math.min(
                constraints.maxHeight,
                MediaQuery.sizeOf(context).height * 0.82,
              );
              // Keep controls reachable when the keyboard or landscape leaves
              // less room than the browser chrome needs.
              final contentHeight = math.max(
                height,
                360 + MediaQuery.textScalerOf(context).scale(160),
              );
              return SizedBox(
                key: const Key('remote_browser_dialog_surface'),
                width: 720,
                height: height,
                child: SingleChildScrollView(
                  child: SizedBox(
                    height: contentHeight,
                    child: RemoteBrowserDialog(
                      source: source,
                      mode: mode,
                      title: title,
                      initialPath: initialPath,
                      initialSelectedIds: initialSelectedIds,
                      canSelectEntry: canSelectEntry,
                      isPathRestricted: isPathRestricted,
                      maxSelectCount: maxSelectCount,
                      allowedExtensions: allowedExtensions,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static Future<String?> pickDirectory(
    BuildContext context,
    RemoteBrowserSource source, {
    String? title,
    String? initialPath,
    bool Function(RemoteBrowserEntry entry)? canSelectEntry,
    bool Function(String path)? isPathRestricted,
  }) async {
    final selection = await show(
      context,
      source: source,
      mode: RemoteBrowserMode.directory,
      title: title,
      initialPath: initialPath,
      canSelectEntry: canSelectEntry,
      isPathRestricted: isPathRestricted,
    );
    if (selection == null || selection.entries.isEmpty) return null;
    return selection.entries.first.id;
  }

  static Future<List<RemoteBrowserEntry>?> pickFiles(
    BuildContext context,
    RemoteBrowserSource source, {
    String? title,
    String? initialPath,
    bool multiSelect = false,
    bool Function(RemoteBrowserEntry entry)? canSelectEntry,
    bool Function(String path)? isPathRestricted,
    int? maxSelectCount,
    Set<String> allowedExtensions = const {},
  }) async {
    final selection = await show(
      context,
      source: source,
      mode: multiSelect
          ? RemoteBrowserMode.multipleFiles
          : RemoteBrowserMode.file,
      title: title,
      initialPath: initialPath,
      canSelectEntry: canSelectEntry,
      isPathRestricted: isPathRestricted,
      maxSelectCount: maxSelectCount,
      allowedExtensions: allowedExtensions,
    );
    return selection?.entries;
  }

  static Future<List<String>?> pickLibraries(
    BuildContext context,
    RemoteBrowserSource source, {
    String? title,
    bool multiSelect = false,
    Set<String> initialSelectedIds = const {},
    bool Function(RemoteBrowserEntry entry)? canSelectEntry,
  }) async {
    final selection = await show(
      context,
      source: source,
      mode: multiSelect
          ? RemoteBrowserMode.multipleLibraries
          : RemoteBrowserMode.mediaLibrary,
      title: title,
      initialSelectedIds: initialSelectedIds,
      canSelectEntry: canSelectEntry,
    );
    if (selection == null) return null;
    return selection.entries.map((e) => e.id).toList();
  }

  @override
  State<RemoteBrowserDialog> createState() => _RemoteBrowserDialogState();
}

class _RemoteBrowserDialogState extends State<RemoteBrowserDialog> {
  final GlobalKey<RemoteBrowserViewState> _viewKey = GlobalKey();
  String _currentPath = '/';
  List<RemoteBrowserEntry> _selected = [];
  bool _isReady = false;

  String get _effectiveCurrentPath {
    final state = _viewKey.currentState;
    return state?.currentPath ?? _currentPath;
  }

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath ?? widget.source.initialPath;
  }

  @override
  void didUpdateWidget(covariant RemoteBrowserDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _selected = [];
      _isReady = false;
      _currentPath = widget.initialPath ?? widget.source.initialPath;
    }
  }

  bool get canConfirm {
    if (!widget.source.isCurrent ||
        !_isReady ||
        !(_viewKey.currentState?.isReady ?? false)) {
      return false;
    }
    if (_selected.any(
      (entry) =>
          !entry.selectable ||
          !(_viewKey.currentState?.canSelectEntry(entry) ?? false) ||
          !(widget.canSelectEntry?.call(entry) ?? true) ||
          (widget.isPathRestricted?.call(entry.id) ?? false),
    )) {
      return false;
    }

    switch (widget.mode) {
      case RemoteBrowserMode.directory:
        if (widget.source.flat) return false;
        if (_selected.isEmpty) {
          if (!_isReady) return false;
          final path = _effectiveCurrentPath;
          if (widget.isPathRestricted != null &&
              widget.isPathRestricted!(path)) {
            return false;
          }
          return widget.canSelectEntry?.call(
                RemoteBrowserEntry(id: path, name: path, isDirectory: true),
              ) ??
              true;
        }
        return _selected.every(
          (e) =>
              e.isDirectory &&
              (widget.isPathRestricted == null ||
                  !widget.isPathRestricted!(e.id)) &&
              (widget.canSelectEntry == null || widget.canSelectEntry!(e)),
        );

      case RemoteBrowserMode.file:
        if (_selected.length != 1) return false;
        final entry = _selected.first;
        if (entry.isDirectory) return false;
        if (widget.isPathRestricted != null &&
            widget.isPathRestricted!(entry.id)) {
          return false;
        }
        if (widget.canSelectEntry != null && !widget.canSelectEntry!(entry)) {
          return false;
        }
        return true;

      case RemoteBrowserMode.multipleFiles:
        if (_selected.isEmpty) return false;
        if (widget.maxSelectCount != null &&
            _selected.length > widget.maxSelectCount!) {
          return false;
        }
        return _selected.every(
          (e) =>
              !e.isDirectory &&
              (widget.isPathRestricted == null ||
                  !widget.isPathRestricted!(e.id)) &&
              (widget.canSelectEntry == null || widget.canSelectEntry!(e)),
        );

      case RemoteBrowserMode.mediaLibrary:
        return _selected.length == 1 &&
            _selected.first.id != '/' &&
            (widget.canSelectEntry?.call(_selected.first) ?? true);

      case RemoteBrowserMode.multipleLibraries:
        return _selected.isNotEmpty &&
            (widget.maxSelectCount == null ||
                _selected.length <= widget.maxSelectCount!) &&
            _selected.every(
              (entry) =>
                  entry.id != '/' &&
                  (widget.canSelectEntry?.call(entry) ?? true),
            );
    }
  }

  void _confirm() {
    if (!canConfirm) return;

    List<RemoteBrowserEntry> finalEntries = List.of(_selected);

    if (widget.mode == RemoteBrowserMode.directory && finalEntries.isEmpty) {
      final effectivePath = _effectiveCurrentPath;
      final name = effectivePath == '/'
          ? '/'
          : effectivePath.split('/').where((s) => s.isNotEmpty).lastOrNull ??
                effectivePath;
      finalEntries = [
        RemoteBrowserEntry(
          id: effectivePath,
          name: name,
          isDirectory: true,
          canEnter: true,
        ),
      ];
    }

    if (finalEntries.isEmpty) return;

    if (widget.mode == RemoteBrowserMode.directory &&
        finalEntries.any((e) => !e.isDirectory)) {
      return;
    }

    try {
      final selection = widget.source.selection(finalEntries);
      Navigator.of(context).pop(selection);
    } catch (_) {
      Navigator.of(context).pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDirectoryMode = widget.mode == RemoteBrowserMode.directory;

    final String titleText =
        widget.title ??
        (widget.source.flat
            ? l10n.remoteBrowserLibrariesTitle
            : (isDirectoryMode
                  ? l10n.remoteBrowserSelectDirectory
                  : l10n.remoteBrowserTitle));

    final String confirmLabel;
    if (isDirectoryMode) {
      confirmLabel = _selected.isNotEmpty
          ? l10n.remoteBrowserSelectDirectory
          : l10n.remoteBrowserSelectCurrentDirectory;
    } else if (widget.mode == RemoteBrowserMode.multipleFiles ||
        widget.mode == RemoteBrowserMode.multipleLibraries) {
      confirmLabel = '${l10n.confirm} (${_selected.length})';
    } else {
      confirmLabel = l10n.confirm;
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 32 + MediaQuery.textScalerOf(context).scale(28),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titleText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.source.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(null),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RemoteBrowserView(
              key: _viewKey,
              source: widget.source,
              mode: widget.mode,
              initialPath: widget.initialPath,
              initialSelectedIds: widget.initialSelectedIds,
              canSelectEntry: widget.canSelectEntry,
              isPathRestricted: widget.isPathRestricted,
              maxSelectCount: widget.maxSelectCount,
              allowedExtensions: widget.allowedExtensions,
              onPathChanged: (path) => setState(() => _currentPath = path),
              onSelectionChanged: (entries) =>
                  setState(() => _selected = entries),
              onStatusChanged: (ready) {
                setState(() => _isReady = ready);
                if (!widget.source.isCurrent) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted &&
                        !widget.source.isCurrent &&
                        (ModalRoute.of(context)?.isCurrent ?? false) &&
                        Navigator.of(context).canPop()) {
                      Navigator.of(context).pop(null);
                    }
                  });
                }
              },
              onEntryDoubleTap:
                  widget.mode == RemoteBrowserMode.file ||
                      widget.mode == RemoteBrowserMode.multipleFiles
                  ? (entry) {
                      if (!entry.isDirectory && canConfirm) _confirm();
                    }
                  : null,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isDirectoryMode
                        ? (_selected.isNotEmpty
                              ? _selected.first.name
                              : _currentPath)
                        : (_selected.isEmpty
                              ? ''
                              : l10n.remoteBrowserSelectedCount(
                                  _selected.length,
                                )),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monoTextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: Text(l10n.cancel),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('remote_browser_confirm_button'),
                          onPressed: canConfirm ? _confirm : null,
                          child: Text(
                            confirmLabel,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
