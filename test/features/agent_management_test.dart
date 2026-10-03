import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/builtin_agent_preset.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/features/agents/agent_command_confirm_dialog.dart';
import 'package:valhalla/features/agents/agent_form_dialog.dart';
import 'package:valhalla/features/agents/agent_management_view.dart';
import 'package:valhalla/features/agents/interactive_login_provider.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/cli/agent_execution_target.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import '../support/temp_chat_db.dart';

void main() {
  final testServer = ServerProfile(
    id: 'srv-test-1',
    name: 'Production US',
    host: '192.168.1.100',
    port: 22,
    username: 'admin',
    authType: AuthType.password,
  );

  Widget createTestApp({
    required Widget child,
    List<dynamic> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [tempChatRepositoryOverride(), ...overrides],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  testWidgets(
    'AgentManagementView renders empty state when no server selected',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(null),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.dns_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'AgentManagementView renders empty state when server has no agents',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Production US (192.168.1.100:22)'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsWidgets);
      expect(find.text('Add Agent'), findsWidgets);
    },
  );

  testWidgets(
    'AgentManagementView displays agent cards with status and commands',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'builtin-codex',
        serverId: 'srv-test-1',
        name: 'OpenAI Codex',
        description: 'OpenAI ACP Agent',
        cliCommand: 'codex',
        acpCommand: 'codex-acp --stdio',
        installCommand: 'npm i -g @openai/codex',
        loginCommand: 'codex login',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          version: '/usr/local/bin/codex',
          checkedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OpenAI Codex'), findsOneWidget);
      expect(find.text('CLI: codex'), findsOneWidget);
      expect(find.text('ACP: codex-acp --stdio'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
    },
  );

  testWidgets(
    'AgentFormDialog populates presets and validates required commands',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      await tester.pumpWidget(
        createTestApp(
          child: const Scaffold(body: AgentFormDialog(serverId: 'srv-test-1')),
          overrides: [localStorageServiceProvider.overrideWithValue(local)],
        ),
      );
      await tester.pumpAndSettle();

      // Default preset is Claude Code
      expect(find.text('Claude CodeX'), findsOneWidget);
      expect(find.text('claude'), findsOneWidget);
      expect(find.text('claude-code-acp'), findsOneWidget);

      // Switch to Codex preset
      await tester.tap(find.text('OpenAI Codex'));
      await tester.pumpAndSettle();

      expect(find.text('OpenAI Codex'), findsNWidgets(2));
      expect(find.text('codex'), findsOneWidget);
      expect(find.text('codex-acp'), findsOneWidget);

      // Switch to Custom preset
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      // Fields should be empty
      expect(find.text('codex'), findsNothing);

      // Tap Save - validation should trigger
      await tester.tap(find.text('Save & Detect'));
      await tester.pumpAndSettle();

      expect(find.text('Agent name is required'), findsOneWidget);
      expect(find.text('CLI probe command is required'), findsOneWidget);
    },
  );

  testWidgets(
    'showAgentCommandConfirmDialog shows details and handles actions',
    (tester) async {
      bool? result;

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showAgentCommandConfirmDialog(
                    context: context,
                    actionType: AgentCommandActionType.install,
                    agentName: 'Claude CodeX',
                    command: 'npm install -g @anthropic-ai/claude-code',
                    server: testServer,
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Agent Installation'), findsOneWidget);
      expect(
        find.text('npm install -g @anthropic-ai/claude-code'),
        findsOneWidget,
      );
      expect(find.text('Production US (192.168.1.100:22)'), findsOneWidget);

      // Click execute
      await tester.tap(find.text('Execute'));
      await tester.pumpAndSettle();

      expect(result, true);
    },
  );

  testWidgets(
    'AgentManagementView displays proactive install prompt when cliMissing and triggers installAgent on confirm',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'codex-cli-missing',
        serverId: 'srv-test-1',
        name: 'OpenAI Codex',
        description: 'OpenAI ACP Agent',
        cliCommand: 'codex',
        acpCommand: 'codex-acp --stdio',
        installCommand: 'npm i -g @openai/codex',
        loginCommand: 'codex login',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.cliMissing,
          checkedAt: DateTime.now(),
        ),
      );

      final mockRegistry = _MockAgentRegistryNotifier(
        AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(() => mockRegistry),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Check status badge
      expect(find.text('Installation not detected'), findsOneWidget);

      // Check proactive prompt and auto-install button
      expect(
        find.text('Installation not detected. Auto-install now?'),
        findsOneWidget,
      );
      final autoInstallBtn = find.text('Auto Install');
      expect(autoInstallBtn, findsOneWidget);
      expect(
        find.ancestor(
          of: autoInstallBtn,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
        findsOneWidget,
      );

      // Tap Auto Install to open confirmation dialog
      await tester.tap(autoInstallBtn);
      await tester.pumpAndSettle();

      expect(find.text('Confirm Agent Installation'), findsOneWidget);
      expect(find.text('npm i -g @openai/codex'), findsOneWidget);

      // Confirm in dialog
      await tester.tap(find.text('Execute'));
      await tester.pumpAndSettle();

      expect(mockRegistry.installedAgentId, 'codex-cli-missing');
    },
  );

  testWidgets(
    'AgentManagementView displays proactive login prompt when notLoggedIn and triggers loginAgent on confirm',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'codex-not-logged-in',
        serverId: 'srv-test-1',
        name: 'OpenAI Codex',
        description: 'OpenAI ACP Agent',
        cliCommand: 'codex',
        acpCommand: 'codex-acp --stdio',
        installCommand: 'npm i -g @openai/codex',
        loginCommand: 'codex login',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.notLoggedIn,
          checkedAt: DateTime.now(),
        ),
      );

      final mockRegistry = _MockAgentRegistryNotifier(
        AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
      );

      String? capturedHostRemoteExec;

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(() => mockRegistry),
            interactiveLoginLauncherProvider.overrideWithValue(({
              required context,
              required agentName,
              required command,
              required serverName,
              required sshClient,
              remoteExecCommand,
            }) async {
              capturedHostRemoteExec = remoteExecCommand;
              return true;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Check status badge
      expect(find.text('Not Logged In'), findsOneWidget);

      // Check proactive login prompt and button
      expect(find.text('Not logged in. Log in now?'), findsOneWidget);
      final loginBtn = find.text('Log In Now');
      expect(loginBtn, findsOneWidget);
      expect(
        find.ancestor(
          of: loginBtn,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
        findsOneWidget,
      );

      // Tap Log In Now to open confirmation dialog
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      expect(find.text('Confirm Agent Login'), findsOneWidget);
      expect(find.text('codex login'), findsOneWidget);

      // Confirm in dialog
      await tester.tap(find.text('Execute'));
      await tester.pumpAndSettle();

      expect(mockRegistry.loggedInAgentId, 'codex-not-logged-in');
      expect(capturedHostRemoteExec, isNull);
    },
  );

  testWidgets(
    'AgentManagementView for Docker agent passes agentTargetCommand as remoteExecCommand while dialog shows raw command',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'codex-docker-login',
        serverId: 'srv-test-1',
        name: 'Docker Codex',
        description: 'Docker ACP Agent',
        cliCommand: 'codex',
        acpCommand: 'codex-acp --stdio',
        installCommand: 'npm i -g @openai/codex',
        loginCommand: 'codex login',
        executionTarget: 'docker',
        containerBinding: 'name',
        containerReference: 'my-codex-container',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.notLoggedIn,
          checkedAt: DateTime.now(),
        ),
      );

      final mockRegistry = _MockAgentRegistryNotifier(
        AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
      );

      String? capturedCommand;
      String? capturedRemoteExec;

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(() => mockRegistry),
            interactiveLoginLauncherProvider.overrideWithValue(({
              required context,
              required agentName,
              required command,
              required serverName,
              required sshClient,
              remoteExecCommand,
            }) async {
              capturedCommand = command;
              capturedRemoteExec = remoteExecCommand;
              return true;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final loginBtn = find.text('Log In Now');
      expect(loginBtn, findsOneWidget);

      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      // Dialog must keep showing the raw command to the user
      expect(find.text('Confirm Agent Login'), findsOneWidget);
      expect(find.text('codex login'), findsOneWidget);
      expect(find.textContaining('docker exec'), findsNothing);

      // Confirm in dialog
      await tester.tap(find.text('Execute'));
      await tester.pumpAndSettle();

      expect(capturedCommand, 'codex login');
      expect(
        capturedRemoteExec,
        agentTargetCommand(profile, 'codex login', interactive: true),
      );
      expect(mockRegistry.loggedInAgentId, 'codex-docker-login');
    },
  );

  testWidgets(
    'Proactive install and login buttons are disabled when SSH is disconnected',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profileInstall = AgentProfile(
        id: 'codex-disconnected-install',
        serverId: 'srv-test-1',
        name: 'OpenAI Codex Install',
        description: 'OpenAI ACP Agent',
        cliCommand: 'codex',
        acpCommand: 'codex-acp --stdio',
        installCommand: 'npm i -g @openai/codex',
      );

      final profileLogin = AgentProfile(
        id: 'codex-disconnected-login',
        serverId: 'srv-test-1',
        name: 'OpenAI Codex Login',
        description: 'OpenAI ACP Agent',
        cliCommand: 'codex',
        acpCommand: 'codex-acp --stdio',
        loginCommand: 'codex login',
      );

      final runtimeInstall = AgentRuntimeState(
        profile: profileInstall,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.cliMissing,
          checkedAt: DateTime.now(),
        ),
      );

      final runtimeLogin = AgentRuntimeState(
        profile: profileLogin,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.notLoggedIn,
          checkedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.disconnected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(
                  serverId: 'srv-test-1',
                  agents: [runtimeInstall, runtimeLogin],
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final installButton = tester.widget<ButtonStyleButton>(
        find
            .ancestor(
              of: find.text('Auto Install'),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            )
            .first,
      );
      expect(installButton.onPressed, isNull);

      final loginButton = tester.widget<ButtonStyleButton>(
        find
            .ancestor(
              of: find.text('Log In Now'),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            )
            .first,
      );
      expect(loginButton.onPressed, isNull);
    },
  );

  testWidgets('AgentManagementView shows installing progress indicator', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final local = await LocalStorageService.init();

    final profileInstall = AgentProfile(
      id: 'codex-installing',
      serverId: 'srv-test-1',
      name: 'OpenAI Codex Installing',
      description: 'OpenAI ACP Agent',
      cliCommand: 'codex',
      acpCommand: 'codex-acp --stdio',
      installCommand: 'npm i -g @openai/codex',
    );

    final runtimeInstall = AgentRuntimeState(
      profile: profileInstall,
      status: AgentEnvironmentStatus(
        kind: AgentEnvironmentStatusKind.cliMissing,
        checkedAt: DateTime.now(),
      ),
      isInstalling: true,
    );

    await tester.pumpWidget(
      createTestApp(
        child: const AgentManagementView(),
        overrides: [
          localStorageServiceProvider.overrideWithValue(local),
          activeServerProvider.overrideWith(
            () => _MockActiveServerNotifier(testServer),
          ),
          serverConnectionProvider.overrideWith(
            () => _MockServerConnectionNotifier(
              const ServerConnectionState(
                status: ConnectionStateEnum.connected,
              ),
            ),
          ),
          agentRegistryProvider.overrideWith(
            () => _MockAgentRegistryNotifier(
              AgentRegistryState(
                serverId: 'srv-test-1',
                agents: [runtimeInstall],
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Installing dependencies on server...'), findsOneWidget);
  });

  testWidgets(
    'AiChatView proactively guides to agent management when unready agents exist',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'codex-unready',
        serverId: 'srv-test-1',
        name: 'OpenAI Codex',
        description: 'OpenAI ACP Agent',
        cliCommand: 'codex',
        acpCommand: 'codex-acp --stdio',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.cliMissing,
          checkedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AiChatView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
            aiChatProvider.overrideWith(
              () => _MockAiChatNotifier(
                const AiChatState(sessions: [], activeAgentProfile: null),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Agents on this server are not installed or ready yet. Please manage and complete environment setup.',
        ),
        findsWidgets,
      );
      expect(
        find.text('Install and ready an agent to start chatting...'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AgentManagementView displays proactive install prompt when acpMissing and triggers installForCurrentStatus on confirm',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'codex-acp-missing',
        serverId: 'srv-test-1',
        name: 'OpenAI Codex',
        description: 'OpenAI ACP Agent',
        cliCommand: 'codex',
        acpCommand: 'codex-acp --stdio',
        installCommand: 'npm i -g @openai/codex',
        acpInstallCommand: 'npm install -g @zed-industries/codex-acp',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.acpMissing,
          checkedAt: DateTime.now(),
        ),
      );

      final mockRegistry = _MockAgentRegistryNotifier(
        AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(() => mockRegistry),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Check status badge
      expect(find.text('ACP component not detected'), findsOneWidget);

      // Check proactive prompt for ACP
      expect(
        find.text('ACP component not detected. Auto-install now?'),
        findsOneWidget,
      );
      final autoInstallBtn = find.text('Auto Install');
      expect(autoInstallBtn, findsOneWidget);
      expect(
        find.ancestor(
          of: autoInstallBtn,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
        findsOneWidget,
      );

      // Tap Auto Install to open confirmation dialog
      await tester.tap(autoInstallBtn);
      await tester.pumpAndSettle();

      expect(find.text('Confirm Agent Installation'), findsOneWidget);
      expect(
        find.text('npm install -g @zed-industries/codex-acp'),
        findsOneWidget,
      );

      // Confirm in dialog
      await tester.tap(find.text('Execute'));
      await tester.pumpAndSettle();

      expect(mockRegistry.installedAgentId, 'codex-acp-missing');
    },
  );

  testWidgets(
    'AgentManagementView displays no install command note when no install command is configured',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'agent-no-install-cmd',
        serverId: 'srv-test-1',
        name: 'Manual Agent',
        description: 'Agent with no install command',
        cliCommand: 'custom-cli',
        acpCommand: 'custom-acp',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.cliMissing,
          checkedAt: DateTime.now(),
        ),
      );

      final mockRegistry = _MockAgentRegistryNotifier(
        AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(() => mockRegistry),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Check status badge
      expect(find.text('Installation not detected'), findsOneWidget);

      // Check no install command note
      expect(
        find.text('No install command configured for this agent'),
        findsOneWidget,
      );

      // Auto Install button should NOT exist
      expect(find.text('Auto Install'), findsNothing);
    },
  );

  testWidgets(
    'AiChatView provides one-click auto-install when exactly one installable agent exists',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'codex-chat-install',
        serverId: 'srv-test-1',
        name: 'OpenAI Codex',
        description: 'OpenAI ACP Agent',
        cliCommand: 'codex',
        acpCommand: 'codex-acp --stdio',
        installCommand: 'npm i -g @openai/codex',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.cliMissing,
          checkedAt: DateTime.now(),
        ),
      );

      final mockRegistry = _MockAgentRegistryNotifier(
        AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AiChatView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(() => mockRegistry),
            aiChatProvider.overrideWith(
              () => _MockAiChatNotifier(
                const AiChatState(sessions: [], activeAgentProfile: null),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Auto Install button should exist
      final autoInstallBtns = find.text('Auto Install');
      expect(autoInstallBtns, findsWidgets);

      // Tap the first Auto Install button
      await tester.tap(autoInstallBtns.first);
      await tester.pumpAndSettle();

      expect(find.text('Confirm Agent Installation'), findsOneWidget);
      expect(find.text('npm i -g @openai/codex'), findsOneWidget);

      // Confirm in dialog
      await tester.tap(find.text('Execute'));
      await tester.pumpAndSettle();

      expect(mockRegistry.installedAgentId, 'codex-chat-install');
    },
  );

  testWidgets(
    'AgentManagementView renders install log panel with streamed lines for installing agent',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'codex-installing',
        serverId: 'srv-test-1',
        name: 'OpenAI Codex',
        description: 'OpenAI ACP Agent',
        cliCommand: 'codex',
        acpCommand: 'codex-acp',
        installCommand: 'npm i -g @openai/codex',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.cliMissing,
          checkedAt: DateTime.now(),
        ),
        isInstalling: true,
      );

      final log = InstallLog(
        agentId: 'codex-installing',
        lines: const [
          'npm notice created a lockfile',
          'added 45 packages in 2s',
          'Install complete',
        ],
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
            installLogProvider.overrideWith(() => _MockInstallLogNotifier(log)),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Install output'), findsOneWidget);
      expect(find.text('npm notice created a lockfile'), findsOneWidget);
      expect(find.text('added 45 packages in 2s'), findsOneWidget);
      expect(find.text('Install complete'), findsOneWidget);
    },
  );

  testWidgets(
    'AgentManagementView shows truncated notice when installLog is truncated',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'codex-truncated',
        serverId: 'srv-test-1',
        name: 'OpenAI Codex',
        description: 'OpenAI ACP Agent',
        cliCommand: 'codex',
        acpCommand: 'codex-acp',
        installCommand: 'npm i -g @openai/codex',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.cliMissing,
          checkedAt: DateTime.now(),
        ),
        isInstalling: true,
      );

      final log = InstallLog(
        agentId: 'codex-truncated',
        lines: const ['tail line 1', 'tail line 2'],
        truncated: true,
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
            installLogProvider.overrideWith(() => _MockInstallLogNotifier(log)),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Install output'), findsOneWidget);
      expect(
        find.text('Output too long; showing the most recent lines'),
        findsOneWidget,
      );
      expect(find.text('tail line 1'), findsOneWidget);
    },
  );

  testWidgets(
    'AgentManagementView shows empty placeholder when installLog is empty',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'codex-empty-log',
        serverId: 'srv-test-1',
        name: 'OpenAI Codex',
        description: 'OpenAI ACP Agent',
        cliCommand: 'codex',
        acpCommand: 'codex-acp',
        installCommand: 'npm i -g @openai/codex',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.cliMissing,
          checkedAt: DateTime.now(),
        ),
        isInstalling: true,
      );

      final log = InstallLog(agentId: 'codex-empty-log', lines: const []);

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
            installLogProvider.overrideWith(() => _MockInstallLogNotifier(log)),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Install output'), findsOneWidget);
      expect(find.text('Waiting for install output…'), findsOneWidget);
    },
  );

  testWidgets(
    'Agent with null/empty acpCommand does NOT show ACP-missing prompt or ACP install action',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'builtin-agy',
        serverId: 'srv-test-1',
        name: 'Antigravity AGY',
        description: 'CLI-only agent',
        cliCommand: 'agy',
        acpCommand: null,
        installCommand: 'npm i -g agy',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          version: '/usr/local/bin/agy 1.0.0',
          checkedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Antigravity AGY'), findsOneWidget);
      expect(find.text('CLI: agy'), findsOneWidget);
      expect(find.text('ACP: N/A'), findsNWidgets(2));
      expect(find.text('Ready'), findsOneWidget);

      expect(find.text('ACP component not detected'), findsNothing);
      expect(
        find.text('ACP component not detected. Auto-install now?'),
        findsNothing,
      );
      expect(find.text('Auto Install'), findsNothing);
    },
  );

  testWidgets(
    'Agent with null acpCommand does NOT show ACP-missing prompt even if status kind is acpMissing',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'builtin-agy-no-acp',
        serverId: 'srv-test-1',
        name: 'Antigravity AGY',
        description: 'CLI-only agent',
        cliCommand: 'agy',
        acpCommand: null,
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.acpMissing,
          checkedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ACP component not detected'), findsNothing);
      expect(
        find.text('ACP component not detected. Auto-install now?'),
        findsNothing,
      );
      expect(find.text('Auto Install'), findsNothing);
    },
  );

  testWidgets(
    'AgentManagementView shows edit button on agent card and clicking it opens edit dialog with prefilled profile',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'agent-dev-1',
        serverId: 'srv-test-1',
        name: 'Dev Assistant',
        description: 'Development assistant',
        cliCommand: 'dev-assist --cli',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          authentication: AgentAuthenticationStatus.authenticated,
          checkedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final editBtn = find.byKey(const Key('agent_edit_button_agent-dev-1'));
      expect(editBtn, findsOneWidget);

      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.byType(AgentFormDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AgentFormDialog),
          matching: find.text('Dev Assistant'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AgentFormDialog),
          matching: find.text('dev-assist --cli'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AgentManagementView renders Docker execution chip when executionTarget is docker',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'agent-docker-1',
        serverId: 'srv-test-1',
        name: 'Docker Assistant',
        description: 'Runs in docker container',
        cliCommand: 'docker-agent --cli',
        executionTarget: 'docker',
        containerBinding: 'name',
        containerReference: 'my-web-container',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          authentication: AgentAuthenticationStatus.authenticated,
          checkedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Docker: my-web-container'), findsOneWidget);
    },
  );

  testWidgets(
    'AgentManagementView renders diagnostic log button disabled when diagnosticLog is empty',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'agent-no-log',
        serverId: 'srv-test-1',
        name: 'No Log Agent',
        description: 'Agent without diagnostic log',
        cliCommand: 'echo hello',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          authentication: AgentAuthenticationStatus.authenticated,
          checkedAt: DateTime.now(),
          diagnosticLog: '',
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final logBtnFinder = find.byKey(
        const Key('agent_diagnostic_log_button_agent-no-log'),
      );
      expect(logBtnFinder, findsOneWidget);
      expect(find.text('View Diagnostic Log'), findsOneWidget);

      final buttonWidget = tester.widget<OutlinedButton>(logBtnFinder);
      expect(buttonWidget.enabled, isFalse);
    },
  );

  testWidgets(
    'AgentManagementView enables diagnostic log button when non-empty, opens monospace dialog with exact log, copies to clipboard with feedback, and closes',
    (tester) async {
      String? clipboardText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      const rawLog =
          '[STEP 1] Probing CLI environment...\n'
          '[STEP 2] Checking authentication for user dev...\n'
          '[RESULT] Agent is authenticated and ready.';

      final profile = AgentProfile(
        id: 'agent-with-log',
        serverId: 'srv-test-1',
        name: 'Logged Agent',
        description: 'Agent with diagnostic log',
        cliCommand: 'logged-cli',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          authentication: AgentAuthenticationStatus.authenticated,
          checkedAt: DateTime.now(),
          diagnosticLog: rawLog,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final logBtnFinder = find.byKey(
        const Key('agent_diagnostic_log_button_agent-with-log'),
      );
      expect(logBtnFinder, findsOneWidget);
      final buttonWidget = tester.widget<OutlinedButton>(logBtnFinder);
      expect(buttonWidget.enabled, isTrue);

      // Open log dialog
      await tester.tap(logBtnFinder);
      await tester.pumpAndSettle();

      // Dialog title with agent name
      expect(find.text('Diagnostic Log - Logged Agent'), findsOneWidget);

      // Exact raw diagnostic log displayed without truncation or modifications
      final contentFinder = find.byKey(
        const Key('agent_diagnostic_log_content'),
      );
      expect(contentFinder, findsOneWidget);
      final textWidget = tester.widget<SelectableText>(contentFinder);
      expect(textWidget.data, rawLog);
      expect(textWidget.style?.fontFamily, 'JetBrains Mono');

      // Copy button
      final copyBtn = find.byKey(const Key('agent_diagnostic_log_copy_button'));
      expect(copyBtn, findsOneWidget);
      await tester.tap(copyBtn);
      await tester.pumpAndSettle();

      expect(clipboardText, rawLog);

      // Verify localized SnackBar feedback
      expect(find.text('Diagnostic log copied to clipboard'), findsOneWidget);

      // Close button dismisses dialog
      final closeBtn = find.byKey(
        const Key('agent_diagnostic_log_close_button'),
      );
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.text('Diagnostic Log - Logged Agent'), findsNothing);
    },
  );

  testWidgets(
    'AgentManagementView and diagnostic log dialog render on 360px narrow viewport without layout overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'narrow-agent',
        serverId: 'srv-test-1',
        name: 'Narrow Agent With Very Long Name For Testing',
        description: 'Agent for narrow test',
        cliCommand: 'super-long-cli-command --option-foo --flag-bar',
        executionTarget: 'docker',
        containerBinding: 'name',
        containerReference: 'very-long-container-reference-prod',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          authentication: AgentAuthenticationStatus.authenticated,
          checkedAt: DateTime.now(),
          diagnosticLog: 'Line 1\nLine 2\nLine 3',
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final logBtn = find.byKey(
        const Key('agent_diagnostic_log_button_narrow-agent'),
      );
      await tester.ensureVisible(logBtn);
      await tester.tap(logBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('agent_diagnostic_log_content')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'saved/unverified 的内置 AgY 只显示 Auth: Unknown，绝不弹「Not logged in. Log in now?」',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'builtin-agy',
        serverId: 'srv-test-1',
        name: 'Antigravity',
        description: 'Official ACP agent',
        cliCommand: 'agy',
        acpCommand: 'agy_acp_server.par',
        loginCommand: 'agy',
        loginCheckCommand: kAntigravityLoginCheckCommand,
      );

      // 内置 AgY 现在自带只读 readiness 探针：saved → AGY_ACP_CREDENTIALS_NOT_VALIDATED，
      // authentication 仍是 unknown——既不是已登录，也不是未登录。
      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          detail: 'AGY_ACP_CREDENTIALS_NOT_VALIDATED',
          checkedAt: DateTime.now(),
          authentication: AgentAuthenticationStatus.unknown,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const AgentManagementView(),
          overrides: [
            localStorageServiceProvider.overrideWithValue(local),
            activeServerProvider.overrideWith(
              () => _MockActiveServerNotifier(testServer),
            ),
            serverConnectionProvider.overrideWith(
              () => _MockServerConnectionNotifier(
                const ServerConnectionState(
                  status: ConnectionStateEnum.connected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Auth: Unknown'), findsOneWidget);
      expect(find.text('Auth: Logged In'), findsNothing);
      expect(
        find.text('Not logged in. Log in now?'),
        findsNothing,
        reason: 'saved/unverified 不是未登录，不得触发主动登录提示',
      );
      expect(find.text('Log In Now'), findsNothing);
      expect(find.text('ACP credentials saved (unverified)'), findsOneWidget);
      expect(
        find.byKey(const Key('agent_acp_callout_login_builtin-agy')),
        findsNothing,
        reason: '只有 missing 才需要主动 ACP Sign-In callout',
      );

      // 官方 ACP 的认证走会话内挑战，不代表手动 CLI / ACP 登录入口被删掉。
      expect(
        find.byKey(const Key('agent_bottom_login_builtin-agy')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('agent_acp_login_builtin-agy')),
        findsOneWidget,
      );
    },
  );

  testWidgets('missing 的内置 AgY 显示 ACP 缺失与显式 ACP Sign-In 入口，且绝不冒充已登录', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final local = await LocalStorageService.init();

    final profile = AgentProfile(
      id: 'builtin-agy',
      serverId: 'srv-test-1',
      name: 'Antigravity',
      description: 'Official ACP agent',
      cliCommand: 'agy',
      acpCommand: 'agy_acp_server.par',
      loginCommand: 'agy',
      loginCheckCommand: kAntigravityLoginCheckCommand,
    );

    final runtime = AgentRuntimeState(
      profile: profile,
      status: AgentEnvironmentStatus(
        kind: AgentEnvironmentStatusKind.ready,
        detail: 'AGY_ACP_SIGN_IN_REQUIRED',
        checkedAt: DateTime.now(),
        authentication: AgentAuthenticationStatus.unauthenticated,
      ),
    );

    await tester.pumpWidget(
      createTestApp(
        child: const AgentManagementView(),
        overrides: [
          localStorageServiceProvider.overrideWithValue(local),
          activeServerProvider.overrideWith(
            () => _MockActiveServerNotifier(testServer),
          ),
          serverConnectionProvider.overrideWith(
            () => _MockServerConnectionNotifier(
              const ServerConnectionState(
                status: ConnectionStateEnum.connected,
              ),
            ),
          ),
          agentRegistryProvider.overrideWith(
            () => _MockAgentRegistryNotifier(
              AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Auth: Not Logged In'), findsOneWidget);
    expect(find.text('Auth: Logged In'), findsNothing);
    expect(
      find.text('ACP credentials missing (ACP sign-in required)'),
      findsNWidgets(2),
      reason: 'detail 行与主动 callout 都必须复述该状态',
    );
    expect(
      find.text('Not logged in. Log in now?'),
      findsNothing,
      reason: 'AgY 走 ACP Sign-In callout，不套用 CLI 登录提示',
    );
    expect(
      find.byKey(const Key('agent_acp_callout_login_builtin-agy')),
      findsOneWidget,
    );
    expect(find.text('ACP Sign-In'), findsWidgets);
    expect(
      find.byKey(const Key('agent_acp_login_builtin-agy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('agent_bottom_login_builtin-agy')),
      findsOneWidget,
    );
  });

  testWidgets('installer 确认弹窗在 320dp + 2x 字号下：多 KB 命令可复制，Cancel/Execute 都够得着', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 真实官方安装脚本 + 一段不可断行的长 token，凑成多 KB 级命令。
    final token = List.filled(600, 'deadbeefcafe1234').join();
    final command = '$kAntigravityAcpInstallCommand\nprintf %s $token';
    expect(command.length, greaterThan(4000), reason: '必须是多 KB 级命令');

    final copied = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      copied.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    bool? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tempChatRepositoryOverride()],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showAgentCommandConfirmDialog(
                      context: context,
                      actionType: AgentCommandActionType.install,
                      agentName: 'Antigravity',
                      command: command,
                      server: testServer,
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 记录（而不是在第一个异常处短路）以便一次跑完，把所有渲染异常一并报上来。
    final layoutErrs = <String>[];
    void grabLayoutErrors() {
      for (var i = 0; i < 64; i++) {
        final e = tester.takeException();
        if (e == null) break;
        layoutErrs.add(e.toString());
      }
    }

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
    grabLayoutErrors();

    // 命令必须完整在场，绝不允许被截断。
    final preview = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(preview.data, command);

    final copyBtn = find.byKey(const Key('agent_command_copy_button'));
    expect(copyBtn, findsOneWidget);
    await tester.ensureVisible(copyBtn);
    await tester.tap(copyBtn);
    await tester.pumpAndSettle();
    grabLayoutErrors();

    final setData = copied.where((c) => c.method == 'Clipboard.setData');
    expect(setData, hasLength(1), reason: '复制按钮必须真的写了剪贴板');
    expect(
      (setData.single.arguments as Map)['text'],
      command,
      reason: '复制的是完整命令，不是被滚动裁掉的一段',
    );

    // 320dp + 2x 字号下两个确认动作都要落在屏幕内。
    final screen = tester.getRect(find.byType(MaterialApp));
    for (final label in ['Cancel', 'Execute']) {
      final rect = tester.getRect(find.text(label));
      expect(
        screen.contains(rect.center),
        isTrue,
        reason: '$label 在窄屏大字号下必须仍可见',
      );
    }

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    grabLayoutErrors();
    expect(result, false);

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
    grabLayoutErrors();
    await tester.tap(find.text('Execute'));
    await tester.pumpAndSettle();
    grabLayoutErrors();
    expect(result, true);

    expect(layoutErrs, isEmpty, reason: '窄屏大字号下渲染异常：$layoutErrs');
  });
}

class _MockAgentRegistryNotifier extends AgentRegistryNotifier {
  final AgentRegistryState _initialState;
  String? installedAgentId;
  String? loggedInAgentId;

  _MockAgentRegistryNotifier(this._initialState);

  @override
  AgentRegistryState build() => _initialState;

  @override
  Future<void> installAgent(String agentId) async {
    installedAgentId = agentId;
  }

  @override
  Future<void> installForCurrentStatus(String agentId) async {
    installedAgentId = agentId;
  }

  @override
  Future<void> loginAgent(String agentId) async {
    loggedInAgentId = agentId;
  }
}

class _MockActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _server;
  _MockActiveServerNotifier(this._server);

  @override
  ServerProfile? build() => _server;
}

class _MockServerConnectionNotifier extends ServerConnectionNotifier {
  final ServerConnectionState _initialState;
  _MockServerConnectionNotifier(this._initialState);

  @override
  ServerConnectionState build() => _initialState;
}

class _MockAiChatNotifier extends AiChatNotifier {
  final AiChatState _initialState;
  _MockAiChatNotifier(this._initialState);

  @override
  AiChatState build() => _initialState;
}

class _MockInstallLogNotifier extends InstallLogNotifier {
  final InstallLog _initial;
  _MockInstallLogNotifier([this._initial = InstallLog.empty]);

  @override
  InstallLog build() => _initial;
}
