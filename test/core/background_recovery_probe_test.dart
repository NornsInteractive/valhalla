import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

/// A client whose `ping()` never completes until the test says so.
///
/// Every lifecycle probe in this file is driven through this gate, so the
/// tests stay deterministic: no real sockets, no real SSH, no wall-clock
/// dependence beyond the injected timeouts.
class _GatedPingClient implements SSHClient {
  bool closed = false;
  bool failPings = false;

  /// One completer per issued `ping()`, in order.
  final List<Completer<void>> gates = [];

  int get pingCalls => gates.length;

  @override
  bool get isClosed => closed;

  @override
  Future<void> get done => Completer<void>().future;

  @override
  Future<void> ping() {
    final gate = Completer<void>();
    gates.add(gate);
    if (failPings) {
      gate.completeError(StateError('transport reset'));
    }
    return gate.future;
  }

  /// Answers every pending ping as if the remote had replied.
  void answer() {
    for (final gate in gates) {
      if (!gate.isCompleted) gate.complete();
    }
  }

  @override
  Future<void> close() async => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AcceptingHostKeyVerifier implements SSHHostKeyVerifier {
  @override
  Future<bool> verifyHostKey({
    required String host,
    required int port,
    required String keyType,
    required Uint8List fingerprint,
    Future<bool> Function(String, String, String)? onConfirmFirstTime,
  }) async => true;
}

SSHClientManager _manager(
  String serverId,
  SSHClient client, {
  bool watchTransport = false,
  bool startKeepAlive = false,
  Duration verifyAliveTimeout = const Duration(milliseconds: 60),
  Duration keepAliveInterval = const Duration(minutes: 30),
}) {
  final manager = SSHClientManager(
    _AcceptingHostKeyVerifier(),
    socketConnector: (_, _, _) async =>
        throw StateError('these tests must never open a socket'),
    verifyAliveTimeout: verifyAliveTimeout,
    transportKeepAliveInterval: keepAliveInterval,
  );
  manager.debugRegisterClient(
    serverId,
    client,
    watchTransport: watchTransport,
    startKeepAlive: startKeepAlive,
  );
  return manager;
}

void main() {
  group('探活合并（single-flight）', () {
    test('并发的 verifyAlive 共用同一次探测与同一个 future', () async {
      final client = _GatedPingClient();
      final manager = _manager('s', client);
      addTearDown(manager.dispose);

      final first = manager.verifyAlive('s');
      final second = manager.verifyAlive('s');

      expect(identical(first, second), isTrue, reason: '同一时间只能有一次探测在飞');
      expect(client.pingCalls, 1, reason: '并发调用不得各发一次 ping');

      client.answer();
      expect(await first, isTrue);
      expect(await second, isTrue);
    });

    test('探测完成后单飞锁释放，下一次探测重新发起 ping', () async {
      final client = _GatedPingClient();
      final manager = _manager('s', client);
      addTearDown(manager.dispose);

      final first = manager.verifyAlive('s');
      client.answer();
      expect(await first, isTrue);

      final second = manager.verifyAlive('s');
      expect(identical(first, second), isFalse);
      expect(client.pingCalls, 2, reason: '已完成的探测不得被缓存复用');
      client.answer();
      expect(await second, isTrue);
    });

    test('心跳定时器在飞时，显式 verifyAlive 复用同一次探测', () async {
      final client = _GatedPingClient();
      final manager = _manager(
        's',
        client,
        startKeepAlive: true,
        keepAliveInterval: const Duration(milliseconds: 5),
        verifyAliveTimeout: const Duration(milliseconds: 400),
      );
      addTearDown(manager.dispose);

      // 心跳定时器已经在飞（探测的 ping 还没回）。
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final heartbeatPings = client.pingCalls;
      expect(heartbeatPings, greaterThan(0), reason: '心跳定时器必须真的发起探测');

      final manual = manager.verifyAlive('s');
      expect(
        client.pingCalls,
        heartbeatPings,
        reason: '心跳已在飞时手动探测必须复用，不能再发一次 ping',
      );

      client.answer();
      expect(await manual, isTrue, reason: '共用同一次探测的结果');
      expect(manager.isConnected('s'), isTrue);
    });

    test('后台期间心跳定时器不发起探测，回前台恢复', () async {
      final client = _GatedPingClient();
      final manager = _manager(
        's',
        client,
        startKeepAlive: true,
        keepAliveInterval: const Duration(milliseconds: 5),
        verifyAliveTimeout: const Duration(milliseconds: 400),
      );
      addTearDown(manager.dispose);

      // 进程被冻结：定时器还在走，但不允许再打扰远端。
      manager.setAppInBackground(true);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(client.pingCalls, 0, reason: '后台期间心跳不得发起探测');

      manager.setAppInBackground(false);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(client.pingCalls, greaterThan(0), reason: '回前台必须恢复心跳探测');

      client.answer();
      expect(await manager.verifyAlive('s'), isTrue);
    });

    test('不同服务器之间的探测互不干扰', () async {
      final a = _GatedPingClient();
      final b = _GatedPingClient();
      final manager = _manager('a', a);
      addTearDown(manager.dispose);
      manager.debugRegisterClient('b', b, watchTransport: false);

      final probingA = manager.verifyAlive('a');
      final probingB = manager.verifyAlive('b');
      expect(identical(probingA, probingB), isFalse);

      a.answer();
      expect(await probingA, isTrue);
      expect(manager.isConnected('b'), isTrue, reason: 'a 的探测不得连带判定 b 死亡');
      b.answer();
      expect(await probingB, isTrue);
    });

    test('断开后单飞记录被清掉，重连的新客户端可以重新探测', () async {
      final client = _GatedPingClient();
      final manager = _manager('s', client);
      addTearDown(manager.dispose);

      final first = manager.verifyAlive('s');
      manager.disconnect('s');
      client.answer();
      await first;

      final replacement = _GatedPingClient();
      manager.debugRegisterClient('s', replacement, watchTransport: false);
      final second = manager.verifyAlive('s');
      expect(replacement.pingCalls, 1);
      replacement.answer();
      expect(await second, isTrue);
    });
  });

  group('超时宽限（timeout grace）', () {
    test('悬挂 ping 先等一个宽限期再判定死亡，且全程只发一次 ping', () async {
      final client = _GatedPingClient();
      final manager = _manager(
        's',
        client,
        verifyAliveTimeout: const Duration(milliseconds: 60),
      );
      addTearDown(manager.dispose);

      final elapsed = Stopwatch()..start();
      final alive = await manager
          .verifyAlive('s')
          .timeout(const Duration(seconds: 5));
      elapsed.stop();

      expect(alive, isFalse);
      expect(client.pingCalls, 1, reason: '宽限期必须等同一个请求，不能再发一次 ping');
      expect(
        elapsed.elapsedMilliseconds,
        greaterThanOrEqualTo(100),
        reason: '单次超时不足以判定死亡：必须至少等满两个超时窗口',
      );
      expect(manager.isConnected('s'), isFalse, reason: '确认死亡后必须清理连接');
    });

    test('宽限期内迟到的回复保住了连接', () async {
      final client = _GatedPingClient();
      final manager = _manager(
        's',
        client,
        verifyAliveTimeout: const Duration(milliseconds: 60),
      );
      addTearDown(manager.dispose);

      final probing = manager.verifyAlive('s');
      // 第一个超时之后、第二个超时之前才收到回复。
      Timer(const Duration(milliseconds: 90), client.answer);

      expect(await probing, isTrue, reason: '迟到的回复仍然算活着');
      expect(manager.isConnected('s'), isTrue);
      expect(client.pingCalls, 1);
      expect(client.closed, isFalse);
    });

    test('ping 抛错立即判定死亡并只广播一次 transportDied', () async {
      final client = _GatedPingClient();
      final manager = _manager('s', client, watchTransport: true);
      addTearDown(manager.dispose);

      final died = <String>[];
      final sub = manager.transportDied.listen(died.add);
      addTearDown(sub.cancel);

      client.failPings = true;
      expect(await manager.verifyAlive('s'), isFalse);
      await Future<void>.delayed(Duration.zero);

      expect(manager.isConnected('s'), isFalse);
      expect(died, ['s'], reason: '探活确认死亡只广播一次，供重连接手');
    });
  });

  group('后台暂停期间的旧代次探活', () {
    test('探测在飞时进入后台，旧截止时间不得拆掉传输层', () async {
      final client = _GatedPingClient();
      final manager = _manager(
        's',
        client,
        verifyAliveTimeout: const Duration(milliseconds: 60),
      );
      addTearDown(manager.dispose);

      final probing = manager.verifyAlive('s');
      // 探测在飞期间设备进入后台：Doze 会冻结 Dart 定时器，
      // 回来后旧 deadline 不能把刚恢复的连接误判为死亡。
      manager.setAppInBackground(true);
      manager.setAppInBackground(false);

      expect(await probing, isTrue);
      expect(manager.isConnected('s'), isTrue);
      expect(client.closed, isFalse, reason: '旧代次探活不得断开连接');
    });

    test('后台期间的探测即使超时也不拆连接', () async {
      final client = _GatedPingClient();
      final manager = _manager(
        's',
        client,
        verifyAliveTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(manager.dispose);

      manager.setAppInBackground(true);
      final alive = await manager
          .verifyAlive('s')
          .timeout(const Duration(seconds: 5));

      expect(alive, isTrue, reason: '后台被冻结时无法区分「卡住」和「已死」，不得主动断线');
      expect(manager.isConnected('s'), isTrue);
      expect(client.closed, isFalse);
    });

    test('暂停期间未回应的旧探测不会拆连接，新代次探测仍然可以', () async {
      final old = _GatedPingClient();
      final manager = _manager(
        's',
        old,
        verifyAliveTimeout: const Duration(milliseconds: 60),
      );
      addTearDown(manager.dispose);

      final stale = manager.verifyAlive('s');
      manager.setAppInBackground(true);
      manager.setAppInBackground(false);
      expect(await stale, isTrue, reason: '旧代次探测只能被作废，不能拆连接');
      expect(manager.isConnected('s'), isTrue);

      // 新代次的探测仍然必须按真实存活判定工作。
      final fresh = manager.verifyAlive('s');
      expect(await fresh.timeout(const Duration(seconds: 5)), isFalse);
      expect(manager.isConnected('s'), isFalse);
    });

    test('未连接时探活直接返回 false 并清理残留记录', () async {
      final manager = SSHClientManager(_AcceptingHostKeyVerifier());
      addTearDown(manager.dispose);

      expect(await manager.verifyAlive('missing'), isFalse);
      expect(manager.isConnected('missing'), isFalse);
      expect(manager.recentlyVerified('missing'), isFalse);
    });
  });

  group('recentlyVerified 复用窗口', () {
    test('注册但未探测过的连接不算近期已验证', () {
      final manager = _manager('s', _GatedPingClient());
      addTearDown(manager.dispose);

      expect(manager.recentlyVerified('s'), isFalse, reason: '只有真的探活过才算近期健康');
    });

    test('探测成功后算近期已验证，断开后立即失效', () async {
      final client = _GatedPingClient();
      final manager = _manager('s', client);
      addTearDown(manager.dispose);

      final probing = manager.verifyAlive('s');
      client.answer();
      expect(await probing, isTrue);
      expect(manager.recentlyVerified('s'), isTrue);

      manager.disconnect('s');
      expect(manager.recentlyVerified('s'), isFalse);
    });

    test('探测失败的连接不算近期已验证', () async {
      final client = _GatedPingClient();
      final manager = _manager(
        's',
        client,
        verifyAliveTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(manager.dispose);

      expect(await manager.verifyAlive('s'), isFalse);
      expect(manager.recentlyVerified('s'), isFalse);
    });
  });
}
