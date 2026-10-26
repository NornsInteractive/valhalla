import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
// SSHSession.channel has a public getter but this type is not re-exported.
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/utils/tmux_session_planner.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';

/// 只实现 bridge 静态查询用到的那一小块 SSHClient 表面。
class _FakeSshClient implements SSHClient {
  _FakeSshClient();

  /// `command -v tmux` 的返回路径。
  String tmuxPath = '/usr/bin/tmux';

  /// 记录 bridge 发出的每一条完整命令。
  final List<String> commands = [];

  /// 回答除探测之外的所有查询。
  SSHSession Function(String command)? onQuery;

  @override
  bool get isClosed => false;

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    commands.add(command);
    if (command == 'LC_ALL=C ${TmuxSessionPlanner.detectCommand}') {
      return _FakeSshSession(stdout: utf8.encode('$tmuxPath\n'));
    }
    final handler = onQuery;
    if (handler != null) return handler(command);
    throw StateError('Unexpected query: $command');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 把 bridge 的查询当成本地 shell 命令执行，用于真实 tmux 的隔离往返。
///
/// 这里永远不会建立任何 SSH 连接：命令只在本地 shell 里跑。
class _LocalShellSshClient implements SSHClient {
  final List<String> commands = [];

  @override
  bool get isClosed => false;

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    commands.add(command);
    // stdoutEncoding: null 保留原始字节，由 bridge 自己按 utf8 解码。
    final result = await Process.run(
      'sh',
      ['-c', command],
      stdoutEncoding: null,
      stderrEncoding: null,
    );
    return _FakeSshSession(
      scriptedExitCode: result.exitCode,
      stdout: result.stdout as List<int>,
      stderr: result.stderr as List<int>,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSshSession implements SSHSession {
  _FakeSshSession({
    this.scriptedExitCode = 0,
    List<int>? stdout,
    List<int>? stderr,
  }) {
    _stdoutController = StreamController<Uint8List>();
    _stderrController = StreamController<Uint8List>();
    _doneCompleter = Completer<void>();
    scheduleMicrotask(() {
      if (stdout != null && stdout.isNotEmpty) {
        _stdoutController.add(Uint8List.fromList(stdout));
      }
      _stdoutController.close();
      if (stderr != null && stderr.isNotEmpty) {
        _stderrController.add(Uint8List.fromList(stderr));
      }
      _stderrController.close();
      if (!_doneCompleter.isCompleted) _doneCompleter.complete();
    });
  }

  final int scriptedExitCode;

  late final StreamController<Uint8List> _stdoutController;
  late final StreamController<Uint8List> _stderrController;
  late final Completer<void> _doneCompleter;

  bool destroyed = false;

  @override
  Stream<Uint8List> get stdout => _stdoutController.stream;

  @override
  Stream<Uint8List> get stderr => _stderrController.stream;

  @override
  StreamSink<Uint8List> get stdin => _NullSink();

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  int? get exitCode => scriptedExitCode;

  @override
  SSHChannel get channel => _FakeSshChannel(this);

  @override
  void close() {}

  @override
  void resizeTerminal(int width, int height, [int pw = 0, int ph = 0]) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSshChannel implements SSHChannel {
  _FakeSshChannel(this.session);

  final _FakeSshSession session;

  @override
  void destroy([Object? error, StackTrace? stack]) {
    session.destroyed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NullSink implements StreamSink<Uint8List> {
  @override
  void add(Uint8List data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Uint8List> stream) => stream.drain<void>();

  @override
  Future<void> close() async {}

  @override
  Future<void> get done => Future<void>.value();
}

/// 六字段外部会话行：`session_id / created / attached / pid / socket / name`。
String _sessionLine({
  required TmuxSessionIdentity identity,
  int attached = 0,
  required String name,
}) =>
    '${identity.sessionId}\t${identity.createdSeconds}\t$attached\t'
    '${identity.serverPid}\t${identity.socketPath}\t$name';

/// `display-message -p` 的四字段身份行。
String _identityLine(TmuxSessionIdentity identity) =>
    '${identity.sessionId}\t${identity.createdSeconds}\t'
    '${identity.serverPid}\t${identity.socketPath}';

TmuxSessionIdentity _identity({
  String sessionId = r'$7',
  int createdSeconds = 1772000000,
  int serverPid = 4211,
  String socketPath = '/tmp/tmux-1000/shared',
}) => TmuxSessionIdentity(
  sessionId: sessionId,
  createdSeconds: createdSeconds,
  serverPid: serverPid,
  socketPath: socketPath,
);

/// 本机是否装了 tmux；真实往返用例据此决定要不要跳过。
bool get _tmuxInstalled {
  try {
    final result = Process.runSync('sh', ['-c', 'command -v tmux']);
    return result.exitCode == 0 && '${result.stdout}'.trim().isNotEmpty;
  } catch (_) {
    return false;
  }
}

void main() {
  group('六字段外部会话发现', () {
    test('显式 -L default 只查询 default 服务器', () async {
      final identity = _identity(
        sessionId: r'$3',
        socketPath: '/tmp/x/default',
      );
      final client = _FakeSshClient()
        ..onQuery = (command) => _FakeSshSession(
          stdout: utf8.encode(
            '${_sessionLine(identity: identity, name: 'ext default')}\n',
          ),
        );

      final sessions = await TerminalSessionBridge.discoverTmuxSessions(
        client,
        serverId: 'srv-1',
        socket: TmuxSocketSource.standard,
        includeExternal: true,
      );

      expect(sessions, hasLength(1));
      final query = client.commands.last;
      expect(query, contains('-L default'));
      expect(query, isNot(contains('-L valhalla')));
      expect(query, contains('list-sessions'));

      final info = sessions.single;
      expect(info.name, 'ext default');
      expect(info.socket.id, TmuxSocketSource.standard.id);
      expect(info.attachedClients, 0);
      expect(info.identity, isNotNull);
      expect(info.identity!.sessionId, r'$3');
      expect(info.identity!.createdSeconds, 1772000000);
      expect(info.identity!.serverPid, 4211);
      expect(info.identity!.socketPath, '/tmp/x/default');
      expect(
        info.createdAt.millisecondsSinceEpoch,
        info.identity!.createdSeconds * 1000,
      );
    });

    test('显式 -L <自定义名> 只查询自定义服务器', () async {
      final identity = _identity(sessionId: r'$2', socketPath: '/tmp/x/team');
      final client = _FakeSshClient()
        ..onQuery = (command) => _FakeSshSession(
          stdout: utf8.encode(
            '${_sessionLine(identity: identity, attached: 3, name: 'ext team')}\n',
          ),
        );

      final sessions = await TerminalSessionBridge.discoverTmuxSessions(
        client,
        serverId: 'srv-1',
        socket: TmuxSocketSource.named('team'),
        includeExternal: true,
      );

      expect(sessions, hasLength(1));
      final query = client.commands.last;
      expect(query, contains("-L 'team'"));
      expect(query, isNot(contains('-L default')));
      expect(query, isNot(contains('-L valhalla')));

      final info = sessions.single;
      expect(info.name, 'ext team');
      expect(info.socket.id, 'named:team');
      expect(info.attachedClients, 3);
      expect(info.identity!.sessionId, r'$2');
    });

    test('显式 -S <路径> 只查询自定义 socket', () async {
      const socketPath = '/tmp/valhalla-custom.sock';
      final identity = _identity(sessionId: r'$1', socketPath: socketPath);
      final client = _FakeSshClient()
        ..onQuery = (command) => _FakeSshSession(
          stdout: utf8.encode(
            '${_sessionLine(identity: identity, name: 'ext path')}\n',
          ),
        );

      final sessions = await TerminalSessionBridge.discoverTmuxSessions(
        client,
        serverId: 'srv-1',
        socket: TmuxSocketSource.path(socketPath),
        includeExternal: true,
      );

      expect(sessions, hasLength(1));
      final query = client.commands.last;
      expect(query, contains("-S '$socketPath'"));
      expect(query, isNot(contains('-L default')));
      expect(query, isNot(contains('-L valhalla')));

      final info = sessions.single;
      expect(info.name, 'ext path');
      expect(info.socket.id, 'path:$socketPath');
      expect(info.identity!.socketPath, socketPath);
    });

    test('外部 socket 必须显式开启 external 模式', () async {
      final client = _FakeSshClient();
      await expectLater(
        TerminalSessionBridge.discoverTmuxSessions(
          client,
          serverId: 'srv-1',
          socket: TmuxSocketSource.standard,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'TMUX_INVALID_SESSION_IDENTITY',
          ),
        ),
        reason: '非 app socket 必须走 external 分支，否则会按 app 语义误判',
      );
      expect(client.commands, isEmpty, reason: '非法参数不应发出任何远端命令');
    });
  });

  group('外部会话只允许按身份操作', () {
    test('任意 Unicode 名字只通过身份寻址，名字不进命令', () async {
      const unicodeName = 'проект 🚀 日本語 "quoted" it\'s';
      final identity = _identity(sessionId: r'$5');
      final client = _FakeSshClient()
        ..onQuery = (command) {
          if (command.contains('list-sessions')) {
            return _FakeSshSession(
              stdout: utf8.encode(
                '${_sessionLine(identity: identity, name: unicodeName)}\n',
              ),
            );
          }
          if (command.contains('display-message')) {
            return _FakeSshSession(
              stdout: utf8.encode('${_identityLine(identity)}\n'),
            );
          }
          if (command.contains('kill-session')) {
            return _FakeSshSession();
          }
          throw StateError('Unexpected query: $command');
        };

      final sessions = await TerminalSessionBridge.discoverTmuxSessions(
        client,
        serverId: 'srv-1',
        socket: TmuxSocketSource.standard,
        includeExternal: true,
      );
      expect(sessions.single.name, unicodeName);
      expect(sessions.single.identity!.key, identity.key);

      expect(
        await TerminalSessionBridge.tmuxSessionExists(
          client,
          unicodeName,
          tmuxPath: '/usr/bin/tmux',
          socket: TmuxSocketSource.standard,
          identity: identity,
        ),
        isTrue,
      );
      final existsQuery = client.commands.last;
      expect(existsQuery, contains("'\$5'"));
      expect(
        existsQuery,
        isNot(contains(unicodeName)),
        reason: '外部会话名绝不能拼进远端命令',
      );

      await TerminalSessionBridge.terminateTmuxSession(
        client,
        unicodeName,
        tmuxPath: '/usr/bin/tmux',
        socket: TmuxSocketSource.standard,
        identity: identity,
      );
      final killQuery = client.commands.last;
      expect(killQuery, contains('kill-session'));
      expect(killQuery, contains("'\$5'"));
      expect(killQuery, isNot(contains(unicodeName)));
    });

    test('没有身份时外部 socket 拒绝按名字操作', () async {
      final client = _FakeSshClient();

      await expectLater(
        TerminalSessionBridge.tmuxSessionExists(
          client,
          'anything',
          tmuxPath: '/usr/bin/tmux',
          socket: TmuxSocketSource.standard,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'TMUX_INVALID_SESSION_IDENTITY',
          ),
        ),
      );

      await expectLater(
        TerminalSessionBridge.terminateTmuxSession(
          client,
          'anything',
          tmuxPath: '/usr/bin/tmux',
          socket: TmuxSocketSource.standard,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'TMUX_INVALID_SESSION_IDENTITY',
          ),
        ),
      );

      expect(client.commands, isEmpty, reason: '拒绝发生在发出命令之前');
    });

    test('app socket 仍可按名字操作，但名字必须是本应用的会话名', () async {
      final client = _FakeSshClient()..onQuery = (command) => _FakeSshSession();

      expect(
        await TerminalSessionBridge.tmuxSessionExists(
          client,
          'valhalla_srv-1_tab-1',
          tmuxPath: '/usr/bin/tmux',
        ),
        isTrue,
      );
      expect(client.commands.last, contains('has-session'));
      expect(client.commands.last, contains("'=valhalla_srv-1_tab-1'"));

      await expectLater(
        TerminalSessionBridge.tmuxSessionExists(
          client,
          'проjekt 🚀',
          tmuxPath: '/usr/bin/tmux',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'TMUX_INVALID_SESSION_NAME',
          ),
        ),
      );
    });
  });

  group('has-session 的身份匹配', () {
    test('身份完全一致时判定存在', () async {
      final identity = _identity();
      final client = _FakeSshClient()
        ..onQuery = (command) => _FakeSshSession(
          stdout: utf8.encode('${_identityLine(identity)}\n'),
        );

      expect(
        await TerminalSessionBridge.tmuxSessionExists(
          client,
          'ext',
          tmuxPath: '/usr/bin/tmux',
          socket: TmuxSocketSource.standard,
          identity: identity,
        ),
        isTrue,
      );
    });

    test('同名但身份不同（pid/创建时间/socket 不同）时判定不存在', () async {
      final identity = _identity();
      final client = _FakeSshClient()
        ..onQuery = (command) => _FakeSshSession(
          stdout: utf8.encode('${_identityLine(_identity(serverPid: 4212))}\n'),
        );

      expect(
        await TerminalSessionBridge.tmuxSessionExists(
          client,
          'ext',
          tmuxPath: '/usr/bin/tmux',
          socket: TmuxSocketSource.standard,
          identity: identity,
        ),
        isFalse,
        reason: '会话被重建后旧身份必须失效',
      );
    });

    test('会话已经不在时判定不存在而不是报错', () async {
      final identity = _identity();
      final client = _FakeSshClient()
        ..onQuery = (command) => _FakeSshSession(
          scriptedExitCode: 1,
          stderr: utf8.encode("can't find session: ${identity.sessionId}\n"),
        );

      expect(
        await TerminalSessionBridge.tmuxSessionExists(
          client,
          'ext',
          tmuxPath: '/usr/bin/tmux',
          socket: TmuxSocketSource.standard,
          identity: identity,
        ),
        isFalse,
      );
    });

    test('服务器整体消失时判定不存在', () async {
      final identity = _identity();
      final client = _FakeSshClient()
        ..onQuery = (command) => _FakeSshSession(
          scriptedExitCode: 1,
          stderr: utf8.encode('no server running on /tmp/tmux-1000/shared\n'),
        );

      expect(
        await TerminalSessionBridge.tmuxSessionExists(
          client,
          'ext',
          tmuxPath: '/usr/bin/tmux',
          socket: TmuxSocketSource.standard,
          identity: identity,
        ),
        isFalse,
      );
    });
  });

  group('非法响应必须抛错', () {
    Future<void> expectInvalidResponse(
      String payload, {
      required String reason,
    }) async {
      final client = _FakeSshClient()
        ..onQuery = (command) => _FakeSshSession(stdout: utf8.encode(payload));
      await expectLater(
        TerminalSessionBridge.discoverTmuxSessions(
          client,
          serverId: 'srv-1',
          socket: TmuxSocketSource.standard,
          includeExternal: true,
        ),
        throwsA(
          isA<SSHConnectionException>().having(
            (e) => e.message,
            'message',
            'TMUX_HISTORY_INVALID_RESPONSE',
          ),
        ),
        reason: reason,
      );
    }

    test('字段数不是六时抛错', () async {
      await expectInvalidResponse(
        '\$3\t1772000000\t0\t4211\t/tmp/x/shared\n',
        reason: '缺 name 字段时不能猜',
      );
    });

    test('会话名为空时抛错', () async {
      await expectInvalidResponse(
        '\$3\t1772000000\t0\t4211\t/tmp/x/shared\t\n',
        reason: '空名字无法被引用',
      );
    });

    test('会话名含控制字符时抛错', () async {
      await expectInvalidResponse(
        '\$3\t1772000000\t0\t4211\t/tmp/x/shared\tbad\nname\n',
        reason: '控制字符不能进入会话名',
      );
    });

    test('attached 不是数字时抛错', () async {
      await expectInvalidResponse(
        '\$3\t1772000000\tx\t4211\t/tmp/x/shared\tname\n',
        reason: 'attached 无法解析时不能默认成 0',
      );
    });

    test('身份字段无法解析时抛错而不是静默接受', () async {
      final client = _FakeSshClient()
        ..onQuery = (command) => _FakeSshSession(
          stdout: utf8.encode(
            '\$3\tnot-a-number\t0\t4211\t/tmp/x/shared\tname\n',
          ),
        );
      await expectLater(
        TerminalSessionBridge.discoverTmuxSessions(
          client,
          serverId: 'srv-1',
          socket: TmuxSocketSource.standard,
          includeExternal: true,
        ),
        throwsA(anything),
        reason: '身份字段坏掉时必须抛错，绝不能返回半可信的身份',
      );
    });

    test('身份查询响应字段数不对时抛错', () async {
      final client = _FakeSshClient()
        ..onQuery = (command) =>
            _FakeSshSession(stdout: utf8.encode('\$3\t1772000000\t4211\n'));
      await expectLater(
        TerminalSessionBridge.tmuxSessionExists(
          client,
          'ext',
          tmuxPath: '/usr/bin/tmux',
          socket: TmuxSocketSource.standard,
          identity: _identity(),
        ),
        throwsA(
          isA<SSHConnectionException>().having(
            (e) => e.message,
            'message',
            'TMUX_HISTORY_INVALID_RESPONSE',
          ),
        ),
      );
    });

    test('tmux 服务器不存在时返回空列表而不是抛错', () async {
      final client = _FakeSshClient()
        ..onQuery = (command) => _FakeSshSession(
          scriptedExitCode: 1,
          stderr: utf8.encode('no server running on /tmp/x/shared\n'),
        );

      expect(
        await TerminalSessionBridge.discoverTmuxSessions(
          client,
          serverId: 'srv-1',
          socket: TmuxSocketSource.standard,
          includeExternal: true,
        ),
        isEmpty,
      );
    });

    test('查询本身失败时抛错而不是当成空列表', () async {
      final client = _FakeSshClient()
        ..onQuery = (command) => _FakeSshSession(
          scriptedExitCode: 2,
          stderr: utf8.encode('permission denied\n'),
        );

      await expectLater(
        TerminalSessionBridge.discoverTmuxSessions(
          client,
          serverId: 'srv-1',
          socket: TmuxSocketSource.standard,
          includeExternal: true,
        ),
        throwsA(isA<SSHConnectionException>()),
      );
    });
  });

  group('default 与 app 服务器不串台', () {
    test('同名会话在两个 socket 上互不串台', () async {
      const sharedName = 'valhalla_work';
      final appIdentity = _identity(
        sessionId: r'$1',
        serverPid: 100,
        socketPath: '/tmp/tmux-1000/valhalla',
      );
      final defaultIdentity = _identity(
        sessionId: r'$9',
        serverPid: 200,
        socketPath: '/tmp/tmux-1000/default',
      );
      final client = _FakeSshClient()
        ..onQuery = (command) {
          if (command.contains('-L default')) {
            return _FakeSshSession(
              stdout: utf8.encode(
                '${_sessionLine(identity: defaultIdentity, name: sharedName)}\n',
              ),
            );
          }
          if (command.contains('-L valhalla')) {
            return _FakeSshSession(
              stdout: utf8.encode(
                '${_sessionLine(identity: appIdentity, name: sharedName)}\n',
              ),
            );
          }
          throw StateError('Unexpected socket in: $command');
        };

      final app = await TerminalSessionBridge.discoverTmuxSessions(
        client,
        serverId: 'srv-1',
        socket: TmuxSocketSource.app,
        includeExternal: true,
      );
      final standard = await TerminalSessionBridge.discoverTmuxSessions(
        client,
        serverId: 'srv-1',
        socket: TmuxSocketSource.standard,
        includeExternal: true,
      );

      expect(app.single.name, sharedName);
      expect(app.single.socket.id, TmuxSocketSource.app.id);
      expect(app.single.identity!.sessionId, r'$1');
      expect(standard.single.name, sharedName);
      expect(standard.single.socket.id, TmuxSocketSource.standard.id);
      expect(standard.single.identity!.sessionId, r'$9');
      expect(
        app.single.identity!.key,
        isNot(standard.single.identity!.key),
        reason: '两个服务器上的同名会话必须是不同的身份',
      );

      final appQuery = client.commands[1];
      expect(appQuery, contains('-L valhalla'));
      expect(appQuery, isNot(contains('-L default')));
      final standardQuery = client.commands[3];
      expect(standardQuery, contains('-L default'));
      expect(standardQuery, isNot(contains('-L valhalla')));
    });

    test('socket 参数互不相同，app 与 default 永远是两个服务器', () {
      expect(
        TmuxSessionPlanner.socketArguments(TmuxSocketSource.app),
        '-L valhalla',
      );
      expect(
        TmuxSessionPlanner.socketArguments(TmuxSocketSource.standard),
        '-L default',
      );
      expect(
        TmuxSessionPlanner.socketArguments(TmuxSocketSource.named('team')),
        "-L 'team'",
      );
      expect(
        TmuxSessionPlanner.socketArguments(
          TmuxSocketSource.path('/tmp/x.sock'),
        ),
        "-S '/tmp/x.sock'",
      );
    });
  });

  group('真实 tmux 隔离往返', () {
    late Directory tempDir;
    late String socketPath;
    late TmuxSocketSource socketSource;
    late _LocalShellSshClient client;
    late String tmuxPath;

    /// 本次用例自己创建、需要在收尾时逐个杀掉的会话名。
    final owned = <String>[];

    setUp(() async {
      // 只在临时目录里建 socket，绝不碰用户已有的 tmux socket。
      tempDir = await Directory.systemTemp.createTemp(
        'valhalla-tmux-multisocket-',
      );
      socketPath = '${tempDir.path}/tmux.sock';
      socketSource = TmuxSocketSource.path(socketPath);
      client = _LocalShellSshClient();
      tmuxPath = await TerminalSessionBridge.tmuxExecutable(client);
    });

    tearDown(() async {
      // 只逐个杀掉本用例创建的会话；永远不用 kill-server。
      for (final name in owned) {
        await Process.run(tmuxPath, [
          '-S',
          socketPath,
          'kill-session',
          '-t',
          name,
        ]);
      }
      owned.clear();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    /// 建一个只属于本用例的 fixture 会话。
    Future<String> createFixture(String name) async {
      final result = await Process.run(tmuxPath, [
        '-S',
        socketPath,
        'new-session',
        '-d',
        '-s',
        name,
        'sleep 60',
      ]);
      expect(result.exitCode, 0, reason: 'fixture 会话必须创建成功: ${result.stderr}');
      if (!owned.contains(name)) owned.add(name);
      return name;
    }

    Future<List<TmuxSessionInfo>> discover() =>
        TerminalSessionBridge.discoverTmuxSessions(
          client,
          serverId: 'srv-1',
          socket: socketSource,
          includeExternal: true,
        );

    test('发现、校验身份、改名、终止后再发现为空', () async {
      final name = 'valhalla_ms_${pid}_a';
      await createFixture(name);

      final sessions = await discover();
      expect(sessions, hasLength(1));
      final info = sessions.single;
      expect(info.name, name);
      expect(info.socket.id, socketSource.id);
      expect(info.attachedClients, 0);
      expect(info.identity, isNotNull);
      final identity = info.identity!;
      expect(identity.sessionId, matches(RegExp(r'^\$\d+$')));
      expect(identity.serverPid, greaterThan(0));
      expect(identity.socketPath, socketPath);
      expect(
        info.createdAt.millisecondsSinceEpoch,
        identity.createdSeconds * 1000,
      );

      expect(
        await TerminalSessionBridge.tmuxSessionExists(
          client,
          name,
          tmuxPath: tmuxPath,
          socket: socketSource,
          identity: identity,
        ),
        isTrue,
        reason: '刚发现的身份必须能再次验证通过',
      );

      final renamed = '${name}_renamed';
      final rename = await Process.run(tmuxPath, [
        '-S',
        socketPath,
        'rename-session',
        '-t',
        name,
        renamed,
      ]);
      expect(rename.exitCode, 0, reason: '改名必须成功: ${rename.stderr}');
      owned[owned.indexOf(name)] = renamed;

      final afterRename = await discover();
      expect(afterRename, hasLength(1));
      expect(afterRename.single.name, renamed);
      expect(
        afterRename.single.identity!.key,
        identity.key,
        reason: '改名不改变会话身份',
      );

      await TerminalSessionBridge.terminateTmuxSession(
        client,
        renamed,
        tmuxPath: tmuxPath,
        socket: socketSource,
        identity: identity,
      );

      expect(await discover(), isEmpty, reason: '终止后必须发现不到会话');
    });

    test('同名重建后旧身份失配，旧终止不会误杀新会话', () async {
      final name = 'valhalla_ms_${pid}_recreate';
      await createFixture(name);

      final first = (await discover()).single;
      final firstIdentity = first.identity!;

      await TerminalSessionBridge.terminateTmuxSession(
        client,
        name,
        tmuxPath: tmuxPath,
        socket: socketSource,
        identity: firstIdentity,
      );
      expect(await discover(), isEmpty);

      // 同名重建：这是「历史记录里的会话已经被同名新会话顶掉」的真实场景。
      // 注意 tmux 服务器退出后会重新从 $0 开始编号，新旧会话可能拿到同一个
      // session id；真正区分它们的是身份里的 serverPid / createdSeconds。
      await createFixture(name);
      final second = (await discover()).single;
      final secondIdentity = second.identity!;
      expect(secondIdentity.key, isNot(firstIdentity.key), reason: '重建后必须是新身份');

      expect(
        await TerminalSessionBridge.tmuxSessionExists(
          client,
          name,
          tmuxPath: tmuxPath,
          socket: socketSource,
          identity: firstIdentity,
        ),
        isFalse,
        reason: '旧身份不能匹配到同名的新会话',
      );

      await TerminalSessionBridge.terminateTmuxSession(
        client,
        name,
        tmuxPath: tmuxPath,
        socket: socketSource,
        identity: firstIdentity,
      );

      expect(
        await TerminalSessionBridge.tmuxSessionExists(
          client,
          name,
          tmuxPath: tmuxPath,
          socket: socketSource,
          identity: secondIdentity,
        ),
        isTrue,
        reason: '用旧身份终止不能杀掉同名的新会话',
      );
      final remaining = await discover();
      expect(remaining, hasLength(1));
      expect(remaining.single.name, name);
      expect(remaining.single.identity!.key, secondIdentity.key);
    });
    group('畸形响应的稳定错误码与脱敏回显', () {
      test('发现响应畸形：稳定错误码 + 原始输出脱敏并 JSON 转义', () async {
        final malformed =
            '\$3\t1772000000\tx\t4211\t/tmp/x/shared\t'
            'Name"With\\Quote password=s3cr3tPASS';
        final client = _FakeSshClient()
          ..onQuery = (command) =>
              _FakeSshSession(stdout: utf8.encode(malformed));
        SSHConnectionException? caught;
        try {
          await TerminalSessionBridge.discoverTmuxSessions(
            client,
            serverId: 'srv-1',
            socket: TmuxSocketSource.standard,
            includeExternal: true,
          );
        } on SSHConnectionException catch (e) {
          caught = e;
        }
        expect(caught, isNotNull, reason: '畸形响应必须抛错');
        expect(
          caught!.message,
          'TMUX_HISTORY_INVALID_RESPONSE',
          reason: '错误码必须稳定，不随输出内容变化',
        );
        final details = caught.details as String;
        expect(details, contains('******'), reason: '密钥必须被脱敏');
        expect(details, isNot(contains('s3cr3tPASS')), reason: '原始口令不得明文出现');
        expect(details, contains(r'\"'), reason: '原始双引号必须被 JSON 转义');
        expect(details, contains(r'\\'), reason: '原始反斜杠必须被 JSON 转义');
        expect(
          details,
          isNot(contains(r'Name"With\Quote')),
          reason: '回显必须是转义后的文本，而非原始输出',
        );
        expect(
          client.commands.last,
          contains('-L default'),
          reason: '外部 socket 的严格断言必须保留',
        );
        expect(client.commands.last, contains('list-sessions'));
      });

      test('身份响应畸形：稳定错误码 + 原始输出脱敏并 JSON 转义', () async {
        final malformed = '\$3\t1772000000\ttoken=AbCdEf12345 "quote';
        final identity = _identity(sessionId: r'$3');
        final client = _FakeSshClient()
          ..onQuery = (command) =>
              _FakeSshSession(stdout: utf8.encode(malformed));
        SSHConnectionException? caught;
        try {
          await TerminalSessionBridge.tmuxSessionExists(
            client,
            'ext',
            tmuxPath: '/usr/bin/tmux',
            socket: TmuxSocketSource.standard,
            identity: identity,
          );
        } on SSHConnectionException catch (e) {
          caught = e;
        }
        expect(caught, isNotNull, reason: '畸形身份响应必须抛错');
        expect(
          caught!.message,
          'TMUX_HISTORY_INVALID_RESPONSE',
          reason: '错误码必须稳定',
        );
        final details = caught.details as String;
        expect(details, contains('******'), reason: 'token 必须被脱敏');
        expect(
          details,
          isNot(contains('AbCdEf12345')),
          reason: '原始 token 不得明文出现',
        );
        expect(details, contains(r'\"'), reason: '原始双引号必须被 JSON 转义');
        expect(
          client.commands.last,
          contains('-L default'),
          reason: '外部 socket 的严格断言必须保留',
        );
        expect(
          client.commands.last,
          contains("'\$3'"),
          reason: '身份寻址的严格断言必须保留',
        );
      });

      test('输出超过 4096 时 details 必须截断到 4096', () async {
        final huge = '\$3\t1772000000\tx\t4211\t/tmp/x/shared\t${'A' * 5000}';
        final client = _FakeSshClient()
          ..onQuery = (command) => _FakeSshSession(stdout: utf8.encode(huge));
        SSHConnectionException? caught;
        try {
          await TerminalSessionBridge.discoverTmuxSessions(
            client,
            serverId: 'srv-1',
            socket: TmuxSocketSource.standard,
            includeExternal: true,
          );
        } on SSHConnectionException catch (e) {
          caught = e;
        }
        expect(caught, isNotNull);
        final details = caught!.details as String;
        expect(details.length, 4096, reason: 'details 不得超过 4096');
        expect(details, startsWith('exit=0;'));
      });
    });
  }, skip: _tmuxInstalled ? null : '本机没有安装 tmux，跳过真实 tmux 往返');
}
