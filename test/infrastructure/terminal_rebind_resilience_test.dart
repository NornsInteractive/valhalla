import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
// SSHSession.channel has a public getter but this type is not re-exported.
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:xterm/xterm.dart';

/// 最小可用的假 SSH 客户端：plain 模式下 bridge 只需要 `shell()`。
class _FakeSshClient implements SSHClient {
  _FakeSshSession? lastSession;

  @override
  bool get isClosed => false;

  @override
  Future<SSHSession> shell({
    SSHPtyConfig? pty = const SSHPtyConfig(),
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    final session = _FakeSshSession();
    lastSession = session;
    return session;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSshSession implements SSHSession {
  bool closed = false;
  bool destroyed = false;
  final _stdout = StreamController<Uint8List>();
  final _stderr = StreamController<Uint8List>();

  @override
  SSHChannel get channel => _FakeSshChannel(this);

  @override
  StreamSink<Uint8List> get stdin => _RecordingSink();

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
    session.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingSink implements StreamSink<Uint8List> {
  @override
  void add(Uint8List data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Uint8List> stream) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> get done => Future<void>.value();
}

/// rebind 直接抛异常的 bridge，模拟重挂过程中的意外失败。
class _ThrowingBridge extends TerminalSessionBridge {
  int rebindCalls = 0;

  _ThrowingBridge(Terminal terminal)
    : super(terminal: terminal, serverName: 'fixture');

  @override
  Future<void> rebind(SSHClient client) async {
    rebindCalls++;
    throw StateError('rebind exploded');
  }
}

void main() {
  test('第一个标签页 rebind 抛异常，后续标签页仍然被重挂', () async {
    final badTerminal = Terminal(maxLines: 100);
    final badBridge = _ThrowingBridge(badTerminal);
    final badTab = TerminalTab(
      id: 't1',
      title: 'bad',
      terminal: badTerminal,
      bridge: badBridge,
    );

    final goodTerminal = Terminal(maxLines: 100);
    final goodBridge = TerminalSessionBridge(
      terminal: goodTerminal,
      sshClient: _FakeSshClient(),
      serverName: 'prod',
    );
    final goodTab = TerminalTab(
      id: 't2',
      title: 'good',
      terminal: goodTerminal,
      bridge: goodBridge,
    );

    final nextClient = _FakeSshClient();
    // 绝不能向外抛异常：坏标签页已被记录并跳过。
    await rebindTabsAfterReconnect([badTab, goodTab], nextClient);

    expect(badBridge.rebindCalls, 1);
    expect(
      goodBridge.sshClient,
      same(nextClient),
      reason: '坏标签页不能挡住其余标签页换上新客户端',
    );
    expect(goodBridge.state, TerminalConnectionState.connected);
    expect(
      badTerminal.buffer.getText(),
      contains('Reconnect failed for this tab'),
      reason: '坏标签页要留下诊断信息，不能无声无息地卡死',
    );
  });

  test('坏标签页排在后面时前面的标签页先被重挂', () async {
    final goodTerminal = Terminal(maxLines: 100);
    final goodBridge = TerminalSessionBridge(
      terminal: goodTerminal,
      sshClient: _FakeSshClient(),
      serverName: 'prod',
    );
    final goodTab = TerminalTab(
      id: 't1',
      title: 'good',
      terminal: goodTerminal,
      bridge: goodBridge,
    );
    final badTerminal = Terminal(maxLines: 100);
    final badTab = TerminalTab(
      id: 't2',
      title: 'bad',
      terminal: badTerminal,
      bridge: _ThrowingBridge(badTerminal),
    );

    final nextClient = _FakeSshClient();
    await rebindTabsAfterReconnect([goodTab, badTab], nextClient);

    expect(goodBridge.sshClient, same(nextClient));
    expect(goodBridge.state, TerminalConnectionState.connected);
  });
}
