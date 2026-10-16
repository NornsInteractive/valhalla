import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/design/tokens.dart';
import '../core/extensions/context_extensions.dart';
import '../data/models/remote_file_toolbar_action.dart';

export '../data/models/remote_file_toolbar_action.dart'
    show RemotePathDisplayMode;

/// Controlled browser chrome shared by the file page and read-only pickers.
class RemoteBrowserBreadcrumb extends StatefulWidget {
  const RemoteBrowserBreadcrumb({
    super.key,
    required this.path,
    this.rootPath = '/',
    this.mode = RemotePathDisplayMode.scroll,
    this.onModeChanged,
    this.onNavigate,
    this.onUp,
    this.trailing,
    this.scrollController,
    this.keyPrefix = 'remote_browser',
  });

  final String path;
  final String rootPath;
  final RemotePathDisplayMode mode;
  final ValueChanged<RemotePathDisplayMode>? onModeChanged;
  final ValueChanged<String>? onNavigate;
  final VoidCallback? onUp;
  final Widget? trailing;
  final ScrollController? scrollController;
  final String keyPrefix;

  @override
  State<RemoteBrowserBreadcrumb> createState() =>
      _RemoteBrowserBreadcrumbState();
}

class _RemoteBrowserBreadcrumbState extends State<RemoteBrowserBreadcrumb> {
  final _ownedController = ScrollController();
  ScrollController get _controller =>
      widget.scrollController ?? _ownedController;

  @override
  void initState() {
    super.initState();
    _revealTail();
  }

  @override
  void didUpdateWidget(covariant RemoteBrowserBreadcrumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.rootPath != widget.rootPath ||
        oldWidget.mode != widget.mode ||
        oldWidget.scrollController != widget.scrollController) {
      _revealTail();
    }
  }

  void _revealTail() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.hasClients) {
        _controller.jumpTo(_controller.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _ownedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final root = p.posix.normalize(widget.rootPath);
    final relative = p.posix.relative(widget.path, from: root);
    final segments = relative == '.' ? <String>[] : p.posix.split(relative);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            IconButton(
              key: Key(
                widget.keyPrefix == 'sftp'
                    ? 'sftp_breadcrumb_up'
                    : '${widget.keyPrefix}_up_button',
              ),
              icon: const Icon(Icons.arrow_upward, size: 18),
              tooltip: context.l10n.sftpUpDirectory,
              onPressed: widget.onUp,
            ),
            _segment(
              context,
              root,
              root,
              widget.path == root,
              Key('${widget.keyPrefix}_breadcrumb_root'),
              maxWidth: 80,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScaler = MediaQuery.textScalerOf(context);
                  double estimateSegmentWidth(String text) {
                    final scaledCharWidth = textScaler.scale(8.5);
                    return (text.length * scaledCharWidth).clamp(24.0, 120.0) +
                        20.0;
                  }

                  final totalEstimatedWidth = segments.fold<double>(
                    0.0,
                    (sum, s) => sum + estimateSegmentWidth(s),
                  );

                  final shouldCollapse =
                      widget.mode == RemotePathDisplayMode.collapsed &&
                      segments.length > 2 &&
                      constraints.maxWidth.isFinite &&
                      totalEstimatedWidth > constraints.maxWidth;

                  return SingleChildScrollView(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!shouldCollapse) ...[
                          for (var i = 0; i < segments.length; i++) ...[
                            Icon(
                              Icons.chevron_right,
                              size: 10,
                              color: context.colorScheme.outline,
                            ),
                            _segment(
                              context,
                              segments[i],
                              p.posix.joinAll([root, ...segments.take(i + 1)]),
                              i == segments.length - 1,
                              Key('${widget.keyPrefix}_breadcrumb_seg_$i'),
                            ),
                          ],
                        ] else ...[
                          Icon(
                            Icons.chevron_right,
                            size: 10,
                            color: context.colorScheme.outline,
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 44,
                              minWidth: 32,
                            ),
                            child: PopupMenuButton<String>(
                              key: Key(
                                '${widget.keyPrefix}_breadcrumb_collapsed',
                              ),
                              tooltip: context.l10n.sftpUpDirectory,
                              icon: const Icon(Icons.more_horiz, size: 16),
                              padding: EdgeInsets.zero,
                              onSelected: widget.onNavigate == null
                                  ? null
                                  : (target) => widget.onNavigate!(target),
                              itemBuilder: (context) => [
                                for (var i = 0; i < segments.length - 1; i++)
                                  PopupMenuItem<String>(
                                    key: Key(
                                      '${widget.keyPrefix}_breadcrumb_seg_$i',
                                    ),
                                    value: p.posix.joinAll([
                                      root,
                                      ...segments.take(i + 1),
                                    ]),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.folder_outlined,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Tooltip(
                                            message: segments[i],
                                            child: Text(
                                              segments[i],
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: monoTextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 10,
                            color: context.colorScheme.outline,
                          ),
                          _segment(
                            context,
                            segments.last,
                            p.posix.joinAll([root, ...segments]),
                            true,
                            Key(
                              '${widget.keyPrefix}_breadcrumb_seg_${segments.length - 1}',
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            if (widget.onModeChanged != null)
              PopupMenuButton<RemotePathDisplayMode>(
                key: Key('${widget.keyPrefix}_path_mode_button'),
                tooltip: context.l10n.remoteBrowserPathDisplayMode,
                icon: Icon(
                  widget.mode == RemotePathDisplayMode.collapsed
                      ? Icons.unfold_less
                      : Icons.unfold_more,
                  size: 18,
                ),
                initialValue: widget.mode,
                onSelected: widget.onModeChanged,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: RemotePathDisplayMode.scroll,
                    child: Row(
                      children: [
                        Icon(
                          widget.mode == RemotePathDisplayMode.scroll
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: widget.mode == RemotePathDisplayMode.scroll
                              ? context.colorScheme.primary
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.remoteBrowserPathDisplayModeScroll,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: RemotePathDisplayMode.collapsed,
                    child: Row(
                      children: [
                        Icon(
                          widget.mode == RemotePathDisplayMode.collapsed
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: widget.mode == RemotePathDisplayMode.collapsed
                              ? context.colorScheme.primary
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.remoteBrowserPathDisplayModeCollapsed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ?widget.trailing,
          ],
        ),
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    String label,
    String target,
    bool current,
    Key key, {
    double maxWidth = 120,
  }) {
    return Tooltip(
      message: target,
      child: InkWell(
        key: key,
        onTap: widget.onNavigate == null
            ? null
            : () => widget.onNavigate!(target),
        borderRadius: BorderRadius.circular(VRadius.button),
        child: Container(
          constraints: BoxConstraints(
            minHeight: 44,
            minWidth: 24,
            maxWidth: maxWidth,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: monoTextStyle(
                fontSize: 12,
                fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                color: current
                    ? context.colorScheme.onSurface
                    : widget.onNavigate != null
                    ? context.colorScheme.primary
                    : context.colorScheme.outline,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RemoteBrowserToolbar extends StatelessWidget {
  const RemoteBrowserToolbar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.showHidden,
    required this.onToggleHidden,
    required this.sortField,
    required this.sortAscending,
    required this.onSort,
    required this.isGrid,
    required this.onToggleView,
    this.viewTooltip,
    this.viewIcon,
    this.onUpload,
    this.onNewFile,
    this.onNewFolder,
    this.onSelectMode,
    this.onBookmarks,
    this.onRefresh,
    this.transferAction,
    this.isPicker = false,
    this.leadingActions = const [],
    this.trailingActions = const [],
    this.keyPrefix = 'remote_browser',
    this.searchHint,
    this.pinnedActions = defaultRemoteFileToolbarActions,
    this.onConfigureToolbar,
    this.onTransfers,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final bool showHidden;
  final VoidCallback? onToggleHidden;
  final String sortField;
  final bool sortAscending;
  final void Function(String, bool) onSort;
  final bool isGrid;
  final VoidCallback? onToggleView;
  final String? viewTooltip;
  final IconData? viewIcon;
  final VoidCallback? onUpload;
  final VoidCallback? onNewFile;
  final VoidCallback? onNewFolder;
  final VoidCallback? onSelectMode;
  final VoidCallback? onBookmarks;
  final VoidCallback? onRefresh;
  final Widget? transferAction;
  final bool isPicker;
  final List<Widget> leadingActions;
  final List<Widget> trailingActions;
  final String keyPrefix;
  final String? searchHint;
  final Iterable<RemoteFileToolbarAction> pinnedActions;
  final VoidCallback? onConfigureToolbar;
  final VoidCallback? onTransfers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fields = {
      'name': l10n.sftpSortName,
      'size': l10n.sftpSortSize,
      'date': l10n.sftpSortDate,
    };
    final pinnedSet = pinnedActions.toSet();
    final sortedPinned = RemoteFileToolbarAction.values
        .where((a) => pinnedSet.contains(a))
        .toList();
    final unpinned = RemoteFileToolbarAction.values
        .where((a) => !pinnedSet.contains(a))
        .toList();

    return ColoredBox(
      color: context.colorScheme.surfaceContainerLowest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: TextField(
              key: Key(
                keyPrefix == 'sftp'
                    ? 'sftp_search_field'
                    : '${keyPrefix}_search',
              ),
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: searchHint ?? l10n.sftpSearchHint,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).deleteButtonTooltip,
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(VRadius.input),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: context.colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          if (isPicker)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...leadingActions,
                  IconButton(
                    key: Key(
                      keyPrefix == 'sftp'
                          ? 'sftpToggleHiddenButton'
                          : '${keyPrefix}_hidden',
                    ),
                    isSelected: showHidden,
                    icon: const Icon(Icons.visibility_off, size: 20),
                    selectedIcon: const Icon(Icons.visibility, size: 20),
                    tooltip: showHidden
                        ? l10n.sftpHideHiddenFiles
                        : l10n.sftpShowHiddenFiles,
                    onPressed: onToggleHidden,
                  ),
                  IconButton(
                    key: Key(
                      keyPrefix == 'sftp'
                          ? 'sftpToggleViewModeButton'
                          : '${keyPrefix}_view',
                    ),
                    icon: Icon(
                      viewIcon ?? (isGrid ? Icons.view_list : Icons.grid_view),
                      size: 20,
                    ),
                    tooltip:
                        viewTooltip ??
                        (isGrid
                            ? l10n.sftpViewModeList
                            : l10n.sftpViewModeGrid),
                    onPressed: onToggleView,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.sort, size: 20),
                    tooltip: l10n.sftpSort,
                    onSelected: (value) {
                      if (value == 'asc' || value == 'desc') {
                        onSort(sortField, value == 'asc');
                      } else {
                        onSort(
                          value,
                          value == sortField ? !sortAscending : sortAscending,
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      for (final field in fields.entries)
                        CheckedPopupMenuItem(
                          value: field.key,
                          checked: sortField == field.key,
                          child: Text(field.value),
                        ),
                      const PopupMenuDivider(),
                      CheckedPopupMenuItem(
                        value: 'asc',
                        checked: sortAscending,
                        child: Text(l10n.sftpSortAscending),
                      ),
                      CheckedPopupMenuItem(
                        value: 'desc',
                        checked: !sortAscending,
                        child: Text(l10n.sftpSortDescending),
                      ),
                    ],
                  ),
                  ...trailingActions,
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Row(
                children: [
                  ...leadingActions,
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final action in sortedPinned)
                            _buildPinnedAction(context, action, l10n, fields),
                        ],
                      ),
                    ),
                  ),
                  _buildMoreButton(context, l10n, fields, unpinned),
                  ...trailingActions,
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPinnedAction(
    BuildContext context,
    RemoteFileToolbarAction action,
    dynamic l10n,
    Map<String, String> fields,
  ) {
    switch (action) {
      case RemoteFileToolbarAction.upload:
        return IconButton(
          key: Key(
            keyPrefix == 'sftp'
                ? 'sftpUploadButton'
                : '${keyPrefix}_upload',
          ),
          icon: const Icon(Icons.upload_file, size: 20),
          tooltip: l10n.sftpUpload,
          onPressed: onUpload,
        );
      case RemoteFileToolbarAction.create:
        return PopupMenuButton<String>(
          key: Key(
            keyPrefix == 'sftp'
                ? 'sftpNewButton'
                : '${keyPrefix}_new',
          ),
          icon: const Icon(Icons.add, size: 20),
          tooltip: l10n.sftpNew,
          enabled: onNewFile != null || onNewFolder != null,
          onSelected: (value) {
            if (value == 'folder') {
              onNewFolder?.call();
            } else if (value == 'file') {
              onNewFile?.call();
            }
          },
          itemBuilder: (context) => [
            if (onNewFolder != null)
              PopupMenuItem<String>(
                key: Key(
                  keyPrefix == 'sftp'
                      ? 'sftpNewFolderButton'
                      : '${keyPrefix}_new_folder',
                ),
                value: 'folder',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.create_new_folder_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Tooltip(
                        message: l10n.sftpNewFolder,
                        child: Text(
                          l10n.sftpNewFolder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (onNewFile != null)
              PopupMenuItem<String>(
                key: Key(
                  keyPrefix == 'sftp'
                      ? 'sftpNewFileButton'
                      : '${keyPrefix}_new_file',
                ),
                value: 'file',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.note_add_outlined, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Tooltip(
                        message: l10n.sftpNewFile,
                        child: Text(
                          l10n.sftpNewFile,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case RemoteFileToolbarAction.view:
        return IconButton(
          key: Key(
            keyPrefix == 'sftp'
                ? 'sftpToggleViewModeButton'
                : '${keyPrefix}_view',
          ),
          icon: Icon(
            viewIcon ?? (isGrid ? Icons.view_list : Icons.grid_view),
            size: 20,
          ),
          tooltip:
              viewTooltip ??
              (isGrid
                  ? l10n.sftpViewModeList
                  : l10n.sftpViewModeGrid),
          onPressed: onToggleView,
        );
      case RemoteFileToolbarAction.transfers:
        if (transferAction != null) {
          return transferAction!;
        }
        return IconButton(
          key: Key(
            keyPrefix == 'sftp'
                ? 'sftpTransferListButton'
                : '${keyPrefix}_transfers',
          ),
          icon: const Icon(Icons.swap_vert, size: 20),
          tooltip: l10n.transferList,
          onPressed: onTransfers,
        );
      case RemoteFileToolbarAction.hidden:
        return IconButton(
          key: Key(
            keyPrefix == 'sftp'
                ? 'sftpToggleHiddenButton'
                : '${keyPrefix}_hidden',
          ),
          isSelected: showHidden,
          icon: Icon(
            showHidden ? Icons.visibility_off : Icons.visibility,
            size: 20,
          ),
          tooltip: showHidden
              ? l10n.sftpHideHiddenFiles
              : l10n.sftpShowHiddenFiles,
          onPressed: onToggleHidden,
        );
      case RemoteFileToolbarAction.sort:
        return PopupMenuButton<String>(
          key: Key(
            keyPrefix == 'sftp' ? 'sftpSortButton' : '${keyPrefix}_sort',
          ),
          icon: const Icon(Icons.sort, size: 20),
          tooltip: l10n.sftpSort,
          onSelected: (value) {
            if (value == 'asc' || value == 'desc') {
              onSort(sortField, value == 'asc');
            } else {
              onSort(
                value,
                value == sortField ? !sortAscending : sortAscending,
              );
            }
          },
          itemBuilder: (context) => [
            for (final field in fields.entries)
              CheckedPopupMenuItem<String>(
                value: field.key,
                checked: sortField == field.key,
                child: Text(field.value),
              ),
            const PopupMenuDivider(),
            CheckedPopupMenuItem<String>(
              value: 'asc',
              checked: sortAscending,
              child: Text(l10n.sftpSortAscending),
            ),
            CheckedPopupMenuItem<String>(
              value: 'desc',
              checked: !sortAscending,
              child: Text(l10n.sftpSortDescending),
            ),
          ],
        );
      case RemoteFileToolbarAction.selection:
        return IconButton(
          key: Key(
            keyPrefix == 'sftp'
                ? 'sftpSelectModeButton'
                : '${keyPrefix}_select',
          ),
          icon: const Icon(Icons.checklist, size: 20),
          tooltip: l10n.sftpSelectMode,
          onPressed: onSelectMode,
        );
      case RemoteFileToolbarAction.bookmarks:
        return IconButton(
          key: Key(
            keyPrefix == 'sftp'
                ? 'sftpBookmarksListButton'
                : '${keyPrefix}_bookmarks',
          ),
          icon: const Icon(Icons.bookmarks_outlined, size: 20),
          tooltip: l10n.sftpBookmarksTitle,
          onPressed: onBookmarks,
        );
      case RemoteFileToolbarAction.refresh:
        return IconButton(
          key: Key(
            keyPrefix == 'sftp'
                ? 'sftpRefreshButton'
                : '${keyPrefix}_refresh',
          ),
          icon: const Icon(Icons.refresh, size: 20),
          tooltip: l10n.sftpRefresh,
          onPressed: onRefresh,
        );
    }
  }

  Widget _buildMoreButton(
    BuildContext context,
    dynamic l10n,
    Map<String, String> fields,
    List<RemoteFileToolbarAction> unpinned,
  ) {
    return PopupMenuButton<String>(
      key: Key(
        keyPrefix == 'sftp'
            ? 'sftpMoreButton'
            : '${keyPrefix}_more',
      ),
      icon: const Icon(Icons.more_vert, size: 20),
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      onOpened: () {
        FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
        FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.scope);
      },
      onCanceled: () {
        FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
        FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.scope);
      },
      onSelected: (value) {
        FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
        FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.scope);
        switch (value) {
          case 'upload':
            onUpload?.call();
          case 'folder':
            onNewFolder?.call();
          case 'file':
            onNewFile?.call();
          case 'view':
            onToggleView?.call();
          case 'transfers':
            onTransfers?.call();
          case 'hidden':
            onToggleHidden?.call();
          case 'asc':
            onSort(sortField, true);
          case 'desc':
            onSort(sortField, false);
          case 'name':
          case 'size':
          case 'date':
            onSort(
              value,
              value == sortField ? !sortAscending : sortAscending,
            );
          case 'select_mode':
            onSelectMode?.call();
          case 'bookmarks':
            onBookmarks?.call();
          case 'refresh':
            onRefresh?.call();
          case 'configure_toolbar':
            onConfigureToolbar?.call();
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<String>>[];
        void addDivider() {
          if (items.isNotEmpty && items.last is! PopupMenuDivider) {
            items.add(const PopupMenuDivider());
          }
        }

        for (final action in unpinned) {
          switch (action) {
            case RemoteFileToolbarAction.upload:
              items.add(
                PopupMenuItem<String>(
                  key: Key(
                    keyPrefix == 'sftp'
                        ? 'sftpUploadButton'
                        : '${keyPrefix}_upload',
                  ),
                  value: 'upload',
                  enabled: onUpload != null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.upload_file, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Tooltip(
                          message: l10n.sftpUpload,
                          child: Text(
                            l10n.sftpUpload,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            case RemoteFileToolbarAction.create:
              if (onNewFolder != null) {
                items.add(
                  PopupMenuItem<String>(
                    key: Key(
                      keyPrefix == 'sftp'
                          ? 'sftpNewFolderButton'
                          : '${keyPrefix}_new_folder',
                    ),
                    value: 'folder',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.create_new_folder_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Tooltip(
                            message: l10n.sftpNewFolder,
                            child: Text(
                              l10n.sftpNewFolder,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (onNewFile != null) {
                items.add(
                  PopupMenuItem<String>(
                    key: Key(
                      keyPrefix == 'sftp'
                          ? 'sftpNewFileButton'
                          : '${keyPrefix}_new_file',
                    ),
                    value: 'file',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.note_add_outlined, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Tooltip(
                            message: l10n.sftpNewFile,
                            child: Text(
                              l10n.sftpNewFile,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (onNewFolder == null && onNewFile == null) {
                items.add(
                  PopupMenuItem<String>(
                    key: Key(
                      keyPrefix == 'sftp'
                          ? 'sftpNewButton'
                          : '${keyPrefix}_new',
                    ),
                    value: 'new',
                    enabled: false,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Tooltip(
                            message: l10n.sftpNew,
                            child: Text(
                              l10n.sftpNew,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            case RemoteFileToolbarAction.view:
              items.add(
                PopupMenuItem<String>(
                  key: Key(
                    keyPrefix == 'sftp'
                        ? 'sftpToggleViewModeButton'
                        : '${keyPrefix}_view',
                  ),
                  value: 'view',
                  enabled: onToggleView != null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        viewIcon ??
                            (isGrid ? Icons.view_list : Icons.grid_view),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Tooltip(
                          message: viewTooltip ??
                              (isGrid
                                  ? l10n.sftpViewModeList
                                  : l10n.sftpViewModeGrid),
                          child: Text(
                            viewTooltip ??
                                (isGrid
                                    ? l10n.sftpViewModeList
                                    : l10n.sftpViewModeGrid),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            case RemoteFileToolbarAction.transfers:
              items.add(
                PopupMenuItem<String>(
                  key: Key(
                    keyPrefix == 'sftp'
                        ? 'sftpTransferListButton'
                        : '${keyPrefix}_transfers',
                  ),
                  value: 'transfers',
                  enabled: onTransfers != null || transferAction != null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_vert, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Tooltip(
                          message: l10n.transferList,
                          child: Text(
                            l10n.transferList,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            case RemoteFileToolbarAction.hidden:
              items.add(
                PopupMenuItem<String>(
                  key: Key(
                    keyPrefix == 'sftp'
                        ? 'sftpToggleHiddenButton'
                        : '${keyPrefix}_hidden',
                  ),
                  value: 'hidden',
                  enabled: onToggleHidden != null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showHidden
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Tooltip(
                          message: showHidden
                              ? l10n.sftpHideHiddenFiles
                              : l10n.sftpShowHiddenFiles,
                          child: Text(
                            showHidden
                                ? l10n.sftpHideHiddenFiles
                                : l10n.sftpShowHiddenFiles,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            case RemoteFileToolbarAction.sort:
              addDivider();
              for (final field in fields.entries) {
                items.add(
                  CheckedPopupMenuItem<String>(
                    value: field.key,
                    checked: sortField == field.key,
                    child: Text(field.value),
                  ),
                );
              }
              items.add(const PopupMenuDivider());
              items.add(
                CheckedPopupMenuItem<String>(
                  value: 'asc',
                  checked: sortAscending,
                  child: Text(l10n.sftpSortAscending),
                ),
              );
              items.add(
                CheckedPopupMenuItem<String>(
                  value: 'desc',
                  checked: !sortAscending,
                  child: Text(l10n.sftpSortDescending),
                ),
              );
            case RemoteFileToolbarAction.selection:
              addDivider();
              items.add(
                PopupMenuItem<String>(
                  key: Key(
                    keyPrefix == 'sftp'
                        ? 'sftpSelectModeButton'
                        : '${keyPrefix}_select',
                  ),
                  value: 'select_mode',
                  enabled: onSelectMode != null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.checklist, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Tooltip(
                          message: l10n.sftpSelectMode,
                          child: Text(
                            l10n.sftpSelectMode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            case RemoteFileToolbarAction.bookmarks:
              items.add(
                PopupMenuItem<String>(
                  key: Key(
                    keyPrefix == 'sftp'
                        ? 'sftpBookmarksListButton'
                        : '${keyPrefix}_bookmarks',
                  ),
                  value: 'bookmarks',
                  enabled: onBookmarks != null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bookmarks_outlined, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Tooltip(
                          message: l10n.sftpBookmarksTitle,
                          child: Text(
                            l10n.sftpBookmarksTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            case RemoteFileToolbarAction.refresh:
              items.add(
                PopupMenuItem<String>(
                  key: Key(
                    keyPrefix == 'sftp'
                        ? 'sftpRefreshButton'
                        : '${keyPrefix}_refresh',
                  ),
                  value: 'refresh',
                  enabled: onRefresh != null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Tooltip(
                          message: l10n.sftpRefresh,
                          child: Text(
                            l10n.sftpRefresh,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
          }
        }

        if (onConfigureToolbar != null) {
          addDivider();
          items.add(
            PopupMenuItem<String>(
              key: Key(
                keyPrefix == 'sftp'
                    ? 'sftpConfigureToolbarButton'
                    : '${keyPrefix}_configure_toolbar',
              ),
              value: 'configure_toolbar',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Tooltip(
                      message: l10n.sftpConfigureToolbar,
                      child: Text(
                        l10n.sftpConfigureToolbar,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return items;
      },
    );
  }
}
