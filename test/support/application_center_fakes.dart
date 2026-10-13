import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/services/application_catalog_service.dart';
import 'package:valhalla/core/services/application_deployment_service.dart';
import 'package:valhalla/data/models/application_center.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

const centerServer = ServerProfile(
  id: 'center-test',
  name: 'Fixture',
  host: 'fixture.invalid',
  username: 'dev',
);
const centerApp = CatalogApplication(
  sourceId: 'fixture',
  id: 'fixture',
  title: 'Fixture App',
  composeUrl: 'https://fixture.invalid/compose.yaml',
);
final centerTemplate = ApplicationTemplate(
  application: centerApp,
  compose: {
    'services': {
      'web': {
        'image': 'nginx:alpine',
        'ports': ['8080:80'],
        'environment': {'TOKEN': 'original'},
      },
    },
  },
  metadata: const {},
);
ApplicationEnvironment centerEnvironment([
  ServerProfile server = centerServer,
]) => ApplicationEnvironment(
  serverId: server.id,
  serverKey: ApplicationDeploymentService.serverKey(server),
  home: '/home/dev',
  os: 'debian',
  osVersion: '12',
  architecture: 'amd64',
  targetIdentity: '${'a' * 32}|fixture-daemon',
  uid: 1000,
  gid: 1000,
  dockerAvailable: true,
  composeAvailable: true,
  useSudo: false,
  canBootstrap: true,
);
ApplicationDeployment centerDeployment([ServerProfile server = centerServer]) =>
    ApplicationDeployment(
      id: 'b' * 32,
      serverKey: ApplicationDeploymentService.serverKey(server),
      serverId: server.id,
      sourceId: centerApp.sourceId,
      appId: centerApp.id,
      name: 'Cached App',
      project: 'valhalla-app-${'b' * 32}',
      directory:
          '/home/dev/.local/share/valhalla/app-center/deployments/${'b' * 32}',
      targetIdentity: centerEnvironment(server).targetIdentity,
      status: 'running',
    );
ApplicationTask centerTask(ApplicationDeployment app) => ApplicationTask(
  id: 'c' * 32,
  serverKey: app.serverKey,
  serverId: app.serverId,
  directory: '/home/dev/.local/share/valhalla/app-center/tasks/${'c' * 32}',
  deploymentId: app.id,
  name: app.name,
  targetIdentity: app.targetIdentity,
  operation: ApplicationOperation.install,
  stage: ApplicationTaskStage.queued,
  createdAt: DateTime.utc(2026),
);

class CenterActiveServer extends ActiveServerNotifier {
  @override
  ServerProfile? build() => centerServer;
  void select(ServerProfile server) => state = server;
}

class CenterConnection extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState();
  void setConnected(bool connected) => state = ServerConnectionState(
    status: connected
        ? ConnectionStateEnum.connected
        : ConnectionStateEnum.disconnected,
  );
}

class CenterCatalog extends ApplicationCatalogService {
  @override
  Future<List<CatalogApplication>> cached(
    ApplicationSource source, {
    String locale = 'en_US',
  }) async => [];
  @override
  Future<List<CatalogApplication>> refresh(
    ApplicationSource source, {
    String locale = 'en_US',
  }) async => [];
  @override
  Future<ApplicationTemplate> template(CatalogApplication app) async =>
      centerTemplate;
}

class _UnusedSsh implements SshCommandExecutor {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

class CenterDeploymentService extends ApplicationDeploymentService {
  CenterDeploymentService() : super(_UnusedSsh());
  Future<ApplicationEnvironment> Function(ServerProfile)? onInspect;
  Future<void> Function(ApplicationTask)? afterPersist;
  bool failReconcile = false;
  int inspections = 0, launches = 0;
  @override
  Future<ApplicationEnvironment> inspect(
    ServerProfile server, {
    String? sudoPassword,
  }) async {
    inspections++;
    return onInspect == null ? centerEnvironment(server) : onInspect!(server);
  }

  @override
  Future<ApplicationDeployment?> reconcile(
    ApplicationDeployment app,
    ApplicationEnvironment env, {
    String? sudoPassword,
  }) async {
    if (failReconcile) {
      throw const ApplicationCenterException('APP_CENTER_REMOTE_FAILED');
    }
    return app;
  }

  @override
  Future<ApplicationTask> readTask(ApplicationTask task) async => task;
  @override
  Future<ApplicationOperationPlan> prepare(
    ServerProfile server,
    ApplicationEnvironment environment,
    ApplicationOperation operation, {
    ApplicationTemplate? template,
    ApplicationConfiguration? configuration,
    ApplicationDeployment? deployment,
    String? sudoPassword,
    ApplicationUninstallSelection? uninstallSelection,
  }) async => ApplicationOperationPlan(
    token: ApplicationDeploymentService.newId(),
    operation: operation,
    deployment: deployment ?? centerDeployment(server),
    configuration: configuration,
    useSudo: false,
    createdAt: DateTime.now(),
  );
  @override
  Future<ApplicationTask> execute(
    ApplicationOperationPlan plan, {
    String? sudoPassword,
    required Future<void> Function(ApplicationTask) persistBeforeLaunch,
  }) async {
    final task = centerTask(plan.deployment);
    await persistBeforeLaunch(task);
    await afterPersist?.call(task);
    launches++;
    return task;
  }
}
