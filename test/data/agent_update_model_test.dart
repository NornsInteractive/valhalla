import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/agent_update.dart';
import 'package:valhalla/data/models/server_profile.dart';

const _server = ServerProfile(
  id: 'server',
  name: 'Server',
  host: 'host.test',
  username: 'dev',
);

AgentProfile _profile() => AgentProfile(
  id: 'agent',
  serverId: 'server',
  name: 'Codex',
  description: '',
  cliCommand: 'codex',
  acpCommand: 'codex-acp',
  executionTarget: 'docker',
  containerBinding: 'name',
  containerReference: 'workspace',
  containerUser: 'dev',
  installCommand: 'npm install -g @openai/codex',
  acpInstallCommand: 'npm install -g @agentclientprotocol/codex-acp',
);

void main() {
  test(
    'stable comparison handles numeric ordering, prefix and build metadata',
    () {
      expect(compareAgentVersions('1.2.3', '1.2.3'), 0);
      expect(compareAgentVersions('1.10.0', '1.9.99'), greaterThan(0));
      expect(compareAgentVersions('1.2.3', '2.0.0'), lessThan(0));
      expect(compareAgentVersions('v1.2.3', '1.2.3+build.7'), 0);
      for (final invalid in <String?>[
        null,
        '',
        '1.2',
        '1.2.3-rc.1',
        'latest',
      ]) {
        expect(compareAgentVersions(invalid, '1.2.3'), isNull);
        expect(compareAgentVersions('1.2.3', invalid), isNull);
      }
    },
  );

  test(
    'target key changes for every execution identity or install command',
    () {
      final profile = _profile();
      final key = agentUpdateTargetKey(_server, profile);
      expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
      for (final server in [
        _server.copyWith(host: 'other.test'),
        _server.copyWith(username: 'other'),
        _server.copyWith(port: 2222),
      ]) {
        expect(agentUpdateTargetKey(server, profile), isNot(key));
      }
      for (final changed in [
        profile.copyWith(executionTarget: 'host'),
        profile.copyWith(containerBinding: 'id'),
        profile.copyWith(containerReference: 'replacement'),
        profile.copyWith(containerUser: 'root'),
        profile.copyWith(cliCommand: '/opt/codex'),
        profile.copyWith(acpCommand: '/opt/codex-acp'),
        profile.copyWith(installCommand: 'custom CLI install'),
        profile.copyWith(acpInstallCommand: 'custom ACP install'),
      ]) {
        expect(agentUpdateTargetKey(_server, changed), isNot(key));
      }
      expect(
        agentUpdateTargetKey(
          _server,
          AgentProfile.fromJson({...profile.toJson(), 'id': 'other-card'}),
        ),
        isNot(key),
      );
      expect(
        agentUpdateTargetKey(
          _server,
          profile.copyWith(
            name: 'Renamed',
            description: 'Changed',
            updatedAt: DateTime(2030),
          ),
        ),
        key,
      );
    },
  );

  test('persisted metadata cannot replay an executable plan', () {
    const component = AgentComponentUpdate(
      component: AgentUpdateComponent.acp,
      status: AgentUpdateStatus.available,
      installedVersion: '1.0.0',
      latestVersion: '2.0.0',
      source: 'official',
      reasonCode: 'reason',
      command: 'do-not-persist',
      migratesClaudeAdapter: true,
      catalogIdentity: 'ephemeral-source-fingerprint',
    );
    final json = component.toJson();
    expect(
      json.keys,
      unorderedEquals([
        'component',
        'status',
        'installedVersion',
        'latestVersion',
        'source',
        'reasonCode',
      ]),
    );
    final restored = AgentComponentUpdate.fromJson(json);
    expect(restored.component, AgentUpdateComponent.acp);
    expect(restored.status, AgentUpdateStatus.available);
    expect(restored.installedVersion, '1.0.0');
    expect(restored.latestVersion, '2.0.0');
    expect(restored.source, 'official');
    expect(restored.reasonCode, 'reason');
    expect(restored.command, isNull);
    expect(restored.catalogIdentity, isNull);
    expect(restored.migratesClaudeAdapter, isFalse);
    expect(restored.canUpdate, isFalse);
    expect(component.canUpdate, isTrue);
  });
}
