import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/application_center.dart';
import '../../data/models/nas_source.dart';
import '../../data/models/server_profile.dart';
import '../../infrastructure/nas/nas_ssh_tunnel_service.dart';
import '../logging/sanitizer.dart';
import '../localization/app_locales.dart';
import '../services/application_catalog_service.dart';
import '../services/application_compose_service.dart';
import '../services/application_deployment_service.dart';
import 'app_visibility_provider.dart';
import 'infrastructure_providers.dart';
import 'server_provider.dart';
import 'settings_provider.dart';
import 'storage_providers.dart';

final applicationCatalogServiceProvider = Provider(
  (ref) => ApplicationCatalogService(),
);
final applicationDeploymentServiceProvider = Provider(
  (ref) => ApplicationDeploymentService(ref.watch(sshCommandExecutorProvider)),
);
final applicationAccessServiceProvider = Provider((ref) {
  ref.watch(activeServerProvider.select((s) => s?.connectionKey));
  final service = NasSshTunnelService(ref.watch(sshCommandExecutorProvider));
  ref.onDispose(service.dispose);
  return service;
});

class ApplicationCenterState {
  final List<ApplicationSource> sources;
  final List<CatalogApplication> catalog;
  final List<ApplicationDeployment> deployments;
  final List<ApplicationTask> tasks;
  final ApplicationEnvironment? environment;
  final String? error;
  final Map<String, String> sourceErrors;
  final Map<String, DateTime> sourceRefreshedAt;
  final bool loadingCatalog, refreshing, busy;
  final DateTime? catalogRefreshedAt;
  const ApplicationCenterState({
    this.sources = const [ApplicationSource.official],
    this.catalog = const [],
    this.deployments = const [],
    this.tasks = const [],
    this.environment,
    this.error,
    this.sourceErrors = const {},
    this.sourceRefreshedAt = const {},
    this.loadingCatalog = false,
    this.refreshing = false,
    this.busy = false,
    this.catalogRefreshedAt,
  });
  ApplicationCenterState copyWith({
    List<ApplicationSource>? sources,
    List<CatalogApplication>? catalog,
    List<ApplicationDeployment>? deployments,
    List<ApplicationTask>? tasks,
    ApplicationEnvironment? environment,
    String? error,
    bool clearError = false,
    Map<String, String>? sourceErrors,
    Map<String, DateTime>? sourceRefreshedAt,
    bool? loadingCatalog,
    bool? refreshing,
    bool? busy,
    DateTime? catalogRefreshedAt,
  }) => ApplicationCenterState(
    sources: sources ?? this.sources,
    catalog: catalog ?? this.catalog,
    deployments: deployments ?? this.deployments,
    tasks: tasks ?? this.tasks,
    environment: environment ?? this.environment,
    error: clearError ? null : error ?? this.error,
    sourceErrors: sourceErrors ?? this.sourceErrors,
    sourceRefreshedAt: sourceRefreshedAt ?? this.sourceRefreshedAt,
    loadingCatalog: loadingCatalog ?? this.loadingCatalog,
    refreshing: refreshing ?? this.refreshing,
    busy: busy ?? this.busy,
    catalogRefreshedAt: catalogRefreshedAt ?? this.catalogRefreshedAt,
  );
}

final applicationCenterProvider =
    NotifierProvider<ApplicationCenterNotifier, ApplicationCenterState>(
      ApplicationCenterNotifier.new,
    );

class ApplicationCenterNotifier extends Notifier<ApplicationCenterState>
    with WidgetsBindingObserver {
  Timer? _poll;
  int _epoch = 0, _catalogEpoch = 0;
  String? _catalogLocale;
  String? _sudoPassword;
  ServerProfile? _boundServer;
  Future<void>? _refreshTask;
  Future<void>? _taskRefresh;
  final _catalogRequests =
      <
        ({int epoch, int generation, String id, String url, String locale}),
        Future<void>
      >{};
  String? _observedTaskId;
  Future<void> _persistQueue = Future.value();
  final _approvalKeys = <String, String>{};

  String? get serverKey => _boundServer == null
      ? null
      : ApplicationDeploymentService.serverKey(_boundServer!);
  bool get _connected =>
      ref.read(serverConnectionProvider).isConnected && _boundServer != null;
  bool _current(int epoch) => ref.mounted && epoch == _epoch;
  String _error(Object error) => LogSanitizer.sanitize(error.toString());

  @override
  ApplicationCenterState build() {
    final epoch = ++_epoch;
    ++_catalogEpoch;
    _catalogRequests.clear();
    _catalogLocale = _locale;
    WidgetsBinding.instance.addObserver(this);
    _poll?.cancel();
    _sudoPassword = null;
    _approvalKeys.clear();
    _refreshTask = null;
    _taskRefresh = null;
    _observedTaskId = null;
    _boundServer =
        ref.watch(activeServerProvider.select((s) => s?.connectionKey)) == null
        ? null
        : ref.read(activeServerProvider);
    final storage = ref.read(localStorageServiceProvider);
    var sources = const [ApplicationSource.official];
    var deployments = <ApplicationDeployment>[];
    var tasks = <ApplicationTask>[];
    String? error;
    List<T> restore<T>(
      String kind,
      String scope,
      T Function(Map<String, dynamic>) decode,
    ) {
      final restored = <T>[];
      try {
        for (final row in storage.getApplicationCenterRecords(kind, scope)) {
          try {
            restored.add(decode(row));
          } catch (e) {
            error = _error(e);
          }
        }
      } catch (e) {
        error = _error(e);
      }
      return restored;
    }

    if (storage.hasApplicationCenterRecords('sources', 'global')) {
      sources = restore('sources', 'global', ApplicationSource.fromJson);
    }
    if (serverKey != null) {
      deployments = restore(
        'deployments',
        serverKey!,
        ApplicationDeployment.fromJson,
      ).where((d) => d.serverKey == serverKey).toList();
      tasks = restore(
        'tasks',
        serverKey!,
        ApplicationTask.fromJson,
      ).where((t) => t.serverKey == serverKey).toList();
    }
    ref.listen(serverConnectionProvider, (previous, next) {
      if (next.isConnected && previous?.isConnected != true) {
        unawaited(refreshServer());
      }
    });
    ref.listen(settingsProvider.select((s) => s.locale), (previous, next) {
      if (previous != next) _refreshCatalogLanguage();
    });
    ref.listen(appVisibilityProvider, (previous, next) {
      if (next && previous == false && _connected) {
        unawaited(refreshServer());
      }
    });
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _poll?.cancel();
      _sudoPassword = null;
    });
    var inspectionTicks = 0;
    _poll = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_current(epoch) || !_connected || !ref.read(appVisibilityProvider)) {
        return;
      }
      inspectionTicks = (inspectionTicks + 1) % 30;
      if (state.tasks.any(
            (t) =>
                t.isBusy ||
                t.id == _observedTaskId &&
                    t.stage == ApplicationTaskStage.needsInspection,
          ) &&
          (_observedTaskId != null || inspectionTicks % 3 == 0)) {
        unawaited(refreshTasks());
      }
      if (inspectionTicks == 0 &&
          state.tasks.any(
            (t) => t.isBusy || t.stage == ApplicationTaskStage.needsInspection,
          )) {
        unawaited(refreshServer());
      }
    });
    Future.microtask(() {
      if (!_current(epoch)) return;
      unawaited(refreshCatalog());
      if (_connected) unawaited(refreshServer());
    });
    return ApplicationCenterState(
      sources: sources,
      deployments: deployments,
      tasks: tasks,
      error: error,
    );
  }

  String get _locale {
    var locale = ref.read(settingsProvider).locale;
    if (locale.languageCode == 'system') {
      locale = resolveAppLocale(
        WidgetsBinding.instance.platformDispatcher.locales,
        appLanguageLocales,
      );
    }
    return switch (locale.languageCode) {
      'zh' => locale.scriptCode == 'Hant' ? 'zh_TW' : 'zh_CN',
      'en' => 'en_US',
      'ja' => 'ja_JP',
      'ko' => 'ko_KR',
      'pt' => 'pt_BR',
      'ar' => 'ar_SA',
      'hi' => 'hi_IN',
      'vi' => 'vi_VN',
      _ => '${locale.languageCode}_${locale.languageCode.toUpperCase()}',
    };
  }

  @override
  void didChangeLocales(List<Locale>? locales) => _refreshCatalogLanguage();

  void _refreshCatalogLanguage() {
    if (!ref.mounted || _catalogLocale == _locale) return;
    _catalogLocale = _locale;
    ++_catalogEpoch;
    _catalogRequests.clear();
    unawaited(refreshCatalog());
  }

  Future<void> refreshCatalog({String? sourceId}) async {
    final sources = state.sources
        .where(
          (source) =>
              source.enabled && (sourceId == null || source.id == sourceId),
        )
        .toList();
    if (sourceId != null && sources.isEmpty) return;
    if (sources.isEmpty) {
      _updateCatalogLoading();
      return;
    }
    await Future.wait(sources.map(_refreshCatalogSource));
  }

  bool _catalogRequestCurrent(
    ({int epoch, int generation, String id, String url, String locale}) key,
  ) =>
      _current(key.epoch) &&
      key.generation == _catalogEpoch &&
      key.locale == _locale &&
      state.sources.any(
        (source) =>
            source.enabled && source.id == key.id && source.url == key.url,
      );

  void _updateCatalogLoading() {
    state = state.copyWith(
      loadingCatalog: _catalogRequests.keys.any(_catalogRequestCurrent),
    );
  }

  Future<void> _refreshCatalogSource(ApplicationSource source) {
    final key = (
      epoch: _epoch,
      generation: _catalogEpoch,
      id: source.id,
      url: source.url,
      locale: _locale,
    );
    final pending = _catalogRequests[key];
    if (pending != null) return pending;
    late final Future<void> request;
    request = _loadCatalogSource(source, key).whenComplete(() {
      if (!identical(_catalogRequests[key], request)) return;
      _catalogRequests.remove(key);
      if (_current(key.epoch)) _updateCatalogLoading();
    });
    _catalogRequests[key] = request;
    _updateCatalogLoading();
    return request;
  }

  Future<void> _loadCatalogSource(
    ApplicationSource source,
    ({int epoch, int generation, String id, String url, String locale}) key,
  ) async {
    final service = ref.read(applicationCatalogServiceProvider);
    // Merge only this source into live state: concurrent sources must not
    // overwrite each other with a snapshot captured before their requests.
    void publish({
      List<CatalogApplication>? rows,
      String? error,
      DateTime? refreshedAt,
      bool fresh = false,
    }) {
      if (!_catalogRequestCurrent(key)) return;
      final errors = Map<String, String>.from(state.sourceErrors);
      if (error != null) {
        errors[source.id] = error;
      } else if (fresh) {
        errors.remove(source.id);
      }
      state = state.copyWith(
        catalog: rows == null
            ? null
            : List.unmodifiable([
                ...state.catalog.where((app) => app.sourceId != source.id),
                ...rows,
              ]),
        sourceErrors: Map.unmodifiable(errors),
        sourceRefreshedAt: refreshedAt == null
            ? null
            : Map.unmodifiable({
                ...state.sourceRefreshedAt,
                source.id: refreshedAt,
              }),
        catalogRefreshedAt: fresh ? refreshedAt : null,
      );
    }

    try {
      final cached = await service.cached(source, locale: key.locale);
      final cachedAt = await service.cachedAt(source, locale: key.locale);
      // Cache eviction must not erase the still-readable in-memory catalog.
      publish(rows: cached.isEmpty ? null : cached, refreshedAt: cachedAt);
    } catch (error) {
      publish(error: _error(error));
    }
    if (!_catalogRequestCurrent(key)) return;
    try {
      final rows = await service.refresh(source, locale: key.locale);
      publish(rows: rows, refreshedAt: DateTime.now(), fresh: true);
    } catch (error) {
      publish(error: _error(error));
    }
  }

  Future<void> saveSources(List<ApplicationSource> sources) async {
    if (sources.length > 20 ||
        sources.map((s) => s.id).toSet().length != sources.length) {
      throw const ApplicationCenterException('APP_CENTER_SOURCE_INVALID');
    }
    for (final source in sources) {
      if (source.id.isEmpty ||
          source.id.length > 160 ||
          source.name.trim().isEmpty ||
          source.name.length > 120) {
        throw const ApplicationCenterException('APP_CENTER_SOURCE_INVALID');
      }
      ApplicationCatalogService.sourceUri(source.url);
    }
    await ref
        .read(localStorageServiceProvider)
        .saveApplicationCenterRecords(
          'sources',
          'global',
          sources.map((s) => s.toJson()).toList(),
        );
    if (!ref.mounted) return;
    ++_catalogEpoch;
    _catalogRequests.clear();
    final retainedSourceIds = sources
        .where(
          (source) =>
              source.enabled &&
              state.sources.any(
                (old) => old.id == source.id && old.url == source.url,
              ),
        )
        .map((source) => source.id)
        .toSet();
    state = state.copyWith(
      sources: List.unmodifiable(sources),
      sourceRefreshedAt: Map.unmodifiable({
        for (final entry in state.sourceRefreshedAt.entries)
          if (retainedSourceIds.contains(entry.key)) entry.key: entry.value,
      }),
      catalog: state.catalog
          .where((app) => retainedSourceIds.contains(app.sourceId))
          .toList(),
      sourceErrors: Map.unmodifiable({
        for (final entry in state.sourceErrors.entries)
          if (retainedSourceIds.contains(entry.key)) entry.key: entry.value,
      }),
    );
    await refreshCatalog();
  }

  Future<ApplicationTemplate> loadTemplate(CatalogApplication application) =>
      ref.read(applicationCatalogServiceProvider).template(application);

  Future<ApplicationEnvironment> inspectEnvironment({
    String? sudoPassword,
  }) async {
    final epoch = _epoch;
    final server = _boundServer;
    if (!_connected || server == null) {
      throw const ApplicationCenterException('APP_CENTER_NOT_CONNECTED');
    }
    if (sudoPassword != null && RegExp(r'[\r\n\x00]').hasMatch(sudoPassword)) {
      throw const ApplicationCenterException('APP_CENTER_CONFIG_INVALID');
    }
    final env = await ref
        .read(applicationDeploymentServiceProvider)
        .inspect(server, sudoPassword: sudoPassword ?? _sudoPassword);
    if (!_current(epoch)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    if (sudoPassword != null) _sudoPassword = sudoPassword;
    state = state.copyWith(environment: env);
    return env;
  }

  ApplicationConfiguration defaultConfiguration(
    ApplicationTemplate template, {
    String? instanceId,
    Map<String, String> variables = const {},
    bool jellyfinSoftwareMode = false,
  }) {
    final env = state.environment;
    if (env == null) {
      throw const ApplicationCenterException('APP_CENTER_ENVIRONMENT_REQUIRED');
    }
    return ApplicationComposeService.defaults(
      template,
      env,
      instanceId ?? ApplicationDeploymentService.newId(),
      variables: variables,
      jellyfinSoftwareMode: jellyfinSoftwareMode,
    );
  }

  ApplicationConfiguration configurationForTemplate(
    ApplicationTemplate template,
    ApplicationConfiguration current,
    String instanceId,
  ) {
    final env = state.environment;
    if (env == null) {
      throw const ApplicationCenterException('APP_CENTER_ENVIRONMENT_REQUIRED');
    }
    return ApplicationComposeService.mergeDefaults(
      template,
      env,
      instanceId,
      current,
    );
  }

  ApplicationConfiguration configurationWithVariables(
    ApplicationTemplate template,
    ApplicationConfiguration current,
    String instanceId,
    Map<String, String> variables,
  ) {
    final env = state.environment;
    if (env == null) {
      throw const ApplicationCenterException('APP_CENTER_ENVIRONMENT_REQUIRED');
    }
    return ApplicationComposeService.changeVariables(
      template,
      env,
      instanceId,
      current,
      variables,
    );
  }

  Future<ApplicationOperationPlan> prepare(
    ApplicationOperation operation, {
    ApplicationTemplate? template,
    ApplicationConfiguration? configuration,
    ApplicationDeployment? deployment,
    String? sudoPassword,
    ApplicationUninstallSelection? uninstallSelection,
  }) async {
    final epoch = _epoch;
    if (deployment != null &&
        state.tasks.any(
          (task) =>
              task.deploymentId == deployment.id &&
              (task.isBusy ||
                  task.stage == ApplicationTaskStage.needsInspection),
        )) {
      throw const ApplicationCenterException('APP_CENTER_PLAN_EXPIRED');
    }
    if (operation == ApplicationOperation.bootstrap &&
        state.tasks.any(
          (task) =>
              task.operation == operation &&
              (task.isBusy ||
                  task.stage == ApplicationTaskStage.needsInspection),
        )) {
      throw const ApplicationCenterException('APP_CENTER_PLAN_EXPIRED');
    }
    final env = await inspectEnvironment(sudoPassword: sudoPassword);
    final plan = await ref
        .read(applicationDeploymentServiceProvider)
        .prepare(
          _boundServer!,
          env,
          operation,
          template: template,
          configuration: configuration,
          deployment: deployment,
          sudoPassword: _sudoPassword,
          uninstallSelection: uninstallSelection,
        );
    if (!_current(epoch)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    _approvalKeys[plan.token] = env.serverKey;
    return plan;
  }

  Future<ApplicationUninstallPreview> inspectUninstall(
    ApplicationDeployment deployment, {
    bool allowAdvancedCleanup = false,
  }) async {
    final epoch = _epoch;
    final env = await inspectEnvironment();
    if (!_current(epoch)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    final preview = await ref
        .read(applicationDeploymentServiceProvider)
        .inspectUninstall(
          deployment,
          env,
          sudoPassword: _sudoPassword,
          allowAdvancedCleanup: allowAdvancedCleanup,
        );
    if (!_current(epoch)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    return preview;
  }

  Future<ApplicationUninstallPreview> inspectCleanupRetry(
    ApplicationTask task, {
    bool allowAdvancedCleanup = false,
  }) async {
    final epoch = _epoch;
    final env = await inspectEnvironment();
    if (!_current(epoch)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    final preview = await ref
        .read(applicationDeploymentServiceProvider)
        .inspectCleanupRetry(
          task,
          env,
          sudoPassword: _sudoPassword,
          allowAdvancedCleanup: allowAdvancedCleanup,
        );
    if (!_current(epoch)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    return preview;
  }

  Future<void> _persist() async {
    final key = serverKey;
    if (key == null) return;
    final storage = ref.read(localStorageServiceProvider);
    final deployments = state.deployments.map((d) => d.toJson()).toList();
    final tasks = state.tasks.take(100).map((t) => t.toJson()).toList();
    final save = _persistQueue.then((_) async {
      await storage.saveApplicationCenterRecords(
        'deployments',
        key,
        deployments,
      );
      await storage.saveApplicationCenterRecords('tasks', key, tasks);
    });
    _persistQueue = save.then<void>((_) {}, onError: (Object _) {});
    await save;
  }

  Future<ApplicationTask> execute(ApplicationOperationPlan plan) async {
    final epoch = _epoch;
    if (_approvalKeys.remove(plan.token) != serverKey ||
        state.busy ||
        !_connected) {
      throw const ApplicationCenterException('APP_CENTER_PLAN_EXPIRED');
    }
    if (state.tasks.any(
      (task) =>
          task.deploymentId == plan.deployment.id &&
          (task.isBusy || task.stage == ApplicationTaskStage.needsInspection),
    )) {
      throw const ApplicationCenterException('APP_CENTER_PLAN_EXPIRED');
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final task = await ref
          .read(applicationDeploymentServiceProvider)
          .execute(
            plan,
            sudoPassword: _sudoPassword,
            persistBeforeLaunch: (task) async {
              if (!_current(epoch)) {
                throw const ApplicationCenterException(
                  'APP_CENTER_TARGET_CHANGED',
                );
              }
              final deployments = [...state.deployments];
              if (plan.operation == ApplicationOperation.install) {
                deployments.add(plan.deployment);
              }
              state = state.copyWith(
                tasks: [task, ...state.tasks].take(100).toList(),
                deployments: deployments,
              );
              await _persist();
              if (!_current(epoch)) {
                throw const ApplicationCenterException(
                  'APP_CENTER_TARGET_CHANGED',
                );
              }
            },
          );
      if (!_current(epoch)) {
        throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
      }
      if (_current(epoch)) unawaited(refreshServer());
      return task;
    } catch (error) {
      if (_current(epoch)) state = state.copyWith(error: _error(error));
      rethrow;
    } finally {
      if (_current(epoch)) state = state.copyWith(busy: false);
    }
  }

  void setObservedTask(String? taskId) {
    _observedTaskId = taskId;
    if (taskId != null && _connected) unawaited(refreshTasks());
  }

  void clearObservedTask(String taskId) {
    if (_observedTaskId == taskId) _observedTaskId = null;
  }

  Future<void> refreshTasks() {
    if (_taskRefresh != null) return _taskRefresh!;
    late final Future<void> pending;
    pending = _refreshTasks().whenComplete(() {
      if (identical(_taskRefresh, pending)) _taskRefresh = null;
    });
    _taskRefresh = pending;
    return pending;
  }

  Future<void> _refreshTasks() async {
    if (!_connected) return;
    final epoch = _epoch;
    final service = ref.read(applicationDeploymentServiceProvider);
    final tasks = state.tasks
        .where(
          (t) =>
              t.isBusy ||
              t.stage == ApplicationTaskStage.needsInspection ||
              t.id == _observedTaskId,
        )
        .toList();
    tasks.sort(
      (a, b) => a.id == b.id
          ? 0
          : a.id == _observedTaskId
          ? -1
          : b.id == _observedTaskId
          ? 1
          : 0,
    );
    var completed = false;
    var changedStatus = false;
    for (final old in tasks) {
      if (!_current(epoch) || !_connected) return;
      ApplicationTask next;
      try {
        next = await service.readTask(old);
      } catch (error) {
        next = old.copyWith(
          stage:
              error is ApplicationCenterException &&
                  (error.code == 'APP_CENTER_TARGET_CHANGED' ||
                      error.code == 'APP_CENTER_CLEANUP_RESULT_INVALID')
              ? ApplicationTaskStage.needsInspection
              : null,
          syncError: _error(error),
        );
      }
      if (!_current(epoch)) return;
      completed |=
          (old.isBusy || old.stage == ApplicationTaskStage.needsInspection) &&
          !next.isBusy &&
          next.stage != ApplicationTaskStage.needsInspection;
      changedStatus |=
          next.stage != old.stage ||
          next.exitCode != old.exitCode ||
          next.uninstallCompleted != old.uninstallCompleted ||
          jsonEncode(
                next.cleanupResults.map((result) => result.toJson()).toList(),
              ) !=
              jsonEncode(
                old.cleanupResults.map((result) => result.toJson()).toList(),
              );
      state = state.copyWith(
        tasks: [
          for (final item in state.tasks) item.id == old.id ? next : item,
        ],
      );
    }
    if (changedStatus) {
      try {
        await _persist();
      } catch (error) {
        if (_current(epoch)) state = state.copyWith(error: _error(error));
      }
    }
    if (_current(epoch) && completed) unawaited(refreshServer());
  }

  Future<void> refreshServer() {
    if (_refreshTask != null) return _refreshTask!;
    late final Future<void> task;
    task = _refreshServer().whenComplete(() {
      if (identical(_refreshTask, task)) _refreshTask = null;
    });
    _refreshTask = task;
    return task;
  }

  Future<void> _refreshServer() async {
    if (!_connected) return;
    final epoch = _epoch;
    state = state.copyWith(refreshing: true, clearError: true);
    try {
      final service = ref.read(applicationDeploymentServiceProvider);
      final env = await inspectEnvironment();
      await refreshTasks();
      if (!_current(epoch)) return;
      final tasks = state.tasks;
      final deployments = <ApplicationDeployment>[];
      if (env.ready) {
        for (final old in state.deployments) {
          try {
            final current = await service.reconcile(
              old,
              env,
              sudoPassword: _sudoPassword,
            );
            if (current != null) {
              deployments.add(current);
            } else if (tasks.any(
              (t) =>
                  t.deploymentId == old.id &&
                  (t.isBusy || t.stage == ApplicationTaskStage.needsInspection),
            )) {
              deployments.add(old.copyWith(status: 'installing'));
            }
          } catch (e) {
            deployments.add(old.copyWith(status: 'unknown'));
          }
          if (!_current(epoch)) return;
        }
      } else {
        deployments.addAll(state.deployments);
      }
      if (!_current(epoch)) return;
      final recentTasks = state.tasks
          .where((t) => !tasks.any((saved) => saved.id == t.id))
          .toList();
      final recentDeployments = state.deployments.where(
        (d) =>
            recentTasks.any((t) => t.deploymentId == d.id) &&
            !deployments.any((saved) => saved.id == d.id),
      );
      state = state.copyWith(
        tasks: state.tasks,
        deployments: [...deployments, ...recentDeployments],
      );
      await _persist();
    } catch (error) {
      if (_current(epoch)) state = state.copyWith(error: _error(error));
    } finally {
      if (_current(epoch)) state = state.copyWith(refreshing: false);
    }
  }

  Future<void> cancelTask(ApplicationTask task) async {
    if (task.serverKey != serverKey || !_connected) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    await ref.read(applicationDeploymentServiceProvider).cancel(task);
    await refreshServer();
  }

  Future<ApplicationConfiguration> configuration(
    ApplicationDeployment deployment,
  ) async {
    final epoch = _epoch;
    if (deployment.serverKey != serverKey || !_connected) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    final result = await ref
        .read(applicationDeploymentServiceProvider)
        .configuration(deployment);
    if (!_current(epoch)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    return result;
  }

  Future<ApplicationAccessInfo> accessInfo(
    ApplicationDeployment deployment,
  ) async {
    final epoch = _epoch;
    if (deployment.serverKey != serverKey || !_connected) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    final env = await inspectEnvironment();
    final result = await ref
        .read(applicationDeploymentServiceProvider)
        .accessInfo(deployment, env, sudoPassword: _sudoPassword);
    if (!_current(epoch)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    return result;
  }

  Future<String> logs(ApplicationDeployment deployment) async {
    final epoch = _epoch;
    if (deployment.serverKey != serverKey || !_connected) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    final env = await inspectEnvironment();
    final result = await ref
        .read(applicationDeploymentServiceProvider)
        .logs(deployment, env, sudoPassword: _sudoPassword);
    if (!_current(epoch)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    return result;
  }

  Future<ApplicationTemplate> installedTemplate(
    ApplicationDeployment deployment,
  ) async {
    final epoch = _epoch;
    if (deployment.serverKey != serverKey || !_connected) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    final result = await ref
        .read(applicationDeploymentServiceProvider)
        .installedTemplate(deployment);
    if (!_current(epoch)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    return result;
  }

  Future<void> openApplication(
    ApplicationDeployment deployment, {
    String? directUrl,
  }) async {
    final epoch = _epoch;
    if (deployment.serverKey != serverKey || !_connected) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    final env = await inspectEnvironment();
    final current = await ref
        .read(applicationDeploymentServiceProvider)
        .reconcile(deployment, env, sudoPassword: _sudoPassword);
    if (!_current(epoch)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    if (current == null) {
      throw const ApplicationCenterException('APP_CENTER_NO_WEB_ENTRY');
    }
    Uri uri;
    if (directUrl != null) {
      uri = Uri.parse(directUrl);
      if (!{'http', 'https'}.contains(uri.scheme) ||
          uri.userInfo.isNotEmpty ||
          uri.host.isEmpty) {
        throw const ApplicationCenterException('APP_CENTER_CONFIG_INVALID');
      }
    } else {
      final endpoint = current.endpoint;
      if (endpoint == null) {
        throw const ApplicationCenterException('APP_CENTER_NO_WEB_ENTRY');
      }
      if (endpoint.scheme == 'https') {
        throw const ApplicationCenterException(
          'APP_CENTER_HTTPS_DIRECT_REQUIRED',
        );
      }
      uri = await ref
          .read(applicationAccessServiceProvider)
          .forward(
            NasSource(
              id: 'application-${deployment.serverKey}-${deployment.id}',
              name: current.name,
              type: NasSourceType.webdav,
              endpoint: endpoint.toString(),
              sshServerId: deployment.serverId,
            ),
          );
    }
    if (!_current(epoch)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const ApplicationCenterException('APP_CENTER_OPEN_FAILED');
    }
  }

  bool hasUpdate(ApplicationDeployment deployment) => state.catalog.any(
    (app) =>
        app.sourceId == deployment.sourceId &&
        app.id == deployment.appId &&
        app.contentHash.isNotEmpty &&
        app.contentHash != deployment.templateHash,
  );

  CatalogApplication? catalogEntry(ApplicationDeployment deployment) => state
      .catalog
      .where(
        (app) =>
            app.sourceId == deployment.sourceId && app.id == deployment.appId,
      )
      .firstOrNull;
  void clearError() => state = state.copyWith(clearError: true);
}
