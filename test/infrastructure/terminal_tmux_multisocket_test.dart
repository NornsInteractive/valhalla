import 'dart:async';
import 'dart:convert';
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
    '${identity.sessionId}$_sep${identity.createdSeconds}$_sep$attached'
    '$_sep${identity.serverPid}$_sep${identity.socketPath}$_sep$name';

/// `display-message -p` 的四字段身份行。
String _identityLine(TmuxSessionIdentity identity) =>
    '${identity.sessionId}$_sep${identity.createdSeconds}$_sep'
    '${identity.serverPid}$_sep${identity.socketPath}';

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

/// 真实协议字段分隔符（碰撞安全的 U+001F）。模拟输出必须与之完全一致，
/// 否则生产解析器（按 U+001F 拆分）会把历史/测试用的旧制表符分隔当作非法响应。
const String _sep = TmuxSessionPlanner.fieldSeparator;


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
        '\$3${_sep}1772000000${_sep}0${_sep}4211$_sep/tmp/x/shared\n',
        reason: '缺 name 字段时不能猜',
      );
    });

    test('会话名为空时抛错', () async {
      await expectInvalidResponse(
        '\$3${_sep}1772000000${_sep}0${_sep}4211$_sep/tmp/x/shared$_sep\n',
        reason: '空名字无法被引用',
      );
    });

    test('会话名含控制字符时抛错', () async {
      await expectInvalidResponse(
        '\$3${_sep}1772000000${_sep}0${_sep}4211$_sep/tmp/x/shared${_sep}bad\nname\n',
        reason: '控制字符不能进入会话名',
      );
    });

    test('attached 不是数字时抛错', () async {
      await expectInvalidResponse(
        '\$3${_sep}1772000000${_sep}x${_sep}4211$_sep/tmp/x/shared${_sep}name\n',
        reason: 'attached 无法解析时不能默认成 0',
      );
    });

    test('身份字段无法解析时抛错而不是静默接受', () async {
      final client = _FakeSshClient()
        ..onQuery = (command) => _FakeSshSession(
          stdout: utf8.encode(
            '\$3${_sep}not-a-number${_sep}0${_sep}4211$_sep/tmp/x/shared${_sep}name\n',
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
            _FakeSshSession(stdout: utf8.encode('\$3${_sep}1772000000${_sep}4211\n'));
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

}
