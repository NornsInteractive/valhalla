import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/services/remote_workspace_service.dart';
import 'package:valhalla/data/models/remote_workspace.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/workspace/workspace_gateway.dart';
import 'package:valhalla/data/workspace/workspace_journal.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/workspace/remote_workspace_client.dart';

const _serverA = ServerProfile(
  id: 'srv-a',
  name: 'A',
  host: 'a.example',
  username: 'dev',
);
const _serverB = ServerProfile(
  id: 'srv-b',
  name: 'B',
  host: 'b.example',
  username: 'dev',
);

class _FakeSsh implements SSHClient {
  final String serverId;
  _FakeSsh(this.serverId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeManager implements SshCommandExecutor {
  final Map<String, SSHClient> clients = {};

  @override
  SSHClient? getClient(String serverId) => clients[serverId];

  @override
  bool isConnected(String serverId) => clients.containsKey(serverId);

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async => const SSHExecutionResult(exitCode: 0, stdout: '', stderr: '');

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) => const Stream.empty();
}

class _Store {
  bool exists = false;
  int schema = 1;
  int? component;
  String workspaceId = 'ws-1';
  int revision = 0;
  final Map<String, Map<String, dynamic>> records = {};
  int installCalls = 0;
  int bootstrapCalls = 0;
  final List<Map<String, dynamic>> commits = [];
  Completer<void>? changesGate;
  Completer<void>? changesStarted;

  void put({
    required String kind,
    required String id,
    required Object? value,
    bool deleted = false,
    int? version,
  }) {
    final key = '$kind\x00$id';
    if (version == null) {
      revision += 1;
      version = revision;
    } else if (version > revision) {
      revision = version;
    }
    records[key] = {
      'kind': kind,
      'id': id,
      'value': value,
      'version': version,
      'deleted': deleted,
    };
  }
}

class _FakeClient extends RemoteWorkspaceClient {
  final Map<String, _Store> stores = {};

  _Store store(String serverId) => stores.putIfAbsent(serverId, _Store.new);

  @override
  Future<Map<String, dynamic>> discover(SSHClient ssh) async {
    final store = this.store((ssh as _FakeSsh).serverId);
    if (!store.exists) return {'ok': true, 'exists': false};
    return {
      'ok': true,
      'exists': true,
      'workspaceId': store.workspaceId,
      'schema': store.schema,
      'revision': store.revision,
      'user': 'dev',
      if (store.component != null) 'component': store.component,
    };
  }

  @override
  Future<void> install(SSHClient ssh) async {
    store((ssh as _FakeSsh).serverId).installCalls += 1;
  }

  @override
  Future<Map<String, dynamic>> request(
    SSHClient ssh,
    Map<String, dynamic> command,
  ) async {
    final store = this.store((ssh as _FakeSsh).serverId);
    final op = command['op'];
    if (op == 'bootstrap') {
      store.bootstrapCalls += 1;
      store.exists = true;
      return {
        'ok': true,
        'workspaceId': store.workspaceId,
        'schema': store.schema,
        'revision': store.revision,
        'user': 'dev',
      };
    }
    if (op == 'changes') {
      final started = store.changesStarted;
      if (started != null && !started.isCompleted) started.complete();
      final gate = store.changesGate;
      if (gate != null) await gate.future;
      final after = command['after'] as int? ?? 0;
      final kinds = (command['kinds'] as List?)?.cast<String>();
      final limit = command['limit'] as int? ?? 100;
      final all =
          store.records.values
              .where(
                (r) =>
                    (r['version'] as int) > after &&
                    (kinds == null || kinds.contains(r['kind'])),
              )
              .toList()
            ..sort(
              (a, b) => (a['version'] as int).compareTo(b['version'] as int),
            );
      final page = all.take(limit).toList();
      final hasMore = all.length > page.length;
      final revision = page.isEmpty
          ? store.revision
          : page.last['version'] as int;
      return {
        'ok': true,
        'records': page.map((r) => Map<String, dynamic>.from(r)).toList(),
        'revision': revision,
        'hasMore': hasMore,
      };
    }
    if (op == 'snapshot') {
      final kind = command['kind'];
      final limit = command['limit'] as int? ?? 100;
      final afterId = command['afterId'] as String? ?? '';
      final values =
          store.records.values
              .where(
                (r) =>
                    (kind == null || r['kind'] == kind) &&
                    (afterId.isEmpty ||
                        (r['id'] as String).compareTo(afterId) > 0),
              )
              .toList()
            ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
      final page = values.take(limit).toList();
      final hasMore = values.length > limit;
      final next = page.isNotEmpty ? page.last['id'] as String : afterId;
      return {
        'ok': true,
        'records': page.map((r) => Map.from(r)).toList(),
        'revision': store.revision,
        'hasMore': hasMore,
        'nextCursor': next,
      };
    }
    if (op == 'commit') {
      store.commits.add(Map<String, dynamic>.from(command));
      final records = (command['records'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      final conflicts = <Map<String, dynamic>>[];
      for (final record in records) {
        final current = store.records['${record['kind']}\x00${record['id']}'];
        final currentVersion = current?['version'] as int? ?? 0;
        if (currentVersion != (record['baseVersion'] as int? ?? 0)) {
          conflicts.add({
            'kind': record['kind'],
            'id': record['id'],
            'value': current?['value'],
            'version': currentVersion,
            'deleted': current?['deleted'] ?? false,
          });
        }
      }
      if (conflicts.isNotEmpty) {
        throw WorkspaceException('WORKSPACE_CONFLICT', {
          'records': conflicts,
          'revision': store.revision,
        });
      }
      final changed = <Map<String, dynamic>>[];
      for (final record in records) {
        store.revision += 1;
        final saved = {
          'kind': record['kind'],
          'id': record['id'],
          'value': record['value'],
          'version': store.revision,
          'deleted': record['deleted'] == true,
        };
        store.records['${record['kind']}\x00${record['id']}'] = saved;
        changed.add(Map<String, dynamic>.from(saved));
      }
      return {'ok': true, 'records': changed, 'revision': store.revision};
    }
    throw WorkspaceException('WORKSPACE_OP_INVALID', {'op': op});
  }
}

class _DiscoveryClient extends _FakeClient {
  Map<String, dynamic>? discovery;

  @override
  Future<Map<String, dynamic>> discover(SSHClient ssh) async =>
      discovery ?? await super.discover(ssh);
}

class _SlowQueueJournal extends WorkspaceJournal {
  _SlowQueueJournal({required super.databasePath});
  String? slowServer;
  Completer<void>? gate;
  Completer<void>? started;

  @override
  Future<void> queue(
    String server,
    List<Map<String, dynamic>> values, {
    bool forceBaseZero = false,
  }) async {
    if (server == slowServer && gate != null) {
      final signal = started;
      if (signal != null && !signal.isCompleted) signal.complete();
      await gate!.future;
    }
    return super.queue(server, values, forceBaseZero: forceBaseZero);
  }
}

class _RacingJournal extends WorkspaceJournal {
  _RacingJournal({required super.databasePath});
  Future<void> Function()? onReceive;

  @override
  Future<bool> receive(
    String server,
    Map<String, dynamic> value, {
    String? operationId,
  }) async {
    final applied = await super.receive(
      server,
      value,
      operationId: operationId,
    );
    final callback = onReceive;
    if (callback != null && operationId == null) {
      onReceive = null;
      await callback();
      await pumpEventQueue();
    }
    return applied;
  }
}

/// Completes journal work immediately so timer creation can be observed inside
/// a [fakeAsync] zone without spawning the real isolate-backed journal.
class _InstantJournal extends WorkspaceJournal {
  _InstantJournal() : super(databasePath: 'instant-journal.sqlite3');

  @override
  Future<Map<String, Map<String, dynamic>>> localSnapshot(String server) async =>
      {};

  @override
  Future<void> rememberLocal(
    String server,
    List<Map<String, dynamic>> records,
  ) async {}

  @override
  Future<void> queue(
    String server,
    List<Map<String, dynamic>> values, {
    bool forceBaseZero = false,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> pending(
    String server, {
    bool conflicts = false,
    int limit = 16,
  }) async => [];

  @override
  Future<int> pendingCount(String server) async => 0;

  @override
  Future<void> forgetCache(String server, String kind, String id) async {}

  @override
  Future<Map<String, dynamic>?> cached(
    String server,
    String kind,
    String id,
  ) async => null;

  @override
  Future<bool> receive(
    String server,
    Map<String, dynamic> value, {
    String? operationId,
  }) async => false;

  @override
  Future<void> clear(String server, {bool requireNoPending = false}) async {}
}

class _Env {
  final LocalStorageService storage;
  final _FakeManager manager;
  final _FakeClient client;
  final WorkspaceJournal journal;
  final RemoteWorkspaceService service;
  final List<RemoteWorkspaceState> states;
  final List<WorkspaceChange> hydrated;
  _Env({
    required this.storage,
    required this.manager,
    required this.client,
    required this.journal,
    required this.service,
    required this.states,
    required this.hydrated,
  });
}

Future<_Env> _env({
  Map<String, Object> prefs = const {},
  WorkspaceJournal? journal,
  String serverId = 'srv-a',
  _FakeClient? customClient,
}) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(prefs));
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  final dir = await Directory.systemTemp.createTemp('rws');
  final actualJournal =
      journal ?? WorkspaceJournal(databasePath: '${dir.path}/journal.sqlite3');
  final manager = _FakeManager()..clients[serverId] = _FakeSsh(serverId);
  final client = customClient ?? _FakeClient();
  final states = <RemoteWorkspaceState>[];
  final hydrated = <WorkspaceChange>[];
  final service = RemoteWorkspaceService(
    storage: storage,
    manager: manager,
    deviceClass: 'desktop',
    onChanged: states.add,
    onHydrated: hydrated.add,
    client: client,
    journal: actualJournal,
  );
  addTearDown(service.dispose);
  return _Env(
    storage: storage,
    manager: manager,
    client: client,
    journal: actualJournal,
    service: service,
    states: states,
    hydrated: hydrated,
  );
}

Future<void> _activate(
  RemoteWorkspaceService service,
  ServerProfile server,
) async {
  service.activate(server, foreground: true);
  await _waitFor(() => !service.state.isBusy);
}

Future<void> _waitFor(bool Function() predicate, {int attempts = 500}) async {
  for (var i = 0; i < attempts; i++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  throw StateError('condition timed out');
}

Map<String, dynamic> _meta(LocalStorageService storage, String serverId) {
  final raw = storage.workspacePreferences.raw.getString(
    'valhalla_workspace_binding_v1::$serverId',
  );
  return raw == null
      ? <String, dynamic>{}
      : Map<String, dynamic>.from(jsonDecode(raw) as Map);
}

List<Map<String, dynamic>> _commands(LocalStorageService storage) {
  final raw = storage.workspacePreferences.getString(
    'valhalla_quick_commands_v1',
  );
  if (raw == null) return [];
  return (jsonDecode(raw) as List)
      .map((v) => Map<String, dynamic>.from(v as Map))
      .toList();
}

void main() {
  group('RemoteWorkspaceService polling lifecycle', () {
    test('a disabled workspace starts no polling timer', () async {
      final env = await _env(journal: _InstantJournal());
      env.client.store('srv-a').exists = false;

      fakeAsync((async) {
        env.service.activate(_serverA, foreground: true);
        async.flushMicrotasks();

        expect(async.periodicTimerCount, 0);
        expect(async.nonPeriodicTimerCount, 0);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('polling only runs while enabled and in the foreground', () async {
      final env = await _env(
        prefs: {
          'valhalla_workspace_binding_v1::srv-a': jsonEncode({
            'enabled': true,
            'workspaceId': 'ws-1',
            'revision': 0,
          }),
        },
        journal: _InstantJournal(),
      );
      env.client.store('srv-a').exists = true;

      fakeAsync((async) {
        env.service.activate(_serverA, foreground: true);
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 1);

        env.service.activate(_serverA, foreground: false);
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 0);

        env.service.activate(_serverA, foreground: true);
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 1);

        env.service.disable();
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 0);
        expect(async.nonPeriodicTimerCount, 0);
      });
    });
  });

  group('RemoteWorkspaceService lifecycle', () {
    test(
      'first migration keeps baseVersion zero and conflicts with remote',
      () async {
        final env = await _env(
          prefs: {
            'valhalla_quick_commands_v1': jsonEncode([
              {'id': 'c1', 'title': 'Local', 'command': 'echo local'},
            ]),
          },
        );
        env.client.store('srv-a')
          ..exists = true
          ..put(
            kind: 'config',
            id: 'command/c1',
            value: {
              'storageKey': 'valhalla_quick_commands_v1',
              'item': {'id': 'c1', 'title': 'Remote', 'command': 'echo remote'},
            },
            version: 5,
          );
        await _activate(env.service, _serverA);
        await env.service.enable();

        expect(env.service.state.conflicts, hasLength(1));
        final pending = await env.journal.pending('srv-a', conflicts: true);
        expect(pending, hasLength(1));
        expect(pending.first['baseVersion'], 0);
        expect(
          (await env.journal.cached(
            'srv-a',
            'config',
            'command/c1',
          ))!['version'],
          5,
        );
        // The remote value was not applied over the local one.
        expect(_commands(env.storage).single['title'], 'Local');
        expect(env.client.store('srv-a').commits, isEmpty);
      },
    );

    test(
      'identical migration value auto-acknowledges without a conflict',
      () async {
        final item = {'id': 'c1', 'title': 'Same', 'command': 'echo same'};
        final env = await _env(
          prefs: {
            'valhalla_quick_commands_v1': jsonEncode([item]),
          },
        );
        env.client.store('srv-a')
          ..exists = true
          ..put(
            kind: 'config',
            id: 'command/c1',
            value: {'storageKey': 'valhalla_quick_commands_v1', 'item': item},
            version: 5,
          );
        await _activate(env.service, _serverA);
        await env.service.enable();

        expect(env.service.state.conflicts, isEmpty);
        expect(await env.journal.pending('srv-a'), isEmpty);
        expect(await env.journal.pendingCount('srv-a'), 0);
        expect(_commands(env.storage).single['title'], 'Same');
      },
    );

    test(
      'delayed A capture and A to B activation does not leak a baseline',
      () async {
        final journal = _SlowQueueJournal(
          databasePath:
              '${(await Directory.systemTemp.createTemp('rws-slow')).path}/j.sqlite3',
        );
        final env = await _env(journal: journal);
        env.manager.clients['srv-b'] = _FakeSsh('srv-b');
        env.client.store('srv-a').exists = false;
        env.client.store('srv-b').exists = false;

        await _activate(env.service, _serverA);
        await env.service.enable();
        await _waitFor(() => env.service.state.phase == WorkspacePhase.ready);

        journal.slowServer = 'srv-a';
        journal.gate = Completer<void>();
        journal.started = Completer<void>();
        await env.storage.workspacePreferences.setString(
          'valhalla_quick_commands_v1',
          jsonEncode([
            {'id': 'cA', 'title': 'A only', 'command': 'echo a'},
          ]),
        );
        await journal.started!.future;

        // Switch to B while A's local capture is still blocked in the outbox.
        env.service.activate(_serverB, foreground: true);
        await pumpEventQueue();
        journal.gate!.complete();
        await pumpEventQueue(times: 20);

        expect(await env.journal.pending('srv-b'), isEmpty);
        expect(
          (await env.journal.pending('srv-a')).map((r) => r['id']),
          contains('command/cA'),
        );

        await _activate(env.service, _serverA);
        await env.service.syncNow();
        expect(
          env.client.store('srv-a').records.keys,
          contains('config\x00command/cA'),
        );
        await _activate(env.service, _serverB);
        await env.service.enable();
        expect(
          env.client.store('srv-b').records.keys,
          isNot(contains('config\x00command/cA')),
        );
      },
    );

    test(
      'restart recovers a local delta from the workspace_local snapshot',
      () async {
        final env = await _env(
          prefs: {
            'valhalla_quick_commands_v1': jsonEncode([
              {'id': 'cA', 'title': 'A', 'command': 'echo a'},
            ]),
          },
        );
        env.client.store('srv-a').exists = false;
        await _activate(env.service, _serverA);
        await env.service.enable();
        await _waitFor(() => env.service.state.phase == WorkspacePhase.ready);
        final snapshot = await env.journal.localSnapshot('srv-a');
        expect(snapshot.keys, contains('config\x00command/cA'));
        env.service.dispose();

        // The process dies before the debounced outbox sees this write.
        await env.storage.workspacePreferences.setString(
          'valhalla_quick_commands_v1',
          jsonEncode([
            {'id': 'cA', 'title': 'A', 'command': 'echo a'},
            {'id': 'cB', 'title': 'B', 'command': 'echo b'},
          ]),
        );

        final restarted = RemoteWorkspaceService(
          storage: env.storage,
          manager: env.manager,
          deviceClass: 'desktop',
          onChanged: (_) {},
          onHydrated: (_) {},
          client: env.client,
          journal: env.journal,
        );
        addTearDown(restarted.dispose);
        await _activate(restarted, _serverA);
        await restarted.syncNow();
        await _waitFor(
          () => env.client
              .store('srv-a')
              .records
              .containsKey('config\x00command/cB'),
        );

        final records = env.client.store('srv-a').records;
        expect(records.keys, contains('config\x00command/cA'));
        expect(records.keys, contains('config\x00command/cB'));
        final lastCommit = env.client.store('srv-a').commits.last;
        final committed = (lastCommit['records'] as List)
            .map((r) => (r as Map)['id'])
            .toList();
        expect(committed, ['command/cB']);
        expect(
          (await env.journal.localSnapshot('srv-a')).keys,
          contains('config\x00command/cB'),
        );
      },
    );

    test('local write racing remote hydration retries the same page', () async {
      final journal = _RacingJournal(
        databasePath:
            '${(await Directory.systemTemp.createTemp('rws-race')).path}/j.sqlite3',
      );
      final env = await _env(journal: journal);
      env.client.store('srv-a').exists = false;
      await _activate(env.service, _serverA);
      await env.service.enable();
      await _waitFor(() => env.service.state.phase == WorkspacePhase.ready);
      expect(_meta(env.storage, 'srv-a')['revision'], 0);

      env.client
          .store('srv-a')
          .put(
            kind: 'config',
            id: 'command/remote',
            value: {
              'storageKey': 'valhalla_quick_commands_v1',
              'item': {'id': 'remote', 'title': 'Remote', 'command': 'echo r'},
            },
          );
      journal.onReceive = () async {
        await env.storage.workspacePreferences.setString(
          'valhalla_quick_commands_v1',
          jsonEncode([
            {'id': 'local', 'title': 'Local', 'command': 'echo l'},
          ]),
        );
      };

      await env.service.syncNow();
      // The cursor must not advance before the concurrent local write is
      // durable and the page is re-read.
      expect(_meta(env.storage, 'srv-a')['revision'], 0);
      expect(
        _commands(env.storage).map((c) => c['id']),
        isNot(contains('remote')),
      );

      await env.service.syncNow();
      expect(_meta(env.storage, 'srv-a')['revision'], 1);
      expect(_commands(env.storage).map((c) => c['id']), contains('remote'));
    });

    test(
      'other-device drafts and other-device-class preferences are skipped',
      () async {
        final env = await _env();
        env.client.store('srv-a').exists = false;
        await _activate(env.service, _serverA);
        await env.service.enable();
        await _waitFor(() => env.service.state.phase == WorkspacePhase.ready);

        env.client.store('srv-a')
          ..put(
            kind: 'draft',
            id: 'other-device/valhalla_chat_draft_v1::srv-a',
            value: {
              'key': 'valhalla_chat_draft_v1::srv-a',
              'deviceId': 'other-device',
              'value': {'string': 'secret'},
            },
          )
          ..put(
            kind: 'preference',
            id: 'tablet/valhalla_theme_mode_v1',
            value: {'key': 'valhalla_theme_mode_v1', 'value': 'dark'},
          )
          ..put(
            kind: 'draft',
            id: 'other-device/valhalla_chat_draft_v1::srv-a',
            value: {
              'key': 'valhalla_chat_draft_v1::srv-a',
              'deviceId': 'other-device',
              'value': {'string': 'secret'},
            },
            deleted: true,
          )
          ..put(
            kind: 'preference',
            id: 'tablet/valhalla_theme_mode_v1',
            value: {'key': 'valhalla_theme_mode_v1', 'value': 'dark'},
            deleted: true,
          );
        await env.service.syncNow();

        expect(
          env.storage.workspacePreferences.getString(
            'valhalla_chat_draft_v1::srv-a',
          ),
          isNull,
        );
        expect(
          env.storage.workspacePreferences.getString('valhalla_theme_mode_v1'),
          isNull,
        );
        expect(await env.journal.pending('srv-a'), isEmpty);
        expect(await env.journal.localSnapshot('srv-a'), isEmpty);
        expect(_meta(env.storage, 'srv-a')['revision'], 4);
      },
    );

    test('disable during an in-flight sync stops remote application', () async {
      final env = await _env();
      env.client.store('srv-a').exists = false;
      await _activate(env.service, _serverA);
      await env.service.enable();
      await _waitFor(() => env.service.state.phase == WorkspacePhase.ready);

      final store = env.client.store('srv-a');
      store.put(
        kind: 'config',
        id: 'command/late',
        value: {
          'storageKey': 'valhalla_quick_commands_v1',
          'item': {'id': 'late', 'title': 'Late', 'command': 'echo late'},
        },
      );
      store.changesGate = Completer<void>();
      store.changesStarted = Completer<void>();
      final syncing = env.service.syncNow();
      await store.changesStarted!.future;
      await env.service.disable();
      store.changesGate!.complete();
      await syncing;

      expect(_commands(env.storage), isEmpty);
      expect(_meta(env.storage, 'srv-a')['revision'], 0);
      expect(env.service.state.enabled, isFalse);
    });
  });

  group('RemoteWorkspaceService safety', () {
    test('future remote schema is rejected before install', () async {
      final env = await _env();
      env.client.store('srv-a')
        ..exists = true
        ..schema = 2;
      await _activate(env.service, _serverA);
      await env.service.enable();

      expect(env.client.store('srv-a').installCalls, 0);
      expect(env.service.state.error, 'WORKSPACE_SCHEMA_UNSUPPORTED');
      expect(_meta(env.storage, 'srv-a')['enabled'], isNot(true));
    });

    test('newer remote component is rejected before install', () async {
      final env = await _env();
      env.client.store('srv-a')
        ..exists = true
        ..component = RemoteWorkspaceClient.componentVersion + 1;
      await _activate(env.service, _serverA);
      await env.service.enable();

      expect(env.client.store('srv-a').installCalls, 0);
      expect(env.service.state.error, 'WORKSPACE_COMPONENT_UNSUPPORTED');
    });

    test('corrupt binding metadata is not overwritten or crashed on', () async {
      final env = await _env(
        prefs: {'valhalla_workspace_binding_v1::srv-a': '{bad json'},
      );
      await _activate(env.service, _serverA);
      expect(env.service.state.error, 'WORKSPACE_LOCAL_CORRUPT');
      await env.service.enable();
      expect(env.service.state.error, 'WORKSPACE_LOCAL_CORRUPT');
      expect(
        env.storage.workspacePreferences.raw.getString(
          'valhalla_workspace_binding_v1::srv-a',
        ),
        '{bad json',
      );
    });

    test(
      'corrupt local configuration yields a stable error and keeps bytes',
      () async {
        final env = await _env(
          prefs: {'valhalla_quick_commands_v1': '{bad json'},
        );
        await _activate(env.service, _serverA);
        await _waitFor(
          () => env.service.state.error == 'WORKSPACE_LOCAL_CORRUPT',
        );
        expect(
          env.storage.workspacePreferences.getString(
            'valhalla_quick_commands_v1',
          ),
          '{bad json',
        );
      },
    );

    test('remote metadata is only hydrated for remote changes', () async {
      final env = await _env();
      env.client.store('srv-a').exists = false;
      await _activate(env.service, _serverA);
      await env.service.enable();
      await _waitFor(() => env.service.state.phase == WorkspacePhase.ready);
      expect(env.hydrated, isEmpty);

      // A local write is acknowledged by our own commit; it must not look like
      // remote hydration and restart settings/agent work.
      await env.storage.workspacePreferences.setString(
        'valhalla_quick_commands_v1',
        jsonEncode([
          {'id': 'own', 'title': 'Own', 'command': 'echo own'},
        ]),
      );
      await pumpEventQueue();
      await env.service.syncNow();
      expect(env.hydrated, isEmpty);

      env.client
          .store('srv-a')
          .put(
            kind: 'config',
            id: 'command/remote',
            value: {
              'storageKey': 'valhalla_quick_commands_v1',
              'item': {'id': 'remote', 'title': 'Remote', 'command': 'echo r'},
            },
          );
      await env.service.syncNow();
      expect(env.hydrated, hasLength(1));
      expect(env.hydrated.single.records.single['id'], 'command/remote');
    });
  });

  group('RemoteWorkspaceService preflight', () {
    Future<void> preflightRejects(
      Map<String, dynamic> discovery,
      String expectedCode,
    ) async {
      final client = _DiscoveryClient();
      final env = await _env(customClient: client);
      client.store('srv-a').exists = true;
      client.discovery = discovery;
      final ssh = env.manager.getClient('srv-a')!;
      expect(
        () => client.preflight(ssh),
        throwsA(
          isA<WorkspaceException>().having((e) => e.code, 'code', expectedCode),
        ),
      );
    }

    test('malformed schema is refused', () async {
      await preflightRejects({
        'ok': true,
        'exists': true,
        'workspaceId': 'ws-1',
        'schema': 'bad',
        'user': 'dev',
      }, 'WORKSPACE_SCHEMA_UNSUPPORTED');
    });

    test('future schema is refused', () async {
      await preflightRejects({
        'ok': true,
        'exists': true,
        'workspaceId': 'ws-1',
        'schema': RemoteWorkspaceClient.schemaVersion + 1,
        'user': 'dev',
      }, 'WORKSPACE_SCHEMA_UNSUPPORTED');
    });

    test('malformed component is refused', () async {
      await preflightRejects({
        'ok': true,
        'exists': true,
        'workspaceId': 'ws-1',
        'schema': 1,
        'component': 'bad',
        'user': 'dev',
      }, 'WORKSPACE_COMPONENT_UNSUPPORTED');
    });

    test('future component is refused', () async {
      await preflightRejects({
        'ok': true,
        'exists': true,
        'workspaceId': 'ws-1',
        'schema': 1,
        'component': RemoteWorkspaceClient.componentVersion + 1,
        'user': 'dev',
      }, 'WORKSPACE_COMPONENT_UNSUPPORTED');
    });

    test('present supported schema/component is accepted', () async {
      final client = _DiscoveryClient();
      final env = await _env(customClient: client);
      client.store('srv-a').exists = true;
      client.discovery = {
        'ok': true,
        'exists': true,
        'workspaceId': 'ws-1',
        'schema': 1,
        'component': RemoteWorkspaceClient.componentVersion,
        'user': 'dev',
      };
      final ssh = env.manager.getClient('srv-a')!;
      expect(() => client.preflight(ssh), returnsNormally);
    });
  });

  group('RemoteWorkspaceService draft restore', () {
    WorkspaceDraft draft(String id, Map<String, dynamic> value) =>
        WorkspaceDraft(
          id: id,
          deviceId: value['deviceId'] as String,
          title: value['key'] as String? ?? id,
          value: value,
        );

    test(
      'foreign draft restore keeps a recoverable backup of the original target',
      () async {
        final env = await _env();
        const targetLocal = 'valhalla_chat_draft_v1::srv-a::target1';
        const targetRemote = 'valhalla_chat_draft_v1::@server::target1';
        await env.storage.workspacePreferences.setString(
          targetLocal,
          'original-content',
        );
        env.client.store('srv-a').exists = false;
        await _activate(env.service, _serverA);
        await env.service.enable();
        await _waitFor(() => env.service.state.phase == WorkspacePhase.ready);

        final foreign = draft('foreign-device/$targetRemote', {
          'key': targetRemote,
          'deviceId': 'foreign-device',
          'value': {'string': 'foreign-content'},
        });

        await env.service.restoreDraft(foreign);

        // The target now holds the foreign content.
        expect(
          env.storage.workspacePreferences.getString(targetLocal),
          'foreign-content',
        );

        // restoreDraft awaited syncNow, so the backup is already committed to
        // the remote store (not lingering in the local outbox). The codec skips
        // ::backup:: on normal hydration, preserving restoreKey remotely.
        final store = env.client.store('srv-a');
        final backups = store.records.values
            .where((r) => (r['id'] as String).contains('backup'))
            .toList();
        expect(backups, hasLength(1));
        final backupValue = backups.first['value'] as Map<String, dynamic>;
        expect(backupValue['restoreKey'], targetRemote);
        expect(backupValue['value'], {'string': 'original-content'});

        // Restoring the backup puts the original content back on the target.
        await env.service.restoreDraft(
          draft(backups.first['id'] as String, backupValue),
        );
        expect(
          env.storage.workspacePreferences.getString(targetLocal),
          'original-content',
        );

        // Sync (already triggered by restoreDraft) and a restart must not stall.
        await env.service.syncNow();
        final restarted = RemoteWorkspaceService(
          storage: env.storage,
          manager: env.manager,
          deviceClass: 'desktop',
          onChanged: (_) {},
          onHydrated: (_) {},
          client: env.client,
          journal: env.journal,
        );
        addTearDown(restarted.dispose);
        await _activate(restarted, _serverA);
        await restarted.syncNow();
        await _waitFor(() => !restarted.state.isBusy);
      },
    );

    test('invalid foreign-scope draft queues nothing', () async {
      final env = await _env();
      const targetLocal = 'valhalla_chat_draft_v1::srv-a::target1';
      const badRemote = 'valhalla_chat_draft_v1::srv-other::x';
      await env.storage.workspacePreferences.setString(
        targetLocal,
        'original-content',
      );
      env.client.store('srv-a').exists = false;
      await _activate(env.service, _serverA);
      await env.service.enable();
      await _waitFor(() => env.service.state.phase == WorkspacePhase.ready);

      final invalid = draft('foreign-device/$badRemote', {
        'key': badRemote,
        'deviceId': 'foreign-device',
        'value': {'string': 'nope'},
      });

      // The scope check is a stable FormatException before any queueing.
      expect(
        () => env.service.restoreDraft(invalid),
        throwsA(isA<FormatException>()),
      );
      expect(await env.journal.pending('srv-a'), isEmpty);
    });
  });

  group('RemoteWorkspaceService device drafts', () {
    test(
      'loadDeviceDrafts paginates with append and reports draftsHaveMore',
      () async {
        final env = await _env();
        env.client.store('srv-a').exists = false;
        await _activate(env.service, _serverA);
        await env.service.enable();
        await _waitFor(() => env.service.state.phase == WorkspacePhase.ready);

        // Seed more than one page (>100) so the first request cannot hold them.
        final store = env.client.store('srv-a');
        for (var i = 0; i < 120; i++) {
          store.put(
            kind: 'draft',
            id: 'dev-1/valhalla_chat_draft_v1::srv-a::d$i',
            value: {
              'key': 'valhalla_chat_draft_v1::srv-a::d$i',
              'deviceId': 'dev-1',
              'value': {'string': 'd$i'},
            },
          );
        }

        await env.service.loadDeviceDrafts();
        expect(env.service.state.draftsHaveMore, isTrue);
        expect(env.service.state.devicesDrafts, hasLength(100));

        await env.service.loadDeviceDrafts(append: true);
        expect(env.service.state.draftsHaveMore, isFalse);
        expect(env.service.state.devicesDrafts, hasLength(120));
      },
    );
  });

  group('RemoteWorkspaceService batching', () {
    Map<String, Object> commands(int count) => {
      'valhalla_quick_commands_v1': jsonEncode([
        for (var i = 0; i < count; i++)
          {'id': 'c$i', 'title': 'C$i', 'command': 'echo $i'},
      ]),
    };

    test(
      'more than one page commits in bounded batches and drains every ack',
      () async {
        const count = 130;
        final env = await _env(prefs: commands(count));
        env.client.store('srv-a').exists = false;
        await _activate(env.service, _serverA);
        await env.service.enable();
        await _waitFor(() => !env.service.state.isBusy);

        final store = env.client.store('srv-a');
        expect(
          store.records.keys.where(
            (key) => key.startsWith('config\x00command/'),
          ),
          hasLength(count),
        );
        expect(store.commits, isNotEmpty);
        // A real commit is a request carrying the record list, not a journal
        // acknowledgement. Two pages of 130 records must not be 130 calls.
        expect(store.commits.length, lessThan(count));
        for (final commit in store.commits) {
          final records = commit['records'] as List;
          expect(records.length, lessThanOrEqualTo(100));
          expect(
            utf8.encode(jsonEncode(records)).length,
            lessThanOrEqualTo(512 * 1024),
          );
        }
        expect(
          store.commits.fold<int>(
            0,
            (total, commit) => total + (commit['records'] as List).length,
          ),
          count,
        );
        expect(await env.journal.pending('srv-a'), isEmpty);
        expect(await env.journal.pendingCount('srv-a'), 0);
      },
    );

    test(
      'a CAS conflict survives while unrelated records commit next batch',
      () async {
        final env = await _env();
        env.client.store('srv-a').exists = false;
        await _activate(env.service, _serverA);
        await env.service.enable();
        await _waitFor(() => env.service.state.phase == WorkspacePhase.ready);
        final store = env.client.store('srv-a');

        // This device already saw c0 at version 5, so its cursor advances.
        store.put(
          kind: 'config',
          id: 'command/c0',
          value: {
            'storageKey': 'valhalla_quick_commands_v1',
            'item': {'id': 'c0', 'title': 'Remote', 'command': 'echo remote'},
          },
          version: 5,
        );
        await env.service.syncNow();
        expect(_meta(env.storage, 'srv-a')['revision'], 5);
        expect(_commands(env.storage).single['title'], 'Remote');
        final baseline = store.commits.length;

        // Stage a stale edit of c0 plus 129 unrelated records. The stale edit
        // is based on version 0 while the server holds version 5.
        await env.journal.queue('srv-a', [
          {
            'kind': 'config',
            'id': 'command/c0',
            'value': {
              'storageKey': 'valhalla_quick_commands_v1',
              'item': {'id': 'c0', 'title': 'Local', 'command': 'echo local'},
            },
          },
          for (var i = 1; i < 130; i++)
            {
              'kind': 'config',
              'id': 'command/c$i',
              'value': {
                'storageKey': 'valhalla_quick_commands_v1',
                'item': {'id': 'c$i', 'title': 'C$i', 'command': 'echo $i'},
              },
            },
        ], forceBaseZero: true);
        await env.service.syncNow();

        final conflicts = await env.journal.pending('srv-a', conflicts: true);
        expect(conflicts, hasLength(1));
        expect(conflicts.single['id'], 'command/c0');
        expect(await env.journal.pendingCount('srv-a'), 1);
        expect(
          (await env.journal.cached(
            'srv-a',
            'config',
            'command/c0',
          ))!['version'],
          5,
        );

        // Every unrelated record landed; the conflicting one still holds the
        // remote value and was never overwritten.
        for (var i = 1; i < 130; i++) {
          expect(store.records.keys, contains('config\x00command/c$i'));
        }
        expect(
          ((store.records['config\x00command/c0']!['value'] as Map)['item']
              as Map)['title'],
          'Remote',
        );

        final attempted = store.commits.skip(baseline).toList();
        expect(attempted, hasLength(3));
        expect(
          (attempted.first['records'] as List).map((r) => (r as Map)['id']),
          contains('command/c0'),
        );
        final successful = attempted.skip(1);
        expect(
          successful.fold<int>(
            0,
            (total, commit) => total + (commit['records'] as List).length,
          ),
          129,
        );
        expect(
          successful
              .expand((commit) => commit['records'] as List)
              .map((r) => (r as Map)['id']),
          isNot(contains('command/c0')),
        );
      },
    );
  });

  group('RemoteWorkspaceService version and identity guards', () {
    test(
      'a component bump between syncs commits nothing and keeps pending work',
      () async {
        final env = await _env(
          prefs: {
            'valhalla_quick_commands_v1': jsonEncode([
              {'id': 'c1', 'title': 'C1', 'command': 'echo 1'},
            ]),
          },
        );
        env.client.store('srv-a').exists = false;
        await _activate(env.service, _serverA);
        await env.service.enable();
        await _waitFor(() => env.service.state.phase == WorkspacePhase.ready);
        final store = env.client.store('srv-a');
        final baseline = store.commits.length;
        expect(baseline, greaterThan(0));

        // The same already validated SSH client now points at a newer
        // component. Every sync invalidates the memo, so this must be seen.
        store.component = RemoteWorkspaceClient.componentVersion + 1;
        await env.storage.workspacePreferences.setString(
          'valhalla_quick_commands_v1',
          jsonEncode([
            {'id': 'c1', 'title': 'C1', 'command': 'echo 1'},
            {'id': 'c2', 'title': 'C2', 'command': 'echo 2'},
          ]),
        );
        await env.service.syncNow();

        expect(store.commits.length, baseline);
        expect(env.service.state.error, 'WORKSPACE_COMPONENT_UNSUPPORTED');
        final pending = await env.journal.pending('srv-a');
        expect(pending.map((record) => record['id']), contains('command/c2'));
      },
    );

    test(
      'a changed workspace identity is refused on the same client',
      () async {
        final env = await _env();
        env.client.store('srv-a').exists = false;
        await _activate(env.service, _serverA);
        await env.service.enable();
        await _waitFor(() => env.service.state.phase == WorkspacePhase.ready);
        final store = env.client.store('srv-a');
        final baseline = store.commits.length;

        store.workspaceId = 'ws-2';
        await env.storage.workspacePreferences.setString(
          'valhalla_quick_commands_v1',
          jsonEncode([
            {'id': 'local', 'title': 'Local', 'command': 'echo local'},
          ]),
        );
        await env.service.syncNow();

        expect(store.commits.length, baseline);
        expect(env.service.state.error, 'WORKSPACE_IDENTITY_CHANGED');
        expect(
          (await env.journal.pending('srv-a')).map((record) => record['id']),
          contains('command/local'),
        );
      },
    );
  });

  group('RemoteWorkspaceService remote record boundaries', () {
    test(
      'an own typed file draft is cached, never applied or tombstoned',
      () async {
        final env = await _env();
        env.client.store('srv-a').exists = false;
        await _activate(env.service, _serverA);
        await env.service.enable();
        await _waitFor(() => env.service.state.phase == WorkspacePhase.ready);

        const path = '/srv/app/config.yml';
        const content = 'typed file draft body';
        final pathHash = sha256.convert(utf8.encode(path)).toString();
        final id = '${env.service.deviceId}/file/$pathHash';
        final store = env.client.store('srv-a');
        store.put(
          kind: 'draft',
          id: id,
          value: {
            'type': 'file',
            'deviceId': env.service.deviceId,
            'path': path,
            'digest': sha256.convert(utf8.encode('revision')).toString(),
            'blob': {
              'hash': sha256.convert(utf8.encode(content)).toString(),
              'size': utf8.encode(content).length,
            },
          },
        );
        final remoteVersion = store.records['draft\x00$id']!['version'];
        final commitsBefore = store.commits.length;
        final changes = <WorkspaceChange>[];
        final subscription = env.service.changes.listen(changes.add);
        addTearDown(subscription.cancel);

        await env.service.syncNow();

        expect(
          changes
              .expand((change) => change.records)
              .map((record) => record['id']),
          contains(id),
        );
        expect(
          (await env.journal.cached('srv-a', 'draft', id))!['version'],
          remoteVersion,
        );
        // The file draft is a blob reference, not text: the config codec must
        // never materialise it into SharedPreferences.
        expect(
          env.storage.workspacePreferences.getKeys().where(
            (key) => key.startsWith('valhalla_chat_draft_v1::'),
          ),
          isEmpty,
        );
        expect(store.commits.length, commitsBefore);
        expect(await env.journal.pending('srv-a'), isEmpty);

        // Restarting with the same journal must not turn the absence of a
        // local text draft into a delete record.
        env.service.dispose();
        final restarted = RemoteWorkspaceService(
          storage: env.storage,
          manager: env.manager,
          deviceClass: 'desktop',
          onChanged: (_) {},
          onHydrated: (_) {},
          client: env.client,
          journal: env.journal,
        );
        addTearDown(restarted.dispose);
        await _activate(restarted, _serverA);
        await restarted.syncNow();
        await _waitFor(() => !restarted.state.isBusy);

        expect(store.commits.length, commitsBefore);
        expect(store.records['draft\x00$id']!['deleted'], isFalse);
        expect(await env.journal.pending('srv-a'), isEmpty);
        expect(
          (await env.journal.cached('srv-a', 'draft', id))!['version'],
          remoteVersion,
        );
      },
    );

    test(
      'a chat_session tombstone is emitted outside the catalog window',
      () async {
        final env = await _env();
        env.client.store('srv-a').exists = false;
        await _activate(env.service, _serverA);
        await env.service.enable();
        await _waitFor(() => env.service.state.phase == WorkspacePhase.ready);

        final store = env.client.store('srv-a');
        // Old enough to sit outside any bounded recent-session page; the
        // change stream still has to surface its metadata tombstone.
        store.put(
          kind: 'chat_session',
          id: 'old-session',
          value: {
            'serverId': '@server',
            'id': 'old-session',
            'title': 'Old session',
            'agentId': 'builtin-codex',
            'updatedAt': '2019-01-01T00:00:00.000Z',
          },
          deleted: true,
        );
        final changes = <WorkspaceChange>[];
        final subscription = env.service.changes.listen(changes.add);
        addTearDown(subscription.cancel);

        await env.service.syncNow();

        final emitted = changes
            .expand((change) => change.records)
            .where((record) => record['kind'] == 'chat_session')
            .toList();
        expect(emitted, hasLength(1));
        expect(emitted.single['id'], 'old-session');
        expect(emitted.single['deleted'], isTrue);
        final value = emitted.single['value'] as Map;
        expect(value['title'], 'Old session');
        expect(value.keys, isNot(contains('messages')));
        expect(value.keys, isNot(contains('transcript')));
        final cached = await env.journal.cached(
          'srv-a',
          'chat_session',
          'old-session',
        );
        expect(cached!['deleted'], isTrue);
        expect(cached['value'], value);
      },
    );
  });
}
