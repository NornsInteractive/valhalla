import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
// SSHSession.channel has a public getter but this type is not re-exported.
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/tmux_install_planner.dart';
import 'package:valhalla/core/utils/tmux_session_planner.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:xterm/xterm.dart';

/// 假的 SSH 客户端，只实现 bridge 用到的方法。
class _FakeSshClient implements SSHClient {
  _FakeSshClient({this.tmuxPath, this.packageManager = 'none'});

  /// 非 null 时 `command -v tmux` 返回它；null 表示未安装（空输出）。
  String? tmuxPath;

  /// 包管理器探测输出。
  final String packageManager;

  /// 记录 `run` 收到的命令。
  final List<String> runCommands = [];
  final List<String> executedCommands = [];

  /// 让探测抛错，验证降级路径。
  bool failDetect = false;

  /// 设置后，包管理器探测会挂在这里等待，用来验证「探测慢也不阻塞 PTY」。
  Completer<void>? gatePackageManagerProbe;

  _FakeSshSession? lastSession;
  Completer<SSHSession>? gateShell;

  /// 记录最后一次 shell 请求的 PTY 尺寸。
  int? lastPtyWidth;
  int? lastPtyHeight;

  @override
  bool get isClosed => false;

  @override
  Future<Uint8List> run(
    String command, {
    bool runInPty = false,
    bool stdout = true,
    bool stderr = true,
    Map<String, String>? environment,
  }) async {
    runCommands.add(command);
    if (failDetect) throw StateError('detect failed');
    if (command == TmuxSessionPlanner.detectCommand) {
      return Uint8List.fromList(utf8.encode(tmuxPath ?? ''));
    }
    if (command == TmuxInstallPlanner.detectPackageManagerCommand) {
      await gatePackageManagerProbe?.future;
    }
    return Uint8List.fromList(utf8.encode(packageManager));
  }

  @override
  Future<SSHSession> shell({
    SSHPtyConfig? pty = const SSHPtyConfig(),
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    lastPtyWidth = pty?.width;
    lastPtyHeight = pty?.height;
    final session = _FakeSshSession();
    lastSession = session;
    return gateShell == null ? session : await gateShell!.future;
  }

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    executedCommands.add(command);
    lastPtyWidth = pty?.width;
    lastPtyHeight = pty?.height;
    final session = _FakeSshSession();
    lastSession = session;
    return session;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 已经关闭的客户端，用于验证 rebind 的降级分支。
class _ClosedSshClient extends _FakeSshClient {
  _ClosedSshClient() : super(tmuxPath: '/usr/bin/tmux');

  @override
  bool get isClosed => true;
}

class _FakeSshSession implements SSHSession {
  bool closed = false;
  bool destroyed = false;
  @override
  SSHChannel get channel => _FakeSshChannel(this);
  final sizes = <(int, int, int, int)>[];
  final _RecordingSink _stdin = _RecordingSink();
  final _stdout = StreamController<Uint8List>();
  final _stderr = StreamController<Uint8List>();

  /// 便于断言写入内容的访问器。
  _RecordingSink get sink => _stdin;

  @override
  StreamSink<Uint8List> get stdin => _stdin;

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  Future<void> get done => Completer<void>().future;

  @override
  int? get exitCode => 0;

  @override
  void close() {
    closed = true;
  }

  @override
  void resizeTerminal(int width, int height, [int pw = 0, int ph = 0]) {
    sizes.add((width, height, pw, ph));
  }

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

class _RecordingSink implements StreamSink<Uint8List> {
  final List<String> written = [];

  String get text => written.join();

  @override
  void add(Uint8List data) =>
      written.add(utf8.decode(data, allowMalformed: true));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Uint8List> stream) => stream.forEach(add);

  @override
  Future<void> close() async {}

  @override
  Future<void> get done => Future<void>.value();
}

Terminal _terminal() => Terminal(maxLines: 200);

void main() {
  test(
    'disposing an open terminal destroys its channel instead of only sending EOF',
    () async {
      final client = _FakeSshClient();
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client,
        serverName: 'fixture',
      );
      await bridge.start();
      bridge.dispose();
      expect(client.lastSession!.destroyed, isTrue);
      expect(client.isClosed, isFalse);
    },
  );

  test(
    'terminal decodes split UTF-8 independently on stdout and stderr while input remains live',
    () async {
      final client = _FakeSshClient();
      final terminal = _terminal();
      final bridge = TerminalSessionBridge(
        terminal: terminal,
        sshClient: client,
        serverName: 'fixture',
      );
      addTearDown(bridge.dispose);
      await bridge.start();
      final session = client.lastSession!;
      session._stdout.add(Uint8List.fromList([230]));
      session._stderr.add(Uint8List.fromList([229]));
      await Future<void>.delayed(Duration.zero);
      terminal.onOutput!('echo ready\n');
      expect(session.sink.text, 'echo ready\n');
      for (final byte in [150, 135]) {
        session._stdout.add(Uint8List.fromList([byte]));
      }
      for (final byte in [173, 151]) {
        session._stderr.add(Uint8List.fromList([byte]));
      }
      await Future<void>.delayed(Duration.zero);
      expect(terminal.buffer.getText(), contains('文'));
      expect(terminal.buffer.getText(), contains('字'));
      expect(terminal.buffer.getText(), isNot(contains('\uFFFD')));
    },
  );

  test(
    'disposing while PTY allocation is pending closes late channel without publishing stale state',
    () async {
      final gate = Completer<SSHSession>();
      final client = _FakeSshClient()..gateShell = gate;
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client,
        serverName: 'test',
      );
      final started = bridge.start();
      await Future<void>.delayed(Duration.zero);
      bridge.dispose();
      bridge.dispose();
      gate.complete(client.lastSession!);
      await started;
      expect(client.lastSession!.closed, isTrue);
      expect(client.lastSession!.destroyed, isTrue);
      expect(client.lastSession!.sink.text, isEmpty);
    },
  );
  testWidgets(
    'PTY resize keeps latest size, deduplicates and cancels on dispose',
    (tester) async {
      final client = _FakeSshClient();
      final terminal = _terminal();
      final bridge = TerminalSessionBridge(
        terminal: terminal,
        sshClient: client,
        serverName: 'test',
        launchCommand: 'exec codex',
      );
      await bridge.start();
      expect(client.lastSession!.sink.text, contains('exec codex\n'));
      terminal.onResize!(90, 30, 0, 0);
      terminal.onResize!(95, 32, 0, 0);
      await tester.pump(const Duration(milliseconds: 74));
      expect(client.lastSession!.sizes, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(client.lastSession!.sizes, [(95, 32, 0, 0)]);
      terminal.onResize!(95, 32, 0, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(client.lastSession!.sizes, hasLength(1));
      terminal.onResize!(100, 35, 0, 0);
      bridge.dispose();
      await tester.pump(const Duration(milliseconds: 100));
      expect(client.lastSession!.sizes, hasLength(1));
    },
  );
  group('TerminalSessionBridge tmux 集成', () {
    test('远端有 tmux 时附着到独立 socket 会话', () async {
      final client = _FakeSshClient(tmuxPath: '/usr/bin/tmux');
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client,
        serverName: 'prod',
        serverId: 'srv-1',
        terminalId: 'tab-1',
        preferTmux: true,
      );
      addTearDown(bridge.dispose);

      await bridge.start();
      // tmux 通过 SSH exec + PTY 启动，不写入交互式 shell history。
      await Future<void>.delayed(Duration.zero);

      expect(bridge.mode, TerminalSessionMode.tmux);
      expect(client.runCommands, [TmuxSessionPlanner.detectCommand]);

      expect(client.lastSession?.sink.text, isEmpty);
      expect(client.executedCommands.single, contains('-L valhalla'));
      expect(client.executedCommands.single, contains('new-session -A'));
      expect(client.executedCommands.single, contains('valhalla_srv-1_tab-1'));
    });

    test('远端没有 tmux 时仍先开普通 PTY，同时进入询问态', () async {
      final client = _FakeSshClient(tmuxPath: null, packageManager: 'apt');
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client,
        serverName: 'prod',
        serverId: 'srv-1',
        preferTmux: true,
      );
      addTearDown(bridge.dispose);

      await bridge.start();
      await Future<void>.delayed(Duration.zero);

      expect(bridge.mode, TerminalSessionMode.tmuxUnavailable);
      expect(bridge.awaitingTmuxDecision, isTrue);
      expect(
        bridge.proposedInstallCommand,
        TmuxInstallPlanner.installCommandFor('apt'),
      );
      // 关键：不能因为要问用户就把终端搭进去当人质。以前这里会停在
      // connecting 且没有 PTY，调用方会一直转圈、敲什么都没反应。
      expect(bridge.state, TerminalConnectionState.connected);
      expect(
        client.lastSession,
        isNotNull,
        reason: '必须先有可用 PTY，绝不能卡在 connecting',
      );
      expect(
        client.runCommands,
        isNot(
          contains(
            predicate((c) {
              return c.toString().contains('install');
            }),
          ),
        ),
      );
    });

    test('用户拒绝安装后走普通 SSH PTY', () async {
      final client = _FakeSshClient(tmuxPath: null, packageManager: 'apt');
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client,
        serverName: 'prod',
        serverId: 'srv-1',
        preferTmux: true,
      );
      addTearDown(bridge.dispose);

      await bridge.start();
      await bridge.proceedWithoutTmux();
      await Future<void>.delayed(Duration.zero);

      expect(bridge.awaitingTmuxDecision, isFalse);
      expect(client.lastSession, isNotNull);
      expect(bridge.state, TerminalConnectionState.connected);
      // 拒绝后仍在普通 PTY 上跑（先开 PTY 保底的路径），只是 mode 保留
      // tmuxUnavailable 以记录「本来想用 tmux 但没装」。
      final written = client.lastSession?.sink.text ?? '';
      expect(written, isNot(contains('tmux -L')));
    });

    test('安装成功后重新探测并附着 tmux', () async {
      final client = _FakeSshClient(tmuxPath: null, packageManager: 'apt');
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client,
        serverName: 'prod',
        serverId: 'srv-1',
        terminalId: 'tab-1',
        preferTmux: true,
      );
      addTearDown(bridge.dispose);

      await bridge.start();
      expect(bridge.awaitingTmuxDecision, isTrue);

      client.tmuxPath = '/usr/bin/tmux';
      await bridge.retryAfterTmuxInstall();
      await Future<void>.delayed(Duration.zero);

      expect(bridge.mode, TerminalSessionMode.tmux);
      expect(bridge.awaitingTmuxDecision, isFalse);
      expect(client.executedCommands.single, contains('-L valhalla'));
      expect(client.lastSession!.sink.text, isEmpty);
    });

    test('探测失败时降级为普通 PTY，不因探测异常而卡住', () async {
      final client = _FakeSshClient(tmuxPath: '/usr/bin/tmux')
        ..failDetect = true;
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client,
        serverName: 'prod',
        serverId: 'srv-1',
        preferTmux: true,
      );
      addTearDown(bridge.dispose);

      await bridge.start();
      await Future<void>.delayed(Duration.zero);

      expect(bridge.mode, TerminalSessionMode.tmuxUnavailable);
      expect(bridge.awaitingTmuxDecision, isTrue);
      // 探测本身抛异常也必须有一个可用的 shell，而不是留个转圈界面。
      expect(bridge.state, TerminalConnectionState.connected);
      expect(client.lastSession, isNotNull);
    });

    test('preferTmux=false 时完全不探测 tmux', () async {
      final client = _FakeSshClient(tmuxPath: '/usr/bin/tmux');
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client,
        serverName: 'prod',
        serverId: 'srv-1',
        preferTmux: false,
      );
      addTearDown(bridge.dispose);

      await bridge.start();

      expect(bridge.mode, TerminalSessionMode.plain);
      expect(client.runCommands, isEmpty);
    });

    test('无法连接时进入 disconnected 而不是假装 tmux', () async {
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: null,
        serverName: 'prod',
        serverId: 'srv-1',
      );
      addTearDown(bridge.dispose);

      await bridge.start();

      expect(bridge.state, TerminalConnectionState.disconnected);
      expect(bridge.mode, TerminalSessionMode.plain);
    });

    test('重建 bridge 后附着到同一个 tmux 会话（断线重连能接回内容）', () async {
      // 这是 tmux 保活的真实契约：同一个 serverId + terminalId 必须生成
      // 同一个会话名，否则「重连」只会开出一个空的新会话。
      final client1 = _FakeSshClient(tmuxPath: '/usr/bin/tmux');
      final first = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client1,
        serverName: 'prod',
        serverId: 'srv-1',
        terminalId: 'tab-1',
        preferTmux: true,
      );
      addTearDown(first.dispose);
      await first.start();
      await Future<void>.delayed(Duration.zero);
      final firstCommand = client1.executedCommands.single;

      // 模拟断线后重建 bridge。
      final client2 = _FakeSshClient(tmuxPath: '/usr/bin/tmux');
      final second = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client2,
        serverName: 'prod',
        serverId: 'srv-1',
        terminalId: 'tab-1',
        preferTmux: true,
      );
      addTearDown(second.dispose);
      await second.start();
      await Future<void>.delayed(Duration.zero);
      final secondCommand = client2.executedCommands.single;

      expect(secondCommand, firstCommand, reason: '同名会话 + -A 才能 attach 回原来的内容');
      expect(secondCommand, contains('-s valhalla_srv-1_tab-1'));
    });

    test('开关 ON 且缺 tmux：PTY 可用、状态 connected，绝不卡在 connecting', () async {
      final client = _FakeSshClient(tmuxPath: null, packageManager: 'apt');
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client,
        serverName: 'prod',
        serverId: 'srv-1',
        preferTmux: true,
      );
      addTearDown(bridge.dispose);

      await bridge.start();

      // 这是本次修复的核心契约。旧实现会停在 connecting 且 lastSession 为
      // null，调用方（codex login 弹窗）因此永远等不到 connected。
      expect(bridge.state, TerminalConnectionState.connected);
      expect(client.lastSession, isNotNull);
      expect(bridge.mode, TerminalSessionMode.tmuxUnavailable);
      expect(bridge.awaitingTmuxDecision, isTrue);
    });

    test('安装命令探测再怎么慢也不阻塞 PTY 打开', () async {
      final client = _FakeSshClient(tmuxPath: null, packageManager: 'apt')
        ..gatePackageManagerProbe = Completer<void>();
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client,
        serverName: 'prod',
        serverId: 'srv-1',
        preferTmux: true,
      );
      addTearDown(bridge.dispose);

      await bridge.start();

      // 探测还被 gate 着，但 shell 必须已经给到用户手里。
      expect(bridge.state, TerminalConnectionState.connected);
      expect(client.lastSession, isNotNull);
      expect(bridge.proposedInstallCommand, isNull, reason: '探测还没返回');

      client.gatePackageManagerProbe!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(
        bridge.proposedInstallCommand,
        TmuxInstallPlanner.installCommandFor('apt'),
      );
    });

    test('已经是普通 PTY 时拒绝安装不重建会话', () async {
      final client = _FakeSshClient(tmuxPath: null, packageManager: 'apt');
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client,
        serverName: 'prod',
        serverId: 'srv-1',
        preferTmux: true,
      );
      addTearDown(bridge.dispose);

      await bridge.start();
      final firstSession = client.lastSession;
      expect(firstSession, isNotNull);

      await bridge.proceedWithoutTmux();

      expect(
        client.lastSession,
        same(firstSession),
        reason: '已经是普通 PTY 了，重开会闪屏并丢掉回滚缓冲',
      );
      expect(bridge.awaitingTmuxDecision, isFalse);
      // mode 保持 tmuxUnavailable 是刻意的：它记录「这台机器本来想用 tmux
      // 但没装成」，UI 据此继续显示非阻塞提示。会话本身已经是普通 PTY。
      expect(bridge.mode, TerminalSessionMode.tmuxUnavailable);
      expect(bridge.state, TerminalConnectionState.connected);
    });
  });

  group('TerminalSessionBridge.rebind 断线重连', () {
    test('换用新客户端后复用同一个 tmux 会话，且保留终端缓冲', () async {
      final terminal = _terminal();
      final first = _FakeSshClient(tmuxPath: '/usr/bin/tmux');
      final bridge = TerminalSessionBridge(
        terminal: terminal,
        sshClient: first,
        serverName: 'prod',
        serverId: 'srv-1',
        terminalId: 'tab-1',
        preferTmux: true,
      );
      addTearDown(bridge.dispose);
      await bridge.start();
      await Future<void>.delayed(Duration.zero);
      final before = first.executedCommands.single;

      // 断线前的输出必须留着 —— 用户靠它看上下文。
      terminal.write('marker-before-drop');

      final second = _FakeSshClient(tmuxPath: '/usr/bin/tmux');
      await bridge.rebind(second);
      await Future<void>.delayed(Duration.zero);

      expect(bridge.mode, TerminalSessionMode.tmux);
      expect(second.executedCommands.single, before, reason: '要 attach 回原会话');
      expect(bridge.sshClient, same(second), reason: '必须换成新的客户端');
      expect(
        terminal.buffer.getText(),
        contains('marker-before-drop'),
        reason: '重建终端会把回滚缓冲清空，用户就看不到断线前的输出了',
      );
    });

    test('重连后 mode 仍为 tmuxUnavailable 时不假装能恢复', () async {
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: _FakeSshClient(),
        serverName: 'prod',
        serverId: 'srv-1',
        terminalId: 'tab-1',
        preferTmux: true,
      );
      addTearDown(bridge.dispose);
      await bridge.start();
      expect(bridge.mode, TerminalSessionMode.tmuxUnavailable);
      expect(bridge.state, TerminalConnectionState.connected);
      expect(bridge.awaitingTmuxDecision, isTrue);

      await bridge.rebind(_FakeSshClient());
      await Future<void>.delayed(Duration.zero);

      expect(bridge.mode, TerminalSessionMode.tmuxUnavailable);
      expect(bridge.state, TerminalConnectionState.connected);
      expect(bridge.awaitingTmuxDecision, isTrue);
    });

    test('重连时客户端已关闭则进入 disconnected，不抛异常', () async {
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: _FakeSshClient(tmuxPath: '/usr/bin/tmux'),
        serverName: 'prod',
        serverId: 'srv-1',
        terminalId: 'tab-1',
        preferTmux: true,
      );
      addTearDown(bridge.dispose);
      await bridge.start();

      await bridge.rebind(_ClosedSshClient());

      expect(bridge.state, TerminalConnectionState.disconnected);
    });

    test('重复 rebind 同一个客户端不重复建会话', () async {
      final client = _FakeSshClient(tmuxPath: '/usr/bin/tmux');
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client,
        serverName: 'prod',
        serverId: 'srv-1',
        terminalId: 'tab-1',
        preferTmux: true,
      );
      addTearDown(bridge.dispose);
      await bridge.start();
      await Future<void>.delayed(Duration.zero);

      final sessionAfterStart = client.lastSession;
      await bridge.rebind(client);

      expect(
        client.lastSession,
        same(sessionAfterStart),
        reason: '已经挂在这个客户端上就不该重建会话',
      );
    });

    test('重连用原来的 PTY 尺寸，避免 tmux 按默认 80x24 重排', () async {
      final client1 = _FakeSshClient(tmuxPath: '/usr/bin/tmux');
      final bridge = TerminalSessionBridge(
        terminal: _terminal(),
        sshClient: client1,
        serverName: 'prod',
        serverId: 'srv-1',
        terminalId: 'tab-1',
        preferTmux: true,
      );
      addTearDown(bridge.dispose);
      await bridge.start(initialWidth: 132, initialHeight: 43);
      await Future<void>.delayed(Duration.zero);

      final client2 = _FakeSshClient(tmuxPath: '/usr/bin/tmux');
      await bridge.rebind(client2);
      await Future<void>.delayed(Duration.zero);

      expect(client2.lastPtyWidth, 132);
      expect(client2.lastPtyHeight, 43);
    });
  });
}
