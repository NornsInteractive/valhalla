import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/acp/acp_oauth_request.dart';

/// Callback delivery contract: host/container routing, the authorization code
/// travelling only on stdin (never in argv or logs), and the SSH session being
/// closed again whatever the outcome.
const _challenge =
    'Open the following link to authenticate the ACP server: '
    'https://accounts.google.com/o/oauth2/v2/auth?client_id=abc'
    '&response_type=code'
    '&redirect_uri=http%3A%2F%2F127.0.0.1%3A8765%2Fcb'
    '&state=state-1';

const _secretCode = '4/0A-SECRET-AUTH-CODE';
const _callback = 'http://127.0.0.1:8765/cb?code=$_secretCode&state=state-1';

class _RecordingSink implements StreamSink<Uint8List> {
  _RecordingSink({this.onClose});

  /// Optional hook so a case can delay or fail `stdin.close()` itself.
  final Future<void> Function()? onClose;

  final List<int> bytes = [];
  String get text => utf8.decode(bytes);

  @override
  void add(Uint8List data) => bytes.addAll(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<Uint8List> stream) =>
      stream.forEach(bytes.addAll);
  @override
  Future<void> close() async {
    final handler = onClose;
    if (handler != null) await handler();
  }

  @override
  Future<void> get done => Future<void>.value();
}

/// FIXTURE SHAPE (test-only; `lib` is never edited to work around it).
///
/// A native completed exec closes **both** streams, so this fake closes stderr
/// as soon as the caller has attached its listener ([stderrErrorOnListen] is
/// emitted first, then the stream is closed). The legacy stdout shape is
/// unchanged: it preloads **and closes** stdout at construction, which every
/// existing success/routing/secret/limit proof relies on. The failure cases
/// still opt out individually through [preloadStdout] /
/// [completeDoneOnCreate] / [onStdinClose] / [stderrErrorOnListen].
class _Session implements SSHSession {
  _Session({
    this.stdoutText = '200',
    this.exitCode = 0,
    this.preloadStdout = true,
    this.completeDoneOnCreate = true,
    this.stderrErrorOnListen,
    Future<void> Function()? onStdinClose,
  }) {
    _sink = _RecordingSink(onClose: onStdinClose);
    if (preloadStdout) {
      _stdout.add(utf8.encode(stdoutText));
      unawaited(_stdout.close());
    }
    if (completeDoneOnCreate && !_done.isCompleted) _done.complete();
  }

  final String stdoutText;
  @override
  final int? exitCode;
  final bool preloadStdout;
  final bool completeDoneOnCreate;

  /// When set, a stderr error is delivered right after the caller subscribes.
  final Object? stderrErrorOnListen;

  final _stdout = StreamController<Uint8List>();
  final _stderr = StreamController<Uint8List>.broadcast();
  late final _RecordingSink _sink;
  final _done = Completer<void>();
  bool _stderrHookArmed = false;
  bool closed = false;

  /// Adds an error to stdout. Single-subscription controllers buffer it until
  /// the delivery attaches its reader, which is exactly the ordering under
  /// test for "stdout error while `stdin.close` is still pending".
  void emitStdoutError(Object error) {
    if (!_stdout.isClosed) _stdout.addError(error);
  }

  /// Completes stdout normally for a fixture that left it open.
  void finishStdout([String text = '200']) {
    if (!_stdout.isClosed) {
      _stdout.add(utf8.encode(text));
      unawaited(_stdout.close());
    }
  }

  /// Rejects `done` while stdout is still pending.
  void rejectDone(Object error) {
    if (!_done.isCompleted) _done.completeError(error);
  }

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr {
    final source = _stderr.stream;
    if (!_stderrHookArmed) {
      _stderrHookArmed = true;
      final pending = stderrErrorOnListen;
      // Runs only after `session.stderr.listen(...)` has attached (the getter
      // is evaluated before `.listen` subscribes), which is the ordering the
      // contract asks about. A native completed exec closes stderr once its
      // output is drained, so the fake closes it too — emitting the injected
      // error first when one was requested.
      scheduleMicrotask(() {
        if (!_stderr.isClosed && pending != null) _stderr.addError(pending);
        if (!_stderr.isClosed) unawaited(_stderr.close());
      });
    }
    return source;
  }

  @override
  StreamSink<Uint8List> get stdin => _sink;
  _RecordingSink get sink => _sink;
  @override
  Future<void> get done => _done.future;

  @override
  void close() {
    closed = true;
    if (!_stdout.isClosed) _stdout.close();
    if (!_stderr.isClosed) _stderr.close();
    if (!_done.isCompleted) _done.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements SSHClient {
  _Client(this.session);
  final _Session session;
  final List<String> commands = [];

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    commands.add(command);
    return session;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AgentProfile _profile({String target = 'host', String? reference}) =>
    AgentProfile(
      id: 'a',
      serverId: 's',
      name: 'A',
      description: '',
      cliCommand: 'codex',
      acpCommand: 'codex-acp --stdio',
      executionTarget: target,
      containerBinding: 'id',
      containerReference: reference,
    );

AcpOAuthRequest _request() {
  final request = AcpOAuthRequest.fromLine(_challenge);
  expect(request, isNotNull, reason: 'fixture challenge must be accepted');
  return request!;
}

final _deliveryFailed = throwsA(
  isA<StateError>().having(
    (error) => error.message,
    'message',
    'ACP_AUTH_CALLBACK_DELIVERY_FAILED',
  ),
);

class _Outcome {
  _Outcome(this.thrown, this.uncaught);

  /// The error the delivery handed to its caller, or null when it resolved.
  final Object? thrown;

  /// Every error nobody observed, reported to the guarded zone.
  final List<String> uncaught;
}

/// Runs [body] in a guarded zone so an error nobody observes is *captured*
/// instead of being swallowed silently or blowing up the test framework from
/// outside. Both contract requirements are collected into one list so a red
/// run prints the caller failure *and* the uncaught error together.
///
/// The outcome is carried out of the zone by an outer [Completer] completed
/// from *inside* the guarded body: awaiting a future that was created in the
/// error zone from outside that zone cannot observe its failure.
Future<_Outcome> _guarded(Future<void> Function() body) async {
  final uncaught = <String>[];
  final completer = Completer<_Outcome>();
  Object? thrown;
  runZonedGuarded<Future<void>>(
    () async {
      try {
        await body();
      } catch (error) {
        thrown = error;
      }
      await Future<void>.microtask(() {});
      await Future<void>.microtask(() {});
      if (!completer.isCompleted) {
        completer.complete(_Outcome(thrown, uncaught));
      }
    },
    (Object error, StackTrace stack) {
      uncaught.add('$error\n$stack');
    },
  );
  try {
    return await completer.future.timeout(const Duration(seconds: 2));
  } on TimeoutException {
    return _Outcome(
      thrown,
      uncaught..add('TIMEOUT: guarded body did not finish within 2s'),
    );
  }
}

/// Asserts both halves of the contract: the caller saw [expected] *and*
/// nothing escaped into the zone unobserved.
void _expectStrictFailure(_Outcome outcome, Object expected, String what) {
  final problems = <String>[];
  if (!identical(outcome.thrown, expected)) {
    problems.add(
      '$what: caller error was ${outcome.thrown.runtimeType} '
      '("${outcome.thrown}") but expected the identical injected error '
      '"$expected"',
    );
  }
  for (final entry in outcome.uncaught) {
    problems.add('$what: uncaught zone error:\n$entry');
  }
  expect(problems, isEmpty, reason: problems.join('\n---\n'));
}

void main() {
  test(
    'routes the delivery through the host target and closes the session',
    () async {
      final session = _Session();
      final client = _Client(session);

      await deliverAcpOAuthCallback(client, _profile(), _request(), _callback);

      expect(client.commands, hasLength(1));
      expect(client.commands.single, startsWith('curl -q --silent'));
      expect(client.commands.single, contains('--noproxy'));
      expect(session.sink.text, contains('url = "$_callback"'));
      expect(session.closed, isTrue, reason: 'the channel must not leak');
    },
  );

  test('routes the delivery through docker for a container target', () async {
    final session = _Session();
    final client = _Client(session);

    await deliverAcpOAuthCallback(
      client,
      _profile(target: 'docker', reference: 'web.api'),
      _request(),
      _callback,
    );

    expect(client.commands, hasLength(1));
    expect(
      client.commands.single,
      contains("docker exec -i 'web.api' /bin/sh -lc"),
    );
    expect(session.closed, isTrue);
  });

  test('keeps the authorization code off the command line', () async {
    final session = _Session();
    final client = _Client(session);

    await deliverAcpOAuthCallback(client, _profile(), _request(), _callback);

    final command = client.commands.single;
    expect(command, isNot(contains(_secretCode)));
    expect(command, isNot(contains('code=')));
    expect(command, isNot(contains('state-1')));
    expect(command, isNot(contains('127.0.0.1')));
    expect(
      session.sink.text,
      contains(_secretCode),
      reason: 'the code must travel on stdin only',
    );
  });

  test('rejects an invalid callback before opening any SSH channel', () async {
    final session = _Session();
    final client = _Client(session);

    await expectLater(
      deliverAcpOAuthCallback(
        client,
        _profile(),
        _request(),
        'http://127.0.0.1:8765/cb?code=x&state=wrong-attempt',
      ),
      throwsA(isA<FormatException>()),
    );

    expect(client.commands, isEmpty);
    expect(session.closed, isFalse);
  });

  test('fails and closes the session when curl exits non-zero', () async {
    final session = _Session(exitCode: 7);
    final client = _Client(session);

    await expectLater(
      deliverAcpOAuthCallback(client, _profile(), _request(), _callback),
      _deliveryFailed,
    );
    expect(session.closed, isTrue);
  });

  test('fails when curl does not report a 2xx/3xx status', () async {
    for (final output in ['500', '0', 'not-a-number']) {
      final session = _Session(stdoutText: output);
      final client = _Client(session);

      await expectLater(
        deliverAcpOAuthCallback(client, _profile(), _request(), _callback),
        _deliveryFailed,
        reason: 'curl reported $output',
      );
      expect(session.closed, isTrue, reason: 'curl reported $output');
    }
  });

  test('fails when the delivery output grows past the 4096 byte cap', () async {
    final session = _Session(stdoutText: '9' * 5000);
    final client = _Client(session);

    await expectLater(
      deliverAcpOAuthCallback(client, _profile(), _request(), _callback),
      _deliveryFailed,
    );
    expect(session.closed, isTrue);
  });

  group('unobserved failure modes', () {
    test('(a) stderr-only error with stdout 200 and a normal done', () async {
      final stderrError = StateError('STDERR_ONLY_FAILURE');
      late final _Session session;
      session = _Session(stderrErrorOnListen: stderrError);
      final client = _Client(session);

      final outcome = await _guarded(
        () =>
            deliverAcpOAuthCallback(client, _profile(), _request(), _callback),
      );

      expect(client.commands, hasLength(1), reason: 'curl still ran');
      expect(session.sink.text, contains(_secretCode));
      expect(session.closed, isTrue, reason: 'the channel must not leak');
      _expectStrictFailure(
        outcome,
        stderrError,
        'stderr-only error (stdout=200, done normal)',
      );
    });

    test('(b) stdout error while stdin.close is still pending', () async {
      final stdoutError = StateError('STDOUT_ERROR_DURING_STDIN_CLOSE');
      late final _Session session;
      session = _Session(
        preloadStdout: false,
        onStdinClose: () async => session.emitStdoutError(stdoutError),
      );
      final client = _Client(session);

      final outcome = await _guarded(
        () =>
            deliverAcpOAuthCallback(client, _profile(), _request(), _callback),
      );

      expect(session.closed, isTrue, reason: 'the channel must not leak');
      _expectStrictFailure(
        outcome,
        stdoutError,
        'stdout error during delayed stdin.close',
      );
    });

    test('(c) stdin.close itself fails', () async {
      final stdinError = StateError('STDIN_CLOSE_FAILED');
      final session = _Session(onStdinClose: () async => throw stdinError);
      final client = _Client(session);

      final outcome = await _guarded(
        () =>
            deliverAcpOAuthCallback(client, _profile(), _request(), _callback),
      );

      expect(session.closed, isTrue, reason: 'the channel must not leak');
      _expectStrictFailure(outcome, stdinError, 'failing stdin.close');
    });

    test('(d) done rejects before stdout completes', () async {
      final doneError = StateError('DONE_REJECTED_EARLY');
      _Session? used;

      // Observation on the delivery is attached immediately: the rejection and
      // the stdout completion are scheduled, then the caller future is awaited
      // straight away so the harness itself can never manufacture an
      // unobserved error by holding the future unlistened across a delay.
      // The session is built *inside* the guarded zone so that a rejection
      // nobody has observed yet is reported to this zone's error handler (and
      // therefore to the strict assertion) instead of escaping to the runner.
      final outcome = await _guarded(() async {
        final session = _Session(
          preloadStdout: false,
          completeDoneOnCreate: false,
        );
        used = session;
        final client = _Client(session);
        scheduleMicrotask(() => session.rejectDone(doneError));
        scheduleMicrotask(() => session.finishStdout('200'));
        await deliverAcpOAuthCallback(
          client,
          _profile(),
          _request(),
          _callback,
        );
      });

      expect(used, isNotNull, reason: 'the fixture must have been created');
      expect(used!.closed, isTrue, reason: 'the channel must not leak');
      _expectStrictFailure(
        outcome,
        doneError,
        'done rejection before stdout completes',
      );
    });
  });
}
