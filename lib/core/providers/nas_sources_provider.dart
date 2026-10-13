import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/nas_source.dart';
import '../../data/models/remote_browser.dart';
import '../../infrastructure/nas/nas_http_client.dart';
import '../../infrastructure/nas/nas_media_server_adapter.dart';
import '../../infrastructure/nas/nas_sftp_adapter.dart';
import '../../infrastructure/nas/nas_smb_adapter.dart';
import '../../infrastructure/nas/nas_webdav_adapter.dart';
import '../../infrastructure/nas/nas_ssh_tunnel_service.dart';
import '../../infrastructure/ssh/ssh_client_manager.dart';
import 'infrastructure_providers.dart';
import 'server_provider.dart';
import 'storage_providers.dart';

enum NasConnectionStage { credentials, tunnel, checking, ready, failed }

String _diagnosticKey(NasSource source) => sha256
    .convert(utf8.encode(jsonEncode(source.toJson()..remove('name'))))
    .toString();

bool _sameCredentialTarget(NasSource a, NasSource b) =>
    a.id == b.id &&
    a.type == b.type &&
    a.endpoint == b.endpoint &&
    a.username == b.username &&
    a.userId == b.userId &&
    a.sshServerId == b.sshServerId;

class NasConnectionDiagnostic {
  final String sourceId;
  final NasConnectionStage stage;
  final DateTime updatedAt;
  final DateTime? lastSuccess;
  final String? errorCode;
  final int? httpStatus;
  const NasConnectionDiagnostic({
    required this.sourceId,
    required this.stage,
    required this.updatedAt,
    this.lastSuccess,
    this.errorCode,
    this.httpStatus,
  });

  // Deliberately excludes endpoints, usernames, credentials and response bodies.
  String get diagnosticText => [
    'stage: ${stage.name}',
    'updatedAt: ${updatedAt.toUtc().toIso8601String()}',
    if (lastSuccess != null)
      'lastSuccess: ${lastSuccess!.toUtc().toIso8601String()}',
    if (errorCode != null) 'error: $errorCode',
    if (httpStatus != null) 'httpStatus: $httpStatus',
  ].join('\n');
}

class NasSourcesState {
  final List<NasSource> sources;
  final String? selectedId;
  final Map<String, NasConnectionDiagnostic> diagnostics;
  const NasSourcesState({
    this.sources = const [],
    this.selectedId,
    this.diagnostics = const {},
  });
  NasConnectionDiagnostic? diagnosticFor(NasSource source) =>
      diagnostics[_diagnosticKey(source)];
  NasSource? get selected =>
      sources.where((s) => s.id == selectedId).firstOrNull;
}

final nasSourcesProvider =
    NotifierProvider<NasSourcesNotifier, NasSourcesState>(
      NasSourcesNotifier.new,
    );

class NasSourcesNotifier extends Notifier<NasSourcesState> {
  Future<void> _mutations = Future.value();
  final _probeRuns = <String, Object>{};
  final _credentialGenerations = <String, int>{};
  final _incompleteSaves = <String>{};
  Future<void> _mutate(Future<void> Function() action) {
    final next = _mutations.then((_) => action());
    _mutations = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  @override
  NasSourcesState build() {
    final storage = ref.watch(localStorageServiceProvider);
    final sources = storage.getNasSources();
    final selected = storage.getNasSelectedSourceId();
    ref.listen(serverListProvider, (previous, next) {
      if (previous == null) return;
      final oldTargets = {
        for (final server in previous) server.id: server.connectionKey,
      };
      final newTargets = {
        for (final server in next) server.id: server.connectionKey,
      };
      final changed = {
        ...oldTargets.keys,
        ...newTargets.keys,
      }.where((id) => oldTargets[id] != newTargets[id]).toSet();
      final affected = state.sources
          .where((source) => changed.contains(source.sshServerId))
          .map((source) => source.id)
          .toSet();
      if (affected.isEmpty) return;
      for (final id in affected) {
        _probeRuns.remove(id);
      }
      state = NasSourcesState(
        sources: state.sources,
        selectedId: state.selectedId,
        diagnostics: Map.unmodifiable(
          {...state.diagnostics}
            ..removeWhere((_, value) => affected.contains(value.sourceId)),
        ),
      );
    });
    return NasSourcesState(
      sources: sources,
      selectedId: sources.any((s) => s.id == selected)
          ? selected
          : sources.firstOrNull?.id,
    );
  }

  Future<void> select(String id) => _mutate(() => _select(id));
  Future<void> _select(String id) async {
    if (!state.sources.any((s) => s.id == id)) {
      throw ArgumentError('NAS_SOURCE_NOT_FOUND');
    }
    await ref.read(localStorageServiceProvider).saveNasSelectedSourceId(id);
    state = NasSourcesState(
      sources: state.sources,
      selectedId: id,
      diagnostics: state.diagnostics,
    );
  }

  Future<void> save(
    NasSource source,
    NasCredentials credentials, {
    bool probe = true,
    bool keepEmptySecrets = false,
  }) => _mutate(
    () => _save(
      source,
      credentials,
      probe: probe,
      keepEmptySecrets: keepEmptySecrets,
    ),
  );

  Future<void> _save(
    NasSource source,
    NasCredentials credentials, {
    required bool probe,
    required bool keepEmptySecrets,
  }) async {
    if (source.id.isEmpty || source.name.trim().isEmpty) {
      throw const FormatException('NAS_SOURCE_NAME_REQUIRED');
    }
    if (source.type != NasSourceType.sftp) {
      final uri = Uri.tryParse(source.endpoint);
      final schemes = source.type == NasSourceType.smb
          ? ['smb']
          : ['http', 'https'];
      if (uri == null ||
          !schemes.contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment) {
        throw const FormatException('NAS_INVALID_ENDPOINT');
      }
    }
    credentials = await _credentials(source, credentials, keepEmptySecrets);
    if (probe) await this.probe(source, credentials);
    if (source.type != NasSourceType.sftp) {
      await ref
          .read(secureStorageServiceProvider)
          .saveNasCredentials(source.id, credentials);
      _credentialGenerations[source.id] =
          (_credentialGenerations[source.id] ?? 0) + 1;
      _incompleteSaves.add(source.id);
    }
    // A fresh snapshot also refreshes the adapter when only credentials changed.
    final saved = NasSource.fromJson(source.toJson());
    final sources = [...state.sources.where((s) => s.id != source.id), saved];
    await ref.read(localStorageServiceProvider).saveNasSources(sources);
    await ref
        .read(localStorageServiceProvider)
        .saveNasSelectedSourceId(source.id);
    _probeRuns.remove(source.id);
    final diagnostics = {...state.diagnostics};
    final key = _diagnosticKey(source);
    diagnostics.removeWhere(
      (entryKey, value) =>
          value.sourceId == source.id && (!probe || entryKey != key),
    );
    state = NasSourcesState(
      sources: sources,
      selectedId: source.id,
      diagnostics: diagnostics,
    );
    _incompleteSaves.remove(source.id);
  }

  Future<NasCredentials> _credentials(
    NasSource source,
    NasCredentials credentials,
    bool keepEmptySecrets,
  ) async {
    final saved = state.sources.where((s) => s.id == source.id).firstOrNull;
    final generation = _credentialGenerations[source.id];
    if (keepEmptySecrets &&
        source.type != NasSourceType.sftp &&
        saved != null &&
        _sameCredentialTarget(source, saved)) {
      if (_incompleteSaves.contains(source.id)) {
        throw StateError('NAS_SOURCE_SAVE_INCOMPLETE');
      }
      final old = await ref
          .read(secureStorageServiceProvider)
          .getNasCredentials(source.id);
      if (!ref.mounted) throw StateError('NAS_SOURCE_CHANGED');
      final current = state.sources.where((s) => s.id == source.id).firstOrNull;
      if (!identical(current, saved) ||
          _credentialGenerations[source.id] != generation) {
        throw StateError('NAS_SOURCE_CHANGED');
      }
      if (source.type == NasSourceType.smb &&
          old.domain != credentials.domain) {
        return credentials;
      }
      credentials = NasCredentials(
        password: credentials.password.isEmpty
            ? old.password
            : credentials.password,
        token: credentials.token.isEmpty ? old.token : credentials.token,
        domain: credentials.domain,
      );
    }
    return credentials;
  }

  Future<RemoteBrowserSource> openSavedBrowser(
    NasSource source, {
    bool Function()? isCurrent,
  }) async {
    if (_incompleteSaves.contains(source.id)) {
      throw StateError('NAS_SOURCE_SAVE_INCOMPLETE');
    }
    final key = _diagnosticKey(source);
    final saved = state.sources
        .where((value) => _diagnosticKey(value) == key)
        .firstOrNull;
    final generation = _credentialGenerations[source.id];
    bool current() =>
        ref.mounted &&
        (isCurrent?.call() ?? true) &&
        !_incompleteSaves.contains(source.id) &&
        _credentialGenerations[source.id] == generation &&
        saved != null &&
        state.sources.any((value) => identical(value, saved));
    if (!current()) throw StateError('NAS_SOURCE_CHANGED');
    final credentials = source.type == NasSourceType.sftp
        ? const NasCredentials()
        : await ref
              .read(secureStorageServiceProvider)
              .getNasCredentials(source.id);
    if (!current()) throw StateError('NAS_SOURCE_CHANGED');
    return openBrowser(source, credentials, isCurrent: current);
  }

  /// Loads the non-secret edit field; blank can subsequently mean explicit clear.
  Future<String> savedDomain(NasSource source) async {
    if (_incompleteSaves.contains(source.id)) {
      throw StateError('NAS_SOURCE_SAVE_INCOMPLETE');
    }
    final saved = state.sources.where((s) => s.id == source.id).firstOrNull;
    final generation = _credentialGenerations[source.id];
    if (source.type != NasSourceType.smb ||
        saved == null ||
        !_sameCredentialTarget(source, saved)) {
      return '';
    }
    final credentials = await ref
        .read(secureStorageServiceProvider)
        .getNasCredentials(source.id);
    if (!ref.mounted) throw StateError('NAS_SOURCE_CHANGED');
    final current = state.sources.where((s) => s.id == source.id).firstOrNull;
    if (!identical(current, saved) ||
        _credentialGenerations[source.id] != generation) {
      throw StateError('NAS_SOURCE_CHANGED');
    }
    return credentials.domain;
  }

  /// Isolated, read-only browsing of either a saved source or an unsaved draft.
  Future<RemoteBrowserSource> openBrowser(
    NasSource source,
    NasCredentials credentials, {
    bool keepEmptySecrets = false,
    bool Function()? isCurrent,
  }) async {
    if (_incompleteSaves.contains(source.id)) {
      throw StateError('NAS_SOURCE_SAVE_INCOMPLETE');
    }
    final saved = state.sources.where((s) => s.id == source.id).firstOrNull;
    final generation = _credentialGenerations[source.id];
    final ssh = ref.read(sshCommandExecutorProvider);
    final serverId = source.type == NasSourceType.sftp
        ? source.sshServerId ?? source.id
        : source.type == NasSourceType.smb
        ? null
        : source.sshServerId;
    final client = serverId == null ? null : ssh.getClient(serverId);
    final serverKey = serverId == null
        ? null
        : ref
              .read(serverListProvider)
              .where((server) => server.id == serverId)
              .firstOrNull
              ?.connectionKey;
    if (serverId != null && serverKey == null) {
      throw StateError('NAS_SSH_SERVER_NOT_FOUND');
    }
    bool current() {
      if (!ref.mounted ||
          !(isCurrent?.call() ?? true) ||
          _incompleteSaves.contains(source.id) ||
          _credentialGenerations[source.id] != generation) {
        return false;
      }
      final nowSaved = state.sources
          .where((s) => s.id == source.id)
          .firstOrNull;
      // Saves replace the snapshot even when only the secure credentials changed.
      if (!identical(nowSaved, saved)) return false;
      if (serverId == null) return true;
      return serverKey != null &&
          client != null &&
          !client.isClosed &&
          identical(ssh.getClient(serverId), client) &&
          ref
                  .read(serverListProvider)
                  .where((server) => server.id == serverId)
                  .firstOrNull
                  ?.connectionKey ==
              serverKey;
    }

    if (!current()) throw StateError('NAS_SOURCE_CHANGED');
    final cancellations = <NasCancellation>{};
    final tunnel = NasSshTunnelService(ssh);
    NasSourceAdapter? adapter;
    try {
      credentials = await _credentials(source, credentials, keepEmptySecrets);
      if (!current()) throw StateError('NAS_SOURCE_CHANGED');
      adapter = _createAdapter(
        await _forwardSource(source, tunnel),
        credentials,
        ssh,
      );
      if (!current()) throw StateError('NAS_SOURCE_CHANGED');
      final ownedAdapter = adapter;
      return RemoteBrowserSource(
        targetKey: 'nas::${_diagnosticKey(source)}::$serverKey',
        label: source.name,
        rootPath: '/',
        initialPath: source.type == NasSourceType.sftp
            ? source.rootPath
            : source.type == NasSourceType.smb
            ? '/${source.rootPath.replaceFirst(RegExp(r'^/+'), '')}'
            : '/',
        flat: source.isMediaServer,
        isCurrent: current,
        list: (path, cancelled) async* {
          final cancellation = NasCancellation();
          cancellations.add(cancellation);
          unawaited(cancelled.then((_) => cancellation.cancel()));
          try {
            yield* ownedAdapter.browse(path, cancellation);
          } finally {
            cancellations.remove(cancellation);
            cancellation.cancel();
          }
        },
        dispose: () async {
          for (final cancellation in cancellations.toList()) {
            cancellation.cancel();
          }
          try {
            await ownedAdapter.dispose();
          } finally {
            await tunnel.dispose();
          }
        },
      );
    } catch (_) {
      for (final cancellation in cancellations.toList()) {
        cancellation.cancel();
      }
      try {
        await adapter?.dispose();
      } finally {
        await tunnel.dispose();
      }
      rethrow;
    }
  }

  /// Recheck a saved source without treating blank form fields as credential edits.
  Future<void> probeSaved(NasSource source) async {
    final identity = _diagnosticKey(source);
    bool unchanged() =>
        ref.mounted &&
        state.selectedId == source.id &&
        state.sources.any((value) => _diagnosticKey(value) == identity);
    Object? sshTarget() => source.sshServerId == null
        ? null
        : ref
              .read(serverListProvider)
              .where((server) => server.id == source.sshServerId)
              .firstOrNull
              ?.connectionKey;
    if (!unchanged()) throw StateError('NAS_SOURCE_CHANGED');
    final target = sshTarget();
    if (source.sshServerId != null && target == null) {
      throw StateError('NAS_SSH_SERVER_NOT_FOUND');
    }
    final credentials = source.type == NasSourceType.sftp
        ? const NasCredentials()
        : await ref
              .read(secureStorageServiceProvider)
              .getNasCredentials(source.id);
    if (!unchanged() || target != sshTarget()) {
      throw StateError('NAS_SOURCE_CHANGED');
    }
    await probe(source, credentials);
  }

  /// Tests connectivity without persisting or selecting a temporary source.
  Future<void> probe(
    NasSource source,
    NasCredentials credentials, {
    bool keepEmptySecrets = false,
  }) async {
    final run = Object();
    final diagnosticKey = _diagnosticKey(source);
    _probeRuns[source.id] = run;
    void report(NasConnectionStage stage, {String? error, int? status}) {
      if (!ref.mounted || !identical(_probeRuns[source.id], run)) return;
      final now = DateTime.now();
      final diagnostics = {...state.diagnostics};
      final previous = diagnostics.remove(diagnosticKey);
      diagnostics[diagnosticKey] = NasConnectionDiagnostic(
        sourceId: source.id,
        stage: stage,
        updatedAt: now,
        lastSuccess: stage == NasConnectionStage.ready
            ? now
            : previous?.lastSuccess,
        errorCode: error,
        httpStatus: status,
      );
      while (diagnostics.length > 32) {
        diagnostics.remove(diagnostics.keys.first);
      }
      state = NasSourcesState(
        sources: state.sources,
        selectedId: state.selectedId,
        diagnostics: Map.unmodifiable(diagnostics),
      );
    }

    report(NasConnectionStage.credentials);
    final ssh = ref.read(sshCommandExecutorProvider);
    final tunnel = NasSshTunnelService(ssh);
    NasSourceAdapter? adapter;
    try {
      credentials = await _credentials(source, credentials, keepEmptySecrets);
      if (source.sshServerId != null &&
          source.type != NasSourceType.sftp &&
          source.type != NasSourceType.smb) {
        report(NasConnectionStage.tunnel);
      }
      adapter = _createAdapter(
        await _forwardSource(source, tunnel),
        credentials,
        ssh,
      );
      report(NasConnectionStage.checking);
      await adapter.probe();
      report(NasConnectionStage.ready);
    } catch (error) {
      final rawCode = switch (error) {
        NasHttpException() => error.code,
        StateError() => error.message,
        ArgumentError() => '${error.message}',
        SocketException() => 'NAS_CONNECTION_UNREACHABLE',
        TimeoutException() => 'NAS_CONNECTION_TIMEOUT',
        HandshakeException() => 'NAS_CONNECTION_TLS_FAILED',
        _ => 'NAS_CONNECTION_FAILED',
      };
      report(
        NasConnectionStage.failed,
        error: RegExp(r'^NAS_[A-Z0-9_]+$').hasMatch(rawCode)
            ? rawCode
            : 'NAS_CONNECTION_FAILED',
        status: error is NasHttpException ? error.status : null,
      );
      rethrow;
    } finally {
      if (identical(_probeRuns[source.id], run)) _probeRuns.remove(source.id);
      await adapter?.dispose();
      await tunnel.dispose();
    }
  }

  Future<void> remove(String id) => _mutate(() => _remove(id));
  Future<void> _remove(String id) async {
    final sources = state.sources.where((s) => s.id != id).toList();
    await ref.read(localStorageServiceProvider).saveNasSources(sources);
    await ref.read(secureStorageServiceProvider).deleteNasCredentials(id);
    _credentialGenerations[id] = (_credentialGenerations[id] ?? 0) + 1;
    _incompleteSaves.add(id);
    final selected = state.selectedId == id
        ? sources.firstOrNull?.id
        : state.selectedId;
    if (selected != null) {
      await ref
          .read(localStorageServiceProvider)
          .saveNasSelectedSourceId(selected);
    }
    _probeRuns.remove(id);
    final diagnostics = {...state.diagnostics}
      ..removeWhere((_, value) => value.sourceId == id);
    state = NasSourcesState(
      sources: sources,
      selectedId: selected,
      diagnostics: diagnostics,
    );
    _incompleteSaves.remove(id);
  }

  Future<({String userId, NasCredentials credentials})> authenticate(
    NasSource source,
    String password,
  ) async {
    final tunnel = NasSshTunnelService(ref.read(sshCommandExecutorProvider));
    try {
      return await NasMediaServerAdapter.authenticate(
        await _forwardSource(source, tunnel),
        password,
      );
    } finally {
      await tunnel.dispose();
    }
  }
}

Future<NasSource> _forwardSource(
  NasSource source,
  NasSshTunnelService tunnel,
) async {
  if (source.sshServerId == null ||
      source.type == NasSourceType.sftp ||
      source.type == NasSourceType.smb) {
    return source;
  }
  final uri = await tunnel.forward(source);
  return NasSource(
    id: source.id,
    name: source.name,
    type: source.type,
    endpoint: uri.toString(),
    sshServerId: source.sshServerId,
    username: source.username,
    userId: source.userId,
    rootPath: source.rootPath,
    forwardedHost: Uri.parse(source.endpoint).authority,
  );
}

NasSourceAdapter _createAdapter(
  NasSource source,
  NasCredentials credentials,
  SshCommandExecutor ssh,
) => switch (source.type) {
  NasSourceType.sftp => NasSftpAdapter(source, ssh),
  NasSourceType.webdav => NasWebDavAdapter(source, credentials),
  NasSourceType.smb => NasSmbAdapter(source: source, credentials: credentials),
  NasSourceType.jellyfin ||
  NasSourceType.emby => NasMediaServerAdapter(source, credentials),
};

final nasSourceAdapterProvider = FutureProvider.family<NasSourceAdapter, String>(
  (ref, id) async {
    final source = ref.watch(
      nasSourcesProvider.select(
        (s) => s.sources.where((source) => source.id == id).firstOrNull,
      ),
    );
    if (source == null) throw StateError('NAS_SOURCE_NOT_FOUND');
    final ssh = ref.watch(sshCommandExecutorProvider);
    final tunnelServerId = source.sshServerId;
    if (tunnelServerId != null &&
        source.type != NasSourceType.sftp &&
        source.type != NasSourceType.smb) {
      // Initial authentication and reconnects publish connection state. Track
      // this source's actual client, not the currently selected server/status:
      // an early failed Future or a closed tunnel must not remain cached.
      ref.watch(
        serverConnectionProvider.select((_) {
          final client = ssh.getClient(tunnelServerId);
          return client?.isClosed == false ? client : null;
        }),
      );
    }
    final tunnel = NasSshTunnelService(ssh);
    NasSourceAdapter? adapter;
    ref.onDispose(() async {
      await adapter?.dispose();
      await tunnel.dispose();
    });
    final credentials = source.type == NasSourceType.sftp
        ? const NasCredentials()
        : await ref.read(secureStorageServiceProvider).getNasCredentials(id);
    try {
      adapter = _createAdapter(
        await _forwardSource(source, tunnel),
        credentials,
        ssh,
      );
      if (!ref.mounted) {
        await adapter.dispose();
        throw StateError('NAS_SOURCE_CLOSED');
      }
    } catch (_) {
      await tunnel.dispose();
      rethrow;
    }
    return adapter;
  },
);
