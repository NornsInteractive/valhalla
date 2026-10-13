import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as path;

import '../../data/models/application_center.dart';
import '../../data/models/server_profile.dart';
import '../../infrastructure/ssh/ssh_client_manager.dart';
import '../logging/sanitizer.dart';
import '../utils/shell_quote.dart';
import 'application_compose_service.dart';
import 'application_cleanup_helper.dart';

class ApplicationDeploymentService {
  final SshCommandExecutor ssh;
  final _approvals =
      <String, (ApplicationOperationPlan, ApplicationEnvironment, SSHClient)>{};
  final _cleanupPreviews =
      <
        String,
        (
          ApplicationUninstallPreview,
          ApplicationEnvironment,
          SSHClient,
          Map<String, dynamic>,
        )
      >{};
  final _cleanupRetryTasks = <String, ApplicationTask>{};
  ApplicationDeploymentService(this.ssh);
  static String serverKey(ServerProfile server) =>
      sha256.convert(utf8.encode(server.connectionKey.toString())).toString();
  static String newId() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  static final _id = RegExp(r'^[a-f0-9]{32}$');

  Future<SSHExecutionResult> _command(
    String serverId,
    String command, {
    String? sudoPassword,
    Duration timeout = const Duration(seconds: 30),
  }) => ssh.executeWithLoginShell(
    serverId,
    command,
    sudoPassword: sudoPassword,
    timeout: timeout,
  );

  Future<String> _require(
    String serverId,
    String command, {
    String? sudoPassword,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final result = await _command(
      serverId,
      command,
      sudoPassword: sudoPassword,
      timeout: timeout,
    );
    if (!result.isSuccess) {
      final detail = LogSanitizer.sanitize(result.stderr).trim();
      throw ApplicationCenterException(
        'APP_CENTER_REMOTE_FAILED',
        detail.substring(0, min(1000, detail.length)),
      );
    }
    return result.stdout.trim();
  }

  Future<ApplicationEnvironment> inspect(
    ServerProfile server, {
    String? sudoPassword,
  }) async {
    final basic = await _require(
      server.id,
      r'''printf '%s\n' "$(uname -s)" "$(id -u)" "$(id -g)" "$HOME" "$(uname -m)" "$(cat /etc/machine-id)"; . /etc/os-release; printf '%s\n' "$ID" "$VERSION_ID"''',
    );
    final lines = basic.split('\n');
    if (lines.length < 8 ||
        lines[0] != 'Linux' ||
        !RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(lines[5])) {
      throw const ApplicationCenterException('APP_CENTER_LINUX_REQUIRED');
    }
    final uid = int.parse(lines[1]), gid = int.parse(lines[2]);
    ApplicationComposeService.validatePath(lines[3]);
    var docker = await _command(server.id, "docker info --format '{{.ID}}'");
    var sudo = false;
    if (!docker.isSuccess && uid != 0) {
      docker = await _command(
        server.id,
        "${sudoPassword == null ? 'sudo -n -- ' : ''}docker info --format '{{.ID}}'",
        sudoPassword: sudoPassword,
      );
      sudo = docker.isSuccess;
    }
    final prefix = sudo && sudoPassword == null ? 'sudo -n -- ' : '';
    final compose = await _command(
      server.id,
      '${prefix}docker compose version --short',
      sudoPassword: sudo ? sudoPassword : null,
    );
    final architecture = switch (lines[4]) {
      'x86_64' => 'amd64',
      'aarch64' => 'arm64',
      _ => lines[4],
    };
    final os = lines[6], version = lines[7];
    final supported =
        (os == 'debian' && {'12', '13'}.contains(version) ||
            os == 'ubuntu' && {'22.04', '24.04', '26.04'}.contains(version)) &&
        {'amd64', 'arm64'}.contains(architecture);
    final init = await _command(
      server.id,
      'test "\$(cat /proc/1/comm)" = systemd',
    );
    final blockers = <String>[];
    if (docker.isSuccess) {
      final context = await _command(
        server.id,
        '${prefix}docker context inspect --format \'{{.Endpoints.docker.Host}}\'',
        sudoPassword: sudo ? sudoPassword : null,
      );
      if (!context.isSuccess || !context.stdout.trim().startsWith('unix:///')) {
        blockers.add('APP_CENTER_LOCAL_DOCKER_REQUIRED');
      }
      final overrides = await _command(
        server.id,
        r'''test -z "${DOCKER_HOST-}" && test -z "${DOCKER_CONTEXT-}"''',
      );
      if (!overrides.isSuccess) {
        blockers.add('APP_CENTER_LOCAL_DOCKER_REQUIRED');
      }
    }
    final tools = await _command(
      server.id,
      'command -v bash && command -v setsid && command -v flock && command -v base64 && command -v realpath && command -v ss && command -v awk',
    );
    if (!tools.isSuccess) blockers.add('APP_CENTER_TOOLS_REQUIRED');
    return ApplicationEnvironment(
      serverId: server.id,
      serverKey: serverKey(server),
      home: lines[3],
      os: os,
      osVersion: version,
      architecture: architecture,
      targetIdentity:
          '${lines[5]}|${docker.isSuccess ? docker.stdout.trim() : ''}',
      uid: uid,
      gid: gid,
      dockerAvailable: docker.isSuccess,
      composeAvailable: compose.isSuccess && docker.isSuccess,
      useSudo: sudo,
      canBootstrap:
          supported && blockers.isEmpty && (docker.isSuccess || init.isSuccess),
      blockers: blockers,
    );
  }

  Future<void> _assertEnvironment(
    ApplicationEnvironment env, {
    String? sudoPassword,
    bool dockerRequired = true,
  }) async {
    final host = await _require(env.serverId, 'cat /etc/machine-id');
    if (host != env.targetIdentity.split('|').first) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    if (dockerRequired) {
      final daemon = await _require(
        env.serverId,
        '${env.useSudo && sudoPassword == null ? 'sudo -n -- ' : ''}docker info --format \'{{.ID}}\'',
        sudoPassword: env.useSudo ? sudoPassword : null,
      );
      if ('$host|$daemon' != env.targetIdentity) {
        throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
      }
    }
  }

  Future<void> _write(String serverId, String filename, String content) async {
    ApplicationComposeService.validatePath(filename);
    if (utf8.encode(content).length > 2 * 1024 * 1024) {
      throw const ApplicationCenterException('APP_CENTER_TEMPLATE_TOO_LARGE');
    }
    final client = ssh.getClient(serverId);
    if (client == null || client.isClosed) {
      throw const ApplicationCenterException('APP_CENTER_NOT_CONNECTED');
    }
    var abandoned = false;
    final opening = client.execute(
      'umask 077; test ! -L ${cliShellQuote(filename)} && cat > ${cliShellQuote(filename)}',
    );
    unawaited(
      opening.then((session) {
        if (abandoned) session.close();
      }, onError: (Object _) {}),
    );
    SSHSession? session;
    try {
      session = await opening.timeout(const Duration(seconds: 15));
      final outputs = Future.wait([
        session.stdout.drain<void>(),
        session.stderr.drain<void>(),
      ]);
      session.stdin.add(Uint8List.fromList(utf8.encode(content)));
      await session.stdin.close();
      await Future.wait([
        session.done,
        outputs,
      ]).timeout(const Duration(seconds: 30));
      if (session.exitCode != 0 ||
          !identical(client, ssh.getClient(serverId))) {
        throw const ApplicationCenterException('APP_CENTER_WRITE_FAILED');
      }
    } finally {
      abandoned = true;
      session?.close();
    }
  }

  Future<ApplicationOperationPlan> prepare(
    ServerProfile server,
    ApplicationEnvironment environment,
    ApplicationOperation operation, {
    ApplicationTemplate? template,
    ApplicationConfiguration? configuration,
    ApplicationDeployment? deployment,
    String? sudoPassword,
    ApplicationUninstallSelection? uninstallSelection,
  }) async {
    if (configuration != null) {
      configuration = ApplicationConfiguration.fromJson(
        jsonDecode(jsonEncode(configuration.toJson())) as Map<String, dynamic>,
      );
      configuration = ApplicationComposeService.canonicalDirectoryPaths(
        configuration,
      );
      configuration = configuration.copyWith(
        ports: List.unmodifiable(configuration.ports),
        mounts: List.unmodifiable(configuration.mounts),
        variables: Map.unmodifiable(configuration.variables),
        environment: Map.unmodifiable(
          configuration.environment.map(
            (k, v) => MapEntry(k, Map<String, String>.unmodifiable(v)),
          ),
        ),
      );
    }
    if (!{
      ApplicationOperation.install,
      ApplicationOperation.configure,
      ApplicationOperation.update,
    }.contains(operation)) {
      configuration = null;
    }
    if (environment.serverKey != serverKey(server)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    if (deployment != null &&
        (deployment.serverKey != environment.serverKey ||
            deployment.targetIdentity != environment.targetIdentity)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    if (operation != ApplicationOperation.bootstrap && !environment.ready) {
      throw const ApplicationCenterException('APP_CENTER_ENVIRONMENT_REQUIRED');
    }
    if (uninstallSelection != null &&
        operation != ApplicationOperation.uninstall) {
      throw const ApplicationCenterException(
        'APP_CENTER_CLEANUP_SELECTION_INVALID',
      );
    }
    if (uninstallSelection != null &&
        uninstallSelection.selectedKeys.isEmpty &&
        _cleanupRetryTasks.containsKey(uninstallSelection.previewId)) {
      throw const ApplicationCenterException(
        'APP_CENTER_CLEANUP_SELECTION_INVALID',
      );
    }
    final client = ssh.getClient(server.id);
    if (client == null || client.isClosed) {
      throw const ApplicationCenterException('APP_CENTER_NOT_CONNECTED');
    }
    await _assertEnvironment(
      environment,
      sudoPassword: sudoPassword,
      dockerRequired: operation != ApplicationOperation.bootstrap,
    );
    String composeJson = '';
    String previousComposeJson = '';
    String templateJson = '';
    var preview = '';
    final token = newId();
    if (operation == ApplicationOperation.bootstrap) {
      if (!environment.canBootstrap || environment.blockers.isNotEmpty) {
        throw const ApplicationCenterException(
          'APP_CENTER_BOOTSTRAP_UNSUPPORTED',
        );
      }
      final conflicts = await _command(
        server.id,
        "dpkg-query -W -f='\${db:Status-Status} \${binary:Package}\\n' docker.io podman-docker containerd runc 2>/dev/null || true",
      );
      if (conflicts.stdout
          .split('\n')
          .any((line) => line.startsWith('installed '))) {
        throw const ApplicationCenterException('APP_CENTER_PACKAGE_CONFLICT');
      }
      preview =
          'Docker Engine + Compose: ${environment.os} ${environment.osVersion} ${environment.architecture}';
      deployment = ApplicationDeployment(
        id: token,
        serverKey: environment.serverKey,
        serverId: server.id,
        sourceId: '',
        appId: '',
        name: 'Docker / Compose',
        project: '',
        directory: '${environment.home}/.local/share/valhalla/app-center',
        targetIdentity: environment.targetIdentity,
      );
    } else if ({
      ApplicationOperation.install,
      ApplicationOperation.configure,
      ApplicationOperation.update,
    }.contains(operation)) {
      if (operation == ApplicationOperation.configure && deployment != null) {
        template = await installedTemplate(deployment);
      }
      if (template == null || configuration == null) {
        throw const ApplicationCenterException('APP_CENTER_CONFIG_INVALID');
      }
      if (template.application.architectures.isNotEmpty &&
          !template.application.architectures.contains(
            environment.architecture,
          )) {
        throw const ApplicationCenterException(
          'APP_CENTER_ARCHITECTURE_UNSUPPORTED',
        );
      }
      final id = deployment?.id ?? configuration.variables['AppID'] ?? token;
      if (!_id.hasMatch(id)) {
        throw const ApplicationCenterException('APP_CENTER_CONFIG_INVALID');
      }
      configuration = configuration.copyWith(
        variables: Map.unmodifiable({...configuration.variables, 'AppID': id}),
      );
      final previousConfiguration = deployment == null
          ? null
          : await this.configuration(deployment);
      // Updates preserve the installed naming mode; absence is not consent
      // to recreate a legacy deployment with new explicit container names.
      configuration = configuration.copyWith(
        instanceContainerNames:
            previousConfiguration?.instanceContainerNames ?? true,
        mainService:
            configuration.mainService ??
            previousConfiguration?.mainService ??
            ApplicationComposeService.suggestedMainService(template),
      );
      final project = deployment?.project ?? 'valhalla-app-$id';
      composeJson = ApplicationComposeService.build(
        template,
        configuration,
        id,
        project,
      );
      templateJson = jsonEncode({
        'application': template.application.toJson(),
        'compose': template.compose,
        'metadata': template.metadata,
      });
      if (utf8.encode(templateJson).length > 2 * 1024 * 1024) {
        throw const ApplicationCenterException('APP_CENTER_TEMPLATE_TOO_LARGE');
      }
      if (operation == ApplicationOperation.configure && deployment != null) {
        previousComposeJson = await _previousCompose(
          deployment,
          environment,
          sudoPassword: sudoPassword,
        );
        final previous =
            (jsonDecode(previousComposeJson) as Map)['services'] as Map;
        final next = jsonDecode(composeJson) as Map<String, dynamic>;
        for (final entry in (next['services'] as Map).entries) {
          (entry.value as Map)['image'] = (previous[entry.key] as Map)['image'];
        }
        composeJson = jsonEncode(next);
      }
      if (previousConfiguration != null &&
          configuration.dataRoot != previousConfiguration.dataRoot) {
        throw const ApplicationCenterException(
          'APP_CENTER_DATA_ROOT_IMMUTABLE',
        );
      }
      final controlRoot =
          '${environment.home}/.local/share/valhalla/app-center';
      if (configuration.dataRoot == controlRoot ||
          path.posix.isWithin(configuration.dataRoot, controlRoot) ||
          path.posix.isWithin(controlRoot, configuration.dataRoot)) {
        throw const ApplicationCenterException('APP_CENTER_MOUNT_FORBIDDEN');
      }
      deployment = ApplicationDeployment(
        id: id,
        serverKey: environment.serverKey,
        serverId: server.id,
        sourceId: template.application.sourceId,
        appId: template.application.id,
        name: configuration.name,
        project: project,
        directory: '$controlRoot/deployments/$id',
        version: template.application.version,
        templateHash: template.application.contentHash,
        targetIdentity: environment.targetIdentity,
        endpoint: ApplicationComposeService.endpoint(template, configuration),
      );
      await _checkContainerNames(
        environment,
        deployment,
        composeJson,
        allowExisting: previousConfiguration != null,
        sudoPassword: sudoPassword,
      );
      final previewMap = jsonDecode(composeJson) as Map<String, dynamic>;
      for (final service in (previewMap['services'] as Map).values) {
        if (service is Map) {
          if (service['environment'] is Map) {
            service['environment'] = (service['environment'] as Map).map(
              (k, v) => MapEntry(k, '••••••'),
            );
          }
          for (final key in ['command', 'entrypoint', 'healthcheck']) {
            if (service.containsKey(key)) service[key] = '••••••';
          }
          if (service['labels'] is Map) {
            service['labels'] = (service['labels'] as Map).map(
              (k, v) =>
                  MapEntry(k, k == 'com.valhalla.app.instance' ? v : '••••••'),
            );
          }
        }
      }
      preview = const JsonEncoder.withIndent('  ').convert(previewMap);
      for (final value in configuration.variables.values.where(
        (s) => s.length >= 4,
      )) {
        preview = preview.replaceAll(
          jsonEncode(value).substring(1, jsonEncode(value).length - 1),
          '••••••',
        );
      }
      preview = LogSanitizer.sanitize(preview);
      await _checkPorts(
        server.id,
        configuration,
        previousConfiguration,
        deployment: previousConfiguration == null ? null : deployment,
        environment: environment,
        sudoPassword: sudoPassword,
      );
      for (final mount in configuration.mounts) {
        if (mount.source == controlRoot ||
            path.posix.isWithin(mount.source, controlRoot) ||
            path.posix.isWithin(controlRoot, mount.source) ||
            mount.source.split('/').contains('.ssh')) {
          throw const ApplicationCenterException('APP_CENTER_MOUNT_FORBIDDEN');
        }
        if (!path.posix.isWithin(configuration.dataRoot, mount.source) &&
            mount.source != configuration.dataRoot) {
          await _require(
            server.id,
            'test -d ${cliShellQuote(mount.source)} && test -r ${cliShellQuote(mount.source)}${mount.readOnly ? '' : ' && test -w ${cliShellQuote(mount.source)}'}',
          );
        }
      }
    }
    if (deployment == null ||
        deployment.serverKey != environment.serverKey ||
        !_id.hasMatch(deployment.id)) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    ApplicationComposeService.validatePath(deployment.directory);
    if (operation != ApplicationOperation.install &&
        operation != ApplicationOperation.bootstrap) {
      await _assertOwned(deployment);
    }
    ApplicationCleanupPlan? cleanupPlan;
    if (uninstallSelection != null &&
        uninstallSelection.selectedKeys.isNotEmpty) {
      cleanupPlan = await _prepareCleanup(
        deployment,
        environment,
        uninstallSelection,
        sudoPassword: sudoPassword,
      );
    }
    if ({
      ApplicationOperation.configure,
      ApplicationOperation.update,
      ApplicationOperation.start,
    }.contains(operation)) {
      if (previousComposeJson.isEmpty) {
        previousComposeJson = await _previousCompose(
          deployment,
          environment,
          sudoPassword: sudoPassword,
        );
      }
    }
    int? availableBytes;
    if (configuration != null) {
      final output = await _require(
        server.id,
        'p=${cliShellQuote(configuration.dataRoot)}; while ! test -d "\$p"; do p=\$(dirname -- "\$p"); done; df -Pk -- "\$p"',
      );
      final rows = output.trim().split('\n');
      if (rows.length >= 2) {
        final columns = rows.last.trim().split(RegExp(r'\s+'));
        if (columns.length >= 6) availableBytes = int.tryParse(columns[3]);
        if (availableBytes != null) availableBytes *= 1024;
      }
      if (availableBytes == null || availableBytes < 0) {
        throw const ApplicationCenterException('APP_CENTER_DISK_CHECK_FAILED');
      }
      if (availableBytes == 0) {
        throw const ApplicationCenterException('APP_CENTER_DISK_FULL');
      }
    }
    final changedSections = <String>[];
    if (previousComposeJson.isNotEmpty && composeJson.isNotEmpty) {
      final before =
          (jsonDecode(previousComposeJson) as Map)['services'] as Map;
      final after = (jsonDecode(composeJson) as Map)['services'] as Map;
      for (final section in [
        'image',
        'ports',
        'volumes',
        'environment',
        'healthcheck',
        'restart',
        'container_name',
      ]) {
        if ({...before.keys, ...after.keys}.any(
          (name) =>
              jsonEncode((before[name] as Map?)?[section]) !=
              jsonEncode((after[name] as Map?)?[section]),
        )) {
          changedSections.add(section);
        }
      }
      if (before.keys.toSet().difference(after.keys.toSet()).isNotEmpty ||
          after.keys.toSet().difference(before.keys.toSet()).isNotEmpty) {
        changedSections.add('services');
      }
    }
    final plan = ApplicationOperationPlan(
      token: token,
      operation: operation,
      deployment: deployment,
      configuration: configuration,
      composeJson: composeJson,
      previousComposeJson: previousComposeJson,
      templateJson: templateJson,
      preview: preview,
      useSudo: operation == ApplicationOperation.bootstrap
          ? environment.uid != 0
          : environment.useSudo,
      createdAt: DateTime.now(),
      availableBytes: availableBytes,
      changedSections: changedSections,
      cleanupPlan: cleanupPlan,
    );
    _approvals[token] = (plan, environment, client);
    _approvals.removeWhere(
      (_, item) =>
          DateTime.now().difference(item.$1.createdAt) >
          const Duration(minutes: 5),
    );
    return plan;
  }

  Map<String, dynamic> _cleanupRequest(
    ApplicationDeployment app,
    ApplicationEnvironment environment,
  ) => {
    'app': {'id': app.id, 'directory': app.directory, 'project': app.project},
    'home': environment.home,
    'controlRoot': '${environment.home}/.local/share/valhalla/app-center',
    'targetIdentity': environment.targetIdentity,
    'uid': environment.uid,
    'gid': environment.gid,
  };

  Future<Map<String, dynamic>> _inspectCleanup(
    ApplicationDeployment app,
    ApplicationEnvironment environment, {
    String? sudoPassword,
    ApplicationTask? retryTask,
    bool allowAdvancedCleanup = false,
  }) async {
    final request = base64Encode(
      utf8.encode(
        jsonEncode({
          ..._cleanupRequest(app, environment),
          'allowAdvancedCleanup': allowAdvancedCleanup,
          if (retryTask != null) ..._retryCleanupRequest(retryTask),
        }),
      ),
    );
    final prefix = environment.useSudo && sudoPassword == null
        ? 'sudo -n -- '
        : '';
    final script = base64Encode(utf8.encode(ApplicationCleanupHelper.script));
    final loader =
        'import base64; exec(compile(base64.b64decode("$script"), '
        '"<valhalla-cleanup>", "exec"))';
    final result = await _command(
      app.serverId,
      '${prefix}python3 -c ${cliShellQuote(loader)} inspect ${cliShellQuote(request)}',
      sudoPassword: environment.useSudo ? sudoPassword : null,
      timeout: const Duration(seconds: 90),
    );
    if (!result.isSuccess) {
      return {
        'fingerprint': '',
        'targets': <dynamic>[],
        'inspectionError': 'APP_CENTER_CLEANUP_CAPABILITY_UNAVAILABLE',
      };
    }
    try {
      if (utf8.encode(result.stdout).length > 1024 * 1024) {
        throw const FormatException('oversized inspection');
      }
      return Map<String, dynamic>.from(jsonDecode(result.stdout) as Map);
    } on FormatException {
      throw const ApplicationCenterException(
        'APP_CENTER_CLEANUP_INSPECTION_INCOMPLETE',
      );
    } on TypeError {
      throw const ApplicationCenterException(
        'APP_CENTER_CLEANUP_INSPECTION_INCOMPLETE',
      );
    }
  }

  Future<ApplicationUninstallPreview> inspectUninstall(
    ApplicationDeployment app,
    ApplicationEnvironment environment, {
    String? sudoPassword,
    ApplicationTask? retryTask,
    bool allowAdvancedCleanup = false,
  }) async {
    if (app.serverKey != environment.serverKey ||
        app.targetIdentity != environment.targetIdentity) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    final client = ssh.getClient(app.serverId);
    if (client == null || client.isClosed) {
      throw const ApplicationCenterException('APP_CENTER_NOT_CONNECTED');
    }
    await _assertOwned(app);
    final snapshot = await _inspectCleanup(
      app,
      environment,
      sudoPassword: sudoPassword,
      retryTask: retryTask,
      allowAdvancedCleanup: allowAdvancedCleanup,
    );
    if (!identical(client, ssh.getClient(app.serverId))) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    final targets = (snapshot['targets'] as List? ?? const [])
        .map(
          (value) => ApplicationCleanupTarget.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList();
    final error = snapshot['inspectionError'] as String?;
    if (targets.isEmpty && error != null) {
      // Capability failure must not turn a configured bind into a selectable
      // path. Still give the user a useful read-only list when it can be read.
      final saved = await configuration(app);
      final sources = <String, List<ApplicationMount>>{};
      for (final mount in saved.mounts) {
        sources.putIfAbsent(mount.source, () => []).add(mount);
      }
      sources.putIfAbsent(saved.dataRoot, () => []);
      for (final entry in sources.entries) {
        targets.add(
          ApplicationCleanupTarget(
            key: sha256.convert(utf8.encode('bind\x00${entry.key}')).toString(),
            source: entry.key,
            serviceTargets: List.unmodifiable(
              entry.value.map((m) => '${m.service}:${m.target}'),
            ),
            readOnly: entry.value.every((m) => m.readOnly),
            isDataRoot: entry.key == saved.dataRoot,
            blockedReason: error,
          ),
        );
      }
    }
    final preview = ApplicationUninstallPreview(
      id: newId(),
      deploymentId: app.id,
      deployment: app,
      fingerprint: snapshot['fingerprint'] as String? ?? '',
      targets: List.unmodifiable(targets),
      createdAt: DateTime.now(),
      inspectionError: error,
      allowAdvancedCleanup: allowAdvancedCleanup,
    );
    _cleanupPreviews.removeWhere(
      (_, item) =>
          DateTime.now().difference(item.$1.createdAt) >
          const Duration(minutes: 5),
    );
    _cleanupPreviews[preview.id] = (preview, environment, client, snapshot);
    if (retryTask != null) _cleanupRetryTasks[preview.id] = retryTask;
    _cleanupRetryTasks.removeWhere(
      (key, _) => !_cleanupPreviews.containsKey(key),
    );
    return preview;
  }

  Map<String, dynamic> _retryCleanupRequest(ApplicationTask task) => {
    'cleanupOnly': true,
    'previousTask': task.directory,
    'previousTaskId': task.id,
  };

  Future<ApplicationUninstallPreview> inspectCleanupRetry(
    ApplicationTask task,
    ApplicationEnvironment environment, {
    String? sudoPassword,
    bool allowAdvancedCleanup = false,
  }) async {
    if (task.operation != ApplicationOperation.uninstall ||
        task.stage != ApplicationTaskStage.failed ||
        !task.uninstallCompleted ||
        task.serverKey != environment.serverKey ||
        task.targetIdentity != environment.targetIdentity ||
        !_id.hasMatch(task.deploymentId) ||
        !_id.hasMatch(task.id)) {
      throw const ApplicationCenterException(
        'APP_CENTER_CLEANUP_RETRY_UNAVAILABLE',
      );
    }
    final root = '${environment.home}/.local/share/valhalla/app-center';
    if (task.directory != '$root/tasks/${task.id}') {
      throw const ApplicationCenterException(
        'APP_CENTER_CLEANUP_RETRY_UNAVAILABLE',
      );
    }
    final stub = ApplicationDeployment(
      id: task.deploymentId,
      serverId: task.serverId,
      serverKey: task.serverKey,
      targetIdentity: task.targetIdentity,
      sourceId: '',
      appId: '',
      name: task.name,
      project: 'valhalla-app-${task.deploymentId}',
      directory: '$root/deployments/${task.deploymentId}',
    );
    final archived = ApplicationDeployment.fromJson(
      await _readPrivateJson(stub, 'deployment.uninstalled.json'),
    );
    if (archived.id != stub.id ||
        archived.directory != stub.directory ||
        archived.project != stub.project ||
        archived.serverKey != stub.serverKey ||
        archived.serverId != stub.serverId ||
        archived.targetIdentity != stub.targetIdentity) {
      throw const ApplicationCenterException(
        'APP_CENTER_CLEANUP_OWNERSHIP_CHANGED',
      );
    }
    final allowed = task.cleanupResults
        .where(
          (result) =>
              result.outcome != ApplicationCleanupOutcome.removed &&
              result.outcome != ApplicationCleanupOutcome.alreadyAbsent,
        )
        .map((result) => result.key)
        .toSet();
    if (allowed.isEmpty) {
      throw const ApplicationCenterException(
        'APP_CENTER_CLEANUP_RETRY_UNAVAILABLE',
      );
    }
    final original = await inspectUninstall(
      archived,
      environment,
      sudoPassword: sudoPassword,
      retryTask: task,
      allowAdvancedCleanup: allowAdvancedCleanup,
    );
    final preview = ApplicationUninstallPreview(
      id: original.id,
      deploymentId: original.deploymentId,
      deployment: archived,
      fingerprint: original.fingerprint,
      createdAt: original.createdAt,
      inspectionError: original.inspectionError,
      allowAdvancedCleanup: original.allowAdvancedCleanup,
      targets: List.unmodifiable([
        for (final target in original.targets)
          allowed.contains(target.key)
              ? target
              : ApplicationCleanupTarget(
                  key: target.key,
                  source: target.source,
                  kind: target.kind,
                  references: target.references,
                  serviceTargets: target.serviceTargets,
                  readOnly: target.readOnly,
                  isDataRoot: target.isDataRoot,
                  risks: target.risks,
                  blockedReason: 'APP_CENTER_CLEANUP_NOT_PREVIOUSLY_SELECTED',
                  identity: target.identity,
                ),
      ]),
    );
    final stored = _cleanupPreviews[preview.id]!;
    _cleanupPreviews[preview.id] = (preview, stored.$2, stored.$3, stored.$4);
    return preview;
  }

  Future<ApplicationCleanupPlan> _prepareCleanup(
    ApplicationDeployment app,
    ApplicationEnvironment environment,
    ApplicationUninstallSelection selection, {
    String? sudoPassword,
  }) async {
    final stored = _cleanupPreviews.remove(selection.previewId);
    final retryTask = _cleanupRetryTasks.remove(selection.previewId);
    if (stored == null ||
        stored.$1.deploymentId != app.id ||
        stored.$2.serverKey != environment.serverKey ||
        stored.$2.targetIdentity != environment.targetIdentity ||
        !identical(stored.$3, ssh.getClient(app.serverId)) ||
        DateTime.now().difference(stored.$1.createdAt) >
            const Duration(minutes: 5)) {
      throw const ApplicationCenterException('APP_CENTER_PLAN_EXPIRED');
    }
    if (stored.$1.inspectionError != null ||
        selection.confirmationName != app.name) {
      throw const ApplicationCenterException(
        'APP_CENTER_CLEANUP_ACKNOWLEDGEMENT_REQUIRED',
      );
    }
    final selectedTargets = stored.$1.targets
        .where((target) => selection.selectedKeys.contains(target.key))
        .toList();
    if (selectedTargets.length != selection.selectedKeys.length ||
        selectedTargets.any((target) => !target.selectable)) {
      throw const ApplicationCenterException(
        'APP_CENTER_CLEANUP_SELECTION_INVALID',
      );
    }
    if (selectedTargets.any(
      (target) =>
          target.requiresRiskAcknowledgement &&
          !selection.acknowledgedRiskKeys.contains(target.key),
    )) {
      throw const ApplicationCenterException(
        'APP_CENTER_CLEANUP_ACKNOWLEDGEMENT_REQUIRED',
      );
    }
    final targets = selectedTargets
        .where(
          (target) => !selectedTargets.any(
            (parent) =>
                parent.kind == 'bind' &&
                target.kind == 'bind' &&
                parent.key != target.key &&
                path.posix.isWithin(parent.source, target.source),
          ),
        )
        .toList();
    final latest = await _inspectCleanup(
      app,
      environment,
      sudoPassword: sudoPassword,
      retryTask: retryTask,
      allowAdvancedCleanup: stored.$1.allowAdvancedCleanup,
    );
    final current = (latest['targets'] as List? ?? const [])
        .map(
          (value) => ApplicationCleanupTarget.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList();
    if (latest['inspectionError'] != null ||
        latest['fingerprint'] != stored.$1.fingerprint ||
        targets.any((target) {
          final other = current
              .where((item) => item.key == target.key)
              .firstOrNull;
          return other == null ||
              !other.selectable ||
              jsonEncode(other.toJson()) != jsonEncode(target.toJson());
        })) {
      throw const ApplicationCenterException('APP_CENTER_CLEANUP_PATH_CHANGED');
    }
    return ApplicationCleanupPlan(
      targets: List.unmodifiable(targets),
      cleanupOnly: retryTask != null,
      requestJson: jsonEncode({
        ..._cleanupRequest(app, environment),
        'allowAdvancedCleanup': stored.$1.allowAdvancedCleanup,
        if (retryTask != null) ..._retryCleanupRequest(retryTask),
        'snapshot': stored.$4,
        'selectedKeys': targets.map((target) => target.key).toList()..sort(),
        'acknowledgedRiskKeys': selection.acknowledgedRiskKeys.toList()..sort(),
      }),
    );
  }

  Future<void> _assertOwned(ApplicationDeployment app) async {
    if (!_id.hasMatch(app.id) ||
        app.project != 'valhalla-app-${app.id}' ||
        !app.managed) {
      throw const ApplicationCenterException('APP_CENTER_OWNERSHIP_CHANGED');
    }
    ApplicationComposeService.validatePath(app.directory);
    final data = await _require(
      app.serverId,
      'test "\$(realpath -- ${cliShellQuote(app.directory)})" = ${cliShellQuote(app.directory)} && test ! -L ${cliShellQuote('${app.directory}/.valhalla-app-owner')} && cat -- ${cliShellQuote('${app.directory}/.valhalla-app-owner')}',
    );
    if (data != app.id) {
      throw const ApplicationCenterException('APP_CENTER_OWNERSHIP_CHANGED');
    }
  }

  // Private configuration must bypass diagnostic redaction without entering logs.
  Future<Map<String, dynamic>> _readPrivateJson(
    ApplicationDeployment app,
    String filename, {
    int maxBytes = 1024 * 1024,
  }) async {
    await _assertOwned(app);
    final client = ssh.getClient(app.serverId);
    if (client == null || client.isClosed) {
      throw const ApplicationCenterException('APP_CENTER_NOT_CONNECTED');
    }
    final file = cliShellQuote('${app.directory}/$filename');
    var abandoned = false;
    final opening = client.execute(
      'test ! -L $file && head -c ${maxBytes + 1} -- $file',
    );
    unawaited(
      opening.then((session) {
        if (abandoned) session.close();
      }, onError: (Object _) {}),
    );
    SSHSession? session;
    try {
      session = await opening.timeout(const Duration(seconds: 15));
      final bytes = BytesBuilder(copy: false);
      final stderr = session.stderr.drain<void>();
      Future<void> read() async {
        await for (final chunk in session!.stdout) {
          bytes.add(chunk);
          if (bytes.length > maxBytes) {
            throw const ApplicationCenterException(
              'APP_CENTER_TEMPLATE_TOO_LARGE',
            );
          }
        }
      }

      await Future.wait([
        read(),
        stderr,
        session.done,
      ]).timeout(const Duration(seconds: 30));
      if (session.exitCode != 0 ||
          !identical(client, ssh.getClient(app.serverId))) {
        throw const ApplicationCenterException('APP_CENTER_REMOTE_FAILED');
      }
      final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
      if (decoded is! Map<String, dynamic>) {
        throw const ApplicationCenterException('APP_CENTER_CONFIG_INVALID');
      }
      return decoded;
    } on FormatException {
      throw const ApplicationCenterException('APP_CENTER_CONFIG_INVALID');
    } finally {
      abandoned = true;
      session?.close();
    }
  }

  Future<String> _previousCompose(
    ApplicationDeployment app,
    ApplicationEnvironment env, {
    String? sudoPassword,
  }) async {
    final previous = await _readPrivateJson(app, 'compose.json');
    final prefix = env.useSudo && sudoPassword == null ? 'sudo -n -- ' : '';
    final ids = (await _require(
      app.serverId,
      '${prefix}docker ps -aq --filter ${cliShellQuote('label=com.valhalla.app.instance=${app.id}')}',
      sudoPassword: env.useSudo ? sudoPassword : null,
    )).split('\n').where((s) => s.isNotEmpty).toList();
    if (ids.isEmpty ||
        ids.length > 20 ||
        ids.any((s) => !RegExp(r'^[a-f0-9]{12,64}$').hasMatch(s))) {
      throw const ApplicationCenterException('APP_CENTER_RESTORE_UNAVAILABLE');
    }
    final records = await _require(
      app.serverId,
      '${prefix}docker inspect --format \'{"service":{{json (index .Config.Labels "com.docker.compose.service")}},"image":{{json .Image}}}\' ${ids.map(cliShellQuote).join(' ')}',
      sudoPassword: env.useSudo ? sudoPassword : null,
    );
    final pinned = <String, String>{};
    for (final line in records.split('\n')) {
      final row = jsonDecode(line) as Map;
      final image = row['image'];
      if (row['service'] is! String ||
          image is! String ||
          !RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(image)) {
        throw const ApplicationCenterException(
          'APP_CENTER_RESTORE_UNAVAILABLE',
        );
      }
      pinned[row['service'] as String] = image;
    }
    for (final entry in (previous['services'] as Map).entries) {
      if (pinned[entry.key] == null) {
        throw const ApplicationCenterException(
          'APP_CENTER_RESTORE_UNAVAILABLE',
        );
      }
      (entry.value as Map)['image'] = pinned[entry.key];
    }
    return jsonEncode(previous);
  }

  Future<ApplicationTemplate> installedTemplate(
    ApplicationDeployment app,
  ) async {
    final saved = await _readPrivateJson(
      app,
      'template.json',
      maxBytes: 2 * 1024 * 1024,
    );
    final application = CatalogApplication.fromJson(
      Map<String, dynamic>.from(saved['application'] as Map),
    );
    if (application.id != app.appId ||
        application.sourceId != app.sourceId ||
        application.contentHash != app.templateHash) {
      throw const ApplicationCenterException('APP_CENTER_OWNERSHIP_CHANGED');
    }
    final compose = Map<String, dynamic>.from(saved['compose'] as Map);
    return ApplicationTemplate(
      application: application,
      compose: compose,
      metadata: Map<String, dynamic>.from(saved['metadata'] as Map),
      variables: ApplicationComposeService.variables(compose),
      blockers: ApplicationComposeService.blockers(compose),
    );
  }

  Future<ApplicationTask> execute(
    ApplicationOperationPlan plan, {
    String? sudoPassword,
    required Future<void> Function(ApplicationTask) persistBeforeLaunch,
  }) async {
    final approval = _approvals.remove(plan.token);
    if (approval == null ||
        !identical(approval.$1, plan) ||
        DateTime.now().difference(plan.createdAt) >
            const Duration(minutes: 5) ||
        !identical(approval.$3, ssh.getClient(plan.deployment.serverId))) {
      throw const ApplicationCenterException('APP_CENTER_PLAN_EXPIRED');
    }
    final environment = approval.$2;
    await _assertEnvironment(
      environment,
      sudoPassword: sudoPassword,
      dockerRequired: plan.operation != ApplicationOperation.bootstrap,
    );
    final app = plan.deployment;
    if (plan.composeJson.isNotEmpty) {
      await _checkContainerNames(
        environment,
        app,
        plan.composeJson,
        allowExisting: plan.operation != ApplicationOperation.install,
        sudoPassword: sudoPassword,
      );
    }
    final root = '${environment.home}/.local/share/valhalla/app-center';
    final taskId = newId();
    final directory = '$root/tasks/$taskId';
    // All parent components must resolve without following user-supplied symlinks.
    await _require(
      app.serverId,
      'umask 077; mkdir -p -- ${cliShellQuote('$root/tasks')}; test "\$(realpath -- ${cliShellQuote(root)})" = ${cliShellQuote(root)} && mkdir -- ${cliShellQuote(directory)}',
    );
    if (plan.operation == ApplicationOperation.install) {
      await _require(
        app.serverId,
        'umask 077; mkdir -p -- ${cliShellQuote(path.posix.dirname(app.directory))} && test "\$(realpath -- ${cliShellQuote(path.posix.dirname(app.directory))})" = ${cliShellQuote(path.posix.dirname(app.directory))} && mkdir -- ${cliShellQuote(app.directory)}',
      );
      await _write(
        app.serverId,
        '${app.directory}/.valhalla-app-owner',
        app.id,
      );
      final dataRoot = plan.configuration!.dataRoot;
      await _require(
        app.serverId,
        'umask 077; mkdir -p -- ${cliShellQuote(path.posix.dirname(dataRoot))} && test "\$(realpath -- ${cliShellQuote(path.posix.dirname(dataRoot))})" = ${cliShellQuote(path.posix.dirname(dataRoot))} && mkdir -- ${cliShellQuote(dataRoot)}',
      );
    } else if (plan.operation != ApplicationOperation.bootstrap) {
      await _assertOwned(app);
    }
    if (plan.configuration != null) {
      for (final mount in plan.configuration!.mounts) {
        final dataRoot = plan.configuration!.dataRoot;
        if (mount.source == dataRoot ||
            path.posix.isWithin(dataRoot, mount.source)) {
          await _require(
            app.serverId,
            'umask 077; mkdir -p -- ${cliShellQuote(mount.source)} && test "\$(realpath -- ${cliShellQuote(mount.source)})" = ${cliShellQuote(mount.source)}',
          );
        }
      }
      await _write(
        app.serverId,
        '$directory/compose.next.json',
        plan.composeJson,
      );
      await _write(
        app.serverId,
        '$directory/configuration.next.json',
        jsonEncode(plan.configuration!.toJson()),
      );
      await _write(
        app.serverId,
        '$directory/template.next.json',
        plan.templateJson,
      );
    }
    if (plan.previousComposeJson.isNotEmpty) {
      await _write(
        app.serverId,
        '$directory/compose.previous.next.json',
        plan.previousComposeJson,
      );
    }
    await _write(
      app.serverId,
      '$directory/deployment.next.json',
      jsonEncode(app.toJson()),
    );
    if (plan.cleanupPlan != null) {
      await _write(
        app.serverId,
        '$directory/cleanup.py',
        ApplicationCleanupHelper.script,
      );
      final request = Map<String, dynamic>.from(
        jsonDecode(plan.cleanupPlan!.requestJson) as Map,
      )..['taskDirectory'] = directory;
      await _write(
        app.serverId,
        '$directory/cleanup-request.json',
        jsonEncode(request),
      );
    }
    await _write(
      app.serverId,
      '$directory/worker.sh',
      workerScript(plan, environment, directory, root),
    );
    final task = ApplicationTask(
      id: taskId,
      serverKey: app.serverKey,
      serverId: app.serverId,
      directory: directory,
      deploymentId: app.id,
      name: app.name,
      targetIdentity: app.targetIdentity,
      operation: plan.operation,
      stage: ApplicationTaskStage.queued,
      createdAt: DateTime.now(),
      useSudo: plan.useSudo,
      cleanupResults: List.unmodifiable([
        for (final target
            in plan.cleanupPlan?.targets ?? <ApplicationCleanupTarget>[])
          ApplicationCleanupResult(
            key: target.key,
            source: target.source,
            outcome: ApplicationCleanupOutcome.pending,
          ),
      ]),
    );
    await persistBeforeLaunch(task);
    if (!identical(approval.$3, ssh.getClient(app.serverId))) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    final launch =
        'setsid -f bash ${cliShellQuote('$directory/worker.sh')} </dev/null >/dev/null 2>&1';
    final script =
        'umask 077; : > ${cliShellQuote('$directory/log')}; : > ${cliShellQuote('$directory/state')}; ${plan.useSudo && sudoPassword == null ? 'sudo -n -- ' : ''}$launch';
    // A failed launch acknowledgement remains reconcilable; never resubmit here.
    await _require(
      app.serverId,
      plan.useSudo && sudoPassword != null
          ? 'bash -c ${cliShellQuote(script)}'
          : script,
      sudoPassword: plan.useSudo ? sudoPassword : null,
    );
    return task;
  }

  // Bash read avoids awk's input buffering on a detached, still-open pipe.
  static const _taskLogFunctions = r'''
write_log() {
  local line code bytes=0 last_tick=-1 dropping=0
  export LC_ALL=C
  while true; do
    line=''
    if IFS= read -r -t 1 -n 65536 line; then code=0; else code=$?; fi
    if test "${#line}" -ge 65536; then
      line='[oversized log line omitted]'
      dropping=1
    elif test "$dropping" = 1; then
      if test "$code" -le 1; then dropping=0; fi
      line=''
    fi
    if test -n "$line"; then
      if test "$((bytes + ${#line} + 1))" -gt 262144; then
        mv -f -- "$task/log" "$task/log.previous"
        : > "$task/log"
        chmod 600 "$task/log"
        chown "$owner" "$task/log" 2>/dev/null || true
        bytes=0
      fi
      line="${line//$'\r'/$'\n'}"
      printf '%s\n' "$line" >>"$task/log"
      bytes=$((bytes + ${#line} + 1))
      if test "$SECONDS" -ne "$last_tick"; then
        date +%s >"$task/output-at.tmp"
        mv -- "$task/output-at.tmp" "$task/output-at"
        chown "$owner" "$task/output-at" 2>/dev/null || true
        last_tick=$SECONDS
      fi
    fi
    if test "$code" = 1; then break; fi
  done
}
run() {
  local rendered code
  printf -v rendered '%q ' "$@"
  { date +%s; printf '%s\n' "$rendered"; } >"$task/current.tmp"
  mv -- "$task/current.tmp" "$task/current"
  chown "$owner" "$task/current" 2>/dev/null || true
  printf '\n> %s\n' "$rendered"
  if "$@"; then code=0; else code=$?; fi
  printf '[exit %s]\n' "$code"
  return "$code"
}
''';

  static String workerScript(
    ApplicationOperationPlan plan,
    ApplicationEnvironment env,
    String directory,
    String root,
  ) {
    final app = plan.deployment;
    final compose =
        'docker compose --project-name ${cliShellQuote(app.project)} -f ${cliShellQuote('${app.directory}/compose.json')}';
    final next =
        'docker compose --project-name ${cliShellQuote(app.project)} -f ${cliShellQuote('$directory/compose.next.json')}';
    final action = switch (plan.operation) {
      ApplicationOperation.install ||
      ApplicationOperation.configure ||
      ApplicationOperation.update =>
        '''
stage preparing
run $next config --quiet
if test -f ${cliShellQuote('${app.directory}/compose.json')}; then
  cp -- ${cliShellQuote('$directory/compose.previous.next.json')} ${cliShellQuote('${app.directory}/compose.previous.json')}
  cp -- ${cliShellQuote('${app.directory}/configuration.json')} ${cliShellQuote('${app.directory}/configuration.previous.json')}
  cp -- ${cliShellQuote('${app.directory}/deployment.json')} ${cliShellQuote('${app.directory}/deployment.previous.json')}
  cp -- ${cliShellQuote('${app.directory}/template.json')} ${cliShellQuote('${app.directory}/template.previous.json')}
fi
${plan.operation == ApplicationOperation.configure ? '' : 'stage pulling\nrun $next pull'}
check_cancel
check_target
stage applying
cp -- ${cliShellQuote('$directory/compose.next.json')} ${cliShellQuote('${app.directory}/compose.json')}
cp -- ${cliShellQuote('$directory/configuration.next.json')} ${cliShellQuote('${app.directory}/configuration.json')}
run $compose up --detach --no-build --pull never --wait --wait-timeout 120
cp -- ${cliShellQuote('$directory/deployment.next.json')} ${cliShellQuote('${app.directory}/deployment.json')}
cp -- ${cliShellQuote('$directory/template.next.json')} ${cliShellQuote('${app.directory}/template.json')}
''',
      ApplicationOperation.start =>
        'cp -- ${cliShellQuote('$directory/compose.previous.next.json')} ${cliShellQuote('${app.directory}/compose.json')}\nrun $compose up --detach --no-build --pull never --wait --wait-timeout 120',
      ApplicationOperation.stop => 'run $compose stop --timeout 20',
      ApplicationOperation.restart => 'run $compose restart --timeout 20',
      ApplicationOperation.uninstall =>
        '''${plan.cleanupPlan == null ? '' : 'run python3 ${cliShellQuote('$directory/cleanup.py')} validate ${cliShellQuote('$directory/cleanup-request.json')}'}
${plan.cleanupPlan?.cleanupOnly == true ? '' : 'run $compose down --timeout 20\nmv -- ${cliShellQuote('${app.directory}/deployment.json')} ${cliShellQuote('${app.directory}/deployment.uninstalled.json')}'}
printf '1' > ${cliShellQuote('$directory/uninstall-complete')}
chown ${env.uid}:${env.gid} ${cliShellQuote('$directory/uninstall-complete')} 2>/dev/null || true
${plan.cleanupPlan == null ? '' : 'stage checking\ncheck_target\nrun python3 ${cliShellQuote('$directory/cleanup.py')} cleanup ${cliShellQuote('$directory/cleanup-request.json')}'}''',
      ApplicationOperation.restore =>
        '''test -f ${cliShellQuote('${app.directory}/compose.previous.json')}
cp -- ${cliShellQuote('${app.directory}/compose.previous.json')} ${cliShellQuote('${app.directory}/compose.json')}
cp -- ${cliShellQuote('${app.directory}/configuration.previous.json')} ${cliShellQuote('${app.directory}/configuration.json')}
run $compose up --detach --no-build --pull never --wait --wait-timeout 120
cp -- ${cliShellQuote('${app.directory}/deployment.previous.json')} ${cliShellQuote('${app.directory}/deployment.json')}
cp -- ${cliShellQuote('${app.directory}/template.previous.json')} ${cliShellQuote('${app.directory}/template.json')}''',
      ApplicationOperation.bootstrap => bootstrapScript(env).replaceAllMapped(
        RegExp(r'^(apt-get|install|curl|systemctl|docker) ', multiLine: true),
        (match) => 'run ${match[1]} ',
      ),
    };
    final ownedFiles = [
      'compose.json',
      'configuration.json',
      'deployment.json',
      'compose.previous.json',
      'configuration.previous.json',
      'deployment.previous.json',
      'deployment.uninstalled.json',
      'template.json',
      'template.previous.json',
    ];
    final ownership = plan.operation == ApplicationOperation.bootstrap
        ? ''
        : 'for file in ${ownedFiles.map((f) => cliShellQuote('${app.directory}/$f')).join(' ')}; do if test -f "\$file"; then chmod 600 "\$file"; chown ${env.uid}:${env.gid} "\$file" 2>/dev/null || true; fi; done';
    return '''#!/bin/bash
set -Eeuo pipefail
umask 077
task=${cliShellQuote(directory)}
root=${cliShellQuote(root)}
owner=${env.uid}:${env.gid}
export COMPOSE_ANSI=never COMPOSE_PROGRESS=plain
$_taskLogFunctions
exec 3>&1
exec > >(write_log) 2>&1
logger_pid=\$!
cancelled=0
record() { printf '%s\\n%s\\n' "\$1" "\$2" > "\$task/state.tmp"; mv -- "\$task/state.tmp" "\$task/state"; chmod 600 "\$task/state"; chown ${env.uid}:${env.gid} "\$task/state" "\$task/log" 2>/dev/null || true; }
stage() { record "\$1" ''; }
check_cancel() { if test -f "\$task/cancel"; then cancelled=1; exit 130; fi; }
check_target() { test "\$(cat /etc/machine-id)" = ${cliShellQuote(env.targetIdentity.split('|').first)}${plan.operation == ApplicationOperation.bootstrap ? '' : ' && test "\$(docker info --format \'{{.ID}}\')" = ${cliShellQuote(env.targetIdentity.split('|').last)} && case "\$(docker context inspect --format \'{{.Endpoints.docker.Host}}\')" in unix:///*) ;; *) return 74 ;; esac'}; }
finish() {
  code=\$?
  trap - EXIT
  ${ownership.isEmpty ? '' : '$ownership;'}
  exec 1>&3 2>&3
  if ! wait "\$logger_pid"; then if test "\$code" = 0; then code=125; fi; fi
  if test "\$cancelled" = 1; then record cancelled 130; else
    if test "\$code" = 0; then record succeeded 0; else record failed "\$code"; fi
  fi
  exit "\$code"
}
trap finish EXIT
exec 9>"\$root/server.lock"
chmod 600 "\$root/server.lock"
chown ${env.uid}:${env.gid} "\$root/server.lock" 2>/dev/null || true
printf '%s\\n' "\$\$" > "\$task/pid"
chown ${env.uid}:${env.gid} "\$task/pid" 2>/dev/null || true
printf '%s\\n%s\\n%s\\n' "\$\$" "\$(cat /proc/sys/kernel/random/boot_id)" "\$(awk '{print \$22}' /proc/\$\$/stat)" > "\$task/identity"
chown ${env.uid}:${env.gid} "\$task/identity" 2>/dev/null || true
stage queued
flock -w 900 9 || exit 73
check_target
stage preparing
check_cancel
${{ApplicationOperation.start, ApplicationOperation.stop, ApplicationOperation.restart, ApplicationOperation.uninstall, ApplicationOperation.restore, ApplicationOperation.bootstrap}.contains(plan.operation) ? 'stage applying' : ''}
$action
$ownership
stage checking
''';
  }

  static String bootstrapScript(ApplicationEnvironment env) {
    final os = env.os;
    if (!env.canBootstrap || !{'debian', 'ubuntu'}.contains(os)) {
      throw const ApplicationCenterException(
        'APP_CENTER_BOOTSTRAP_UNSUPPORTED',
      );
    }
    return '''
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --no-remove -y ca-certificates curl
install -d -m 0755 /etc/apt/keyrings
curl --fail --silent --show-error --location --proto '=https' https://download.docker.com/linux/$os/gpg -o /etc/apt/keyrings/valhalla-docker.asc
chmod a+r /etc/apt/keyrings/valhalla-docker.asc
. /etc/os-release
printf 'Types: deb\\nURIs: https://download.docker.com/linux/$os\\nSuites: %s\\nComponents: stable\\nArchitectures: %s\\nSigned-By: /etc/apt/keyrings/valhalla-docker.asc\\n' "\$VERSION_CODENAME" "\$(dpkg --print-architecture)" > /etc/apt/sources.list.d/valhalla-docker.sources
apt-get update
apt-get install --no-remove -y ${env.dockerAvailable ? 'docker-compose-plugin' : 'docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin'}
${env.dockerAvailable ? '' : 'systemctl enable --now docker'}
docker info >/dev/null
docker compose version
''';
  }

  Future<ApplicationTask> readTask(ApplicationTask task) async {
    if (!_id.hasMatch(task.id) ||
        !task.directory.endsWith('/tasks/${task.id}')) {
      throw const ApplicationCenterException('APP_CENTER_TASK_INVALID');
    }
    ApplicationComposeService.validatePath(task.directory);
    await _assertTaskHost(task);
    final identity = cliShellQuote('${task.directory}/identity');
    final live =
        '''live=unknown
if test -f $identity && test ! -L $identity; then
  live=inactive
  pid=\$(sed -n '1p' $identity); boot=\$(sed -n '2p' $identity); started=\$(sed -n '3p' $identity)
  case "\$pid" in ''|*[!0-9]*) ;; *) if test "\$boot" = "\$(cat /proc/sys/kernel/random/boot_id)" && test -r "/proc/\$pid/stat" && test "\$started" = "\$(awk '{print \$22}' /proc/\$pid/stat)" && test "\$(awk '{print \$3}' /proc/\$pid/stat)" != Z; then live=active; fi ;; esac
fi
''';
    final cleanupRead = task.operation == ApplicationOperation.uninstall
        ? '''printf '\\n---VALHALLA-CLEANUP---\\n';
test ! -L ${cliShellQuote('${task.directory}/cleanup.json')} && test ! -L ${cliShellQuote('${task.directory}/uninstall-complete')} || exit 75;
if test -f ${cliShellQuote('${task.directory}/cleanup.json')}; then head -c 1048577 -- ${cliShellQuote('${task.directory}/cleanup.json')};
elif test -f ${cliShellQuote('${task.directory}/uninstall-complete')}; then printf '{"uninstallCompleted":true,"results":[]}'; fi;
'''
        : '';
    final result = await _command(
      task.serverId,
      'test "\$(realpath -- ${cliShellQuote(task.directory)})" = ${cliShellQuote(task.directory)} && test ! -L ${cliShellQuote('${task.directory}/state')} && test ! -L ${cliShellQuote('${task.directory}/log')} && test ! -L ${cliShellQuote('${task.directory}/log.previous')} && test ! -L ${cliShellQuote('${task.directory}/current')} && test ! -L ${cliShellQuote('${task.directory}/output-at')} && { $live head -c 512 -- ${cliShellQuote('${task.directory}/state')}; printf "\\n---VALHALLA-LIVE---\\n%s\\n" "\$live"; printf "\\n---VALHALLA-META---\\n"; head -c 8192 -- ${cliShellQuote('${task.directory}/current')} 2>/dev/null || true; printf "\\n---VALHALLA-OUTPUT---\\n"; head -c 32 -- ${cliShellQuote('${task.directory}/output-at')} 2>/dev/null || true; $cleanupRead printf "\\n---VALHALLA-LOG---\\n"; { tail -c 65536 -- ${cliShellQuote('${task.directory}/log.previous')} 2>/dev/null || true; tail -c 65536 -- ${cliShellQuote('${task.directory}/log')}; } | tail -c 65536; }',
    );
    if (!result.isSuccess) {
      throw const ApplicationCenterException('APP_CENTER_TASK_UNAVAILABLE');
    }
    final parts = result.stdout.split('\n---VALHALLA-LOG---\n');
    final cleanupParts = parts.first.split('\n---VALHALLA-CLEANUP---\n');
    final metadata = cleanupParts.first.split('\n---VALHALLA-META---\n');
    final header = metadata.first.split('\n---VALHALLA-LIVE---\n');
    final output = metadata.length > 1
        ? metadata[1].split('\n---VALHALLA-OUTPUT---\n')
        : const <String>[];
    final command = output.isNotEmpty
        ? output.first.trim().split('\n')
        : const <String>[];
    DateTime? timestamp(String? value) {
      final epoch = int.tryParse(value?.trim() ?? '');
      if (epoch == null || epoch < 0 || epoch > 8640000000000) return null;
      return DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true);
    }

    final state = header.first.trim().split('\n');
    var stage =
        ApplicationTaskStage.values
            .where((v) => v.name == state.firstOrNull)
            .firstOrNull ??
        ApplicationTaskStage.needsInspection;
    int? exitCode = state.length > 1 ? int.tryParse(state[1]) : null;
    if (task.copyWith(stage: stage).isBusy &&
        (header.length < 2 || header[1].trim() != 'active')) {
      if (header.length > 1 && header[1].trim() == 'inactive') {
        stage = ApplicationTaskStage.failed;
        exitCode = 125;
      } else {
        stage = ApplicationTaskStage.needsInspection;
      }
    }
    var uninstallCompleted = task.uninstallCompleted;
    var cleanupResults = task.cleanupResults;
    var confirmedCleanup = false;
    if (cleanupParts.length > 1 && cleanupParts[1].trim().isNotEmpty) {
      try {
        if (utf8.encode(cleanupParts[1]).length > 1024 * 1024) {
          throw const FormatException('oversized cleanup result');
        }
        final cleanup = jsonDecode(cleanupParts[1]) as Map;
        uninstallCompleted = cleanup['uninstallCompleted'] == true;
        final rows = cleanup['results'] as List? ?? const [];
        if (rows.isNotEmpty) {
          final decoded = rows
              .map(
                (value) => ApplicationCleanupResult.fromJson(
                  Map<String, dynamic>.from(value as Map),
                ),
              )
              .toList();
          if (decoded.length != task.cleanupResults.length ||
              decoded.map((row) => row.key).toSet().length != decoded.length ||
              decoded.any(
                (row) => !task.cleanupResults.any(
                  (old) => old.key == row.key && old.source == row.source,
                ),
              )) {
            throw const FormatException('unexpected cleanup target');
          }
          cleanupResults = List.unmodifiable(decoded);
          confirmedCleanup =
              uninstallCompleted &&
              decoded.every(
                (row) =>
                    row.outcome == ApplicationCleanupOutcome.removed ||
                    row.outcome == ApplicationCleanupOutcome.alreadyAbsent,
              );
        }
      } on FormatException {
        throw const ApplicationCenterException(
          'APP_CENTER_CLEANUP_RESULT_INVALID',
        );
      } on TypeError {
        throw const ApplicationCenterException(
          'APP_CENTER_CLEANUP_RESULT_INVALID',
        );
      }
    }
    // A worker exit alone cannot prove every explicitly selected target cleared.
    if (task.operation == ApplicationOperation.uninstall &&
        task.cleanupResults.isNotEmpty &&
        stage == ApplicationTaskStage.succeeded &&
        !confirmedCleanup) {
      throw const ApplicationCenterException(
        'APP_CENTER_CLEANUP_RESULT_INVALID',
      );
    }
    return task.copyWith(
      stage: stage,
      exitCode: exitCode,
      currentCommand: command.length > 1
          ? LogSanitizer.sanitize(command.skip(1).join('\n'))
          : null,
      commandStartedAt: timestamp(command.firstOrNull),
      lastOutputAt: timestamp(output.length > 1 ? output[1] : null),
      lastSyncedAt: DateTime.now(),
      clearSyncError: true,
      uninstallCompleted: uninstallCompleted,
      cleanupResults: cleanupResults,
      logTail: LogSanitizer.sanitize(
        parts.length > 1 ? parts.sublist(1).join('\n---VALHALLA-LOG---\n') : '',
      ),
    );
  }

  Future<void> cancel(ApplicationTask task) async {
    if (!task.canCancel ||
        !_id.hasMatch(task.id) ||
        !task.directory.endsWith('/tasks/${task.id}')) {
      throw const ApplicationCenterException('APP_CENTER_TASK_INVALID');
    }
    await _assertTaskHost(task);
    await _write(task.serverId, '${task.directory}/cancel', task.id);
  }

  Future<void> _assertTaskHost(ApplicationTask task) async {
    final host = await _require(task.serverId, 'cat /etc/machine-id');
    if (task.targetIdentity.isEmpty ||
        host != task.targetIdentity.split('|').first) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
  }

  Future<ApplicationDeployment?> reconcile(
    ApplicationDeployment app,
    ApplicationEnvironment env, {
    String? sudoPassword,
  }) async {
    if (app.serverKey != env.serverKey ||
        app.targetIdentity != env.targetIdentity) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    await _assertOwned(app);
    final output = await _require(
      app.serverId,
      'if test -f ${cliShellQuote('${app.directory}/deployment.json')}; then head -c 65536 -- ${cliShellQuote('${app.directory}/deployment.json')}; fi',
    );
    if (output.isEmpty) return null;
    final saved = ApplicationDeployment.fromJson(
      jsonDecode(output) as Map<String, dynamic>,
    );
    if (saved.id != app.id ||
        saved.directory != app.directory ||
        saved.project != app.project ||
        saved.serverId != app.serverId ||
        !saved.managed ||
        saved.serverKey != env.serverKey ||
        saved.targetIdentity != env.targetIdentity) {
      throw const ApplicationCenterException('APP_CENTER_OWNERSHIP_CHANGED');
    }
    final prefix = env.useSudo && sudoPassword == null ? 'sudo -n -- ' : '';
    final listing = await _require(
      app.serverId,
      '${prefix}docker ps -aq --no-trunc --filter ${cliShellQuote('label=com.valhalla.app.instance=${app.id}')}',
      sudoPassword: env.useSudo ? sudoPassword : null,
    );
    final ids = listing.split('\n').where((v) => v.isNotEmpty).toList();
    if (ids.length > 100 ||
        ids.any((id) => !RegExp(r'^[a-f0-9]{12,64}$').hasMatch(id))) {
      throw const ApplicationCenterException('APP_CENTER_HEALTH_INVALID');
    }
    final services = <ApplicationServiceHealth>[];
    if (ids.isNotEmpty) {
      final inspect = await _require(
        app.serverId,
        '${prefix}docker inspect --format ${cliShellQuote('{{json .Name}}|{{json .State.Status}}|{{if .State.Health}}{{json .State.Health.Status}}{{else}}"none"{{end}}')} ${ids.map(cliShellQuote).join(' ')}',
        sudoPassword: env.useSudo ? sudoPassword : null,
      );
      for (final row in inspect.split('\n').where((r) => r.isNotEmpty)) {
        final fields = row.split('|');
        if (fields.length != 3) {
          throw const ApplicationCenterException('APP_CENTER_HEALTH_INVALID');
        }
        services.add(
          ApplicationServiceHealth(
            name: (jsonDecode(fields[0]) as String).replaceFirst(
              RegExp(r'^/'),
              '',
            ),
            state: jsonDecode(fields[1]) as String,
            health: jsonDecode(fields[2]) as String,
          ),
        );
      }
      if (services.length != ids.length) {
        throw const ApplicationCenterException('APP_CENTER_HEALTH_INVALID');
      }
    }
    final states = services.map((s) => s.state).toList();
    final unhealthy = services.any(
      (s) => s.health != 'none' && s.health != 'healthy',
    );
    final status = states.isEmpty
        ? 'missing'
        : states.every((s) => s == 'running') && !unhealthy
        ? 'running'
        : states.every((s) => s == 'exited' || s == 'created')
        ? 'stopped'
        : 'partial';
    return saved.copyWith(status: status, services: services);
  }

  Future<ApplicationConfiguration> configuration(
    ApplicationDeployment app,
  ) async {
    return ApplicationConfiguration.fromJson(
      await _readPrivateJson(app, 'configuration.json'),
    );
  }

  Future<void> _checkContainerNames(
    ApplicationEnvironment environment,
    ApplicationDeployment deployment,
    String composeJson, {
    required bool allowExisting,
    String? sudoPassword,
  }) async {
    final services = (jsonDecode(composeJson) as Map)['services'] as Map;
    final desired = <String, String>{};
    for (final entry in services.entries) {
      final name = (entry.value as Map)['container_name'];
      if (name is String) desired[name] = entry.key as String;
    }
    if (desired.isEmpty) return;
    final prefix = environment.useSudo && sudoPassword == null
        ? 'sudo -n -- '
        : '';
    const format =
        '{"name":{{json .Names}},"instance":{{json (.Label "com.valhalla.app.instance")}},"project":{{json (.Label "com.docker.compose.project")}},"service":{{json (.Label "com.docker.compose.service")}}}';
    final output = await _require(
      deployment.serverId,
      '${prefix}docker ps -a --no-trunc --format ${cliShellQuote(format)}',
      sudoPassword: environment.useSudo ? sudoPassword : null,
    );
    final rows = output
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (rows.length > 2000) {
      throw const ApplicationCenterException(
        'APP_CENTER_CONTAINER_NAME_CHECK_FAILED',
      );
    }
    for (final row in rows) {
      Map<String, dynamic> item;
      try {
        item = Map<String, dynamic>.from(jsonDecode(row) as Map);
        if (item['name'] is! String ||
            item['instance'] is! String ||
            item['project'] is! String ||
            item['service'] is! String) {
          throw const FormatException('invalid container inventory');
        }
      } on FormatException {
        throw const ApplicationCenterException(
          'APP_CENTER_CONTAINER_NAME_CHECK_FAILED',
        );
      } on TypeError {
        throw const ApplicationCenterException(
          'APP_CENTER_CONTAINER_NAME_CHECK_FAILED',
        );
      }
      final service = desired[item['name']];
      if (service == null) continue;
      if (!allowExisting ||
          item['instance'] != deployment.id ||
          item['project'] != deployment.project ||
          item['service'] != service) {
        throw ApplicationCenterException(
          'APP_CENTER_CONTAINER_NAME_CONFLICT',
          item['name'] as String,
        );
      }
    }
  }

  Future<void> _checkPorts(
    String serverId,
    ApplicationConfiguration configuration,
    ApplicationConfiguration? previous, {
    required ApplicationEnvironment environment,
    ApplicationDeployment? deployment,
    String? sudoPassword,
  }) async {
    if (configuration.ports.isEmpty) return;
    final current = deployment == null
        ? const <ApplicationPort>[]
        : (await _currentBindings(
            deployment,
            environment,
            sudoPassword: sudoPassword,
          )).$1;
    final occupied = await _require(serverId, 'ss -H -ltun');
    for (final row in occupied.split('\n').where((line) => line.isNotEmpty)) {
      final fields = row.trim().split(RegExp(r'\s+'));
      if (fields.length < 6 || !{'tcp', 'udp'}.contains(fields.first)) {
        throw const ApplicationCenterException('APP_CENTER_REMOTE_FAILED');
      }
      final local = fields[4];
      final separator = local.lastIndexOf(':');
      if (separator == -1) {
        throw const ApplicationCenterException('APP_CENTER_REMOTE_FAILED');
      }
      final address = local
          .substring(0, separator)
          .replaceAll(RegExp(r'[\[\]]'), '');
      final published = int.tryParse(local.substring(separator + 1));
      if (published == null) {
        throw const ApplicationCenterException('APP_CENTER_REMOTE_FAILED');
      }
      for (final port in configuration.ports) {
        if (published != port.published || fields.first != port.protocol) {
          continue;
        }
        final binding = port.effectiveBindAddress(configuration.bindAddress);
        if (binding == '127.0.0.1' &&
            !{'127.0.0.1', '0.0.0.0', '::', '*'}.contains(address)) {
          continue;
        }
        // A saved port number alone does not own sockets on other interfaces.
        final owned =
            previous != null &&
            previous.ports.any(
              (old) =>
                  old.published == published &&
                  old.protocol == port.protocol &&
                  old.effectiveBindAddress(previous.bindAddress) == address,
            ) &&
            current.any(
              (actual) =>
                  actual.published == published &&
                  actual.protocol == port.protocol &&
                  actual.bindAddress == address,
            );
        if (!owned) {
          throw ApplicationCenterException(
            'APP_CENTER_PORT_IN_USE',
            '$published',
          );
        }
      }
    }
  }

  Future<(List<ApplicationPort>, List<ApplicationServiceHealth>)>
  _currentBindings(
    ApplicationDeployment app,
    ApplicationEnvironment env, {
    String? sudoPassword,
  }) async {
    final prefix = env.useSudo && sudoPassword == null ? 'sudo -n -- ' : '';
    final listing = await _require(
      app.serverId,
      '${prefix}docker ps -aq --no-trunc --filter ${cliShellQuote('label=com.valhalla.app.instance=${app.id}')} --filter ${cliShellQuote('label=com.docker.compose.project=${app.project}')}',
      sudoPassword: env.useSudo ? sudoPassword : null,
    );
    final ids = listing.split('\n').where((id) => id.isNotEmpty).toList();
    if (ids.length > 100 ||
        ids.any((id) => !RegExp(r'^[a-f0-9]{12,64}$').hasMatch(id))) {
      throw const ApplicationCenterException('APP_CENTER_HEALTH_INVALID');
    }
    final ports = <ApplicationPort>[];
    final services = <ApplicationServiceHealth>[];
    if (ids.isNotEmpty) {
      const format =
          '{"service":{{json (index .Config.Labels "com.docker.compose.service")}},"instance":{{json (index .Config.Labels "com.valhalla.app.instance")}},"project":{{json (index .Config.Labels "com.docker.compose.project")}},"state":{{json .State.Status}},"health":{{if .State.Health}}{{json .State.Health.Status}}{{else}}"none"{{end}},"ports":{{json .NetworkSettings.Ports}}}';
      final output = await _require(
        app.serverId,
        '${prefix}docker inspect --format ${cliShellQuote(format)} ${ids.map(cliShellQuote).join(' ')}',
        sudoPassword: env.useSudo ? sudoPassword : null,
      );
      for (final line in output.split('\n').where((line) => line.isNotEmpty)) {
        final dynamic record;
        try {
          record = jsonDecode(line);
        } on FormatException {
          throw const ApplicationCenterException('APP_CENTER_HEALTH_INVALID');
        }
        if (record is! Map ||
            record['instance'] != app.id ||
            record['project'] != app.project ||
            record['service'] is! String ||
            record['state'] is! String ||
            record['health'] is! String ||
            (record['ports'] != null && record['ports'] is! Map)) {
          throw const ApplicationCenterException('APP_CENTER_HEALTH_INVALID');
        }
        final service = record['service'] as String;
        services.add(
          ApplicationServiceHealth(
            name: service,
            state: record['state'] as String,
            health: record['health'] as String,
          ),
        );
        if (!{'running', 'restarting', 'paused'}.contains(record['state'])) {
          continue;
        }
        for (final entry in (record['ports'] as Map? ?? {}).entries) {
          final parts = '${entry.key}'.split('/');
          final target = int.tryParse(parts.first);
          if (parts.length != 2 ||
              target == null ||
              target < 1 ||
              target > 65535 ||
              !{'tcp', 'udp'}.contains(parts.last) ||
              (entry.value != null && entry.value is! List)) {
            throw const ApplicationCenterException('APP_CENTER_HEALTH_INVALID');
          }
          for (final binding in entry.value as List? ?? []) {
            if (binding is! Map || binding['HostIp'] is! String) {
              throw const ApplicationCenterException(
                'APP_CENTER_HEALTH_INVALID',
              );
            }
            final published = int.tryParse('${binding['HostPort']}');
            if (published == null || published < 1 || published > 65535) {
              throw const ApplicationCenterException(
                'APP_CENTER_HEALTH_INVALID',
              );
            }
            ports.add(
              ApplicationPort(
                service: service,
                target: target,
                published: published,
                protocol: parts.last,
                bindAddress: binding['HostIp'] as String,
              ),
            );
          }
        }
      }
      if (services.length != ids.length) {
        throw const ApplicationCenterException('APP_CENTER_HEALTH_INVALID');
      }
    }
    return (ports, services);
  }

  Future<ApplicationAccessInfo> accessInfo(
    ApplicationDeployment app,
    ApplicationEnvironment env, {
    String? sudoPassword,
  }) async {
    if (app.serverId != env.serverId ||
        app.serverKey != env.serverKey ||
        app.targetIdentity != env.targetIdentity) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    final client = ssh.getClient(app.serverId);
    if (client == null || client.isClosed) {
      throw const ApplicationCenterException('APP_CENTER_NOT_CONNECTED');
    }
    await _assertOwned(app);
    await _assertEnvironment(env, sudoPassword: sudoPassword);
    final template = await installedTemplate(app);
    final config = await configuration(app);
    final expected = ApplicationComposeService.webPort(template, config);
    final (ports, services) = await _currentBindings(
      app,
      env,
      sudoPassword: sudoPassword,
    );
    final matches = ports.where((port) => port.key == expected?.key);
    final management =
        matches
            .where(
              (port) => {'127.0.0.1', '0.0.0.0'}.contains(port.bindAddress),
            )
            .firstOrNull ??
        matches.firstOrNull;
    Uri? endpoint;
    var probeStatus = ApplicationAccessProbeStatus.notApplicable;
    int? httpStatus, probeExitCode;
    if (management != null) {
      probeStatus = ApplicationAccessProbeStatus.unavailable;
      if ({
        '127.0.0.1',
        '0.0.0.0',
        '::1',
        '::',
      }.contains(management.bindAddress)) {
        endpoint = ApplicationComposeService.endpoint(template, config)
            ?.replace(
              host: management.bindAddress!.contains(':') ? '::1' : '127.0.0.1',
              port: management.published,
            );
        if (endpoint != null) {
          final probe = Uri(
            scheme: endpoint.scheme,
            host: endpoint.host,
            port: endpoint.port,
            path: '/',
          );
          final result = await _command(
            app.serverId,
            "if command -v curl >/dev/null 2>&1; then curl -q --noproxy '*' --connect-timeout 3 --max-time 8 --silent --output /dev/null --write-out '%{http_code}' --proto '=http,https' -- ${cliShellQuote(probe.toString())}; else printf 'unavailable'; fi",
            timeout: const Duration(seconds: 12),
          );
          if (result.stdout.trim() != 'unavailable') {
            probeExitCode = result.exitCode;
            final code = int.tryParse(result.stdout.trim());
            if (code != null && code >= 100 && code <= 599) {
              httpStatus = code;
            }
            probeStatus = result.isSuccess && httpStatus != null
                ? ApplicationAccessProbeStatus.reachable
                : ApplicationAccessProbeStatus.failed;
          }
        }
      }
    }
    if (!identical(client, ssh.getClient(app.serverId)) || client.isClosed) {
      throw const ApplicationCenterException('APP_CENTER_TARGET_CHANGED');
    }
    return ApplicationAccessInfo(
      ports: List.unmodifiable(ports),
      services: List.unmodifiable(services),
      managementPort: management,
      sshEndpoint: endpoint,
      probeStatus: probeStatus,
      httpStatus: httpStatus,
      probeExitCode: probeExitCode,
      checkedAt: DateTime.now(),
    );
  }

  Future<String> logs(
    ApplicationDeployment app,
    ApplicationEnvironment env, {
    String? sudoPassword,
  }) async {
    await _assertOwned(app);
    await _assertEnvironment(env, sudoPassword: sudoPassword);
    final prefix = env.useSudo && sudoPassword == null ? 'sudo -n -- ' : '';
    final command =
        'set -o pipefail; ${prefix}docker compose --project-name ${cliShellQuote(app.project)} -f ${cliShellQuote('${app.directory}/compose.json')} logs --no-color --tail 200 2>&1 | tail -c 65536';
    final output = await _require(
      app.serverId,
      env.useSudo && sudoPassword != null
          ? 'bash -c ${cliShellQuote(command)}'
          : command,
      sudoPassword: env.useSudo ? sudoPassword : null,
    );
    return LogSanitizer.sanitize(output);
  }
}
