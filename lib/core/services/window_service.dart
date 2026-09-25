import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../data/storage/local_storage_service.dart';
import '../constants/layout_breakpoints.dart';

/// 桌面窗口尺寸与坐标数据模型。
@immutable
class WindowBounds {
  final double width;
  final double height;
  final double? x;
  final double? y;

  const WindowBounds({
    required this.width,
    required this.height,
    this.x,
    this.y,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WindowBounds &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(width, height, x, y);

  @override
  String toString() =>
      'WindowBounds(width: $width, height: $height, x: $x, y: $y)';
}

/// 窗口驱动抽象接口（允许在单元测试中使用 Mock/Fake 替代真实原生 window_manager）。
abstract interface class WindowDriver {
  Future<void> ensureInitialized();
  Future<void> waitUntilReadyToShow([
    WindowOptions? options,
    VoidCallback? callback,
  ]);
  Future<void> setMinimumSize(Size size);
  Future<void> setSize(Size size);
  Future<void> setPosition(Offset position);
  Future<void> setTitle(String title);
  Future<void> show();
  Future<void> focus();
  Future<Size> getSize();
  Future<Offset> getPosition();
  void addListener(WindowListener listener);
  void removeListener(WindowListener listener);
}

/// 生产环境基于 `package:window_manager` 的驱动实现。
class WindowManagerDriver implements WindowDriver {
  const WindowManagerDriver();

  @override
  Future<void> ensureInitialized() => windowManager.ensureInitialized();

  @override
  Future<void> waitUntilReadyToShow([
    WindowOptions? options,
    VoidCallback? callback,
  ]) => windowManager.waitUntilReadyToShow(options, callback);

  @override
  Future<void> setMinimumSize(Size size) => windowManager.setMinimumSize(size);

  @override
  Future<void> setSize(Size size) => windowManager.setSize(size);

  @override
  Future<void> setPosition(Offset position) =>
      windowManager.setPosition(position);

  @override
  Future<void> setTitle(String title) => windowManager.setTitle(title);

  @override
  Future<void> show() => windowManager.show();

  @override
  Future<void> focus() => windowManager.focus();

  @override
  Future<Size> getSize() => windowManager.getSize();

  @override
  Future<Offset> getPosition() => windowManager.getPosition();

  @override
  void addListener(WindowListener listener) =>
      windowManager.addListener(listener);

  @override
  void removeListener(WindowListener listener) =>
      windowManager.removeListener(listener);
}

/// 桌面窗口管理服务（负责尺寸/位置记忆与最小尺寸约束）。
class DesktopWindowService with WindowListener {
  final LocalStorageService _storage;
  final WindowDriver _driver;
  final bool isDesktopPlatform;

  DesktopWindowService({
    required LocalStorageService storage,
    WindowDriver driver = const WindowManagerDriver(),
    bool? isDesktop,
  }) : _storage = storage,
       _driver = driver,
       isDesktopPlatform =
           isDesktop ??
           (!kIsWeb &&
               (Platform.isLinux || Platform.isMacOS || Platform.isWindows));

  /// 初始化窗口（仅在桌面平台上执行原生窗口设置与尺寸恢复）。
  Future<WindowBounds?> initialize() async {
    if (!isDesktopPlatform) return null;

    await _driver.ensureInitialized();
    await _driver.setMinimumSize(
      const Size(
        LayoutBreakpoints.windowMinWidth,
        LayoutBreakpoints.windowMinHeight,
      ),
    );

    final raw = _storage.getWindowBounds();
    final saved = raw != null
        ? WindowBounds(
            width: raw['width']!,
            height: raw['height']!,
            x: raw['x'],
            y: raw['y'],
          )
        : null;

    final effective = resolveEffectiveBounds(saved);

    final windowOptions = WindowOptions(
      size: Size(effective.width, effective.height),
      minimumSize: const Size(
        LayoutBreakpoints.windowMinWidth,
        LayoutBreakpoints.windowMinHeight,
      ),
      center: effective.x == null || effective.y == null,
      title: 'Valhalla',
    );

    await _driver.waitUntilReadyToShow(windowOptions, () async {
      if (effective.x != null && effective.y != null) {
        await _driver.setPosition(Offset(effective.x!, effective.y!));
      }
      await _driver.show();
      await _driver.focus();
    });

    _driver.addListener(this);
    return effective;
  }

  /// 计算生效的窗口边界：保证不小于最小允许尺寸；若无有效保存记录则使用默认推荐尺寸。
  static WindowBounds resolveEffectiveBounds(WindowBounds? saved) {
    if (saved == null) {
      return const WindowBounds(
        width: LayoutBreakpoints.windowDefaultWidth,
        height: LayoutBreakpoints.windowDefaultHeight,
      );
    }

    final double width = saved.width.isFinite
        ? math.max(saved.width, LayoutBreakpoints.windowMinWidth)
        : LayoutBreakpoints.windowDefaultWidth;

    final double height = saved.height.isFinite
        ? math.max(saved.height, LayoutBreakpoints.windowMinHeight)
        : LayoutBreakpoints.windowDefaultHeight;

    final double? x = (saved.x != null && saved.x!.isFinite) ? saved.x : null;
    final double? y = (saved.y != null && saved.y!.isFinite) ? saved.y : null;

    return WindowBounds(width: width, height: height, x: x, y: y);
  }

  @override
  void onWindowResized() {
    _saveCurrentBounds();
  }

  @override
  void onWindowMoved() {
    _saveCurrentBounds();
  }

  Future<void> _saveCurrentBounds() async {
    try {
      final size = await _driver.getSize();
      final position = await _driver.getPosition();
      final clampedWidth = math.max(
        size.width,
        LayoutBreakpoints.windowMinWidth,
      );
      final clampedHeight = math.max(
        size.height,
        LayoutBreakpoints.windowMinHeight,
      );

      await _storage.saveWindowBounds(
        width: clampedWidth,
        height: clampedHeight,
        x: position.dx,
        y: position.dy,
      );
    } catch (_) {
      // 捕获测试环境或通信异常，静默处理
    }
  }

  void dispose() {
    if (isDesktopPlatform) {
      _driver.removeListener(this);
    }
  }
}
