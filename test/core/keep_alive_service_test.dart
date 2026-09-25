import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/reconnect_provider.dart';
import 'package:valhalla/core/services/keep_alive_service.dart';

/// 记录调用的假实现，供 provider 层测试使用。
class _RecordingService implements KeepAliveService {
  final List<int> startCalls = [];
  final List<int> updateCalls = [];
  int stopCalls = 0;
  bool startResult = true;

  @override
  Future<bool> start(int sessionCount) async {
    startCalls.add(sessionCount);
    return startResult;
  }

  @override
  Future<void> updateSessionCount(int sessionCount) async {
    updateCalls.add(sessionCount);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<bool> isRunning() async => startCalls.length > stopCalls;

  @override
  Future<void> notifyTransferCompleted(int completedCount) async {}

  @override
  Future<bool> consumeOpenTransfersAction() async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = MethodChannelKeepAliveService();
  const channel = MethodChannel('valhalla/keepalive');
  late List<MethodCall> calls;
  late Object? Function(MethodCall) handler;

  setUp(() {
    calls = [];
    handler = (_) => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return handler(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('MethodChannelKeepAliveService', () {
    test('start 转发 sessionCount 并返回原生结果', () async {
      handler = (_) => true;

      expect(await service.start(3), isTrue);
      expect(calls.single.method, 'start');
      expect(calls.single.arguments, {'sessionCount': 3});
    });

    test('start 在原生返回 null 时按 false 处理', () async {
      expect(await service.start(1), isFalse);
    });

    test('start 吞掉 PlatformException 并返回 false（后台启动被拒）', () async {
      // 系统在后台启动限制下会拒绝，这必须降级而不是崩溃。
      handler = (_) => throw PlatformException(
        code: 'foreground_service_start_failed',
        message: 'not allowed',
      );

      expect(await service.start(1), isFalse);
    });

    test('start 在通道缺失时返回 false（非 Android 平台）', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      expect(await service.start(1), isFalse);
    });

    test('updateSessionCount 转发数量', () async {
      await service.updateSessionCount(5);
      expect(calls.single.method, 'updateSessionCount');
      expect(calls.single.arguments, {'sessionCount': 5});
    });

    test('updateSessionCount 不因原生异常而抛出', () async {
      handler = (_) => throw PlatformException(code: 'boom');

      await expectLater(service.updateSessionCount(2), completes);
    });

    test('stop 调用原生 stop', () async {
      await service.stop();
      expect(calls.single.method, 'stop');
    });

    test('stop 不因原生异常而抛出', () async {
      handler = (_) => throw PlatformException(code: 'boom');

      await expectLater(service.stop(), completes);
    });

    test('isRunning 返回原生结果', () async {
      handler = (_) => true;
      expect(await service.isRunning(), isTrue);
    });

    test('isRunning 在异常时保守返回 false', () async {
      handler = (_) => throw PlatformException(code: 'boom');
      expect(await service.isRunning(), isFalse);
    });

    test('isRunning 在通道缺失时返回 false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      expect(await service.isRunning(), isFalse);
    });

    test('notifyTransferCompleted 转发合并后的条数', () async {
      await service.notifyTransferCompleted(3);

      expect(calls.single.method, 'notifyTransferCompleted');
      expect(calls.single.arguments, {'count': 3});
    });

    test('notifyTransferCompleted 不因原生异常而抛出', () async {
      handler = (_) => throw PlatformException(code: 'transfer_notify_failed');

      await expectLater(service.notifyTransferCompleted(1), completes);
    });

    group('consumeOpenTransfersAction', () {
      test('原生返回 openTransfers 时为 true，并调用 getLaunchAction', () async {
        handler = (_) => 'openTransfers';

        expect(await service.consumeOpenTransfersAction(), isTrue);
        expect(calls.single.method, 'getLaunchAction');
      });

      test('原生返回 null（没有待处理动作）时为 false', () async {
        // 这是「从后台普通切回来」的形态：原生侧已经把自己的标志清掉了。
        handler = (_) => null;

        expect(await service.consumeOpenTransfersAction(), isFalse);
      });

      test('未知的原生返回值按 false 处理，不当成 true 放行', () async {
        // 只在精确等于 'openTransfers' 时才跳转，避免原生侧将来加了别的
        // action 名时被误判成「打开传输列表」。
        handler = (_) => 'somethingElse';

        expect(await service.consumeOpenTransfersAction(), isFalse);
      });

      test('通道缺失时返回 false（非 Android 平台 / 测试环境）', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);

        expect(await service.consumeOpenTransfersAction(), isFalse);
      });

      test('原生抛异常时返回 false，不阻断启动路径', () async {
        handler = (_) => throw PlatformException(code: 'boom');

        expect(await service.consumeOpenTransfersAction(), isFalse);
      });
    });
  });

  group('KeepAliveCoordinator', () {
    late _RecordingService service;
    late KeepAliveCoordinator coordinator;

    setUp(() {
      service = _RecordingService();
      coordinator = KeepAliveCoordinator(service);
    });

    test('第一个连接启动前台服务并带上会话数', () async {
      await coordinator.addSession('s1');

      expect(service.startCalls, [1]);
      expect(service.updateCalls, [1]);
      expect(service.stopCalls, 0);
      expect(coordinator.hasActiveSessions, isTrue);
    });

    test('第二个连接只更新数量，不重复 stop', () async {
      await coordinator.addSession('s1');
      await coordinator.addSession('s2');

      expect(service.startCalls, [1, 2]);
      expect(service.updateCalls, [1, 2]);
      expect(service.stopCalls, 0);
      expect(coordinator.activeCount, 2);
    });

    test('重复添加同一 server 不增加计数', () async {
      await coordinator.addSession('s1');
      await coordinator.addSession('s1');

      expect(coordinator.activeCount, 1);
      expect(service.startCalls, [1, 1]);
    });

    test('最后一个连接移除后停止前台服务（避免僵尸通知）', () async {
      await coordinator.addSession('s1');
      await coordinator.removeSession('s1');

      expect(service.stopCalls, 1);
      expect(coordinator.hasActiveSessions, isFalse);
    });

    test('仍有余量连接时不停止服务', () async {
      await coordinator.addSession('s1');
      await coordinator.addSession('s2');
      await coordinator.removeSession('s1');

      expect(service.stopCalls, 0);
      expect(service.updateCalls, [1, 2, 1]);
      expect(coordinator.activeCount, 1);
    });

    test('移除不存在的连接不会误停服务', () async {
      await coordinator.addSession('s1');
      await coordinator.removeSession('nope');

      expect(service.stopCalls, 0);
      expect(coordinator.activeCount, 1);
    });

    test('clear 清空并停止服务', () async {
      await coordinator.addSession('s1');
      await coordinator.addSession('s2');
      await coordinator.clear();

      expect(service.stopCalls, 1);
      expect(coordinator.hasActiveSessions, isFalse);
    });

    test('start 失败（后台被拒）也不会抛异常', () async {
      service.startResult = false;

      await expectLater(coordinator.addSession('s1'), completes);
      expect(coordinator.hasActiveSessions, isTrue);
    });
  });

  group('DesktopKeepAliveService (Task D3)', () {
    const desktopService = DesktopKeepAliveService();

    test('start 安全返回 false 且不抛异常', () async {
      final result = await desktopService.start(3);
      expect(result, isFalse);
    });

    test('updateSessionCount 静默完成且不抛异常', () async {
      await expectLater(desktopService.updateSessionCount(5), completes);
    });

    test('stop 静默完成且不抛异常', () async {
      await expectLater(desktopService.stop(), completes);
    });

    test('isRunning 始终返回 false', () async {
      final result = await desktopService.isRunning();
      expect(result, isFalse);
    });

    test('notifyTransferCompleted 静默完成且不抛异常', () async {
      await expectLater(desktopService.notifyTransferCompleted(10), completes);
    });

    test('consumeOpenTransfersAction 返回 false', () async {
      final result = await desktopService.consumeOpenTransfersAction();
      expect(result, isFalse);
    });
  });
}
