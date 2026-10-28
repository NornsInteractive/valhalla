import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/application_center_provider.dart';
import 'package:valhalla/core/providers/file_bookmarks_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/core/services/application_catalog_service.dart';
import 'package:valhalla/core/services/application_deployment_service.dart';
import 'package:valhalla/data/models/application_center.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/workspace/workspace_gateway.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:xterm/xterm.dart';

import '../support/application_center_fakes.dart';

class _FakeGateway implements WorkspaceGateway {
  final controller = StreamController<WorkspaceChange>.broadcast();

  @override
  String get deviceId => 'test-device';

  @override
  bool isEnabled(String serverId) => true;

  @override
  Future<Map<String, dynamic>> request(
    String serverId,
    Map<String, dynamic> command,
  ) async => const {};

  @override
  Future<void> putRecords(
    String serverId,
    List<Map<String, dynamic>> records,
  ) async {}

  @override
  Stream<WorkspaceChange> get changes => controller.stream;

  Future<void> emit(String serverId, List<Map<String, dynamic>> records) async {
    controller.add(WorkspaceChange(serverId, records));
    await settle();
  }

  Future<void> close() => controller.close();
}

Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _server = ServerProfile(
  id: 'srv-1',
  name: 'first server',
  host: 'a.example.test',
  username: 'root',
);
const _second = ServerProfile(
  id: 'srv-2',
  name: 'second server',
  host: 'b.example.test',
  username: 'root',
);

class _Active extends ActiveServerNotifier {
  _Active([this.initial = _server]);
  final ServerProfile? initial;
  @override
  ServerProfile? build() => initial;
  void select(ServerProfile? next) => state = next;
}

class _Connection extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-1',
  );
}

class _Servers extends ServerListNotifier {
  @override
  List<ServerProfile> build() => const [_server, _second];
}

class _Bridge extends TerminalSessionBridge {
  _Bridge() : super(terminal: Terminal(), serverName: 'test');

  bool disposed = false;

  @override
  TerminalConnectionState get state => TerminalConnectionState.connected;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _SeededTerminal extends TerminalNotifier {
  _SeededTerminal(this.initial);
  final SshTerminalState initial;

  @override
  SshTerminalState build() {
    final empty = super.build();
    updateShouldNotify(empty, initial);
    return initial;
  }
}

TmuxSessionIdentity _identity(int session) => TmuxSessionIdentity(
  sessionId: '\$$session',
  createdSeconds: 1,
  serverPid: 10,
  socketPath: '/tmp/tmux-1000/valhalla',
);

TerminalHistoryRecord _record(
  String id,
  TmuxSessionIdentity identity, {
  String title = 'shell',
}) => TerminalHistoryRecord(
  id: id,
  serverId: _server.id,
  targetKey: TerminalHistoryRecord.targetFor(_server),
  remoteSessionName: 'valhalla_$id',
  title: title,
  createdAt: DateTime.utc(2026),
  lastUsedAt: DateTime.utc(2026),
  identity: identity,
);

Map<String, dynamic> _terminalRecord(String key) => {
  'kind': 'config',
  'id': key,
};

Future<
  ({
    ProviderContainer container,
    LocalStorageService storage,
    _FakeGateway gateway,
  })
>
_terminalEnv(SshTerminalState initial) async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  final gateway = _FakeGateway();
  storage.workspaceGateway = gateway;
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      activeServerProvider.overrideWith(_Active.new),
      serverListProvider.overrideWith(_Servers.new),
      serverConnectionProvider.overrideWith(_Connection.new),
      terminalProvider.overrideWith(() => _SeededTerminal(initial)),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(gateway.close);
  container.read(terminalProvider);
  return (container: container, storage: storage, gateway: gateway);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('terminal metadata hot refresh', () {
    test(
      'default/socket keys replace history, default, sources and hidden ids without rebuilding tabs',
      () async {
        final target = TerminalHistoryRecord.targetFor(_server);
        final first = _record('first', _identity(1));
        final tab = TerminalTab(
          id: first.id,
          title: first.title,
          terminal: Terminal(),
          bridge: _Bridge(),
        );
        final env = await _terminalEnv(
          SshTerminalState(
            tabs: [tab],
            history: [first],
            historyStatuses: {first.id: TerminalHistoryStatus.open},
          ),
        );
        final extra = TmuxSocketSource.named('extra');
        final second = _record('second', _identity(2));
        await env.storage.saveTerminalHistory(
          _server.id,
          target,
          TerminalHistorySnapshot(
            records: [first, second],
            defaultRecordId: second.id,
            socketSources: [extra],
            hiddenRecordIds: [second.id],
            forgottenSessionNames: ['valhalla_gone'],
          ),
        );

        // Only the legacy default key changes: the refresh must still run.
        await env.gateway.emit(_server.id, [
          _terminalRecord('valhalla_terminal_default_v1::@server::@terminal'),
        ]);

        final state = env.container.read(terminalProvider);
        expect(state.history.map((record) => record.id), [first.id, second.id]);
        expect(state.defaultHistoryId, second.id);
        expect(state.socketSources.map((source) => source.id), [extra.id]);
        expect(state.hiddenRecordIds, [second.id]);
        expect(state.tabs.single, same(tab));
        expect(identical(state.tabs.single.terminal, tab.terminal), isTrue);
        expect((tab.bridge as _Bridge).disposed, isFalse);
        // Same real tmux identity keeps its live status; new records are unknown.
        expect(state.historyStatuses[first.id], TerminalHistoryStatus.open);
        expect(state.historyStatuses[second.id], TerminalHistoryStatus.unknown);
      },
    );

    test('changed tmux identity drops the preserved status', () async {
      final target = TerminalHistoryRecord.targetFor(_server);
      final first = _record('first', _identity(1));
      final env = await _terminalEnv(
        SshTerminalState(
          tabs: const [],
          history: [first],
          historyStatuses: {first.id: TerminalHistoryStatus.open},
        ),
      );
      await env.storage.saveTerminalHistory(
        _server.id,
        target,
        TerminalHistorySnapshot(records: [_record('first', _identity(9))]),
      );

      await env.gateway.emit(_server.id, [
        _terminalRecord('valhalla_terminal_history_v2::@server::@terminal'),
      ]);

      expect(
        env.container.read(terminalProvider).historyStatuses[first.id],
        TerminalHistoryStatus.unknown,
      );
    });

    test(
      'events for another server never touch the active workspace',
      () async {
        final first = _record('first', _identity(1));
        final env = await _terminalEnv(
          SshTerminalState(tabs: const [], history: [first]),
        );
        final before = env.container.read(terminalProvider);

        await env.gateway.emit(_second.id, [
          _terminalRecord('valhalla_terminal_history_v2::@server::@terminal'),
        ]);

        expect(identical(env.container.read(terminalProvider), before), isTrue);
      },
    );
  });

  group('bookmark/recent metadata hot refresh', () {
    Future<
      ({
        ProviderContainer container,
        LocalStorageService storage,
        _FakeGateway gateway,
      })
    >
    env() async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      final gateway = _FakeGateway();
      storage.workspaceGateway = gateway;
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          activeServerProvider.overrideWith(_Active.new),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(gateway.close);
      return (container: container, storage: storage, gateway: gateway);
    }

    test(
      'empty polls and unrelated records do not rebuild bookmark state',
      () async {
        final e = await env();
        await e.storage.saveFileBookmarks(_server.id, ['/a']);
        final before = e.container.read(fileBookmarksProvider);

        await e.gateway.emit(_server.id, const []);
        await e.gateway.emit(_server.id, [
          {'kind': 'config', 'id': 'valhalla_agents_v1/x'},
        ]);

        expect(
          identical(e.container.read(fileBookmarksProvider), before),
          isTrue,
        );
      },
    );

    test(
      'relevant bookmark record refreshes only the current server',
      () async {
        final e = await env();
        await e.storage.saveFileBookmarks(_server.id, ['/a']);
        final before = e.container.read(fileBookmarksProvider);

        await e.storage.saveFileBookmarks(_server.id, ['/a', '/b']);
        await e.gateway.emit(_second.id, [
          {'kind': 'config', 'id': 'valhalla_file_bookmarks::@server'},
        ]);
        expect(
          identical(e.container.read(fileBookmarksProvider), before),
          isTrue,
        );

        await e.gateway.emit(_server.id, [
          {'kind': 'config', 'id': 'valhalla_file_bookmarks::@server'},
        ]);
        expect(e.container.read(fileBookmarksProvider), ['/a', '/b']);
      },
    );

    test(
      'relevant records with identical mirror data do not rebuild',
      () async {
        final e = await env();
        await e.storage.saveFileBookmarks(_server.id, ['/a']);
        await e.storage.saveRecentDirectories(_server.id, ['/one']);
        final bookmarks = e.container.read(fileBookmarksProvider);
        final recent = e.container.read(fileRecentDirectoriesProvider);

        await e.gateway.emit(_server.id, [
          {'kind': 'config', 'id': 'valhalla_file_bookmarks::@server'},
          {'kind': 'config', 'id': 'valhalla_recent_directories::@server'},
        ]);

        expect(
          identical(e.container.read(fileBookmarksProvider), bookmarks),
          isTrue,
        );
        expect(
          identical(e.container.read(fileRecentDirectoriesProvider), recent),
          isTrue,
        );
      },
    );

    test('recent directories refresh on their own record key', () async {
      final e = await env();
      await e.storage.saveRecentDirectories(_server.id, ['/one']);
      final before = e.container.read(fileRecentDirectoriesProvider);

      await e.gateway.emit(_server.id, const []);
      expect(
        identical(e.container.read(fileRecentDirectoriesProvider), before),
        isTrue,
      );

      await e.storage.saveRecentDirectories(_server.id, ['/one', '/two']);
      await e.gateway.emit(_server.id, [
        {'kind': 'config', 'id': 'valhalla_recent_directories::@server'},
      ]);
      expect(e.container.read(fileRecentDirectoriesProvider), ['/one', '/two']);
    });
  });

  group('application center metadata hot refresh', () {
    late LocalStorageService storage;
    late _FakeGateway gateway;
    late _TrackingCatalog catalog;
    late ProviderContainer container;

    Future<void> setup() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService(await SharedPreferences.getInstance());
      gateway = _FakeGateway();
      storage.workspaceGateway = gateway;
      catalog = _TrackingCatalog();
      container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          applicationCatalogServiceProvider.overrideWithValue(catalog),
          applicationDeploymentServiceProvider.overrideWithValue(
            CenterDeploymentService(),
          ),
          activeServerProvider.overrideWith(CenterActiveServer.new),
          serverConnectionProvider.overrideWith(CenterConnection.new),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(gateway.close);
    }

    ApplicationDeployment deployment(ServerProfile server, String id) =>
        ApplicationDeployment(
          id: id,
          serverKey: ApplicationDeploymentService.serverKey(server),
          serverId: server.id,
          sourceId: 'fixture',
          appId: 'fixture',
          name: 'App $id',
          project: 'project-$id',
          directory: '/home/dev/$id',
          targetIdentity: centerEnvironment(server).targetIdentity,
          status: 'running',
        );

    Future<void> seedDeployments(
      ServerProfile server,
      List<ApplicationDeployment> deployments,
    ) => storage.saveApplicationCenterRecords(
      'deployments',
      ApplicationDeploymentService.serverKey(server),
      deployments.map((deployment) => deployment.toJson()).toList(),
    );

    Map<String, dynamic> deploymentsRecord() => {
      'kind': 'config',
      'id': 'valhalla_app_center_v1::deployments::@target',
    };

    test(
      'active install and its task state survive a remote deletion',
      () async {
        await setup();
        final app = deployment(centerServer, 'installing');
        final task = centerTask(
          app,
        ).copyWith(stage: ApplicationTaskStage.pulling, logTail: 'layer 2/3');
        await seedDeployments(centerServer, [app]);
        await storage.saveApplicationCenterRecords('tasks', app.serverKey, [
          task.toJson(),
        ]);
        container.read(applicationCenterProvider);
        final before = container.read(applicationCenterProvider);

        // Remote record deletion lands in the mirror while the task is busy.
        await seedDeployments(centerServer, const []);
        await gateway.emit(centerServer.id, [deploymentsRecord()]);

        final state = container.read(applicationCenterProvider);
        expect(state.deployments.single.id, app.id);
        expect(state.tasks.single.id, task.id);
        expect(state.tasks.single.stage, ApplicationTaskStage.pulling);
        expect(identical(state.tasks, before.tasks), isTrue);
        expect(identical(state.tasks.single, before.tasks.single), isTrue);
      },
    );

    test('deleting an idle deployment removes it from state', () async {
      await setup();
      final keep = deployment(centerServer, 'keep');
      final gone = deployment(centerServer, 'gone');
      await seedDeployments(centerServer, [keep, gone]);
      container.read(applicationCenterProvider);
      expect(
        container.read(applicationCenterProvider).deployments.map((d) => d.id),
        ['keep', 'gone'],
      );

      await seedDeployments(centerServer, [keep]);
      await gateway.emit(centerServer.id, [deploymentsRecord()]);

      expect(
        container.read(applicationCenterProvider).deployments.map((d) => d.id),
        ['keep'],
      );
    });

    test(
      'changed sources prune catalog and refresh only the new source',
      () async {
        await setup();
        const first = ApplicationSource(
          id: 'first',
          name: 'First',
          url: 'https://first.invalid',
        );
        const second = ApplicationSource(
          id: 'second',
          name: 'Second',
          url: 'https://second.invalid',
        );
        catalog.rows['first'] = [
          const CatalogApplication(
            sourceId: 'first',
            id: 'app',
            title: 'First app',
            composeUrl: 'https://first.invalid/compose',
          ),
        ];
        catalog.rows['second'] = [
          const CatalogApplication(
            sourceId: 'second',
            id: 'app',
            title: 'Second app',
            composeUrl: 'https://second.invalid/compose',
          ),
        ];
        await storage.saveApplicationCenterRecords('sources', 'global', [
          first.toJson(),
        ]);
        container.read(applicationCenterProvider);
        await settle();
        expect(
          container.read(applicationCenterProvider).catalog.single.sourceId,
          'first',
        );

        catalog.refreshed.clear();
        await storage.saveApplicationCenterRecords('sources', 'global', [
          second.toJson(),
        ]);
        await gateway.emit(centerServer.id, [
          {'kind': 'config', 'id': 'valhalla_app_center_v1::sources::global'},
        ]);
        await settle();

        final state = container.read(applicationCenterProvider);
        expect(state.sources.single.id, 'second');
        expect(state.catalog.single.sourceId, 'second');
        expect(state.sourceRefreshedAt.keys, isNot(contains('first')));
        expect(state.sourceErrors.keys, isNot(contains('first')));
        expect(catalog.refreshed, ['second']);
      },
    );

    test(
      'switching servers never leaks the old deployment or accepts its events',
      () async {
        await setup();
        final oldApp = deployment(centerServer, 'old');
        final next = centerServer.copyWith(id: 'next', host: 'next.invalid');
        final newApp = deployment(next, 'new');
        await seedDeployments(centerServer, [oldApp]);
        await seedDeployments(next, [newApp]);
        container.read(applicationCenterProvider);
        expect(
          container.read(applicationCenterProvider).deployments.single.id,
          'old',
        );

        (container.read(activeServerProvider.notifier) as CenterActiveServer)
            .select(next);
        expect(
          container.read(applicationCenterProvider).deployments.single.id,
          'new',
        );

        await gateway.emit(centerServer.id, [deploymentsRecord()]);
        final state = container.read(applicationCenterProvider);
        expect(state.deployments.single.id, 'new');
        expect(state.deployments.single.serverId, next.id);
      },
    );

    test('unchanged deployment mirror does not rebuild state', () async {
      await setup();
      final app = deployment(centerServer, 'app');
      await seedDeployments(centerServer, [app]);
      container.read(applicationCenterProvider);
      await settle();
      final before = container.read(applicationCenterProvider);

      await gateway.emit(centerServer.id, [deploymentsRecord()]);

      expect(
        identical(container.read(applicationCenterProvider), before),
        isTrue,
      );
    });

    test('empty polls and unrelated config never rebuild state', () async {
      await setup();
      container.read(applicationCenterProvider);
      await settle();
      final before = container.read(applicationCenterProvider);
      await gateway.emit(centerServer.id, const []);
      await gateway.emit(centerServer.id, [
        {'kind': 'config', 'id': 'valhalla_agents_v1/x'},
      ]);
      expect(
        identical(container.read(applicationCenterProvider), before),
        isTrue,
      );
    });
  });
}

class _TrackingCatalog extends ApplicationCatalogService {
  final rows = <String, List<CatalogApplication>>{};
  final refreshed = <String>[];

  @override
  Future<List<CatalogApplication>> cached(
    ApplicationSource source, {
    String locale = 'en_US',
  }) async => rows[source.id] ?? const [];

  @override
  Future<DateTime?> cachedAt(
    ApplicationSource source, {
    String locale = 'en_US',
  }) async => null;

  @override
  Future<List<CatalogApplication>> refresh(
    ApplicationSource source, {
    String locale = 'en_US',
  }) async {
    refreshed.add(source.id);
    return rows[source.id] ?? const [];
  }

  @override
  Future<ApplicationTemplate> template(CatalogApplication application) async =>
      centerTemplate;
}
