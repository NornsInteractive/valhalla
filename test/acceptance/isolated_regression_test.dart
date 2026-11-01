import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
// ignore: implementation_imports
import 'package:dartssh2/src/ssh_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/tmux_session_planner.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';

import '../support/fake_acp_transport.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';

class _FakeSshClient implements SSHClient {
  _FakeSshClient();

  String tmuxPath = '/usr/bin/tmux';
  final List<String> commands = [];
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
  void destroy([Object? error, StackTrace? stack]) {}

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

void main() {
  group('isolated SSH tmux discovery regression', () {
    test('directory query failure returns no discovered sockets', () async {
      final client = _FakeSshClient()
        ..onQuery = (command) {
          if (command.contains("sh -c 'printf")) {
            return _FakeSshSession(scriptedExitCode: 1);
          }
          throw StateError('Unexpected query: $command');
        };

      expect(
        await TerminalSessionBridge.discoverSocketSources(client),
        isEmpty,
      );
    });

    test('missing tmux returns no discovered sockets', () async {
      final client = _FakeSshClient()
        ..onQuery = (command) {
          if (command.contains("sh -c 'printf")) {
            return _FakeSshSession(stdout: utf8.encode('/tmp/tmux-1000\n'));
          }
          if (command.contains('command -v tmux')) {
            return _FakeSshSession(scriptedExitCode: 1);
          }
          throw StateError('Unexpected query: $command');
        };

      expect(
        await TerminalSessionBridge.discoverSocketSources(client),
        isEmpty,
      );
    });

    test(
      'discovers named and path sockets while deduplicating by path',
      () async {
        final client = _FakeSshClient()
          ..onQuery = (command) {
            if (command.contains("sh -c 'printf")) {
              return _FakeSshSession(stdout: utf8.encode('/tmp/tmux-1000\n'));
            }
            if (command.contains('command -v tmux')) {
              return _FakeSshSession(stdout: utf8.encode('/usr/bin/tmux\n'));
            }
            if (command.contains("ls -1 --")) {
              return _FakeSshSession(
                stdout: utf8.encode('valhalla\nshared\npointed\n'),
              );
            }
            if (command.contains('list-sessions')) {
              final name = command.contains("-L 'valhalla'")
                  ? 'valhalla'
                  : command.contains("-L 'shared'")
                  ? 'shared'
                  : 'pointed';
              final path = name == 'pointed'
                  ? '/tmp/tmux-1000/shared'
                  : '/tmp/tmux-1000/$name';
              return _FakeSshSession(stdout: utf8.encode('$path\n'));
            }
            throw StateError('Unexpected query: $command');
          };

        final found = await TerminalSessionBridge.discoverSocketSources(client);
        expect(found, hasLength(2));
        expect(found.map((item) => item.source.id).toList(), [
          'app:valhalla',
          'named:shared',
        ]);
        expect(found.map((item) => item.socketPath).toSet(), {
          '/tmp/tmux-1000/valhalla',
          '/tmp/tmux-1000/shared',
        });
      },
    );

    test(
      'probe with a non-missing server error uses display-message path',
      () async {
        final client = _FakeSshClient()
          ..onQuery = (command) {
            if (command.contains("sh -c 'printf")) {
              return _FakeSshSession(stdout: utf8.encode('/tmp/tmux-1000\n'));
            }
            if (command.contains('command -v tmux')) {
              return _FakeSshSession(stdout: utf8.encode('/usr/bin/tmux\n'));
            }
            if (command.contains("ls -1 --")) {
              return _FakeSshSession(stdout: utf8.encode('shared\n'));
            }
            if (command.contains('list-sessions')) {
              return _FakeSshSession(
                scriptedExitCode: 1,
                stderr: utf8.encode("permission denied\n"),
              );
            }
            if (command.contains('display-message')) {
              return _FakeSshSession(
                stdout: utf8.encode('/tmp/tmux-1000/shared\n'),
              );
            }
            throw StateError('Unexpected query: $command');
          };

        final found = await TerminalSessionBridge.discoverSocketSources(client);
        expect(found, hasLength(1));
        expect(found.single.source.id, 'named:shared');
        expect(found.single.socketPath, '/tmp/tmux-1000/shared');
      },
    );

    test('probe with invalid socket path is ignored', () async {
      final client = _FakeSshClient()
        ..onQuery = (command) {
          if (command.contains("sh -c 'printf")) {
            return _FakeSshSession(stdout: utf8.encode('/tmp/tmux-1000\n'));
          }
          if (command.contains('command -v tmux')) {
            return _FakeSshSession(stdout: utf8.encode('/usr/bin/tmux\n'));
          }
          if (command.contains("ls -1 --")) {
            return _FakeSshSession(stdout: utf8.encode('shared\n'));
          }
          if (command.contains('list-sessions')) {
            return _FakeSshSession(
              stdout: utf8.encode('not-an-absolute-path\n'),
            );
          }
          throw StateError('Unexpected query: $command');
        };

      expect(
        await TerminalSessionBridge.discoverSocketSources(client),
        isEmpty,
      );
    });

    test('probe permission failure is ignored', () async {
      final client = _FakeSshClient()
        ..onQuery = (command) {
          if (command.contains("sh -c 'printf")) {
            return _FakeSshSession(stdout: utf8.encode('/tmp/tmux-1000\n'));
          }
          if (command.contains('command -v tmux')) {
            return _FakeSshSession(stdout: utf8.encode('/usr/bin/tmux\n'));
          }
          if (command.contains("ls -1 --")) {
            return _FakeSshSession(stdout: utf8.encode('shared\n'));
          }
          if (command.contains('list-sessions')) {
            return _FakeSshSession(
              scriptedExitCode: 1,
              stderr: utf8.encode('permission denied\n'),
            );
          }
          throw StateError('Unexpected query: $command');
        };

      expect(
        await TerminalSessionBridge.discoverSocketSources(client),
        isEmpty,
      );
    });

    test(
      'identity mismatch returns false without changing the supplied identity',
      () async {
        final identity = TmuxSessionIdentity(
          sessionId: r'$7',
          createdSeconds: 1772000000,
          serverPid: 4211,
          socketPath: '/tmp/tmux-1000/shared',
        );
        final client = _FakeSshClient()
          ..onQuery = (command) => _FakeSshSession(
            stdout: utf8.encode(
              r'$7'
              '\u001f'
              '1772000000'
              '\u001f'
              '9999'
              '\u001f'
              '/tmp/tmux-1000/shared'
              '\n',
            ),
          );

        final exists = await TerminalSessionBridge.tmuxSessionExists(
          client,
          'unused',
          tmuxPath: '/usr/bin/tmux',
          socket: TmuxSocketSource.path('/tmp/tmux-1000/shared'),
          identity: identity,
        );

        expect(exists, isFalse);
        expect(identity.serverPid, 4211);
      },
    );
  });

  group('isolated ACP background recovery regression', () {
    test('a background turn completes normally without cancellation', () async {
      final pair = FakeAcpPair(sessionId: 'bg-regression')..holdPrompt = false;
      addTearDown(pair.close);
      final adapter = ACPClientAdapter(
        profile: testAgentProfile(),
        transport: pair.client,
        requestTimeout: const Duration(milliseconds: 300),
      );
      addTearDown(adapter.dispose);
      adapter.setInBackground(true);
      final events = <ACPEvent>[];
      final subscription = adapter.eventStream.listen(events.add);
      addTearDown(subscription.cancel);

      pair.promptUpdates = [
        {
          'sessionUpdate': 'agent_message_chunk',
          'content': {'type': 'text', 'text': 'done'},
        },
      ];
      await adapter.sendPrompt('quick question');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(events.whereType<ACPErrorEvent>(), isEmpty);
      expect(events.whereType<ACPCompleteEvent>(), isNotEmpty);
      expect(
        pair.sentToAgent.where((wire) => wire.contains('"session/cancel"')),
        isEmpty,
      );
      expect(adapter.isDisposed, isFalse);
    });
    test(
      'a background turn that fails surfaces an error without cancel or dispose',
      () async {
        // -32000 is ACP's authRequired code and would surface as a recoverable
        // auth challenge; use a generic remote error to exercise the error path.
        final pair = FakeAcpPair(sessionId: 'bg-fail')
          ..failPrompt = true
          ..promptErrorCode = -32001;
        addTearDown(pair.close);
        final adapter = ACPClientAdapter(
          profile: testAgentProfile(),
          transport: pair.client,
          requestTimeout: const Duration(milliseconds: 300),
        );
        addTearDown(adapter.dispose);
        adapter.setInBackground(true);
        final events = <ACPEvent>[];
        final subscription = adapter.eventStream.listen(events.add);
        addTearDown(subscription.cancel);

        await adapter.sendPrompt('will fail');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final errors = events.whereType<ACPErrorEvent>().toList();
        expect(errors, isNotEmpty);
        expect(errors.single.error, contains('ACP_REMOTE_ERROR'));
        expect(
          pair.sentToAgent.where((wire) => wire.contains('"session/cancel"')),
          isEmpty,
          reason: 'a failing background turn must not be cancelled as idle',
        );
        expect(adapter.isDisposed, isFalse);
      },
    );
  });
}
