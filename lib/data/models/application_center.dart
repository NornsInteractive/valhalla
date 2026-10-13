enum ApplicationOperation {
  install,
  configure,
  update,
  start,
  stop,
  restart,
  uninstall,
  restore,
  bootstrap,
}

enum ApplicationTaskStage {
  queued,
  preparing,
  pulling,
  applying,
  checking,
  succeeded,
  failed,
  cancelled,
  needsInspection,
}

class ApplicationSource {
  static const official = ApplicationSource(
    id: 'zimaos-official',
    name: 'CasaOS / ZimaOS',
    url: 'https://cdn.jsdelivr.net/gh/IceWhaleTech/CasaOS-AppStore@gh-pages',
  );
  final String id, name, url;
  final bool enabled;
  const ApplicationSource({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
  });
  ApplicationSource copyWith({bool? enabled}) => ApplicationSource(
    id: id,
    name: name,
    url: url,
    enabled: enabled ?? this.enabled,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'enabled': enabled,
  };
  factory ApplicationSource.fromJson(Map<String, dynamic> j) =>
      ApplicationSource(
        id: j['id'] as String,
        name: j['name'] as String,
        url: j['url'] as String,
        enabled: j['enabled'] != false,
      );
}

class CatalogApplication {
  final String sourceId, id, title, summary, category, version, contentHash;
  final String iconUrl, thumbnailUrl, composeUrl, metadataUrl;
  final List<String> architectures;
  const CatalogApplication({
    required this.sourceId,
    required this.id,
    required this.title,
    this.summary = '',
    this.category = 'Others',
    this.version = '',
    this.contentHash = '',
    this.iconUrl = '',
    this.thumbnailUrl = '',
    required this.composeUrl,
    this.metadataUrl = '',
    this.architectures = const [],
  });
  String get key => '$sourceId::$id';
  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'id': id,
    'title': title,
    'summary': summary,
    'category': category,
    'version': version,
    'contentHash': contentHash,
    'iconUrl': iconUrl,
    'thumbnailUrl': thumbnailUrl,
    'composeUrl': composeUrl,
    'metadataUrl': metadataUrl,
    'architectures': architectures,
  };
  factory CatalogApplication.fromJson(Map<String, dynamic> j) =>
      CatalogApplication(
        sourceId: j['sourceId'] as String,
        id: j['id'] as String,
        title: j['title'] as String,
        summary: j['summary'] as String? ?? '',
        category: j['category'] as String? ?? 'Others',
        version: j['version'] as String? ?? '',
        contentHash: j['contentHash'] as String? ?? '',
        iconUrl: j['iconUrl'] as String? ?? '',
        thumbnailUrl: j['thumbnailUrl'] as String? ?? '',
        composeUrl: j['composeUrl'] as String,
        metadataUrl: j['metadataUrl'] as String? ?? '',
        architectures: (j['architectures'] as List? ?? []).cast<String>(),
      );
}

class ApplicationTemplate {
  final CatalogApplication application;
  final Map<String, dynamic> compose, metadata;
  final Set<String> variables;
  final List<String> blockers;
  const ApplicationTemplate({
    required this.application,
    required this.compose,
    required this.metadata,
    this.variables = const {},
    this.blockers = const [],
  });
  bool get canInstall => blockers.isEmpty;
  String get description =>
      metadata['description'] as String? ?? application.summary;
  List<String> get screenshots =>
      (metadata['screenshot_link'] as List? ?? []).whereType<String>().toList();
}

class ApplicationPort {
  final String service, protocol;
  final int target, published;
  final String? bindAddress;
  const ApplicationPort({
    required this.service,
    required this.target,
    required this.published,
    this.protocol = 'tcp',
    this.bindAddress,
  });
  String get key => '$service/$target/$protocol';
  String effectiveBindAddress(String applicationBindAddress) =>
      bindAddress ?? applicationBindAddress;
  Map<String, dynamic> toJson() => {
    'service': service,
    'target': target,
    'published': published,
    'protocol': protocol,
    if (bindAddress != null) 'bindAddress': bindAddress,
  };
  factory ApplicationPort.fromJson(Map<String, dynamic> j) => ApplicationPort(
    service: j['service'] as String,
    target: j['target'] as int,
    published: j['published'] as int,
    protocol: j['protocol'] as String? ?? 'tcp',
    bindAddress: j['bindAddress'] as String?,
  );
}

class ApplicationMount {
  final String service, target, source;
  final bool readOnly;
  const ApplicationMount({
    required this.service,
    required this.target,
    required this.source,
    this.readOnly = false,
  });
  String get key => '$service:$target';
  Map<String, dynamic> toJson() => {
    'service': service,
    'target': target,
    'source': source,
    'readOnly': readOnly,
  };
  factory ApplicationMount.fromJson(Map<String, dynamic> j) => ApplicationMount(
    service: j['service'] as String,
    target: j['target'] as String,
    source: j['source'] as String,
    readOnly: j['readOnly'] == true,
  );
}

class ApplicationConfiguration {
  final String name, dataRoot, bindAddress;
  final bool jellyfinSoftwareMode;

  /// Missing in saved configurations means Compose's legacy generated names.
  final bool instanceContainerNames;
  final String? mainService;
  final List<ApplicationPort> ports;
  final List<ApplicationMount> mounts;

  /// Values remain in memory / private remote config, never plain local preferences.
  final Map<String, String> variables;
  final Map<String, Map<String, String>> environment;
  const ApplicationConfiguration({
    required this.name,
    required this.dataRoot,
    this.bindAddress = '127.0.0.1',
    this.jellyfinSoftwareMode = false,
    this.instanceContainerNames = false,
    this.mainService,
    this.ports = const [],
    this.mounts = const [],
    this.variables = const {},
    this.environment = const {},
  });
  ApplicationConfiguration copyWith({
    String? name,
    String? dataRoot,
    String? bindAddress,
    bool? jellyfinSoftwareMode,
    bool? instanceContainerNames,
    String? mainService,
    List<ApplicationPort>? ports,
    List<ApplicationMount>? mounts,
    Map<String, String>? variables,
    Map<String, Map<String, String>>? environment,
  }) => ApplicationConfiguration(
    name: name ?? this.name,
    dataRoot: dataRoot ?? this.dataRoot,
    bindAddress: bindAddress ?? this.bindAddress,
    jellyfinSoftwareMode: jellyfinSoftwareMode ?? this.jellyfinSoftwareMode,
    instanceContainerNames:
        instanceContainerNames ?? this.instanceContainerNames,
    mainService: mainService ?? this.mainService,
    ports: ports ?? this.ports,
    mounts: mounts ?? this.mounts,
    variables: variables ?? this.variables,
    environment: environment ?? this.environment,
  );
  Map<String, dynamic> toJson() => {
    'name': name,
    'dataRoot': dataRoot,
    'bindAddress': bindAddress,
    'jellyfinSoftwareMode': jellyfinSoftwareMode,
    if (instanceContainerNames) 'instanceContainerNames': true,
    if (mainService != null) 'mainService': mainService,
    'ports': ports.map((p) => p.toJson()).toList(),
    'mounts': mounts.map((m) => m.toJson()).toList(),
    'variables': variables,
    'environment': environment,
  };
  factory ApplicationConfiguration.fromJson(Map<String, dynamic> j) =>
      ApplicationConfiguration(
        name: j['name'] as String,
        dataRoot: j['dataRoot'] as String,
        bindAddress: j['bindAddress'] as String? ?? '127.0.0.1',
        jellyfinSoftwareMode: j['jellyfinSoftwareMode'] == true,
        instanceContainerNames: j['instanceContainerNames'] == true,
        mainService: j['mainService'] as String?,
        ports: (j['ports'] as List? ?? [])
            .map(
              (p) =>
                  ApplicationPort.fromJson(Map<String, dynamic>.from(p as Map)),
            )
            .toList(),
        mounts: (j['mounts'] as List? ?? [])
            .map(
              (p) => ApplicationMount.fromJson(
                Map<String, dynamic>.from(p as Map),
              ),
            )
            .toList(),
        variables: Map<String, String>.from(j['variables'] as Map? ?? {}),
        environment: (j['environment'] as Map? ?? {}).map(
          (k, v) => MapEntry(k as String, Map<String, String>.from(v as Map)),
        ),
      );
}

class ApplicationServiceHealth {
  final String name, state, health;
  const ApplicationServiceHealth({
    required this.name,
    required this.state,
    this.health = 'none',
  });
  Map<String, dynamic> toJson() => {
    'name': name,
    'state': state,
    'health': health,
  };
  factory ApplicationServiceHealth.fromJson(Map<String, dynamic> j) =>
      ApplicationServiceHealth(
        name: j['name'] as String,
        state: j['state'] as String,
        health: j['health'] as String? ?? 'none',
      );
}

class ApplicationDeployment {
  final String id,
      serverKey,
      serverId,
      sourceId,
      appId,
      name,
      project,
      directory,
      version,
      templateHash,
      targetIdentity;
  final String status;
  final Uri? endpoint;
  final bool managed;
  final List<ApplicationServiceHealth> services;
  const ApplicationDeployment({
    required this.id,
    required this.serverKey,
    required this.serverId,
    required this.sourceId,
    required this.appId,
    required this.name,
    required this.project,
    required this.directory,
    required this.targetIdentity,
    this.version = '',
    this.templateHash = '',
    this.status = 'unknown',
    this.endpoint,
    this.managed = true,
    this.services = const [],
  });
  ApplicationDeployment copyWith({
    String? status,
    List<ApplicationServiceHealth>? services,
  }) => ApplicationDeployment(
    id: id,
    serverKey: serverKey,
    serverId: serverId,
    sourceId: sourceId,
    appId: appId,
    name: name,
    project: project,
    directory: directory,
    targetIdentity: targetIdentity,
    version: version,
    templateHash: templateHash,
    status: status ?? this.status,
    endpoint: endpoint,
    managed: managed,
    services: services ?? this.services,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'serverKey': serverKey,
    'serverId': serverId,
    'sourceId': sourceId,
    'appId': appId,
    'name': name,
    'project': project,
    'directory': directory,
    'targetIdentity': targetIdentity,
    'version': version,
    'templateHash': templateHash,
    'status': status,
    'endpoint': endpoint?.toString(),
    'managed': managed,
    'services': services.map((s) => s.toJson()).toList(),
  };
  factory ApplicationDeployment.fromJson(
    Map<String, dynamic> j,
  ) => ApplicationDeployment(
    id: j['id'] as String,
    serverKey: j['serverKey'] as String,
    serverId: j['serverId'] as String,
    sourceId: j['sourceId'] as String,
    appId: j['appId'] as String,
    name: j['name'] as String,
    project: j['project'] as String,
    directory: j['directory'] as String,
    targetIdentity: j['targetIdentity'] as String,
    version: j['version'] as String? ?? '',
    templateHash: j['templateHash'] as String? ?? '',
    status: j['status'] as String? ?? 'unknown',
    endpoint: j['endpoint'] == null ? null : Uri.parse(j['endpoint'] as String),
    managed: j['managed'] != false,
    services: (j['services'] as List? ?? const [])
        .map(
          (s) => ApplicationServiceHealth.fromJson(
            Map<String, dynamic>.from(s as Map),
          ),
        )
        .toList(),
  );
}

class ApplicationEnvironment {
  final String serverId,
      serverKey,
      home,
      os,
      osVersion,
      architecture,
      targetIdentity;
  final int uid, gid;
  final bool dockerAvailable, composeAvailable, useSudo, canBootstrap;
  final List<String> blockers;
  const ApplicationEnvironment({
    required this.serverId,
    required this.serverKey,
    required this.home,
    required this.os,
    required this.osVersion,
    required this.architecture,
    required this.targetIdentity,
    required this.uid,
    required this.gid,
    required this.dockerAvailable,
    required this.composeAvailable,
    this.useSudo = false,
    this.canBootstrap = false,
    this.blockers = const [],
  });
  bool get ready => dockerAvailable && composeAvailable && blockers.isEmpty;
}

class ApplicationOperationPlan {
  final String token;
  final ApplicationOperation operation;
  final ApplicationDeployment deployment;
  final ApplicationConfiguration? configuration;
  final String composeJson, preview, previousComposeJson, templateJson;
  final bool useSudo;
  final DateTime createdAt;
  final int? availableBytes;
  final List<String> changedSections;
  final ApplicationCleanupPlan? cleanupPlan;
  const ApplicationOperationPlan({
    required this.token,
    required this.operation,
    required this.deployment,
    this.configuration,
    this.composeJson = '',
    this.preview = '',
    this.previousComposeJson = '',
    this.templateJson = '',
    this.useSudo = false,
    required this.createdAt,
    this.availableBytes,
    this.changedSections = const [],
    this.cleanupPlan,
  });
}

class ApplicationTask {
  final String id,
      serverKey,
      serverId,
      directory,
      deploymentId,
      name,
      targetIdentity;
  final ApplicationOperation operation;
  final ApplicationTaskStage stage;
  final String logTail;
  final String currentCommand;
  final DateTime? commandStartedAt, lastOutputAt, lastSyncedAt;
  final String? syncError;
  final int? exitCode;
  final bool useSudo;
  final DateTime createdAt;
  final bool uninstallCompleted;
  final List<ApplicationCleanupResult> cleanupResults;
  const ApplicationTask({
    required this.id,
    required this.serverKey,
    required this.serverId,
    required this.directory,
    required this.deploymentId,
    required this.name,
    required this.operation,
    required this.stage,
    required this.createdAt,
    this.targetIdentity = '',
    this.logTail = '',
    this.currentCommand = '',
    this.commandStartedAt,
    this.lastOutputAt,
    this.lastSyncedAt,
    this.syncError,
    this.exitCode,
    this.useSudo = false,
    this.uninstallCompleted = false,
    this.cleanupResults = const [],
  });
  bool get isBusy => {
    ApplicationTaskStage.queued,
    ApplicationTaskStage.preparing,
    ApplicationTaskStage.pulling,
    ApplicationTaskStage.applying,
    ApplicationTaskStage.checking,
  }.contains(stage);
  bool get canCancel =>
      {
        ApplicationTaskStage.queued,
        ApplicationTaskStage.preparing,
        ApplicationTaskStage.pulling,
      }.contains(stage) &&
      operation != ApplicationOperation.bootstrap;
  ApplicationTask copyWith({
    ApplicationTaskStage? stage,
    String? logTail,
    int? exitCode,
    String? currentCommand,
    DateTime? commandStartedAt,
    DateTime? lastOutputAt,
    DateTime? lastSyncedAt,
    String? syncError,
    bool clearSyncError = false,
    bool? uninstallCompleted,
    List<ApplicationCleanupResult>? cleanupResults,
  }) => ApplicationTask(
    id: id,
    serverKey: serverKey,
    serverId: serverId,
    directory: directory,
    deploymentId: deploymentId,
    name: name,
    operation: operation,
    stage: stage ?? this.stage,
    createdAt: createdAt,
    targetIdentity: targetIdentity,
    logTail: logTail ?? this.logTail,
    currentCommand: currentCommand ?? this.currentCommand,
    commandStartedAt: commandStartedAt ?? this.commandStartedAt,
    lastOutputAt: lastOutputAt ?? this.lastOutputAt,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    syncError: clearSyncError ? null : syncError ?? this.syncError,
    exitCode: exitCode ?? this.exitCode,
    useSudo: useSudo,
    uninstallCompleted: uninstallCompleted ?? this.uninstallCompleted,
    cleanupResults: cleanupResults ?? this.cleanupResults,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'serverKey': serverKey,
    'serverId': serverId,
    'directory': directory,
    'deploymentId': deploymentId,
    'name': name,
    'targetIdentity': targetIdentity,
    'operation': operation.name,
    'stage': stage.name,
    'createdAt': createdAt.toIso8601String(),
    'useSudo': useSudo,
    'exitCode': exitCode,
    'commandStartedAt': commandStartedAt?.toIso8601String(),
    'lastOutputAt': lastOutputAt?.toIso8601String(),
    'uninstallCompleted': uninstallCompleted,
    'cleanupResults': cleanupResults.map((result) => result.toJson()).toList(),
  };
  factory ApplicationTask.fromJson(Map<String, dynamic> j) => ApplicationTask(
    id: j['id'] as String,
    serverKey: j['serverKey'] as String,
    serverId: j['serverId'] as String,
    directory: j['directory'] as String,
    deploymentId: j['deploymentId'] as String,
    name: j['name'] as String,
    targetIdentity: j['targetIdentity'] as String? ?? '',
    operation: ApplicationOperation.values.byName(j['operation'] as String),
    stage: ApplicationTaskStage.values.byName(j['stage'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
    useSudo: j['useSudo'] == true,
    exitCode: j['exitCode'] as int?,
    commandStartedAt: DateTime.tryParse(j['commandStartedAt'] as String? ?? ''),
    lastOutputAt: DateTime.tryParse(j['lastOutputAt'] as String? ?? ''),
    uninstallCompleted: j['uninstallCompleted'] == true,
    cleanupResults: (j['cleanupResults'] as List? ?? const [])
        .map(
          (value) => ApplicationCleanupResult.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(),
  );
}

/// An inspection result, never an authorization to remove a directory.
class ApplicationCleanupTarget {
  final String key, source;
  final String kind;
  final List<String> references;
  final List<String> serviceTargets, risks;
  final bool readOnly;
  final bool isDataRoot;
  final String? blockedReason;
  final Map<String, dynamic> identity;
  const ApplicationCleanupTarget({
    required this.key,
    required this.source,
    this.kind = 'bind',
    this.references = const [],
    this.serviceTargets = const [],
    this.risks = const [],
    this.readOnly = false,
    this.isDataRoot = false,
    this.blockedReason,
    this.identity = const {},
  });
  bool get selectable => blockedReason == null && identity.isNotEmpty;
  bool get requiresRiskAcknowledgement => risks.isNotEmpty;
  Map<String, dynamic> toJson() => {
    'key': key,
    'source': source,
    if (kind != 'bind') 'kind': kind,
    if (references.isNotEmpty) 'references': references,
    'serviceTargets': serviceTargets,
    'risks': risks,
    'readOnly': readOnly,
    'isDataRoot': isDataRoot,
    'blockedReason': blockedReason,
    'identity': identity,
  };
  factory ApplicationCleanupTarget.fromJson(Map<String, dynamic> json) =>
      ApplicationCleanupTarget(
        key: json['key'] as String,
        source: json['source'] as String,
        kind: json['kind'] as String? ?? 'bind',
        references: List<String>.unmodifiable(
          (json['references'] as List? ?? const []).cast<String>(),
        ),
        serviceTargets: List<String>.unmodifiable(
          (json['serviceTargets'] as List? ?? const []).cast<String>(),
        ),
        risks: List<String>.unmodifiable(
          (json['risks'] as List? ?? const []).cast<String>(),
        ),
        readOnly: json['readOnly'] == true,
        isDataRoot: json['isDataRoot'] == true,
        blockedReason: json['blockedReason'] as String?,
        identity: Map<String, dynamic>.unmodifiable(
          Map<String, dynamic>.from(json['identity'] as Map? ?? const {}),
        ),
      );
}

class ApplicationUninstallPreview {
  final String id, deploymentId, fingerprint;
  final ApplicationDeployment deployment;
  final List<ApplicationCleanupTarget> targets;
  final DateTime createdAt;
  final String? inspectionError;
  final bool allowAdvancedCleanup;
  const ApplicationUninstallPreview({
    required this.id,
    required this.deploymentId,
    required this.deployment,
    required this.fingerprint,
    required this.targets,
    required this.createdAt,
    this.inspectionError,
    this.allowAdvancedCleanup = false,
  });
}

/// Selection is by inspected keys. UI-supplied paths are never accepted.
class ApplicationUninstallSelection {
  final String previewId, confirmationName;
  final Set<String> selectedKeys, acknowledgedRiskKeys;
  ApplicationUninstallSelection({
    required this.previewId,
    required this.confirmationName,
    required Set<String> selectedKeys,
    Set<String> acknowledgedRiskKeys = const {},
  }) : selectedKeys = Set.unmodifiable(selectedKeys),
       acknowledgedRiskKeys = Set.unmodifiable(acknowledgedRiskKeys);
}

class ApplicationCleanupPlan {
  final String requestJson;
  final List<ApplicationCleanupTarget> targets;
  final bool cleanupOnly;
  const ApplicationCleanupPlan({
    required this.requestJson,
    required this.targets,
    this.cleanupOnly = false,
  });
}

enum ApplicationCleanupOutcome {
  pending,
  removed,
  alreadyAbsent,
  retained,
  failed,
}

class ApplicationCleanupResult {
  final String key, source;
  final ApplicationCleanupOutcome outcome;
  final String? reasonCode;
  const ApplicationCleanupResult({
    required this.key,
    required this.source,
    required this.outcome,
    this.reasonCode,
  });
  Map<String, dynamic> toJson() => {
    'key': key,
    'source': source,
    'outcome': outcome.name,
    'reasonCode': reasonCode,
  };
  factory ApplicationCleanupResult.fromJson(Map<String, dynamic> json) =>
      ApplicationCleanupResult(
        key: json['key'] as String,
        source: json['source'] as String,
        outcome:
            ApplicationCleanupOutcome.values
                .where((value) => value.name == json['outcome'])
                .firstOrNull ??
            ApplicationCleanupOutcome.retained,
        reasonCode: json['reasonCode'] as String?,
      );
}

class ApplicationCenterException implements Exception {
  final String code;
  final String? detail;
  const ApplicationCenterException(this.code, [this.detail]);
  @override
  String toString() => detail == null ? code : '$code: $detail';
}

enum ApplicationAccessProbeStatus {
  notApplicable,
  unavailable,
  reachable,
  failed,
}

class ApplicationAccessInfo {
  final List<ApplicationPort> ports;
  final List<ApplicationServiceHealth> services;
  final ApplicationPort? managementPort;
  final Uri? sshEndpoint;
  final ApplicationAccessProbeStatus probeStatus;
  final int? httpStatus, probeExitCode;
  final DateTime checkedAt;
  const ApplicationAccessInfo({
    required this.ports,
    required this.services,
    required this.probeStatus,
    required this.checkedAt,
    this.managementPort,
    this.sshEndpoint,
    this.httpStatus,
    this.probeExitCode,
  });
}
