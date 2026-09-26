import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_mosh/dart_mosh.dart';
import 'package:dartssh2/dartssh2.dart';
// SSHSession.channel 的返回类型没有从 dartssh2 导出，fake 需要显式实现它。
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/mosh/mosh_session_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

/// mosh-server 打印的 canonical printable key（16 个 0..15 字节）。
const _key = 'AAECAwQFBgcICQoLDA0ODw';

const _request = MoshBootstrapRequest(serverId: 'srv-1', host: '203.0.113.10');

class _FakeExecutor implements SshCommandExecutor {
  _FakeExecutor({this.client});

  _FakeSshClient? client;

  @override
  SSHClient? getClient(String serverId) => client;

  @override
  bool isConnected(String serverId) => client != null && !client!.isClosed;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 假的 SSH 客户端，只实现 bootstrap 用到的 execute。
///
/// `command -v` 探测命令按脚本自动完成；`mosh-server new` 命令的输出
/// 由 [bootstrapOutput]/[bootstrapExitCode] 决定。
class _FakeSshClient implements SSHClient {
  _FakeSshClient();

  /// 探测命令（command -v）的 stdout。
  String probeOutput = '/usr/bin/mosh-server';
  int probeExitCode = 0;

  /// 探测命令挂死（模拟慢执行器 → timeout）。
  bool probeHangs = false;

  /// execute 直接抛错（→ sshFailed）。
  bool failExecute = false;

  /// bootstrap 命令挂死。
  bool bootstrapHangs = false;

  /// bootstrap 会话的输出流里抛错误（→ sshFailed）。
  bool failBootstrapStream = false;

  /// bootstrap 会话传输层挂掉：无退出码、流关闭、done 正常完成
  /// （dartssh2 的 SSHChannel.done 从不携带错误）（→ sshFailed）。
  bool dieBootstrapTransport = false;

  String bootstrapOutput = '';
  int bootstrapExitCode = 0;

  /// false：只吐输出不结束进程，验证 CONNECT 行到手后提前拆通道。
  bool bootstrapClose = true;

  final executed = <String>[];
  _FakeSshSession? lastSession;

  @override
  bool get isClosed => false;

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    executed.add(command);
    if (failExecute) throw StateError('exec failed');
    final session = _FakeSshSession();
    lastSession = session;
    if (command.contains('command -v')) {
      if (probeHangs) return session;
      session.emit(probeOutput, exitCode: probeExitCode);
      return session;
    }
    if (command.contains('mosh-server new')) {
      if (bootstrapHangs) return session;
      if (failBootstrapStream) {
        session.emitError(StateError('stream died'));
        return session;
      }
      if (dieBootstrapTransport) {
        session.dieTransport();
        return session;
      }
      session.emit(
        bootstrapOutput,
        exitCode: bootstrapExitCode,
        close: bootstrapClose,
      );
    }
    return session;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSshSession implements SSHSession {
  final _stdout = StreamController<Uint8List>();
  final _stderr = StreamController<Uint8List>();
  final _done = Completer<void>();
  int? _exitCode;
  bool closed = false;
  bool destroyed = false;

  /// 吐输出并结束进程；[close] 为 false 时进程保持运行。
  void emit(
    String text, {
    int? exitCode,
    bool close = true,
    bool toStderr = false,
  }) {
    final bytes = Uint8List.fromList(utf8.encode(text));
    if (toStderr) {
      _stderr.add(bytes);
    } else {
      _stdout.add(bytes);
    }
    if (exitCode != null) _exitCode = exitCode;
    if (close) {
      _stdout.close();
      _stderr.close();
      if (!_done.isCompleted) _done.complete();
    }
  }

  /// 输出流出错后结束进程。
  void emitError(Object error) {
    _stderr.addError(error);
    emit('', exitCode: -1);
  }

  /// 传输层挂掉：通道被拆、无退出码、流关闭、done 正常完成
  /// （dartssh2 的 SSHChannel.done 从不携带错误）。
  void dieTransport() {
    _stdout.close();
    _stderr.close();
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  Future<void> get done => _done.future;

  @override
  int? get exitCode => _exitCode;

  @override
  SSHChannel get channel => _FakeSshChannel(this);

  @override
  void close() => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSshChannel implements SSHChannel {
  _FakeSshChannel(this.session);

  final _FakeSshSession session;

  @override
  void destroy([Object? error, StackTrace? stack]) {
    session.destroyed = true;
    session.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 假的 dart_mosh 会话，验证句柄的转发。
class _FakeMoshSession implements MoshSession {
  final _stdout = StreamController<List<int>>();
  final sent = <List<int>>[];
  final sizes = <(int, int)>[];
  var closeCount = 0;
  final _done = Completer<void>();

  /// 模拟远端输出。
  void pushBytes(List<int> bytes) => _stdout.add(bytes);

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<Object> get errors => const Stream<Object>.empty();

  @override
  Stream<int> get echoAcks => const Stream<int>.empty();

  @override
  Future<void> get done => _done.future;

  @override
  Duration? get smoothedRtt => null;

  @override
  int send(List<int> data) {
    sent.add(data);
    return 0;
  }

  @override
  int resize(int columns, int rows) {
    sizes.add((columns, rows));
    return 0;
  }

  @override
  Future<void> rehome({InternetAddress? localAddress, int localPort = 0}) async {}

  @override
  Future<void> close() async {
    closeCount++;
    if (!_done.isCompleted) _done.complete();
  }
}

MoshBootstrapFailure _failure(MoshBootstrapResult result) =>
    result as MoshBootstrapFailure;

void main() {
  group('bootstrap command assembly', () {
    test('probes command -v then runs mosh-server with custom path and port range',
        () async {
      final client = _FakeSshClient()
        ..bootstrapOutput = 'MOSH CONNECT 60001 $_key\n';
      final service = MoshSessionService(_FakeExecutor(client: client));

      final result = await service.bootstrap(
        const MoshBootstrapRequest(
          serverId: 'srv-1',
          host: '203.0.113.10',
          serverPath: '/opt/mosh/bin/mosh-server',
          portRange: '60000:61000',
        ),
      );

      expect(result, isA<MoshBootstrapSuccess>());
      expect(client.executed, hasLength(2));
      final probe = client.executed[0];
      expect(probe, startsWith('bash -l -c '));
      expect(probe, contains('command -v'));
      expect(probe, contains('/opt/mosh/bin/mosh-server'));
      final bootstrap = client.executed[1];
      expect(bootstrap, contains('bash -l -c'));
      expect(bootstrap, contains('/opt/mosh/bin/mosh-server new'));
      expect(bootstrap, contains('-p 60000:61000'));
      expect(bootstrap, contains('TERM=xterm-256color'));
      expect(bootstrap, contains('LC_ALL=en_US.UTF-8'));
    });

    test('single port range is passed through as-is', () async {
      final client = _FakeSshClient()
        ..bootstrapOutput = 'MOSH CONNECT 60001 $_key\n';
      final service = MoshSessionService(_FakeExecutor(client: client));

      await service.bootstrap(
        const MoshBootstrapRequest(
          serverId: 'srv-1',
          host: 'h',
          portRange: '60001',
        ),
      );

      expect(client.executed[1], contains('-p 60001'));
    });

    test('invalid port range fails as startFailed before any command', () async {
      final client = _FakeSshClient();
      final service = MoshSessionService(_FakeExecutor(client: client));

      for (final range in ['abc', '70000', '60000:61000:62000']) {
        final result = await service.bootstrap(
          MoshBootstrapRequest(serverId: 'srv-1', host: 'h', portRange: range),
        );
        expect(_failure(result).error, MoshBootstrapError.startFailed);
      }
      expect(client.executed, isEmpty);
    });
  });

  group('CONNECT line parsing', () {
    test('parses a clean MOSH CONNECT line', () async {
      final client = _FakeSshClient()
        ..bootstrapOutput = 'MOSH CONNECT 60001 $_key\n';
      final service = MoshSessionService(_FakeExecutor(client: client));

      final result = await service.bootstrap(_request);

      final success = result as MoshBootstrapSuccess;
      expect(success.endpoint.host, '203.0.113.10');
      expect(success.endpoint.port, 60001);
      expect(success.endpoint.key, _key);
      expect(success.rawOutput, contains('MOSH CONNECT'));
    });

    test('parses the CONNECT line amid SSH banner noise', () async {
      final output = 'Welcome to Ubuntu 22.04 LTS\r\n'
          'mosh-server (mosh 1.4.0) [build Oct 2023]\r\n'
          'Copyright 2012 Keith Winstein\r\n'
          'MOSH CONNECT 60001 $_key\r\n'
          '\r\nmosh-server started on port 60001\r\n';
      final client = _FakeSshClient()..bootstrapOutput = output;
      final service = MoshSessionService(_FakeExecutor(client: client));

      final result = await service.bootstrap(_request);

      expect((result as MoshBootstrapSuccess).endpoint.port, 60001);
    });

    test('finds the CONNECT line on stderr too', () async {
      final client = _FakeSshClient()..bootstrapClose = false;
      final service = MoshSessionService(_FakeExecutor(client: client));
      // 等探测完成、bootstrap 命令已经发出后，把 CONNECT 行写到 stderr。
      final future = service.bootstrap(_request);
      while (client.executed.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      client.lastSession!.emit(
        'MOSH CONNECT 60001 $_key\n',
        toStderr: true,
      );
      final result = await future;

      expect(result, isA<MoshBootstrapSuccess>());
    });

    test('malformed output without a CONNECT line fails as startFailed',
        () async {
      final client = _FakeSshClient()
        ..bootstrapOutput = 'mosh-server: failed to bind UDP socket\n';
      final service = MoshSessionService(_FakeExecutor(client: client));

      final result = await service.bootstrap(_request);

      final failure = _failure(result);
      expect(failure.error, MoshBootstrapError.startFailed);
      expect(failure.detail, contains('exit code 0'));
    });

    test('exit 127 with command not found fails as notInstalled', () async {
      final client = _FakeSshClient()
        ..bootstrapOutput = 'bash: mosh-server: command not found\n'
        ..bootstrapExitCode = 127;
      final service = MoshSessionService(_FakeExecutor(client: client));

      final result = await service.bootstrap(_request);

      expect(_failure(result).error, MoshBootstrapError.notInstalled);
    });

    test('empty probe output fails as notInstalled without starting the server',
        () async {
      final client = _FakeSshClient()
        ..probeOutput = ''
        ..probeExitCode = 1;
      final service = MoshSessionService(_FakeExecutor(client: client));

      final result = await service.bootstrap(_request);

      expect(_failure(result).error, MoshBootstrapError.notInstalled);
      expect(client.executed, hasLength(1));
    });
  });

  group('bootstrap failure classification', () {
    test('executor without a client reports sshFailed', () async {
      final service = MoshSessionService(_FakeExecutor(client: null));

      final result = await service.bootstrap(_request);

      expect(_failure(result).error, MoshBootstrapError.sshFailed);
    });

    test('execute throwing reports sshFailed', () async {
      final client = _FakeSshClient()..failExecute = true;
      final service = MoshSessionService(_FakeExecutor(client: client));

      final result = await service.bootstrap(_request);

      expect(_failure(result).error, MoshBootstrapError.sshFailed);
    });

    test('bootstrap output stream error reports sshFailed', () async {
      final client = _FakeSshClient()..failBootstrapStream = true;
      final service = MoshSessionService(_FakeExecutor(client: client));

      final result = await service.bootstrap(_request);

      expect(_failure(result).error, MoshBootstrapError.sshFailed);
    });

    test('bootstrap transport death reports sshFailed', () async {
      final client = _FakeSshClient()..dieBootstrapTransport = true;
      final service = MoshSessionService(_FakeExecutor(client: client));

      final result = await service.bootstrap(_request);

      expect(_failure(result).error, MoshBootstrapError.sshFailed);
    });

    test('slow probe reports timeout', () async {
      final client = _FakeSshClient()..probeHangs = true;
      final service = MoshSessionService(
        _FakeExecutor(client: client),
        probeTimeout: const Duration(milliseconds: 30),
      );

      final result = await service.bootstrap(_request);

      expect(_failure(result).error, MoshBootstrapError.timeout);
    });

    test('slow mosh-server startup reports timeout', () async {
      final client = _FakeSshClient()..bootstrapHangs = true;
      final service = MoshSessionService(
        _FakeExecutor(client: client),
        bootstrapTimeout: const Duration(milliseconds: 30),
      );

      final result = await service.bootstrap(_request);

      expect(_failure(result).error, MoshBootstrapError.timeout);
    });

    test('CONNECT line arrival tears down the SSH channel early', () async {
      final client = _FakeSshClient()
        ..bootstrapOutput = 'MOSH CONNECT 60001 $_key\n'
        ..bootstrapClose = false;
      final service = MoshSessionService(_FakeExecutor(client: client));

      final result = await service.bootstrap(_request);

      expect(result, isA<MoshBootstrapSuccess>());
      expect(client.lastSession!.destroyed, isTrue);
    });
  });

  group('connect', () {
    test('wraps the dart_mosh session in our own handle', () async {
      final session = _FakeMoshSession();
      MoshServerConfig? seenServer;
      MoshCipher? seenCipher;
      int? seenColumns;
      int? seenRows;
      final service = MoshSessionService(
        _FakeExecutor(client: _FakeSshClient()),
        openSession: ({
          required MoshServerConfig server,
          required MoshCipher cipher,
          required int columns,
          required int rows,
        }) async {
          seenServer = server;
          seenCipher = cipher;
          seenColumns = columns;
          seenRows = rows;
          return session;
        },
      );

      final handle = await service.connect(
        const MoshEndpoint(host: '203.0.113.10', port: 60001, key: _key),
        columns: 100,
        rows: 30,
      );

      expect(seenServer!.host, '203.0.113.10');
      expect(seenServer!.port, 60001);
      expect(seenServer!.key.bytes, hasLength(16));
      expect(seenCipher, isNotNull);
      expect(seenColumns, 100);
      expect(seenRows, 30);

      final received = <List<int>>[];
      final sub = handle.stdout.listen(received.add);
      session.pushBytes(utf8.encode('hi'));
      await Future<void>.delayed(Duration.zero);
      expect(utf8.decode(received.single), 'hi');

      handle.send(utf8.encode('ls\n'));
      expect(utf8.decode(session.sent.single), 'ls\n');

      handle.resize(120, 40);
      expect(session.sizes.single, (120, 40));

      await handle.dispose();
      expect(session.closeCount, 1);
      await sub.cancel();
    });

    test('invalid key material throws MoshSessionException', () async {
      final service = MoshSessionService(_FakeExecutor(client: _FakeSshClient()));

      await expectLater(
        service.connect(
          const MoshEndpoint(host: 'h', port: 60001, key: 'short'),
          columns: 80,
          rows: 24,
        ),
        throwsA(isA<MoshSessionException>()),
      );
    });

    test('opener failure is wrapped in MoshSessionException', () async {
      final service = MoshSessionService(
        _FakeExecutor(client: _FakeSshClient()),
        openSession: ({
          required MoshServerConfig server,
          required MoshCipher cipher,
          required int columns,
          required int rows,
        }) async {
          throw StateError('no route to host');
        },
      );

      await expectLater(
        service.connect(
          const MoshEndpoint(host: 'h', port: 60001, key: _key),
          columns: 80,
          rows: 24,
        ),
        throwsA(isA<MoshSessionException>()),
      );
    });

    test('slow opener throws MoshSessionException', () async {
      final service = MoshSessionService(
        _FakeExecutor(client: _FakeSshClient()),
        openSession: ({
          required MoshServerConfig server,
          required MoshCipher cipher,
          required int columns,
          required int rows,
        }) {
          return Completer<MoshSession>().future;
        },
        connectTimeout: const Duration(milliseconds: 30),
      );

      await expectLater(
        service.connect(
          const MoshEndpoint(host: 'h', port: 60001, key: _key),
          columns: 80,
          rows: 24,
        ),
        throwsA(isA<MoshSessionException>()),
      );
    });
  });
}
