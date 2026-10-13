import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/services/nas_native_install_service.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

const _server = ServerProfile(
  id: 'ssh-one',
  name: 'Isolated fake server',
  host: 'fixture.invalid',
  username: 'fixture',
);
const _targetIdentity = '0123456789abcdef0123456789abcdef';
const _taskId = 'abcdef0123456789abcdef0123456789';

class _Client extends Fake implements SSHClient {}

class _Invocation {
  final List<String> argv;
  final Map<String, dynamic> payload;

  _Invocation(this.argv)
    : payload = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(base64Decode(argv[4]))) as Map,
      );

  String get mode => argv[3];
  String get loader => argv[2];
}

/// Decode the actual shell quoting without executing any remote helper code.
/// Only the generated `set --` prefix and a shell-builtin printf may run.
Future<_Invocation> _decodeInvocation(String command) async {
  const boundary = '; if ! test -x /usr/bin/python3;';
  final end = command.indexOf(boundary);
  if (!command.startsWith('set -- /usr/bin/python3 -c ') || end < 0) {
    throw StateError('Unexpected native command wrapper');
  }
  final result = await Process.run('/bin/sh', [
    '-c',
    '${command.substring(0, end)}; printf \'%s\\0\' "\$@"',
  ]);
  expect(result.exitCode, 0, reason: result.stderr as String);
  final argv = (result.stdout as String).split('\u0000')..removeLast();
  expect(argv, hasLength(5));
  expect(argv.take(2), ['/usr/bin/python3', '-c']);
  expect(argv[3], isIn(['prepare', 'launch', 'read', 'cancel']));
  return _Invocation(argv);
}

class _Executor extends Fake implements SshCommandExecutor {
  SSHClient client = _Client();
  final commands = <String>[];
  final invocations = <_Invocation>[];
  final events = <String>[];
  Map<String, dynamic> readResponse = {
    'stage': 'succeeded',
    'updatedAt': DateTime.now().toIso8601String(),
    'requiresReconciliation': false,
  };

  List<String> get modes => invocations.map((call) => call.mode).toList();

  @override
  bool isConnected(String serverId) => serverId == _server.id;

  @override
  SSHClient? getClient(String serverId) =>
      serverId == _server.id ? client : null;

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    expect(serverId, _server.id);
    expect(sudoPassword, isNull);
    commands.add(command);
    final invocation = await _decodeInvocation(command);
    invocations.add(invocation);
    events.add(invocation.mode);
    final response = switch (invocation.mode) {
      'prepare' => <String, dynamic>{
        'packageVersions': {
          'jellyfin': '10.11.0',
          'jellyfin-server': '10.11.0',
          'jellyfin-web': '10.11.0',
        },
        'targetIdentity': _targetIdentity,
        'os': 'debian',
        'osVersion': '12',
        'architecture': 'amd64',
        'blockers': <String>[],
        'existingInstall': false,
      },
      'launch' => <String, dynamic>{'accepted': true},
      'read' => readResponse,
      _ => throw StateError('Unexpected mutation: ${invocation.mode}'),
    };
    return SSHExecutionResult(
      exitCode: response.containsKey('error') ? 1 : 0,
      stdout: 'VALHALLA_NATIVE:${jsonEncode(response)}\n',
      stderr: '',
    );
  }
}

Matcher _code(String code) => isA<NasNativeInstallException>().having(
  (error) => error.code,
  'code',
  code,
);

Map<String, dynamic> _recovered(NasNativeInstallRequest request) => {
  ...request.toJson(),
  'id': _taskId,
  'targetIdentity': _targetIdentity,
  'packageVersion': '10.11.0',
  'stage': 'installing',
  'startedAt': DateTime.utc(2026, 10, 1).toIso8601String(),
  'updatedAt': DateTime.utc(2026, 10, 1).toIso8601String(),
  'requiresReconciliation': true,
};

Future<Map<String, dynamic>> _isolatedPythonHealth(String listeners) async {
  // Compile only these actual production definitions. No module top-level,
  // installer, SSH, subprocess or package-manager operation can execute.
  const harness = r'''
import ast, base64, json, sys, types
source = base64.b64decode(sys.argv[1]).decode()
fixture = json.loads(sys.argv[2])
tree = ast.parse(source)
names = {'Failure', 'fail', 'verify_health'}
nodes = [node for node in tree.body
         if isinstance(node, (ast.FunctionDef, ast.ClassDef)) and node.name in names]
assert {node.name for node in nodes} == names
calls = []
def text(args, **kwargs):
    if args == ['systemctl', 'is-active', 'jellyfin.service']:
        return 'active'
    if args == ['systemctl', 'show', 'jellyfin.service', '--property=MainPID', '--value']:
        return '123'
    if args == ['ss', '-H', '-ltnp', 'sport = :8096']:
        return fixture['listeners']
    raise AssertionError('unexpected text command: ' + repr(args))
def run(args, **kwargs):
    assert args == ['curl', '--noproxy', '*', '--fail', '--silent', '--show-error',
                    '--max-time', '5', 'http://127.0.0.1:8096/health']
    calls.append(args)
    return types.SimpleNamespace(returncode=0)
scope = {'text': text, 'run': run}
exec(compile(ast.Module(body=nodes, type_ignores=[]), '<native-health>', 'exec'), scope)
try:
    value = scope['verify_health']()
    result = {'value': value, 'error': None}
except scope['Failure'] as error:
    result = {'value': None, 'error': str(error)}
result['curlCalls'] = len(calls)
print(json.dumps(result))
''';
  final result = await Process.run('/usr/bin/python3', [
    '-c',
    harness,
    base64Encode(utf8.encode(NasNativeInstallService.remoteScript)),
    jsonEncode({'listeners': listeners}),
  ]);
  expect(result.exitCode, 0, reason: result.stderr as String);
  return Map<String, dynamic>.from(jsonDecode(result.stdout as String) as Map);
}

void main() {
  late _Executor ssh;
  late NasNativeInstallRequest request;
  late String currentServerKey;

  setUp(() {
    ssh = _Executor();
    request = NasNativeInstallRequest.forServer(
      _server,
      mediaPath: "/media/Owner's photos",
    );
    currentServerKey = request.serverKey;
  });

  NasNativeInstallService service({
    Map<String, dynamic>? recovered,
    Future<void> Function(Map<String, dynamic>)? persist,
  }) {
    final value = NasNativeInstallService(
      ssh,
      currentServerKey: () => currentServerKey,
      recoveredTask: recovered,
      persistTask: persist,
    );
    addTearDown(value.dispose);
    return value;
  }

  test(
    'native health loop honors cancellation before health probing',
    () async {
      // Extract only the real bounded health loop, not the worker's mutations.
      const harness = r'''
import ast, base64, json, sys, types
tree = ast.parse(base64.b64decode(sys.argv[1]).decode())
worker = next(node for node in tree.body
              if isinstance(node, ast.FunctionDef) and node.name == 'worker')
loops = [node for node in ast.walk(worker) if isinstance(node, ast.For)
         and isinstance(node.iter, ast.Call)
         and isinstance(node.iter.func, ast.Name) and node.iter.func.id == 'range'
         and len(node.iter.args) == 1 and isinstance(node.iter.args[0], ast.Constant)
         and node.iter.args[0].value == 60]
assert len(loops) == 1
support = [node for node in tree.body
           if isinstance(node, (ast.FunctionDef, ast.ClassDef))
           and node.name in {'Failure', 'fail'}]
scope = {'healthy': False}
exec(compile(ast.Module(body=support, type_ignores=[]), '<health-support>', 'exec'), scope)
events = []
def cancelled():
    events.append('cancelled')
    scope['fail']('CANCELLED')
def verify_health():
    events.append('verify_health')
    return True
def sleep(_):
    raise AssertionError('a cancelled probe must never wait')
scope.update(cancelled=cancelled, verify_health=verify_health,
             time=types.SimpleNamespace(sleep=sleep))
error = None
try:
    exec(compile(ast.Module(body=loops, type_ignores=[]), '<health-loop>', 'exec'), scope)
except scope['Failure'] as failure:
    error = str(failure)
print(json.dumps({'events': events, 'error': error, 'healthy': scope['healthy']}))
''';
      final result = await Process.run('/usr/bin/python3', [
        '-c',
        harness,
        base64Encode(utf8.encode(NasNativeInstallService.remoteScript)),
      ]);
      expect(result.exitCode, 0, reason: result.stderr as String);
      final state = jsonDecode(result.stdout as String) as Map;
      expect(state['error'], 'NAS_NATIVE_CANCELLED');
      expect(state['events'], ['cancelled']);
      expect(state['healthy'], isFalse);
    },
  );

  const ownListener =
      'LISTEN 0 512 127.0.0.1:8096 0.0.0.0:* users:(("jellyfin",pid=123,fd=9))';
  const wildcardListener =
      'LISTEN 0 512 0.0.0.0:8096 0.0.0.0:* users:(("jellyfin",pid=123,fd=9))';
  const foreignListener =
      'LISTEN 0 512 127.0.0.1:8096 0.0.0.0:* users:(("other",pid=124,fd=9))';
  for (final fixture in <({String name, String listeners, bool? healthy})>[
    (name: 'not listening yet is retryable', listeners: '', healthy: false),
    (name: 'owned loopback is healthy', listeners: ownListener, healthy: true),
    (
      name: 'wildcard bind fails closed',
      listeners: wildcardListener,
      healthy: null,
    ),
    (
      name: 'foreign PID fails closed',
      listeners: foreignListener,
      healthy: null,
    ),
    (
      name: 'mixed safe and unsafe listeners fail closed',
      listeners: '$ownListener\n$wildcardListener',
      healthy: null,
    ),
  ]) {
    test('native Python health: ${fixture.name}', () async {
      final result = await _isolatedPythonHealth(fixture.listeners);
      if (fixture.healthy == null) {
        expect(result['error'], 'NAS_NATIVE_LISTENER_UNSAFE');
        expect(result['value'], isNull);
        expect(result['curlCalls'], 0);
      } else {
        expect(result['error'], isNull);
        expect(result['value'], fixture.healthy);
        expect(result['curlCalls'], fixture.healthy! ? 1 : 0);
      }
    });
  }

  test(
    'prepare transports exact multiline script and quoted payload safely',
    () async {
      final native = service();
      final plan = await native.prepare(request);

      expect(ssh.modes, ['prepare']);
      expect(plan.canInstall, isTrue);
      final invocation = ssh.invocations.single;
      expect(invocation.loader, isNot(contains('\n')));
      expect(invocation.payload, {...request.toJson(), 'id': plan.id});

      // Intercept compile so loader execution can never run the remote script.
      // Its actual decoded bytes, filename and mode are the only output.
      const inspectLoader = r'''
import base64, builtins, json, sys
observed = []
real_compile = builtins.compile
def capture(source, filename, mode, *args, **kwargs):
    if not isinstance(source, bytes):
        raise AssertionError('loader must decode bytes')
    observed.append({'source': base64.b64encode(source).decode(),
                     'filename': filename, 'mode': mode})
    return real_compile('pass', filename, mode)
builtins.compile = capture
exec(sys.argv[1], {'__builtins__': builtins.__dict__})
assert len(observed) == 1
print(json.dumps(observed[0]))
''';
      final inspected = await Process.run('/usr/bin/python3', [
        '-c',
        inspectLoader,
        invocation.loader,
      ]);
      expect(inspected.exitCode, 0, reason: inspected.stderr as String);
      final decoded = jsonDecode(inspected.stdout as String) as Map;
      expect(
        utf8.decode(base64Decode(decoded['source'] as String)),
        NasNativeInstallService.remoteScript,
      );
      expect(decoded['filename'], '<valhalla-native>');
      expect(decoded['mode'], 'exec');
    },
  );

  for (final missingCallback in [false, true]) {
    test(
      'durable persistence ${missingCallback ? 'missing' : 'failure'} prevents launch',
      () async {
        final native = service(
          persist: missingCallback
              ? null
              : (_) async => throw StateError('fixture persistence failed'),
        );
        final plan = await native.prepare(request);
        await expectLater(
          native.execute(plan.confirmationToken),
          throwsA(_code('NAS_NATIVE_PERSIST_FAILED')),
        );
        expect(ssh.modes, ['prepare']);
        expect(native.state!.stage, NasNativeInstallStage.failed);
        expect(native.state!.requiresReconciliation, isFalse);
      },
    );
  }

  test(
    'restore and missing remote task reconcile only read, never replay',
    () async {
      ssh.readResponse = {'error': 'NAS_NATIVE_REMOTE_FAILED'};
      final native = service(recovered: _recovered(request));
      expect(ssh.commands, isEmpty);
      expect(native.state!.stage, NasNativeInstallStage.needsInspection);
      expect(native.state!.requiresReconciliation, isTrue);

      await native.reconcile();
      await native.reconcile();
      expect(ssh.modes, ['read', 'read']);
      expect(native.state!.stage, NasNativeInstallStage.needsInspection);
      expect(native.state!.errorCode, 'NAS_NATIVE_REMOTE_FAILED');
      expect(native.state!.requiresReconciliation, isTrue);
      await expectLater(
        native.prepare(request),
        throwsA(_code('NAS_NATIVE_TASK_PENDING')),
      );
      expect(ssh.modes, ['read', 'read']);
    },
  );

  test(
    'restore can observe completed task without launching installation',
    () async {
      final native = service(recovered: _recovered(request));
      expect(ssh.commands, isEmpty);
      await native.reconcile();
      expect(ssh.modes, ['read']);
      expect(native.state!.stage, NasNativeInstallStage.succeeded);
      expect(native.state!.requiresReconciliation, isFalse);
      expect(native.state!.result!.healthy, isTrue);
    },
  );

  test(
    'confirmation launches once, persists first, and preserves worker argv',
    () async {
      final native = service(persist: (_) async => ssh.events.add('persist'));
      final plan = await native.prepare(request);
      await native.execute(plan.confirmationToken);
      expect(ssh.modes, ['prepare', 'launch', 'read']);
      expect(ssh.events.take(3), ['prepare', 'persist', 'launch']);
      expect(native.state!.stage, NasNativeInstallStage.succeeded);
      final launch = ssh.invocations[1];
      expect(
        launch.payload['_workerCode'],
        NasNativeInstallService.remoteScript,
      );
      expect(launch.payload['id'], plan.id);
      expect(launch.payload['mediaPath'], request.mediaPath);
      expect(launch.payload['serverKey'], request.serverKey);
      expect(launch.payload['targetIdentity'], _targetIdentity);
      // The complete generated shell command must not duplicate script/payload
      // enough to exceed Linux's per-argument limit for SSH's shell -c argument.
      final shellCommand =
          "bash -l -c '${ssh.commands[1].replaceAll("'", "'\\''")}'";
      expect(utf8.encode(shellCommand).length, lessThan(128 * 1024));
      await expectLater(
        native.execute(plan.confirmationToken),
        throwsA(_code('NAS_NATIVE_CONFIRMATION_INVALID')),
      );
      expect(ssh.modes, ['prepare', 'launch', 'read']);
    },
  );

  test(
    'wrong confirmation consumes approval without any remote mutation',
    () async {
      final native = service(persist: (_) async {});
      final plan = await native.prepare(request);
      await expectLater(
        native.execute('not-the-confirmed-token'),
        throwsA(_code('NAS_NATIVE_CONFIRMATION_INVALID')),
      );
      await expectLater(
        native.execute(plan.confirmationToken),
        throwsA(_code('NAS_NATIVE_CONFIRMATION_INVALID')),
      );
      expect(ssh.modes, ['prepare']);
    },
  );

  for (final changeClient in [true, false]) {
    test(
      'changed ${changeClient ? 'SSH instance' : 'connection key'} invalidates approval',
      () async {
        var persistenceCount = 0;
        final native = service(persist: (_) async => persistenceCount++);
        final plan = await native.prepare(request);
        if (changeClient) {
          ssh.client = _Client();
        } else {
          currentServerKey = NasNativeInstallService.serverKey(
            _server.copyWith(host: 'other.fixture.invalid'),
          );
        }
        await expectLater(
          native.execute(plan.confirmationToken),
          throwsA(_code('NAS_NATIVE_TARGET_CHANGED')),
        );
        expect(persistenceCount, 0);
        expect(ssh.modes, ['prepare']);
      },
    );
  }

  test(
    'connection changed while persisting prevents launch after durable write',
    () async {
      final native = service(persist: (_) async => ssh.client = _Client());
      final plan = await native.prepare(request);
      await expectLater(
        native.execute(plan.confirmationToken),
        throwsA(_code('NAS_NATIVE_TARGET_CHANGED')),
      );
      expect(ssh.modes, ['prepare']);
      expect(native.state!.stage, NasNativeInstallStage.failed);
      expect(native.state!.errorCode, 'NAS_NATIVE_TARGET_CHANGED');
    },
  );
}
