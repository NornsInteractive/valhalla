import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/providers/reconnect_provider.dart';
import 'package:valhalla/core/utils/reconnect_backoff.dart';
import 'package:valhalla/data/models/server_profile.dart';

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
  late _FakeScheduler scheduler;
  late ReconnectController controller;
  late List<ServerProfile> attempts;

  setUp(() {
    scheduler = _FakeScheduler();
    attempts = [];
    controller = ReconnectController(
      connectAttempt: (server) async => attempts.add(server),
      scheduler: scheduler.call,
      backoff: const ReconnectBackoff(jitterRatio: 0),
    );
  });

  tearDown(() => controller.dispose());

  group('重连尝试的单飞', () {
    test('连接尝试在飞时再次掉线不会并发发起第二次', () async {
      final gate = Completer<void>();
      final single = ReconnectController(
        connectAttempt: (_) => gate.future,
        scheduler: scheduler.call,
        backoff: const ReconnectBackoff(jitterRatio: 0),
      );
      addTearDown(single.dispose);

      single.start(_server('a'));
      single.handleTransportDied();
      scheduler.fireLatest();
      await Future<void>.delayed(Duration.zero);

      // 第一次尝试还在握手，远端又报了一次掉线。
      single.handleTransportDied();
      single.handleVerifyFailed();
      expect(scheduler.pendingCount, 0, reason: '同代次内不得在已有尝试时再排一次');
      expect(single.state.attempt, 1, reason: 'attempt 计数不得跳级');

      gate.complete();
      await pumpEventQueue();
      expect(single.state.isConnected, isTrue);
    });

    test('尝试失败后只排下一次，且退避按代次递进', () async {
      final failing = ReconnectController(
        connectAttempt: (server) async {
          attempts.add(server);
          throw SSHConnectionException('still down');
        },
        scheduler: scheduler.call,
        backoff: const ReconnectBackoff(jitterRatio: 0),
      );
      addTearDown(failing.dispose);

      failing.start(_server('a'));
      failing.handleTransportDied();
      expect(scheduler.fireLatest(), const Duration(seconds: 1));
      await pumpEventQueue();

      expect(attempts, hasLength(1));
      expect(scheduler.pendingCount, 1, reason: '失败后必须继续重试');
      expect(scheduler.fireLatest(), const Duration(seconds: 2));
      await pumpEventQueue();
      expect(attempts, hasLength(2));
    });

    test('成功后才触发一次 onReconnected', () async {
      var reconnected = 0;
      final single = ReconnectController(
        connectAttempt: (_) async {},
        scheduler: scheduler.call,
        backoff: const ReconnectBackoff(jitterRatio: 0),
        onReconnected: (_) async => reconnected++,
      );
      addTearDown(single.dispose);

      single.start(_server('a'));
      single.handleTransportDied();
      scheduler.fireLatest();
      await pumpEventQueue();

      expect(single.state.isConnected, isTrue);
      expect(reconnected, 1);
    });
  });

  group('旧代次隔离', () {
    test('用户在握手期间断开：迟到的成功不得改状态或再排期', () async {
      final gate = Completer<void>();
      final single = ReconnectController(
        connectAttempt: (_) => gate.future,
        scheduler: scheduler.call,
        backoff: const ReconnectBackoff(jitterRatio: 0),
      );
      addTearDown(single.dispose);

      single.start(_server('a'));
      single.handleTransportDied();
      scheduler.fireLatest();
      await Future<void>.delayed(Duration.zero);

      single.userDisconnect();
      gate.complete();
      await pumpEventQueue();

      expect(
        single.state.status,
        ReconnectStatus.idle,
        reason: '用户已断开，任何迟到结果都不该把它翻成已连接',
      );
      expect(scheduler.pendingCount, 0, reason: '断开后不得再排重连');
    });

    test('握手期间切换服务器：迟到成功不得替新服务器宣布已连接', () async {
      final gate = Completer<void>();
      var reconnected = 0;
      final single = ReconnectController(
        connectAttempt: (_) => gate.future,
        scheduler: scheduler.call,
        backoff: const ReconnectBackoff(jitterRatio: 0),
        onReconnected: (_) async => reconnected++,
      );
      addTearDown(single.dispose);

      single.start(_server('a'));
      single.handleTransportDied();
      scheduler.fireLatest();
      await Future<void>.delayed(Duration.zero);

      single.start(_server('b'));
      gate.complete();
      await pumpEventQueue();

      expect(single.serverId, 'b');
      expect(
        single.state.status,
        ReconnectStatus.connecting,
        reason: '旧服务器的成功不代表新服务器连上了',
      );
      expect(reconnected, 0);
    });

    test('detach 期间丢弃迟到成功，回前台立刻重试', () async {
      final gate = Completer<void>();
      final single = ReconnectController(
        connectAttempt: (_) => gate.future,
        scheduler: scheduler.call,
        backoff: const ReconnectBackoff(jitterRatio: 0),
      );
      addTearDown(single.dispose);

      single.start(_server('a'));
      single.handleTransportDied();
      scheduler.fireLatest();
      await Future<void>.delayed(Duration.zero);

      single.setAppDetached(true);
      gate.complete();
      await pumpEventQueue();
      expect(single.state.status, isNot(ReconnectStatus.connected));

      single.setAppDetached(false);
      expect(scheduler.pendingCount, 1, reason: '回到前台且用户仍想连着，应立刻重试而不是等剩余退避');
      expect(scheduler.fireLatest(), Duration.zero);
    });

    test('dispose 之后迟到的成功被丢弃', () async {
      final gate = Completer<void>();
      final single = ReconnectController(
        connectAttempt: (_) => gate.future,
        scheduler: scheduler.call,
        backoff: const ReconnectBackoff(jitterRatio: 0),
        onReconnected: (_) async => fail('dispose 后不得再挂载消费者'),
      );
      single.start(_server('a'));
      single.handleTransportDied();
      scheduler.fireLatest();
      await Future<void>.delayed(Duration.zero);

      single.dispose();
      gate.complete();
      await pumpEventQueue();

      expect(scheduler.pendingCount, 0);
    });
  });

  group('maintains：凭据竞态的判定依据', () {
    test('start 之后维持该服务器', () {
      final server = _server('a');
      controller.start(server);
      expect(controller.maintains(server), isTrue);
    });

    test('用户断开后不再维持', () {
      final server = _server('a');
      controller.start(server);
      controller.userDisconnect();
      expect(controller.maintains(server), isFalse);
    });

    test('换到别的服务器后不再维持旧的', () {
      final first = _server('a');
      final second = _server('b');
      controller.start(first);
      controller.start(second);
      expect(controller.maintains(first), isFalse);
      expect(controller.maintains(second), isTrue);
    });

    test('dispose 之后不再维持', () {
      final server = _server('a');
      controller.start(server);
      controller.dispose();
      expect(controller.maintains(server), isFalse);
    });
  });
}
