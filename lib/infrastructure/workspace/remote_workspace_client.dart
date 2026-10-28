import 'dart:convert';
import 'dart:isolate';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart';
import '../../core/utils/shell_quote.dart';

class WorkspaceException implements Exception {
  final String code;
  final Map<String, dynamic> details;
  const WorkspaceException(this.code, [this.details = const {}]);
  @override
  String toString() => code;
}

/// Uses SSH stdin, never a public listener or command-line data arguments.
class RemoteWorkspaceClient {
  static const _relative = '.local/share/valhalla/workspace-v1';

  static String _pythonCommand(String source) {
    final encoded = base64Encode(utf8.encode(source));
    return 'python3 -c ${cliShellQuote("import base64;exec(base64.b64decode('$encoded'))")}';
  }

  /// Protocol/schema understood by this app build.
  static const schemaVersion = 1;

  /// Store implementation revision. A remote component newer than this build
  /// must never be replaced by an older bundled `store.py`.
  static const componentVersion = 2;

  /// The backend caps a page below 1 MiB; the transport keeps a 4 MiB
  /// safety ceiling for older/foreign stores.
  static const maxPageBytes = 1024 * 1024;
  static const maxResponseBytes = 4 * 1024 * 1024;

  /// Reads the remote store without writing anything and rejects a future
  /// schema/component before any install can replace it.
  Future<Map<String, dynamic>> preflight(SSHClient ssh) async {
    final value = await discover(ssh);
    if (value['exists'] == false) return value;
    _checkVersions(value);
    return value;
  }

  void _checkVersions(Map<String, dynamic> value) {
    final schema = value['schema'];
    if (schema is! int || schema < 1 || schema > schemaVersion) {
      throw const WorkspaceException('WORKSPACE_SCHEMA_UNSUPPORTED');
    }
    final component = value['component'] ?? value['componentVersion'];
    if (component != null &&
        (component is! int || component < 1 || component > componentVersion)) {
      throw const WorkspaceException('WORKSPACE_COMPONENT_UNSUPPORTED');
    }
  }

  Future<Map<String, dynamic>> discover(SSHClient ssh) async {
    const source = '''import json,pathlib,os,sys,stat
def fail(code):
 print(json.dumps({"ok":False,"error":code}));sys.exit(0)
if sys.version_info<(3,9): fail("WORKSPACE_PYTHON_REQUIRED")
home=pathlib.Path.home()
root=home/".local/share/valhalla/workspace-v1"
p=root/"store.py"
for x in (home,home/".local",home/".local/share",root.parent,root,p):
 if x.is_symlink(): fail("WORKSPACE_PATH_UNSAFE")
 if not x.exists():
  print(json.dumps({"ok":True,"exists":False}));sys.exit(0)
 info=x.stat()
 if info.st_uid!=os.getuid() or (not stat.S_ISREG(info.st_mode) if x==p else not stat.S_ISDIR(info.st_mode)): fail("WORKSPACE_PATH_UNSAFE")
os.execv(sys.executable,[sys.executable,str(p)])
''';
    return _execute(ssh, _pythonCommand(source), {'op': 'discover'});
  }

  Future<void> install(SSHClient ssh) async {
    // Never overwrite a store before learning its schema/component. This runs
    // before the bundled source is even loaded or written.
    final existing = await preflight(ssh);
    if (existing['exists'] != false) _checkVersions(existing);
    final source = await rootBundle.loadString(
      'assets/runtime/workspace_store.py',
    );
    final nasSource = await rootBundle.loadString(
      'assets/runtime/workspace_nas.py',
    );
    const loader = '''import os,pathlib,tempfile,base64,sys,json,stat
if sys.version_info<(3,9): raise RuntimeError("WORKSPACE_PYTHON_REQUIRED")
os.umask(0o077)
root=pathlib.Path.home()
if root.is_symlink() or root.stat().st_uid!=os.getuid(): raise RuntimeError("WORKSPACE_PATH_UNSAFE")
for part in (".local","share","valhalla","workspace-v1"):
 root=root/part
 if root.is_symlink(): raise RuntimeError("WORKSPACE_PATH_UNSAFE")
 root.mkdir(mode=0o700,exist_ok=True)
 if root.stat().st_uid!=os.getuid(): raise RuntimeError("WORKSPACE_PATH_UNSAFE")
os.chmod(root,0o700)
sources=json.loads(sys.stdin.buffer.read())
if set(sources)!={"store.py","workspace_nas.py"}: raise RuntimeError("WORKSPACE_SETUP_FAILED")
for name in ("workspace_nas.py","store.py"):
 p=root/name
 if p.is_symlink() or p.exists() and (p.stat().st_uid!=os.getuid() or not stat.S_ISREG(p.stat().st_mode)): raise RuntimeError("WORKSPACE_PATH_UNSAFE")
 data=base64.b64decode(sources[name],validate=True)
 fd,tmp=tempfile.mkstemp(prefix=".component-",dir=root)
 try:
  with os.fdopen(fd,"wb") as f: f.write(data);f.flush();os.fsync(f.fileno())
  os.replace(tmp,p)
 finally:
  if os.path.exists(tmp): os.unlink(tmp)
print("WORKSPACE_INSTALLED")
''';
    final session = await ssh.execute(_pythonCommand(loader));
    final result = Future.wait([
      session.stdout.drain<void>(),
      session.stderr.drain<void>(),
      session.done,
    ]);
    session.stdin.add(
      utf8.encode(
        jsonEncode({
          'store.py': base64Encode(utf8.encode(source)),
          'workspace_nas.py': base64Encode(utf8.encode(nasSource)),
        }),
      ),
    );
    await session.stdin.close();
    await result.timeout(const Duration(seconds: 30));
    if (session.exitCode != 0) {
      throw const WorkspaceException('WORKSPACE_SETUP_FAILED');
    }
  }

  Future<Map<String, dynamic>> request(
    SSHClient ssh,
    Map<String, dynamic> command,
  ) => _execute(
    ssh,
    'python3 "\$HOME/$_relative/${(command['op'] as String?)?.startsWith('nas_') == true ? 'workspace_nas.py' : 'store.py'}"',
    command,
  );

  Future<Map<String, dynamic>> _execute(
    SSHClient ssh,
    String command,
    Map<String, dynamic> body,
  ) async {
    final session = await ssh.execute(command);
    final output = session.stdout.fold<List<int>>([], (bytes, part) {
      if (bytes.length + part.length > maxResponseBytes) {
        session.close();
        throw const WorkspaceException('WORKSPACE_RESPONSE_TOO_LARGE');
      }
      return bytes..addAll(part);
    });
    // Drain stderr separately; never expose or persist remote startup output.
    final errors = session.stderr.drain<void>();
    session.stdin.add(utf8.encode('${jsonEncode(body)}\n'));
    await session.stdin.close();
    try {
      final bytes = await output.timeout(const Duration(seconds: 30));
      await errors;
      await session.done;
      if (session.exitCode == 127) {
        throw const WorkspaceException('WORKSPACE_PYTHON_REQUIRED');
      }
      final text = utf8.decode(bytes).trim();
      // Large pages are decoded off the UI isolate; small replies stay cheap.
      final value = bytes.length > 256 * 1024
          ? await Isolate.run(() => jsonDecode(text))
          : jsonDecode(text);
      if (value is! Map<String, dynamic>) {
        throw const WorkspaceException('WORKSPACE_INVALID_RESPONSE');
      }
      if (value['ok'] != true) {
        final code = value['error'];
        throw WorkspaceException(
          code is String && RegExp(r'^WORKSPACE_[A-Z_]+$').hasMatch(code)
              ? code
              : 'WORKSPACE_REQUEST_FAILED',
          value,
        );
      }
      if (session.exitCode != 0) {
        throw const WorkspaceException('WORKSPACE_REQUEST_FAILED');
      }
      return value;
    } on FormatException {
      throw const WorkspaceException('WORKSPACE_INVALID_RESPONSE');
    } finally {
      session.close();
    }
  }
}
