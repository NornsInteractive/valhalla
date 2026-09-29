import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_run_settings.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/features/chat/cli_chat_view.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _FakeAiChatNotifier extends AiChatNotifier {
  final AiChatState _initialState;
  ChatRunSettings? updatedSettings;

  _FakeAiChatNotifier(this._initialState);

  @override
  AiChatState build() => _initialState;

  @override
  Future<bool> prepareRunSettings() async => true;

  @override
  Future<void> updateRunSettings(ChatRunSettings settings) async {
    updatedSettings = settings;
    state = state.copyWith(runSettings: settings);
  }
}

class _FakeCliChatNotifier extends CliChatNotifier {
  final CliChatState _initialState;
  ChatRunSettings? updatedSettings;

  _FakeCliChatNotifier(this._initialState);

  @override
  CliChatState build() => _initialState;

  @override
  Future<void> updateRunSettings(ChatRunSettings settings) async {
    updatedSettings = settings;
    state = state.copyWith(runSettings: settings);
  }
}

class _TestServerConnectionNotifier extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.connected);
}

class _TestActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _server;
  _TestActiveServerNotifier(this._server);

  @override
  ServerProfile? build() => _server;
}

class _TestAgentRegistryNotifier extends AgentRegistryNotifier {
  final List<AgentProfile> _agents;
  _TestAgentRegistryNotifier(this._agents);

  @override
  AgentRegistryState build() {
    return AgentRegistryState(
      agents: _agents
          .map(
            (a) => AgentRuntimeState(
              profile: a,
              status: AgentEnvironmentStatus(
                kind: AgentEnvironmentStatusKind.ready,
                checkedAt: DateTime.utc(2026),
              ),
            ),
          )
          .toList(),
    );
  }
}

void main() {
  final testServer = ServerProfile(
    id: 'srv-1',
    name: 'Production Server',
    host: '192.168.1.1',
    port: 22,
    username: 'root',
    authType: AuthType.password,
  );

  final testAcpAgent = AgentProfile(
    id: 'agent-acp',
    serverId: 'srv-1',
    name: 'Claude Code ACP',
    description: 'ACP agent',
    cliCommand: 'claude',
    acpCommand: 'claude-acp',
  );

  final testCliCodexAgent = AgentProfile(
    id: 'agent-codex',
    serverId: 'srv-1',
    name: 'Codex CLI',
    description: 'Codex CLI agent',
    cliCommand: 'codex',
  );

  final testCliClaudeAgent = AgentProfile(
    id: 'agent-claude',
    serverId: 'srv-1',
    name: 'Claude Interactive CLI',
    description: 'Claude agent',
    cliCommand: 'claude',
  );

  Widget createChatApp({
    required Widget child,
    required List<dynamic> overrides,
    Locale locale = const Locale('zh'),
  }) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AiChatView Run Settings & Drawer Tests', () {
    testWidgets(
      'mobile uses Material Drawer and desktop session column has width 320',
      (tester) async {
        final local = await LocalStorageService.init();

        // 1. Mobile viewport (< 768)
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final aiNotifier = _FakeAiChatNotifier(
          AiChatState(
            sessions: [
              ChatSession(
                id: 's-1',
                title: 'Session 1',
                serverId: 'srv-1',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ],
            activeSessionId: 's-1',
            activeAgentProfile: testAcpAgent,
          ),
        );

        await tester.pumpWidget(
          createChatApp(
            child: const AiChatView(),
            overrides: [
              localStorageServiceProvider.overrideWithValue(local),
              activeServerProvider.overrideWith(
                () => _TestActiveServerNotifier(testServer),
              ),
              serverConnectionProvider.overrideWith(
                _TestServerConnectionNotifier.new,
              ),
              agentRegistryProvider.overrideWith(
                () => _TestAgentRegistryNotifier([testAcpAgent]),
              ),
              aiChatProvider.overrideWith(() => aiNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Open mobile drawer
        final drawerButton = find.byKey(
          const Key('ai_mobile_session_drawer_button'),
        );
        expect(drawerButton, findsOneWidget);
        await tester.tap(drawerButton);
        await tester.pumpAndSettle();

        // Drawer is Material Drawer widget
        expect(find.byType(Drawer), findsOneWidget);

        // Close drawer
        await tester.tap(find.text('Session 1'));
        await tester.pumpAndSettle();
        expect(find.byType(Drawer), findsNothing);

        // 2. Desktop viewport (>= 1024)
        tester.view.physicalSize = const Size(1280, 800);
        await tester.pumpAndSettle();

        // Desktop shows SizedBox with width 320 for sessions column
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final desktopSessionBar = sizedBoxes.where((box) => box.width == 320);
        expect(desktopSessionBar, isNotEmpty);
      },
    );

    testWidgets(
      'header has run settings button, opens modal, and updates settings',
      (tester) async {
        final local = await LocalStorageService.init();

        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final aiNotifier = _FakeAiChatNotifier(
          AiChatState(
            runSettings: const ChatRunSettings(
              modelId: 'gpt-4',
              permissionPolicy: OperationPermissionPolicy.askEveryTime,
            ),
            capabilities: const AgentRuntimeCapabilities(
              models: [
                ChatSettingOption('gpt-4', 'GPT-4'),
                ChatSettingOption('gpt-4o', 'GPT-4o'),
              ],
              reasoningLevels: [
                ChatSettingOption('low', 'Low'),
                ChatSettingOption('high', 'High'),
              ],
            ),
            activeAgentProfile: testAcpAgent,
          ),
        );

        await tester.pumpWidget(
          createChatApp(
            child: const AiChatView(),
            overrides: [
              localStorageServiceProvider.overrideWithValue(local),
              activeServerProvider.overrideWith(
                () => _TestActiveServerNotifier(testServer),
              ),
              serverConnectionProvider.overrideWith(
                _TestServerConnectionNotifier.new,
              ),
              agentRegistryProvider.overrideWith(
                () => _TestAgentRegistryNotifier([testAcpAgent]),
              ),
              aiChatProvider.overrideWith(() => aiNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final settingsBtn = find.byKey(const Key('chat_run_settings_button'));
        expect(settingsBtn, findsOneWidget);

        // Tap settings button to open modal
        await tester.tap(settingsBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('chat_run_settings_dialog')),
          findsOneWidget,
        );

        // Switch permission to autoAllowSafe
        final safeRadio = find.byKey(
          const Key('chat_permission_auto_allow_safe'),
        );
        expect(safeRadio, findsOneWidget);
        await tester.tap(safeRadio);
        await tester.pumpAndSettle();

        // Save
        final saveBtn = find.byKey(const Key('chat_run_settings_save_button'));
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(aiNotifier.updatedSettings, isNotNull);
        expect(
          aiNotifier.updatedSettings!.permissionPolicy,
          OperationPermissionPolicy.autoAllowSafe,
        );
      },
    );

    testWidgets('run settings button disabled during isGenerating', (
      tester,
    ) async {
      final local = await LocalStorageService.init();

      final aiNotifier = _FakeAiChatNotifier(
        AiChatState(isGenerating: true, activeAgentProfile: testAcpAgent),
      );

      await tester.pumpWidget(
        createChatApp(
          child: const AiChatView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _TestActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              _TestServerConnectionNotifier.new,
            ),
            agentRegistryProvider.overrideWith(
              () => _TestAgentRegistryNotifier([testAcpAgent]),
            ),
            aiChatProvider.overrideWith(() => aiNotifier),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final btn = tester.widget<IconButton>(
        find.byKey(const Key('chat_run_settings_button')),
      );
      expect(btn.onPressed, isNull);
    });
  });

  group('CliChatView Run Settings Tests', () {
    testWidgets(
      'CLI non-structuredSend shows managed by interactive CLI notice',
      (tester) async {
        final local = await LocalStorageService.init();

        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final cliNotifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            agents: [testCliClaudeAgent],
            activeAgent: testCliClaudeAgent,
          ),
        );

        await tester.pumpWidget(
          createChatApp(
            child: const CliChatView(),
            overrides: [
              localStorageServiceProvider.overrideWithValue(local),
              activeServerProvider.overrideWith(
                () => _TestActiveServerNotifier(testServer),
              ),
              serverConnectionProvider.overrideWith(
                _TestServerConnectionNotifier.new,
              ),
              agentRegistryProvider.overrideWith(
                () => _TestAgentRegistryNotifier([testCliClaudeAgent]),
              ),
              cliChatProvider.overrideWith(() => cliNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final settingsBtn = find.byKey(const Key('cli_run_settings_button'));
        expect(settingsBtn, findsOneWidget);
        await tester.tap(settingsBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('chat_run_settings_dialog')),
          findsOneWidget,
        );
        // Shows "由交互式 CLI 管理"
        expect(find.text('由交互式 CLI 管理'), findsNWidgets(2));
      },
    );

    testWidgets('CLI autoAllowAll triggers confirmation dialog before saving', (
      tester,
    ) async {
      final local = await LocalStorageService.init();

      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cliNotifier = _FakeCliChatNotifier(
        CliChatState(
          serverId: 'srv-1',
          agents: [testCliCodexAgent],
          activeAgent: testCliCodexAgent,
          runSettings: const ChatRunSettings(
            permissionPolicy: OperationPermissionPolicy.askEveryTime,
          ),
        ),
      );

      await tester.pumpWidget(
        createChatApp(
          child: const CliChatView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _TestActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              _TestServerConnectionNotifier.new,
            ),
            agentRegistryProvider.overrideWith(
              () => _TestAgentRegistryNotifier([testCliCodexAgent]),
            ),
            cliChatProvider.overrideWith(() => cliNotifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cli_run_settings_button')));
      await tester.pumpAndSettle();

      // Tap auto-allow all
      await tester.tap(find.byKey(const Key('chat_permission_auto_allow_all')));
      await tester.pumpAndSettle();

      // Secondary confirmation dialog appears
      expect(find.text('确认自动允许全部操作？'), findsOneWidget);

      // Cancel confirmation
      final confirmCancel = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('取消'),
      );
      await tester.tap(confirmCancel);
      await tester.pumpAndSettle();

      // Confirmation dialog closed, policy still askEveryTime
      // Tap auto-allow all again and confirm
      await tester.tap(find.byKey(const Key('chat_permission_auto_allow_all')));
      await tester.pumpAndSettle();

      final confirmBtn = find.byKey(
        const Key('chat_permission_auto_allow_all_confirm_button'),
      );
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.byKey(const Key('chat_run_settings_save_button')));
      await tester.pumpAndSettle();

      expect(cliNotifier.updatedSettings, isNotNull);
      expect(
        cliNotifier.updatedSettings!.permissionPolicy,
        OperationPermissionPolicy.autoAllowAll,
      );
    });

    testWidgets('CLI run settings button disabled during isSending', (
      tester,
    ) async {
      final local = await LocalStorageService.init();

      final cliNotifier = _FakeCliChatNotifier(
        CliChatState(
          serverId: 'srv-1',
          agents: [testCliCodexAgent],
          activeAgent: testCliCodexAgent,
          isSending: true,
        ),
      );

      await tester.pumpWidget(
        createChatApp(
          child: const CliChatView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _TestActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              _TestServerConnectionNotifier.new,
            ),
            agentRegistryProvider.overrideWith(
              () => _TestAgentRegistryNotifier([testCliCodexAgent]),
            ),
            cliChatProvider.overrideWith(() => cliNotifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final btn = tester.widget<IconButton>(
        find.byKey(const Key('cli_run_settings_button')),
      );
      expect(btn.onPressed, isNull);
    });
  });
}
