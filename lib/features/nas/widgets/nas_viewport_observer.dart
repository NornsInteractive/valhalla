import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/nas_preview_provider.dart';
import '../../../data/models/nas_media.dart';

/// Contract for a thumbnail tile registering with the viewport observer.
abstract class NasViewportTile {
  BuildContext get context;
  NasMediaItem get item;
  bool get tickerEnabled;
}

/// Composite key distinguishing viewport groups by ancestor Scrollable
/// (or null for standalone tiles like mini player/details) and Riverpod ProviderContainer.
@immutable
class _GroupKey {
  final Object? scrollable;
  final ProviderContainer container;

  const _GroupKey(this.scrollable, this.container);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _GroupKey &&
          identical(scrollable, other.scrollable) &&
          identical(container, other.container);

  @override
  int get hashCode =>
      Object.hash(identityHashCode(scrollable), identityHashCode(container));
}

class _NasViewportGroup {
  final Object? scrollableState;
  final ProviderContainer container;
  final Object owner = Object();
  final Set<NasViewportTile> tiles = {};

  ScrollPosition? _attachedPosition;
  Timer? _settleTimer;
  bool _isScrolling = false;
  bool _postFrameScheduled = false;
  bool _disposed = false;

  _NasViewportGroup({
    required this.scrollableState,
    required this.container,
  });

  void addTile(NasViewportTile tile) {
    if (_disposed) return;
    tiles.add(tile);
    _attachPositionIfNeeded();
    scheduleMeasurement();
  }

  void removeTile(NasViewportTile tile) {
    if (_disposed) return;
    tiles.remove(tile);
    if (tiles.isEmpty) {
      dispose();
    } else {
      scheduleMeasurement();
    }
  }

  void onTileUpdated(NasViewportTile tile) {
    if (_disposed) return;
    scheduleMeasurement();
  }

  void _attachPositionIfNeeded() {
    if (scrollableState is! ScrollableState) return;
    final scrollable = scrollableState as ScrollableState;
    try {
      final position = scrollable.position;
      if (!identical(position, _attachedPosition)) {
        _attachedPosition?.removeListener(_onScroll);
        _attachedPosition = position;
        _attachedPosition?.addListener(_onScroll);
      }
    } catch (_) {
      // scrollable.position may not be ready during initial layout
    }
  }

  void _onScroll() {
    if (_disposed) return;
    _isScrolling = true;
    _settleTimer?.cancel();
    scheduleMeasurement(clearPrefetch: true);
    _settleTimer = Timer(const Duration(milliseconds: 150), () {
      if (_disposed) return;
      _isScrolling = false;
      scheduleMeasurement(clearPrefetch: false, requestFrame: true);
    });
  }

  void onLifecycleChanged(AppLifecycleState state) {
    if (_disposed) return;
    if (state != AppLifecycleState.resumed) {
      _settleTimer?.cancel();
      _isScrolling = false;
      _safeReleaseImmediate();
    } else {
      scheduleMeasurement(requestFrame: true);
    }
  }

  void scheduleMeasurement({
    bool clearPrefetch = false,
    bool requestFrame = false,
  }) {
    if (_disposed) return;
    if (!_postFrameScheduled) {
      _postFrameScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _postFrameScheduled = false;
        if (_disposed) return;
        _performMeasurement(clearPrefetch: clearPrefetch || _isScrolling);
      });
    }
    if (requestFrame) {
      try {
        WidgetsBinding.instance.ensureVisualUpdate();
      } catch (_) {}
    }
  }

  void _performMeasurement({bool clearPrefetch = false}) {
    if (_disposed) return;
    _attachPositionIfNeeded();

    if (tiles.isEmpty ||
        NasViewportCoordinator.instance.currentLifecycle !=
            AppLifecycleState.resumed) {
      _safeUpdate(visible: const [], prefetch: const []);
      return;
    }

    if (scrollableState == null) {
      _measureStandalone();
      return;
    }

    final scrollable = scrollableState as ScrollableState;
    if (!scrollable.mounted) {
      _safeUpdate(visible: const [], prefetch: const []);
      return;
    }

    final scrollBox = scrollable.context.findRenderObject() as RenderBox?;
    if (scrollBox == null || !scrollBox.hasSize) {
      // Do not endlessly re-schedule when size is not yet available to avoid infinite visual frame loops.
      return;
    }

    final windowView = View.maybeOf(scrollable.context);
    final screenSize = windowView != null
        ? (windowView.physicalSize / windowView.devicePixelRatio)
        : const Size(4000, 4000);
    final screenRect = Offset.zero & screenSize;

    final scrollBoxGlobal =
        scrollBox.localToGlobal(Offset.zero) & scrollBox.size;
    if (!scrollBoxGlobal.overlaps(screenRect)) {
      _safeUpdate(visible: const [], prefetch: const []);
      return;
    }

    // Visible viewport is the true intersection of scrollable viewport and screen
    final visibleViewportGlobal = scrollBoxGlobal.intersect(screenRect);
    if (visibleViewportGlobal.isEmpty) {
      _safeUpdate(visible: const [], prefetch: const []);
      return;
    }

    final axisDirection = scrollable.axisDirection;
    final isVertical =
        axisDirection == AxisDirection.down || axisDirection == AxisDirection.up;

    ScrollDirection userDirection = ScrollDirection.idle;
    try {
      userDirection = scrollable.position.userScrollDirection;
    } catch (_) {}
    final isForward = userDirection != ScrollDirection.forward;

    final visibleItems = <NasMediaItem>[];
    final prefetchCandidates = <(NasMediaItem, double)>[];

    for (final tile in tiles) {
      if (!tile.context.mounted || !tile.tickerEnabled) continue;

      final tileBox = tile.context.findRenderObject() as RenderBox?;
      if (tileBox == null || !tileBox.hasSize) continue;

      final tileGlobal = tileBox.localToGlobal(Offset.zero);
      final tileGlobalRect = tileGlobal & tileBox.size;

      // Visibility is strictly judged against the visible viewport intersection on screen
      final isTileVisible = tileGlobalRect.overlaps(visibleViewportGlobal) &&
          tileBox.size.width > 0 &&
          tileBox.size.height > 0;

      if (isTileVisible) {
        visibleItems.add(tile.item);
      } else if (!clearPrefetch) {
        // Prefetch extends one viewport length along the scroll direction from the viewport.
        // It is NOT filtered by screenRect so off-screen candidates ahead in scroll direction can be prefetched.
        final localOffset =
            tileBox.localToGlobal(Offset.zero, ancestor: scrollBox);

        if (isVertical) {
          final top = localOffset.dy;
          final bottom = top + tileBox.size.height;
          final viewportHeight = scrollBox.size.height;

          if (isForward) {
            if (top >= viewportHeight && top <= 2 * viewportHeight) {
              prefetchCandidates.add((tile.item, top - viewportHeight));
            }
          } else {
            if (bottom <= 0 && bottom >= -viewportHeight) {
              prefetchCandidates.add((tile.item, -bottom));
            }
          }
        } else {
          final left = localOffset.dx;
          final right = left + tileBox.size.width;
          final viewportWidth = scrollBox.size.width;

          if (isForward) {
            if (left >= viewportWidth && left <= 2 * viewportWidth) {
              prefetchCandidates.add((tile.item, left - viewportWidth));
            }
          } else {
            if (right <= 0 && right >= -viewportWidth) {
              prefetchCandidates.add((tile.item, -right));
            }
          }
        }
      }
    }

    prefetchCandidates.sort((a, b) => a.$2.compareTo(b.$2));
    final prefetchItems =
        prefetchCandidates.map((c) => c.$1).take(24).toList();

    _safeUpdate(visible: visibleItems, prefetch: prefetchItems);
  }

  void _measureStandalone() {
    final visibleItems = <NasMediaItem>[];
    for (final tile in tiles) {
      if (!tile.context.mounted || !tile.tickerEnabled) continue;
      final tileBox = tile.context.findRenderObject() as RenderBox?;
      if (tileBox == null || !tileBox.hasSize) continue;

      final windowView = View.maybeOf(tile.context);
      final screenSize = windowView != null
          ? (windowView.physicalSize / windowView.devicePixelRatio)
          : const Size(4000, 4000);
      final screenRect = Offset.zero & screenSize;

      final tileGlobal = tileBox.localToGlobal(Offset.zero);
      final tileGlobalRect = tileGlobal & tileBox.size;
      if (tileGlobalRect.overlaps(screenRect) &&
          tileBox.size.width > 0 &&
          tileBox.size.height > 0) {
        visibleItems.add(tile.item);
      }
    }
    _safeUpdate(visible: visibleItems, prefetch: const []);
  }

  void _safeUpdate({
    required List<NasMediaItem> visible,
    required List<NasMediaItem> prefetch,
  }) {
    if (_disposed) return;
    try {
      if (visible.isEmpty && prefetch.isEmpty) {
        container.read(nasPreviewRequestsProvider.notifier).release(owner);
      } else {
        container.read(nasPreviewRequestsProvider.notifier).update(
              owner,
              visible: visible,
              prefetch: prefetch,
            );
      }
    } catch (_) {}
  }

  void _safeReleaseImmediate() {
    try {
      container.read(nasPreviewRequestsProvider.notifier).release(owner);
    } catch (_) {}
  }

  void _safeReleaseDelayed() {
    final capturedContainer = container;
    final capturedOwner = owner;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        capturedContainer
            .read(nasPreviewRequestsProvider.notifier)
            .release(capturedOwner);
      } catch (_) {}
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _settleTimer?.cancel();
    _settleTimer = null;
    _attachedPosition?.removeListener(_onScroll);
    _attachedPosition = null;
    tiles.clear();
    _safeReleaseDelayed();
  }
}

class NasViewportCoordinator with WidgetsBindingObserver {
  static final NasViewportCoordinator instance = NasViewportCoordinator._();

  final Map<_GroupKey, _NasViewportGroup> _groups = {};
  final Map<NasViewportTile, _GroupKey> _tileToGroup = {};
  AppLifecycleState _currentLifecycle = AppLifecycleState.resumed;

  AppLifecycleState get currentLifecycle => _currentLifecycle;

  NasViewportCoordinator._() {
    WidgetsBinding.instance.addObserver(this);
    try {
      _currentLifecycle =
          WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _currentLifecycle = state;
    for (final group in _groups.values.toList()) {
      group.onLifecycleChanged(state);
    }
  }

  void register(
    NasViewportTile tile, {
    required Object? scrollable,
    required ProviderContainer container,
    required bool tickerEnabled,
  }) {
    final newKey = _GroupKey(scrollable, container);
    final oldKey = _tileToGroup[tile];

    if (oldKey != null && oldKey != newKey) {
      final oldGroup = _groups[oldKey];
      if (oldGroup != null) {
        oldGroup.removeTile(tile);
        if (oldGroup.tiles.isEmpty) {
          _groups.remove(oldKey);
        }
      }
    }

    _tileToGroup[tile] = newKey;
    final group = _groups.putIfAbsent(
      newKey,
      () => _NasViewportGroup(
        scrollableState: scrollable,
        container: container,
      ),
    );
    group.addTile(tile);
  }

  void updateTile(NasViewportTile tile) {
    final key = _tileToGroup[tile];
    if (key != null) {
      _groups[key]?.onTileUpdated(tile);
    }
  }

  void unregister(NasViewportTile tile) {
    final key = _tileToGroup.remove(tile);
    if (key != null) {
      final group = _groups[key];
      if (group != null) {
        group.removeTile(tile);
        if (group.tiles.isEmpty) {
          _groups.remove(key);
        }
      }
    }
  }
}

class NasViewportObserver extends StatelessWidget {
  final Widget child;
  const NasViewportObserver({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
