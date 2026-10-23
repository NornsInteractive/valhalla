import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/infrastructure/acp/acp_ssh_transport.dart';

class _Stdin implements StreamSink<Uint8List> {
  final controller = StreamController<Uint8List>.broadcast();
  final writes = <Uint8List>[];
  @override
  void add(Uint8List event) {
    writes.add(event);
    controller.add(event);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      controller.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<Uint8List> stream) =>
      controller.addStream(stream);

  @override
  Future<void> close() => controller.close();

  @override
  Future<void> get done => controller.done;
}

class _Session implements SSHSession {
  final _stdout = StreamController<Uint8List>.broadcast();
  final _stderr = StreamController<Uint8List>.broadcast();
  final _stdin = _Stdin();
  bool closed = false;
  int? exitCodeValue;

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  StreamSink<Uint8List> get stdin => _stdin;

  @override
  int? get exitCode => exitCodeValue;

  void emitStdout(String text) => _stdout.add(utf8.encode(text));

  @override
  void close() {
    closed = true;
    if (!_stdout.isClosed) _stdout.close();
    if (!_stderr.isClosed) _stderr.close();
    unawaited(_stdin.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AgentProfile _profile() => AgentProfile(
  id: 'builtin-codex',
  serverId: 'srv-1',
  name: 'codex',
  description: 'desc',
  cliCommand: 'codex',
  acpCommand: 'codex-acp',
);

void _autoReplyInit(_Session session) {
  session._stdin.controller.stream
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        try {
          final outer = jsonDecode(line) as Map<String, dynamic>;
          final inner = outer['frame'] as Map<String, dynamic>;
          final method = inner['method'] as String?;
          final id = inner['id'];
          if (method == 'initialize') {
            session.emitStdout(
              '${jsonEncode({
                'type': 'frame',
                'frame': {
                  'jsonrpc': '2.0',
                  'id': id,
                  'result': {'protocolVersion': 1, 'agentCapabilities': <String, dynamic>{}, 'authMethods': <dynamic>[]},
                },
              })}\n',
            );
          } else if (method == 'session/new') {
            session.emitStdout(
              '${jsonEncode({
                'type': 'frame',
                'frame': {
                  'jsonrpc': '2.0',
                  'id': id,
                  'result': {'sessionId': 'sess'},
                },
              })}\n',
            );
          } else if (method == 'session/cancel') {
            session.emitStdout(
              '${jsonEncode({
                'type': 'frame',
                'frame': {'jsonrpc': '2.0', 'id': id, 'result': <String, dynamic>{}},
              })}\n',
            );
          }
        } catch (_) {}
      });
}

void main() {
  late _Session session;
  setUp(() {
    session = _Session();
    _autoReplyInit(session);
  });
  tearDown(() {
    session.close();
  });

  test('initializes and prepares a persistent session', () async {
    final transport = AcpSshTransport(
      session,
      runtimeKey: 'rk',
      afterSequence: 0,
    );
    final adapter = ACPClientAdapter(
      profile: _profile(),
      transport: transport,
      workingDirectory: '/tmp',
    );
    final events = <ACPEvent>[];
    final sub = adapter.eventStream.listen(events.add);
    await adapter.initializeOnly();
    await pumpEventQueue();
    await adapter.prepareSession();
    await pumpEventQueue();
    expect(adapter.sessionId, 'sess');
    await sub.cancel();
    adapter.dispose();
    await transport.close();
  });

  test(
    'permission request is emitted and dispose suppresses response',
    () async {
      final transport = AcpSshTransport(
        session,
        runtimeKey: 'rk',
        afterSequence: 0,
      );
      final adapter = ACPClientAdapter(
        profile: _profile(),
        transport: transport,
        workingDirectory: '/tmp',
      );
      final events = <ACPEvent>[];
      final sub = adapter.eventStream.listen(events.add);
      await adapter.initializeOnly();
      await pumpEventQueue();
      await adapter.prepareSession();
      await pumpEventQueue();

      final received = Completer<void>();
      adapter.eventStream.listen((event) {
        if (event is ACPPermissionRequestEvent && !received.isCompleted) {
          received.complete();
        }
      });

      final envelope = jsonEncode({
        'type': 'frame',
        'turnId': 'turn-1',
        'seq': 1,
        'frame': {
          'jsonrpc': '2.0',
          'id': 'perm-1',
          'method': 'session/request_permission',
          'params': {
            'sessionId': 'sess',
            'toolCall': {
              'toolCallId': 'tool-1',
              'title': 'bash',
              'status': 'pending',
            },
            'options': [
              {'optionId': 'allow', 'name': 'Allow', 'kind': 'allow_once'},
            ],
          },
        },
      });
      session.emitStdout('$envelope\n');
      await received.future.timeout(const Duration(seconds: 2));
      await pumpEventQueue();

      final permission = events.whereType<ACPPermissionRequestEvent>().last;
      expect(permission.request.options.single.id, 'allow');
      expect(permission.request.options.single.name, 'Allow');
      expect(permission.request.options.single.kind, 'allow_once');

      adapter.dispose();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final joined = utf8.decode(
        session._stdin.writes.expand((e) => e).toList(),
      );
      expect(joined, isNot(contains('perm-1')));

      await sub.cancel();
      await transport.close();
    },
  );

  test('explicit cancelPrompt sends session/cancel', () async {
    final transport = AcpSshTransport(
      session,
      runtimeKey: 'rk',
      afterSequence: 0,
    );
    final adapter = ACPClientAdapter(
      profile: _profile(),
      transport: transport,
      workingDirectory: '/tmp',
    );
    await adapter.initializeOnly();
    await pumpEventQueue();
    await adapter.prepareSession();
    await pumpEventQueue();

    adapter.cancelPrompt();
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final joined = utf8.decode(session._stdin.writes.expand((e) => e).toList());
    expect(joined, contains('session/cancel'));

    adapter.dispose();
    await transport.close();
  });

  test('completed turn without live prompt emits complete', () async {
    final transport = AcpSshTransport(
      session,
      runtimeKey: 'rk',
      afterSequence: 0,
    );
    final adapter = ACPClientAdapter(
      profile: _profile(),
      transport: transport,
      workingDirectory: '/tmp',
    );
    final events = <ACPEvent>[];
    final sub = adapter.eventStream.listen(events.add);
    await adapter.initializeOnly();
    await pumpEventQueue();

    final envelope = jsonEncode({
      'type': 'turn',
      'state': 'completed',
      'turnId': 'turn-9',
      'seq': 4,
    });
    session.emitStdout('$envelope\n');
    await pumpEventQueue();
    await pumpEventQueue();

    expect(events.whereType<ACPCompleteEvent>(), isNotEmpty);

    await sub.cancel();
    adapter.dispose();
    await transport.close();
  });

  test('initial status completed produces status and caught_up events', () async {
    final transport = AcpSshTransport(
      session,
      runtimeKey: 'rk',
      afterSequence: 0,
    );
    final adapter = ACPClientAdapter(
      profile: _profile(),
      transport: transport,
      workingDirectory: '/tmp',
    );
    final events = <ACPEvent>[];
    final sub = adapter.eventStream.listen(events.add);
    await adapter.initializeOnly();
    await pumpEventQueue();

    session.emitStdout(
      '${jsonEncode({'type': 'status', 'state': 'completed', 'turnId': 'turn-1', 'seq': 1})}\n',
    );
    await pumpEventQueue();
    session.emitStdout(
      '${jsonEncode({'type': 'caught_up', 'state': 'completed', 'turnId': 'turn-1', 'seq': 1})}\n',
    );
    await pumpEventQueue();

    final statusEvents = events.whereType<ACPPersistentStatusEvent>().toList();
    expect(
      statusEvents.any((e) => e.status == 'completed' && !e.settled),
      isTrue,
    );
    expect(statusEvents.any((e) => e.caughtUp), isTrue);

    await sub.cancel();
    adapter.dispose();
    await transport.close();
  });
}
