import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_workspace.dart';
import 'package:valhalla/infrastructure/acp/acp_workspace_files.dart';

AgentProfile _dockerProfile() => AgentProfile(
  id: 'builtin-codex',
  serverId: 'srv-1',
  name: 'codex',
  description: 'test',
  cliCommand: 'cli',
  acpCommand: 'acp --stdio',
  executionTarget: 'docker',
  containerBinding: 'name',
  containerReference: 'valhalla-agent',
);

Matcher _stateError(String message) => throwsA(
  isA<StateError>().having((error) => error.message, 'message', message),
);

void main() {
  late _ScriptedClient client;
  late AcpWorkspaceFiles files;

  tearDown(() => files.close());

  void useClient(
    Future<_ScriptedResponse> Function(String command, Uint8List? input)
    handler,
  ) {
    client = _ScriptedClient(handler);
    files = AcpWorkspaceFiles(client, _dockerProfile());
  }

  group('AcpWorkspaceFiles text snapshots', () {
    test(
      'canSave=false falls back to read-only content when python is missing',
      () async {
        useClient((command, input) async {
          if (command.contains('python3')) {
            return _ScriptedResponse(
              exitCode: 1,
              stdout: utf8.encode('{"error": "ACP_FILE_EDITOR_UNAVAILABLE"}'),
            );
          }
          if (command.contains('head -c')) {
            return _ScriptedResponse(
              exitCode: 0,
              stdout: utf8.encode('fallback content'),
            );
          }
          return const _ScriptedResponse(exitCode: 0);
        });

        final snapshot = await files.readTextSnapshot('/workspace/readme.txt');

        expect(snapshot.path, '/workspace/readme.txt');
        expect(snapshot.targetPath, '/workspace/readme.txt');
        expect(snapshot.content, 'fallback content');
        expect(snapshot.revision, isEmpty);
        expect(snapshot.canSave, isFalse);
        expect(snapshot.owner, same(files));
        expect(snapshot.executionKey, chatExecutionKey(_dockerProfile()));
      },
    );

    test(
      'read-only snapshot rejects save without running an editor command',
      () async {
        useClient((command, input) async {
          if (command.contains('python3')) {
            return _ScriptedResponse(
              exitCode: 1,
              stdout: utf8.encode('{"error": "ACP_FILE_EDITOR_UNAVAILABLE"}'),
            );
          }
          return _ScriptedResponse(
            exitCode: 0,
            stdout: utf8.encode('fallback content'),
          );
        });
        final snapshot = await files.readTextSnapshot('/workspace/readme.txt');
        final commandCount = client.commands.length;

        await expectLater(
          files.saveTextSnapshot(snapshot, 'new content'),
          _stateError('ACP_FILE_EDITOR_UNAVAILABLE'),
        );

        expect(client.commands, hasLength(commandCount));
      },
    );

    test('editable snapshot saves through the editor endpoint', () async {
      useClient((command, input) async {
        final request = _request(input);
        if (request['operation'] == 'read') {
          return _ScriptedResponse(
            exitCode: 0,
            stdout: utf8.encode(
              jsonEncode({
                'path': request['path'],
                'targetPath': request['path'],
                'content': 'hello',
                'revision': 'rev-1',
              }),
            ),
          );
        }
        return _ScriptedResponse(
          exitCode: 0,
          stdout: utf8.encode('{"saved": true}'),
        );
      });
      final snapshot = await files.readTextSnapshot('/workspace/file.txt');
      expect(snapshot.canSave, isTrue);
      expect(snapshot.revision, 'rev-1');

      await files.saveTextSnapshot(snapshot, 'updated');

      expect(client.requests, hasLength(2));
      expect(client.requests.last['operation'], 'save');
      expect(client.requests.last['revision'], 'rev-1');
      expect(client.requests.last['content'], 'updated');
    });

    test('snapshot from another workspace owner is rejected', () async {
      useClient((command, input) async {
        final request = _request(input);
        if (request['operation'] == 'read') {
          return _ScriptedResponse(
            exitCode: 0,
            stdout: utf8.encode(
              jsonEncode({
                'path': request['path'],
                'targetPath': request['path'],
                'content': 'hello',
                'revision': 'rev-1',
              }),
            ),
          );
        }
        return const _ScriptedResponse(exitCode: 0, stdout: [123, 125]);
      });
      final snapshot = await files.readTextSnapshot('/workspace/file.txt');

      final otherClient = _ScriptedClient(
        (command, input) async => const _ScriptedResponse(exitCode: 0),
      );
      final other = AcpWorkspaceFiles(otherClient, _dockerProfile());
      addTearDown(other.close);

      await expectLater(
        other.saveTextSnapshot(snapshot, 'updated'),
        _stateError('ACP_TARGET_CHANGED'),
      );
      expect(otherClient.commands, isEmpty);
    });

    test(
      'snapshot execution key mismatch is rejected before writing',
      () async {
        useClient((command, input) async {
          final request = _request(input);
          if (request['operation'] == 'read') {
            return _ScriptedResponse(
              exitCode: 0,
              stdout: utf8.encode(
                jsonEncode({
                  'path': request['path'],
                  'targetPath': request['path'],
                  'content': 'hello',
                  'revision': 'rev-1',
                }),
              ),
            );
          }
          return const _ScriptedResponse(exitCode: 0);
        });
        final snapshot = await files.readTextSnapshot('/workspace/file.txt');
        final forged = AcpTextSnapshot(
          path: snapshot.path,
          targetPath: snapshot.targetPath,
          content: snapshot.content,
          revision: snapshot.revision,
          executionKey: 'different-execution',
          owner: snapshot.owner,
        );

        await expectLater(
          files.saveTextSnapshot(forged, 'updated'),
          _stateError('ACP_TARGET_CHANGED'),
        );
        expect(client.requests, hasLength(1));
      },
    );

    test('reconnection closes the old snapshot and the old client', () async {
      useClient((command, input) async {
        final request = _request(input);
        if (request['operation'] == 'read') {
          return _ScriptedResponse(
            exitCode: 0,
            stdout: utf8.encode(
              jsonEncode({
                'path': request['path'],
                'targetPath': request['path'],
                'content': 'hello',
                'revision': 'rev-1',
              }),
            ),
          );
        }
        return const _ScriptedResponse(exitCode: 0);
      });
      final snapshot = await files.readTextSnapshot('/workspace/file.txt');
      files.close();

      await expectLater(
        files.saveTextSnapshot(snapshot, 'updated'),
        _stateError('ACP_FILE_READ_CANCELLED'),
      );
      await expectLater(
        files.readTextSnapshot('/workspace/file.txt'),
        _stateError('ACP_FILE_READ_CANCELLED'),
      );

      final reconnected = AcpWorkspaceFiles(client, _dockerProfile());
      addTearDown(reconnected.close);
      await expectLater(
        reconnected.saveTextSnapshot(snapshot, 'updated'),
        _stateError('ACP_TARGET_CHANGED'),
      );
    });
  });
}

Map<String, dynamic> _request(Uint8List? input) => input == null
    ? const {}
    : jsonDecode(utf8.decode(input)) as Map<String, dynamic>;

class _ScriptedResponse {
  final int exitCode;
  final List<int> stdout;

  const _ScriptedResponse({required this.exitCode, this.stdout = const []});
}

class _ScriptedClient extends Fake implements SSHClient {
  _ScriptedClient(this.handler);

  final Future<_ScriptedResponse> Function(String command, Uint8List? input)
  handler;
  final List<String> commands = [];
  final List<Map<String, dynamic>> requests = [];
  int closes = 0;

  @override
  bool get isClosed => false;

  @override
  Future<void> close() async {
    closes++;
  }

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    commands.add(command);
    return _ScriptedSession(this, command);
  }

  Future<_ScriptedResponse> respond(String command, Uint8List? input) async {
    if (input != null) requests.add(_request(input));
    return handler(command, input);
  }
}

class _ScriptedSession extends Fake implements SSHSession {
  _ScriptedSession(this.client, this.command) {
    _input.stream.listen(_bytes.addAll, onDone: _respond);
    if (!command.contains('python3')) scheduleMicrotask(_respond);
  }

  final _ScriptedClient client;
  final String command;
  final _stdout = StreamController<Uint8List>();
  final _stderr = StreamController<Uint8List>();
  final _input = StreamController<Uint8List>();
  final _done = Completer<void>();
  final _bytes = <int>[];
  int? _exitCode;
  bool _responded = false;

  Future<void> _respond() async {
    if (_responded) return;
    _responded = true;
    final response = await client.respond(
      command,
      _bytes.isEmpty ? null : Uint8List.fromList(_bytes),
    );
    _exitCode = response.exitCode;
    if (response.stdout.isNotEmpty) {
      _stdout.add(Uint8List.fromList(response.stdout));
    }
    await _stdout.close();
    await _stderr.close();
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  StreamSink<Uint8List> get stdin => _input.sink;

  @override
  Future<void> get done => _done.future;

  @override
  int? get exitCode => _exitCode;

  @override
  void close() {
    if (_responded) return;
    _responded = true;
    unawaited(_stdout.close());
    unawaited(_stderr.close());
    if (!_done.isCompleted) _done.complete();
  }
}
