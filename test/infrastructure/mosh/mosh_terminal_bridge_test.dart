import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/mosh/mosh_session_service.dart';
import 'package:valhalla/infrastructure/mosh/mosh_terminal_bridge.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart'
    show TerminalConnectionState;
import 'package:xterm/xterm.dart';

const _key = 'AAECAwQFBgcICQoLDA0ODw';

const _request = MoshBootstrapRequest(serverId: 'srv-1', host: '203.0.113.10');

final _success = MoshBootstrapSuccess(
  endpoint: MoshEndpoint(host: '203.0.113.10', port: 60001, key: _key),
  rawOutput: 'MOSH CONNECT 60001 $_key',
  locale: 'en_US.UTF-8',
);

class _FakeHandle implements MoshSessionHandle {
  final _stdout = StreamController<List<int>>();
  final _errors = StreamController<Object>();
  final _done = Completer<void>();
  final sent = <List<int>>[];
  final sizes = <(int, int)>[];
  var disposeCount = 0;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> get done => _done.future;

  @override
  void send(List<int> bytes) => sent.add(bytes);

  @override
  void resize(int columns, int rows) => sizes.add((columns, rows));

  @override
  Future<void> dispose() async {
    disposeCount++;
    if (!_done.isCompleted) _done.complete();
  }

  /// 模拟远端输出（完整文本）。
  void emit(String text) => _stdout.add(utf8.encode(text));

  /// 模拟远端输出（原始字节，用于拆开的 UTF-8 序列）。
  void emitBytes(List<int> bytes) => _stdout.add(bytes);

  /// 模拟 server 进程退出（会话终态）。
  void end() {
    if (!_done.isCompleted) _done.complete();
  }
}

class _FakeService implements MoshSessionService {
  _FakeService();

  MoshBootstrapResult? bootstrapResult;
  MoshSessionHandle? connectHandle;
  Object? connectError;

  /// 挂住 bootstrap，验证 dispose 后的迟到完成不会产生副作用。
  Completer<void>? bootstrapGate;

  var bootstrapCalls = 0;
  var connectCalls = 0;
  MoshEndpoint? lastEndpoint;
  (int, int)? lastSize;

  @override
  Future<MoshBootstrapResult> bootstrap(MoshBootstrapRequest request) async {
    bootstrapCalls++;
    if (bootstrapGate != null) await bootstrapGate!.future;
    final result = bootstrapResult;
    if (result != null) return result;
    throw StateError('no bootstrap result scripted');
  }

  @override
  Future<MoshSessionHandle> connect(
    MoshEndpoint endpoint, {
    required int columns,
    required int rows,
  }) async {
    connectCalls++;
    lastEndpoint = endpoint;
    lastSize = (columns, rows);
    if (connectError != null) throw connectError!;
    final handle = connectHandle;
    if (handle == null) throw StateError('no handle scripted');
    return handle;
  }
}

_FakeService _connectedService(_FakeHandle handle) => _FakeService()
  ..bootstrapResult = _success
  ..connectHandle = handle;

void main() {
  group('bridge state machine', () {
    test(
      'start goes connecting -> connected and forwards stdout to terminal',
      () async {
        final handle = _FakeHandle();
        final service = _connectedService(handle);
        final bridge = MoshTerminalBridge(
          terminal: Terminal(maxLines: 200),
          sessionService: service,
          request: _request,
          serverName: 'nas',
        );
        final states = <TerminalConnectionState>[];
        bridge.stateListenable.addListener(
          () => states.add(bridge.stateListenable.value),
        );
        addTearDown(bridge.dispose);

        await bridge.start(initialWidth: 100, initialHeight: 30);

        expect(bridge.state, TerminalConnectionState.connected);
        expect(states, [
          TerminalConnectionState.connecting,
          TerminalConnectionState.connected,
        ]);
        expect(service.connectCalls, 1);
        expect(service.lastEndpoint!.port, 60001);
        expect(service.lastSize, (100, 30));

        handle.emit('hello mosh');
        // 拆开的 UTF-8 序列也要能拼出「文」。
        handle.emitBytes([0xe6]);
        handle.emitBytes([0x96, 0x87]);
        await Future<void>.delayed(Duration.zero);
        final text = bridge.terminal.buffer.getText();
        expect(text, contains('hello mosh'));
        expect(text, contains('文'));
      },
    );

    test('terminal input reaches session.send and resize is debounced',
        () async {
      final handle = _FakeHandle();
      final bridge = MoshTerminalBridge(
        terminal: Terminal(maxLines: 200),
        sessionService: _connectedService(handle),
        request: _request,
        serverName: 'nas',
      );
      addTearDown(bridge.dispose);
      await bridge.start();

      bridge.terminal.onOutput!('ls -l\n');
      expect(utf8.decode(handle.sent.single), 'ls -l\n');

      bridge.terminal.onResize!(100, 30, 0, 0);
      bridge.terminal.onResize!(120, 40, 0, 0);
      expect(handle.sizes, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(handle.sizes, [(120, 40)]);
    });

    test('session end moves to disconnected and disposes the handle once',
        () async {
      final handle = _FakeHandle();
      final bridge = MoshTerminalBridge(
        terminal: Terminal(maxLines: 200),
        sessionService: _connectedService(handle),
        request: _request,
        serverName: 'nas',
      );
      addTearDown(bridge.dispose);
      await bridge.start();

      handle.end();
      await Future<void>.delayed(Duration.zero);

      expect(bridge.state, TerminalConnectionState.disconnected);
      expect(handle.disposeCount, 1);
    });

    test('bootstrap failure surfaces the classified error', () async {
      final service =
          _FakeService()
            ..bootstrapResult = const MoshBootstrapFailure(
              error: MoshBootstrapError.notInstalled,
              detail: 'exit code 1',
            );
      final bridge = MoshTerminalBridge(
        terminal: Terminal(maxLines: 200),
        sessionService: service,
        request: _request,
        serverName: 'nas',
      );
      addTearDown(bridge.dispose);

      await bridge.start();

      expect(bridge.state, TerminalConnectionState.error);
      expect(bridge.bootstrapError, MoshBootstrapError.notInstalled);
      expect(bridge.bootstrapErrorDetail, 'exit code 1');
      expect(service.connectCalls, 0);
    });

    test('connect failure surfaces the error state', () async {
      final service =
          _FakeService()
            ..bootstrapResult = _success
            ..connectError = const MoshSessionException('boom');
      final bridge = MoshTerminalBridge(
        terminal: Terminal(maxLines: 200),
        sessionService: service,
        request: _request,
        serverName: 'nas',
      );
      addTearDown(bridge.dispose);

      await bridge.start();

      expect(bridge.state, TerminalConnectionState.error);
      expect(bridge.bootstrapError, isNull);
    });
  });

  group('bridge lifecycle', () {
    test('dispose is idempotent and ignores a stale bootstrap completion',
        () async {
      final gate = Completer<void>();
      final service =
          _FakeService()
            ..bootstrapResult = _success
            ..connectHandle = _FakeHandle()
            ..bootstrapGate = gate;
      final bridge = MoshTerminalBridge(
        terminal: Terminal(maxLines: 200),
        sessionService: service,
        request: _request,
        serverName: 'nas',
      );
      final states = <TerminalConnectionState>[];
      bridge.stateListenable.addListener(
        () => states.add(bridge.stateListenable.value),
      );

      final started = bridge.start();
      await Future<void>.delayed(Duration.zero);
      bridge.dispose();
      bridge.dispose();
      gate.complete();
      await started;

      expect(service.connectCalls, 0);
      expect(states, [TerminalConnectionState.connecting]);
    });

    test('late stdout after dispose does not reach the terminal', () async {
      final handle = _FakeHandle();
      final bridge = MoshTerminalBridge(
        terminal: Terminal(maxLines: 200),
        sessionService: _connectedService(handle),
        request: _request,
        serverName: 'nas',
      );
      await bridge.start();
      final before = bridge.terminal.buffer.getText();

      bridge.dispose();
      handle.emit('late output');
      await Future<void>.delayed(Duration.zero);

      expect(bridge.terminal.buffer.getText(), before);
    });
  });
}
