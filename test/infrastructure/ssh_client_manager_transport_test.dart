import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
// SSHSession exposes this type but dartssh2 does not export it.
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_channel.dart';
// SSH_Message_Userauth_Success is only reachable through the implementation
// library; the package's own tests import it the same way.
// ignore: implementation_imports
import 'package:dartssh2/src/message/msg_userauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

/// 可注入的假 socket。
///
/// [SSHSocket] 是 `abstract class`，因此这里必须把它当作具体类来实现
/// （`implements SSHSocket`，不能 `extends` 一个不存在的接口）。
class _FakeSshSocket implements SSHSocket {
  final StreamController<Uint8List> _incoming =
      StreamController<Uint8List>.broadcast();
  final StreamController<List<int>> _outgoing =
      StreamController<List<int>>.broadcast();
  final Completer<void> _done = Completer<void>();

  /// 记录收到的原始字节，便于断言没有任何东西被误发。
  final List<List<int>> written = [];

  bool destroyed = false;

  @override
  Stream<Uint8List> get stream => _incoming.stream;

  @override
  StreamSink<List<int>> get sink => _outgoing.sink;

  @override
  Future<void> get done => _done.future;

  /// 模拟远端/网络把连接掐掉。
  void dropConnection() {
    if (!_done.isCompleted) _done.complete();
    if (!_incoming.isClosed) _incoming.close();
    if (!_outgoing.isClosed) _outgoing.close();
  }

  @override
  Future<void> close() async {
    dropConnection();
  }

  @override
  void destroy() {
    destroyed = true;
    dropConnection();
  }

  @override
  Future<void> flush() async {}
}

Future<LocalStorageService> _storage() async {
  SharedPreferences.setMockInitialValues({});
  return LocalStorageService.init();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'concurrent exec channels own their exit code and drain final output',
    () async {
      final client = _ExecClient();
      final manager = _managerWithClient('s', client, live: false);
      addTearDown(manager.dispose);
      final first = manager.executeWithLoginShell('s', 'first');
      final second = manager.executeWithLoginShell('s', 'second');
      await Future<void>.delayed(Duration.zero);
      final a = client.sessions[0];
      final b = client.sessions[1];
      a.complete(7, 'first output');
      b.complete(3, 'second output');
      final results = await Future.wait([first, second]);
      expect(results.map((r) => r.exitCode), [7, 3]);
      expect(results.map((r) => r.stdout), ['first output', 'second output']);
      final lost = manager.executeWithLoginShell('s', 'lost');
      await Future<void>.delayed(Duration.zero);
      client.sessions.last.complete(null, '');
      expect((await lost).exitCode, -1);
    },
  );

  test('channel opening is timed out and its late session is closed', () async {
    final client = _ExecClient()..openGate = Completer<void>();
    final manager = _managerWithClient('s', client, live: false);
    addTearDown(manager.dispose);
    await expectLater(
      manager
          .executeStreaming(
            's',
            'hang',
            timeout: const Duration(milliseconds: 30),
          )
          .toList(),
      throwsA(isA<SSHConnectionException>()),
    );
    client.openGate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(client.sessions.single.closed, isTrue);
  });

  test(
    'cancel while opening returns promptly and closes a late session',
    () async {
      final client = _ExecClient()..openGate = Completer<void>();
      final manager = _managerWithClient('s', client, live: false);
      addTearDown(manager.dispose);
      final sub = manager.executeStreaming('s', 'hang').listen((_) {});
      await sub.cancel().timeout(const Duration(seconds: 1));
      client.openGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(client.sessions.single.closed, isTrue);
    },
  );

  test(
    'cancel destroys a running channel even when the remote ignores EOF',
    () async {
      final client = _ExecClient();
      final manager = _managerWithClient('s', client, live: false);
      addTearDown(manager.dispose);
      final ready = Completer<void>();
      final sub = manager.executeStreaming('s', 'long running').listen((chunk) {
        if (chunk.text.contains('ready')) ready.complete();
      });
      await Future<void>.delayed(Duration.zero);
      final session = client.sessions.single;
      session.output.add(utf8.encode('ready\n'));
      await ready.future;
      await sub.cancel().timeout(const Duration(seconds: 1));
      expect(session.finished.isCompleted, isTrue);
      expect(session.closed, isTrue);
    },
  );

  test(
    'stream preserves split UTF-8 and emits remote exit status last',
    () async {
      final client = _ExecClient();
      final manager = _managerWithClient('s', client, live: false);
      addTearDown(manager.dispose);
      final chunks = manager.executeStreaming('s', 'output').toList();
      await Future<void>.delayed(Duration.zero);
      final session = client.sessions.single;
      final bytes = utf8.encode('视频');
      session.output.add(Uint8List.fromList(bytes.sublist(0, 2)));
      session.output.add(Uint8List.fromList(bytes.sublist(2)));
      session.errors.add(utf8.encode('error detail'));
      session.complete(7, '');
      final output = await chunks;
      expect(
        output
            .where((c) => c.kind == SSHStreamKind.stdout)
            .map((c) => c.text)
            .join(),
        '视频',
      );
      expect(
        output.where((c) => c.kind == SSHStreamKind.stderr).single.text,
        'error detail',
      );
      expect(output.last.exitCode, 7);
      expect(session.closed, isTrue);
    },
  );

  test(
    'buffered command fails explicitly at its output limit and closes channel',
    () async {
      final client = _ExecClient();
      final manager = _managerWithClient('s', client, live: false);
      addTearDown(manager.dispose);
      final result = manager.executeWithLoginShell('s', 'large');
      final assertion = expectLater(
        result,
        throwsA(isA<SSHConnectionException>()),
      );
      await Future<void>.delayed(Duration.zero);
      final session = client.sessions.single;
      session.output.add(Uint8List(8 * 1024 * 1024 + 1));
      await assertion;
      expect(session.closed, isTrue);
    },
  );

  test('silent handshake expires and destroys its socket', () async {
    final socket = _FakeSshSocket();
    final manager = SSHClientManager(
      _NoopHostKeyVerifier(),
      socketConnector: (_, _, _) async => socket,
      authenticationTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(manager.dispose);
    await expectLater(
      manager.getOrCreateClient(_server),
      throwsA(isA<SSHConnectionException>()),
    );
    expect(socket.destroyed, isTrue);
    expect(manager.isConnected('s'), isFalse);
  });

  test(
    'disconnect cancels a pending socket and destroys its late result',
    () async {
      final socket = _FakeSshSocket();
      final opening = Completer<SSHSocket>();
      final manager = SSHClientManager(
        _NoopHostKeyVerifier(),
        socketConnector: (_, _, _) => opening.future,
      );
      addTearDown(manager.dispose);
      final connecting = manager.getOrCreateClient(_server);
      expect(identical(connecting, manager.getOrCreateClient(_server)), isTrue);
      final assertion = expectLater(
        connecting,
        throwsA(isA<SSHConnectionException>()),
      );
      manager.disconnect('s');
      await assertion;
      opening.complete(socket);
      await Future<void>.delayed(Duration.zero);
      expect(socket.destroyed, isTrue);
      expect(manager.isConnected('s'), isFalse);
    },
  );

  test(
    'same ID with edited endpoint cancels the pending connection instead of reusing it',
    () async {
      final openings = <Completer<SSHSocket>>[];
      final manager = SSHClientManager(
        _NoopHostKeyVerifier(),
        socketConnector: (_, _, _) {
          final opening = Completer<SSHSocket>();
          openings.add(opening);
          return opening.future;
        },
      );
      addTearDown(manager.dispose);
      final first = manager.getOrCreateClient(_server);
      final firstFailed = expectLater(
        first,
        throwsA(isA<SSHConnectionException>()),
      );
      final second = manager.getOrCreateClient(
        _server.copyWith(host: 'new.invalid'),
      );
      final secondFailed = expectLater(
        second,
        throwsA(isA<SSHConnectionException>()),
      );
      expect(openings, hasLength(2));
      expect(identical(first, second), isFalse);
      await firstFailed;
      manager.disconnect('s');
      await secondFailed;
      for (final opening in openings) {
        opening.complete(_FakeSshSocket());
      }
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'stale failed ping cannot disconnect a replacement connection',
    () async {
      final oldClient = SSHClient(_FakeSshSocket(), username: 'dev');
      final manager = _managerWithClient(
        's',
        oldClient,
        verifyAliveTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(manager.dispose);
      final probing = manager.verifyAlive('s');
      final replacement = _ExecClient();
      manager.debugRegisterClient('s', replacement, watchTransport: false);
      expect(await probing, isTrue);
      expect(manager.getClient('s'), same(replacement));
      oldClient.close();
    },
  );

  group('SSHClientManager transport death detection', () {
    test('broadcasts transportDied when an active transport ends', () async {
      // 用真实的 SSHClient + 假 socket：认证不会成功，但 socket 完成
      // 会让 client.done 完成，这正是我们要验证的掉线路径。
      final socket = _FakeSshSocket();
      final client = SSHClient(socket, username: 'dev');

      final manager = _managerWithClient('s1', client);
      addTearDown(manager.dispose);

      final died = <String>[];
      final sub = manager.transportDied.listen(died.add);
      addTearDown(sub.cancel);

      socket.dropConnection();

      // 让微任务队列跑完，给 client.done -> broadcast 留出时间。
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(died, ['s1']);
    });

    test('旧代际的 done 不会误报新连接掉线（代际守卫）', () async {
      // 模拟：s1 先连上 client A（已监听），随后被 client B 替换（重连成功）。
      // 此时 A 的 done 才完成 —— 必须被 identical 守卫丢弃。
      final oldSocket = _FakeSshSocket();
      final oldClient = SSHClient(oldSocket, username: 'dev');

      final manager = _managerWithClient('s1', oldClient);
      addTearDown(manager.dispose);

      final newSocket = _FakeSshSocket();
      final newClient = SSHClient(newSocket, username: 'dev');
      // 替换：A 的 done 监听器依然存在，但 _activeClients 已指向 B。
      manager.debugRegisterClient('s1', newClient);

      final died = <String>[];
      final sub = manager.transportDied.listen(died.add);
      addTearDown(sub.cancel);

      // 旧客户端现在才结束 —— 不应广播。
      oldSocket.dropConnection();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(died, isEmpty, reason: '旧代际结束不应把新连接判定为掉线');

      // 新客户端结束 —— 应当广播。
      newSocket.dropConnection();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(died, ['s1']);
    });

    test('transportDied stream is a broadcast stream', () async {
      final manager = SSHClientManager(SSHHostKeyVerifier(await _storage()));
      addTearDown(manager.dispose);

      expect(manager.transportDied.isBroadcast, isTrue);
    });

    test(
      'verifyAlive returns false and cleans up when not connected',
      () async {
        final manager = SSHClientManager(SSHHostKeyVerifier(await _storage()));
        addTearDown(manager.dispose);

        expect(await manager.verifyAlive('missing'), isFalse);
        expect(manager.isConnected('missing'), isFalse);
      },
    );

    test('verifyAlive 在半开连接上按超时返回 false 而非永久挂起', () async {
      // 这是本次修复的核心回归：半开 socket 上 `SSHClient.ping()` 既不返回
      // 也不抛错，旧代码里 keepalive 的 `await client.ping()` 会永远卡住，
      // catch 块形同虚设。verifyAlive 必须靠显式 timeout 把它变成确定结果。
      final socket = _FakeSshSocket();
      final client = SSHClient(socket, username: 'dev');
      final manager = _managerWithClient('s1', client);
      addTearDown(manager.dispose);

      // 注意：这里不能 dropConnection（那会让 done 完成从而走另一条路径）。
      // 我们模拟的正是「连接看起来还在、但实际已经不通」的状态。
      final alive = await manager
          .verifyAlive('s1')
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('verifyAlive 必须在 verifyAliveTimeout 内返回'),
          );

      expect(alive, isFalse);
      expect(manager.isConnected('s1'), isFalse, reason: '探活失败后必须清理连接');
    });

    test('disconnect(notifyDeath: true) 在摘掉 client 后仍广播', () async {
      final socket = _FakeSshSocket();
      final client = SSHClient(socket, username: 'dev');
      final manager = _managerWithClient('s1', client);
      addTearDown(manager.dispose);

      final died = <String>[];
      final sub = manager.transportDied.listen(died.add);
      addTearDown(sub.cancel);

      manager.disconnect('s1', notifyDeath: true);
      await Future<void>.delayed(Duration.zero);

      expect(died, ['s1']);
      expect(manager.isConnected('s1'), isFalse);
    });

    test('已认证真实 SSHClient：verifyAlive 等待期间 socket 掉线 → false 并广播', () async {
      final socket = _FakeSshSocket();
      final client = SSHClient(socket, username: 'dev');
      // 用协议层注入 SSH_MSG_USERAUTH_SUCCESS，让 client 进入已认证态，
      // 这是包自身测试的做法（handlePacket 标注了 @visibleForTesting）。
      client.handlePacket(SSH_Message_Userauth_Success().encode());

      final manager = _managerWithClient(
        's1',
        client,
        verifyAliveTimeout: const Duration(seconds: 2),
      );
      addTearDown(manager.dispose);

      final died = <String>[];
      final sub = manager.transportDied.listen(died.add);
      addTearDown(sub.cancel);

      var probeSettled = false;
      final probing = manager.verifyAlive('s1');
      unawaited(
        probing.then<void>(
          (_) => probeSettled = true,
          onError: (_) => probeSettled = true,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final pendingAtDrop = !probeSettled;
      socket.dropConnection();

      final alive = await probing.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('verifyAlive 必须在掉线后返回，不得永久挂起'),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(pendingAtDrop, isTrue, reason: '掉线发生时探活必须仍在等待');
      expect(alive, isFalse, reason: '掉线后必须回到调用方 false');
      expect(manager.isConnected('s1'), isFalse, reason: '掉线后必须清理连接');
      expect(died, contains('s1'), reason: '掉线必须通知重连');
    });

    test('用户主动 disconnect 不广播 transportDied', () async {
      final socket = _FakeSshSocket();
      final client = SSHClient(socket, username: 'dev');
      final manager = _managerWithClient('s1', client);
      addTearDown(manager.dispose);

      final died = <String>[];
      final sub = manager.transportDied.listen(died.add);
      addTearDown(sub.cancel);

      manager.disconnect('s1');
      socket.dropConnection();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(died, isEmpty, reason: '主动断开不得触发自动重连');
    });

    test('dispose closes the transportDied stream', () async {
      final manager = SSHClientManager(SSHHostKeyVerifier(await _storage()));
      final done = Completer<void>();
      manager.transportDied.listen(null, onDone: done.complete);

      manager.dispose();

      await done.future.timeout(const Duration(seconds: 1));
      expect(done.isCompleted, isTrue);
    });
  });
}

SSHClientManager _managerWithClient(
  String serverId,
  SSHClient client, {
  bool live = true,
  Duration verifyAliveTimeout = const Duration(milliseconds: 200),
}) {
  final manager = SSHClientManager(
    _NoopHostKeyVerifier(),
    socketConnector: (host, port, timeout) async => client.socket,
    verifyAliveTimeout: verifyAliveTimeout,
  );
  manager.debugRegisterClient(serverId, client, watchTransport: live);
  return manager;
}

const _server = ServerProfile(
  id: 's',
  name: 'test',
  host: 'test.invalid',
  username: 'dev',
);

class _ExecClient implements SSHClient {
  Completer<void>? openGate;
  final sessions = <_ExecSession>[];
  @override
  bool get isClosed => false;
  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    await openGate?.future;
    final session = _ExecSession();
    sessions.add(session);
    return session;
  }

  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _ExecSession implements SSHSession {
  final output = StreamController<Uint8List>();
  final errors = StreamController<Uint8List>();
  final input = StreamController<Uint8List>();
  final finished = Completer<void>();
  int? code;
  bool closed = false;
  @override
  SSHChannel get channel => _ExecChannel(this);
  @override
  void kill(SSHSignal signal) {}
  void complete(int? exit, String text) {
    code = exit;
    finished.complete();
    output.add(utf8.encode(text));
    unawaited(output.close());
    unawaited(errors.close());
  }

  @override
  int? get exitCode => code;
  @override
  Future<void> get done => finished.future;
  @override
  Stream<Uint8List> get stdout => output.stream;
  @override
  Stream<Uint8List> get stderr => errors.stream;
  @override
  StreamSink<Uint8List> get stdin => input.sink;
  @override
  void close() {
    closed = true;
    unawaited(input.close());
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
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

class _ExecChannel implements SSHChannel {
  _ExecChannel(this.session);
  final _ExecSession session;
  @override
  void destroy([Object? error, StackTrace? stackTrace]) {
    session.closed = true;
    if (!session.finished.isCompleted) session.finished.complete();
    if (!session.output.isClosed) unawaited(session.output.close());
    if (!session.errors.isClosed) unawaited(session.errors.close());
    session.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
