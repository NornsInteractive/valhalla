import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/application_center_provider.dart';
import '../../../core/providers/storage_providers.dart';
import '../../../data/models/application_center.dart';
import '../../../widgets/valhalla_card.dart';
import 'app_cached_image.dart';
import 'app_center_error_resolver.dart';
import 'app_details_dialog.dart';
import 'app_sources_dialog.dart';

class AppStoreTab extends ConsumerStatefulWidget {
  final void Function(int index)? onNavigateToTab;

  const AppStoreTab({super.key, this.onNavigateToTab});

  @override
  ConsumerState<AppStoreTab> createState() => _AppStoreTabState();
}

class _AppStoreTabState extends ConsumerState<AppStoreTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedCategory = 'ALL';
  String _selectedSourceId = 'ALL';
  String? _viewMode;
  String? _anchorAppId;
  String? _anchorSourceId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  void _loadViewMode() {
    try {
      final storage = ref.read(localStorageServiceProvider);
      final saved = storage.getApplicationStoreViewMode();
      if (saved == 'list' || saved == 'grid') {
        setState(() => _viewMode = saved);
      }
    } catch (_) {}
  }

  double _lastWidth = 800;

  static double _computeCardExtent(BuildContext context) {
    final typography = _CatalogCardTypography.of(context);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: 'Title Sample',
        style: typography.titleStyle,
        locale: typography.locale,
      ),
      textDirection: typography.direction,
      textScaler: typography.textScaler,
      maxLines: 1,
    )..layout();

    final badgePainter = TextPainter(
      text: TextSpan(
        text: 'Badge',
        style: typography.badgeStyle,
        locale: typography.locale,
      ),
      textDirection: typography.direction,
      textScaler: typography.textScaler,
      maxLines: 1,
    )..layout();

    final summaryPainter = TextPainter(
      text: TextSpan(
        text: 'Summary',
        style: typography.summaryStyle,
        locale: typography.locale,
      ),
      textDirection: typography.direction,
      textScaler: typography.textScaler,
      maxLines: 1,
    )..layout();

    final sourcePainter = TextPainter(
      text: TextSpan(
        text: 'Source v1.0.0',
        style: typography.sourceStyle,
        locale: typography.locale,
      ),
      textDirection: typography.direction,
      textScaler: typography.textScaler,
      maxLines: 1,
    )..layout();

    final titleRowHeight = math.max(
      titlePainter.height,
      badgePainter.height + 4.0,
    );
    final textColumnHeight =
        titleRowHeight +
        2.0 +
        summaryPainter.height +
        4.0 +
        sourcePainter.height;
    final contentHeight = math.max(48.0, textColumnHeight);
    final totalCardHeight = contentHeight + 20.0;

    titlePainter.dispose();
    badgePainter.dispose();
    summaryPainter.dispose();
    sourcePainter.dispose();

    return totalCardHeight.ceilToDouble();
  }

  static double _computeGridCardExtent(BuildContext context) {
    final typography = _CatalogCardTypography.of(context);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: 'Title Line 1\nTitle Line 2',
        style: typography.titleStyle,
        locale: typography.locale,
      ),
      textDirection: typography.direction,
      textScaler: typography.textScaler,
      maxLines: 2,
    )..layout();

    final summaryPainter = TextPainter(
      text: TextSpan(
        text: 'Summary',
        style: typography.summaryStyle,
        locale: typography.locale,
      ),
      textDirection: typography.direction,
      textScaler: typography.textScaler,
      maxLines: 1,
    )..layout();

    final sourcePainter = TextPainter(
      text: TextSpan(
        text: 'Source',
        style: typography.sourceStyle,
        locale: typography.locale,
      ),
      textDirection: typography.direction,
      textScaler: typography.textScaler,
      maxLines: 1,
    )..layout();

    final versionPainter = TextPainter(
      text: TextSpan(
        text: '1.0.0',
        style: typography.versionStyle,
        locale: typography.locale,
      ),
      textDirection: typography.direction,
      textScaler: typography.textScaler,
      maxLines: 1,
    )..layout();

    final badgePainter = TextPainter(
      text: TextSpan(
        text: 'Badge',
        style: typography.badgeStyle,
        locale: typography.locale,
      ),
      textDirection: typography.direction,
      textScaler: typography.textScaler,
      maxLines: 1,
    )..layout();

    const paddingHeight = 16.0;
    const iconHeight = 32.0;
    final titleRowHeight = math.max(iconHeight, titlePainter.height);
    final versionRowHeight = math.max(
      versionPainter.height,
      badgePainter.height + 3.0,
    );
    const gap1 = 4.0;
    const gap2 = 2.0;

    final totalHeight =
        paddingHeight +
        titleRowHeight +
        gap1 +
        summaryPainter.height +
        gap2 +
        sourcePainter.height +
        versionRowHeight;

    titlePainter.dispose();
    badgePainter.dispose();
    summaryPainter.dispose();
    sourcePainter.dispose();
    versionPainter.dispose();

    return totalHeight.ceilToDouble();
  }

  List<CatalogApplication> _getFilteredCatalog() {
    final state = ref.read(applicationCenterProvider);
    final catalog = state.catalog;
    final query = _searchCtrl.text.trim().toLowerCase();
    return catalog.where((app) {
      if (_selectedCategory != 'ALL' && app.category != _selectedCategory) {
        return false;
      }
      if (_selectedSourceId != 'ALL' && app.sourceId != _selectedSourceId) {
        return false;
      }
      if (query.isNotEmpty) {
        final title = app.title.toLowerCase();
        final summary = app.summary.toLowerCase();
        final cat = app.category.toLowerCase();
        if (!title.contains(query) &&
            !summary.contains(query) &&
            !cat.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _resetAnchor() {
    _anchorAppId = null;
    _anchorSourceId = null;
  }

  Future<void> _toggleViewMode() async {
    final width = _lastWidth > 0
        ? _lastWidth
        : MediaQuery.sizeOf(context).width;
    final isCompact = width < LayoutBreakpoints.compactMax;
    final current = _viewMode ?? (isCompact ? 'list' : 'grid');
    final next = current == 'list' ? 'grid' : 'list';
    final previous = _viewMode;

    final layout = AppStoreGridLayout.compute(context, width);

    final filtered = _getFilteredCatalog();

    if (_scrollController.hasClients && filtered.isNotEmpty) {
      final offset = _scrollController.offset;
      int targetIndex;
      if (current == 'list') {
        targetIndex =
            ((offset - 12.0).clamp(0.0, double.infinity) /
                    layout.listItemExtent)
                .floor();
      } else {
        final gridRow =
            ((offset - 16.0).clamp(0.0, double.infinity) / layout.gridRowStride)
                .floor();
        targetIndex = gridRow * layout.crossAxisCount;
      }
      targetIndex = targetIndex.clamp(0, filtered.length - 1);
      final anchorApp = filtered[targetIndex];
      _anchorAppId = anchorApp.id;
      _anchorSourceId = anchorApp.sourceId;
    }

    setState(() => _viewMode = next);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final currentFiltered = _getFilteredCatalog();
      int resolvedIndex = 0;
      if (_anchorAppId != null && currentFiltered.isNotEmpty) {
        final idx = currentFiltered.indexWhere(
          (a) => a.id == _anchorAppId && a.sourceId == _anchorSourceId,
        );
        if (idx != -1) {
          resolvedIndex = idx;
        } else {
          resolvedIndex = 0;
        }
      }
      if (currentFiltered.isNotEmpty) {
        resolvedIndex = resolvedIndex.clamp(0, currentFiltered.length - 1);
      }

      final postLayout = AppStoreGridLayout.compute(
        context,
        _lastWidth > 0 ? _lastWidth : MediaQuery.sizeOf(context).width,
      );

      double targetOffset;
      if (next == 'list') {
        targetOffset = 12.0 + resolvedIndex * postLayout.listItemExtent;
      } else {
        final row = (resolvedIndex / postLayout.crossAxisCount).floor();
        targetOffset = 16.0 + row * postLayout.gridRowStride;
      }
      final maxScroll = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(targetOffset.clamp(0.0, maxScroll));
    });

    try {
      final storage = ref.read(localStorageServiceProvider);
      await storage.setApplicationStoreViewMode(next);
    } catch (e) {
      if (mounted) {
        setState(() => _viewMode = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: context.vDanger,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchCtrl.clear();
    _resetAnchor();
    setState(() {
      _selectedCategory = 'ALL';
      _selectedSourceId = 'ALL';
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final state = ref.watch(applicationCenterProvider);
    final notifier = ref.read(applicationCenterProvider.notifier);
    final catalog = state.catalog;
    final sources = state.sources;
    final env = state.environment;

    final hasEnabledSources = sources.any((s) => s.enabled);

    // Normalize category dropdown
    final categories = <String>{'ALL'};
    for (final app in catalog) {
      if (app.category.isNotEmpty) categories.add(app.category);
    }
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = 'ALL';
    }

    // Normalize source dropdown
    final allowedSourceIds = <String>{'ALL', ...sources.map((s) => s.id)};
    if (!allowedSourceIds.contains(_selectedSourceId)) {
      _selectedSourceId = 'ALL';
    }

    final filtered = _getFilteredCatalog();

    return LayoutBuilder(
      builder: (context, constraints) {
        _lastWidth = constraints.maxWidth;
        final isCompact = constraints.maxWidth < LayoutBreakpoints.compactMax;
        final effectiveMode = _viewMode ?? (isCompact ? 'list' : 'grid');

        return Column(
          children: [
            // Search & Filter Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.appCenterSearchHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _resetAnchor();
                                setState(() {});
                              },
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VRadius.input),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) {
                      _resetAnchor();
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Category dropdown
                        DropdownButton<String>(
                          value: _selectedCategory,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          items: categories.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(
                                cat == 'ALL'
                                    ? l10n.appCenterFilterAllCategories
                                    : cat,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _resetAnchor();
                              setState(() => _selectedCategory = val);
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        // Source dropdown
                        DropdownButton<String>(
                          value: _selectedSourceId,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            DropdownMenuItem(
                              value: 'ALL',
                              child: Text(
                                l10n.appCenterFilterAllSources,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            ...sources.map((s) {
                              return DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                  s.name,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              _resetAnchor();
                              setState(() => _selectedSourceId = val);
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        // View Mode toggle
                        IconButton(
                          icon: Icon(
                            effectiveMode == 'list'
                                ? Icons.grid_view
                                : Icons.view_list,
                            size: 20,
                          ),
                          tooltip: effectiveMode == 'list'
                              ? l10n.sftpViewModeGrid
                              : l10n.sftpViewModeList,
                          onPressed: _toggleViewMode,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Per-source error banner with retry, last success and copyable diagnostics
            if (state.sourceErrors.isNotEmpty)
              Container(
                width: double.maxFinite,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.vWarning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VRadius.card),
                  border: Border.all(
                    color: context.vWarning.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...state.sourceErrors.entries.map((entry) {
                      final sourceName =
                          sources
                              .where((s) => s.id == entry.key)
                              .firstOrNull
                              ?.name ??
                          entry.key;
                      final sourceLastRefresh =
                          state.sourceRefreshedAt[entry.key];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: context.vWarning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$sourceName: ${resolveAppCenterErrorMessage(context, entry.value)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.vWarning,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (sourceLastRefresh != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 1,
                                        bottom: 2,
                                      ),
                                      child: Text(
                                        '${context.appCenterSourceRefreshedAtLabel}: ${sourceLastRefresh.toLocal().toString().split('.').first}',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: context.colorScheme.outline,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 14),
                              tooltip: l10n.appCenterCopyLog,
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: '${entry.key}: ${entry.value}',
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.l10n.appCenterLogsCopied,
                                    ),
                                  ),
                                );
                              },
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              onPressed: state.loadingCatalog
                                  ? null
                                  : () => notifier.refreshCatalog(
                                      sourceId: entry.key,
                                    ),
                              child: Text(
                                context.appCenterRetryLabel,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (state.sourceRefreshedAt.isEmpty &&
                        state.catalogRefreshedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${context.appCenterSourceRefreshedAtLabel}: ${state.catalogRefreshedAt!.toLocal().toString().split('.').first}',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.colorScheme.outline,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const Divider(height: 1),
            // Catalog List / Grid / Empty States
            Expanded(
              child: Builder(
                builder: (context) {
                  // 1. No sources configured / enabled
                  if (!hasEnabledSources) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.source_outlined,
                              size: 48,
                              color: context.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.appCenterNoSourcesLabel,
                              style: TextStyle(
                                color: context.colorScheme.outline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonalIcon(
                              icon: const Icon(
                                Icons.settings_outlined,
                                size: 16,
                              ),
                              label: Text(l10n.appCenterManageSources),
                              onPressed: () => AppSourcesDialog.show(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // 2. Catalog is completely empty due to source loading failure
                  if (catalog.isEmpty && state.sourceErrors.isNotEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_off_outlined,
                              size: 48,
                              color: context.vWarning,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.appCenterSourceLoadFailedLabel,
                              style: TextStyle(
                                color: context.colorScheme.outline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.refresh, size: 16),
                              label: Text(context.appCenterRetryLabel),
                              onPressed: state.loadingCatalog
                                  ? null
                                  : () => notifier.refreshCatalog(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // 3. Catalog is empty (no apps returned)
                  if (catalog.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.apps_outage_outlined,
                              size: 48,
                              color: context.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.appCenterNoApps,
                              style: TextStyle(
                                color: context.colorScheme.outline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.refresh, size: 16),
                              label: Text(l10n.appCenterRefresh),
                              onPressed: state.loadingCatalog
                                  ? null
                                  : () => notifier.refreshCatalog(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // 4. Filters returned 0 results while catalog has apps
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_alt_off_outlined,
                              size: 48,
                              color: context.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.appCenterNoMatchingAppsLabel,
                              style: TextStyle(
                                color: context.colorScheme.outline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.clear, size: 16),
                              label: Text(context.appCenterClearFiltersLabel),
                              onPressed: _clearFilters,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // 5. Normal populated catalog
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      _lastWidth = constraints.maxWidth;
                      final layout = AppStoreGridLayout.compute(
                        context,
                        constraints.maxWidth,
                      );
                      final isCompact =
                          constraints.maxWidth < LayoutBreakpoints.compactMax;
                      final effectiveMode =
                          _viewMode ?? (isCompact ? 'list' : 'grid');

                      if (effectiveMode == 'list') {
                        return ListView.builder(
                          key: const PageStorageKey('app-store-scroll'),
                          controller: _scrollController,
                          itemExtent: layout.listItemExtent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, idx) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _CatalogItemCard(
                                app: filtered[idx],
                                state: state,
                                env: env,
                                onNavigateToTab: widget.onNavigateToTab,
                                isGrid: false,
                              ),
                            );
                          },
                        );
                      }

                      return GridView.builder(
                        key: const PageStorageKey('app-store-scroll'),
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: layout.crossAxisCount,
                          mainAxisExtent: layout.gridCardExtent,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, idx) {
                          return _CatalogItemCard(
                            app: filtered[idx],
                            state: state,
                            env: env,
                            onNavigateToTab: widget.onNavigateToTab,
                            isGrid: true,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class AppStoreGridLayout {
  final int crossAxisCount;
  final double gridCardExtent;
  final double listCardExtent;

  const AppStoreGridLayout({
    required this.crossAxisCount,
    required this.gridCardExtent,
    required this.listCardExtent,
  });

  double get gridRowStride => gridCardExtent + 8.0;
  double get listItemExtent => listCardExtent + 8.0;

  static AppStoreGridLayout compute(BuildContext context, double width) {
    final textScaler = MediaQuery.textScalerOf(context);
    final isLargeText = textScaler.scale(14.0) >= 22.5;
    final isCompact = width < LayoutBreakpoints.compactMax;

    final int cols;
    if (isCompact) {
      cols = isLargeText ? 1 : 2;
    } else {
      final crossAxisExtent = math.max(0.0, width - 32.0);
      cols = math.max(
        isLargeText ? 1 : 2,
        (crossAxisExtent / (isLargeText ? 420.0 : 340.0)).floor(),
      );
    }

    final gridExtent = _AppStoreTabState._computeGridCardExtent(context);
    final listExtent = _AppStoreTabState._computeCardExtent(context);

    return AppStoreGridLayout(
      crossAxisCount: cols,
      gridCardExtent: gridExtent,
      listCardExtent: listExtent,
    );
  }
}

class _CatalogItemCard extends StatelessWidget {
  final CatalogApplication app;
  final ApplicationCenterState state;
  final ApplicationEnvironment? env;
  final void Function(int index)? onNavigateToTab;
  final bool isGrid;

  const _CatalogItemCard({
    required this.app,
    required this.state,
    required this.env,
    this.onNavigateToTab,
    this.isGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typography = _CatalogCardTypography.of(context);
    final isInstalled = state.deployments.any(
      (d) => d.sourceId == app.sourceId && d.appId == app.id,
    );
    final isCompatible =
        env == null ||
        app.architectures.isEmpty ||
        app.architectures.contains(env!.architecture);

    final sourceName =
        state.sources.where((s) => s.id == app.sourceId).firstOrNull?.name ??
        app.sourceId;
    final rawVersion = app.version.trim();
    final versionText = rawVersion.isNotEmpty ? rawVersion : '—';

    if (!isGrid) {
      return ValhallaCard(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(VRadius.card),
          onTap: () => AppDetailsDialog.show(
            context,
            application: app,
            onNavigateToTab: onNavigateToTab,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(VRadius.card),
                  child: SizedBox(
                    width: 48,
                    height: 48,
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              app.title,
                              style: typography.titleStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isInstalled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.vSuccess.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  VRadius.pill,
                                ),
                              ),
                              child: Text(
                                l10n.appCenterInstalledBadge,
                                style: typography.badgeStyle.copyWith(
                                  color: context.vSuccess,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else if (!isCompatible)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.vDanger.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  VRadius.pill,
                                ),
                              ),
                              child: Text(
                                l10n.appCenterIncompatibleBadge,
                                style: typography.badgeStyle.copyWith(
                                  color: context.vDanger,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.summary.isNotEmpty ? app.summary : app.category,
                        style: typography.summaryStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              sourceName,
                              style: typography.sourceStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (app.version.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              flex: 2,
                              child: Text(
                                'v${app.version}',
                                style: typography.versionStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ValhallaCard(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(VRadius.card),
        onTap: () => AppDetailsDialog.show(
          context,
          application: app,
          onNavigateToTab: onNavigateToTab,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(VRadius.card),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: AppCachedImage(
                        url: app.iconUrl,
                        revision: app.contentHash,
                        sourceId: app.sourceId,
                        fit: BoxFit.cover,
                        errorWidget: const Icon(Icons.apps, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      app.title,
                      style: typography.titleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                app.summary.isNotEmpty ? app.summary : app.category,
                style: typography.summaryStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                sourceName,
                style: typography.sourceStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: versionText,
                      child: Text(
                        versionText,
                        style: typography.versionStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (isInstalled) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: context.vSuccess.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(VRadius.pill),
                        ),
                        child: Text(
                          l10n.appCenterInstalledBadge,
                          style: typography.badgeStyle.copyWith(
                            color: context.vSuccess,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ] else if (!isCompatible) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: context.vDanger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(VRadius.pill),
                        ),
                        child: Text(
                          l10n.appCenterIncompatibleBadge,
                          style: typography.badgeStyle.copyWith(
                            color: context.vDanger,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogCardTypography {
  final TextStyle titleStyle;
  final TextStyle badgeStyle;
  final TextStyle summaryStyle;
  final TextStyle sourceStyle;
  final TextStyle versionStyle;
  final Locale? locale;
  final TextDirection direction;
  final TextScaler textScaler;

  const _CatalogCardTypography({
    required this.titleStyle,
    required this.badgeStyle,
    required this.summaryStyle,
    required this.sourceStyle,
    required this.versionStyle,
    required this.locale,
    required this.direction,
    required this.textScaler,
  });

  factory _CatalogCardTypography.of(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = (theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(
          fontFamily: theme.textTheme.bodyMedium?.fontFamily ?? 'Inter',
          height: 1.5,
        );

    return _CatalogCardTypography(
      titleStyle: baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
      badgeStyle: baseStyle.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
      summaryStyle: baseStyle.copyWith(
        fontSize: 11,
        color: theme.colorScheme.outline,
      ),
      sourceStyle: baseStyle.copyWith(
        fontSize: 10,
        color: theme.colorScheme.primary,
      ),
      versionStyle: baseStyle.copyWith(
        fontSize: 10,
        color: theme.colorScheme.outline,
      ),
      locale: Localizations.maybeLocaleOf(context),
      direction: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
  }
}
