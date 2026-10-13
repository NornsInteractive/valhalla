import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/application_center_provider.dart';
import 'package:valhalla/core/providers/app_visibility_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/settings_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/application_center.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import '../support/application_center_fakes.dart';

class _FailingStorage extends LocalStorageService {
  _FailingStorage(super.prefs);
  bool failWrites = true;
  @override
  Future<void> saveApplicationCenterRecords(
    String kind,
    String scope,
    List<Map<String, dynamic>> records,
  ) async {
    if (failWrites) throw StateError('save failed');
    await super.saveApplicationCenterRecords(kind, scope, records);
  }
}

class _TaskService extends CenterDeploymentService {
  Future<ApplicationTask> Function(ApplicationTask)? onRead;
  final reads = <ApplicationTask>[];
  int reconciliations = 0;

  @override
  Future<ApplicationTask> readTask(ApplicationTask task) async {
    reads.add(task);
    return onRead == null ? task : onRead!(task);
  }

  @override
  Future<ApplicationDeployment?> reconcile(
    ApplicationDeployment app,
    ApplicationEnvironment env, {
    String? sudoPassword,
  }) async {
    reconciliations++;
    return super.reconcile(app, env, sudoPassword: sudoPassword);
  }
}

class _Catalog extends CenterCatalog {
  bool failNetwork = false, failCache = false;
  List<CatalogApplication> rows = [];
  List<CatalogApplication> cachedRows = [];
  final cachedSources = <String>[];
  final refreshedSources = <String>[];
  final refreshedLocales = <String>[];
  Future<List<CatalogApplication>> Function(ApplicationSource)? onRefresh;
  @override
  Future<List<CatalogApplication>> cached(
    ApplicationSource source, {
    String locale = 'en_US',
  }) async {
    cachedSources.add(source.id);
    if (failCache) throw StateError('cache unreadable');
    return cachedRows.where((row) => row.sourceId == source.id).toList();
  }

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
    refreshedSources.add(source.id);
    refreshedLocales.add(locale);
    if (failNetwork) throw StateError('network unavailable');
    if (onRefresh != null) return onRefresh!(source);
    return rows.where((row) => row.sourceId == source.id).toList();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late LocalStorageService storage;
  late _TaskService service;
  late _Catalog catalog;
  Future<void> setup({bool failingStorage = false}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = failingStorage
        ? _FailingStorage(prefs)
        : LocalStorageService(prefs);
    service = _TaskService();
    catalog = _Catalog();
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        applicationCatalogServiceProvider.overrideWithValue(catalog),
        applicationDeploymentServiceProvider.overrideWithValue(service),
        activeServerProvider.overrideWith(CenterActiveServer.new),
        serverConnectionProvider.overrideWith(CenterConnection.new),
      ],
    );
    container.read(activeServerProvider);
    container.read(serverConnectionProvider);
  }

  setUp(setup);
  tearDown(() => container.dispose());
  void connect(bool connected) =>
      (container.read(serverConnectionProvider.notifier) as CenterConnection)
          .setConnected(connected);
  Future<ApplicationCenterNotifier> seedTask({
    ApplicationTaskStage stage = ApplicationTaskStage.pulling,
  }) async {
    final app = centerDeployment();
    await storage.saveApplicationCenterRecords('deployments', app.serverKey, [
      app.toJson(),
    ]);
    await storage.saveApplicationCenterRecords('tasks', app.serverKey, [
      centerTask(app).copyWith(stage: stage).toJson(),
    ]);
    final notifier = container.read(applicationCenterProvider.notifier);
    connect(true);
    await notifier.refreshServer();
    return notifier;
  }

  test('cache survives disconnect and failed reconciliation', () async {
    final app = centerDeployment();
    await storage.saveApplicationCenterRecords('deployments', app.serverKey, [
      app.toJson(),
    ]);
    await storage.saveApplicationCenterRecords('tasks', app.serverKey, [
      centerTask(app).toJson(),
    ]);
    expect(
      container.read(applicationCenterProvider).deployments.single.name,
      app.name,
    );
    connect(true);
    service.failReconcile = true;
    await container.read(applicationCenterProvider.notifier).refreshServer();
    connect(false);
    expect(
      container.read(applicationCenterProvider).deployments.single.id,
      app.id,
    );
    expect(
      container.read(applicationCenterProvider).tasks.single.id,
      centerTask(app).id,
    );
  });
  test('late old-target inspection cannot overwrite new server data', () async {
    final oldResult = Completer<ApplicationEnvironment>();
    service.onInspect = (server) => server.id == centerServer.id
        ? oldResult.future
        : Future.value(centerEnvironment(server));
    container.read(applicationCenterProvider);
    connect(true);
    final pending = container
        .read(applicationCenterProvider.notifier)
        .refreshServer();
    await Future<void>.delayed(Duration.zero);
    final next = centerServer.copyWith(id: 'next', host: 'next.invalid');
    final app = centerDeployment(next);
    await storage.saveApplicationCenterRecords('deployments', app.serverKey, [
      app.toJson(),
    ]);
    (container.read(activeServerProvider.notifier) as CenterActiveServer)
        .select(next);
    container.read(applicationCenterProvider);
    await container.read(applicationCenterProvider.notifier).refreshServer();
    oldResult.complete(centerEnvironment());
    await pending;
    expect(
      container.read(applicationCenterProvider).environment!.serverId,
      next.id,
    );
    expect(
      container.read(applicationCenterProvider).deployments.single.serverKey,
      app.serverKey,
    );
  });
  test('refresh singleflight waits for the same inspection', () async {
    container.read(applicationCenterProvider);
    await Future<void>.delayed(Duration.zero);
    final gate = Completer<ApplicationEnvironment>();
    service.onInspect = (_) => gate.future;
    connect(true);
    final notifier = container.read(applicationCenterProvider.notifier);
    final first = notifier.refreshServer(), second = notifier.refreshServer();
    expect(identical(first, second), true);
    expect(service.inspections, 1);
    gate.complete(centerEnvironment());
    await first;
  });
  test('intent persists before launch and reconnect never replays', () async {
    container.read(applicationCenterProvider);
    connect(true);
    final notifier = container.read(applicationCenterProvider.notifier);
    final plan = await notifier.prepare(
      ApplicationOperation.install,
      template: centerTemplate,
      configuration: const ApplicationConfiguration(
        name: 'Fixture',
        dataRoot: '/home/dev/data',
      ),
    );
    service.afterPersist = (task) async {
      expect(
        storage
            .getApplicationCenterRecords('tasks', task.serverKey)
            .single['id'],
        task.id,
      );
      expect(service.launches, 0);
    };
    final task = await notifier.execute(plan);
    connect(false);
    expect(container.read(applicationCenterProvider).tasks.single.id, task.id);
    connect(true);
    await notifier.refreshServer();
    expect(service.launches, 1);
  });
  test('failed persistence prevents remote launch', () async {
    container.dispose();
    await setup(failingStorage: true);
    container.read(applicationCenterProvider);
    connect(true);
    final notifier = container.read(applicationCenterProvider.notifier);
    final plan = await notifier.prepare(
      ApplicationOperation.install,
      template: centerTemplate,
      configuration: const ApplicationConfiguration(
        name: 'Fixture',
        dataRoot: '/home/dev/data',
      ),
    );
    await expectLater(notifier.execute(plan), throwsStateError);
    expect(service.launches, 0);
  });

  const source = ApplicationSource(
    id: 'fixture',
    name: 'Fixture',
    url: 'https://fixture.invalid/store',
  );
  const staleCatalogRow = CatalogApplication(
    sourceId: 'fixture',
    id: 'stale',
    title: 'Superseded row',
    composeUrl: 'https://stale.invalid/compose.yaml',
  );
  Future<ApplicationCenterNotifier> seedCatalog() async {
    catalog.rows = [centerApp];
    final notifier = container.read(applicationCenterProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await notifier.saveSources([source]);
    expect(container.read(applicationCenterProvider).catalog, [centerApp]);
    return notifier;
  }

  test(
    'missing disk cache and network failure retain populated catalog',
    () async {
      final notifier = await seedCatalog();
      catalog.failNetwork = true;
      await notifier.refreshCatalog();
      final state = container.read(applicationCenterProvider);
      expect(state.catalog, [centerApp]);
      expect(state.sourceErrors['fixture'], contains('network unavailable'));
      expect(state.loadingCatalog, false);
    },
  );

  test(
    'same-ID changed URL discards old source rows but retains unchanged source',
    () async {
      final notifier = await seedCatalog();
      const other = ApplicationSource(
        id: 'other',
        name: 'Other',
        url: 'https://other.invalid/store',
      );
      const otherApp = CatalogApplication(
        sourceId: 'other',
        id: 'other',
        title: 'Other',
        composeUrl: 'https://other.invalid/compose',
      );
      catalog.rows = [centerApp, otherApp];
      await notifier.saveSources([source, other]);
      expect(container.read(applicationCenterProvider).catalog, [
        centerApp,
        otherApp,
      ]);
      catalog.failNetwork = true;
      await notifier.saveSources([
        const ApplicationSource(
          id: 'fixture',
          name: 'Fixture',
          url: 'https://replacement.invalid/store',
        ),
        other,
      ]);
      expect(container.read(applicationCenterProvider).catalog, [otherApp]);
      expect(container.read(applicationCenterProvider).loadingCatalog, false);
    },
  );

  test(
    'cache exception recovered by network clears source error not server error',
    () async {
      final notifier = await seedCatalog();
      service.onInspect = (_) async => throw StateError('server unreachable');
      connect(true);
      await notifier.refreshServer();
      expect(
        container.read(applicationCenterProvider).error,
        contains('server unreachable'),
      );
      catalog.failCache = true;
      await notifier.refreshCatalog();
      final state = container.read(applicationCenterProvider);
      expect(state.catalog, [centerApp]);
      expect(state.sourceErrors, isEmpty);
      expect(state.loadingCatalog, false);
      expect(state.error, contains('server unreachable'));
    },
  );

  group('source-specific catalog retry', () {
    const otherSource = ApplicationSource(
      id: 'other',
      name: 'Other',
      url: 'https://other.invalid/store',
    );
    const otherApp = CatalogApplication(
      sourceId: 'other',
      id: 'other',
      title: 'Other',
      composeUrl: 'https://other.invalid/compose',
    );
    final updated = CatalogApplication.fromJson({
      ...centerApp.toJson(),
      'title': 'Updated fixture',
    });

    Future<ApplicationCenterNotifier> twoSources() async {
      final notifier = await seedCatalog();
      catalog.rows = [centerApp, otherApp];
      await notifier.saveSources([source, otherSource]);
      return notifier;
    }

    test(
      'retrying one source preserves other catalog, error and success time',
      () async {
        final notifier = await twoSources();
        catalog.failNetwork = true;
        await notifier.refreshCatalog();
        final previous = container.read(applicationCenterProvider);
        expect(previous.sourceErrors.keys, containsAll(['fixture', 'other']));
        catalog.failNetwork = false;
        catalog.rows = [updated];
        catalog.cachedSources.clear();
        catalog.refreshedSources.clear();
        final before = DateTime.now();
        await notifier.refreshCatalog(sourceId: source.id);
        final current = container.read(applicationCenterProvider);
        expect(catalog.cachedSources, ['fixture']);
        expect(catalog.refreshedSources, ['fixture']);
        expect(current.catalog, containsAll([updated, otherApp]));
        expect(current.sourceErrors.containsKey('fixture'), isFalse);
        expect(current.sourceErrors['other'], previous.sourceErrors['other']);
        expect(
          current.sourceRefreshedAt['other'],
          previous.sourceRefreshedAt['other'],
        );
        expect(current.sourceRefreshedAt['fixture']!.isBefore(before), isFalse);
        expect(current.catalogRefreshedAt!.isBefore(before), isFalse);
        expect(current.loadingCatalog, isFalse);
      },
    );

    test(
      'failed single-source retry preserves usable catalog and success timestamps',
      () async {
        final notifier = await twoSources();
        final previous = container.read(applicationCenterProvider);
        catalog.failNetwork = true;
        catalog.cachedSources.clear();
        catalog.refreshedSources.clear();
        await notifier.refreshCatalog(sourceId: otherSource.id);
        final current = container.read(applicationCenterProvider);
        expect(catalog.cachedSources, ['other']);
        expect(catalog.refreshedSources, ['other']);
        expect(current.catalog, previous.catalog);
        expect(current.sourceRefreshedAt, previous.sourceRefreshedAt);
        expect(current.catalogRefreshedAt, previous.catalogRefreshedAt);
        expect(current.sourceErrors.keys, ['other']);
        expect(current.loadingCatalog, isFalse);
      },
    );

    test(
      'unknown and disabled retry is a no-op and does not cancel valid in-flight refresh',
      () async {
        final notifier = await seedCatalog();
        await notifier.saveSources([
          source,
          otherSource.copyWith(enabled: false),
        ]);
        final gate = Completer<List<CatalogApplication>>();
        final started = Completer<void>();
        catalog.onRefresh = (_) {
          started.complete();
          return gate.future;
        };
        final pending = notifier.refreshCatalog(sourceId: source.id);
        await started.future;
        final previous = container.read(applicationCenterProvider);
        final reads = catalog.refreshedSources.length;
        await notifier.refreshCatalog(sourceId: 'unknown');
        await notifier.refreshCatalog(sourceId: otherSource.id);
        expect(container.read(applicationCenterProvider), same(previous));
        expect(catalog.refreshedSources.length, reads);
        gate.complete([updated]);
        await pending;
        expect(container.read(applicationCenterProvider).catalog, [updated]);
        expect(
          container.read(applicationCenterProvider).loadingCatalog,
          isFalse,
        );
      },
    );

    test('same-context retry joins the in-flight refresh', () async {
      final notifier = await twoSources();
      final gate = Completer<List<CatalogApplication>>();
      final started = Completer<void>();
      catalog.onRefresh = (_) {
        if (!started.isCompleted) started.complete();
        return gate.future;
      };
      catalog.cachedSources.clear();
      catalog.refreshedSources.clear();
      final first = notifier.refreshCatalog(sourceId: source.id);
      await started.future;
      final second = notifier.refreshCatalog(sourceId: source.id);
      var firstSettled = false;
      first.then((_) => firstSettled = true);
      await Future<void>.delayed(Duration.zero);
      expect(firstSettled, isFalse);
      expect(catalog.cachedSources, ['fixture']);
      expect(catalog.refreshedSources, ['fixture']);
      expect(container.read(applicationCenterProvider).loadingCatalog, isTrue);
      gate.complete([updated]);
      await Future.wait([first, second]);
      expect(catalog.cachedSources, ['fixture']);
      expect(catalog.refreshedSources, ['fixture']);
      final current = container.read(applicationCenterProvider);
      expect(current.catalog, containsAll([updated, otherApp]));
      expect(current.sourceRefreshedAt.keys, containsAll(['fixture', 'other']));
      expect(current.loadingCatalog, isFalse);
    });

    test(
      'supersession happens only when the source identity changes',
      () async {
        final notifier = await twoSources();
        final staleGate = Completer<List<CatalogApplication>>();
        final started = Completer<void>();
        var fixtureRefreshes = 0;
        catalog.onRefresh = (entry) {
          if (entry.id == source.id && ++fixtureRefreshes == 1) {
            if (!started.isCompleted) started.complete();
            return staleGate.future;
          }
          return Future.value(entry.id == source.id ? [updated] : [otherApp]);
        };
        final stale = notifier.refreshCatalog(sourceId: source.id);
        await started.future;
        await notifier.saveSources([
          const ApplicationSource(
            id: 'fixture',
            name: 'Fixture',
            url: 'https://replacement.invalid/store',
          ),
          otherSource,
        ]);
        final newer = container.read(applicationCenterProvider);
        expect(newer.catalog, containsAll([updated, otherApp]));
        expect(newer.loadingCatalog, isFalse);
        staleGate.complete([staleCatalogRow]);
        await stale;
        final after = container.read(applicationCenterProvider);
        expect(identical(after.catalog, newer.catalog), isTrue);
        expect(identical(after.sourceErrors, newer.sourceErrors), isTrue);
        expect(
          identical(after.sourceRefreshedAt, newer.sourceRefreshedAt),
          isTrue,
        );
        expect(after.catalog.map((app) => app.id), isNot(contains('stale')));
        expect(after.catalog, containsAll([updated, otherApp]));
        expect(after.loadingCatalog, isFalse);
      },
    );

    test(
      'default refresh still refreshes every enabled source after scoped retry',
      () async {
        final notifier = await twoSources();
        await notifier.refreshCatalog(sourceId: source.id);
        catalog.cachedSources.clear();
        catalog.refreshedSources.clear();
        await notifier.refreshCatalog();
        expect(catalog.cachedSources, ['fixture', 'other']);
        expect(catalog.refreshedSources, ['fixture', 'other']);
        expect(container.read(applicationCenterProvider).catalog, [
          centerApp,
          otherApp,
        ]);
      },
    );
  });

  group('catalog concurrency', () {
    const otherSource = ApplicationSource(
      id: 'other',
      name: 'Other',
      url: 'https://other.invalid/store',
    );
    const otherApp = CatalogApplication(
      sourceId: 'other',
      id: 'other',
      title: 'Other',
      composeUrl: 'https://other.invalid/compose',
    );
    final updated = CatalogApplication.fromJson({
      ...centerApp.toJson(),
      'title': 'Updated fixture',
    });

    Future<ApplicationCenterNotifier> twoSources() async {
      final notifier = await seedCatalog();
      catalog.rows = [centerApp, otherApp];
      await notifier.saveSources([source, otherSource]);
      return notifier;
    }

    Future<void> settleCatalog() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test(
      'first read auto refresh and immediate explicit refresh share one request',
      () async {
        final official = ApplicationSource.official;
        final officialApp = CatalogApplication(
          sourceId: official.id,
          id: official.id,
          title: 'Official App',
          composeUrl: 'https://official.invalid/compose.yaml',
        );
        catalog.rows = [officialApp];
        final started = Completer<void>();
        final gate = Completer<List<CatalogApplication>>();
        catalog.onRefresh = (entry) {
          if (!started.isCompleted) started.complete();
          return gate.future;
        };
        final notifier = container.read(applicationCenterProvider.notifier);
        final explicit = notifier.refreshCatalog();
        var explicitSettled = false;
        explicit.then((_) => explicitSettled = true);
        await started.future;
        await settleCatalog();
        expect(catalog.cachedSources, [official.id]);
        expect(catalog.refreshedSources, [official.id]);
        expect(explicitSettled, isFalse);
        final waiting = container.read(applicationCenterProvider);
        expect(waiting.loadingCatalog, isTrue);
        expect(waiting.catalog, isEmpty);
        gate.complete([officialApp]);
        await explicit;
        final settled = container.read(applicationCenterProvider);
        expect(settled.catalog, [officialApp]);
        expect(settled.sourceErrors, isEmpty);
        expect(settled.loadingCatalog, isFalse);
        expect(catalog.cachedSources, [official.id]);
        expect(catalog.refreshedSources, [official.id]);
      },
    );

    test(
      'independent source completions merge rows, errors and timestamps',
      () async {
        final notifier = await twoSources();
        final seeded = container.read(applicationCenterProvider);
        final fixtureGate = Completer<List<CatalogApplication>>();
        final otherGate = Completer<List<CatalogApplication>>();
        final fixtureStarted = Completer<void>();
        final otherStarted = Completer<void>();
        catalog.onRefresh = (entry) {
          if (entry.id == source.id) {
            if (!fixtureStarted.isCompleted) fixtureStarted.complete();
            return fixtureGate.future;
          }
          if (!otherStarted.isCompleted) otherStarted.complete();
          return otherGate.future;
        };
        final pending = notifier.refreshCatalog();
        await Future.wait([fixtureStarted.future, otherStarted.future]);
        expect(
          container.read(applicationCenterProvider).loadingCatalog,
          isTrue,
        );
        fixtureGate.complete([updated]);
        await settleCatalog();
        final partial = container.read(applicationCenterProvider);
        expect(partial.catalog, contains(updated));
        expect(partial.catalog, contains(otherApp));
        expect(
          partial.catalog.any((app) => app.title == centerApp.title),
          isFalse,
        );
        expect(
          identical(
            partial.sourceRefreshedAt['other'],
            seeded.sourceRefreshedAt['other'],
          ),
          isTrue,
        );
        expect(
          identical(
            partial.sourceRefreshedAt['fixture'],
            seeded.sourceRefreshedAt['fixture'],
          ),
          isFalse,
        );
        expect(partial.sourceErrors, isEmpty);
        expect(partial.loadingCatalog, isTrue);
        otherGate.completeError(StateError('other source down'));
        await pending;
        final current = container.read(applicationCenterProvider);
        expect(current.catalog, containsAll([updated, otherApp]));
        expect(current.sourceErrors.keys, ['other']);
        expect(current.sourceErrors['other'], contains('other source down'));
        expect(
          identical(
            current.sourceRefreshedAt['other'],
            seeded.sourceRefreshedAt['other'],
          ),
          isTrue,
        );
        expect(current.loadingCatalog, isFalse);
      },
    );

    test(
      'full refresh and scoped refresh share one in-flight request per source',
      () async {
        final notifier = await twoSources();
        final gate = Completer<List<CatalogApplication>>();
        final started = Completer<void>();
        catalog.onRefresh = (entry) {
          if (entry.id != source.id) return Future.value([otherApp]);
          if (!started.isCompleted) started.complete();
          return gate.future;
        };
        catalog.cachedSources.clear();
        catalog.refreshedSources.clear();
        final scoped = notifier.refreshCatalog(sourceId: source.id);
        await started.future;
        var scopedSettled = false;
        var fullSettled = false;
        scoped.then((_) => scopedSettled = true);
        final full = notifier.refreshCatalog();
        full.then((_) => fullSettled = true);
        await settleCatalog();
        expect(scopedSettled, isFalse);
        expect(fullSettled, isFalse);
        expect(
          catalog.refreshedSources.where((id) => id == source.id).length,
          1,
        );
        expect(
          catalog.refreshedSources.where((id) => id == otherSource.id).length,
          1,
        );
        expect(
          container.read(applicationCenterProvider).loadingCatalog,
          isTrue,
        );
        gate.complete([updated]);
        await Future.wait([scoped, full]);
        expect(catalog.cachedSources.where((id) => id == source.id).length, 1);
        expect(
          catalog.refreshedSources.where((id) => id == source.id).length,
          1,
        );
        final current = container.read(applicationCenterProvider);
        expect(current.catalog, containsAll([updated, otherApp]));
        expect(current.loadingCatalog, isFalse);
      },
    );

    test(
      'rows published from a readable disk cache survive a network failure',
      () async {
        catalog.cachedRows = [centerApp];
        catalog.failNetwork = true;
        final notifier = container.read(applicationCenterProvider.notifier);
        await settleCatalog();
        await notifier.saveSources([source]);
        final state = container.read(applicationCenterProvider);
        expect(state.catalog, [centerApp]);
        expect(state.sourceErrors.keys, ['fixture']);
        expect(state.sourceErrors['fixture'], contains('network unavailable'));
        expect(state.loadingCatalog, isFalse);
      },
    );

    test(
      'cache failure with a failed network refresh recovers on the next retry',
      () async {
        final notifier = await seedCatalog();
        catalog.failCache = true;
        catalog.failNetwork = true;
        await notifier.refreshCatalog();
        var state = container.read(applicationCenterProvider);
        expect(state.catalog, [centerApp]);
        expect(state.sourceErrors['fixture'], contains('network unavailable'));
        expect(state.loadingCatalog, isFalse);
        catalog.failCache = false;
        catalog.failNetwork = false;
        catalog.cachedSources.clear();
        catalog.refreshedSources.clear();
        await notifier.refreshCatalog();
        state = container.read(applicationCenterProvider);
        expect(state.sourceErrors, isEmpty);
        expect(state.catalog, [centerApp]);
        expect(state.sourceRefreshedAt.containsKey('fixture'), isTrue);
        expect(state.loadingCatalog, isFalse);
        expect(catalog.cachedSources, ['fixture']);
        expect(catalog.refreshedSources, ['fixture']);
      },
    );

    test(
      'all sources disabled makes every refresh a no-op without service calls',
      () async {
        final notifier = await seedCatalog();
        await notifier.saveSources([source.copyWith(enabled: false)]);
        final before = container.read(applicationCenterProvider);
        expect(before.catalog, isEmpty);
        expect(before.sourceErrors, isEmpty);
        expect(before.sourceRefreshedAt, isEmpty);
        catalog.cachedSources.clear();
        catalog.refreshedSources.clear();
        await notifier.refreshCatalog();
        await notifier.refreshCatalog(sourceId: source.id);
        final after = container.read(applicationCenterProvider);
        expect(catalog.cachedSources, isEmpty);
        expect(catalog.refreshedSources, isEmpty);
        expect(after.catalog, isEmpty);
        expect(after.sourceErrors, isEmpty);
        expect(after.sourceRefreshedAt, isEmpty);
        expect(after.loadingCatalog, isFalse);
      },
    );

    test(
      'disabling sources stops loading while a stale request is still in flight',
      () async {
        final notifier = await twoSources();
        final gate = Completer<List<CatalogApplication>>();
        final started = Completer<void>();
        catalog.onRefresh = (entry) {
          if (!started.isCompleted) started.complete();
          return gate.future;
        };
        catalog.cachedSources.clear();
        catalog.refreshedSources.clear();
        final stale = notifier.refreshCatalog(sourceId: source.id);
        await started.future;
        expect(catalog.refreshedSources, [source.id]);
        expect(
          container.read(applicationCenterProvider).loadingCatalog,
          isTrue,
        );
        await notifier.saveSources([
          source.copyWith(enabled: false),
          otherSource.copyWith(enabled: false),
        ]);
        final disabled = container.read(applicationCenterProvider);
        expect(disabled.loadingCatalog, isFalse);
        expect(disabled.catalog, isEmpty);
        gate.complete([staleCatalogRow]);
        await stale;
        final after = container.read(applicationCenterProvider);
        expect(identical(after.catalog, disabled.catalog), isTrue);
        expect(after.catalog, isEmpty);
        expect(after.sourceErrors, isEmpty);
        expect(after.loadingCatalog, isFalse);
      },
    );

    test('locale change discards the superseded catalog result', () async {
      final notifier = await twoSources();
      final staleGate = Completer<List<CatalogApplication>>();
      final started = Completer<void>();
      var fixtureRefreshes = 0;
      catalog.onRefresh = (entry) {
        if (entry.id == source.id && ++fixtureRefreshes == 1) {
          if (!started.isCompleted) started.complete();
          return staleGate.future;
        }
        return Future.value(entry.id == source.id ? [updated] : [otherApp]);
      };
      final stale = notifier.refreshCatalog(sourceId: source.id);
      await started.future;
      await container
          .read(settingsProvider.notifier)
          .setLocale(const Locale('ja'));
      await settleCatalog();
      final newer = container.read(applicationCenterProvider);
      expect(newer.catalog, containsAll([updated, otherApp]));
      expect(newer.loadingCatalog, isFalse);
      staleGate.complete([staleCatalogRow]);
      await stale;
      final after = container.read(applicationCenterProvider);
      expect(identical(after.catalog, newer.catalog), isTrue);
      expect(identical(after.sourceErrors, newer.sourceErrors), isTrue);
      expect(
        identical(after.sourceRefreshedAt, newer.sourceRefreshedAt),
        isTrue,
      );
      expect(after.catalog.map((app) => app.id), isNot(contains('stale')));
      expect(after.catalog, containsAll([updated, otherApp]));
      expect(after.loadingCatalog, isFalse);
    });

    test('server change discards the superseded catalog result', () async {
      final notifier = await twoSources();
      final staleGate = Completer<List<CatalogApplication>>();
      final started = Completer<void>();
      var fixtureRefreshes = 0;
      catalog.onRefresh = (entry) {
        if (entry.id == source.id && ++fixtureRefreshes == 1) {
          if (!started.isCompleted) started.complete();
          return staleGate.future;
        }
        return Future.value(entry.id == source.id ? [updated] : [otherApp]);
      };
      final stale = notifier.refreshCatalog(sourceId: source.id);
      await started.future;
      final next = centerServer.copyWith(id: 'next', host: 'next.invalid');
      (container.read(activeServerProvider.notifier) as CenterActiveServer)
          .select(next);
      container.read(applicationCenterProvider);
      await settleCatalog();
      final newer = container.read(applicationCenterProvider);
      expect(newer.catalog, containsAll([updated, otherApp]));
      expect(newer.loadingCatalog, isFalse);
      staleGate.complete([staleCatalogRow]);
      await stale;
      final after = container.read(applicationCenterProvider);
      expect(identical(after.catalog, newer.catalog), isTrue);
      expect(identical(after.sourceErrors, newer.sourceErrors), isTrue);
      expect(
        identical(after.sourceRefreshedAt, newer.sourceRefreshedAt),
        isTrue,
      );
      expect(after.catalog.map((app) => app.id), isNot(contains('stale')));
      expect(after.catalog, containsAll([updated, otherApp]));
      expect(after.loadingCatalog, isFalse);
    });

    test(
      'system locale event refreshes and rejects the prior language',
      () async {
        binding.platformDispatcher.localesTestValue = const [Locale('en')];
        addTearDown(binding.platformDispatcher.clearLocalesTestValue);
        await container
            .read(settingsProvider.notifier)
            .setLocale(const Locale('system'));
        final notifier = await twoSources();
        final staleGate = Completer<List<CatalogApplication>>();
        final started = Completer<void>();
        var calls = 0;
        catalog.onRefresh = (entry) {
          if (entry.id == source.id && ++calls == 1) {
            started.complete();
            return staleGate.future;
          }
          return Future.value(entry.id == source.id ? [updated] : [otherApp]);
        };
        catalog.refreshedLocales.clear();
        final stale = notifier.refreshCatalog(sourceId: source.id);
        await started.future;
        expect(catalog.refreshedLocales, ['en_US']);
        binding.platformDispatcher.localesTestValue = const [Locale('ja')];
        await settleCatalog();
        final fresh = container.read(applicationCenterProvider);
        expect(catalog.refreshedLocales, ['en_US', 'ja_JP', 'ja_JP']);
        expect(fresh.loadingCatalog, isFalse);
        expect(fresh.catalog, containsAll([updated, otherApp]));
        staleGate.complete([staleCatalogRow]);
        await stale;
        expect(
          identical(
            container.read(applicationCenterProvider).catalog,
            fresh.catalog,
          ),
          isTrue,
        );
      },
    );

    test('explicit app locale ignores system locale events', () async {
      binding.platformDispatcher.localesTestValue = const [Locale('en')];
      addTearDown(binding.platformDispatcher.clearLocalesTestValue);
      await container
          .read(settingsProvider.notifier)
          .setLocale(const Locale('de'));
      await twoSources();
      catalog.refreshedSources.clear();
      final before = container.read(applicationCenterProvider);
      binding.platformDispatcher.localesTestValue = const [Locale('ja')];
      await settleCatalog();
      expect(catalog.refreshedSources, isEmpty);
      expect(
        identical(container.read(applicationCenterProvider), before),
        isTrue,
      );
    });
  });

  test(
    'foreground return singleflight retains rows and never replays task',
    () async {
      final app = centerDeployment();
      final task = centerTask(
        app,
      ).copyWith(stage: ApplicationTaskStage.succeeded);
      await storage.saveApplicationCenterRecords('deployments', app.serverKey, [
        app.toJson(),
      ]);
      await storage.saveApplicationCenterRecords('tasks', app.serverKey, [
        task.toJson(),
      ]);
      final notifier = container.read(applicationCenterProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      connect(true);
      await notifier.refreshServer();
      final baseline = service.inspections;
      final gate = Completer<ApplicationEnvironment>();
      service.onInspect = (_) => gate.future;
      final visibility = container.read(appVisibilityProvider.notifier);
      visibility.setForeground(false);
      visibility.setForeground(true);
      visibility.setForeground(false);
      visibility.setForeground(true);
      final pending = notifier.refreshServer();
      expect(service.inspections, baseline + 1);
      expect(
        container.read(applicationCenterProvider).deployments.single.id,
        app.id,
      );
      expect(
        container.read(applicationCenterProvider).tasks.single.id,
        task.id,
      );
      gate.complete(centerEnvironment());
      await pending;
      expect(service.launches, 0);
      expect(container.read(applicationCenterProvider).refreshing, false);
    },
  );

  test(
    'lightweight task refresh does not inspect or reconcile deployments',
    () async {
      final notifier = await seedTask();
      final inspections = service.inspections;
      final reconciliations = service.reconciliations;
      final reads = service.reads.length;
      service.onRead = (task) async => task.copyWith(
        logTail: 'Pulling layer 2/5',
        currentCommand: 'docker compose pull',
        commandStartedAt: DateTime.utc(2026, 10, 12),
        lastOutputAt: DateTime.utc(2026, 10, 12, 0, 0, 1),
        lastSyncedAt: DateTime.utc(2026, 10, 12, 0, 0, 2),
        clearSyncError: true,
      );
      await notifier.refreshTasks();
      final current = container.read(applicationCenterProvider).tasks.single;
      expect(service.reads.length, reads + 1);
      expect(service.inspections, inspections);
      expect(service.reconciliations, reconciliations);
      expect(current.stage, ApplicationTaskStage.pulling);
      expect(current.logTail, 'Pulling layer 2/5');
      expect(current.currentCommand, 'docker compose pull');
      expect(current.lastOutputAt, DateTime.utc(2026, 10, 12, 0, 0, 1));
      expect(current.lastSyncedAt, DateTime.utc(2026, 10, 12, 0, 0, 2));
      expect(service.launches, 0);
    },
  );

  test('task refresh coalesces concurrent reads into one future', () async {
    final notifier = await seedTask();
    final gate = Completer<ApplicationTask>();
    service.onRead = (_) => gate.future;
    final reads = service.reads.length;
    final first = notifier.refreshTasks();
    final second = notifier.refreshTasks();
    expect(identical(first, second), isTrue);
    expect(service.reads.length, reads + 1);
    gate.complete(service.reads.last.copyWith(logTail: 'coalesced output'));
    await first;
    expect(
      container.read(applicationCenterProvider).tasks.single.logTail,
      'coalesced output',
    );
  });

  test(
    'read failure during disconnect retains command, log and stage then recovers',
    () async {
      final notifier = await seedTask();
      service.onRead = (task) async => task.copyWith(
        logTail: 'Existing layer progress',
        currentCommand: 'docker compose pull',
        lastOutputAt: DateTime.utc(2026, 10, 12),
      );
      await notifier.refreshTasks();
      final gate = Completer<ApplicationTask>();
      service.onRead = (_) => gate.future;
      final pending = notifier.refreshTasks();
      connect(false);
      gate.completeError(
        const ApplicationCenterException('APP_CENTER_REMOTE_FAILED'),
      );
      await pending;
      final current = container.read(applicationCenterProvider).tasks.single;
      expect(current.stage, ApplicationTaskStage.pulling);
      expect(current.logTail, 'Existing layer progress');
      expect(current.currentCommand, 'docker compose pull');
      expect(current.lastOutputAt, DateTime.utc(2026, 10, 12));
      expect(current.syncError, 'APP_CENTER_REMOTE_FAILED');
      final reads = service.reads.length;
      await notifier.refreshTasks();
      expect(service.reads.length, reads);
      service.onRead = (task) async => task.copyWith(
        logTail: 'Resumed layer progress',
        clearSyncError: true,
      );
      connect(true);
      await notifier.refreshServer();
      final resumed = container.read(applicationCenterProvider).tasks.single;
      expect(resumed.stage, ApplicationTaskStage.pulling);
      expect(resumed.syncError, isNull);
      expect(resumed.logTail, 'Resumed layer progress');
      expect(service.launches, 0);
    },
  );

  test(
    'changed remote identity requires inspection without discarding existing output',
    () async {
      final notifier = await seedTask();
      service.onRead = (task) async =>
          task.copyWith(logTail: 'Last known output');
      await notifier.refreshTasks();
      service.onRead = (_) async =>
          throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
      await notifier.refreshTasks();
      final current = container.read(applicationCenterProvider).tasks.single;
      expect(current.stage, ApplicationTaskStage.needsInspection);
      expect(current.logTail, 'Last known output');
      expect(current.syncError, 'APP_CENTER_TARGET_CHANGED');
      expect(service.launches, 0);
    },
  );

  test(
    'invalid cleanup result on cached uninstall requires inspection keeping selection',
    () async {
      final app = centerDeployment();
      final cached = ApplicationTask.fromJson({
        ...centerTask(
          app,
        ).copyWith(stage: ApplicationTaskStage.succeeded).toJson(),
        'operation': ApplicationOperation.uninstall.name,
        'cleanupResults': [
          {'key': 'A', 'source': '/fixture/data', 'outcome': 'pending'},
        ],
      });
      await storage.saveApplicationCenterRecords('deployments', app.serverKey, [
        app.toJson(),
      ]);
      await storage.saveApplicationCenterRecords('tasks', app.serverKey, [
        cached.toJson(),
      ]);
      final notifier = container.read(applicationCenterProvider.notifier);
      connect(true);
      await notifier.refreshServer();
      final seeded = container.read(applicationCenterProvider).tasks.single;
      expect(seeded.stage, ApplicationTaskStage.succeeded);
      expect(seeded.operation, ApplicationOperation.uninstall);
      expect(seeded.cleanupResults.single.key, 'A');
      expect(seeded.cleanupResults.single.source, '/fixture/data');
      expect(
        seeded.cleanupResults.single.outcome,
        ApplicationCleanupOutcome.pending,
      );
      service.onRead = (task) async =>
          task.copyWith(logTail: 'Last known output');
      notifier.setObservedTask(seeded.id);
      await notifier.refreshTasks();
      final baseline = container.read(applicationCenterProvider).tasks.single;
      expect(baseline.stage, ApplicationTaskStage.succeeded);
      expect(baseline.logTail, 'Last known output');
      service.onRead = (_) async => throw const ApplicationCenterException(
        'APP_CENTER_CLEANUP_RESULT_INVALID',
      );
      await notifier.refreshTasks();
      final current = container.read(applicationCenterProvider).tasks.single;
      expect(current.stage, ApplicationTaskStage.needsInspection);
      expect(current.syncError, 'APP_CENTER_CLEANUP_RESULT_INVALID');
      expect(current.logTail, 'Last known output');
      expect(current.operation, ApplicationOperation.uninstall);
      expect(current.cleanupResults.single.key, 'A');
      expect(current.cleanupResults.single.source, '/fixture/data');
      expect(
        current.cleanupResults.single.outcome,
        ApplicationCleanupOutcome.pending,
      );
      expect(service.launches, 0);
    },
  );

  testWidgets(
    'observed unresolved tasks poll each second without full inspection',
    (tester) async {
      final notifier = await seedTask(
        stage: ApplicationTaskStage.needsInspection,
      );
      final task = container.read(applicationCenterProvider).tasks.single;
      notifier.setObservedTask(task.id);
      await notifier.refreshTasks();
      final reads = service.reads.length;
      final inspections = service.inspections;
      await tester.pump(const Duration(seconds: 1));
      expect(service.reads.length, reads + 1);
      expect(service.inspections, inspections);
      notifier.clearObservedTask(task.id);
      await tester.pump(const Duration(seconds: 2));
      expect(service.reads.length, reads + 1);
      expect(service.inspections, inspections);
      container.dispose();
    },
  );

  test(
    'observing terminal history reads its final log; clearing observation stops rereads',
    () async {
      final notifier = await seedTask(stage: ApplicationTaskStage.succeeded);
      final task = container.read(applicationCenterProvider).tasks.single;
      final reads = service.reads.length;
      service.onRead = (task) async =>
          task.copyWith(logTail: 'Final complete output', exitCode: 0);
      notifier.setObservedTask(task.id);
      await notifier.refreshTasks();
      expect(service.reads.length, reads + 1);
      expect(
        container.read(applicationCenterProvider).tasks.single.logTail,
        'Final complete output',
      );
      notifier.clearObservedTask('some-other-task');
      await notifier.refreshTasks();
      expect(service.reads.length, reads + 2);
      notifier.clearObservedTask(task.id);
      await notifier.refreshTasks();
      expect(service.reads.length, reads + 2);
    },
  );

  test(
    'inspection recovery to terminal status triggers deployment reconciliation',
    () async {
      final notifier = await seedTask(
        stage: ApplicationTaskStage.needsInspection,
      );
      final inspections = service.inspections;
      final reconciliations = service.reconciliations;
      service.onRead = (task) async => task.copyWith(
        stage: ApplicationTaskStage.succeeded,
        exitCode: 0,
        logTail: 'All output drained',
      );
      await notifier.refreshTasks();
      await notifier.refreshServer();
      expect(service.inspections, inspections + 1);
      expect(service.reconciliations, reconciliations + 1);
      final current = container.read(applicationCenterProvider).tasks.single;
      expect(current.stage, ApplicationTaskStage.succeeded);
      expect(current.logTail, 'All output drained');
      expect(current.exitCode, 0);
    },
  );

  testWidgets(
    'unawaited observation and timer persistence failures stay handled and recover',
    (tester) async {
      container.dispose();
      await setup(failingStorage: true);
      final failing = storage as _FailingStorage;
      failing.failWrites = false;
      final notifier = await seedTask();
      final task = container.read(applicationCenterProvider).tasks.single;
      failing.failWrites = true;
      service.onRead = (task) async =>
          task.copyWith(stage: ApplicationTaskStage.applying);
      notifier.setObservedTask(task.id);
      await notifier.refreshTasks();
      expect(
        container.read(applicationCenterProvider).error,
        contains('save failed'),
      );
      expect(
        container.read(applicationCenterProvider).tasks.single.stage,
        ApplicationTaskStage.applying,
      );
      service.onRead = (task) async =>
          task.copyWith(stage: ApplicationTaskStage.checking);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(
        container.read(applicationCenterProvider).tasks.single.stage,
        ApplicationTaskStage.checking,
      );
      expect(
        container.read(applicationCenterProvider).error,
        contains('save failed'),
      );
      failing.failWrites = false;
      service.onRead = (task) async =>
          task.copyWith(stage: ApplicationTaskStage.pulling);
      await notifier.refreshTasks();
      expect(
        storage
            .getApplicationCenterRecords('tasks', task.serverKey)
            .single['stage'],
        'pulling',
      );
      container.dispose();
    },
  );

  test(
    'late old-server task response cannot overwrite newly selected server',
    () async {
      final notifier = await seedTask();
      final gate = Completer<ApplicationTask>();
      final old = container.read(applicationCenterProvider).tasks.single;
      service.onRead = (task) =>
          task.serverId == centerServer.id ? gate.future : Future.value(task);
      final pending = notifier.refreshTasks();
      final next = centerServer.copyWith(id: 'next', host: 'next.invalid');
      final app = centerDeployment(next);
      await storage.saveApplicationCenterRecords('deployments', app.serverKey, [
        app.toJson(),
      ]);
      await storage.saveApplicationCenterRecords('tasks', app.serverKey, [
        centerTask(app).toJson(),
      ]);
      (container.read(activeServerProvider.notifier) as CenterActiveServer)
          .select(next);
      container.read(applicationCenterProvider);
      await container.read(applicationCenterProvider.notifier).refreshServer();
      gate.complete(old.copyWith(logTail: 'stale old-server output'));
      await pending;
      final current = container.read(applicationCenterProvider).tasks.single;
      expect(current.serverKey, app.serverKey);
      expect(current.logTail, isNot(contains('stale')));
    },
  );
}
