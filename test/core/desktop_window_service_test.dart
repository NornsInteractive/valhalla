import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/constants/layout_breakpoints.dart';
import 'package:valhalla/core/services/window_service.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:window_manager/window_manager.dart';

class FakeWindowDriver implements WindowDriver {
  bool isInitialized = false;
  Size? minimumSize;
  Size currentSize = const Size(1280, 800);
  Offset currentPosition = const Offset(100, 100);
  Size? appliedSize;
  Offset? appliedPosition;
  String? appliedTitle;
  bool isShown = false;
  bool isFocused = false;
  final List<WindowListener> listeners = [];
  WindowOptions? receivedOptions;

  @override
  Future<void> ensureInitialized() async {
    isInitialized = true;
  }

  @override
  Future<void> waitUntilReadyToShow([
    WindowOptions? options,
    VoidCallback? callback,
  ]) async {
    receivedOptions = options;
    if (options != null) {
      if (options.size != null) {
        appliedSize = options.size;
        currentSize = options.size!;
      }
      if (options.title != null) {
        appliedTitle = options.title;
      }
    }
    if (callback != null) {
      callback();
    }
  }

  @override
  Future<void> setMinimumSize(Size size) async {
    minimumSize = size;
  }

  @override
  Future<void> setSize(Size size) async {
    appliedSize = size;
    currentSize = size;
  }

  @override
  Future<void> setPosition(Offset position) async {
    appliedPosition = position;
    currentPosition = position;
  }

  @override
  Future<void> setTitle(String title) async {
    appliedTitle = title;
  }

  @override
  Future<void> show() async {
    isShown = true;
  }

  @override
  Future<void> focus() async {
    isFocused = true;
  }

  @override
  Future<Size> getSize() async => currentSize;

  @override
  Future<Offset> getPosition() async => currentPosition;

  @override
  void addListener(WindowListener listener) {
    listeners.add(listener);
  }

  @override
  void removeListener(WindowListener listener) {
    listeners.remove(listener);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late FakeWindowDriver driver;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await LocalStorageService.init();
    driver = FakeWindowDriver();
  });

  group('LocalStorageService Window Bounds (Task D1)', () {
    test('未保存时读取返回 null', () {
      expect(storage.getWindowBounds(), isNull);
    });

    test('保存并读取完整尺寸与位置', () async {
      await storage.saveWindowBounds(width: 1440, height: 900, x: 120, y: 80);

      final bounds = storage.getWindowBounds();
      expect(bounds, isNotNull);
      expect(bounds!['width'], 1440.0);
      expect(bounds['height'], 900.0);
      expect(bounds['x'], 120.0);
      expect(bounds['y'], 80.0);
    });

    test('保存无位置（居中）的尺寸并正确读取', () async {
      await storage.saveWindowBounds(width: 1024, height: 768);

      final bounds = storage.getWindowBounds();
      expect(bounds, isNotNull);
      expect(bounds!['width'], 1024.0);
      expect(bounds['height'], 768.0);
      expect(bounds['x'], isNull);
      expect(bounds['y'], isNull);
    });

    test('异常负数或 0 尺寸读取时过滤为 null', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('valhalla_window_width_v1', -50.0);
      await prefs.setDouble('valhalla_window_height_v1', 0.0);

      expect(storage.getWindowBounds(), isNull);
    });
  });

  group('DesktopWindowService.resolveEffectiveBounds (Task D1 & D2)', () {
    test('无已存记录时回落到默认窗口尺寸 1280x800', () {
      final effective = DesktopWindowService.resolveEffectiveBounds(null);
      expect(effective.width, equals(LayoutBreakpoints.windowDefaultWidth));
      expect(effective.height, equals(LayoutBreakpoints.windowDefaultHeight));
      expect(effective.x, isNull);
      expect(effective.y, isNull);
    });

    test('已存宽度小于 windowMinWidth(480) 时强行钳制到 480', () {
      const saved = WindowBounds(width: 320, height: 600);
      final effective = DesktopWindowService.resolveEffectiveBounds(saved);
      expect(effective.width, equals(LayoutBreakpoints.windowMinWidth));
      expect(effective.height, equals(600.0));
    });

    test('已存高度小于 windowMinHeight(400) 时强行钳制到 400', () {
      const saved = WindowBounds(width: 800, height: 250);
      final effective = DesktopWindowService.resolveEffectiveBounds(saved);
      expect(effective.width, equals(800.0));
      expect(effective.height, equals(LayoutBreakpoints.windowMinHeight));
    });

    test('合法大屏尺寸与坐标原样保留', () {
      const saved = WindowBounds(width: 1920, height: 1080, x: 200, y: 150);
      final effective = DesktopWindowService.resolveEffectiveBounds(saved);
      expect(effective.width, equals(1920.0));
      expect(effective.height, equals(1080.0));
      expect(effective.x, equals(200.0));
      expect(effective.y, equals(150.0));
    });
  });

  group('DesktopWindowService.initialize 行为与约束 (Task D1 & D2)', () {
    test('非桌面环境（isDesktop: false）不执行任何驱动操作并返回 null', () async {
      final service = DesktopWindowService(
        storage: storage,
        driver: driver,
        isDesktop: false,
      );

      final result = await service.initialize();
      expect(result, isNull);
      expect(driver.isInitialized, isFalse);
      expect(driver.minimumSize, isNull);
      expect(driver.listeners, isEmpty);
    });

    test('桌面环境（isDesktop: true）正确施加最小尺寸约束与默认配置', () async {
      final service = DesktopWindowService(
        storage: storage,
        driver: driver,
        isDesktop: true,
      );

      final result = await service.initialize();
      expect(result, isNotNull);
      expect(driver.isInitialized, isTrue);

      // 验证最小尺寸约束被正确下发到 driver
      expect(driver.minimumSize, isNotNull);
      expect(
        driver.minimumSize!.width,
        equals(LayoutBreakpoints.windowMinWidth),
      );
      expect(
        driver.minimumSize!.height,
        equals(LayoutBreakpoints.windowMinHeight),
      );

      // 验证默认标题与尺寸下发
      expect(driver.receivedOptions?.title, equals('Valhalla'));
      expect(driver.isShown, isTrue);
      expect(driver.isFocused, isTrue);
      expect(driver.listeners, contains(service));
    });

    test('恢复上次存储的窗口尺寸和位置', () async {
      await storage.saveWindowBounds(width: 1400, height: 950, x: 80, y: 60);

      final service = DesktopWindowService(
        storage: storage,
        driver: driver,
        isDesktop: true,
      );

      final result = await service.initialize();
      expect(result, isNotNull);
      expect(result!.width, equals(1400.0));
      expect(result.height, equals(950.0));
      expect(result.x, equals(80.0));
      expect(result.y, equals(60.0));

      expect(driver.appliedPosition, equals(const Offset(80, 60)));
      expect(driver.appliedSize, equals(const Size(1400, 950)));
    });

    test('窗口调整大小与移动事件触发持久化保存', () async {
      final service = DesktopWindowService(
        storage: storage,
        driver: driver,
        isDesktop: true,
      );

      await service.initialize();

      // 模拟用户拖动窗口至 1600x1000, 坐标 (300, 200)
      driver.currentSize = const Size(1600, 1000);
      driver.currentPosition = const Offset(300, 200);

      service.onWindowResized();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      var bounds = storage.getWindowBounds();
      expect(bounds, isNotNull);
      expect(bounds!['width'], 1600.0);
      expect(bounds['height'], 1000.0);
      expect(bounds['x'], 300.0);
      expect(bounds['y'], 200.0);

      // 模拟用户移动窗口至 (450, 250)
      driver.currentPosition = const Offset(450, 250);
      service.onWindowMoved();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bounds = storage.getWindowBounds();
      expect(bounds!['x'], 450.0);
      expect(bounds['y'], 250.0);

      service.dispose();
      expect(driver.listeners, isEmpty);
    });
  });
}
