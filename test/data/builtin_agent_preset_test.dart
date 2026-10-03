import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/security/agent_command_validator.dart';
import 'package:valhalla/data/models/builtin_agent_preset.dart';
import 'package:valhalla/data/models/chat_session.dart';

void main() {
  group('kBuiltinAgentPresets', () {
    test('covers every builtin agent id referenced by the legacy map', () {
      const expectedIds = {
        'builtin-claude-code',
        'builtin-codex',
        'builtin-opencode',
        'builtin-agy',
      };

      expect(kBuiltinAgentPresets.keys.toSet(), expectedIds);
      expect(kLegacyAgentTypeToId.values.toSet(), expectedIds);
    });

    test('every preset declares its own id as the map key', () {
      kBuiltinAgentPresets.forEach((key, preset) {
        expect(
          preset.id,
          key,
          reason: 'preset under key $key has id ${preset.id}',
        );
      });
    });

    test('every preset has a non-empty name and cli command', () {
      for (final preset in kBuiltinAgentPresets.values) {
        expect(preset.name.trim(), isNotEmpty, reason: preset.id);
        expect(preset.cliCommand.trim(), isNotEmpty, reason: preset.id);
      }
    });

    test('no preset uses the non-existent --stdio ACP flag', () {
      for (final preset in kBuiltinAgentPresets.values) {
        expect(
          preset.acpCommand ?? '',
          isNot(contains('--stdio')),
          reason:
              '${preset.id}: ACP adapters take no arguments; --stdio is bogus',
        );
      }
    });

    test('opencode uses the "acp" subcommand, not the --acp flag', () {
      expect(
        kBuiltinAgentPresets['builtin-opencode']!.acpCommand,
        'opencode acp',
      );
    });

    test('agy uses the separate official ACP server', () {
      final agy = kBuiltinAgentPresets['builtin-agy']!;
      expect(agy.acpCommand, 'agy_acp_server.par');
      expect(agy.acpInstallCommand, kAntigravityAcpInstallCommand);
      expect(agy.cliCommand, 'agy');
      expect(agy.loginCommand, 'agy');
    });

    test('no preset invents an --acp flag', () {
      for (final preset in kBuiltinAgentPresets.values) {
        expect(
          preset.acpCommand ?? '',
          isNot(contains('--acp')),
          reason: preset.id,
        );
      }
    });

    test('every install/login command passes the command validator', () {
      for (final preset in kBuiltinAgentPresets.values) {
        final commands = <String?>[
          preset.cliInstallCommand,
          preset.acpInstallCommand,
          preset.loginCheckCommand,
          preset.loginCommand,
        ];
        for (final command in commands) {
          if (command == null) continue;
          expect(
            () => AgentCommandValidator.validate(command),
            returnsNormally,
            reason: '${preset.id} has an unsafe command: $command',
          );
        }
      }
    });

    test(
      'agents whose acp ships with the cli leave acpInstallCommand null',
      () {
        expect(
          kBuiltinAgentPresets['builtin-opencode']!.acpInstallCommand,
          isNull,
        );
      },
    );

    test(
      'agents with a separate acp package declare an acp install command',
      () {
        expect(
          kBuiltinAgentPresets['builtin-claude-code']!.acpInstallCommand,
          'npm install -g @zed-industries/claude-code-acp',
        );
        expect(
          kBuiltinAgentPresets['builtin-codex']!.acpInstallCommand,
          'npm install -g @agentclientprotocol/codex-acp',
        );
      },
    );

    test('no preset relies on the unverified bare codex-acp package name', () {
      for (final preset in kBuiltinAgentPresets.values) {
        expect(
          preset.cliInstallCommand ?? '',
          isNot(contains('install -g codex-acp')),
          reason: preset.id,
        );
        expect(
          preset.acpInstallCommand ?? '',
          isNot(contains('install -g codex-acp')),
          reason: preset.id,
        );
        expect(
          preset.cliInstallCommand ?? '',
          isNot(contains('antigravity.dev')),
          reason: preset.id,
        );
      }
    });
  });
}
