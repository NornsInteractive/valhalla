import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/app_visibility_provider.dart';
import 'package:valhalla/core/providers/connection_lifecycle_provider.dart';
import 'package:valhalla/core/providers/reconnect_provider.dart';
import 'package:valhalla/core/services/keep_alive_service.dart';
import 'package:valhalla/core/utils/reconnect_backoff.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

/// 记录调用的假保活服务。
class _RecordingService implements KeepAliveService {
  final List<int> startCalls = [];
  int stopCalls = 0;
  bool running = false;

  @override
  Future<bool> start(int sessionCount) async {
    startCalls.add(sessionCount);
    running = true;
    return true;
  }

  @override
  Future<void> updateSessionCount(int sessionCount) async {}

  @override
  Future<void> stop() async {
    stopCalls++;
    running = false;
  }

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<void> notifyTransferCompleted(int completedCount) async {}

  @override
  Future<bool> consumeOpenTransfersAction() async => false;
}

/// 记录每次登记/撤销的是哪台服务器。
///
/// 协调器只暴露 `activeCount`，无法区分「换了服务器」和「多了一台」，
/// 所以这里把会话 id 也记录下来，断言才落得到具体服务器上。
class _RecordingKeepAlive extends KeepAliveCoordinator {
  _RecordingKeepAlive(super.service);

  final List<String> added = [];
  final List<String> removed = [];

  @override
  Future<void> addSession(String serverId) {
    added.add(serverId);
    return super.addSession(serverId);
  }

  @override
  Future<void> removeSession(String serverId) {
    removed.add(serverId);
    return super.removeSession(serverId);
  }
}

/// 只回答协调器真正用到的问题，其余调用一律报错。
///
/// `noSuchMethod` 故意抛错：后台恢复期间如果协调器开始调用别的东西，
/// 这个假对象会立刻把回归暴露出来，而不是悄悄返回默认值。
class _FakeSshManager implements SSHClientManager {
  bool connected = true;
  bool recent = false;
  int verifyCalls = 0;
  final List<String> probed = [];
  final List<String> disconnected = [];
  final List<bool> backgroundCalls = [];

  /// 让探活停在测试手里，用来制造「探测在飞时生命周期又变了」的竞态。
  final List<Completer<bool>> gates = [];
  bool holdProbes = false;

  /// 未挂起时探活直接给出的结果；false 表示探活确认死亡并清理连接。
  bool probeAlive = false;

  @override
  void setAppInBackground(bool value) => backgroundCalls.add(value);

  @override
  bool isConnected(String serverId) => connected;

  @override
  bool recentlyVerified(String serverId) => recent;

  @override
  Future<bool> verifyAlive(String serverId, {bool notifyDeath = true}) {
    verifyCalls++;
    probed.add(serverId);
    if (!holdProbes) {
      if (probeAlive) return Future.value(true);
      disconnect(serverId);
      return Future.value(false);
    }
    final gate = Completer<bool>();
    gates.add(gate);
    return gate.future;
  }

  /// 让被挂起的探活按真实存活结果落地。
  void release(bool alive) {
    for (final gate in gates) {
      if (!gate.isCompleted) gate.complete(alive);
    }
    gates.clear();
  }

  @override
  void disconnect(String serverId, {bool notifyDeath = false}) {
    disconnected.add(serverId);
    connected = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('未预期的调用: ${invocation.memberName}');
}

/// 手动触发的调度器：把退避等待变成测试可控的一步。
class _FakeScheduler {
  final List<({Duration delay, void Function()? action})> pending = [];

  Timer call(Duration delay, void Function() action) {
    pending.add((delay: delay, action: action));
    final index = pending.length - 1;
    return _FakeTimer(() {
      if (index < pending.length) {
        pending[index] = (delay: delay, action: null);
      }
    });
  }

  int get pendingCount => pending.where((e) => e.action != null).length;

  Duration fireLatest() {
    final index = pending.lastIndexWhere((entry) => entry.action != null);
    if (index < 0) fail('没有待执行的排期，但测试期望有一次');
    final entry = pending[index];
    pending[index] = (delay: entry.delay, action: null);
    entry.action!.call();
    return entry.delay;
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this._cancel);

  final void Function() _cancel;

  @override
  void cancel() => _cancel();

  @override
  bool get isActive => true;

  @override
  int get tick => 0;
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
  late _RecordingKeepAlive keepAlive;
  late _FakeSshManager ssh;
  late _FakeScheduler scheduler;
  late ReconnectController controller;
  ServerProfile? active;

  setUp(() {
    service = _RecordingService();
    keepAlive = _RecordingKeepAlive(service);
    ssh = _FakeSshManager();
    scheduler = _FakeScheduler();
    active = null;
    controller = ReconnectController(
      connectAttempt: (_) async {},
      scheduler: scheduler.call,
    );
  });

  tearDown(() => controller.dispose());

  ConnectionLifecycleCoordinator build({
    ReconnectController? withController,
    void Function(bool foreground)? onVisibilityChanged,
  }) => ConnectionLifecycleCoordinator(
    sshManager: ssh,
    reconnectController: withController ?? controller,
    keepAlive: keepAlive,
    activeServer: () => active,
    onVisibilityChanged: onVisibilityChanged,
  );

  group('回前台的探活', () {
    test('并发的 resumed 共用同一次复验', () async {
      final server = _server('a');
      active = server;
      controller.start(server);
      controller.markConnected();
      ssh.holdProbes = true;
      final lifecycle = build();

      final first = lifecycle.onResumed();
      final second = lifecycle.onResumed();

      expect(identical(first, second), isTrue, reason: '一次复验只该发一次探测');
      await Future<void>.delayed(Duration.zero);
      expect(ssh.verifyCalls, 1);

      ssh.release(true);
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(ssh.verifyCalls, 1);
    });

    test('短暂后台后复用近期已验证的连接，不再打扰远端', () async {
      final server = _server('a');
      active = server;
      controller.start(server);
      controller.markConnected();
      ssh.recent = true;
      final lifecycle = build();

      await lifecycle.onPaused();
      final alive = await lifecycle.onResumed();

      expect(alive, isTrue);
      expect(ssh.verifyCalls, 0, reason: '刚复验过的连接不该再被 ping 一遍');
      expect(ssh.probed, isEmpty);
    });

    test('不满足复用条件时仍然复验一次', () async {
      final server = _server('a');
      active = server;
      controller.start(server);
      controller.markConnected();
      ssh.recent = false;
      ssh.holdProbes = true;
      final lifecycle = build();

      final resuming = lifecycle.onResumed();
      await Future<void>.delayed(Duration.zero);
      expect(ssh.probed, ['a']);
      ssh.release(true);

      expect(await resuming, isTrue);
      expect(ssh.verifyCalls, 1);
    });

    test('复验失败触发重连排期', () async {
      final server = _server('a');
      active = server;
      controller.start(server);
      controller.markConnected();
      final lifecycle = build();

      expect(await lifecycle.onResumed(), isFalse);
      expect(ssh.disconnected, contains('a'));
      expect(controller.state.isReconnecting, isTrue);
      expect(scheduler.pendingCount, 1, reason: '必须排期一次重连');
    });

    test('用户已主动断开时，复验失败不得排重连', () async {
      final server = _server('a');
      active = server;
      controller.start(server);
      controller.markConnected();
      controller.userDisconnect();
      final lifecycle = build();

      expect(await lifecycle.onResumed(), isFalse);
      expect(controller.state.isReconnecting, isFalse, reason: '用户明确断开了，重连必须停');
      expect(scheduler.pendingCount, 0);
      expect(keepAlive.removed, ['a'], reason: '死掉的会话要撤掉前台通知');
      expect(keepAlive.activeCount, 0);
    });

    test('从未武装过连接时，复验失败也不排重连', () async {
      final server = _server('a');
      active = server;
      final lifecycle = build();

      expect(await lifecycle.onResumed(), isFalse);
      expect(scheduler.pendingCount, 0);
    });

    test('本来就没连上但仍想保持连接时立刻排重连', () async {
      final server = _server('a');
      active = server;
      controller.start(server);
      controller.markConnected();
      ssh.connected = false;
      final lifecycle = build();

      expect(await lifecycle.onResumed(), isFalse);
      expect(ssh.verifyCalls, 0, reason: '已经不在连接表里，无需再 ping');
      expect(controller.state.isReconnecting, isTrue);
      expect(scheduler.pendingCount, 1);
    });
  });

  group('旧代次隔离', () {
    test('探测在飞时进入后台，旧结果不得触发重连', () async {
      final server = _server('a');
      active = server;
      controller.start(server);
      controller.markConnected();
      ssh.holdProbes = true;
      final lifecycle = build();

      final resuming = lifecycle.onResumed();
      await Future<void>.delayed(Duration.zero);
      expect(ssh.verifyCalls, 1);

      await lifecycle.onPaused();
      // 迟到的复验结果属于上一个代次：回来时已经重新排过期了。
      ssh.release(false);

      expect(await resuming, isFalse);
      expect(
        controller.state.isReconnecting,
        isFalse,
        reason: '过期的复验结果不得再改动状态机',
      );
      expect(scheduler.pendingCount, 0);
    });

    test('探测在飞时切换服务器，旧服务器的结果不得排重连', () async {
      final first = _server('a');
      final second = _server('b');
      active = first;
      controller.start(first);
      controller.markConnected();
      ssh.holdProbes = true;
      final lifecycle = build();

      final resuming = lifecycle.onResumed();
      await Future<void>.delayed(Duration.zero);
      expect(ssh.probed, ['a']);

      // 用户在另一台服务器上连接：旧服务器的探测结果已经过期。
      active = second;
      controller.start(second);
      ssh.release(false);

      expect(await resuming, isFalse);
      expect(controller.serverId, 'b');
      expect(
        controller.state.status,
        isNot(ReconnectStatus.reconnecting),
        reason: '旧服务器的失败不得把新服务器的连接翻成重连中',
      );

      ssh.holdProbes = false;
      ssh.probeAlive = true;
      ssh.connected = true;
      expect(await lifecycle.onResumed(), isTrue);
      expect(ssh.probed, ['a', 'b'], reason: '新服务器必须被独立复验');
    });

    test('后台标记只上报一次，重复 paused 幂等', () async {
      final server = _server('a');
      active = server;
      controller.start(server);
      controller.markConnected();
      final visibility = <bool>[];
      final lifecycle = build(onVisibilityChanged: visibility.add);

      await lifecycle.onPaused();
      await lifecycle.onPaused();
      await lifecycle.onDetached();

      expect(visibility, [false], reason: '重复后台回调不得重复上报');
      expect(ssh.backgroundCalls, [true]);

      await lifecycle.onResumed();
      expect(visibility, [false, true]);
      expect(ssh.backgroundCalls, [true, false]);
      expect(lifecycle.inBackground, isFalse);
    });
  });

  group('后台与退出', () {
    test('detached 不撤前台服务，暂停重试但保留用户意图', () async {
      final server = _server('a');
      active = server;
      controller.start(server);
      controller.markConnected();
      final lifecycle = build();

      await lifecycle.onDetached();

      expect(service.stopCalls, 0);
      expect(controller.userIntent, isTrue);
      controller.handleTransportDied();
      expect(
        controller.state.isReconnecting,
        isFalse,
        reason: '划掉任务不等于用户要断开，但后台必须暂停重试',
      );
      expect(controller.userIntent, isTrue, reason: '暂停不改变用户保持连接的意图');
      expect(scheduler.pendingCount, 0, reason: '后台期间不得排任何重试');

      // 回前台先复验：连接还活着就直接回到已连接，不空转重连。
      ssh.probeAlive = true;
      expect(await lifecycle.onResumed(), isTrue);
      await pumpEventQueue();
      expect(controller.state.isConnected, isTrue);
      expect(controller.userIntent, isTrue);
      expect(scheduler.pendingCount, 0, reason: '复验通过就不用重连');
      expect(service.stopCalls, 0, reason: '整个过程都不许撤掉前台服务');
    });

    test('后台一次尝试都不发，回前台复验失败后恰好补试一次', () async {
      final server = _server('a');
      active = server;
      var attempts = 0;
      final own = ReconnectController(
        connectAttempt: (_) async {
          attempts++;
        },
        scheduler: scheduler.call,
      );
      own.start(server);
      own.markConnected();
      final lifecycle = build(withController: own);

      await lifecycle.onDetached();
      ssh.probeAlive = false;
      own.handleTransportDied();

      expect(own.state.isReconnecting, isFalse, reason: '后台必须暂停重试');
      expect(scheduler.pendingCount, 0, reason: '后台一次排期都不许有');
      expect(attempts, 0, reason: '后台一次连接都不许建');
      expect(own.userIntent, isTrue, reason: '暂停不等于用户断开');

      expect(await lifecycle.onResumed(), isFalse, reason: '复验失败必须如实上报');
      expect(ssh.verifyCalls, 1, reason: '回前台只探活一次');
      expect(scheduler.pendingCount, 1, reason: '复验失败后恰好排一次补试，不多不少');
      expect(
        scheduler.pending.single.delay,
        Duration.zero,
        reason: '回前台的补试是立即的，不等退避',
      );
      expect(attempts, 0, reason: '补试排期了但还没跑');

      expect(scheduler.fireLatest(), Duration.zero);
      await pumpEventQueue();

      expect(attempts, 1, reason: '补试恰好跑一次');
      expect(own.state.isConnected, isTrue, reason: '补试成功后回到已连接');
      expect(scheduler.pendingCount, 0, reason: '成功后排期表必须清空');
      expect(own.userIntent, isTrue);
    });

    test('重连期间同一服务器的前台服务仍然保留', () async {
      final server = _server('a');
      active = server;
      controller.start(server);
      controller.markConnected();
      ssh.connected = false;
      final lifecycle = build();

      await lifecycle.onResumed();
      await pumpEventQueue();

      expect(keepAlive.activeCount, 1, reason: '重连中的会话仍然需要进程保活');
      expect(service.startCalls, [1]);
      expect(keepAlive.removed, isEmpty);
    });

    test('切到别的服务器时登记新的会话服务器', () async {
      active = _server('a');
      controller.start(_server('a'));
      controller.markConnected();
      ssh.recent = true;
      final lifecycle = build();
      await lifecycle.onPaused();
      expect(keepAlive.added, ['a']);

      active = _server('b');
      controller.start(_server('b'));
      controller.markConnected();
      await lifecycle.onResumed();

      expect(keepAlive.added, ['a', 'b']);
      expect(keepAlive.activeCount, 2);
    });

    test('切回原服务器不会重复计数', () async {
      final server = _server('a');
      active = server;
      controller.start(server);
      controller.markConnected();
      ssh.recent = true;
      final lifecycle = build();

      await lifecycle.onPaused();
      await lifecycle.onResumed();

      expect(keepAlive.activeCount, 1, reason: '同一台服务器只算一个会话');
      expect(service.startCalls, [1]);
    });
  });

  group('appVisibilityProvider', () {
    test('默认前台，重复赋值不产生多余通知', () {
      var notifications = 0;
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      container.listen<bool>(
        appVisibilityProvider,
        (_, _) => notifications++,
        fireImmediately: false,
      );

      expect(container.read(appVisibilityProvider), isTrue);

      final notifier = container.read(appVisibilityProvider.notifier);
      notifier.setForeground(false);
      notifier.setForeground(false);
      notifier.setForeground(true);

      expect(notifications, 2);
      expect(container.read(appVisibilityProvider), isTrue);
    });
  });
}
