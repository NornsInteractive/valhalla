import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/commands_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_composer_item.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_launch_preference.dart';
import 'package:valhalla/data/models/chat_run_settings.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/features/chat/cli_chat_view.dart';
import 'package:valhalla/features/chat/widgets/chat_run_settings_strip.dart';
import 'package:valhalla/features/nas/widgets/nas_library_settings_dialog.dart';
import 'package:valhalla/features/shell/main_shell.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class _FakeAiChatNotifier extends AiChatNotifier {
  final AiChatState _initialState;
  ChatLaunchPreference? savedLaunchPreference;
  String? savedDefaultAgentId;

  _FakeAiChatNotifier(this._initialState);

  @override
  AiChatState build() => _initialState;

  @override
  Future<void> setLaunchPreference(ChatLaunchPreference preference) async {
    savedLaunchPreference = preference;
  }

  @override
  Future<void> setDefaultAgent(String? agentId) async {
    savedDefaultAgentId = agentId;
  }
}

class _FakeCliChatNotifier extends CliChatNotifier {
  final CliChatState _initialState;
  ChatLaunchPreference? savedLaunchPreference;
  String? savedDefaultAgentId;
  bool refreshComposerCatalogCalled = false;

  _FakeCliChatNotifier(this._initialState);

  @override
  CliChatState build() => _initialState;

  @override
  Future<void> setLaunchPreference(ChatLaunchPreference preference) async {
    savedLaunchPreference = preference;
  }

  @override
  Future<void> setDefaultAgent(String? agentId) async {
    savedDefaultAgentId = agentId;
  }

  @override
  Future<void> refreshComposerCatalog() async {
    refreshComposerCatalogCalled = true;
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

class _TestServerListNotifier extends ServerListNotifier {
  final List<ServerProfile> _servers;
  _TestServerListNotifier(this._servers);

  @override
  List<ServerProfile> build() => _servers;
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

Widget _wrapWithApp(Widget child, List<dynamic> overrides) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  final testServer = ServerProfile(
    id: 'srv-test',
    name: 'Test Server',
    host: '127.0.0.1',
    port: 22,
    username: 'dev',
    authType: AuthType.password,
  );

  final testAgent = AgentProfile(
    id: 'agent-1',
    serverId: 'srv-test',
    name: 'Codex Agent',
    description: 'Test agent',
    cliCommand: 'codex',
    acpCommand: 'codex-acp',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MainShell Page Title Ownership Tests', () {
    testWidgets('mobile shell renders section title next to menu button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final local = await LocalStorageService.init();

      await tester.pumpWidget(
        _wrapWithApp(const MainShell(), [
          localStorageServiceProvider.overrideWithValue(local),
          activeServerProvider.overrideWith(
            () => _TestActiveServerNotifier(testServer),
          ),
          serverListProvider.overrideWith(
            () => _TestServerListNotifier([testServer]),
          ),
          serverConnectionProvider.overrideWith(
            _TestServerConnectionNotifier.new,
          ),
          agentRegistryProvider.overrideWith(
            () => _TestAgentRegistryNotifier([testAgent]),
          ),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Mobile shell shows section title in its own AppBar
      expect(find.text('AI Ops'), findsWidgets);
    });

    testWidgets('desktop shell renders section title at top-left', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final local = await LocalStorageService.init();

      await tester.pumpWidget(
        _wrapWithApp(const MainShell(), [
          localStorageServiceProvider.overrideWithValue(local),
          activeServerProvider.overrideWith(
            () => _TestActiveServerNotifier(testServer),
          ),
          serverListProvider.overrideWith(
            () => _TestServerListNotifier([testServer]),
          ),
          serverConnectionProvider.overrideWith(
            _TestServerConnectionNotifier.new,
          ),
          agentRegistryProvider.overrideWith(
            () => _TestAgentRegistryNotifier([testAgent]),
          ),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Top bar contains section title on desktop
      expect(find.text('AI Ops'), findsWidgets);
    });
  });

  group('ChatRunSettingsStrip Widget Tests', () {
    testWidgets('renders model, reasoning, and permission chips', (
      tester,
    ) async {
      bool opened = false;
      await tester.pumpWidget(
        _wrapWithApp(
          ChatRunSettingsStrip(
            settings: const ChatRunSettings(
              modelId: 'gpt-4o',
              reasoningId: 'high',
              permissionPolicy: OperationPermissionPolicy.autoAllowSafe,
            ),
            capabilities: const AgentRuntimeCapabilities(
              models: [ChatSettingOption('gpt-4o', 'GPT-4o')],
              reasoningLevels: [ChatSettingOption('high', 'High Reasoning')],
            ),
            isBusy: false,
            onOpenSettings: () => opened = true,
          ),
          [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chat_run_settings_strip')), findsOneWidget);
      expect(find.byKey(const Key('chat_strip_model_chip')), findsOneWidget);
      expect(
        find.byKey(const Key('chat_strip_reasoning_chip')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_strip_permission_chip')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('chat_strip_model_chip')));
      await tester.pump();
      expect(opened, isTrue);
    });
  });

  group('Chat Drawer Launch Preference & Default Session Tests', () {
    testWidgets(
      'AiChatView drawer displays launch mode selector and pins default session',
      (tester) async {
        final local = await LocalStorageService.init();
        // Configure initial fixed preference
        await local.saveChatLaunchPreference(
          testServer.id,
          testAgent.id,
          const ChatLaunchPreference(
            mode: ChatLaunchMode.fixed,
            sessionId: 'session-1',
          ),
          cli: false,
        );

        final notifier = _FakeAiChatNotifier(
          AiChatState(
            activeAgentProfile: testAgent,
            activeSessionId: 'session-1',
            sessions: [
              ChatSession(
                id: 'session-1',
                title: 'Fixed Default Session',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
              ChatSession(
                id: 'session-2',
                title: 'Other Session',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ],
          ),
        );

        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(const AiChatView(), [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _TestActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              _TestServerConnectionNotifier.new,
            ),
            agentRegistryProvider.overrideWith(
              () => _TestAgentRegistryNotifier([testAgent]),
            ),
            aiChatProvider.overrideWith(() => notifier),
          ]),
        );
        await tester.pumpAndSettle();

        // Launch mode dropdown is present
        expect(
          find.byKey(const Key('ai_chat_launch_mode_selector')),
          findsOneWidget,
        );

        // Default session badge (pin icon) is present for session-1
        expect(
          find.byKey(const Key('default_session_badge_session-1')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CliChatView sidebar displays launch mode selector and default session badge',
      (tester) async {
        final local = await LocalStorageService.init();
        await local.saveChatLaunchPreference(
          testServer.id,
          testAgent.id,
          const ChatLaunchPreference(
            mode: ChatLaunchMode.fixed,
            sessionId: 'cli-sess-1',
          ),
          cli: true,
        );

        final notifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: testServer.id,
            agents: [testAgent],
            activeAgent: testAgent,
            sessions: const [
              NativeCliSession(id: 'cli-sess-1', title: 'CLI Session 1'),
              NativeCliSession(id: 'cli-sess-2', title: 'CLI Session 2'),
            ],
          ),
        );

        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(const CliChatView(), [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _TestActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              _TestServerConnectionNotifier.new,
            ),
            agentRegistryProvider.overrideWith(
              () => _TestAgentRegistryNotifier([testAgent]),
            ),
            cliChatProvider.overrideWith(() => notifier),
          ]),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('cli_chat_launch_mode_selector')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('cli_default_session_badge_cli-sess-1')),
          findsOneWidget,
        );
      },
    );
  });

  group('CLI Composer Left Actions Menu Tests', () {
    testWidgets(
      'actions menu renders options, skills is disabled, and workdir inserts without sending',
      (tester) async {
        final local = await LocalStorageService.init();

        final notifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: testServer.id,
            agents: [testAgent],
            activeAgent: testAgent,
            draftCwd: '/var/www/project',
            sessions: const [
              NativeCliSession(id: 'cli-sess-1', title: 'Session 1'),
            ],
          ),
        );

        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(const CliChatView(), [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _TestActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              _TestServerConnectionNotifier.new,
            ),
            agentRegistryProvider.overrideWith(
              () => _TestAgentRegistryNotifier([testAgent]),
            ),
            cliChatProvider.overrideWith(() => notifier),
            commandsProvider.overrideWith(() => CommandsNotifier()),
          ]),
        );
        await tester.pumpAndSettle();

        final menuBtn = find.byKey(
          const Key('cli_composer_actions_menu_button'),
        );
        expect(menuBtn, findsOneWidget);

        await tester.tap(menuBtn);
        await tester.pumpAndSettle();

        // Check popup items
        expect(
          find.byKey(const Key('cli_composer_action_commands')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('cli_composer_action_files')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('cli_composer_action_workdir')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('cli_composer_action_skills')),
          findsOneWidget,
        );

        // Skills option is disabled
        final skillsItem = tester.widget<PopupMenuItem>(
          find.byKey(const Key('cli_composer_action_skills')),
        );
        expect(skillsItem.enabled, isFalse);

        // Tap workdir action
        await tester.tap(find.byKey(const Key('cli_composer_action_workdir')));
        await tester.pumpAndSettle();

        // Input field draft now has the working directory text inserted
        final input = tester.widget<TextField>(
          find.byKey(const Key('cli_chat_input_field')),
        );
        expect(input.controller?.text, '/var/www/project');
      },
    );

    testWidgets(
      'CLI composer enables skills menu when skills are nonempty and inserts into draft',
      (tester) async {
        final local = await LocalStorageService.init();

        final notifier = _FakeCliChatNotifier(
          CliChatState(
            serverId: 'srv-1',
            activeAgent: testAgent,
            agents: [testAgent],
            activeSession: const NativeCliSession(
              id: 'sess-1',
              title: 'Active Session',
              cwd: '/var/www/project',
            ),
            composerCatalog: const AgentComposerCatalog(
              skills: [
                AgentComposerItem(
                  kind: AgentComposerItemKind.skill,
                  id: 'skill-git-status',
                  label: 'Git Status Skill',
                  insertion: '/git-status',
                  description: 'Inspect workspace git state',
                ),
              ],
            ),
          ),
        );

        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapWithApp(const CliChatView(), [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _TestActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              _TestServerConnectionNotifier.new,
            ),
            agentRegistryProvider.overrideWith(
              () => _TestAgentRegistryNotifier([testAgent]),
            ),
            cliChatProvider.overrideWith(() => notifier),
            commandsProvider.overrideWith(() => CommandsNotifier()),
          ]),
        );
        await tester.pumpAndSettle();

        // Tap '+' insert menu button
        await tester.tap(
          find.byKey(const Key('cli_composer_actions_menu_button')),
        );
        await tester.pumpAndSettle();

        // Verify refreshComposerCatalog was called on opening
        expect(notifier.refreshComposerCatalogCalled, isTrue);

        // Skills option is enabled
        final skillsItem = tester.widget<PopupMenuItem>(
          find.byKey(const Key('cli_composer_action_skills')),
        );
        expect(skillsItem.enabled, isTrue);

        // Tap skills action
        await tester.tap(find.byKey(const Key('cli_composer_action_skills')));
        await tester.pumpAndSettle();

        // Skills dialog appears
        expect(
          find.byKey(const Key('cli_insert_skills_dialog')),
          findsOneWidget,
        );
        expect(find.text('Git Status Skill'), findsOneWidget);

        // Tap skill item
        await tester.tap(
          find.byKey(const Key('cli_insert_skill_skill-git-status')),
        );
        await tester.pumpAndSettle();

        // Input field draft has insertion without sending
        final input = tester.widget<TextField>(
          find.byKey(const Key('cli_chat_input_field')),
        );
        expect(input.controller?.text, '/git-status');
      },
    );
  });

  group('NAS Library Settings & Media View Surfaces Tests', () {
    testWidgets('library settings dialog allows selecting opening policy', (
      tester,
    ) async {
      NasOpenPolicy? selectedPolicy;

      await tester.pumpWidget(
        _wrapWithApp(
          Builder(
            builder: (ctx) => FilledButton(
              onPressed: () => NasLibrarySettingsDialog.show(
                ctx,
                currentPolicy: NasOpenPolicy.inApp,
                onPolicyChanged: (val) => selectedPolicy = val,
                scanConfig: const NasScanConfig(includePaths: ['/media']),
                onSaveScanConfig: (_) {},
                isScanning: false,
                onScan: () {},
                onCancelScan: () {},
              ),
              child: const Text('Open Settings'),
            ),
          ),
          [],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('nas_library_settings_dialog')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('nas_policy_in_app')), findsOneWidget);
      expect(find.byKey(const Key('nas_policy_external')), findsOneWidget);
      expect(find.byKey(const Key('nas_policy_ask')), findsOneWidget);

      await tester.tap(find.byKey(const Key('nas_policy_external')));
      await tester.pumpAndSettle();

      expect(selectedPolicy, NasOpenPolicy.external);
    });

    testWidgets(
      'library settings dialog allows selecting policy per media kind',
      (tester) async {
        NasMediaKind? changedKind;
        NasOpenPolicy? changedPolicy;

        await tester.pumpWidget(
          _wrapWithApp(
            Builder(
              builder: (ctx) => FilledButton(
                onPressed: () => NasLibrarySettingsDialog.show(
                  ctx,
                  currentPolicy: NasOpenPolicy.inApp,
                  onPolicyChanged: (_) {},
                  kindPolicies: const {
                    NasMediaKind.video: NasOpenPolicy.inApp,
                    NasMediaKind.audio: NasOpenPolicy.inApp,
                    NasMediaKind.image: NasOpenPolicy.external,
                  },
                  onKindPolicyChanged: (kind, policy) {
                    changedKind = kind;
                    changedPolicy = policy;
                  },
                  scanConfig: const NasScanConfig(includePaths: ['/media']),
                  onSaveScanConfig: (_) {},
                  isScanning: false,
                  onScan: () {},
                  onCancelScan: () {},
                ),
                child: const Text('Open Settings'),
              ),
            ),
            [],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('nas_kind_chip_video')), findsOneWidget);
        expect(find.byKey(const Key('nas_kind_chip_audio')), findsOneWidget);
        expect(find.byKey(const Key('nas_kind_chip_image')), findsOneWidget);

        // Switch to Audio and set to Always Ask
        await tester.tap(find.byKey(const Key('nas_kind_chip_audio')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('nas_policy_ask')));
        await tester.pumpAndSettle();

        expect(changedKind, NasMediaKind.audio);
        expect(changedPolicy, NasOpenPolicy.askEveryTime);
      },
    );
  });
}
