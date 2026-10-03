import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/utils/shell_quote.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/cli/agent_execution_target.dart';
import 'package:valhalla/infrastructure/cli/agy_model_catalog.dart';

/// Independent `agy models` discovery. Read-only: no ACP session, no prompt.
/// These checks pin the parser contract and the query's failure modes.
void main() {
  AgentProfile buildProfile({
    String cliCommand = 'agy',
    String executionTarget = 'host',
    String? containerReference,
  }) => AgentProfile(
    id: 'a1',
    serverId: 's1',
    name: 'AgY',
    description: '',
    cliCommand: cliCommand,
    executionTarget: executionTarget,
    containerBinding: 'name',
    containerReference: containerReference,
    acpCommand: 'agy-acp --stdio',
  );

  group('AgyModelCatalog.parse', () {
    test('keeps only gemini ids and preserves the full reasoning label', () {
      final models = AgyModelCatalog.parse('''
gemini-3.8-pro  Gemini 3.8 Pro
gpt-5-codex     GPT-5 Codex
claude-sonnet   Claude Sonnet
gemini-2.5-flash  Gemini 2.5 Flash
''');

      expect(models.map((m) => m.id).toList(), [
        'gemini-3.8-pro',
        'gemini-2.5-flash',
      ]);
      expect(models.first.label, 'Gemini 3.8 Pro');
      expect(models.last.label, 'Gemini 2.5 Flash');
    });

    test('strips ANSI colour codes before matching', () {
      final models = AgyModelCatalog.parse(
        '\x1b[32mgemini-3.8-pro\x1b[0m  \x1b[1mGemini 3.8 Pro\x1b[0m\n',
      );

      expect(models, hasLength(1));
      expect(models.single.id, 'gemini-3.8-pro');
      expect(models.single.label, 'Gemini 3.8 Pro');
      expect(models.single.label, isNot(contains('\x1b')));
    });

    test('keeps a dotted/underscored id and its suffix intact', () {
      final models = AgyModelCatalog.parse(
        'gemini-3.8-pro-thinking-high  Gemini 3.8 Pro (high)\n',
      );

      expect(models.single.id, 'gemini-3.8-pro-thinking-high');
      expect(models.single.label, 'Gemini 3.8 Pro (high)');
    });

    test('later duplicate ids replace the label but keep first-seen order', () {
      final models = AgyModelCatalog.parse('''
gemini-3.8-pro  First label
gemini-2.5-flash  Flash
gemini-3.8-pro  Second label
''');

      expect(models.map((m) => m.id).toList(), [
        'gemini-3.8-pro',
        'gemini-2.5-flash',
      ]);
      expect(models.first.label, 'Second label');
    });

    test('ignores headers, blanks and vendor lines that do not match', () {
      final models = AgyModelCatalog.parse('''
Available models:
                        
* gemini-not-a-match  no id column
gemini-3.8-pro  Gemini 3.8 Pro
  gemini-2.5-flash  Gemini 2.5 Flash
''');

      expect(models.map((m) => m.id).toList(), [
        'gemini-3.8-pro',
        'gemini-2.5-flash',
      ]);
    });

    test('a catalog with no gemini model fails explicitly', () {
      expect(
        () => AgyModelCatalog.parse('gpt-5-codex  GPT\n'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'AGENT_MODEL_CATALOG_EMPTY',
          ),
        ),
      );
    });

    test('an empty or whitespace-only output also fails explicitly', () {
      expect(
        () => AgyModelCatalog.parse('   \n\n'),
        throwsA(isA<StateError>()),
      );
      expect(() => AgyModelCatalog.parse(''), throwsA(isA<StateError>()));
    });
  });

  group('AgyModelCatalog.query', () {
    _StubSession stubSession({
      String stdoutText = '',
      int exitCode = 0,
      bool closeStderr = true,
    }) => _StubSession(stdoutText, exitCode, closeStderr);

    test(
      'host target runs the CLI through a login shell and parses stdout',
      () async {
        final session = stubSession(
          stdoutText: 'gemini-3.8-pro  Gemini 3.8 Pro\n',
        );
        final client = _StubClient(session);

        final capabilities = await AgyModelCatalog.query(
          client,
          buildProfile(),
        );

        expect(client.commands, hasLength(1), reason: 'one independent query');
        // Exact nested quoting: the CLI is one login-shell word, the subcommand
        // is appended after it, and the whole thing is wrapped once more.
        expect(
          cliShellQuote("'agy' models"),
          r"''\''agy'\'' models'",
          reason: 'pin the quoter itself so this test is not a tautology',
        );
        expect(
          client.commands.single,
          "bash -l -c ${cliShellQuote("'agy' models")}",
        );
        expect(
          client.commands.single,
          r"bash -l -c ''\''agy'\'' models'",
          reason: 'and the fully literal expected command line',
        );
        expect(capabilities.models.map((m) => m.id), ['gemini-3.8-pro']);
        expect(capabilities.supportsStructuredSettings, isTrue);
        expect(session.closed, isTrue, reason: 'the channel must not leak');
      },
    );

    test(
      'docker target routes the same read-only command through docker exec',
      () async {
        final session = stubSession(
          stdoutText: 'gemini-3.8-pro  Gemini 3.8 Pro\n',
        );
        final client = _StubClient(session);
        final profile = buildProfile(
          executionTarget: 'docker',
          containerReference: 'web.api',
        );

        await AgyModelCatalog.query(client, profile);

        expect(
          client.commands.single,
          agentTargetCommand(profile, "${cliShellQuote('agy')} models"),
          reason: 'same quoted payload, routed by execution target',
        );
        expect(
          client.commands.single,
          startsWith("docker exec -i 'web.api' "),
          reason: 'the container already has the runtime, no login shell',
        );
        expect(session.closed, isTrue);
      },
    );

    test(
      'a non-zero exit fails explicitly instead of trusting partial stdout',
      () async {
        final session = stubSession(
          stdoutText: 'gemini-3.8-pro  Gemini 3.8 Pro\n',
          exitCode: 7,
        );
        final client = _StubClient(session);

        await expectLater(
          AgyModelCatalog.query(client, buildProfile()),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'AGENT_MODEL_QUERY_FAILED',
            ),
          ),
        );
        expect(session.closed, isTrue, reason: 'the channel must not leak');
      },
    );

    test(
      'a successful exit with no gemini model fails as an empty catalog',
      () async {
        final session = stubSession(stdoutText: 'no models here\n');
        final client = _StubClient(session);

        await expectLater(
          AgyModelCatalog.query(client, buildProfile()),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'AGENT_MODEL_CATALOG_EMPTY',
            ),
          ),
        );
        expect(session.closed, isTrue);
      },
    );

    test(
      'an oversized catalog is rejected instead of being buffered',
      () async {
        final session = stubSession(stdoutText: 'x' * (256 * 1024 + 64));
        final client = _StubClient(session);

        await expectLater(
          AgyModelCatalog.query(client, buildProfile()),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'AGENT_MODEL_CATALOG_TOO_LARGE',
            ),
          ),
        );
        expect(session.closed, isTrue);
      },
    );

    test('stderr is drained so a chatty CLI cannot fail the query', () async {
      final session = stubSession(
        stdoutText: 'gemini-3.8-pro  Gemini 3.8 Pro\n',
        closeStderr: false,
      );
      session.emitStderrLine('warning: experimental\n');
      session.finishStderr();
      final client = _StubClient(session);

      final capabilities = await AgyModelCatalog.query(client, buildProfile());

      expect(capabilities.models.single.id, 'gemini-3.8-pro');
      expect(session.closed, isTrue);
    });

    test('the CLI command is never interpolated into a shell', () async {
      final session = stubSession(
        stdoutText: 'gemini-3.8-pro  Gemini 3.8 Pro\n',
      );
      final client = _StubClient(session);

      await AgyModelCatalog.query(client, buildProfile(cliCommand: 'agy beta'));

      final command = client.commands.single;
      expect(
        cliShellQuote("'agy beta' models"),
        r"''\''agy beta'\'' models'",
        reason: 'pin the quoter itself so this test is not a tautology',
      );
      expect(command, "bash -l -c ${cliShellQuote("'agy beta' models")}");
      expect(
        command,
        r"bash -l -c ''\''agy beta'\'' models'",
        reason: 'and the fully literal expected command line',
      );
    });

    test('shell metacharacters stay inside the single quoted word', () async {
      final session = stubSession(
        stdoutText: 'gemini-3.8-pro  Gemini 3.8 Pro\n',
      );
      final client = _StubClient(session);

      await AgyModelCatalog.query(
        client,
        buildProfile(cliCommand: 'agy; rm -rf /'),
      );

      expect(cliShellQuote('agy; rm -rf /'), "'agy; rm -rf /'");
      expect(
        client.commands.single,
        r"bash -l -c ''\''agy; rm -rf /'\'' models'",
        reason: 'the separator never reaches the shell unquoted',
      );
      expect(
        client.commands.single,
        "bash -l -c ${cliShellQuote("'agy; rm -rf /' models")}",
      );
    });
  });
}

/// Session stub: stdout preloaded and closed, optional stderr control,
/// `done` already completed — the shape of a finished CLI invocation.
class _StubSession implements SSHSession {
  _StubSession(String stdoutText, this.exitCode, bool closeStderr) {
    _stdout.add(utf8.encode(stdoutText));
    unawaited(_stdout.close());
    if (closeStderr) unawaited(_stderr.close());
  }

  final _stdout = StreamController<Uint8List>();
  final _stderr = StreamController<Uint8List>();
  final _sink = _RecordingSink();
  bool closed = false;

  @override
  final int? exitCode;

  void emitStderrLine(String line) => _stderr.add(utf8.encode(line));
  void finishStderr() => unawaited(_stderr.close());

  @override
  Stream<Uint8List> get stdout => _stdout.stream;
  @override
  Stream<Uint8List> get stderr => _stderr.stream;
  @override
  StreamSink<Uint8List> get stdin => _sink;
  @override
  Future<void> get done => Future<void>.value();

  @override
  void close() {
    closed = true;
    if (!_stdout.isClosed) _stdout.close();
    if (!_stderr.isClosed) _stderr.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingSink implements StreamSink<Uint8List> {
  final List<int> bytes = [];

  @override
  void add(Uint8List data) => bytes.addAll(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<Uint8List> stream) =>
      stream.forEach(bytes.addAll);
  @override
  Future<void> close() => Future<void>.value();
  @override
  Future<void> get done => Future<void>.value();
}

class _StubClient implements SSHClient {
  _StubClient(this.session);
  final SSHSession session;
  final List<String> commands = [];

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) {
    commands.add(command);
    return Future<SSHSession>.value(session);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
