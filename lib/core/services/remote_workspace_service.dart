import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/remote_workspace.dart';
import '../../data/models/server_profile.dart';
import '../../data/storage/local_storage_service.dart';
import '../../data/workspace/workspace_config_codec.dart';
import '../../data/workspace/workspace_gateway.dart';
import '../../data/workspace/workspace_journal.dart';
import '../../infrastructure/ssh/ssh_client_manager.dart'
    show SshCommandExecutor;
import '../../infrastructure/workspace/remote_workspace_client.dart';

class RemoteWorkspaceService implements WorkspaceGateway {
  final LocalStorageService storage;
  final SshCommandExecutor manager;
  final RemoteWorkspaceClient client;
  final WorkspaceJournal journal;
  final String deviceClass;
  void Function(RemoteWorkspaceState) onChanged;
  final void Function(WorkspaceChange) onHydrated;
  final Future<void> Function(ServerProfile, WorkspaceDraft)? restoreFileDraft;
  final Future<bool> Function(String serverId)? migrateLegacyBatch;
  final _changes = StreamController<WorkspaceChange>.broadcast();
  final Map<String, ServerProfile> _servers = {};
  final Map<String, Future<void>> _syncs = {};
  final _validationClock = Stopwatch()..start();
  final Map<String, ({Object client, int checked})> _verifiedClients = {};
  final Set<String> _corruptMeta = {};
  StreamSubscription<String>? _subscription;
  Timer? _timer, _debounce;
  ServerProfile? _active;
  bool _foreground = true, _disposed = false;
  int _epoch = 0;
  String _draftCursor = '';
  int _draftRequest = 0;

  /// Invalidates an in-flight `activate` baseline read when `enable` (or a
  /// preference-source switch) installs a newer baseline.
  int _baselineLock = 0;
  Map<String, Map<String, dynamic>> _baseline = {};
  Future<void> _captureTail = Future.value();
  Future<void> _baselineReady = Future.value();
  late final String _deviceId;
  late final Future<void> _deviceSaved;
  String? _deviceError;
  RemoteWorkspaceState state = const RemoteWorkspaceState();
  RemoteWorkspaceService({
    required this.storage,
    required this.manager,
    required this.deviceClass,
    required this.onChanged,
    required this.onHydrated,
    this.restoreFileDraft,
    this.migrateLegacyBatch,
    RemoteWorkspaceClient? client,
    WorkspaceJournal? journal,
  }) : client = client ?? RemoteWorkspaceClient(),
       journal = journal ?? WorkspaceJournal() {
    final raw = storage.workspacePreferences.raw;
    final old = raw.getString('valhalla_workspace_device_v1');
    _deviceId = old ?? const Uuid().v4();
    _deviceSaved = old != null
        ? Future.value()
        : raw
              .setString('valhalla_workspace_device_v1', _deviceId)
              .then<void>(
                (ok) {
                  if (!ok) _deviceError = 'WORKSPACE_DEVICE_SAVE_FAILED';
                },
                onError: (Object _, StackTrace _) {
                  _deviceError = 'WORKSPACE_DEVICE_SAVE_FAILED';
                },
              );
    storage.workspaceGateway = this;
    _subscription = storage.workspacePreferences.changes.listen((key) {
      if (key.startsWith('valhalla_workspace_') ||
          _active == null ||
          !isEnabled(_active!.id)) {
        return;
      }
      _captureTail = _captureTail.then((_) => _capture()).catchError((
        Object e,
      ) {
        _show(error: _error(e));
      });
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 500),
        () => unawaited(syncNow()),
      );
    });
  }

  void _updatePolling() {
    _timer?.cancel();
    _timer = null;
    if (_disposed ||
        !_foreground ||
        _active == null ||
        !isEnabled(_active!.id)) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(syncNow());
    });
  }

  @override
  String get deviceId => _deviceId;
  @override
  Stream<WorkspaceChange> get changes => _changes.stream;
  String _metaKey(String id) => 'valhalla_workspace_binding_v1::$id';

  Map<String, dynamic> _meta(String id) {
    final raw = storage.workspacePreferences.raw.getString(_metaKey(id));
    if (raw == null || raw.isEmpty) return {};
    try {
      final value = jsonDecode(raw);
      if (value is Map) {
        _corruptMeta.remove(id);
        return Map<String, dynamic>.from(value);
      }
    } on FormatException {
      // Never overwrite a corrupt binding implicitly; expose a stable error.
    } on TypeError {
      // Same as above for a JSON scalar/array.
    }
    _corruptMeta.add(id);
    return {};
  }

  @override
  bool isEnabled(String serverId) => _meta(serverId)['enabled'] == true;
  bool get _preferenceSource =>
      _active != null &&
      storage.workspacePreferences.raw.getString(
            'valhalla_workspace_preference_source_v1',
          ) ==
          _active!.id;
  WorkspaceConfigCodec _codec(
    ServerProfile server, {
    bool claimUnowned = false,
  }) => WorkspaceConfigCodec(
    storage,
    server,
    deviceId,
    deviceClass,
    includePreferences:
        storage.workspacePreferences.raw.getString(
          'valhalla_workspace_preference_source_v1',
        ) ==
        server.id,
    claimUnowned: claimUnowned,
  );

  Future<void> _saveMeta(String id, Map<String, dynamic> meta) async {
    final raw = storage.workspacePreferences.raw.getString(_metaKey(id));
    if (raw != null && raw.isNotEmpty) {
      try {
        final value = jsonDecode(raw);
        if (value is! Map) {
          throw const FormatException('WORKSPACE_LOCAL_CORRUPT');
        }
      } on FormatException {
        throw const WorkspaceException('WORKSPACE_LOCAL_CORRUPT');
      } on TypeError {
        throw const WorkspaceException('WORKSPACE_LOCAL_CORRUPT');
      }
    }
    if (!await storage.workspacePreferences.raw.setString(
      _metaKey(id),
      jsonEncode(meta),
    )) {
      throw const WorkspaceException('WORKSPACE_LOCAL_SAVE_FAILED');
    }
    _corruptMeta.remove(id);
  }

  void _show({
    WorkspacePhase? phase,
    String? error,
    int? pendingCount,
    List<WorkspaceConflict>? conflicts,
    List<WorkspaceDraft>? drafts,
    bool? draftsHaveMore,
    bool clearError = false,
  }) {
    if (_disposed) return;
    final server = _active;
    final meta = server == null ? <String, dynamic>{} : _meta(server.id);
    final corrupt = server != null && _corruptMeta.contains(server.id);
    final keepCorrupt = state.error == 'WORKSPACE_LOCAL_CORRUPT';
    state = RemoteWorkspaceState(
      serverId: server?.id,
      workspaceId: meta['workspaceId'] as String?,
      user: meta['user'] as String?,
      phase: phase ?? state.phase,
      error: clearError
          ? null
          : error ??
                ((corrupt || keepCorrupt) ? 'WORKSPACE_LOCAL_CORRUPT' : null),
      lastSyncedAt: DateTime.tryParse(meta['lastSyncedAt'] as String? ?? ''),
      pendingCount: pendingCount ?? state.pendingCount,
      conflicts: conflicts ?? state.conflicts,
      devicesDrafts: drafts ?? state.devicesDrafts,
      draftsHaveMore: draftsHaveMore ?? state.draftsHaveMore,
      isPreferenceSource: _preferenceSource,
      enabled: meta['enabled'] == true,
      migrationPending: meta['migrationPending'] == true,
    );
    onChanged(state);
  }

  void activate(ServerProfile? server, {required bool foreground}) {
    _foreground = foreground;
    if (_active?.connectionKey == server?.connectionKey) {
      _updatePolling();
      if (foreground) unawaited(syncNow());
      return;
    }
    _active = server;
    _updatePolling();
    _draftCursor = '';
    _epoch++;
    state = const RemoteWorkspaceState();
    _baseline = {};
    if (server != null) {
      _servers[server.id] = server;
      final epoch = _epoch;
      final lock = _baselineLock;
      _baselineReady = journal
          .localSnapshot(server.id)
          .then((saved) {
            if (epoch != _epoch || _disposed || lock != _baselineLock) return;
            _baseline = isEnabled(server.id) ? saved : _codec(server).export();
          })
          .catchError((Object e) {
            if (epoch == _epoch && lock == _baselineLock) {
              _show(phase: WorkspacePhase.error, error: _error(e));
            }
          });
    }
    _show(phase: WorkspacePhase.local);
    if (server != null) unawaited(discover());
  }

  Future<Map<String, dynamic>> _call(
    String serverId,
    Map<String, dynamic> command,
  ) async {
    await _deviceSaved;
    if (_deviceError != null) throw WorkspaceException(_deviceError!);
    final ssh = manager.getClient(serverId);
    if (ssh == null) throw const WorkspaceException('WORKSPACE_OFFLINE');
    final checked = _verifiedClients[serverId];
    if (checked == null ||
        !identical(checked.client, ssh) ||
        _validationClock.elapsedMilliseconds - checked.checked >= 10000) {
      final remote = await client.preflight(ssh);
      final boundId = _meta(serverId)['workspaceId'];
      if (remote['exists'] != false &&
          boundId != null &&
          boundId != remote['workspaceId']) {
        throw const WorkspaceException('WORKSPACE_IDENTITY_CHANGED');
      }
      if (remote['exists'] == false && command['op'] != 'bootstrap') {
        throw const WorkspaceException('WORKSPACE_NOT_BOOTSTRAPPED');
      }
      _verifiedClients[serverId] = (
        client: ssh,
        checked: _validationClock.elapsedMilliseconds,
      );
    }
    return client.request(ssh, {...command, 'deviceId': deviceId, 'schema': 1});
  }

  @override
  Future<Map<String, dynamic>> request(
    String serverId,
    Map<String, dynamic> command,
  ) {
    if (!isEnabled(serverId)) {
      throw const WorkspaceException('WORKSPACE_NOT_ENABLED');
    }
    return _call(serverId, command);
  }

  Future<void> discover() async {
    final server = _active;
    if (server == null || state.isBusy) return;
    final epoch = _epoch;
    final ssh = manager.getClient(server.id);
    if (ssh == null) {
      _show(phase: WorkspacePhase.offline);
      return;
    }
    _show(phase: WorkspacePhase.discovering);
    try {
      final value = await client.preflight(ssh);
      if (epoch != _epoch || _disposed) return;
      if (value['exists'] == false) {
        _show(phase: WorkspacePhase.local);
        return;
      }
      if (value['schema'] != 1) {
        throw const WorkspaceException('WORKSPACE_SCHEMA_UNSUPPORTED');
      }
      final meta = _meta(server.id);
      if (meta['workspaceId'] != null &&
          meta['workspaceId'] != value['workspaceId']) {
        throw const WorkspaceException('WORKSPACE_IDENTITY_CHANGED');
      }
      await _saveMeta(server.id, {
        ...meta,
        'workspaceId': value['workspaceId'],
        'user': value['user'],
      });
      _show(
        phase: isEnabled(server.id)
            ? WorkspacePhase.ready
            : WorkspacePhase.available,
      );
      if (isEnabled(server.id)) await syncNow();
    } catch (e) {
      if (epoch == _epoch) {
        _show(phase: WorkspacePhase.error, error: _error(e));
      }
    }
  }

  Future<Map<String, int>> migrationPreview() async {
    final server = _active;
    if (server == null) return {};
    final out = <String, int>{};
    final records = _codec(server, claimUnowned: true).export();
    for (final r in records.values) {
      final kind = r['kind'] as String;
      out[kind] = (out[kind] ?? 0) + 1;
    }
    return out;
  }

  Future<void> enable() async {
    final server = _active;
    if (server == null || state.isBusy) return;
    final epoch = _epoch;
    final ssh = manager.getClient(server.id);
    if (ssh == null) {
      _show(phase: WorkspacePhase.offline, error: 'WORKSPACE_OFFLINE');
      return;
    }
    _show(phase: WorkspacePhase.syncing);
    try {
      // Explicit preflight: a future schema/component must be rejected before
      // the client can replace the remote store with the bundled one.
      await client.preflight(ssh);
      await client.install(ssh);
      final value = await _call(server.id, {'op': 'bootstrap'});
      if (value['schema'] != 1) {
        throw const WorkspaceException('WORKSPACE_SCHEMA_UNSUPPORTED');
      }
      if (epoch != _epoch) return;
      final meta = _meta(server.id);
      if (meta['workspaceId'] != null &&
          meta['workspaceId'] != value['workspaceId']) {
        throw const WorkspaceException('WORKSPACE_IDENTITY_CHANGED');
      }
      final firstMigration =
          meta['revision'] == null && meta['enabled'] != true;
      final codec = _codec(server, claimUnowned: true);
      // Claim before exporting so a second server cannot publish entries that
      // already belong to this workspace.
      await codec.claimOwnership();
      final local = codec.export();
      final raw = storage.workspacePreferences.raw;
      if (raw.getString('valhalla_workspace_preference_source_v1') == null) {
        if (!await raw.setString(
          'valhalla_workspace_preference_source_v1',
          server.id,
        )) {
          throw const WorkspaceException('WORKSPACE_LOCAL_SAVE_FAILED');
        }
      }
      // Queue before reading server records: migration must never inherit a
      // remote CAS version.
      await journal.queue(
        server.id,
        local.values.toList(),
        forceBaseZero: firstMigration,
      );
      // Persist the observed baseline too, so a crash before the first outbox
      // flush cannot replay the whole migration on restart.
      await journal.rememberLocal(server.id, local.values.toList());
      _baselineLock++;
      _baseline = local;
      await _saveMeta(server.id, {
        ...meta,
        'workspaceId': value['workspaceId'],
        'user': value['user'],
        'enabled': true,
        'migrationPending':
            meta['migrationPending'] == true ||
            firstMigration && migrateLegacyBatch != null,
      });
      _show(phase: WorkspacePhase.ready, clearError: true);
      _updatePolling();
      await syncNow();
    } catch (e) {
      if (epoch == _epoch) {
        _show(phase: WorkspacePhase.error, error: _error(e));
      }
    }
  }

  Future<void> disable() async {
    final server = _active;
    if (server == null) return;
    await _saveMeta(server.id, {..._meta(server.id), 'enabled': false});
    _updatePolling();
    _epoch++;
    _show(phase: WorkspacePhase.local);
  }

  Future<void> useAsPreferenceSource() async {
    final server = _active;
    if (server == null) return;
    if (!await storage.workspacePreferences.raw.setString(
      'valhalla_workspace_preference_source_v1',
      server.id,
    )) {
      throw const WorkspaceException('WORKSPACE_LOCAL_SAVE_FAILED');
    }
    _baselineLock++;
    _baseline = _codec(server).export();
    // Re-read from zero so the newly chosen source's preference records are
    // applied.
    await _saveMeta(server.id, {..._meta(server.id), 'revision': 0});
    _show();
    await syncNow();
  }

  Future<void> _capture() async {
    final server = _active;
    if (server == null || !isEnabled(server.id)) return;
    final epoch = _epoch;
    await _baselineReady;
    if (epoch != _epoch || _disposed) return;
    final Map<String, Map<String, dynamic>> current;
    try {
      final codec = _codec(server);
      // New local commands/sources become owned by this workspace before
      // export, so a second workspace cannot later claim them.
      await codec.claimOwnership();
      current = codec.export();
    } on FormatException {
      throw const WorkspaceException('WORKSPACE_LOCAL_CORRUPT');
    } on TypeError {
      throw const WorkspaceException('WORKSPACE_LOCAL_CORRUPT');
    }
    final delta = <Map<String, dynamic>>[];
    for (final e in current.entries) {
      if (!_equal(e.value, _baseline[e.key])) delta.add(e.value);
    }
    for (final e in _baseline.entries) {
      if (!current.containsKey(e.key)) {
        delta.add({...e.value, 'deleted': true});
      }
    }
    if (delta.isNotEmpty) {
      await journal.queue(server.id, delta);
      await journal.rememberLocal(server.id, delta);
    }
    if (epoch == _epoch && !_disposed) _baseline = current;
  }

  @override
  Future<void> putRecords(
    String serverId,
    List<Map<String, dynamic>> records,
  ) async {
    if (!isEnabled(serverId)) return;
    await journal.queue(serverId, records);
    if (_active?.id == serverId && _foreground) unawaited(syncNow());
  }

  Future<void> syncNow() {
    final server = _active;
    if (server == null || !isEnabled(server.id) || !_foreground) {
      return Future.value();
    }
    final existing = _syncs[server.id];
    if (existing != null) return existing;
    late Future<void> job;
    job = _sync(server, _epoch).whenComplete(() {
      if (identical(_syncs[server.id], job)) _syncs.remove(server.id);
    });
    _syncs[server.id] = job;
    return job;
  }

  Future<void> _sync(ServerProfile server, int epoch) async {
    if (manager.getClient(server.id) == null) {
      _show(phase: WorkspacePhase.offline);
      return;
    }
    _show(phase: WorkspacePhase.syncing);
    try {
      _verifiedClients.remove(server.id);
      await _captureTail;
      await _baselineReady;
      if (epoch != _epoch || _disposed) return;
      await _capture();
      if (_meta(server.id)['migrationPending'] == true &&
          migrateLegacyBatch != null &&
          await journal.pendingCount(server.id) < 200) {
        final done = await migrateLegacyBatch!(server.id);
        if (epoch != _epoch || _disposed) return;
        if (done) {
          await _saveMeta(server.id, {
            ..._meta(server.id),
            'migrationPending': false,
          });
        }
      }
      final codec = _codec(server);
      var meta = _meta(server.id);
      var cursor = meta['revision'] as int? ?? 0;
      final notifications = <Map<String, dynamic>>[];
      final hydrated = <Map<String, dynamic>>[];
      var more = true;
      while (more) {
        final page = await request(server.id, {
          'op': 'changes',
          'after': cursor,
          'limit': 100,
          'kinds': ['config', 'preference', 'draft', 'chat_session'],
        });
        if (epoch != _epoch || _disposed) return;
        for (final value in (page['records'] as List? ?? [])) {
          final record = Map<String, dynamic>.from(value as Map);
          // Other devices' drafts / other device classes' preferences are not
          // this device's data: never cache, apply, notify or tombstone them.
          if (record['kind'] == 'chat_session' ||
              record['kind'] == 'draft' &&
                  ((record['id'] as String).contains('/file/') ||
                      (record['id'] as String).contains('::backup::'))) {
            await journal.receive(server.id, record);
            notifications.add(record);
            continue;
          }
          if (!codec.handles(record)) continue;
          // Validate before caching so a malformed record cannot be skipped
          // silently on a retry because its version is already cached.
          codec.validate(record);
          final generation = storage.workspacePreferences.generation;
          final apply = await journal.receive(server.id, record);
          if (generation != storage.workspacePreferences.generation) {
            if (apply) {
              // The record was cached but not applied yet. Remove that marker
              // so the retry does not mistake it for an already-applied record.
              await journal.forgetCache(
                server.id,
                record['kind'] as String,
                record['id'] as String,
              );
            }
            await _captureTail;
            _show(phase: WorkspacePhase.ready);
            return; // Retry the same page after local writes are durable.
          }
          if (apply) {
            await codec.apply(record);
            final key = '${record['kind']}\x00${record['id']}';
            final visible = codec.export()[key];
            if (visible != null) {
              await journal.rememberLocal(server.id, [
                {...visible, 'version': record['version']},
              ]);
            } else if (record['deleted'] == true &&
                _baseline.containsKey(key)) {
              await journal.rememberLocal(server.id, [record]);
            }
            notifications.add(record);
            hydrated.add(record);
          }
        }
        final next = page['revision'] as int;
        more = page['hasMore'] == true;
        if (more && next <= cursor) {
          throw const WorkspaceException('WORKSPACE_CURSOR_INVALID');
        }
        cursor = next;
        await _saveMeta(server.id, {...meta, 'revision': cursor});
        meta = _meta(server.id);
      }
      for (var batch = 0; batch < 16; batch++) {
        final candidates = await journal.pending(server.id, limit: 100);
        if (candidates.isEmpty) break;
        final pending = <String, Map<String, dynamic>>{};
        final outgoing = <Map<String, dynamic>>[];
        // Leave room for the JSON array delimiters and request envelope.
        var bytes = 1024;
        for (final value in candidates) {
          final record = {...value}..remove('operationId');
          final size = utf8.encode(jsonEncode(record)).length;
          if (outgoing.isNotEmpty && bytes + size > 512 * 1024) break;
          if (size + 1024 > 512 * 1024) {
            throw const WorkspaceException('WORKSPACE_VALUE_TOO_LARGE');
          }
          outgoing.add(record);
          pending['${value['kind']}\x00${value['id']}'] = value;
          bytes += size;
        }
        final operation = sha256
            .convert(
              utf8.encode(
                jsonEncode([
                  for (final value in pending.values) value['operationId'],
                ]),
              ),
            )
            .toString();
        try {
          final response = await request(server.id, {
            'op': 'commit',
            'operationId': operation,
            'records': outgoing,
          });
          for (final v in response['records'] as List) {
            final record = Map<String, dynamic>.from(v as Map);
            final original = pending['${record['kind']}\x00${record['id']}'];
            if (original == null) {
              throw const WorkspaceException('WORKSPACE_RECORD_INVALID');
            }
            final applied = await journal.receive(
              server.id,
              record,
              operationId: original['operationId'] as String,
            );
            if (applied && codec.handles(record)) {
              await journal.rememberLocal(server.id, [record]);
            }
            notifications.add(record);
          }
        } on WorkspaceException catch (e) {
          if (e.code != 'WORKSPACE_CONFLICT') rethrow;
          final conflicts = e.details['records'] as List? ?? [];
          if (conflicts.isEmpty) rethrow;
          for (final v in conflicts) {
            final remote = Map<String, dynamic>.from(v as Map);
            final original = pending['${remote['kind']}\x00${remote['id']}'];
            if (original == null) {
              throw const WorkspaceException('WORKSPACE_RECORD_INVALID');
            }
            final same =
                _equal(remote['value'], original['value']) &&
                (remote['deleted'] == true) == (original['deleted'] == true);
            final applied = await journal.receive(
              server.id,
              remote,
              operationId: same ? original['operationId'] as String : null,
            );
            if (applied && same && codec.handles(remote)) {
              await journal.rememberLocal(server.id, [remote]);
            }
          }
        }
        if (epoch != _epoch || _disposed) return;
      }
      await _saveMeta(server.id, {
        ..._meta(server.id),
        'lastSyncedAt': DateTime.now().toUtc().toIso8601String(),
      });
      if (epoch != _epoch || _disposed) return;
      await _captureTail;
      _baseline = codec.export();
      _changes.add(WorkspaceChange(server.id, notifications));
      if (hydrated.isNotEmpty) {
        onHydrated(WorkspaceChange(server.id, hydrated));
      }
      await _refreshState(server.id);
      _show(phase: WorkspacePhase.ready, clearError: true);
    } catch (e) {
      if (epoch == _epoch && !_disposed) {
        _show(
          phase: manager.getClient(server.id) == null
              ? WorkspacePhase.offline
              : WorkspacePhase.error,
          error: _error(e),
        );
      }
    }
  }

  Future<void> _refreshState(String id) async {
    final conflicts = <WorkspaceConflict>[];
    for (final p in await journal.pending(id, conflicts: true, limit: 1000)) {
      final remote = await journal.cached(
        id,
        p['kind'] as String,
        p['id'] as String,
      );
      conflicts.add(
        WorkspaceConflict(
          kind: p['kind'] as String,
          id: p['id'] as String,
          localValue: p,
          remoteValue: remote,
        ),
      );
    }
    if (_active?.id == id) {
      _show(pendingCount: await journal.pendingCount(id), conflicts: conflicts);
    }
  }

  Future<void> resolveConflict(
    WorkspaceConflict conflict, {
    required bool keepLocal,
  }) async {
    final server = _active;
    if (server == null) return;
    await journal.resolve(
      server.id,
      conflict.kind,
      conflict.id,
      keepLocal: keepLocal,
    );
    if (!keepLocal) {
      final record = await journal.cached(
        server.id,
        conflict.kind,
        conflict.id,
      );
      if (record != null && _codec(server).handles(record)) {
        await _codec(server).apply(record);
        _baseline = _codec(server).export();
        onHydrated(WorkspaceChange(server.id, [record]));
      }
    }
    await _refreshState(server.id);
    await syncNow();
  }

  Future<void> loadDeviceDrafts({bool append = false}) async {
    final server = _active;
    if (server == null ||
        !isEnabled(server.id) ||
        append && !state.draftsHaveMore) {
      return;
    }
    final epoch = _epoch;
    final generation = ++_draftRequest;
    final cursor = append ? _draftCursor : '';
    final page = await request(server.id, {
      'op': 'snapshot',
      'kind': 'draft',
      'limit': 100,
      'afterId': cursor,
    });
    if (epoch != _epoch || generation != _draftRequest) return;
    final drafts = <String, WorkspaceDraft>{
      if (append)
        for (final draft in state.devicesDrafts) draft.id: draft,
    };
    for (final v in page['records'] as List? ?? []) {
      final r = Map<String, dynamic>.from(v as Map);
      final id = r['id'] as String;
      if (r['deleted'] == true) {
        drafts.remove(id);
        continue;
      }
      final value = Map<String, dynamic>.from(r['value'] as Map);
      drafts[id] = WorkspaceDraft(
        id: id,
        deviceId: value['deviceId'] as String? ?? '',
        title:
            value['path'] as String? ??
            value['restoreKey'] as String? ??
            value['key'] as String? ??
            id,
        value: value,
      );
    }
    final more = page['hasMore'] == true;
    final next = page['nextCursor'] as String?;
    if (more && (next == null || next.compareTo(cursor) <= 0)) {
      throw const WorkspaceException('WORKSPACE_CURSOR_INVALID');
    }
    _draftCursor = next ?? cursor;
    _show(drafts: drafts.values.toList(), draftsHaveMore: more);
  }

  Future<void> restoreDraft(WorkspaceDraft draft) async {
    final server = _active;
    if (server == null) return;
    if (draft.value['type'] == 'file') {
      final restore = restoreFileDraft;
      if (restore == null) {
        throw const WorkspaceException('WORKSPACE_FILE_DRAFT_UNAVAILABLE');
      }
      await restore(server, draft);
      return;
    }
    final codec = _codec(server);
    final restoredKey =
        draft.value['restoreKey'] as String? ?? draft.value['key'];
    final restored = <String, dynamic>{
      'kind': 'draft',
      'id': '${draft.deviceId}/$restoredKey',
      'value': {...draft.value, 'key': restoredKey}..remove('restoreKey'),
    };
    codec.validate(restored, restoreDraft: true);
    final saved = codec
        .export()
        .values
        .where(
          (x) =>
              x['kind'] == 'draft' && (x['value'] as Map)['key'] == restoredKey,
        )
        .toList();
    // Keep a recoverable copy of this device's drafts before explicit
    // replacement.
    if (saved.isNotEmpty) {
      await journal.queue(
        server.id,
        saved.map((r) {
          final key =
              'valhalla_chat_draft_v1::@server::backup::${const Uuid().v4()}';
          return <String, dynamic>{
            'kind': 'draft',
            'id': '$deviceId/$key',
            'value': {
              ...r['value'] as Map,
              'key': key,
              'restoreKey': restoredKey,
            },
          };
        }).toList(),
      );
    }
    await codec.apply(restored, restoreDraft: true);
    await _capture();
    onHydrated(WorkspaceChange(server.id, const []));
    await syncNow();
  }

  Future<void> clearLocalCache() async {
    final server = _active;
    if (server == null) return;
    try {
      await journal.clear(server.id, requireNoPending: true);
    } on StateError {
      throw const WorkspaceException('WORKSPACE_PENDING_CHANGES');
    }
    await _saveMeta(server.id, {..._meta(server.id), 'revision': 0});
    _show(pendingCount: 0, conflicts: [], drafts: []);
    await syncNow();
  }

  String _error(Object e) {
    if (e is WorkspaceException) return e.code;
    if (e is FormatException || e is TypeError) {
      return 'WORKSPACE_LOCAL_CORRUPT';
    }
    return 'WORKSPACE_SYNC_FAILED';
  }

  bool _equal(Object? a, Object? b) =>
      jsonEncode(_ordered(a)) == jsonEncode(_ordered(b));

  Object? _ordered(Object? v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: _ordered(v[k])};
    }
    if (v is List) return v.map(_ordered).toList();
    return v;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    _timer?.cancel();
    _debounce?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_changes.close());
    if (identical(storage.workspaceGateway, this)) {
      storage.workspaceGateway = null;
    }
  }
}
