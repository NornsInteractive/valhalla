import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/agents/auth_method_picker_dialog.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
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

  group('AuthMethodPickerDialog', () {
    testWidgets('shows methods and returns selected methodId on proceed', (
      tester,
    ) async {
      String? result;

      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showAuthMethodPickerDialog(
                      context: context,
                      agentName: 'Codex Agent',
                      methods: const [
                        AcpAuthMethod(
                          id: 'browser_oauth',
                          name: 'Browser Login',
                          description: 'Log in via OpenAI browser popup',
                        ),
                        AcpAuthMethod(
                          id: 'api_key',
                          name: 'API Key',
                          description: 'Enter your API key',
                        ),
                      ],
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Choose how to log in to Codex Agent'), findsOneWidget);
      expect(find.text('Browser Login'), findsOneWidget);
      expect(find.text('Log in via OpenAI browser popup'), findsOneWidget);
      expect(find.text('API Key'), findsOneWidget);

      // Select API Key option
      await tester.tap(find.text('API Key'));
      await tester.pumpAndSettle();

      // Tap Proceed
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();

      expect(result, 'api_key');
    });

    testWidgets('returns null on cancel', (tester) async {
      String? result = 'initial';

      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showAuthMethodPickerDialog(
                      context: context,
                      agentName: 'Codex Agent',
                      methods: const [
                        AcpAuthMethod(id: 'm1', name: 'Method 1'),
                      ],
                    );
                  },
                  child: const Text('Open Dialog'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('AiChatView AuthChallengeCard', () {
    testWidgets('renders notice when methods list is empty', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'builtin-agy',
        serverId: 'srv-test-1',
        name: 'Antigravity AGY',
        description: 'CLI agent',
        cliCommand: 'agy',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          checkedAt: DateTime.now(),
        ),
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
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
            aiChatProvider.overrideWith(
              () => _MockAiChatNotifier(
                AiChatState(
                  sessions: const [],
                  activeAgentProfile: profile,
                  authChallenge: const AuthChallenge(
                    agentId: 'builtin-agy',
                    methods: [],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Authentication Required'), findsOneWidget);
      expect(
        find.text(
          'The agent requires authentication before it can process your request.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'The agent did not provide a login method. Please check its configuration on the server.',
        ),
        findsOneWidget,
      );
      expect(find.text('Log In'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    /// 组装「已有消息」的会话态，用来验证真实挑战卡片到底挂在哪里。
    Widget pendingTurnApp({
      required LocalStorageService local,
      required AgentRuntimeState runtime,
      required AgentProfile profile,
      required ChatTurnStatus assistantStatus,
      required AuthChallenge challenge,
    }) {
      final session = ChatSession(
        id: 'sess-attached',
        title: 'attached',
        serverId: 'srv-test-1',
        agentId: 'builtin-agy',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        messages: [
          ChatMessage(
            id: 'm1',
            role: MessageRole.user,
            content: 'hi',
            createdAt: DateTime.utc(2026),
          ),
          ChatMessage(
            id: 'm2',
            role: MessageRole.assistant,
            content: '',
            status: assistantStatus,
            createdAt: DateTime.utc(2026),
          ),
        ],
      );
      return createTestApp(
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
          agentRegistryProvider.overrideWith(
            () => _MockAgentRegistryNotifier(
              AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
            ),
          ),
          aiChatProvider.overrideWith(
            () => _MockAiChatNotifier(
              AiChatState(
                sessions: [session],
                activeSessionId: session.id,
                activeAgentProfile: profile,
                authChallenge: challenge,
              ),
            ),
          ),
        ],
      );
    }

    testWidgets('待认证轮次里只渲染一张真实卡片，并贴在该轮状态下方', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();
      final profile = AgentProfile(
        id: 'builtin-agy',
        serverId: 'srv-test-1',
        name: 'Antigravity AGY',
        description: 'ACP agent',
        cliCommand: 'agy',
        acpCommand: 'agy_acp_server.par',
        loginCommand: 'agy',
      );
      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          checkedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        pendingTurnApp(
          local: local,
          runtime: runtime,
          profile: profile,
          assistantStatus: ChatTurnStatus.awaitingAuthentication,
          challenge: AuthChallenge(
            agentId: 'builtin-agy',
            methods: const [
              AcpAuthMethod(id: 'browser_oauth', name: 'Browser Login'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Authentication Required'),
        findsOneWidget,
        reason: '整个界面只能出现一张挑战卡片',
      );

      final turn = find.byKey(const ValueKey('assistant_msg_m2'));
      expect(turn, findsOneWidget);
      expect(
        find.descendant(
          of: turn,
          matching: find.text('Authentication Required'),
        ),
        findsOneWidget,
        reason: '卡片必须挂在待认证的那一轮上，避免被自动滚动埋掉',
      );
      expect(
        find.descendant(
          of: turn,
          matching: find.byKey(const Key('chat_status_awaiting_auth_badge')),
        ),
        findsOneWidget,
      );
      // 等待认证的徽标，而不是「已中断」。
      expect(find.text('Interrupted'), findsNothing);
      expect(find.text('Awaiting ACP Authentication'), findsOneWidget);
    });

    testWidgets('轮次已结束时卡片落到屏幕底部，且仍然只有一张', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();
      final profile = AgentProfile(
        id: 'builtin-agy',
        serverId: 'srv-test-1',
        name: 'Antigravity AGY',
        description: 'ACP agent',
        cliCommand: 'agy',
        acpCommand: 'agy_acp_server.par',
        loginCommand: 'agy',
      );
      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          checkedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        pendingTurnApp(
          local: local,
          runtime: runtime,
          profile: profile,
          assistantStatus: ChatTurnStatus.completed,
          challenge: AuthChallenge(
            agentId: 'builtin-agy',
            methods: const [
              AcpAuthMethod(id: 'browser_oauth', name: 'Browser Login'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Authentication Required'), findsOneWidget);

      final turn = find.byKey(const ValueKey('assistant_msg_m2'));
      expect(
        find.descendant(
          of: turn,
          matching: find.text('Authentication Required'),
        ),
        findsNothing,
        reason: '只有待认证的那一轮才允许内嵌卡片',
      );
      expect(
        find.byKey(const Key('chat_status_awaiting_auth_badge')),
        findsNothing,
      );
    });

    testWidgets('草稿会话没有消息时，认证入口仍然只有底部那一张', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();
      final profile = AgentProfile(
        id: 'builtin-agy',
        serverId: 'srv-test-1',
        name: 'Antigravity AGY',
        description: 'ACP agent',
        cliCommand: 'agy',
        acpCommand: 'agy_acp_server.par',
        loginCommand: 'agy',
      );
      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          checkedAt: DateTime.now(),
        ),
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
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
            aiChatProvider.overrideWith(
              () => _MockAiChatNotifier(
                AiChatState(
                  sessions: const [],
                  activeAgentProfile: profile,
                  authChallenge: AuthChallenge(
                    agentId: 'builtin-agy',
                    methods: const [
                      AcpAuthMethod(id: 'browser_oauth', name: 'Browser Login'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Authentication Required'), findsOneWidget);
      expect(
        find.byKey(const Key('chat_status_awaiting_auth_badge')),
        findsNothing,
      );
    });

    for (final entry in [
      ('builtin-codex', 'codex', 'codex-acp', null),
      ('builtin-agy', 'agy', 'agy_acp_server.par', 'agy'),
    ]) {
      testWidgets(
        'renders single method and responds without CLI login for ${entry.$1}',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final local = await LocalStorageService.init();

          final profile = AgentProfile(
            id: entry.$1,
            serverId: 'srv-test-1',
            name: 'OpenAI Codex',
            description: 'ACP agent',
            cliCommand: entry.$2,
            acpCommand: entry.$3,
            loginCommand: entry.$4,
          );

          final runtime = AgentRuntimeState(
            profile: profile,
            status: AgentEnvironmentStatus(
              kind: AgentEnvironmentStatusKind.ready,
              checkedAt: DateTime.now(),
            ),
          );

          final chatNotifier = _MockAiChatNotifier(
            AiChatState(
              sessions: const [],
              activeAgentProfile: profile,
              authChallenge: AuthChallenge(
                agentId: entry.$1,
                methods: const [
                  AcpAuthMethod(
                    id: 'browser_oauth',
                    name: 'Browser Login',
                    description: 'Open browser to authenticate',
                  ),
                ],
              ),
            ),
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
                agentRegistryProvider.overrideWith(
                  () => _MockAgentRegistryNotifier(
                    AgentRegistryState(
                      serverId: 'srv-test-1',
                      agents: [runtime],
                    ),
                  ),
                ),
                aiChatProvider.overrideWith(() => chatNotifier),
              ],
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Authentication Required'), findsOneWidget);
          expect(find.text('Authentication Method'), findsOneWidget);
          expect(find.text('Browser Login'), findsOneWidget);
          expect(find.text('Open browser to authenticate'), findsOneWidget);

          // Tap Log In button
          await tester.ensureVisible(find.text('Log In'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Log In'));
          await tester.pumpAndSettle();

          expect(chatNotifier.respondedMethodId, 'browser_oauth');
          expect(find.byType(AlertDialog), findsNothing);
          expect(
            find.text('After logging in, send your message again.'),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets(
      'renders multiple methods with selection and cancel clears challenge',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final local = await LocalStorageService.init();

        final profile = AgentProfile(
          id: 'builtin-codex',
          serverId: 'srv-test-1',
          name: 'OpenAI Codex',
          description: 'ACP agent',
          cliCommand: 'codex',
          acpCommand: 'codex-acp',
        );

        final runtime = AgentRuntimeState(
          profile: profile,
          status: AgentEnvironmentStatus(
            kind: AgentEnvironmentStatusKind.ready,
            checkedAt: DateTime.now(),
          ),
        );

        final chatNotifier = _MockAiChatNotifier(
          AiChatState(
            sessions: const [],
            activeAgentProfile: profile,
            authChallenge: const AuthChallenge(
              agentId: 'builtin-codex',
              methods: [
                AcpAuthMethod(id: 'oauth', name: 'OAuth 2.0'),
                AcpAuthMethod(id: 'api_key', name: 'API Key'),
              ],
            ),
          ),
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
              agentRegistryProvider.overrideWith(
                () => _MockAgentRegistryNotifier(
                  AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
                ),
              ),
              aiChatProvider.overrideWith(() => chatNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Authentication Required'), findsOneWidget);
        expect(find.text('OAuth 2.0'), findsOneWidget);
        expect(find.text('API Key'), findsOneWidget);

        // Tap cancel
        await tester.ensureVisible(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(chatNotifier.respondedMethodId, isNull);
        expect(chatNotifier.respondAuthCalled, isTrue);
      },
    );

    testWidgets('disables proceed button when SSH is disconnected', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final profile = AgentProfile(
        id: 'builtin-codex',
        serverId: 'srv-test-1',
        name: 'OpenAI Codex',
        description: 'ACP agent',
        cliCommand: 'codex',
        acpCommand: 'codex-acp',
      );

      final runtime = AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus(
          kind: AgentEnvironmentStatusKind.ready,
          checkedAt: DateTime.now(),
        ),
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
                  status: ConnectionStateEnum.disconnected,
                ),
              ),
            ),
            agentRegistryProvider.overrideWith(
              () => _MockAgentRegistryNotifier(
                AgentRegistryState(serverId: 'srv-test-1', agents: [runtime]),
              ),
            ),
            aiChatProvider.overrideWith(
              () => _MockAiChatNotifier(
                AiChatState(
                  sessions: const [],
                  activeAgentProfile: profile,
                  authChallenge: const AuthChallenge(
                    agentId: 'builtin-codex',
                    methods: [AcpAuthMethod(id: 'm1', name: 'Method 1')],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final filledButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Log In'),
      );
      expect(filledButton.onPressed, isNull);
    });
  });
}

class _MockAgentRegistryNotifier extends AgentRegistryNotifier {
  final AgentRegistryState _initialState;
  _MockAgentRegistryNotifier(this._initialState);

  @override
  AgentRegistryState build() => _initialState;
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
  String? respondedMethodId;
  bool respondAuthCalled = false;

  _MockAiChatNotifier(this._initialState);

  @override
  AiChatState build() => _initialState;

  @override
  Future<void> respondAuth(String? methodId) async {
    respondAuthCalled = true;
    respondedMethodId = methodId;
    if (methodId == null) return;
    state = state.copyWith(isAuthenticating: true);
    state = state.copyWith(
      isAuthenticating: false,
      authenticationConfirmed: true,
      clearAuthChallenge: true,
    );
  }
}
