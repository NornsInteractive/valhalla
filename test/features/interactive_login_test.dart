import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm/xterm.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/agents/interactive_login_dialog.dart';
import 'package:valhalla/features/agents/interactive_login_provider.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/features/terminal/widgets/terminal_accessory_bar.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import '../support/fixed_terminal_settings.dart';
import '../support/temp_chat_db.dart';

class _MockAiChatNotifier extends AiChatNotifier {
  final AiChatState _initial;
  String? respondedMethodId;

  _MockAiChatNotifier(this._initial);

  @override
  AiChatState build() => _initial;

  @override
  Future<void> respondAuth(String? methodId) async {
    respondedMethodId = methodId;
    state = state.copyWith(clearAuthChallenge: true);
  }
}

class _MockAgentRegistryNotifier extends AgentRegistryNotifier {
  final AgentRegistryState _initial;
  String? loggedInAgentId;

  _MockAgentRegistryNotifier(this._initial);

  @override
  AgentRegistryState build() => _initial;

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

void main() {
  final testServer = ServerProfile(
    id: 'srv-test-login',
    name: 'Login Test Server',
    host: '10.0.0.1',
    port: 22,
    username: 'root',
    authType: AuthType.password,
  );

  Widget createTestApp({
    required Widget child,
    List<dynamic> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        tempChatRepositoryOverride(),
        ...fixedTerminalSettingsOverrides(),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  group('TerminalAccessoryBar', () {
    testWidgets('renders all keys and triggers callbacks', (tester) async {
      final pressedKeys = <String>[];
      var ctrlToggled = false;
      var altToggled = false;
      var pasted = false;
      var pasteDeliveries = 0;

      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: TerminalAccessoryBar(
              onKey: (key, {bool isCtrl = false, bool isAlt = false}) {
                pressedKeys.add('${isCtrl ? 'Ctrl+' : ''}$key');
              },
              onToggleCtrl: () => ctrlToggled = true,
              onToggleAlt: () => altToggled = true,
              onPaste: () {
                pasted = true;
                pasteDeliveries++;
              },
              isCtrlActive: false,
              isAltActive: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pinned row (default pinned keys): ESC/TAB/CTRL/ALT/Ctrl+C/PASTE stay
      // inline without opening any panel.
      expect(find.text('ESC'), findsOneWidget);
      expect(find.text('TAB'), findsOneWidget);
      expect(find.text('CTRL'), findsOneWidget);
      expect(find.text('ALT'), findsOneWidget);
      expect(find.text('Ctrl+C'), findsOneWidget);
      expect(find.byIcon(Icons.content_paste), findsOneWidget);

      await tester.tap(find.text('ESC'));
      expect(pressedKeys, contains('ESC'));

      await tester.tap(find.text('CTRL'));
      expect(ctrlToggled, isTrue);

      await tester.tap(find.text('ALT'));
      expect(altToggled, isTrue);

      await tester.tap(find.text('Ctrl+C'));
      expect(pressedKeys, contains('Ctrl+C'));

      await tester.tap(find.byIcon(Icons.content_paste));
      await tester.pumpAndSettle();
      expect(pasted, isTrue);
      expect(
        pasteDeliveries,
        1,
        reason: 'paste callback must be delivered exactly once',
      );

      // Unpinned keys are only reachable through the More panel: arrows live
      // in the Nav category, Ctrl+D in the Edit category.
      await tester.tap(find.byKey(const Key('terminal_accessory_more_button')));
      await tester.pumpAndSettle();

      expect(find.text('↑'), findsOneWidget);
      await tester.tap(find.text('↑'));
      expect(pressedKeys, contains('↑'));
      expect(
        pressedKeys.where((key) => key == '↑').length,
        1,
        reason: 'arrow key must be delivered exactly once',
      );

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Ctrl+D'), findsOneWidget);
      await tester.tap(find.text('Ctrl+D'));
      expect(pressedKeys, contains('Ctrl+D'));
    });
  });

  group('InteractiveLoginDialog', () {
    testWidgets('renders dialog and returns null on Close', (tester) async {
      bool? dialogResult = true;

      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    dialogResult = await showInteractiveLoginDialog(
                      context: context,
                      agentName: 'Codex Agent',
                      command: 'codex login',
                      serverName: 'Production US',
                      sshClient: null,
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(
        find.text('Interactive Login Terminal - Codex Agent'),
        findsOneWidget,
      );
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Finish & Verify'), findsOneWidget);
      expect(
        find.text('SSH connection lost. The login session was interrupted.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(dialogResult, isNull);
    });

    testWidgets('returns true on Finish & Verify', (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    dialogResult = await showInteractiveLoginDialog(
                      context: context,
                      agentName: 'Codex Agent',
                      command: 'codex login',
                      serverName: 'Production US',
                      sshClient: null,
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Finish & Verify'));
      await tester.pumpAndSettle();

      expect(dialogResult, isTrue);
    });

    testWidgets('copyAllButton copies terminal buffer to clipboard', (
      tester,
    ) async {
      String? copiedContent;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'Clipboard.setData') {
              final args = methodCall.arguments as Map<dynamic, dynamic>;
              copiedContent = args['text'] as String;
              return null;
            } else if (methodCall.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': copiedContent};
            }
            return null;
          });

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showInteractiveLoginDialog(
                  context: context,
                  agentName: 'Codex Agent',
                  command: 'codex login',
                  serverName: 'Production US',
                  sshClient: null,
                ),
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('copyAllButton')), findsOneWidget);
      expect(find.byKey(const Key('loginUrlChip')), findsNothing);

      await tester.tap(find.byKey(const Key('copyAllButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.widgetWithText(SnackBar, 'Terminal output copied to clipboard'),
        findsOneWidget,
      );
      expect(copiedContent, contains('Valhalla SSH Terminal'));
    });

    testWidgets('detects login URL, renders loginUrlChip, and copies URL', (
      tester,
    ) async {
      String? copiedContent;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall methodCall,
          ) async {
            if (methodCall.method == 'Clipboard.setData') {
              final args = methodCall.arguments as Map<dynamic, dynamic>;
              copiedContent = args['text'] as String;
              return null;
            } else if (methodCall.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': copiedContent};
            }
            return null;
          });

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showInteractiveLoginDialog(
                  context: context,
                  agentName: 'Codex Agent',
                  command: 'codex login',
                  serverName: 'Production US',
                  sshClient: null,
                ),
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loginUrlChip')), findsNothing);

      final terminalView = tester.widget<TerminalView>(
        find.byType(TerminalView),
      );
      terminalView.terminal.write(
        'Open browser at https://auth.openai.com/oauth/authorize?client_id=123&code=456 to continue\r\n',
      );

      // Wait for the 250ms debounce
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loginUrlChip')), findsOneWidget);
      expect(find.byKey(const Key('loginUrlCopyButton')), findsOneWidget);
      expect(
        find.text(
          'https://auth.openai.com/oauth/authorize?client_id=123&code=456',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('loginUrlCopyButton')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.widgetWithText(SnackBar, 'Login URL copied to clipboard'),
        findsOneWidget,
      );
      expect(
        copiedContent,
        'https://auth.openai.com/oauth/authorize?client_id=123&code=456',
      );
    });
  });

  group('AiChatView Interactive Login Integration', () {
    testWidgets(
      'triggers launcher and rechecks loginAgent when dialog completes',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final local = await LocalStorageService.init();

        const agentId = 'test-codex-login';
        final profile = AgentProfile(
          id: agentId,
          serverId: testServer.id,
          name: 'Codex Auth Agent',
          description: 'Codex description',
          cliCommand: 'codex',
          acpCommand: 'codex-acp',
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
          AgentRegistryState(serverId: testServer.id, agents: [runtime]),
        );

        const challenge = AuthChallenge(
          agentId: agentId,
          methods: [AcpAuthMethod(id: 'auth1', name: 'Browser OAuth')],
        );

        final mockChat = _MockAiChatNotifier(
          AiChatState(
            sessions: [
              ChatSession(
                id: 'sess-1',
                title: 'Test Session',
                agentId: agentId,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                messages: const [],
              ),
            ],
            activeSessionId: 'sess-1',
            readyAgents: [profile],
            activeAgentProfile: profile,
            authChallenge: challenge,
          ),
        );

        var launcherCalled = false;
        String? launcherCommand;

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
              aiChatProvider.overrideWith(() => mockChat),
              interactiveLoginLauncherProvider.overrideWithValue(({
                required context,
                required agentName,
                required command,
                required serverName,
                required sshClient,
                remoteExecCommand,
              }) async {
                launcherCalled = true;
                launcherCommand = command;
                return true;
              }),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Check Auth Challenge card
        expect(find.text('Authentication Required'), findsOneWidget);
        expect(find.text('Log In'), findsOneWidget);

        // Tap Log In to open confirmation dialog
        await tester.ensureVisible(find.text('Log In'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Log In'));
        await tester.pumpAndSettle();

        // Confirm command execution
        expect(find.text('Confirm Agent Login'), findsOneWidget);
        await tester.tap(find.text('Execute'));
        await tester.pumpAndSettle();

        expect(launcherCalled, isTrue);
        expect(launcherCommand, 'codex login');
        expect(mockRegistry.loggedInAgentId, agentId);
        expect(
          find.text('After logging in, send your message again.'),
          findsOneWidget,
        );
      },
    );
  });
}
