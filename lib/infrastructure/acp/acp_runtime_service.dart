import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart';

import '../../core/utils/shell_quote.dart';
import '../../data/models/agent_profile.dart';
import '../cli/agent_execution_target.dart';
import 'acp_ssh_transport.dart';

/// User-owned broker installation; no sudo, package install, or public listener.
class AcpRuntimeService {
  static Future<String>? _source;

  static String identity(String serverIdentity) =>
      sha256.convert(utf8.encode(serverIdentity)).toString();

  static String sessionKey(
    String identity,
    AgentProfile profile,
    String sessionId,
  ) => sha256
      .convert(utf8.encode('$identity\n${profile.id}\n$sessionId'))
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
print(json.dumps({'script':str(p),'python':sys.executable,'version':1}))
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

  static Future<AcpSshTransport> open(
    SSHClient ssh,
    AgentProfile profile, {
    required String runtimeKey,
    required int afterSequence,
    String? remoteSessionId,
    String? initialModelId,
  }) async {
    final installed = await install(ssh);
    final config = base64Encode(
      utf8.encode(
        jsonEncode({
          'key': runtimeKey,
          'afterSeq': afterSequence,
          'sessionId': remoteSessionId,
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
