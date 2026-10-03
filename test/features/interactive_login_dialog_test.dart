import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/features/agents/interactive_login_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/fixed_terminal_settings.dart';

/// Fake remote PTY.
///
/// `SSHSession` is a concrete class in dartssh2 4.1.0, so this extends it and
/// overrides only what the bridge touches. `stdin` is backed by a controller
/// the test controls, which lets us record exactly what the dialog typed.
class _FakeSshSession implements SSHSession {
  final _stdin = StreamController<Uint8List>();
  final _stdout = StreamController<Uint8List>();
  final _stderr = StreamController<Uint8List>();

  bool closed = false;

  /// Everything written to the remote PTY, decoded as UTF-8.
  final List<String> writes = [];

  @override
  StreamSink<Uint8List> get stdin {
    _stdin.stream.listen(
      (bytes) => writes.add(utf8.decode(bytes, allowMalformed: true)),
      onError: (_) {},
    );
    return _stdin.sink;
  }

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  /// Simulates the remote program printing to the terminal.
  void emit(String text) {
    if (!_stdout.isClosed) _stdout.add(utf8.encode(text));
  }

  /// Simulates the remote side dropping the channel.
  Future<void> drop() async {
    if (!_stdout.isClosed) await _stdout.close();
    if (!_stderr.isClosed) await _stderr.close();
  }

  @override
  void close() {
    closed = true;
    _stdout.close();
    _stderr.close();
    _stdin.close();
  }

  @override
  void resizeTerminal(int width, int height, [int pw = 0, int ph = 0]) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `SSHClient` fake that records `shell()` calls and hands out fake sessions.
class _FakeSshClient implements SSHClient {
  _FakeSshClient({this.shellGate});

  /// When set, `shell()` waits on this so the test can hold the bridge in
  /// `connecting` and assert nothing was sent prematurely.
  final Future<void>? shellGate;

  final List<_FakeSshSession> sessions = [];

  int shellCallCount = 0;

  /// The most recently allocated PTY.
  _FakeSshSession get session => sessions.last;
  bool _closed = false;

  @override
  bool get isClosed => _closed;

  @override
  Future<SSHSession> shell({
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    shellCallCount++;
    if (shellGate != null) await shellGate;
    final created = _FakeSshSession();
    sessions.add(created);
    return created;
  }

  int executeCallCount = 0;
  final List<String> executedCommands = [];

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    executeCallCount++;
    executedCommands.add(command);
    if (shellGate != null) await shellGate;
    final created = _FakeSshSession();
    sessions.add(created);
    return created;
  }

  @override
  Future<void> close() async {
    _closed = true;
    for (final s in sessions) {
      s.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Every command dispatched across all PTYs the client allocated, in order.
///
/// Derived from the recorded PTY writes by splitting on newline. A reconnect
/// allocates a second PTY, so all sessions must be scanned rather than just the
/// latest one.
List<String> _commandsFrom(_FakeSshClient client) {
  return [
    for (final session in client.sessions)
      for (final write in session.writes)
        if (write.contains('\n')) write.split('\n').first,
  ];
}

void main() {
  Widget host(Widget child) {
    return ProviderScope(
      overrides: fixedTerminalSettingsOverrides(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  /// The dialog shows an indeterminate progress spinner while the login command
  /// runs, which never stops animating. `pumpAndSettle` would therefore time
  /// out, so all waits use bounded pumps instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpDialog(
    WidgetTester tester, {
    required String command,
    required SSHClient? sshClient,
    String? remoteExecCommand,
  }) {
    return tester.pumpWidget(
      host(
        InteractiveLoginDialog(
          agentName: 'Codex Agent',
          command: command,
          serverName: 'Production US',
          sshClient: sshClient,
          remoteExecCommand: remoteExecCommand,
        ),
      ),
    );
  }

  group('InteractiveLoginDialog command dispatch', () {
    testWidgets('sends the command only after the PTY reaches connected', (
      tester,
    ) async {
      final gate = Completer<void>();
      final client = _FakeSshClient(shellGate: gate.future);

      await pumpDialog(tester, command: 'codex login', sshClient: client);
      await tester.pump();
      await tester.pump();

      // PTY not allocated yet: dispatching now would silently drop the command.
      expect(_commandsFrom(client), isEmpty, reason: '命令必须在 PTY 就绪后才发送，否则会被丢弃');

      gate.complete();
      await settle(tester);

      expect(_commandsFrom(client), ['codex login']);
    });

    testWidgets('does not send or allocate a PTY when client is null', (
      tester,
    ) async {
      await pumpDialog(tester, command: 'codex login', sshClient: null);
      await settle(tester);

      expect(find.text('Close'), findsOneWidget);
      expect(
        find.text('SSH connection lost. The login session was interrupted.'),
        findsOneWidget,
      );
    });

    testWidgets('does not allocate a PTY when the client is already closed', (
      tester,
    ) async {
      final client = _FakeSshClient();
      await client.close();

      await pumpDialog(tester, command: 'codex login', sshClient: client);
      await settle(tester);

      expect(client.shellCallCount, 0);
    });

    testWidgets(
      'passes remoteExecCommand to TerminalSessionBridge and executes directly without stdin send',
      (tester) async {
        final client = _FakeSshClient();
        const dockerExec = "docker exec -it 'my-box' sh -c 'codex login'";

        await pumpDialog(
          tester,
          command: 'codex login',
          sshClient: client,
          remoteExecCommand: dockerExec,
        );
        await settle(tester);

        expect(client.executeCallCount, 1);
        expect(client.executedCommands, [dockerExec]);
        expect(client.shellCallCount, 0);
        expect(
          _commandsFrom(client),
          isEmpty,
          reason:
              'remoteExecCommand 已通过 SSH exec 运行，不应在 stdin 重复写入 loginCommand',
        );
      },
    );

    testWidgets(
      'reconnect with remoteExecCommand preserves remoteExecCommand dispatch',
      (tester) async {
        final client = _FakeSshClient();
        const dockerExec = "docker exec -it 'my-box' sh -c 'codex login'";

        await pumpDialog(
          tester,
          command: 'codex login',
          sshClient: client,
          remoteExecCommand: dockerExec,
        );
        await settle(tester);
        expect(client.executeCallCount, 1);

        await client.session.drop();
        await settle(tester);

        await tester.tap(find.text('Reconnect Terminal'));
        await settle(tester);

        expect(client.executeCallCount, 2);
        expect(client.executedCommands, [dockerExec, dockerExec]);
        expect(_commandsFrom(client), isEmpty);
      },
    );
  });

  group('InteractiveLoginDialog lifecycle', () {
    testWidgets('closes the remote PTY when the dialog is disposed', (
      tester,
    ) async {
      final client = _FakeSshClient();

      await pumpDialog(tester, command: 'codex login', sshClient: client);
      await settle(tester);
      expect(client.session.closed, isFalse);

      await tester.pumpWidget(host(const Scaffold(body: SizedBox())));
      await settle(tester);

      expect(client.session.closed, isTrue, reason: '弹窗关闭必须释放 PTY，否则远端会残留登录进程');
    });

    testWidgets('shows the disconnected banner when the remote PTY dies', (
      tester,
    ) async {
      final client = _FakeSshClient();

      await pumpDialog(tester, command: 'codex login', sshClient: client);
      await settle(tester);
      expect(
        find.text('SSH connection lost. The login session was interrupted.'),
        findsNothing,
      );

      await client.session.drop();
      await settle(tester);

      expect(
        find.text('SSH connection lost. The login session was interrupted.'),
        findsOneWidget,
      );
      expect(find.text('Reconnect Terminal'), findsOneWidget);
    });

    testWidgets('reconnect allocates a fresh PTY and resends the command', (
      tester,
    ) async {
      final client = _FakeSshClient();

      await pumpDialog(tester, command: 'codex login', sshClient: client);
      await settle(tester);
      expect(client.shellCallCount, 1);
      expect(_commandsFrom(client), ['codex login']);

      await client.session.drop();
      await settle(tester);

      await tester.tap(find.text('Reconnect Terminal'));
      await settle(tester);

      expect(client.shellCallCount, 2);
      expect(_commandsFrom(client), ['codex login', 'codex login']);
    });

    testWidgets('returns true on Finish & Verify and null on Close', (
      tester,
    ) async {
      final client = _FakeSshClient();
      bool? result;
      var opened = false;

      await tester.pumpWidget(
        host(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  opened = true;
                  result = await showInteractiveLoginDialog(
                    context: context,
                    agentName: 'Codex Agent',
                    command: 'codex login',
                    serverName: 'Production US',
                    sshClient: client,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(opened, isTrue);
      expect(find.text('Interactive Login Terminal - Codex Agent'), findsOne);

      await tester.tap(find.text('Finish & Verify'));
      await settle(tester);
      expect(result, isTrue);
    });

    testWidgets('Close returns null so the caller skips the re-probe', (
      tester,
    ) async {
      final client = _FakeSshClient();
      bool? result;

      await tester.pumpWidget(
        host(
          Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showInteractiveLoginDialog(
                    context: context,
                    agentName: 'Codex Agent',
                    command: 'codex login',
                    serverName: 'Production US',
                    sshClient: client,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Open'));
      await settle(tester);

      await tester.tap(find.text('Close'));
      await settle(tester);
      expect(result, isNull);
    });
  });

  group('InteractiveLoginDialog login URL copy', () {
    /// Intercepts the platform clipboard channel so we can assert exactly what
    /// the user would get, rather than trusting an internal call.
    late List<MethodCall> clipboardCalls;
    String? clipboardText;

    setUp(() {
      clipboardCalls = [];
      clipboardText = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            clipboardCalls.add(call);
            if (call.method == 'Clipboard.setData') {
              clipboardText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    /// Boots the dialog on a live fake PTY so the test can push terminal output.
    Future<_FakeSshClient> pumpConnectedDialog(WidgetTester tester) async {
      final client = _FakeSshClient();
      await pumpDialog(tester, command: 'codex login', sshClient: client);
      await settle(tester);
      return client;
    }

    /// Pushes remote output into the terminal, then waits past the provider's
    /// 250ms debounce so the URL state is refreshed.
    Future<void> emitAndSettle(
      WidgetTester tester,
      _FakeSshClient client,
      String text,
    ) async {
      client.session.emit(text);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
    }

    testWidgets('shows no URL chip when the output has no link', (
      tester,
    ) async {
      final client = await pumpConnectedDialog(tester);
      await emitAndSettle(tester, client, 'Starting login...\r\n');

      expect(find.byKey(const Key('loginUrlChip')), findsNothing);
    });

    testWidgets('shows a chip containing the printed login URL', (
      tester,
    ) async {
      final client = await pumpConnectedDialog(tester);
      await emitAndSettle(
        tester,
        client,
        'Open https://auth.example.com/device?code=ABCD-1234\r\n',
      );

      expect(find.byKey(const Key('loginUrlChip')), findsOneWidget);
      expect(
        find.textContaining('https://auth.example.com/device?code=ABCD-1234'),
        findsOneWidget,
      );
    });

    testWidgets('copies the full URL verbatim when the copy button is tapped', (
      tester,
    ) async {
      final client = await pumpConnectedDialog(tester);
      const url =
          'https://auth.example.com/oauth2/authorize?client_id=abc&scope=openid&state=xyz';
      await emitAndSettle(tester, client, 'Visit $url\r\n');

      await tester.tap(find.byKey(const Key('loginUrlCopyButton')));
      await settle(tester);

      expect(clipboardText, url);
      expect(
        clipboardCalls.any((c) => c.method == 'Clipboard.setData'),
        isTrue,
      );
    });

    testWidgets('copies a URL that arrived split across two writes', (
      tester,
    ) async {
      final client = await pumpConnectedDialog(tester);
      client.session.emit(
        'open https://auth.example.com/oauth2/authorize?client_id=abc&\r\n',
      );
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
      client.session.emit('scope=openid&state=xyz\r\n');
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);

      expect(find.byKey(const Key('loginUrlChip')), findsOneWidget);

      await tester.tap(find.byKey(const Key('loginUrlCopyButton')));
      await settle(tester);

      expect(
        clipboardText,
        'https://auth.example.com/oauth2/authorize?client_id=abc&scope=openid&state=xyz',
      );
    });

    testWidgets('copies the whole buffer via the copy-all fallback', (
      tester,
    ) async {
      final client = await pumpConnectedDialog(tester);
      await emitAndSettle(tester, client, 'codex login output line\r\n');

      await tester.tap(find.byKey(const Key('copyAllButton')));
      await settle(tester);

      expect(clipboardText, isNotNull);
      expect(clipboardText, contains('codex login output line'));
    });

    testWidgets('chip disappears when the terminal is disposed', (
      tester,
    ) async {
      final client = await pumpConnectedDialog(tester);
      await emitAndSettle(
        tester,
        client,
        'https://auth.example.com/device\r\n',
      );
      expect(find.byKey(const Key('loginUrlChip')), findsOneWidget);

      await tester.pumpWidget(host(const Scaffold(body: SizedBox())));
      await settle(tester);

      expect(find.byKey(const Key('loginUrlChip')), findsNothing);
    });
  });
}
