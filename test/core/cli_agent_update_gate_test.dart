import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/agent_update_lock_provider.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_run_settings.dart';

final _profile = AgentProfile(
  id: 'codex-alias',
  serverId: 'server-1',
  name: 'Codex',
  description: '',
  cliCommand: 'codex',
);

class _SeededCli extends CliChatNotifier {
  @override
  CliChatState build() => CliChatState(
    serverId: _profile.serverId,
    activeAgent: _profile,
    draftCwd: '/workspace',
    canDelete: true,
    sessions: const [NativeCliSession(id: 'existing', title: 'Existing')],
    messages: const [
      NativeCliMessage(id: 'm1', role: 'assistant', text: 'Keep this'),
    ],
    runSettings: const ChatRunSettings(modelId: 'existing-model'),
  );
}

void main() {
  final operations = <String, Future<void> Function(CliChatNotifier)>{
    'send': (notifier) => notifier.sendMessage('must not send'),
    'model settings': (notifier) =>
        notifier.updateRunSettings(const ChatRunSettings(modelId: 'new-model')),
    'interactive terminal': (notifier) => notifier.openTerminal(),
    'SDK install': (notifier) => notifier.installHistorySdk(confirmed: true),
    'delete history': (notifier) =>
        notifier.deleteSession('existing', confirmed: true),
  };
  for (final operation in operations.entries) {
    test(
      'server update lease blocks CLI ${operation.key} without losing cached data',
      () async {
        final container = ProviderContainer(
          overrides: [cliChatProvider.overrideWith(_SeededCli.new)],
        );
        addTearDown(container.dispose);
        final notifier = container.read(cliChatProvider.notifier);
        final before = container.read(cliChatProvider);
        // A different Agent ID on this server may share the same installation.
        final locks = container.read(agentUpdateLockProvider.notifier);
        final alias = AgentProfile.fromJson({
          ..._profile.toJson(),
          'id': 'another-agent',
        });
        expect(locks.acquire(alias), isTrue);
        await operation.value(notifier);
        final after = container.read(cliChatProvider);
        expect(after.errorCode, 'AGENT_UPDATE_IN_PROGRESS');
        expect(after.messages, same(before.messages));
        expect(after.sessions, same(before.sessions));
        expect(after.runSettings.modelId, 'existing-model');
        expect(after.draftCwd, '/workspace');
        expect(after.isSending, isFalse);
        expect(after.terminal, isNull);
        expect(notifier.activeConnectionCount, 0);
      },
    );
  }
}
