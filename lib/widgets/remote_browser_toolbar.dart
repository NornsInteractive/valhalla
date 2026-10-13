import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/design/tokens.dart';
import '../core/extensions/context_extensions.dart';

/// Controlled browser chrome shared by the file page and read-only pickers.
class RemoteBrowserBreadcrumb extends StatefulWidget {
  const RemoteBrowserBreadcrumb({
    super.key,
    required this.path,
    this.rootPath = '/',
    this.onNavigate,
    this.onUp,
    this.trailing,
    this.scrollController,
    this.keyPrefix = 'remote_browser',
  });

  final String path;
  final String rootPath;
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
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                  ],
                ),
              ),
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
    this.leadingActions = const [],
    this.trailingActions = const [],
    this.keyPrefix = 'remote_browser',
    this.searchHint,
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
  final List<Widget> leadingActions;
  final List<Widget> trailingActions;
  final String keyPrefix;
  final String? searchHint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fields = {
      'name': l10n.sftpSortName,
      'size': l10n.sftpSortSize,
      'date': l10n.sftpSortDate,
    };
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
                      (isGrid ? l10n.sftpViewModeList : l10n.sftpViewModeGrid),
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
          ),
        ],
      ),
    );
  }
}
