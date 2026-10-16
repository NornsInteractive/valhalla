import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'agent_profile.dart';
import 'server_profile.dart';

enum AgentUpdateComponent { cli, acp }

enum AgentUpdateStatus { current, available, unsupported, missing, error }

String agentUpdateTargetKey(ServerProfile server, AgentProfile profile) =>
    sha256
        .convert(
          utf8.encode(
            jsonEncode([
              server.connectionKey.toString(),
              profile.id,
              profile.executionTarget,
              profile.containerBinding,
              profile.containerReference,
              profile.containerUser,
              profile.cliCommand,
              profile.acpCommand,
              profile.installCommand,
              profile.acpInstallCommand,
            ]),
          ),
        )
        .toString();

/// Locks all agents sharing an installation environment, not only a card ID.
String agentUpdateScopeKey(AgentProfile profile) => jsonEncode([
  profile.serverId,
  profile.executionTarget,
  profile.containerReference,
  profile.containerUser,
]);

class AgentComponentUpdate {
  final AgentUpdateComponent component;
  final AgentUpdateStatus status;
  final String? installedVersion;
  final String? latestVersion;
  final String? source;
  final String? reasonCode;
  final String? command;
  final bool migratesClaudeAdapter;
  final String? catalogIdentity;
  final String? replacementAcpCommand;

  const AgentComponentUpdate({
    required this.component,
    required this.status,
    this.installedVersion,
    this.latestVersion,
    this.source,
    this.reasonCode,
    this.command,
    this.migratesClaudeAdapter = false,
    this.catalogIdentity,
    this.replacementAcpCommand,
  });

  bool get canUpdate =>
      status == AgentUpdateStatus.available && command != null;

  Map<String, dynamic> toJson() => {
    'component': component.name,
    'status': status.name,
    'installedVersion': installedVersion,
    'latestVersion': latestVersion,
    'source': source,
    'reasonCode': reasonCode,
  };

  factory AgentComponentUpdate.fromJson(Map<String, dynamic> json) =>
      AgentComponentUpdate(
        component: AgentUpdateComponent.values.byName(
          json['component'] as String,
        ),
        status: AgentUpdateStatus.values.byName(json['status'] as String),
        installedVersion: json['installedVersion'] as String?,
        latestVersion: json['latestVersion'] as String?,
        source: json['source'] as String?,
        reasonCode: json['reasonCode'] as String?,
      );
}

class AgentUpdateReport {
  final String agentId;
  final String targetKey;
  final DateTime checkedAt;
  final List<AgentComponentUpdate> components;
  final String diagnosticLog;

  const AgentUpdateReport({
    required this.agentId,
    required this.targetKey,
    required this.checkedAt,
    required this.components,
    this.diagnosticLog = '',
  });

  bool get hasUpdates =>
      components.any((entry) => entry.status == AgentUpdateStatus.available);
  bool get hasErrors =>
      components.any((entry) => entry.status == AgentUpdateStatus.error);
}

/// An ephemeral, explicitly confirmed command plan. Never persisted or replayed.
class AgentUpdatePlan {
  final ServerProfile server;
  final AgentProfile profile;
  final String targetKey;
  final DateTime preparedAt;
  final String runtimeIdentity;
  final String? resolvedContainerId;
  final List<AgentComponentUpdate> components;

  const AgentUpdatePlan({
    required this.server,
    required this.profile,
    required this.targetKey,
    required this.preparedAt,
    required this.runtimeIdentity,
    this.resolvedContainerId,
    required this.components,
  });

  String get commandPreview =>
      components.map((item) => item.command).whereType<String>().join('\n');
}

class AgentUpdateException implements Exception {
  final String code;
  final String? detail;
  const AgentUpdateException(this.code, [this.detail]);
  @override
  String toString() => detail == null ? code : '$code: $detail';
}

/// Stable versions only: preview builds are never silently replaced/downgraded.
int? compareAgentVersions(String? left, String? right) {
  List<int>? parse(String? value) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:\+[A-Za-z0-9.-]+)?$',
    ).firstMatch(value ?? '');
    if (match == null) return null;
    return [for (var i = 1; i <= 3; i++) int.parse(match[i]!)];
  }

  final a = parse(left);
  final b = parse(right);
  if (a == null || b == null) return null;
  for (var i = 0; i < a.length; i++) {
    final comparison = a[i].compareTo(b[i]);
    if (comparison != 0) return comparison;
  }
  return 0;
}
