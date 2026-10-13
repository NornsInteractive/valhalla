import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../data/models/server_profile.dart';
import '../../infrastructure/ssh/ssh_client_manager.dart';
import '../logging/sanitizer.dart';
import '../utils/shell_quote.dart';

enum NasNativeInstallStage {
  preflight,
  review,
  installing,
  configuring,
  starting,
  health,
  succeeded,
  failed,
  cancelled,
  needsInspection,
  reconciling,
}

class NasNativeInstallException implements Exception {
  final String code;
  const NasNativeInstallException(this.code);
  @override
  String toString() => code;
}

class NasNativeInstallRequest {
  final String serverId, serverName, serverKey, mediaPath;
  const NasNativeInstallRequest({
    required this.serverId,
    required this.serverName,
    required this.serverKey,
    required this.mediaPath,
  });
  factory NasNativeInstallRequest.forServer(
    ServerProfile server, {
    required String mediaPath,
  }) => NasNativeInstallRequest(
    serverId: server.id,
    serverName: server.name,
    serverKey: NasNativeInstallService.serverKey(server),
    mediaPath: mediaPath,
  );
  Map<String, dynamic> toJson() => {
    'serverId': serverId,
    'serverName': serverName,
    'serverKey': serverKey,
    'mediaPath': mediaPath,
  };
  factory NasNativeInstallRequest.fromJson(Map<String, dynamic> value) =>
      NasNativeInstallRequest(
        serverId: value['serverId'] as String,
        serverName: value['serverName'] as String,
        serverKey: value['serverKey'] as String,
        mediaPath: value['mediaPath'] as String,
      );
}

class NasNativeInstallPlan {
  final String id, confirmationToken, targetIdentity;
  final String os, osVersion, architecture, packageVersion;
  final NasNativeInstallRequest request;
  final DateTime createdAt;
  final List<String> steps, blockers, guidance;
  final bool existingInstall;
  final Map<String, String> packageVersions;
  final Map<String, dynamic> _remote;
  const NasNativeInstallPlan._({
    required this.id,
    required this.confirmationToken,
    required this.targetIdentity,
    required this.request,
    required this.createdAt,
    required this.os,
    required this.osVersion,
    required this.architecture,
    required this.packageVersion,
    required this.steps,
    required this.blockers,
    required this.guidance,
    required this.existingInstall,
    required this.packageVersions,
    required Map<String, dynamic> remote,
  }) : _remote = remote;
  bool get canInstall => blockers.isEmpty && !existingInstall;
  Uri get endpoint => Uri.parse('http://127.0.0.1:8096');
}

class NasNativeInstallResult {
  final String packageVersion;
  final bool healthy, existingInstall;
  const NasNativeInstallResult({
    required this.packageVersion,
    required this.healthy,
    this.existingInstall = false,
  });
  String get serviceName => 'jellyfin.service';
  String get dataRoot => '/var/lib/jellyfin';
  Uri get endpoint => Uri.parse('http://127.0.0.1:8096');
}

class NasNativeInstallTask {
  final String id, targetIdentity, packageVersion;
  final NasNativeInstallRequest request;
  final NasNativeInstallStage stage;
  final DateTime startedAt, updatedAt;
  final String currentCommand, logTail;
  final String? errorCode;
  final bool requiresReconciliation;
  final NasNativeInstallPlan? plan;
  final NasNativeInstallResult? result;
  const NasNativeInstallTask({
    required this.id,
    required this.request,
    required this.stage,
    required this.startedAt,
    required this.updatedAt,
    this.targetIdentity = '',
    this.packageVersion = '',
    this.currentCommand = '',
    this.logTail = '',
    this.errorCode,
    this.requiresReconciliation = false,
    this.plan,
    this.result,
  });
  bool get isBusy => const {
    NasNativeInstallStage.preflight,
    NasNativeInstallStage.installing,
    NasNativeInstallStage.configuring,
    NasNativeInstallStage.starting,
    NasNativeInstallStage.health,
    NasNativeInstallStage.reconciling,
  }.contains(stage);
  bool get canCancel => isBusy && stage != NasNativeInstallStage.reconciling &&
      stage != NasNativeInstallStage.preflight;
  Duration get elapsed =>
      (isBusy ? DateTime.now() : updatedAt).difference(startedAt);
}

/// Jellyfin's signed APT packages only. Never upgrades, adopts or removes an
/// existing installation. Confirmations are memory-only, bound to SSH identity.
/// A detached, root-owned worker survives disconnection; reconciliation only
/// observes it and never replays package operations.
class NasNativeInstallService {
  final SshCommandExecutor _ssh;
  final String? Function() _currentServerKey;
  final Future<void> Function(Map<String, dynamic>)? _persistTask;
  final _states = StreamController<NasNativeInstallTask?>.broadcast();
  NasNativeInstallTask? _state;
  NasNativeInstallPlan? _approval;
  Object? _approvalConnection;
  bool _disposed = false, _operation = false, _reading = false;
  Timer? _poller;
  Future<void> _persistence = Future<void>.value();

  NasNativeInstallService(
    this._ssh, {
    required String? Function() currentServerKey,
    Map<String, dynamic>? recoveredTask,
    Future<void> Function(Map<String, dynamic>)? persistTask,
  }) : _currentServerKey = currentServerKey,
       _persistTask = persistTask {
    if (recoveredTask != null) _restore(recoveredTask);
  }
  NasNativeInstallTask? get state => _state;
  Stream<NasNativeInstallTask?> get states => _states.stream;
  static String serverKey(ServerProfile server) =>
      sha256.convert(utf8.encode(server.connectionKey.toString())).toString();
  static String _newId() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  static final _id = RegExp(r'^[a-f0-9]{32}$');

  static void _validate(NasNativeInstallRequest request) {
    final media = request.mediaPath;
    if (request.serverId.isEmpty ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(request.serverKey) ||
        !media.startsWith('/') || media == '/' || media.length > 4096 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(media) ||
        media.split('/').any((part) => part == '.' || part == '..')) {
      throw const NasNativeInstallException('NAS_NATIVE_PATH_INVALID');
    }
  }

  void _check(NasNativeInstallRequest request, {Object? connection}) {
    _validate(request);
    if (_disposed || _currentServerKey() != request.serverKey) {
      throw const NasNativeInstallException('NAS_NATIVE_TARGET_CHANGED');
    }
    if (!_ssh.isConnected(request.serverId) ||
        _ssh.getClient(request.serverId) == null) {
      throw const NasNativeInstallException('NAS_NATIVE_SSH_REQUIRED');
    }
    if (connection != null &&
        !identical(connection, _ssh.getClient(request.serverId))) {
      throw const NasNativeInstallException('NAS_NATIVE_TARGET_CHANGED');
    }
  }

  void _emit(NasNativeInstallTask task) {
    if (_disposed) return;
    _state = task;
    _states.add(task);
  }

  Future<Map<String, dynamic>> _remote(
    NasNativeInstallRequest request,
    String mode,
    Map<String, dynamic> payload, {
    Object? connection,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    _check(request, connection: connection);
    final captured = _ssh.getClient(request.serverId);
    final body = base64Encode(utf8.encode(jsonEncode(payload)));
    // Keep the shared shell argument guard strict; transmit multiline code as data.
    final script = base64Encode(utf8.encode(remoteScript));
    final loader = 'import base64; exec(compile(base64.b64decode("$script"), '
        '"<valhalla-native>", "exec"))';
    final invocation = '/usr/bin/python3 -c ${cliShellQuote(loader)} '
        '${cliShellQuote(mode)} ${cliShellQuote(body)}';
    // Reuse argv rather than duplicate the embedded source in root/sudo branches.
    final result = await _ssh.executeWithLoginShell(
      request.serverId,
      'set -- $invocation; '
      'if ! test -x /usr/bin/python3; then '
      'printf \'VALHALLA_NATIVE:{"error":"NAS_NATIVE_TOOLS_REQUIRED"}\\n\'; '
      'elif test "\$(id -u)" = 0; then "\$@"; '
      'elif sudo -n -- true >/dev/null 2>&1; then sudo -n -- "\$@"; '
      'else printf \'VALHALLA_NATIVE:{"error":"NAS_NATIVE_SUDO_REQUIRED"}\\n\'; fi',
      timeout: timeout,
    );
    _check(request, connection: connection ?? captured);
    if (result.stdout.length > 512 * 1024) {
      throw const NasNativeInstallException('NAS_NATIVE_PROTOCOL_INVALID');
    }
    final lines = const LineSplitter().convert(result.stdout);
    final encoded = lines.where((line) => line.startsWith('VALHALLA_NATIVE:'))
        .lastOrNull;
    if (encoded == null) {
      throw NasNativeInstallException(result.exitCode == 127
          ? 'NAS_NATIVE_TOOLS_REQUIRED' : 'NAS_NATIVE_REMOTE_FAILED');
    }
    final value = jsonDecode(encoded.substring('VALHALLA_NATIVE:'.length));
    if (value is! Map) {
      throw const NasNativeInstallException('NAS_NATIVE_PROTOCOL_INVALID');
    }
    final data = Map<String, dynamic>.from(value);
    if (data['error'] is String) {
      throw NasNativeInstallException(_safeCode(data['error'] as String));
    }
    if (!result.isSuccess) {
      throw const NasNativeInstallException('NAS_NATIVE_REMOTE_FAILED');
    }
    return data;
  }

  Future<NasNativeInstallPlan> prepare(NasNativeInstallRequest request) async {
    _check(request);
    if (_operation || _state?.isBusy == true ||
        _state?.requiresReconciliation == true) {
      throw const NasNativeInstallException('NAS_NATIVE_TASK_PENDING');
    }
    _operation = true;
    _approval = null;
    final id = _newId(), now = DateTime.now();
    final connection = _ssh.getClient(request.serverId);
    _emit(NasNativeInstallTask(id: id, request: request,
      stage: NasNativeInstallStage.preflight, startedAt: now, updatedAt: now));
    try {
      final remote = await _remote(request, 'prepare', {
        ...request.toJson(), 'id': id,
      }, connection: connection, timeout: const Duration(minutes: 4));
      final versions = Map<String, String>.from(remote['packageVersions'] as Map);
      final plan = NasNativeInstallPlan._(
        id: id, confirmationToken: _newId(), request: request, createdAt: now,
        targetIdentity: remote['targetIdentity'] as String,
        os: remote['os'] as String, osVersion: remote['osVersion'] as String,
        architecture: remote['architecture'] as String,
        packageVersion: versions['jellyfin-server'] ?? '',
        packageVersions: Map.unmodifiable(versions),
        existingInstall: remote['existingInstall'] == true,
        blockers: List<String>.unmodifiable((remote['blockers'] as List).cast<String>()),
        guidance: const ['NAS_NATIVE_SETUP_REQUIRED', 'NAS_NATIVE_LOOPBACK_ONLY',
          'NAS_NATIVE_MEDIA_ACCESS_UNCHANGED', 'NAS_NATIVE_NO_AUTOMATIC_UPGRADE'],
        steps: const ['NAS_NATIVE_VERIFY_SIGNED_REPOSITORY',
          'NAS_NATIVE_PREVENT_AUTOSTART', 'NAS_NATIVE_INSTALL_PINNED_PACKAGES',
          'NAS_NATIVE_CONFIGURE_LOOPBACK', 'NAS_NATIVE_VERIFY_SERVICE'],
        remote: Map.unmodifiable(remote),
      );
      _approval = plan;
      _approvalConnection = connection;
      _emit(NasNativeInstallTask(id: id, request: request,
        stage: NasNativeInstallStage.review, startedAt: now, updatedAt: DateTime.now(),
        targetIdentity: plan.targetIdentity, packageVersion: plan.packageVersion,
        plan: plan));
      return plan;
    } catch (error) {
      _fail(error, mutation: false);
      rethrow;
    } finally { _operation = false; }
  }

  Future<NasNativeInstallTask> execute(String confirmationToken) async {
    final plan = _approval;
    final connection = _approvalConnection;
    _approval = null;
    _approvalConnection = null;
    if (_operation || plan == null || !plan.canInstall ||
        plan.confirmationToken != confirmationToken ||
        DateTime.now().difference(plan.createdAt) > const Duration(minutes: 15)) {
      throw const NasNativeInstallException('NAS_NATIVE_CONFIRMATION_INVALID');
    }
    _check(plan.request, connection: connection);
    _operation = true;
    var launched = false;
    try {
      final task = NasNativeInstallTask(id: plan.id, request: plan.request,
        stage: NasNativeInstallStage.installing, startedAt: DateTime.now(),
        updatedAt: DateTime.now(), targetIdentity: plan.targetIdentity,
        packageVersion: plan.packageVersion, requiresReconciliation: true);
      _emit(task);
      // A durable identity is mandatory before any remote mutation.
      await _persist(strict: true);
      _check(plan.request, connection: connection);
      launched = true;
      await _remote(plan.request, 'launch', {
        ...plan.request.toJson(), ...plan._remote, 'id': plan.id,
        '_workerCode': remoteScript,
      }, connection: connection);
      await refresh();
      _startPolling();
      return _state!;
    } catch (error) {
      _fail(error, mutation: launched);
      await _persist();
      rethrow;
    } finally { _operation = false; }
  }

  void _startPolling() {
    _poller?.cancel();
    if (!_disposed && _state?.isBusy == true) {
      _poller = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(refresh());
      });
    }
  }

  Future<void> refresh() async {
    final task = _state;
    if (_reading || _disposed || task == null ||
        task.stage == NasNativeInstallStage.preflight ||
        task.stage == NasNativeInstallStage.review) {
      return;
    }
    _reading = true;
    try {
      final data = await _remote(task.request, 'read', {
        ...task.request.toJson(), 'id': task.id,
        'targetIdentity': task.targetIdentity,
      });
      final stage = NasNativeInstallStage.values.byName(data['stage'] as String);
      final updated = DateTime.tryParse(data['updatedAt'] as String? ?? '') ??
          task.updatedAt;
      final boundedDate = updated.isBefore(task.startedAt) ||
          updated.isAfter(DateTime.now().add(const Duration(minutes: 5)))
          ? task.updatedAt : updated;
      final errorCode = data['errorCode'] as String?;
      final success = stage == NasNativeInstallStage.succeeded;
      _emit(NasNativeInstallTask(id: task.id, request: task.request,
        stage: stage, startedAt: task.startedAt, updatedAt: boundedDate,
        targetIdentity: task.targetIdentity, packageVersion: task.packageVersion,
        currentCommand: _safeText(data['currentCommand'] as String? ?? '', 4096),
        logTail: _safeText(data['logTail'] as String? ?? '', 64 * 1024),
        errorCode: errorCode == null ? null : _safeCode(errorCode),
        requiresReconciliation: stage == NasNativeInstallStage.needsInspection ||
            data['requiresReconciliation'] == true,
        result: success ? NasNativeInstallResult(
          packageVersion: task.packageVersion, healthy: true) : null));
      await _persist();
    } catch (error) {
      _fail(error, mutation: true);
      await _persist();
    } finally {
      _reading = false;
      if (_state?.isBusy != true) _poller?.cancel();
    }
  }

  Future<void> reconcile() async {
    final task = _state;
    if (task == null || _operation) return;
    _check(task.request);
    await refresh();
    _startPolling();
  }

  Future<void> requestCancel() async {
    final task = _state;
    if (task == null || !task.canCancel) return;
    if (task.stage == NasNativeInstallStage.preflight) {
      // Preflight has no package mutations; it must finish before another plan.
      throw const NasNativeInstallException('NAS_NATIVE_PREFLIGHT_IN_PROGRESS');
    }
    await _remote(task.request, 'cancel', {
      ...task.request.toJson(), 'id': task.id,
      'targetIdentity': task.targetIdentity,
    });
    await refresh();
  }

  void _fail(Object error, {required bool mutation}) {
    final task = _state;
    if (task == null || _disposed) return;
    _emit(NasNativeInstallTask(id: task.id, request: task.request,
      stage: mutation ? NasNativeInstallStage.needsInspection : NasNativeInstallStage.failed,
      startedAt: task.startedAt, updatedAt: DateTime.now(),
      targetIdentity: task.targetIdentity, packageVersion: task.packageVersion,
      currentCommand: task.currentCommand, logTail: task.logTail,
      errorCode: error is NasNativeInstallException ? error.code : 'NAS_NATIVE_REMOTE_FAILED',
      requiresReconciliation: mutation));
  }

  Future<void> _persist({bool strict = false}) async {
    final task = _state;
    if (_persistTask == null || task == null) {
      if (strict) throw const NasNativeInstallException('NAS_NATIVE_PERSIST_FAILED');
      return;
    }
    final summary = <String, dynamic>{
      ...task.request.toJson(), 'id': task.id, 'stage': task.stage.name,
      'targetIdentity': task.targetIdentity, 'packageVersion': task.packageVersion,
      'startedAt': task.startedAt.toIso8601String(),
      'updatedAt': task.updatedAt.toIso8601String(),
      'requiresReconciliation': task.requiresReconciliation,
      'currentCommand': _safeText(task.currentCommand, 4096),
      'logTail': _safeText(task.logTail, 64 * 1024), 'errorCode': task.errorCode,
    };
    final next = _persistence.then((_) => _persistTask(summary));
    _persistence = next.catchError((Object _) {});
    try { await next; } catch (_) {
      if (strict) throw const NasNativeInstallException('NAS_NATIVE_PERSIST_FAILED');
    }
  }

  void _restore(Map<String, dynamic> value) {
    try {
      final request = NasNativeInstallRequest.fromJson(value);
      _validate(request);
      if (request.serverKey != _currentServerKey() ||
          !_id.hasMatch(value['id'] as String) ||
          !RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(value['targetIdentity'] as String)) {
        return;
      }
      final oldStage = NasNativeInstallStage.values.byName(value['stage'] as String);
      if (oldStage == NasNativeInstallStage.preflight || oldStage == NasNativeInstallStage.review) return;
      final done = const {NasNativeInstallStage.succeeded,
        NasNativeInstallStage.failed, NasNativeInstallStage.cancelled}.contains(oldStage) &&
          value['requiresReconciliation'] != true;
      final version = value['packageVersion'] as String;
      final started = DateTime.parse(value['startedAt'] as String);
      final updated = DateTime.parse(value['updatedAt'] as String);
      _state = NasNativeInstallTask(id: value['id'] as String, request: request,
        stage: done ? oldStage : NasNativeInstallStage.needsInspection,
        startedAt: started, updatedAt: updated, targetIdentity: value['targetIdentity'] as String,
        packageVersion: version, requiresReconciliation: !done,
        currentCommand: _safeText(value['currentCommand'] as String? ?? '', 4096),
        logTail: _safeText(value['logTail'] as String? ?? '', 64 * 1024),
        errorCode: done ? value['errorCode'] as String? : 'NAS_NATIVE_INTERRUPTED',
        result: oldStage == NasNativeInstallStage.succeeded ?
          NasNativeInstallResult(packageVersion: version, healthy: true) : null);
    } catch (_) { /* Corrupt summaries never authorize a remote mutation. */ }
  }

  static String _safeCode(String code) =>
      RegExp(r'^NAS_NATIVE_[A-Z_]{1,80}$').hasMatch(code)
          ? code : 'NAS_NATIVE_REMOTE_FAILED';
  static String _safeText(String text, int limit) {
    final safe = LogSanitizer.sanitize(text);
    return safe.length <= limit ? safe : safe.substring(safe.length - limit);
  }
  void dispose() {
    _disposed = true;
    _approval = null;
    _approvalConnection = null;
    _poller?.cancel();
    unawaited(_states.close());
  }

  // The isolated APT lists in prepare are temporary and never alter sources,
  // package state, services or firewall. Only execute's one-use approval launches
  // this same audited helper as a private, detached systemd unit.
  static const remoteScript = r'''
import base64, datetime, fcntl, json, os, pathlib, pwd, re, selectors, shutil, stat, subprocess, sys, tempfile, time, urllib.request
os.environ['PATH']='/usr/sbin:/usr/bin:/sbin:/bin'
MODE = sys.argv[1]
C = json.loads(base64.b64decode(sys.argv[2], validate=True))
ROOT = '/var/lib/valhalla-native-jellyfin'
KEY_FINGERPRINT = '4918AABC486CA052358D778D49023CD01DE21A7B'
PACKAGES = ('jellyfin', 'jellyfin-server', 'jellyfin-web')
APT_SOURCE = '/etc/apt/sources.list.d/valhalla-jellyfin.sources'
APT_KEY = '/etc/apt/keyrings/valhalla-jellyfin.gpg'
GUARD_DIR = '/etc/systemd/system/jellyfin.service.d'
GUARD = GUARD_DIR + '/valhalla-native-install.conf'
MASK = '/etc/systemd/system/jellyfin.service'
TASK = None
META = {}
LOG_PENDING = b''
LOG_DROPPING = False

class Failure(Exception): pass
def fail(code): raise Failure('NAS_NATIVE_' + code)
def now(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def run(args, timeout=30, check=True):
    r = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        timeout=timeout, env=dict(os.environ, LC_ALL='C', DEBIAN_FRONTEND='noninteractive'))
    if len(r.stdout) > 4194304 or len(r.stderr) > 4194304: fail('OUTPUT_LIMIT')
    if check and r.returncode: fail('REMOTE_FAILED')
    return r
def text(args, **kwargs): return run(args, **kwargs).stdout.decode('utf-8', 'replace').strip()
def regular(p, root=True):
    s = os.lstat(p)
    if not stat.S_ISREG(s.st_mode) or s.st_nlink != 1 or (root and s.st_uid != 0): fail('PATH_UNSAFE')
    return s
def directory(p, create=False, mode=0o700):
    if create:
        try: os.mkdir(p, mode)
        except FileExistsError: pass
    s = os.lstat(p)
    if not stat.S_ISDIR(s.st_mode) or s.st_uid != 0 or s.st_mode & 0o022 or os.path.realpath(p) != p: fail('PATH_UNSAFE')
def write_new(p, data, mode=0o600):
    fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, mode)
    with os.fdopen(fd, 'wb') as f:
        f.write(data.encode() if isinstance(data, str) else data)
        f.flush(); os.fsync(f.fileno())
def atomic(p, data):
    if os.path.lexists(p): regular(p)
    tmp = p + '.next'
    write_new(tmp, json.dumps(data))
    os.replace(tmp, p)
def read_json(p):
    s = regular(p)
    if s.st_size > 131072: fail('OUTPUT_LIMIT')
    with open(p) as f: return json.load(f)
def identity():
    v = pathlib.Path('/etc/machine-id').read_text().strip()
    if not re.fullmatch('[0-9a-fA-F]{32}', v): fail('TARGET_INVALID')
    return v
def validate():
    if os.geteuid() != 0: fail('SUDO_REQUIRED')
    if not re.fullmatch('[0-9a-f]{32}', C.get('id', '')): fail('TASK_INVALID')
    if not re.fullmatch('[0-9a-f]{64}', C.get('serverKey', '')): fail('TARGET_INVALID')
    media = C.get('mediaPath', '')
    if not media.startswith('/') or media == '/' or len(media) > 4096 or re.search(r'[\x00-\x1f\x7f]', media) or any(p in ('.', '..') for p in media.split('/')): fail('PATH_INVALID')
    for tool in ('python3', 'apt-get', 'apt-cache', 'dpkg-query', 'dpkg', 'gpg', 'curl', 'systemctl', 'systemd-run', 'ss', 'runuser'):
        if not shutil.which(tool): fail('TOOLS_REQUIRED')
    if pathlib.Path('/proc/1/comm').read_text().strip() != 'systemd': fail('SYSTEMD_REQUIRED')
def basics():
    values = {}
    for line in pathlib.Path('/etc/os-release').read_text().splitlines():
        if '=' in line:
            k,v = line.split('=', 1); values[k] = v.strip().strip('"').strip("'")
    os_id, version, codename = values.get('ID',''), values.get('VERSION_ID',''), values.get('VERSION_CODENAME','')
    supported = {'debian': {'bullseye','bookworm','trixie'}, 'ubuntu': {'focal','jammy','noble','resolute'}}
    arch = text(['dpkg', '--print-architecture'])
    if os_id not in supported or codename not in supported[os_id] or arch not in ('amd64', 'arm64'): fail('OS_UNSUPPORTED')
    return dict(os=os_id, osVersion=version, codename=codename, architecture=arch, targetIdentity=identity())
def package_present():
    r = run(['dpkg-query', '-W', '-f=${db:Status-Abbrev}\n', *PACKAGES], check=False)
    return any(line.strip() and not line.startswith('un ') for line in r.stdout.decode().splitlines())
def check_new():
    if package_present(): fail('ALREADY_INSTALLED')
    for p in ('/etc/jellyfin','/var/lib/jellyfin','/var/cache/jellyfin','/var/log/jellyfin','/etc/default/jellyfin', MASK, '/run/systemd/system/jellyfin.service', GUARD_DIR, APT_SOURCE, APT_KEY):
        if os.path.lexists(p): fail('EXISTING_CONFIGURATION')
    if text(['systemctl','show','jellyfin.service','--property=LoadState','--value'], check=False) != 'not-found': fail('EXISTING_CONFIGURATION')
    if text(['ss','-H','-ltn','sport = :8096']): fail('PORT_BUSY')
    for p in ('/var/lib/dpkg/lock-frontend','/var/lib/dpkg/lock','/var/lib/apt/lists/lock'):
        if not os.path.lexists(p): continue
        regular(p)
        fd = os.open(p, os.O_RDWR | os.O_NOFOLLOW)
        try:
            try: fcntl.lockf(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError: fail('PACKAGE_MANAGER_BUSY')
        finally: os.close(fd)
    if text(['dpkg','--audit']): fail('PACKAGE_STATE_UNHEALTHY')
    if shutil.disk_usage('/var/lib').free < 2 * 1024**3: fail('DISK_SPACE')
    media = C['mediaPath'].rstrip('/')
    if not os.path.isdir(media) or os.path.realpath(media) != media or not os.access(media, os.R_OK | os.X_OK): fail('MEDIA_PATH_UNREADABLE')
    # No recursive ownership/ACL changes. If no service account exists yet,
    # demand public traversal/readability rather than promise unverified access.
    try: pwd.getpwnam('jellyfin'); has_user=True
    except KeyError: has_user=False
    if has_user:
        for flag in ('-r','-x'):
            if run(['runuser','-u','jellyfin','--','test',flag,media],check=False).returncode: fail('MEDIA_SERVICE_ACCESS_REQUIRED')
    else:
        parent=media
        while parent!='/':
            mode=os.stat(parent).st_mode
            if not mode & stat.S_IXOTH or (parent==media and not mode & stat.S_IROTH): fail('MEDIA_SERVICE_ACCESS_REQUIRED')
            parent=os.path.dirname(parent)
    for p in ('/etc/apt','/etc/apt/sources.list.d','/etc/systemd/system','/var/lib'):
        directory(p)

def source_text(info, key):
    return ('Types: deb\nURIs: https://repo.jellyfin.org/' + info['os'] +
        '\nSuites: ' + info['codename'] + '\nComponents: main\nArchitectures: ' +
        info['architecture'] + '\nSigned-By: ' + key + '\n')

def repository(info, scratch):
    asc, key = scratch + '/key.asc', scratch + '/key.gpg'
    run(['curl','--fail','--silent','--show-error','--location','--max-time','30',
        '--max-filesize','131072','--proto','=https','--proto-redir','=https',
        'https://repo.jellyfin.org/jellyfin_team.gpg.key','-o',asc], timeout=40)
    fingerprints = text(['gpg','--batch','--no-options','--homedir',scratch,
        '--with-colons','--import-options','show-only','--import',asc])
    first = next((s.split(':')[9] for s in fingerprints.splitlines() if s.startswith('fpr:')), '')
    if first != KEY_FINGERPRINT: fail('REPOSITORY_KEY_CHANGED')
    run(['gpg','--batch','--no-options','--homedir',scratch,'--dearmor','--output',key,asc])
    lists = scratch + '/lists'; os.mkdir(lists); os.mkdir(lists + '/partial')
    source = scratch + '/jellyfin.sources'; pathlib.Path(source).write_text(source_text(info,key))
    opts = ['-o','Dir::Etc::main=-','-o','Dir::Etc::parts=-',
        '-o','Dir::Etc::sourcelist='+source,'-o','Dir::Etc::sourceparts=-',
        '-o','Dir::State::lists='+lists,'-o','Dir::Cache::pkgcache=',
        '-o','Dir::Cache::srcpkgcache=','-o','APT::Get::List-Cleanup=0',
        '-o','Acquire::AllowInsecureRepositories=false',
        '-o','APT::Get::AllowUnauthenticated=false',
        '-o','APT::Update::Error-Mode=any']
    # APT_CONFIG prevents the machine's global hooks from executing during
    # an isolated preview. Explicit -o options remain authoritative.
    empty_config = scratch + '/apt.conf'
    pathlib.Path(empty_config).write_text('Dir::Etc::main "-"; Dir::Etc::parts "-";\n')
    previous = os.environ.get('APT_CONFIG'); os.environ['APT_CONFIG'] = empty_config
    try:
        if run(['apt-get',*opts,'update'], timeout=150, check=False).returncode: fail('REPOSITORY_UNAVAILABLE')
        versions = {}
        server_metadata=text(['apt-cache',*opts,'show','jellyfin-server'])
        ffmpeg=re.search(r'^Recommends:.*?\b(jellyfin-ffmpeg[0-9]+)\b',server_metadata,re.M)
        if not ffmpeg: fail('PACKAGE_UNAVAILABLE')
        for package in (*PACKAGES,ffmpeg.group(1)):
            output = text(['apt-cache',*opts,'policy',package])
            candidate = re.search(r'^\s*Candidate:\s*(\S+)',output,re.M)
            if not candidate or not re.fullmatch(r'[A-Za-z0-9.+:~_-]{1,150}',candidate.group(1)): fail('PACKAGE_UNAVAILABLE')
            versions[package] = candidate.group(1)
        installed_ffmpeg=text(['dpkg-query','-W','-f=${Version}',ffmpeg.group(1)],check=False)
        if installed_ffmpeg and installed_ffmpeg!=versions[ffmpeg.group(1)]: fail('EXISTING_CONFIGURATION')
    finally:
        if previous is None: os.environ.pop('APT_CONFIG',None)
        else: os.environ['APT_CONFIG'] = previous
    return versions, pathlib.Path(key).read_bytes()

def prepare():
    info = basics(); blockers = []
    existing = package_present()
    try: check_new()
    except Failure as e: blockers.append(str(e))
    versions = {}
    if not blockers:
        with tempfile.TemporaryDirectory(prefix='valhalla-jellyfin-preview-') as scratch:
            versions,_ = repository(info,scratch)
    return dict(info, packageVersions=versions, existingInstall=existing, blockers=blockers)

def task_path():
    global TASK
    directory('/var/lib'); directory(ROOT)
    TASK = ROOT + '/' + C['id']; directory(TASK)
    owner = read_json(TASK + '/owner.json')
    for key in ('id','serverKey','targetIdentity'):
        if owner.get(key) != C.get(key): fail('TARGET_CHANGED')
    if identity() != C['targetIdentity']: fail('TARGET_CHANGED')
    return owner

def stage(value, command='', error=None, reconcile=False):
    global META
    META = dict(stage=value, currentCommand=command, errorCode=error,
        updatedAt=now(), requiresReconciliation=reconcile)
    atomic(TASK + '/state.json',META)
def log_chunk(data):
    global LOG_PENDING, LOG_DROPPING
    # Flush only complete bounded lines; truncation never persists the suffix
    # of a credential-bearing line without the key needed by the sanitizer.
    output=[]
    for piece in data.replace(b'\r',b'\n').splitlines(keepends=True):
        end=piece.endswith(b'\n')
        if not LOG_DROPPING:
            if len(LOG_PENDING)+len(piece)>16384:
                output.append(b'[oversized log line omitted]\n')
                LOG_PENDING=b''; LOG_DROPPING=True
            else:
                LOG_PENDING+=piece
                if end: output.append(LOG_PENDING); LOG_PENDING=b''
        if end: LOG_DROPPING=False
    data=b''.join(output)
    if not data: return
    p = TASK + '/log'
    regular(p)
    # Store only a bounded tail; no credentials are passed to this worker.
    with open(p,'r+b') as f:
        f.seek(0,2)
        if f.tell()+len(data) > 65536:
            f.seek(0); prior=f.read(65536); merged=(prior+data)[-65536:]
            merged=merged.partition(b'\n')[2]
            f.seek(0); f.write(merged); f.truncate()
        else: f.write(data)
def command(args, phase, timeout=None):
    import shlex
    shown = shlex.join(args)
    stage(phase,shown,reconcile=True); log_chunk(('\n$ '+shown+'\n').encode())
    p = subprocess.Popen(args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
        env=dict(os.environ,LC_ALL='C',DEBIAN_FRONTEND='noninteractive',NEEDRESTART_MODE='l'))
    # Bounded reads expose output while a process is alive, without readline
    # buffering or sending a signal to package-manager children on cancellation.
    sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ)
    began=time.monotonic()
    try:
        while sel.get_map():
            for key,_ in sel.select(1):
                data=os.read(key.fd,4096)
                if data: log_chunk(data)
                else: sel.unregister(key.fileobj)
            if timeout is not None and time.monotonic()-began > timeout:
                p.terminate(); p.wait(); fail('HEALTH_FAILED')
        code=p.wait()
    finally: sel.close(); p.stdout.close()
    log_chunk(b'\n')
    if code: fail('COMMAND_FAILED')
def cancelled():
    p=TASK+'/cancel'
    if os.path.lexists(p): regular(p); fail('CANCELLED')
def assert_target():
    if identity()!=C['targetIdentity']: fail('TARGET_CHANGED')
    actual=basics()
    if any(actual[k]!=C[k] for k in ('os','osVersion','codename','architecture')): fail('TARGET_CHANGED')
def own_mask(): return os.path.islink(MASK) and os.readlink(MASK)=='/dev/null'
def verify_health():
    if text(['systemctl','is-active','jellyfin.service'],check=False)!='active': return False
    pid=text(['systemctl','show','jellyfin.service','--property=MainPID','--value'])
    if not pid.isdigit() or pid=='0': return False
    listeners=text(['ss','-H','-ltnp','sport = :8096'])
    lines=[s.split() for s in listeners.splitlines() if s.strip()]
    if not lines: return False
    if any(len(s)<5 or s[3]!='127.0.0.1:8096' or ('pid='+pid+',') not in ' '.join(s) for s in lines): fail('LISTENER_UNSAFE')
    r=run(['curl','--noproxy','*','--fail','--silent','--show-error','--max-time','5','http://127.0.0.1:8096/health'],timeout=8,check=False)
    return r.returncode==0

def worker():
    task_path(); assert_target()
    lock=os.open(ROOT+'/install.lock',os.O_RDWR|os.O_CREAT|os.O_NOFOLLOW,0o600)
    regular(ROOT+'/install.lock')
    try: fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    except BlockingIOError: fail('TASK_PENDING')
    check_new(); cancelled()
    with tempfile.TemporaryDirectory(prefix='valhalla-jellyfin-install-') as scratch:
        stage('installing','Verify official signed APT package versions',reconcile=True)
        versions,key=repository(C,scratch)
        if versions!=C['packageVersions']: fail('PACKAGE_VERSION_CHANGED')
        assert_target(); check_new(); cancelled()
        if not os.path.exists('/etc/apt/keyrings'): os.mkdir('/etc/apt/keyrings',0o755)
        directory('/etc/apt/keyrings')
        write_new(APT_KEY,key,0o644)
        write_new(APT_SOURCE,source_text(C,APT_KEY),0o644)
        # The persistent condition supplements the mask: a maintainer script
        # unmasking the unit still cannot start it before safe configuration.
        os.mkdir(GUARD_DIR,0o755)
        guard='[Unit]\nConditionPathExists='+TASK+'/ready\n'
        write_new(GUARD,guard,0o644)
        os.symlink('/dev/null',MASK)
        command(['systemctl','daemon-reload'],'installing')
        command(['apt-get','-o','APT::Update::Error-Mode=any',
            '-o','Acquire::AllowInsecureRepositories=false','update'],'installing')
        cancelled()
        command(['apt-get','-o','APT::Get::AllowUnauthenticated=false',
            '--no-remove','--no-upgrade','-y','install',
            *[p+'='+v for p,v in versions.items()]],'installing')
        # No cancellation signal is ever sent to apt/dpkg. Cancel only once
        # packages have reached a consistent stopping point; keep guard/mask.
        cancelled()
        for p,v in versions.items():
            if text(['dpkg-query','-W','-f=${Version}',p])!=v: fail('PACKAGE_VERSION_CHANGED')
        if text(['systemctl','is-active','jellyfin.service'],check=False)=='active': fail('AUTOSTART_UNSAFE')
        stage('configuring','Configure Jellyfin loopback binding',reconcile=True)
        service_user=pwd.getpwnam('jellyfin')
        s=os.lstat('/etc/jellyfin')
        if not stat.S_ISDIR(s.st_mode) or s.st_uid not in (0,service_user.pw_uid) or s.st_mode & 0o002 or os.path.realpath('/etc/jellyfin')!='/etc/jellyfin': fail('PATH_UNSAFE')
        config='/etc/jellyfin/network.xml'
        network='<?xml version="1.0" encoding="utf-8"?>\n<NetworkConfiguration><EnableIPv4>true</EnableIPv4><EnableIPv6>false</EnableIPv6><EnableHttps>false</EnableHttps><EnableUPnP>false</EnableUPnP><AutoDiscovery>false</AutoDiscovery><EnableRemoteAccess>false</EnableRemoteAccess><InternalHttpPort>8096</InternalHttpPort><LocalNetworkAddresses><string>127.0.0.1</string></LocalNetworkAddresses></NetworkConfiguration>\n'
        # A package-provided config may exist on this freshly installed service.
        # Refuse symlinks or files not owned by root/the new service user.
        if os.path.lexists(config):
            s=regular(config,root=False)
            if s.st_uid not in (0,service_user.pw_uid): fail('PATH_UNSAFE')
            if s.st_size>65536: fail('PATH_UNSAFE')
            os.rename(config,TASK+'/network.package.xml')
        write_new(config,network,0o640)
        os.chown(config,service_user.pw_uid,service_user.pw_gid)
        if run(['runuser','-u','jellyfin','--','test','-r',C['mediaPath']],check=False).returncode or run(['runuser','-u','jellyfin','--','test','-x',C['mediaPath']],check=False).returncode: fail('MEDIA_SERVICE_ACCESS_REQUIRED')
        cancelled(); assert_target()
        regular(GUARD)
        if pathlib.Path(GUARD).read_text()!=guard: fail('PATH_UNSAFE')
        # ready remains inside the owned task: failure does not auto-unmask or
        # remove a user's independent unit override.
        write_new(TASK+'/ready','ready\n')
        if os.path.lexists(MASK):
            if not own_mask(): fail('PATH_UNSAFE')
            os.unlink(MASK)
        command(['systemctl','daemon-reload'],'starting')
        command(['systemctl','enable','--now','jellyfin.service'],'starting')
        stage('health','curl --noproxy * http://127.0.0.1:8096/health',reconcile=True)
        healthy=False
        for _ in range(60):
            cancelled()
            if verify_health(): healthy=True; break
            time.sleep(2)
        if not healthy: fail('HEALTH_FAILED')
        stage('succeeded')

def launch():
    global TASK
    assert_target(); check_new()
    directory('/var/lib'); directory(ROOT,create=True)
    TASK=ROOT+'/'+C['id']
    os.mkdir(TASK,0o700); directory(TASK)
    worker_code=C.pop('_workerCode')
    write_new(TASK+'/owner.json',json.dumps(C))
    write_new(TASK+'/log',b'')
    stage('installing','Prepare native Jellyfin worker',reconcile=True)
    write_new(TASK+'/worker.py',worker_code)
    # Child receives only validated non-secret task identity. It reloads the
    # private owner record, which includes exact previewed package versions.
    arg=base64.b64encode(json.dumps(C).encode()).decode()
    r=run(['systemd-run','--quiet','--unit=valhalla-jellyfin-'+C['id'],
        '--property=Type=exec','--property=RemainAfterExit=yes',
        '/usr/bin/python3',TASK+'/worker.py','worker',arg],check=False)
    if r.returncode: fail('LAUNCH_UNCERTAIN')
    return {'accepted':True}

def read_task():
    owner=task_path()
    # Observe liveness before reading state, so a just-finished worker's final
    # result wins over a preceding active snapshot.
    active=text(['systemctl','show','valhalla-jellyfin-'+C['id'],
        '--property=SubState','--value'],check=False)
    meta=read_json(TASK+'/state.json')
    regular(TASK+'/log')
    with open(TASK+'/log','rb') as f:
        f.seek(0,2); f.seek(max(0,f.tell()-65536)); logs=f.read(65536).decode('utf-8','replace')
    terminal=meta.get('stage') in ('succeeded','failed','cancelled')
    if not terminal and active not in ('running','start','start-pre','start-post'):
        meta.update(stage='needsInspection',errorCode='NAS_NATIVE_INTERRUPTED',requiresReconciliation=True)
    if active not in ('running','start','start-pre','start-post') and meta.get('requiresReconciliation'):
        # Inspect the installed outcome, never continue installation or remove
        # an owned mask. A manually repaired completed service can be recognized.
        expected=owner.get('packageVersions',{})
        versions_ok=bool(expected) and all(text(['dpkg-query','-W','-f=${Version}',p],check=False)==v for p,v in expected.items())
        audit=text(['dpkg','--audit'])
        details='\nReconciliation: packages='+('exact' if versions_ok else 'incomplete')+', dpkg='+('clean' if not audit else 'needs inspection')
        try: healthy=versions_ok and not audit and verify_health()
        except Failure: healthy=False
        if healthy:
            meta.update(stage='succeeded',errorCode=None,requiresReconciliation=False,updatedAt=now(),currentCommand='')
        else:
            meta.update(stage='needsInspection',requiresReconciliation=True)
        logs=(logs+details)[-65536:]
    return dict(meta,logTail=logs)

try:
    validate()
    if MODE=='prepare': result=prepare()
    elif MODE=='launch': result=launch()
    elif MODE=='read': result=read_task()
    elif MODE=='cancel':
        task_path()
        if not os.path.lexists(TASK+'/cancel'): write_new(TASK+'/cancel','requested\n')
        else: regular(TASK+'/cancel')
        result={'requested':True}
    elif MODE=='worker':
        # The script is supplied once by the confirmed client, not downloaded.
        try: worker()
        except Exception as error:
            code=str(error) if isinstance(error,Failure) else 'NAS_NATIVE_REMOTE_FAILED'
            if TASK:
                # Only this newly owned service may be stopped. Do not undo a
                # foreign mask/unit or kill any package-manager process.
                try:
                    guard='[Unit]\nConditionPathExists='+TASK+'/ready\n'
                    owner=read_json(TASK+'/owner.json')
                    same_target=identity()==C.get('targetIdentity') and all(owner.get(k)==C.get(k) for k in ('id','serverKey','targetIdentity'))
                    fragment=text(['systemctl','show','jellyfin.service','--property=FragmentPath','--value'],check=False)
                    owned_unit=fragment in ('','/dev/null','/lib/systemd/system/jellyfin.service','/usr/lib/systemd/system/jellyfin.service')
                    if same_target and owned_unit and os.path.isfile(GUARD) and not os.path.islink(GUARD) and pathlib.Path(GUARD).read_text()==guard:
                        regular(GUARD)
                        ready=TASK+'/ready'
                        if os.path.lexists(ready): regular(ready); os.unlink(ready)
                        run(['systemctl','stop','jellyfin.service'],timeout=60,check=False)
                        if not os.path.lexists(MASK): os.symlink('/dev/null',MASK)
                        run(['systemctl','daemon-reload'],check=False)
                except Exception: code='NAS_NATIVE_SERVICE_NEEDS_INSPECTION'
                # Package/config changes are never rolled back blindly.
                stage('cancelled' if code=='NAS_NATIVE_CANCELLED' else 'failed',
                    error=code,reconcile=True)
                log_chunk(('\n'+code+'\n').encode())
            raise
        result={'finished':True}
    else: fail('PROTOCOL_INVALID')
    print('VALHALLA_NATIVE:'+json.dumps(result))
except Exception as error:
    code=str(error) if isinstance(error,Failure) else 'NAS_NATIVE_REMOTE_FAILED'
    print('VALHALLA_NATIVE:'+json.dumps({'error':code}))
    sys.exit(1)
''';
}
