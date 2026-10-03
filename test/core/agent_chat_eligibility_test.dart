import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';

void main() {
  test(
    'official AGY ACP enters the switcher only when ready on this server',
    () {
      final profile = AgentProfile(
        id: 'builtin-agy',
        serverId: 'server',
        name: 'AGY',
        description: '',
        cliCommand: 'agy',
        acpCommand: 'agy_acp_server.par',
      );
      for (final kind in [
        AgentEnvironmentStatusKind.ready,
        AgentEnvironmentStatusKind.acpMissing,
      ]) {
        final registry = AgentRegistryState(
          serverId: 'server',
          agents: [
            AgentRuntimeState(
              profile: profile,
              status: AgentEnvironmentStatus(
                kind: kind,
                checkedAt: DateTime.utc(2026),
              ),
            ),
          ],
        );
        expect(
          registry.readyAgents,
          kind == AgentEnvironmentStatusKind.ready ? [profile] : isEmpty,
        );
        expect(registry.copyWith(serverId: 'other').readyAgents, isEmpty);
      }
    },
  );

  test('CLI-only agents do not enter ACP chat switcher', () {
    final profile = AgentProfile(
      id: 'agy',
      serverId: 'server',
      name: 'AGY',
      description: '',
      cliCommand: 'agy',
      acpCommand: null,
    );
    final registry = AgentRegistryState(
      serverId: 'server',
      agents: [
        AgentRuntimeState(
          profile: profile,
          status: AgentEnvironmentStatus(
            kind: AgentEnvironmentStatusKind.ready,
            checkedAt: DateTime.utc(2026),
          ),
        ),
      ],
    );
    expect(registry.readyAgents, isEmpty);
  });
}
