import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/features/chat/cli_chat_view.dart';
import 'package:valhalla/l10n/app_localizations.dart';

const _server = ServerProfile(
  id: 'srv-default-test',
  name: 'Default Test Server',
  host: '10.0.0.2',
  port: 22,
  username: 'root',
);

final _agent1 = AgentProfile(
  id: 'agent-1',
  serverId: 'srv-default-test',
  name: 'Codex Assistant',
  description: 'Codex CLI Agent',
  cliCommand: 'codex',
);

final _agent2 = AgentProfile(
  id: 'agent-2',
  serverId: 'srv-default-test',
  name: 'Claude Assistant',
  description: 'Claude CLI Agent',
  cliCommand: 'claude',
);

class _FakeActiveServerNotifier extends ActiveServerNotifier {
  @override
  ServerProfile? build() => _server;
}

class _FakeConnectionNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: 'srv-default-test',
  );
}

class _FakeCliChatNotifier extends CliChatNotifier {
  final CliChatState _initial;
  final LocalStorageService _storage;
  String? capturedDefaultAgentId;
  int setDefaultAgentCalls = 0;

  _FakeCliChatNotifier(this._initial, this._storage);

  @override
  CliChatState build() => _initial;

  @override
  Future<void> setDefaultAgent(String? agentId) async {
    capturedDefaultAgentId = agentId;
    setDefaultAgentCalls++;
    await _storage.setDefaultAgentId('srv-default-test', agentId, cli: true);
  }
}

class _FakeAiChatNotifier extends AiChatNotifier {
  final AiChatState _initial;
  String? capturedDefaultAgentId;
  int setDefaultAgentCalls = 0;

  _FakeAiChatNotifier(this._initial);

  @override
  AiChatState build() => _initial;

  @override
  Future<void> setDefaultAgent(String? agentId) async {
    capturedDefaultAgentId = agentId;
    setDefaultAgentCalls++;
  }
}

void main() {
  group('CLI Agent Selector - Set As Default', () {
    testWidgets(
      'toggles default agent without switching current active agent',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);

        final cliState = CliChatState(
          serverId: 'srv-default-test',
          agents: [_agent1, _agent2],
          activeAgent: _agent1,
        );
        final fakeCliNotifier = _FakeCliChatNotifier(cliState, storage);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerProvider.overrideWith(_FakeActiveServerNotifier.new),
              serverConnectionProvider.overrideWith(
                _FakeConnectionNotifier.new,
              ),
              localStorageServiceProvider.overrideWithValue(storage),
              cliChatProvider.overrideWith(() => fakeCliNotifier),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: CliChatView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Button should show outline star initially since no default is set
        final defaultBtn = find.byKey(
          const Key('cli_set_default_agent_button'),
        );
        expect(defaultBtn, findsOneWidget);

        final initialIcon = tester.widget<Icon>(
          find.descendant(of: defaultBtn, matching: find.byType(Icon)),
        );
        expect(initialIcon.icon, Icons.star_outline_rounded);

        // Tap default button to set agent-1 as default
        await tester.tap(defaultBtn);
        await tester.pumpAndSettle();

        // Verify setDefaultAgent was called with 'agent-1'
        expect(fakeCliNotifier.setDefaultAgentCalls, 1);
        expect(fakeCliNotifier.capturedDefaultAgentId, 'agent-1');

        // Verify star is now filled
        final filledIcon = tester.widget<Icon>(
          find.descendant(of: defaultBtn, matching: find.byType(Icon)),
        );
        expect(filledIcon.icon, Icons.star_rounded);

        // Tap again to clear default
        await tester.tap(defaultBtn);
        await tester.pumpAndSettle();

        expect(fakeCliNotifier.setDefaultAgentCalls, 2);
        expect(fakeCliNotifier.capturedDefaultAgentId, isNull);
      },
    );
  });

  group('ACP AI Chat Agent Switcher - Set As Default', () {
    testWidgets(
      'toggles default agent inside modal without closing modal or switching agent',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final storage = LocalStorageService(prefs);

        final aiState = AiChatState(
          readyAgents: [_agent1, _agent2],
          activeAgentProfile: _agent1,
        );
        final fakeAiNotifier = _FakeAiChatNotifier(aiState);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeServerProvider.overrideWith(_FakeActiveServerNotifier.new),
              serverConnectionProvider.overrideWith(
                _FakeConnectionNotifier.new,
              ),
              localStorageServiceProvider.overrideWithValue(storage),
              aiChatProvider.overrideWith(() => fakeAiNotifier),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: AiChatView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap header to open agent switcher modal
        final headerAgentName = find.text('Codex Assistant');
        expect(headerAgentName, findsWidgets);
        await tester.tap(headerAgentName.first);
        await tester.pumpAndSettle();

        // Modal should be open with buttons for both agents
        final defaultBtn1 = find.byKey(
          const Key('ai_set_default_agent_agent-1'),
        );
        final defaultBtn2 = find.byKey(
          const Key('ai_set_default_agent_agent-2'),
        );
        expect(defaultBtn1, findsOneWidget);
        expect(defaultBtn2, findsOneWidget);

        // Tap set default on agent-2
        await tester.tap(defaultBtn2);
        await tester.pumpAndSettle();

        // Verify setDefaultAgent was called with 'agent-2'
        expect(fakeAiNotifier.setDefaultAgentCalls, 1);
        expect(fakeAiNotifier.capturedDefaultAgentId, 'agent-2');

        // Modal should still be open
        expect(
          find.byKey(const Key('ai_set_default_agent_agent-2')),
          findsOneWidget,
        );

        // Close modal
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('ai_set_default_agent_agent-2')),
          findsNothing,
        );
      },
    );
  });
}
