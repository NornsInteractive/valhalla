import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:dartssh2/dartssh2.dart' show SSHSession, SSHSignal;
import 'package:flutter/foundation.dart' show immutable;

import '../logging/sanitizer.dart';
import 'app_diagnostics.dart';

import '../../infrastructure/docker/docker_cli_service.dart';
import '../../infrastructure/ssh/ssh_client_manager.dart';
import '../utils/shell_quote.dart';

enum NasInstallProduct { jellyfin, emby, webdav }

enum NasInstallStage {
  preflight,
  review,
  writing,
  pulling,
  starting,
  health,
  cleanup,
  succeeded,
  failed,
  cancelled,
  needsInspection,
  reconciling,
}

@immutable
class NasInstallTask {
  final String id;
  final NasInstallRequest request;
  final NasInstallStage stage;
  final DateTime startedAt, updatedAt;
  final String logTail;
  final String? errorCode;
  final bool? cleanupComplete;
  final bool requiresReconciliation;
  final NasInstallPlan? plan;
  final NasInstallResult? result;
  const NasInstallTask({
    required this.id,
    required this.request,
    required this.stage,
    required this.startedAt,
    required this.updatedAt,
    this.logTail = '',
    this.errorCode,
    this.cleanupComplete,
    this.requiresReconciliation = false,
    this.plan,
    this.result,
  });
  bool get isBusy => const {
    NasInstallStage.preflight,
    NasInstallStage.writing,
    NasInstallStage.pulling,
    NasInstallStage.starting,
    NasInstallStage.health,
    NasInstallStage.cleanup,
    NasInstallStage.reconciling,
  }.contains(stage);
  bool get canCancel =>
      isBusy &&
      stage != NasInstallStage.cleanup &&
      stage != NasInstallStage.reconciling;
  Duration get elapsed =>
      (isBusy ? DateTime.now() : updatedAt).difference(startedAt);
}

@immutable
class NasInstallRequest {
  final String serverId,
      serverName,
      mediaPath,
      dataRoot,
      bindAddress,
      webdavUser;
  final NasInstallProduct product;
  final int port;
  const NasInstallRequest({
    required this.serverId,
    required this.serverName,
    required this.product,
    required this.mediaPath,
    required this.dataRoot,
    this.bindAddress = '127.0.0.1',
    this.port = 8096,
    this.webdavUser = 'nas',
  });
}

class NasInstallPlan {
  final String id,
      pinnedImage,
      composePreview,
      confirmationToken,
      targetIdentity;
  final NasInstallRequest request;
  final DateTime createdAt;
  final List<String> steps, blockers, guidance;
  const NasInstallPlan._({
    required this.id,
    required this.request,
    required this.pinnedImage,
    required this.composePreview,
    required this.steps,
    required this.blockers,
    required this.guidance,
    required this.confirmationToken,
    required this.createdAt,
    required this.targetIdentity,
  });
  String get containerName => 'valhalla-nas-${id.substring(0, 12)}';
  bool get canInstall => blockers.isEmpty;
}

class NasInstallResult {
  final String containerId, dataRoot;
  final Uri endpoint;
  final bool healthy;
  const NasInstallResult({
    required this.containerId,
    required this.endpoint,
    required this.dataRoot,
    required this.healthy,
  });
}

class NasInstallException implements Exception {
  final String code;
  final bool cleanupComplete;
  const NasInstallException(this.code, {this.cleanupComplete = true});
  @override
  String toString() =>
      '$code${cleanupComplete ? '' : ':NAS_INSTALL_CLEANUP_INCOMPLETE'}';
}

/// Creates only a new, isolated Compose project after a one-use confirmation.
/// Service data, existing directories, images and external networks are never
/// deleted by rollback. Passwords are sent over SSH stdin, never command text.
class NasInstallService {
  final SshCommandExecutor _ssh;
  final DockerCliService _docker;
  final Map<String, (NasInstallPlan, String?)> _pending = {};
  final Future<void> Function(Map<String, dynamic>)? _persistTask;
  final _states = StreamController<NasInstallTask?>.broadcast();
  NasInstallTask? _state;
  Completer<void>? _cancellation;
  Timer? _ticker;
  bool _disposed = false;
  bool _running = false;
  bool _interruptedMutation = false;
  NasInstallStage? _interruptedStage;
  String? _interruptionCode;
  String? _secret;
  String? _targetIdentity;
  String? _targetCanonicalDataRoot;
  Object? _connection;
  String _pendingLog = '';
  static const maxLogBytes = 256 * 1024;
  NasInstallService(
    this._ssh,
    this._docker, {
    Map<String, dynamic>? recoveredTask,
    Future<void> Function(Map<String, dynamic>)? persistTask,
  }) : _persistTask = persistTask {
    if (recoveredTask != null) _restore(recoveredTask);
  }
  NasInstallTask? get state => _state;
  Stream<NasInstallTask?> get states => _states.stream;

  void _restore(Map<String, dynamic> value) {
    try {
      final request = NasInstallRequest(
        serverId: value['serverId'] as String,
        serverName: value['serverName'] as String,
        product: NasInstallProduct.values.byName(value['product'] as String),
        mediaPath: value['mediaPath'] as String,
        dataRoot: value['dataRoot'] as String,
        bindAddress: value['bindAddress'] as String,
        port: value['port'] as int,
      );
      _validate(request);
      final stage = NasInstallStage.values.byName(value['stage'] as String);
      _targetIdentity = value['targetIdentity'] as String?;
      _targetCanonicalDataRoot = value['canonicalDataRoot'] as String?;
      final interrupted = value['interruptedStage'] as String?;
      _interruptedStage = interrupted == null
          ? ({
                  NasInstallStage.writing,
                  NasInstallStage.pulling,
                  NasInstallStage.starting,
                }.contains(stage)
                ? stage
                : null)
          : NasInstallStage.values.byName(interrupted);
      _interruptionCode = value['interruptionCode'] as String?;
      // Approval and credentials are never restored. Completed outcomes remain
      // historical outcomes; only an interrupted mutation blocks a new plan.
      if (stage == NasInstallStage.review ||
          stage == NasInstallStage.preflight) {
        return;
      }
      final finished =
          stage == NasInstallStage.succeeded ||
          ((stage == NasInstallStage.failed ||
                  stage == NasInstallStage.cancelled) &&
              value['cleanupComplete'] == true);
      final containerId = value['containerId'] as String?;
      final result = stage == NasInstallStage.succeeded && containerId != null
          ? NasInstallResult(
              containerId: containerId,
              endpoint: _endpoint(request),
              dataRoot: request.dataRoot,
              healthy: true,
            )
          : null;
      _state = NasInstallTask(
        id: value['id'] as String,
        request: request,
        stage: finished ? stage : NasInstallStage.needsInspection,
        startedAt: DateTime.parse(value['startedAt'] as String),
        updatedAt:
            DateTime.tryParse(value['updatedAt'] as String? ?? '') ??
            DateTime.now(),
        errorCode: finished
            ? value['errorCode'] as String?
            : 'NAS_INSTALL_INTERRUPTED',
        result: result,
        cleanupComplete: finished,
        requiresReconciliation: !finished,
      );
      if (!RegExp(r'^[a-f0-9]{48}$').hasMatch(_state!.id)) _state = null;
    } catch (_) {
      // Invalid non-secret cached summaries cannot authorize remote operations.
      _state = null;
    }
  }

  Future<void> _persist() async {
    final state = _state;
    if (state == null || _persistTask == null) return;
    try {
      await _persistTask({
        'id': state.id,
        'serverId': state.request.serverId,
        'serverName': state.request.serverName,
        'product': state.request.product.name,
        'mediaPath': state.request.mediaPath,
        'dataRoot': state.request.dataRoot,
        'bindAddress': state.request.bindAddress,
        'port': state.request.port,
        'stage': state.stage.name,
        'targetIdentity': _targetIdentity,
        'canonicalDataRoot': _targetCanonicalDataRoot,
        'interruptedStage': _interruptedStage?.name,
        'interruptionCode': _interruptionCode,
        'cleanupComplete': state.cleanupComplete,
        'errorCode': state.errorCode,
        'containerId': state.result?.containerId,
        'updatedAt': state.updatedAt.toIso8601String(),
        'startedAt': state.startedAt.toIso8601String(),
      }).timeout(const Duration(seconds: 5));
    } catch (_) {
      throw const NasInstallException('NAS_INSTALL_STATE_SAVE_FAILED');
    }
  }

  void _emit() {
    if (!_disposed) _states.add(_state);
  }

  Future<void> _transition(
    NasInstallStage stage, {
    NasInstallPlan? plan,
    NasInstallResult? result,
    String? errorCode,
    bool? cleanupComplete,
    bool requiresReconciliation = false,
  }) async {
    final previous = _state!;
    _state = NasInstallTask(
      id: previous.id,
      request: previous.request,
      stage: stage,
      startedAt: previous.startedAt,
      updatedAt: DateTime.now(),
      logTail: previous.logTail,
      plan: plan ?? previous.plan,
      result: result,
      errorCode: errorCode,
      cleanupComplete: cleanupComplete,
      requiresReconciliation: requiresReconciliation,
    );
    _emit();
    unawaited(
      AppDiagnostics.instance.record(
        'nas.install',
        jsonEncode({
          'taskId': previous.id,
          'product': previous.request.product.name,
          'stage': stage.name,
          'errorCode': errorCode,
          'blockers': plan?.blockers,
          'cleanupComplete': cleanupComplete,
          'requiresReconciliation': requiresReconciliation,
        }),
      ),
    );
    if (!_state!.isBusy) _ticker?.cancel();
    try {
      await _persist();
    } catch (_) {
      _appendLog('NAS_INSTALL_STATE_SAVE_FAILED\n');
      // Persistence must succeed before a mutation. A disk failure must never
      // suppress rollback, hide its original error, or undo a successful result.
      if (const {
        NasInstallStage.writing,
        NasInstallStage.pulling,
        NasInstallStage.starting,
      }.contains(stage)) {
        rethrow;
      }
    }
  }

  void _begin(String id, NasInstallRequest request) {
    if (_disposed) throw StateError('NAS installer is disposed');
    if (_running || _state?.isBusy == true) {
      throw const NasInstallException('NAS_INSTALL_BUSY');
    }
    if (_state?.requiresReconciliation == true) {
      throw const NasInstallException('NAS_INSTALL_RECONCILIATION_REQUIRED');
    }
    _running = true;
    _connection = _ssh.getClient(request.serverId);
    _pending.clear();
    _targetIdentity = null;
    _targetCanonicalDataRoot = null;
    _cancellation = Completer<void>();
    _interruptedMutation = false;
    _interruptedStage = null;
    _interruptionCode = null;
    _pendingLog = '';
    _state = NasInstallTask(
      id: id,
      request: request,
      stage: NasInstallStage.preflight,
      startedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
    _emit();
  }

  void _checkCancelled() {
    if (_cancellation?.isCompleted == true) {
      throw const NasInstallException('NAS_INSTALL_CANCELLED');
    }
  }

  void _markInterrupted() {
    _interruptedMutation = true;
    _interruptedStage ??= _state?.stage;
  }

  void _checkConnection(String serverId) {
    final current = _ssh.getClient(serverId);
    if (current == null ||
        current.isClosed ||
        !identical(current, _connection)) {
      if (const {
        NasInstallStage.writing,
        NasInstallStage.pulling,
        NasInstallStage.starting,
      }.contains(_state?.stage)) {
        _markInterrupted();
      }
      throw const NasInstallException('NAS_INSTALL_CONNECTION_CHANGED');
    }
  }

  Future<void> cancel() async {
    if (_state?.canCancel != true) return;
    if (!(_cancellation?.isCompleted ?? true)) _cancellation!.complete();
  }

  // Hold incomplete lines so credentials split across SSH packets cannot leak.
  void _appendLog(String chunk, {bool flush = false}) {
    _pendingLog += chunk;
    final end = flush ? _pendingLog.length : _pendingLog.lastIndexOf('\n') + 1;
    if (end == 0) {
      if (_pendingLog.length > maxLogBytes) {
        _pendingLog = '[Oversized output omitted]\n';
      }
      return;
    }
    if (!flush &&
        _pendingLog.contains('-----BEGIN ') &&
        _pendingLog.contains('PRIVATE KEY-----') &&
        !_pendingLog.contains('-----END ')) {
      if (_pendingLog.length > maxLogBytes) {
        _pendingLog = '[Private key output omitted]\n';
      }
      return;
    }
    var text = _pendingLog.substring(0, end);
    _pendingLog = _pendingLog.substring(end);
    if (_secret?.isNotEmpty == true) text = text.replaceAll(_secret!, '******');
    text = LogSanitizer.sanitize(text);
    text = text.replaceAll(
      RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*'),
      '[Private key output omitted]',
    );
    final previous = _state!;
    final bytes = utf8.encode(previous.logTail + text);
    var start = max(0, bytes.length - maxLogBytes);
    while (start < bytes.length && bytes[start] & 0xc0 == 0x80) {
      start++;
    }
    final tail = utf8.decode(bytes.sublist(start), allowMalformed: true);
    _state = NasInstallTask(
      id: previous.id,
      request: previous.request,
      stage: previous.stage,
      startedAt: previous.startedAt,
      updatedAt: DateTime.now(),
      logTail: tail,
      plan: previous.plan,
      result: previous.result,
      errorCode: previous.errorCode,
      cleanupComplete: previous.cleanupComplete,
      requiresReconciliation: previous.requiresReconciliation,
    );
    _emit();
  }

  // Official publisher images. Full version tags are checked with Docker
  // manifest inspect during preview. Digests pin the verified multiarch builds.
  // https://hub.docker.com/r/jellyfin/jellyfin
  // https://hub.docker.com/r/emby/embyserver
  // https://github.com/rclone/rclone/releases/tag/v1.75.0
  static const images = {
    NasInstallProduct.jellyfin:
        'jellyfin/jellyfin:10.11.11@sha256:aefb67e6a7ff1debdd154a78a7bbb780fd0c873d8639210a7f6a2016ad2b35db',
    NasInstallProduct.emby:
        'emby/embyserver:4.10.0.40@sha256:3aafff933d3f28d23ed0bc201022abe71c0aa80deb17177566c726b9bbc686c6',
    NasInstallProduct.webdav: 'rclone/rclone:1.75.0',
  };

  Future<NasInstallPlan> prepare(
    NasInstallRequest request, {
    String? webdavPassword,
  }) async {
    _validate(request);
    if (request.product == NasInstallProduct.webdav &&
        (webdavPassword == null ||
            webdavPassword.length < 12 ||
            RegExp(r'[\r\n\x00]').hasMatch(webdavPassword))) {
      throw const NasInstallException('NAS_INSTALL_PASSWORD_REQUIRED');
    }
    _begin(_token(), request);
    _secret = webdavPassword;
    try {
      final id = _state!.id;
      final name = 'valhalla-nas-${id.substring(0, 12)}';
      final image = images[request.product]!;
      await _persist();
      final check = await _preflight(request, name, image);
      _targetIdentity = check.identity;
      _targetCanonicalDataRoot = check.canonicalDataRoot;
      final plan = NasInstallPlan._(
        id: id,
        request: request,
        pinnedImage: check.image,
        composePreview: _compose(
          request,
          id,
          check.image,
          check.uid,
          check.gid,
        ),
        steps: List.unmodifiable([
          'NAS_INSTALL_CREATE_PRIVATE_DIRECTORY',
          'NAS_INSTALL_WRITE_COMPOSE',
          if (request.product == NasInstallProduct.webdav)
            'NAS_INSTALL_WRITE_PRIVATE_CREDENTIALS',
          'NAS_INSTALL_PULL_PINNED_IMAGE',
          'NAS_INSTALL_START_SERVICE',
          'NAS_INSTALL_CHECK_HTTP',
        ]),
        blockers: List.unmodifiable(check.blockers),
        guidance: List.unmodifiable([
          'https://docs.docker.com/engine/install/',
          'https://docs.docker.com/compose/install/linux/',
          if (request.bindAddress == '127.0.0.1' ||
              request.bindAddress == '::1')
            'NAS_INSTALL_SSH_TUNNEL_REQUIRED',
          if (request.bindAddress != '127.0.0.1' &&
              request.bindAddress != '::1')
            'NAS_INSTALL_TLS_PROXY_RECOMMENDED',
          if (request.product != NasInstallProduct.webdav)
            'NAS_INSTALL_COMPLETE_SERVER_SETUP',
          'NAS_INSTALL_MEDIA_READ_ONLY',
          'NAS_INSTALL_DATA_PRESERVED_ON_FAILURE',
        ]),
        confirmationToken: _token(),
        createdAt: DateTime.now(),
        targetIdentity: check.identity,
      );
      _checkCancelled();
      if (plan.canInstall) _pending[id] = (plan, webdavPassword);
      await _transition(NasInstallStage.review, plan: plan);
      return plan;
    } catch (error) {
      final code = error is NasInstallException
          ? error.code
          : 'NAS_INSTALL_PREFLIGHT_FAILED';
      await _transition(
        code == 'NAS_INSTALL_CANCELLED'
            ? NasInstallStage.cancelled
            : NasInstallStage.failed,
        errorCode: code,
        cleanupComplete: true,
      );
      rethrow;
    } finally {
      _running = false;
    }
  }

  void discard(NasInstallPlan plan) {
    if (_running || _state?.isBusy == true) return;
    _pending.remove(plan.id);
    if (_state?.plan == plan) {
      _state = null;
      _emit();
    }
    _secret = null;
  }

  void dispose() {
    unawaited(cancel());
    _disposed = true;
    _ticker?.cancel();
    _pending.clear();
    _secret = null;
    unawaited(_states.close());
  }

  Future<NasInstallResult> install(
    NasInstallPlan plan, {
    required String confirmationToken,
  }) async {
    if (_running || _state?.isBusy == true) {
      throw const NasInstallException('NAS_INSTALL_BUSY');
    }
    final pending = _pending[plan.id];
    if (pending == null ||
        !identical(pending.$1, plan) ||
        !plan.canInstall ||
        confirmationToken != plan.confirmationToken ||
        DateTime.now().difference(plan.createdAt) >
            const Duration(minutes: 15)) {
      throw const NasInstallException('NAS_INSTALL_CONFIRMATION_REQUIRED');
    }
    _running = true;
    _connection = _ssh.getClient(plan.request.serverId);
    _pending.remove(plan.id);
    _cancellation = Completer<void>();
    _interruptedMutation = false;
    _interruptedStage = null;
    _interruptionCode = null;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
    final request = plan.request;
    var created = false;
    try {
      await _transition(NasInstallStage.preflight);
      final check = await _preflight(
        request,
        plan.containerName,
        plan.pinnedImage,
      );
      if (check.blockers.isNotEmpty || check.identity != plan.targetIdentity) {
        throw const NasInstallException('NAS_INSTALL_PLAN_STALE');
      }
      await _transition(NasInstallStage.writing);
      // mkdir without -p is an atomic reservation, including dangling symlinks.
      await _run(
        request.serverId,
        'umask 077; mkdir -- ${cliShellQuote(request.dataRoot)}',
        'NAS_INSTALL_DIRECTORY_COLLISION',
      );
      created = true;
      await _writePrivateFile(
        request.serverId,
        '${request.dataRoot}/.valhalla-owner',
        plan.id,
      );
      await _run(
        request.serverId,
        'mkdir -- ${cliShellQuote('${request.dataRoot}/config')} ${cliShellQuote('${request.dataRoot}/cache')}',
        'NAS_INSTALL_WRITE_FAILED',
      );
      await _writePrivateFile(
        request.serverId,
        '${request.dataRoot}/compose.json',
        plan.composePreview,
      );
      if (request.product == NasInstallProduct.webdav) {
        await _writePrivateFile(
          request.serverId,
          '${request.dataRoot}/webdav-user',
          request.webdavUser,
        );
        await _writePrivateFile(
          request.serverId,
          '${request.dataRoot}/webdav-password',
          pending.$2!,
        );
      }
      final compose =
          'docker compose --project-name ${cliShellQuote(plan.containerName)} -f ${cliShellQuote('${request.dataRoot}/compose.json')}';
      await _run(
        request.serverId,
        '$compose config --quiet',
        'NAS_INSTALL_COMPOSE_INVALID',
      );
      await _transition(NasInstallStage.pulling);
      await _run(
        request.serverId,
        '$compose pull',
        'NAS_INSTALL_PULL_FAILED',
        timeout: const Duration(minutes: 10),
      );
      await _transition(NasInstallStage.starting);
      await _run(
        request.serverId,
        '$compose up --detach --no-build',
        'NAS_INSTALL_START_FAILED',
        timeout: const Duration(minutes: 3),
      );
      await _transition(NasInstallStage.health);
      final deadline = DateTime.now().add(const Duration(minutes: 2));
      while (DateTime.now().isBefore(deadline)) {
        _checkCancelled();
        final inspected = await _inspect(
          request.serverId,
          plan.containerName,
          deadline: deadline,
        );
        _assertOwned(inspected, plan);
        final state = inspected['State'] as Map?;
        if (state?['Running'] != true) {
          throw const NasInstallException('NAS_INSTALL_SERVICE_EXITED');
        }
        final health = await _command(
          request.serverId,
          "curl --noproxy '*' --silent --output /dev/null --write-out '%{http_code}' --connect-timeout 2 --max-time 5 ${cliShellQuote(_healthEndpoint(request).toString())}",
          timeout: _remaining(deadline, const Duration(seconds: 10)),
        );
        final status = int.tryParse(health.stdout.trim());
        if (health.isSuccess && _isHealthyStatus(request.product, status)) {
          final result = NasInstallResult(
            containerId: inspected['Id'] as String,
            endpoint: _endpoint(request),
            dataRoot: request.dataRoot,
            healthy: true,
          );
          await _transition(
            NasInstallStage.succeeded,
            result: result,
            cleanupComplete: true,
          );
          return result;
        }
        await Future.any([
          Future<void>.delayed(const Duration(seconds: 2)),
          _cancellation!.future,
        ]);
      }
      throw const NasInstallException('NAS_INSTALL_HEALTH_TIMEOUT');
    } catch (error) {
      final code = error is NasInstallException
          ? error.code
          : 'NAS_INSTALL_FAILED';
      if (_interruptedMutation) _interruptionCode = code;
      if (created) await _transition(NasInstallStage.cleanup, errorCode: code);
      final cleaned = !created || await _rollback(plan);
      final certain = cleaned && !_interruptedMutation;
      await _transition(
        !certain
            ? NasInstallStage.needsInspection
            : code == 'NAS_INSTALL_CANCELLED'
            ? NasInstallStage.cancelled
            : NasInstallStage.failed,
        errorCode: code,
        cleanupComplete: certain,
        requiresReconciliation: !certain,
      );
      throw NasInstallException(code, cleanupComplete: certain);
    } finally {
      _appendLog('', flush: true);
      _secret = null;
      _running = false;
    }
  }

  Future<
    ({
      List<String> blockers,
      String identity,
      String canonicalDataRoot,
      int uid,
      int gid,
      String image,
    })
  >
  _preflight(NasInstallRequest request, String name, String image) async {
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    final blockers = <String>[];
    var identity = '';
    var canonicalDataRoot = '';
    var uid = 1000;
    var gid = 1000;
    if (!_ssh.isConnected(request.serverId)) {
      return (
        blockers: ['NAS_INSTALL_SSH_REQUIRED'],
        identity: identity,
        canonicalDataRoot: canonicalDataRoot,
        uid: uid,
        gid: gid,
        image: image,
      );
    }
    Future<String?> probe(String command, String code) async {
      try {
        final result = await _command(
          request.serverId,
          command,
          timeout: _remaining(deadline, const Duration(seconds: 30)),
          logOutput: false,
        );
        if (result.isSuccess) return result.stdout.trim();
        _appendLog('$code: ${result.stderr.trim()}\n');
      } on NasInstallException catch (error) {
        if (error.code == 'NAS_INSTALL_CANCELLED' ||
            error.code == 'NAS_INSTALL_DEADLINE_EXCEEDED') {
          rethrow;
        }
        _appendLog('$code: $error\n');
      } catch (error) {
        // Preserve the cause of a failed prerequisite without logging identities.
        _appendLog('$code: $error\n');
      }
      _checkCancelled();
      blockers.add(code);
      return null;
    }

    if (await probe('uname -s', 'NAS_INSTALL_LINUX_REQUIRED') != 'Linux') {
      if (!blockers.contains('NAS_INSTALL_LINUX_REQUIRED')) {
        blockers.add('NAS_INSTALL_LINUX_REQUIRED');
      }
      return (
        blockers: blockers,
        identity: identity,
        canonicalDataRoot: canonicalDataRoot,
        uid: uid,
        gid: gid,
        image: image,
      );
    }
    final docker = await probe(
      "docker info --format '{{.ID}}'",
      'NAS_INSTALL_DOCKER_REQUIRED',
    );
    final dockerEndpoint = await probe(
      r'''test -z "${DOCKER_HOST-}" && test -z "${DOCKER_CONTEXT-}" && docker context inspect --format '{{.Endpoints.docker.Host}}' ''',
      'NAS_INSTALL_LOCAL_DOCKER_REQUIRED',
    );
    if (dockerEndpoint != null && !dockerEndpoint.startsWith('unix:///')) {
      blockers.add('NAS_INSTALL_LOCAL_DOCKER_REQUIRED');
    }
    await probe(
      'docker compose version --short',
      'NAS_INSTALL_COMPOSE_REQUIRED',
    );
    final host = await probe(
      'cat /etc/machine-id',
      'NAS_INSTALL_IDENTITY_UNAVAILABLE',
    );
    if (docker != null &&
        host != null &&
        docker.isNotEmpty &&
        host.isNotEmpty) {
      identity = '$host:$docker';
    }
    if (identity.isEmpty &&
        !blockers.contains('NAS_INSTALL_IDENTITY_UNAVAILABLE')) {
      blockers.add('NAS_INSTALL_IDENTITY_UNAVAILABLE');
    }
    uid =
        int.tryParse(
          await probe('id -u', 'NAS_INSTALL_IDENTITY_UNAVAILABLE') ?? '',
        ) ??
        uid;
    gid =
        int.tryParse(
          await probe('id -g', 'NAS_INSTALL_IDENTITY_UNAVAILABLE') ?? '',
        ) ??
        gid;
    await probe(
      'command -v curl && command -v ss && command -v realpath',
      'NAS_INSTALL_TOOLS_REQUIRED',
    );
    final media = await probe(
      'test -d ${cliShellQuote(request.mediaPath)} && test -r ${cliShellQuote(request.mediaPath)} && realpath -- ${cliShellQuote(request.mediaPath)}',
      'NAS_INSTALL_MEDIA_UNREADABLE',
    );
    final parent = path.posix.dirname(request.dataRoot);
    final actualParent = await probe(
      'test -d ${cliShellQuote(parent)} && test -w ${cliShellQuote(parent)} && realpath -- ${cliShellQuote(parent)}',
      'NAS_INSTALL_PARENT_UNWRITABLE',
    );
    if (media != null && actualParent != null) {
      final data = path.posix.join(
        actualParent,
        path.posix.basename(request.dataRoot),
      );
      canonicalDataRoot = data;
      if (_overlap(media, data)) blockers.add('NAS_INSTALL_MEDIA_DATA_OVERLAP');
      identity = '$identity:$media:$data:$uid:$gid';
    }
    await probe(
      'test ! -e ${cliShellQuote(request.dataRoot)} && test ! -L ${cliShellQuote(request.dataRoot)}',
      'NAS_INSTALL_DIRECTORY_COLLISION',
    );
    final ports = await probe(
      "ss -H -ltn ${cliShellQuote('sport = :${request.port}')}",
      'NAS_INSTALL_PORT_CHECK_FAILED',
    );
    if (ports?.isNotEmpty ?? false) blockers.add('NAS_INSTALL_PORT_IN_USE');
    if (docker != null) {
      final names = await probe(
        "docker ps -a --filter ${cliShellQuote('name=^/$name\$')} --format '{{.Names}}'",
        'NAS_INSTALL_CONTAINER_CHECK_FAILED',
      );
      if (names?.isNotEmpty ?? false) {
        blockers.add('NAS_INSTALL_CONTAINER_COLLISION');
      }
      final manifest = await probe(
        'docker manifest inspect ${cliShellQuote(image)}',
        'NAS_INSTALL_IMAGE_UNAVAILABLE',
      );
      if (!image.contains('@sha256:') && manifest != null) {
        final machine = await probe(
          'uname -m',
          'NAS_INSTALL_IMAGE_UNAVAILABLE',
        );
        final arch = switch (machine) {
          'x86_64' => 'amd64',
          'aarch64' => 'arm64',
          'armv7l' => 'arm',
          'armv6l' => 'arm',
          'i686' => '386',
          _ => machine,
        };
        try {
          final manifests = (jsonDecode(manifest) as Map)['manifests'] as List;
          final entry = manifests.cast<Map>().firstWhere((entry) {
            final platform = entry['platform'] as Map?;
            return platform?['os'] == 'linux' &&
                platform?['architecture'] == arch &&
                (machine != 'armv7l' || platform?['variant'] == 'v7') &&
                (machine != 'armv6l' || platform?['variant'] == 'v6');
          });
          final digest = entry['digest'] as String;
          if (!RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(digest)) {
            throw const FormatException();
          }
          // A tag resolves the multiarch index, not this platform manifest.
          // Docker 29 verifies repo@digest correctly but rejects tag@platformDigest.
          image = '${image.substring(0, image.lastIndexOf(':'))}@$digest';
        } catch (_) {
          blockers.add('NAS_INSTALL_IMAGE_UNAVAILABLE');
        }
      }
    }
    return (
      blockers: blockers,
      identity: identity,
      canonicalDataRoot: canonicalDataRoot,
      uid: uid,
      gid: gid,
      image: image,
    );
  }

  static Duration _remaining(DateTime deadline, Duration maximum) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw const NasInstallException('NAS_INSTALL_DEADLINE_EXCEEDED');
    }
    return remaining < maximum ? remaining : maximum;
  }

  Future<T> _interruptible<T>(
    Future<T> work,
    Duration timeout, {
    bool mutation = false,
  }) async {
    try {
      return await Future.any<T>([
        work,
        _cancellation!.future.then<T>(
          (_) => throw const NasInstallException('NAS_INSTALL_CANCELLED'),
        ),
      ]).timeout(timeout);
    } on TimeoutException {
      if (mutation) _markInterrupted();
      throw const NasInstallException('NAS_INSTALL_COMMAND_TIMEOUT');
    } on NasInstallException catch (error) {
      if (mutation && error.code == 'NAS_INSTALL_CANCELLED') {
        _markInterrupted();
      }
      rethrow;
    }
  }

  static void _closePrivateSession(
    SSHSession session, {
    required bool terminate,
  }) {
    if (terminate) {
      try {
        session.kill(SSHSignal.TERM);
      } finally {
        session.channel.destroy();
      }
    } else {
      session.close();
    }
  }

  Future<void> _writePrivateFile(
    String serverId,
    String target,
    String value,
  ) async {
    _checkCancelled();
    _checkConnection(serverId);
    final client = _ssh.getClient(serverId);
    if (client == null || client.isClosed) {
      throw const NasInstallException('NAS_INSTALL_SSH_REQUIRED');
    }
    var abandoned = false;
    final opening = client.execute(
      'umask 077; set -C; cat > ${cliShellQuote(target)}',
    );
    // A channel can arrive after cancellation/timeout. It still needs closing.
    unawaited(
      opening.then<void>((session) {
        if (abandoned) {
          try {
            _closePrivateSession(session, terminate: true);
          } catch (_) {
            /* The channel may already be closed after disconnect. */
          }
        }
      }, onError: (Object _, StackTrace _) {}),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    try {
      final session = await _interruptible(
        opening,
        const Duration(seconds: 30),
        mutation: true,
      );
      var completed = false;
      try {
        final output = Future.wait([
          session.stdout.drain<void>(),
          session.stderr.drain<void>(),
        ]);
        session.stdin.add(Uint8List.fromList(utf8.encode(value)));
        await _interruptible(
          Future.wait([session.stdin.close(), session.done, output]),
          _remaining(deadline, const Duration(seconds: 30)),
          mutation: true,
        );
        completed = true;
        if (session.exitCode != 0) {
          throw const NasInstallException('NAS_INSTALL_WRITE_FAILED');
        }
      } finally {
        try {
          _closePrivateSession(session, terminate: !completed);
        } catch (_) {
          /* Preserve the original write/cancellation outcome. */
        }
      }
    } finally {
      abandoned = true;
    }
  }

  Future<SSHExecutionResult> _command(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    bool logOutput = true,
  }) async {
    _checkCancelled();
    _checkConnection(serverId);
    final done = Completer<void>();
    final out = StringBuffer(), err = StringBuffer();
    var code = -1;
    final subscription = _ssh
        .executeStreaming(serverId, command, timeout: timeout)
        .listen(
          (chunk) {
            if (chunk.exitCode != null) code = chunk.exitCode!;
            final buffer = chunk.kind == SSHStreamKind.stdout ? out : err;
            // Read-only JSON/probe responses are capped too; installer output cannot exhaust RAM.
            if (buffer.length < maxLogBytes) {
              buffer.write(
                chunk.text.substring(
                  0,
                  min(chunk.text.length, maxLogBytes - buffer.length),
                ),
              );
            }
            if (logOutput) _appendLog(chunk.text);
          },
          onError: (Object error, StackTrace stack) {
            if (!done.isCompleted) done.completeError(error, stack);
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );
    final mutation = const {
      NasInstallStage.writing,
      NasInstallStage.pulling,
      NasInstallStage.starting,
    }.contains(_state?.stage);
    try {
      await _interruptible(done.future, timeout, mutation: mutation);
      _checkCancelled();
      _checkConnection(serverId);
      if (code < 0) {
        if (mutation) _markInterrupted();
        throw const NasInstallException('NAS_INSTALL_COMMAND_RESULT_UNKNOWN');
      }
      return SSHExecutionResult(
        exitCode: code,
        stdout: out.toString(),
        stderr: err.toString(),
      );
    } catch (_) {
      if (mutation && code < 0) _markInterrupted();
      rethrow;
    } finally {
      await subscription.cancel();
      if (logOutput) _appendLog('', flush: true);
    }
  }

  Future<Map<String, dynamic>> _inspect(
    String serverId,
    String name, {
    DateTime? deadline,
  }) async {
    final result = await _command(
      serverId,
      'docker inspect ${cliShellQuote(name)}',
      timeout: deadline == null
          ? const Duration(seconds: 30)
          : _remaining(deadline, const Duration(seconds: 30)),
      logOutput: false,
    );
    if (!result.isSuccess) {
      throw const NasInstallException('NAS_INSTALL_INSPECT_FAILED');
    }
    return Map<String, dynamic>.from(
      (jsonDecode(result.stdout) as List).single as Map,
    );
  }

  Future<void> _run(
    String serverId,
    String command,
    String code, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final result = await _command(serverId, command, timeout: timeout);
    if (!result.isSuccess) throw NasInstallException(code);
  }

  /// Read-only recovery. No password, confirmation token or remote mutation is restored.
  Future<void> reconcile() async {
    final old = _state;
    if (old == null || old.isBusy || _running) return;
    _running = true;
    _connection = _ssh.getClient(old.request.serverId);
    _cancellation = Completer<void>();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _emit());
    await _transition(NasInstallStage.reconciling);
    try {
      final serverId = old.request.serverId;
      final identity = await _command(
        serverId,
        'cat /etc/machine-id',
        logOutput: false,
      );
      if (!identity.isSuccess || identity.stdout.trim().isEmpty) {
        throw const NasInstallException('NAS_INSTALL_SSH_REQUIRED');
      }
      final dockerIdentity = await _command(
        serverId,
        "docker info --format '{{.ID}}'",
        logOutput: false,
      );
      final expected = _targetIdentity;
      if (!dockerIdentity.isSuccess ||
          expected == null ||
          !expected.startsWith(
            '${identity.stdout.trim()}:${dockerIdentity.stdout.trim()}:',
          )) {
        throw const NasInstallException('NAS_INSTALL_PLAN_STALE');
      }
      Map<String, dynamic> inspected;
      try {
        inspected = await _inspect(
          serverId,
          'valhalla-nas-${old.id.substring(0, 12)}',
        );
      } on NasInstallException catch (error) {
        if (error.code != 'NAS_INSTALL_INSPECT_FAILED') rethrow;
        if (!await _confirmNoOwnedResources(old)) {
          throw const NasInstallException(
            'NAS_INSTALL_REMOTE_INSPECTION_REQUIRED',
          );
        }
        final cause =
            _interruptionCode ?? old.errorCode ?? 'NAS_INSTALL_INTERRUPTED';
        await _transition(
          cause == 'NAS_INSTALL_CANCELLED'
              ? NasInstallStage.cancelled
              : NasInstallStage.failed,
          errorCode: cause,
          cleanupComplete: true,
        );
        return;
      }
      final labels = (inspected['Config'] as Map?)?['Labels'] as Map?;
      if (labels?['com.valhalla.nas.install'] != old.id) {
        throw const NasInstallException('NAS_INSTALL_OWNERSHIP_CHANGED');
      }
      final health = await _command(
        serverId,
        "curl --noproxy '*' --silent --output /dev/null --write-out '%{http_code}' --connect-timeout 2 --max-time 5 ${cliShellQuote(_healthEndpoint(old.request).toString())}",
        timeout: const Duration(seconds: 10),
        logOutput: false,
      );
      final status = int.tryParse(health.stdout.trim());
      if ((inspected['State'] as Map?)?['Running'] == true &&
          health.isSuccess &&
          _isHealthyStatus(old.request.product, status)) {
        await _transition(
          NasInstallStage.succeeded,
          result: NasInstallResult(
            containerId: inspected['Id'] as String,
            endpoint: _endpoint(old.request),
            dataRoot: old.request.dataRoot,
            healthy: true,
          ),
          cleanupComplete: true,
        );
      } else {
        await _transition(
          NasInstallStage.needsInspection,
          errorCode: 'NAS_INSTALL_REMOTE_INSPECTION_REQUIRED',
          cleanupComplete: false,
        );
      }
    } catch (error) {
      await _transition(
        NasInstallStage.needsInspection,
        errorCode: error is NasInstallException
            ? error.code
            : 'NAS_INSTALL_RECONCILIATION_FAILED',
        cleanupComplete: false,
        requiresReconciliation: !_ssh.isConnected(old.request.serverId),
      );
    } finally {
      _running = false;
    }
  }

  Future<bool> _confirmNoOwnedResources(NasInstallTask task) async {
    // During pull, previous file writes have completed and Docker cannot create
    // a container. Writing/starting may still complete a late channel/request,
    // so a single snapshot cannot establish that their mutations have stopped.
    if (_interruptedStage != NasInstallStage.pulling) {
      return false;
    }
    final serverId = task.request.serverId;
    final name = 'valhalla-nas-${task.id.substring(0, 12)}';
    final listed = await _command(
      serverId,
      "docker ps -a --filter ${cliShellQuote('name=^/$name\$')} --format '{{.Names}}'",
      logOutput: false,
    );
    if (!listed.isSuccess || listed.stdout.trim().isNotEmpty) return false;
    final root = task.request.dataRoot;
    final parent = path.posix.dirname(root);
    final canonicalParent = await _command(
      serverId,
      'test -d ${cliShellQuote(parent)} && test -x ${cliShellQuote(parent)} && realpath -- ${cliShellQuote(parent)}',
      logOutput: false,
    );
    if (!canonicalParent.isSuccess ||
        _targetCanonicalDataRoot == null ||
        path.posix.join(
              canonicalParent.stdout.trim(),
              path.posix.basename(root),
            ) !=
            _targetCanonicalDataRoot) {
      return false;
    }
    final files = [
      'compose.json',
      'webdav-user',
      'webdav-password',
      '.valhalla-owner',
    ];
    final absent = await _command(
      serverId,
      'test ! -L ${cliShellQuote(root)} && '
      '(test ! -e ${cliShellQuote(root)} || (test -d ${cliShellQuote(root)} && test -x ${cliShellQuote(root)})) && '
      '${files.map((file) => 'test ! -e ${cliShellQuote('$root/$file')} && test ! -L ${cliShellQuote('$root/$file')}').join(' && ')}',
      logOutput: false,
    );
    if (!absent.isSuccess) return false;
    // Full command lines are inspected remotely, never logged. Exclude only
    // this probe's process tree, not commands belonging to the interrupted task.
    // pipefail + the nonempty snapshot check prevent a broken `ps` reporting idle.
    final processes = await _command(
      serverId,
      'set -o pipefail; command -v ps >/dev/null && command -v awk >/dev/null || exit 2; '
      'export VALHALLA_RECONCILE_PROJECT=${cliShellQuote(name)} VALHALLA_RECONCILE_PATH=${cliShellQuote(root)}; '
      r'''ps -ww -eo pid=,ppid=,args= | awk -v root="$$" '
{ parent[$1]=$2; line[$1]=$0; count++ }
END {
  if (!count) exit 2;
  for (pid in line) {
    ancestor=pid; depth=0;
    while (ancestor in parent && ancestor != root && depth++ < 1000) ancestor=parent[ancestor];
    if (ancestor == root) continue;
    if (index(line[pid], ENVIRON["VALHALLA_RECONCILE_PROJECT"]) || index(line[pid], ENVIRON["VALHALLA_RECONCILE_PATH"])) {
      print "BUSY"; exit;
    }
  }
  print "IDLE";
}' ''',
      logOutput: false,
    );
    return processes.isSuccess && processes.stdout.trim() == 'IDLE';
  }

  Future<bool> _rollback(NasInstallPlan plan) async {
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    try {
      _checkConnection(plan.request.serverId);
      final listed = await _docker
          .listContainers(plan.request.serverId)
          .timeout(_remaining(deadline, const Duration(seconds: 30)));
      for (final container in listed.where(
        (item) => item.name == plan.containerName,
      )) {
        _checkConnection(plan.request.serverId);
        final inspected = await _docker
            .inspect(plan.request.serverId, container.id)
            .timeout(_remaining(deadline, const Duration(seconds: 30)));
        _assertOwned(inspected, plan);
        if ((inspected['State'] as Map?)?['Running'] == true) {
          _checkConnection(plan.request.serverId);
          final stopped = await _docker
              .lifecycle(plan.request.serverId, 'stop', container.id)
              .timeout(_remaining(deadline, const Duration(seconds: 30)));
          if (!stopped.isSuccess) return false;
        }
        _checkConnection(plan.request.serverId);
        final removed = await _docker
            .lifecycle(plan.request.serverId, 'rm', container.id)
            .timeout(_remaining(deadline, const Duration(seconds: 30)));
        if (!removed.isSuccess) return false;
      }
      final root = plan.request.dataRoot;
      final files = [
        'compose.json',
        'webdav-user',
        'webdav-password',
        '.valhalla-owner',
      ];
      _checkConnection(plan.request.serverId);
      final cleanup = await _ssh
          .executeWithLoginShell(
            plan.request.serverId,
            'test ! -L ${cliShellQuote(root)} && test "\$(cat ${cliShellQuote('$root/.valhalla-owner')})" = ${cliShellQuote(plan.id)} && rm -f -- ${files.map((name) => cliShellQuote('$root/$name')).join(' ')}',
            timeout: _remaining(deadline, const Duration(seconds: 30)),
          )
          .timeout(_remaining(deadline, const Duration(seconds: 30)));
      return cleanup.isSuccess;
    } catch (_) {
      return false;
    }
  }

  static void _assertOwned(
    Map<String, dynamic> inspected,
    NasInstallPlan plan,
  ) {
    final labels = (inspected['Config'] as Map?)?['Labels'] as Map?;
    if (labels?['com.valhalla.nas.install'] != plan.id) {
      throw const NasInstallException('NAS_INSTALL_OWNERSHIP_CHANGED');
    }
  }

  static String _compose(
    NasInstallRequest request,
    String id,
    String image,
    int uid,
    int gid,
  ) {
    String literal(String value) => value.replaceAll(r'$', r'$$');
    Map<String, dynamic> mount(
      String source,
      String target, {
      bool readOnly = false,
    }) => {
      'type': 'bind',
      'source': literal(source),
      'target': target,
      'read_only': readOnly,
      'bind': {'create_host_path': false},
    };
    final webdav = request.product == NasInstallProduct.webdav;
    final service = <String, dynamic>{
      'image': image,
      'container_name': 'valhalla-nas-${id.substring(0, 12)}',
      'restart': 'unless-stopped',
      'network_mode': 'bridge',
      'labels': {'com.valhalla.nas.install': id},
      'ports': [
        {
          'target': webdav ? 8080 : 8096,
          'published': request.port.toString(),
          'host_ip': request.bindAddress,
          'protocol': 'tcp',
        },
      ],
      'volumes': [
        mount(request.mediaPath, '/media', readOnly: true),
        mount('${request.dataRoot}/config', '/config'),
        mount('${request.dataRoot}/cache', '/cache'),
        if (webdav) ...[
          mount(
            '${request.dataRoot}/webdav-user',
            '/run/secrets/webdav-user',
            readOnly: true,
          ),
          mount(
            '${request.dataRoot}/webdav-password',
            '/run/secrets/webdav-password',
            readOnly: true,
          ),
        ],
      ],
      if (request.product != NasInstallProduct.emby) 'user': '$uid:$gid',
      if (request.product == NasInstallProduct.emby)
        'environment': {'UID': uid.toString(), 'GID': gid.toString()},
      if (webdav) 'entrypoint': ['/bin/sh', '-c'],
      if (webdav)
        'command': [
          r'export RCLONE_USER="$$(cat /run/secrets/webdav-user)" RCLONE_PASS="$$(cat /run/secrets/webdav-password)"; exec rclone serve webdav /media --addr :8080 --read-only --vfs-cache-mode off',
        ],
    };
    return const JsonEncoder.withIndent('  ').convert({
      'services': {'nas': service},
    });
  }

  static Uri _endpoint(NasInstallRequest request) => Uri(
    scheme: 'http',
    host: request.bindAddress == '0.0.0.0'
        ? '127.0.0.1'
        : request.bindAddress == '::'
        ? '::1'
        : request.bindAddress,
    port: request.port,
    path: '/',
  );

  static Uri _healthEndpoint(NasInstallRequest request) =>
      _endpoint(request).replace(
        path: switch (request.product) {
          NasInstallProduct.jellyfin => '/health',
          NasInstallProduct.emby => '/System/Info/Public',
          NasInstallProduct.webdav => '/',
        },
      );

  static bool _isHealthyStatus(NasInstallProduct product, int? status) =>
      switch (product) {
        NasInstallProduct.webdav => status == 401,
        NasInstallProduct.emby => status == 200,
        NasInstallProduct.jellyfin =>
          status != null && status >= 200 && status < 400,
      };

  static void _validate(NasInstallRequest request) {
    for (final value in [request.mediaPath, request.dataRoot]) {
      cliShellQuote(value);
      if (!value.startsWith('/') ||
          value == '/' ||
          path.posix.normalize(value) != value) {
        throw const NasInstallException('NAS_INSTALL_ABSOLUTE_PATH_REQUIRED');
      }
    }
    if (_overlap(request.mediaPath, request.dataRoot)) {
      throw const NasInstallException('NAS_INSTALL_MEDIA_DATA_OVERLAP');
    }
    if (request.port < 1 ||
        request.port > 65535 ||
        InternetAddress.tryParse(request.bindAddress) == null) {
      throw const NasInstallException('NAS_INSTALL_ADDRESS_INVALID');
    }
    if (request.serverId.isEmpty ||
        request.webdavUser.isEmpty ||
        RegExp(r'[\r\n\x00:]').hasMatch(request.webdavUser)) {
      throw const NasInstallException('NAS_INSTALL_REQUEST_INVALID');
    }
  }

  static bool _overlap(String a, String b) =>
      a == b || path.posix.isWithin(a, b) || path.posix.isWithin(b, a);
  static String _token() => List.generate(
    24,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
