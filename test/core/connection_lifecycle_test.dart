import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/connection_lifecycle_provider.dart';
import 'package:valhalla/core/providers/reconnect_provider.dart';
import 'package:valhalla/core/services/keep_alive_service.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

/// 记录调用的假保活服务。
class _RecordingService implements KeepAliveService {
  final List<int> startCalls = [];
  final List<int> updateCalls = [];
  int stopCalls = 0;

  @override
  Future<bool> start(int sessionCount) async {
    startCalls.add(sessionCount);
    return true;
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

/// 假 SSH 管理器，只回答本测试关心的问题。
class _FakeSshManager implements SSHClientManager {
  _FakeSshManager();

  bool connected = true;
  bool alive = true;
  int verifyCalls = 0;
  final List<String> disconnected = [];
  // 真实实现会在这里清掉死连接，测试记录调用以便断言「有没有被通知」。
  bool throwOnDisconnect = false;

  @override
  bool isConnected(String serverId) => connected;

  @override
  Future<bool> verifyAlive(String serverId) async {
    verifyCalls++;
    if (!alive) {
      // 与真实实现保持一致：探活失败即清理连接。
      disconnect(serverId);
    }
    return alive;
  }

  @override
  void disconnect(String serverId, {bool notifyDeath = false}) {
    if (throwOnDisconnect) throw StateError('unexpected disconnect');
    disconnected.add(serverId);
    connected = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('未预期的调用: ${invocation.memberName}');
}

ServerProfile _server(String id) => ServerProfile(
  id: id,
  name: 'server-$id',
  host: '10.0.0.1',
  port: 22,
  username: 'dev',
);

void main() {
  late _RecordingService service;
  late KeepAliveCoordinator keepAlive;
  late _FakeSshManager ssh;
  late ReconnectController controller;

  setUp(() {
    service = _RecordingService();
    keepAlive = KeepAliveCoordinator(service);
    ssh = _FakeSshManager();
    controller = ReconnectController(connectAttempt: (_) async {});
  });

  ConnectionLifecycleCoordinator build({
    ServerProfile? server,
    ReconnectController? withController,
  }) {
    return ConnectionLifecycleCoordinator(
      sshManager: ssh,
      reconnectController: withController ?? controller,
      keepAlive: keepAlive,
      activeServer: () => server,
    );
  }

  group('ConnectionLifecycleCoordinator 回前台', () {
    test('resumed 会立刻复验连接，而不是等心跳', () async {
      final server = _server('a');
      controller.start(server);
      controller.markConnected();
      final lifecycle = build(server: server);

      final alive = await lifecycle.onResumed();

      expect(alive, isTrue);
      expect(ssh.verifyCalls, 1, reason: '回前台必须主动探活一次');
    });

    test('复验失败时触发重连排期', () async {
      final server = _server('a');
      controller.start(server);
      controller.markConnected();

      ssh.alive = false;
      final lifecycle = build(server: server);

      final alive = await lifecycle.onResumed();

      expect(alive, isFalse);
      expect(ssh.disconnected, contains('a'), reason: '死连接必须被清掉');
      expect(
        controller.state.isReconnecting,
        isTrue,
        reason: '探活失败必须把状态翻成 reconnecting，让用户看到真实情况',
      );
    });

    test('本来就没连上且未武装时不复验也不排期', () async {
      final server = _server('a');
      ssh.connected = false;
      final lifecycle = build(server: server);

      await lifecycle.onResumed();

      expect(ssh.verifyCalls, 0, reason: '没连上就没什么可复验的');
      expect(controller.state.isReconnecting, isFalse);
    });

    test('已武装但连接已不在时回前台立即重连', () async {
      final server = _server('a');
      controller.start(server);
      controller.markConnected();
      ssh.connected = false;
      final lifecycle = build(server: server);

      await lifecycle.onResumed();

      expect(ssh.verifyCalls, 0);
      expect(
        controller.state.isReconnecting,
        isTrue,
        reason: '用户还想连着，回前台必须立刻排期，不能干等心跳',
      );
    });

    test('没有活跃服务器时安全返回 true 且不做任何事', () async {
      final lifecycle = build();

      expect(await lifecycle.onResumed(), isTrue);
      expect(ssh.verifyCalls, 0);
      expect(service.startCalls, isEmpty);
    });

    test('resumed 会清掉 detached 标志，让重连可以继续', () async {
      final server = _server('a');
      controller.start(server);
      controller.markConnected();
      final lifecycle = build(server: server);

      await lifecycle.onDetached();
      expect(lifecycle.inBackground, isTrue);

      await lifecycle.onResumed();
      expect(lifecycle.inBackground, isFalse, reason: '用户回来了就该继续维持连接');
    });

    test('自动重连未启用（controller 为 null）时不崩溃', () async {
      final server = _server('a');
      final lifecycle = ConnectionLifecycleCoordinator(
        sshManager: ssh,
        reconnectController: null,
        keepAlive: keepAlive,
        activeServer: () => server,
      );

      ssh.alive = false;
      expect(await lifecycle.onResumed(), isFalse);
    });
  });

  group('ConnectionLifecycleCoordinator 后台与退出', () {
    test('paused 时把已连接的服务器登记进前台服务', () async {
      final server = _server('a');
      final lifecycle = build(server: server);

      await lifecycle.onPaused();

      expect(service.startCalls, [1]);
      expect(service.updateCalls, [1]);
    });

    test('paused 时未连接则不启动前台服务', () async {
      final server = _server('a');
      ssh.connected = false;
      final lifecycle = build(server: server);

      await lifecycle.onPaused();

      expect(service.startCalls, isEmpty, reason: '没有活跃会话不该挂常驻通知');
      expect(service.stopCalls, 1);
    });

    test('detached 不停止前台服务，也不暂停重连', () async {
      final server = _server('a');
      controller.start(server);
      controller.markConnected();
      final lifecycle = build(server: server);

      await lifecycle.onPaused();
      await lifecycle.onDetached();

      expect(service.stopCalls, 0, reason: 'Activity detached 时 FGS 仍在托着进程');

      controller.handleTransportDied();
      expect(controller.state.isReconnecting, isTrue, reason: '划掉任务不等于用户断开');
    });

    test('detached 保留用户意图，回前台能恢复重连', () async {
      var attempts = 0;
      final server = _server('a');
      final own = ReconnectController(
        connectAttempt: (_) async {
          attempts++;
        },
      );
      own.start(server);
      final lifecycle = build(server: server, withController: own);

      await lifecycle.onDetached();
      expect(own.userIntent, isTrue, reason: '用户没说不想连，只是想退出进程');

      await lifecycle.onResumed();
      // resumed 里 setAppDetached(false) 会对未连接状态立刻重试。
      await Future<void>.delayed(Duration.zero);
      expect(attempts, greaterThan(0));
    });

    test('inactive 不产生任何副作用（过渡态）', () async {
      final server = _server('a');
      final lifecycle = build(server: server);

      // inactive 由 main.dart 直接忽略，这里断言协调器本身没有被调用。
      expect(service.startCalls, isEmpty);
      expect(ssh.verifyCalls, 0);
      expect(lifecycle.inBackground, isFalse);
    });
  });

  group('ConnectionLifecycleCoordinator 保活同步', () {
    test('已连接时重复同步不会重复计数', () async {
      final server = _server('a');
      final lifecycle = build(server: server);

      await lifecycle.onPaused();
      await lifecycle.onPaused();

      expect(keepAlive.activeCount, 1, reason: '同一个服务器只该算一个会话');
      expect(service.updateCalls, [1, 1]);
    });

    test('断开的服务器会被移出保活集合', () async {
      final server = _server('a');
      final lifecycle = build(server: server);

      await lifecycle.onPaused();
      expect(keepAlive.activeCount, 1);

      ssh.connected = false;
      await lifecycle.onPaused();
      expect(keepAlive.activeCount, 0);
    });
  });
}
