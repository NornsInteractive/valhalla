import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/providers/reconnect_provider.dart';
import 'package:valhalla/core/services/keep_alive_service.dart';
import 'package:valhalla/core/utils/reconnect_backoff.dart';
import 'package:valhalla/data/models/server_profile.dart';

/// 手动触发的调度器：把「等待」变成测试可完全掌控的一步。
///
/// 这是本文件能快速跑完的关键 —— 真实 Timer 会让每个重连测试都要
/// 等好几秒，也会引入时序抖动。
class _FakeScheduler {
  /// 每次排期记一条；已被 fire 或 cancel 的条目置空以免重复执行。
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

  /// 执行最近一次未执行的排期，返回它排期的延迟。
  Duration fireLatest() {
    final index = pending.lastIndexWhere((entry) => entry.action != null);
    if (index < 0) {
      fail('没有待执行的排期，但测试期望有一次');
    }
    final entry = pending[index];
    pending[index] = (delay: entry.delay, action: null);
    entry.action!.call();
    return entry.delay;
  }

  /// 仍待执行的排期数量。
  int get pendingCount => pending.where((e) => e.action != null).length;

  Duration get latestDelay => pending.last.delay;
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

ServerProfile _server() => const ServerProfile(
  id: 's1',
  name: 'Prod',
  host: 'example.com',
  port: 22,
  username: 'dev',
  authType: AuthType.password,
);

void main() {
  group('ReconnectController 状态机', () {
    late _FakeScheduler scheduler;
    late List<ReconnectState> states;
    late List<String> connectCalls;
    late ReconnectController controller;

    setUp(() {
      scheduler = _FakeScheduler();
      states = [];
      connectCalls = [];
      controller = ReconnectController(
        connectAttempt: (server) async => connectCalls.add(server.id),
        scheduler: scheduler.call,
        backoff: const ReconnectBackoff(jitterRatio: 0),
      );
      controller.onStateChanged = states.add;
    });

    tearDown(() => controller.dispose());

    test('start 后进入 connecting', () {
      controller.start(_server());
      expect(controller.state.status, ReconnectStatus.connecting);
      expect(controller.userIntent, isTrue);
    });

    test('markConnected 进入 connected', () {
      controller.start(_server());
      controller.markConnected();
      expect(controller.state.isConnected, isTrue);
      expect(controller.state.attempt, 0);
    });

    test('markConnected 幂等：已 connected 时一次也不再广播', () {
      controller.start(_server());
      controller.markConnected();
      expect(states.map((s) => s.status), [
        ReconnectStatus.connecting,
        ReconnectStatus.connected,
      ]);
      final emissions = states.length;

      // 前台健康检查会反复调用它；重复广播会让终端/指标重新订阅一遍。
      controller.markConnected();
      controller.markConnected();
      controller.markConnected();

      expect(
        states,
        hasLength(emissions),
        reason: '已 connected 时重复 markConnected 必须是零副作用',
      );
      expect(controller.state.isConnected, isTrue);
      expect(controller.state.attempt, 0);
      expect(controller.state.nextDelay, isNull);
      expect(controller.userIntent, isTrue);
    });

    test('重复 markConnected 之后掉线仍只排一次期', () {
      controller.start(_server());
      controller.markConnected();
      for (var i = 0; i < 5; i++) {
        controller.markConnected();
      }

      controller.handleTransportDied();

      expect(controller.state.status, ReconnectStatus.reconnecting);
      expect(controller.state.attempt, 1);
      expect(controller.state.nextDelay, const Duration(seconds: 1));
      expect(scheduler.pendingCount, 1, reason: '重复的健康广播不得让退避从 1s 跳到 2s');
    });

    test('恢复连接后再连击 markConnected，状态机仍只走一次转换', () async {
      controller.start(_server());
      controller.markConnected();
      controller.handleTransportDied();
      // 重连成功：attempt 归零并回到 connected。
      expect(scheduler.fireLatest(), const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.isConnected, isTrue);
      expect(controller.state.attempt, 0);
      final emissions = states.length;

      for (var i = 0; i < 3; i++) {
        controller.markConnected();
      }
      expect(states, hasLength(emissions));

      // 幂等没有把状态机搞坏：掉线仍然只排一次 attempt 1。
      controller.handleTransportDied();
      expect(controller.state.attempt, 1);
      expect(scheduler.pendingCount, 1);
    });

    test('掉线后按退避排期重连', () {
      controller.start(_server());
      controller.markConnected();
      controller.handleTransportDied();

      expect(controller.state.status, ReconnectStatus.reconnecting);
      expect(controller.state.attempt, 1);
      expect(controller.state.nextDelay, const Duration(seconds: 1));
    });

    test('连续失败时退避递增，且每次真的调用连接函数', () async {
      final failing = ReconnectController(
        connectAttempt: (server) async {
          connectCalls.add(server.id);
          throw SSHConnectionException('still down');
        },
        scheduler: scheduler.call,
        backoff: const ReconnectBackoff(jitterRatio: 0),
      );
      addTearDown(failing.dispose);

      failing.start(_server());

      // 第 1 次排期 → 1s
      failing.handleTransportDied();
      expect(failing.state.nextDelay, const Duration(seconds: 1));

      // 执行第 1 次尝试 → 失败 → 自动排期第 2 次，间隔 2s
      scheduler.fireLatest();
      await Future<void>.delayed(Duration.zero);
      expect(connectCalls, hasLength(1));
      expect(
        failing.state.nextDelay,
        const Duration(seconds: 2),
        reason: '连续失败时退避必须递增',
      );

      // 执行第 2 次尝试 → 失败 → 排期第 3 次，间隔 4s
      scheduler.fireLatest();
      await Future<void>.delayed(Duration.zero);
      expect(connectCalls, hasLength(2));
      expect(failing.state.nextDelay, const Duration(seconds: 4));
    });

    test('无限重试：持续失败也永不放弃', () async {
      final failing = ReconnectController(
        connectAttempt: (server) async {
          connectCalls.add(server.id);
          throw SSHConnectionException('still down');
        },
        scheduler: scheduler.call,
        backoff: const ReconnectBackoff(jitterRatio: 0),
      );
      addTearDown(failing.dispose);

      failing.start(_server());
      failing.handleTransportDied();

      // 连续失败 20 次，远超旧实现可能设的 5 次上限。
      for (var i = 0; i < 20; i++) {
        scheduler.fireLatest();
        await Future<void>.delayed(Duration.zero);
      }

      expect(connectCalls, hasLength(20));
      expect(failing.state.status, ReconnectStatus.reconnecting);
      expect(failing.state.retryable, isTrue);
      expect(failing.isPending, isTrue, reason: '必须仍在排期下一次重试');

      // 间隔封顶在 30s，而不是放弃。
      expect(failing.state.nextDelay, const Duration(seconds: 30));
    });

    test('用户主动断开后不再重连', () async {
      controller.start(_server());
      controller.markConnected();
      controller.userDisconnect();

      expect(controller.state.status, ReconnectStatus.idle);
      expect(controller.userIntent, isFalse);

      // 即使收到掉线事件也必须无动于衷。
      controller.handleTransportDied();
      expect(controller.state.status, ReconnectStatus.idle);
      expect(scheduler.pendingCount, 0);
    });

    test('App detached 时暂停重连，回前台立刻重试', () async {
      controller.start(_server());
      controller.markConnected();
      controller.handleTransportDied();

      controller.setAppDetached(true);
      expect(controller.state.status, ReconnectStatus.idle);

      // detached 期间的掉线事件不应排期。
      unawaited(Future<void>.value());
      final before = scheduler.pendingCount;
      controller.handleTransportDied();
      expect(scheduler.pendingCount, before);

      // 回前台：用户意图仍在，应立刻重试（不等退避）。
      controller.setAppDetached(false);
      expect(controller.state.status, ReconnectStatus.reconnecting);
      expect(controller.state.nextDelay, Duration.zero);
    });

    test('回前台连击不会重复排期导致退避跳级', () async {
      // 真实路径里 `setAppDetached(false)` 与 `handleVerifyFailed()` 会在
      // 同一次回前台中先后触发。若两次都排期，attempt 会一次跳两级，
      // 退避从 1s 直接变 2s，用户体感是「刚切回来就要等更久」。
      final controller2 = ReconnectController(
        connectAttempt: (server) async => throw Exception('boom'),
        scheduler: scheduler.call,
        backoff: const ReconnectBackoff(jitterRatio: 0),
      );
      addTearDown(controller2.dispose);

      controller2.start(_server());
      controller2.setAppDetached(true);
      controller2.setAppDetached(false);
      controller2.handleVerifyFailed();

      expect(controller2.state.attempt, 1, reason: '一次回前台只算一次尝试');
      expect(scheduler.pendingCount, 1, reason: '同一时刻只应存在一个待触发的重试定时器');
    });

    test('主机密钥变更 → 不可重试并终止循环', () async {
      final failing = ReconnectController(
        connectAttempt: (server) async => throw HostKeyMismatchException(
          host: 'example.com:22',
          expectedFingerprint: 'SHA256:aaa',
          actualFingerprint: 'SHA256:bbb',
        ),
        scheduler: scheduler.call,
        backoff: const ReconnectBackoff(jitterRatio: 0),
      );
      addTearDown(failing.dispose);

      failing.start(_server());
      failing.handleTransportDied();
      scheduler.fireLatest();
      await Future<void>.delayed(Duration.zero);

      expect(failing.state.status, ReconnectStatus.failed);
      expect(failing.state.retryable, isFalse);
      expect(failing.isPending, isFalse, reason: '不应再排期下一次重试');

      // 再次掉线事件也不应重新排期。
      final before = scheduler.pendingCount;
      failing.handleTransportDied();
      expect(scheduler.pendingCount, before);
    });

    test('可重试的错误不会终止循环', () async {
      final failing = ReconnectController(
        connectAttempt: (server) async => throw SSHConnectionException('nope'),
        scheduler: scheduler.call,
        backoff: const ReconnectBackoff(jitterRatio: 0),
      );
      addTearDown(failing.dispose);

      failing.start(_server());
      failing.handleTransportDied();
      scheduler.fireLatest();
      await Future<void>.delayed(Duration.zero);

      expect(failing.state.status, ReconnectStatus.reconnecting);
      expect(failing.state.retryable, isTrue);
      expect(failing.isPending, isTrue);
    });

    test('重连成功后回到 connected 并清零计数', () async {
      controller.start(_server());
      controller.handleTransportDied();
      scheduler.fireLatest();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.isConnected, isTrue);
      expect(controller.state.attempt, 0);
      expect(controller.isPending, isFalse);
    });

    test('每次重试都重新建立连接（凭据不缓存）', () async {
      controller.start(_server());
      controller.markConnected();

      for (var i = 0; i < 3; i++) {
        controller.handleTransportDied();
        scheduler.fireLatest();
        await Future<void>.delayed(Duration.zero);
      }

      // 连接函数被调用 3 次 —— 凭据读取在 provider 注入的实现里，
      // 因此每次调用都会重新读取，不会复用旧密码。
      expect(connectCalls, ['s1', 's1', 's1']);
    });

    test('未 start 时掉线事件不触发任何排期', () {
      controller.handleTransportDied();
      expect(scheduler.pendingCount, 0);
      expect(controller.state.status, ReconnectStatus.idle);
    });

    test('handleVerifyFailed 与 transportDied 行为一致', () {
      controller.start(_server());
      controller.markConnected();
      controller.handleVerifyFailed();
      expect(controller.state.status, ReconnectStatus.reconnecting);
      expect(controller.state.attempt, 1);
    });

    test('dispose 后不再触发状态回调', () {
      controller.start(_server());
      final countBefore = states.length;
      controller.dispose();
      controller.handleTransportDied();
      expect(states.length, countBefore);
    });

    test('多个监听者都能收到通知，互不覆盖', () {
      // 单槽 onStateChanged 的问题：后注册的会覆盖先注册的，
      // 先注册者从此收不到任何通知。
      final first = <ReconnectState>[];
      final second = <ReconnectState>[];
      final a = controller.addStateListener(first.add);
      controller.addStateListener(second.add);
      addTearDown(a);

      controller.start(_server());

      expect(first, isNotEmpty, reason: '先注册的监听者不能被覆盖掉');
      expect(second, isNotEmpty);
    });

    test('取消订阅后不再收到通知', () {
      final received = <ReconnectState>[];
      final unsubscribe = controller.addStateListener(received.add);

      controller.start(_server());
      final countAfterStart = received.length;

      unsubscribe();
      controller.markConnected();

      expect(received.length, countAfterStart, reason: '取消后不该再被调用');
    });

    test('监听者在回调中取消订阅不会导致并发修改异常', () {
      final received = <ReconnectState>[];
      void Function()? unsubscribe;
      unsubscribe = controller.addStateListener((state) {
        received.add(state);
        unsubscribe?.call();
      });

      controller.start(_server());
      controller.markConnected();

      expect(received.length, 1, reason: '取消后不再收到第二次');
    });
  });

  group('arm/disarmConnectionSession', () {
    test('arm 会武装重连并启动前台服务', () async {
      final reconnect = ReconnectController(connectAttempt: (_) async {});
      final keepAlive = KeepAliveCoordinator(_ArmRecordingService());
      armConnectionSession(
        reconnect: reconnect,
        keepAlive: keepAlive,
        server: _server(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(reconnect.userIntent, isTrue);
      expect(reconnect.state.isConnected, isTrue);
      expect(keepAlive.hasActiveSessions, isTrue);
    });

    test('disarm 会清掉意图并停前台服务', () async {
      final reconnect = ReconnectController(connectAttempt: (_) async {});
      final keepAlive = KeepAliveCoordinator(_ArmRecordingService());
      armConnectionSession(
        reconnect: reconnect,
        keepAlive: keepAlive,
        server: _server(),
      );
      await Future<void>.delayed(Duration.zero);

      disarmConnectionSession(
        reconnect: reconnect,
        keepAlive: keepAlive,
        serverId: _server().id,
      );
      await Future<void>.delayed(Duration.zero);

      expect(reconnect.userIntent, isFalse);
      expect(keepAlive.hasActiveSessions, isFalse);
      reconnect.handleTransportDied();
      expect(reconnect.state.isReconnecting, isFalse);
    });

    test('arm 之后的健康 markConnected 不再广播', () async {
      final reconnect = ReconnectController(connectAttempt: (_) async {});
      addTearDown(reconnect.dispose);
      final emitted = <ReconnectState>[];
      reconnect.onStateChanged = emitted.add;
      final keepAlive = KeepAliveCoordinator(_ArmRecordingService());

      armConnectionSession(
        reconnect: reconnect,
        keepAlive: keepAlive,
        server: _server(),
      );
      await Future<void>.delayed(Duration.zero);
      final afterArm = emitted.length;
      expect(emitted.last.status, ReconnectStatus.connected);

      // 连上之后的健康复验只调 markConnected（见 connection_lifecycle）。
      reconnect.markConnected();
      reconnect.markConnected();

      expect(emitted, hasLength(afterArm), reason: '健康复验必须是零副作用，不得重新武装状态订阅');
      expect(reconnect.state.isConnected, isTrue);
      expect(reconnect.userIntent, isTrue);
      expect(keepAlive.hasActiveSessions, isTrue);
    });
  });
}

class _ArmRecordingService implements KeepAliveService {
  @override
  Future<bool> start(int sessionCount) async => true;

  @override
  Future<void> updateSessionCount(int sessionCount) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<bool> isRunning() async => true;

  @override
  Future<void> notifyTransferCompleted(int completedCount) async {}

  @override
  Future<bool> consumeOpenTransfersAction() async => false;
}
