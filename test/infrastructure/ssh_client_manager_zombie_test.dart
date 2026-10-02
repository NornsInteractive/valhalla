import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

/// 假 socket：真实 `SSHClient` 可以架在上面完成「永远握不上手」的连接。
class _FakeSshSocket implements SSHSocket {
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final StreamController<List<int>> _outgoing =
      StreamController<List<int>>.broadcast();
  final Completer<void> _done = Completer<void>();

  @override
  Stream<Uint8List> get stream => _incoming.stream;

  @override
  StreamSink<List<int>> get sink => _outgoing.sink;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() async {
    if (!_done.isCompleted) _done.complete();
    if (!_incoming.isClosed) unawaited(_incoming.close());
    if (!_outgoing.isClosed) unawaited(_outgoing.close());
  }

  @override
  void destroy() {
    unawaited(close());
  }

  @override
  Future<void> flush() async {}
}

/// 幽灵连接：`isClosed` 是 false（没有 FIN 到达），但 `ping()` 永远挂起 ——
/// 真实网络掉线（拔线/切网）后旧 TCP socket 正是这个样子。
class _ZombieClient implements SSHClient {
  final _socket = _FakeSshSocket();
  bool closeCalled = false;

  @override
  bool get isClosed => false;

  @override
  Future<void> ping() => Completer<void>().future;

  @override
  Future<void> close() async {
    closeCalled = true;
  }

  @override
  SSHSocket get socket => _socket;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 活着的客户端：`ping()` 立即返回。
class _HealthyClient implements SSHClient {
  final _socket = _FakeSshSocket();
  int pingCount = 0;

  @override
  bool get isClosed => false;

  @override
  Future<void> ping() async {
    pingCount++;
  }

  @override
  Future<void> close() async {}

  @override
  SSHSocket get socket => _socket;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopHostKeyVerifier implements SSHHostKeyVerifier {
  @override
  Future<bool> verifyHostKey({
    required String host,
    required int port,
    required String keyType,
    required Uint8List fingerprint,
    Future<bool> Function(String, String, String)? onConfirmFirstTime,
  }) async => true;
}

const _server = ServerProfile(
  id: 's1',
  name: 'fixture',
  host: 'test.invalid',
  username: 'dev',
);

void main() {
  test('getOrCreateClient 拒绝僵尸连接：探活失败后断开并用全新握手替换', () async {
    final zombie = _ZombieClient();
    var connectorCalls = 0;
    final manager = SSHClientManager(
      _NoopHostKeyVerifier(),
      socketConnector: (_, _, _) async {
        connectorCalls++;
        return _FakeSshSocket();
      },
      verifyAliveTimeout: const Duration(milliseconds: 30),
      authenticationTimeout: const Duration(milliseconds: 200),
    );
    addTearDown(manager.dispose);
    // 注册为「目标一致的现有客户端」，走到 getOrCreateClient 的复用分支。
    manager.debugRegisterClient(
      's1',
      zombie,
      watchTransport: false,
      target: _server,
    );
    // 注意：从未 verifyAlive 过 → recentlyVerified 为 false → 必须先探活。
    final died = <String>[];
    final sub = manager.transportDied.listen(died.add);
    addTearDown(sub.cancel);

    final handedBack = manager.getOrCreateClient(_server);
    // 僵尸 ping 挂起 → 探活按超时判死 → 落到全新握手。假 socket 上认证
    // 永远完不成，最终以认证超时失败 —— 但绝不是把僵尸交回来。
    await expectLater(handedBack, throwsA(isA<SSHConnectionException>()));

    expect(zombie.closeCalled, isTrue, reason: '僵尸连接必须被断开');
    expect(connectorCalls, 1, reason: '必须发起一次全新的 socket 连接');
    expect(manager.getClient('s1'), isNot(same(zombie)));
    expect(manager.isConnected('s1'), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(died, isEmpty, reason: '僵尸换新路径不得广播 transportDied（notifyDeath: false）');
  });

  test('recentlyVerified 窗口内 getOrCreateClient 直接复用，不再探活', () async {
    final healthy = _HealthyClient();
    var connectorCalls = 0;
    final manager = SSHClientManager(
      _NoopHostKeyVerifier(),
      socketConnector: (_, _, _) async {
        connectorCalls++;
        return _FakeSshSocket();
      },
      verifyAliveTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(manager.dispose);
    manager.debugRegisterClient(
      's1',
      healthy,
      watchTransport: false,
      target: _server,
    );

    // 先探活一次建立 30 秒窗口。
    expect(await manager.verifyAlive('s1'), isTrue);
    expect(healthy.pingCount, 1);

    final client = await manager.getOrCreateClient(_server);
    expect(identical(client, healthy), isTrue);
    expect(healthy.pingCount, 1, reason: '快照窗口内不得再次 ping');
    expect(connectorCalls, 0, reason: '连接活着就不该重建');
  });
}
