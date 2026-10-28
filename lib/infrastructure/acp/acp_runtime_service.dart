import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart';

import '../../core/utils/shell_quote.dart';
import '../../data/models/agent_profile.dart';
import '../cli/agent_execution_target.dart';
import 'acp_ssh_transport.dart';

class AcpRuntimeStatus {
  final String runtimeKey;
  final String state;
  final bool alive;
  final bool childAlive;
  final int protocolVersion;
  final int workspaceProtocol;
  final String? workspaceSessionId;
  final String? remoteSessionId;
  final String? turnId;
  const AcpRuntimeStatus({
    required this.runtimeKey,
    required this.state,
    this.alive = false,
    this.childAlive = false,
    this.protocolVersion = 1,
    this.workspaceProtocol = 0,
    this.workspaceSessionId,
    this.remoteSessionId,
    this.turnId,
  });

  bool get isBusy => state == 'running' || state == 'waiting_permission';
  bool get canRecover =>
      !childAlive &&
      const {
        'completed',
        'failed',
        'cancelled',
        'exited',
        'expired',
        'retired',
      }.contains(state);

  factory AcpRuntimeStatus.fromJson(Map<String, dynamic> value) =>
      AcpRuntimeStatus(
        runtimeKey: value['runtimeKey'] as String,
        state: value['state'] as String,
        alive: value['alive'] == true,
        childAlive: value['childAlive'] == true,
        protocolVersion: (value['protocolVersion'] as num?)?.toInt() ?? 1,
        workspaceProtocol: (value['workspaceProtocol'] as num?)?.toInt() ?? 0,
        workspaceSessionId: value['workspaceSessionId'] as String?,
        remoteSessionId: value['sessionId'] as String?,
        turnId: value['turnId'] as String?,
      );
}

class AcpRuntimeUnavailableException implements Exception {
  final AcpRuntimeStatus status;
  const AcpRuntimeUnavailableException(this.status);
  @override
  String toString() => 'ACP_RUNTIME_UNAVAILABLE: ${status.state}';
}

/// User-owned broker installation; no sudo, package install, or public listener.
class AcpRuntimeService {
  static Future<String>? _source;

  static String identity(String serverIdentity) =>
      sha256.convert(utf8.encode(serverIdentity)).toString();

  static String sessionKey(
    String identity,
    AgentProfile profile,
    String sessionId, {
    int generation = 0,
  }) => sha256
      .convert(
        utf8.encode(
          '$identity\n${profile.id}\n$sessionId${generation == 0 ? '' : '\n$generation'}',
        ),
      )
      .toString();

  static Future<Map<String, dynamic>> install(SSHClient ssh) async {
    final source = await (_source ??= rootBundle.loadString(
      'assets/runtime/acp_broker.py',
    ));
    final bytes = base64Encode(utf8.encode(source));
    final loader =
        '''import os,pathlib,base64,hashlib,json,sys,socket,fcntl,sqlite3
if sys.version_info < (3,9): raise RuntimeError('ACP_RUNTIME_PYTHON_REQUIRED')
os.umask(0o077)
root=pathlib.Path.home()/'.local/share/valhalla/acp-runtime-v1'
root.mkdir(parents=True,exist_ok=True,mode=0o700)
if root.is_symlink() or root.stat().st_uid != os.getuid(): raise RuntimeError('ACP_RUNTIME_PATH_UNSAFE')
os.chmod(root,0o700)
p=root/'broker.py'
if p.is_symlink(): raise RuntimeError('ACP_RUNTIME_PATH_UNSAFE')
data=base64.b64decode('$bytes')
if not p.exists() or hashlib.sha256(p.read_bytes()).digest()!=hashlib.sha256(data).digest():
 import tempfile
 fd,tmp=tempfile.mkstemp(prefix='.broker-',dir=root)
 with os.fdopen(fd,'wb') as out: out.write(data)
 os.chmod(tmp,0o600)
 os.replace(tmp,p)
print(json.dumps({'script':str(p),'python':sys.executable,'version':2}))
''';
    final command =
        'python3 -c ${cliShellQuote('exec(__import__("base64").b64decode("${base64Encode(utf8.encode(loader))}"))')}';
    final result = await ssh
        .runWithResult(command)
        .timeout(const Duration(seconds: 30));
    if (result.exitCode != 0) throw StateError('ACP_RUNTIME_SETUP_FAILED');
    return jsonDecode(utf8.decode(result.stdout).trim())
        as Map<String, dynamic>;
  }

  static Future<dynamic> _query(
    SSHClient ssh,
    Map<String, dynamic> installed,
    String operation,
    String argument,
  ) async {
    final result = await ssh
        .runWithResult(
          '${cliShellQuote(installed['python'] as String)} '
          '${cliShellQuote(installed['script'] as String)} '
          '$operation ${cliShellQuote(argument)}',
        )
        .timeout(const Duration(seconds: 30));
    final dynamic value;
    try {
      value = jsonDecode(utf8.decode(result.stdout).trim());
    } on FormatException {
      throw StateError('ACP_RUNTIME_MANAGEMENT_FAILED');
    }
    if (value is Map && value['error'] is String) {
      final code = value['error'] as String;
      throw StateError(
        code.startsWith('ACP_RUNTIME_')
            ? code
            : 'ACP_RUNTIME_MANAGEMENT_FAILED',
      );
    }
    if (result.exitCode != 0) throw StateError('ACP_RUNTIME_MANAGEMENT_FAILED');
    return value;
  }

  static String _argument(Map<String, dynamic> command) =>
      base64Encode(utf8.encode(jsonEncode(command)));

  static Future<AcpRuntimeStatus> inspect(
    SSHClient ssh, {
    required String runtimeKey,
  }) async {
    final value = await _query(
      ssh,
      await install(ssh),
      'manage',
      _argument({'key': runtimeKey, 'action': 'inspect'}),
    );
    return AcpRuntimeStatus.fromJson(Map<String, dynamic>.from(value as Map));
  }

  static Future<List<AcpRuntimeStatus>> activeForServer(
    SSHClient ssh,
    String serverId,
  ) async {
    final value = await _query(
      ssh,
      await install(ssh),
      'active',
      identity(serverId),
    );
    return (value as List)
        .map(
          (item) =>
              AcpRuntimeStatus.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  static Future<void> manage(
    SSHClient ssh, {
    required String runtimeKey,
    required String action,
    bool stopRunning = false,
  }) => _manage(
    ssh,
    runtimeKey: runtimeKey,
    action: action,
    stopRunning: stopRunning,
  );
  static Future<void> manageShared(
    SSHClient ssh, {
    required String runtimeKey,
    required String action,
    required Map<String, dynamic> workspace,
    bool stopRunning = false,
  }) => _manage(
    ssh,
    runtimeKey: runtimeKey,
    action: action,
    stopRunning: stopRunning,
    workspace: workspace,
  );

  static Future<void> _manage(
    SSHClient ssh, {
    required String runtimeKey,
    required String action,
    bool stopRunning = false,
    Map<String, dynamic>? workspace,
  }) async {
    if (!const {'retire', 'purge'}.contains(action)) {
      throw ArgumentError('ACP_RUNTIME_COMMAND_INVALID');
    }
    await _query(
      ssh,
      await install(ssh),
      'manage',
      _argument({
        ...?workspace,
        'key': runtimeKey,
        'action': action,
        'stopRunning': stopRunning,
      }),
    );
  }

  static Future<AcpSshTransport> open(
    SSHClient ssh,
    AgentProfile profile, {
    required String runtimeKey,
    required int afterSequence,
    String? remoteSessionId,
    String? initialModelId,
  }) => _open(
    ssh,
    profile,
    runtimeKey: runtimeKey,
    afterSequence: afterSequence,
    remoteSessionId: remoteSessionId,
    initialModelId: initialModelId,
  );

  static Future<AcpSshTransport> openShared(
    SSHClient ssh,
    AgentProfile profile, {
    required String runtimeKey,
    required int afterSequence,
    required Map<String, dynamic> workspace,
    String? remoteSessionId,
    String? initialModelId,
    String? workingDirectory,
    String? title,
  }) => _open(
    ssh,
    profile,
    runtimeKey: runtimeKey,
    afterSequence: afterSequence,
    remoteSessionId: remoteSessionId,
    initialModelId: initialModelId,
    workspace: workspace,
    workingDirectory: workingDirectory,
    title: title,
  );

  static Future<AcpSshTransport> _open(
    SSHClient ssh,
    AgentProfile profile, {
    required String runtimeKey,
    required int afterSequence,
    String? remoteSessionId,
    String? initialModelId,
    Map<String, dynamic>? workspace,
    String? workingDirectory,
    String? title,
  }) async {
    final installed = await install(ssh);
    final status = AcpRuntimeStatus.fromJson(
      Map<String, dynamic>.from(
        await _query(
              ssh,
              installed,
              'manage',
              _argument({'key': runtimeKey, 'action': 'inspect'}),
            )
            as Map,
      ),
    );
    if (workspace != null &&
        workspace['controlToken'] == null &&
        !status.alive) {
      throw StateError('WORKSPACE_RUNTIME_NOT_RUNNING');
    }
    // A read-only observer may attach to a live legacy runtime: it receives the
    // raw stream and the transport refuses every write.  Only a writer needs
    // workspaceProtocol 1, and upgrading it must wait for an idle runtime.
    if (workspace != null &&
        workspace['controlToken'] != null &&
        status.alive &&
        status.workspaceProtocol < 1) {
      throw StateError('WORKSPACE_RUNTIME_UPGRADE_REQUIRED');
    }
    if (status.canRecover) throw AcpRuntimeUnavailableException(status);
    if (!status.alive && status.isBusy) {
      throw StateError('ACP_RUNTIME_UNFINISHED_PROCESS_EXITED');
    }
    final config = base64Encode(
      utf8.encode(
        jsonEncode({
          ...?workspace,
          'agentId': profile.id,
          'key': runtimeKey,
          'serverScope': identity(
            workspace?['workspaceId'] as String? ?? profile.serverId,
          ),
          'afterSeq': afterSequence,
          'sessionId': remoteSessionId,
          'chatSessionId': workspace?['workspaceSessionId'],
          'workingDirectory': workingDirectory,
          'title': title,
          'targetIdentity': identity(
            jsonEncode([
              profile.acpCommand,
              profile.cliCommand,
              profile.executionTarget,
              profile.containerBinding,
              profile.containerReference,
              profile.containerUser,
            ]),
          ),
          'argv': [
            '/bin/sh',
            '-c',
            agentAcpLaunchCommand(profile, initialModelId: initialModelId),
          ],
        }),
      ),
    );
    final session = await ssh.execute(
      '${cliShellQuote(installed['python'] as String)} '
      '${cliShellQuote(installed['script'] as String)} attach ${cliShellQuote(config)}',
    );
    final transport = AcpSshTransport(
      session,
      workspaceReadOnly: workspace != null && workspace['controlToken'] == null,
      runtimeKey: runtimeKey,
      afterSequence: afterSequence,
    );
    try {
      await transport.attached.timeout(const Duration(seconds: 30));
      return transport;
    } catch (_) {
      await transport.close();
      rethrow;
    }
  }
}
