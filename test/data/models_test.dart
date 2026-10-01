import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/models/host_key_entry.dart';
import 'package:valhalla/data/models/quick_command.dart';
import 'package:valhalla/data/models/chat_session.dart';

void main() {
  group('Domain Models Tests', () {
    test('ServerProfile JSON roundtrip', () {
      final server = ServerProfile(
        id: 'srv-1',
        name: 'prod-srv',
        host: '10.0.0.1',
        port: 2222,
        username: 'ubuntu',
        authType: AuthType.privateKey,
        tags: const ['Prod', 'K8s'],
        lastConnectedAt: DateTime(2026, 9, 13, 20, 0),
      );

      final json = server.toJson();
      final parsed = ServerProfile.fromJson(json);

      expect(parsed.id, equals('srv-1'));
      expect(parsed.name, equals('prod-srv'));
      expect(parsed.host, equals('10.0.0.1'));
      expect(parsed.port, equals(2222));
      expect(parsed.username, equals('ubuntu'));
      expect(parsed.authType, equals(AuthType.privateKey));
      expect(parsed.tags, equals(['Prod', 'K8s']));
    });

    test('HostKeyEntry JSON roundtrip', () {
      final entry = HostKeyEntry(
        hostPort: '192.168.1.1:22',
        keyType: 'ssh-ed25519',
        fingerprintSha256: 'SHA256:abc123xyz',
        trustedAt: DateTime(2026, 9, 13),
      );

      final json = entry.toJson();
      final parsed = HostKeyEntry.fromJson(json);

      expect(parsed.hostPort, equals('192.168.1.1:22'));
      expect(parsed.keyType, equals('ssh-ed25519'));
      expect(parsed.fingerprintSha256, equals('SHA256:abc123xyz'));
    });

    test('QuickCommand extractParams and applyParams', () {
      const cmd = QuickCommand(
        id: 'cmd-1',
        title: 'Inspect Container',
        command: 'docker inspect {{container_id}} -n {{namespace}}',
        category: 'Docker',
        description: 'Inspect metadata',
      );

      final params = cmd.extractParams();
      expect(params, equals(['container_id', 'namespace']));

      final replaced = cmd.applyParams({
        'container_id': '4a1b2c3d',
        'namespace': 'production',
      });
      expect(replaced, equals('docker inspect 4a1b2c3d -n production'));
    });

    test('ChatSession and ChatMessage JSON roundtrip', () {
      final session = ChatSession(
        id: 'sess-1',
        title: 'OOM Troubleshoot',
        agentType: AgentType.claudeCode,
        createdAt: DateTime(2026, 9, 13, 18, 0),
        updatedAt: DateTime(2026, 9, 13, 19, 0),
        messages: [
          ChatMessage(
            id: 'm1',
            role: MessageRole.user,
            content: 'Hello Agent',
            createdAt: DateTime(2026, 9, 13, 18, 1),
          ),
          ChatMessage(
            id: 'm2',
            role: MessageRole.assistant,
            content: 'I analyzed the issue.',
            thinking: 'Step 1 analysis',
            planSteps: const [
              PlanStep(
                id: 'p1',
                title: 'Check RAM',
                status: PlanStepStatus.completed,
              ),
            ],
            toolExecutions: const [
              ToolExecution(
                id: 't1',
                name: 'bash',
                command: 'free -m',
                status: ToolExecutionStatus.completed,
                output: 'total 7912',
              ),
            ],
            createdAt: DateTime(2026, 9, 13, 18, 2),
          ),
        ],
      );

      final json = session.toJson();
      final parsed = ChatSession.fromJson(json);

      expect(parsed.id, equals('sess-1'));
      expect(parsed.messages.length, equals(2));
      expect(parsed.messages[1].thinking, equals('Step 1 analysis'));
      expect(parsed.messages[1].planSteps.first.title, equals('Check RAM'));
      expect(
        parsed.messages[1].toolExecutions.first.output,
        equals('total 7912'),
      );
    });

    test('ChatSession persists the stable agentId', () {
      final session = ChatSession(
        id: 'sess-1',
        title: 'Stable id',
        agentId: 'builtin-codex',
        createdAt: DateTime(2026, 9, 13, 18, 0),
        updatedAt: DateTime(2026, 9, 13, 18, 0),
      );

      final json = session.toJson();
      expect(json['agentId'], equals('builtin-codex'));

      final parsed = ChatSession.fromJson(json);
      expect(parsed.agentId, equals('builtin-codex'));
    });

    test('legacy ChatSession without agentId migrates via the single table', () {
      final parsed = ChatSession.fromJson({
        'id': 'legacy-1',
        'title': 'legacy',
        'agentType': 'OpenAI Codex',
        'createdAt': '2026-09-13T18:00:00.000',
        'updatedAt': '2026-09-13T18:00:00.000',
        'messages': <dynamic>[],
      });

      expect(parsed.agentId, equals('builtin-codex'));
      // Legacy field stays readable during migration, but is never written back.
      expect(parsed.agentType, equals(AgentType.codex));
      expect(parsed.toJson().containsKey('agentType'), isFalse);
    });

    test('unknown legacy agentType does not invent an agentId', () {
      final parsed = ChatSession.fromJson({
        'id': 'legacy-2',
        'title': 'legacy',
        'agentType': 'something-unknown',
        'createdAt': '2026-09-13T18:00:00.000',
        'updatedAt': '2026-09-13T18:00:00.000',
        'messages': <dynamic>[],
      });

      expect(parsed.agentId, isNull);
      expect(parsed.agentType, equals(AgentType.claudeCode));
    });

    test('kLegacyAgentTypeToId is the single migration source of truth', () {
      expect(kLegacyAgentTypeToId['claudecode'], 'builtin-claude-code');
      expect(kLegacyAgentTypeToId['claude codex'], 'builtin-claude-code');
      expect(kLegacyAgentTypeToId['codex'], 'builtin-codex');
      expect(kLegacyAgentTypeToId['openai codex'], 'builtin-codex');
      expect(kLegacyAgentTypeToId['opencode'], 'builtin-opencode');
      expect(kLegacyAgentTypeToId['opencode acp'], 'builtin-opencode');
      expect(kLegacyAgentTypeToId['agy'], 'builtin-agy');
      expect(kLegacyAgentTypeToId['antigravity'], 'builtin-agy');
      expect(kLegacyAgentTypeToId['nope'], isNull);
    });
  });

  group('AgentProfile', () {
    AgentProfile buildProfile({String? acpInstallCommand}) => AgentProfile(
      id: 'builtin-codex',
      serverId: 'srv-1',
      name: 'OpenAI Codex',
      description: 'OpenAI ACP Agent',
      cliCommand: 'codex',
      acpCommand: 'codex-acp --stdio',
      installCommand: 'npm install -g @openai/codex',
      acpInstallCommand: acpInstallCommand,
      loginCheckCommand: 'codex --version',
      loginCommand: 'codex login',
    );

    test('round-trips acpInstallCommand through JSON', () {
      final profile = buildProfile(
        acpInstallCommand: 'npm install -g @zed-industries/codex-acp',
      );

      final restored = AgentProfile.fromJson(profile.toJson());

      expect(restored, equals(profile));
      expect(
        restored.acpInstallCommand,
        equals('npm install -g @zed-industries/codex-acp'),
      );
    });

    test('reads legacy JSON without acpInstallCommand as null', () {
      final json = buildProfile().toJson()..remove('acpInstallCommand');

      final restored = AgentProfile.fromJson(json);

      expect(restored.acpInstallCommand, isNull);
      expect(restored.containerUser, isNull);
    });

    test('round-trips optional Docker execution user', () {
      final profile = buildProfile().copyWith(
        executionTarget: 'docker',
        containerBinding: 'id',
        containerReference: 'workspace',
        containerUser: 'dev:1000',
      );

      final restored = AgentProfile.fromJson(profile.toJson());

      expect(restored.containerUser, 'dev:1000');
      expect(restored, profile);
    });

    test('copyWith preserves acpInstallCommand when omitted', () {
      final profile = buildProfile(
        acpInstallCommand: 'npm install -g @zed-industries/codex-acp',
      );

      final renamed = profile.copyWith(name: 'Renamed');

      expect(
        renamed.acpInstallCommand,
        equals('npm install -g @zed-industries/codex-acp'),
      );
    });

    test('differs when acpInstallCommand differs', () {
      expect(
        buildProfile(acpInstallCommand: 'a'),
        isNot(equals(buildProfile(acpInstallCommand: 'b'))),
      );
    });

    test('defaults containerBinding to name', () {
      expect(buildProfile().containerBinding, equals('name'));
    });

    test('missing containerBinding in JSON falls back to id', () {
      final json = buildProfile().toJson()..remove('containerBinding');

      final restored = AgentProfile.fromJson(json);

      expect(restored.containerBinding, equals('id'));
    });
  });
}
