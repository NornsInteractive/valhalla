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
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';

void main() {
  final testServer = ServerProfile(
    id: 'srv-test-1',
    name: 'Production Server US',
    host: '192.168.1.100',
    port: 22,
    username: 'admin',
    authType: AuthType.password,
  );

  final testAgent = AgentProfile(
    id: 'builtin-codex',
    serverId: 'srv-test-1',
    name: 'OpenAI Codex',
    description: 'ACP agent',
    cliCommand: 'codex',
    acpCommand: 'codex-acp',
  );

  final testAgentRuntime = AgentRuntimeState(
    profile: testAgent,
    status: AgentEnvironmentStatus(
      kind: AgentEnvironmentStatusKind.ready,
      checkedAt: DateTime.utc(2026),
    ),
  );

  Widget createTestApp({
    required Widget child,
    List<dynamic> overrides = const [],
    Locale locale = const Locale('en'),
  }) {
    return ProviderScope(
      overrides: [...overrides],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  group('AiChatView - Stop Generation Button', () {
    testWidgets('shows send button and no stop button when not generating', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final stoppedChatNotifier = _MockAiChatNotifier(
        AiChatState(
          sessions: [
            ChatSession(
              id: 'sess-1',
              title: 'Session 1',
              serverId: 'srv-test-1',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
          activeSessionId: 'sess-1',
          activeAgentProfile: testAgent,
          readyAgents: [testAgent],
          isGenerating: false,
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
                  agents: [testAgentRuntime],
                ),
              ),
            ),
            aiChatProvider.overrideWith(() => stoppedChatNotifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sendMessageButton')), findsOneWidget);
      expect(find.byKey(const Key('stopGenerationButton')), findsNothing);
    });

    testWidgets(
      'shows stop button and clicking invokes stopGeneration when isGenerating',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final local = await LocalStorageService.init();

        final generatingChatNotifier = _MockAiChatNotifier(
          AiChatState(
            sessions: [
              ChatSession(
                id: 'sess-1',
                title: 'Session 1',
                serverId: 'srv-test-1',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ],
            activeSessionId: 'sess-1',
            activeAgentProfile: testAgent,
            readyAgents: [testAgent],
            isGenerating: true,
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
                    agents: [testAgentRuntime],
                  ),
                ),
              ),
              aiChatProvider.overrideWith(() => generatingChatNotifier),
            ],
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('sendMessageButton')), findsNothing);
        expect(find.byKey(const Key('stopGenerationButton')), findsOneWidget);

        // Tap stop button
        await tester.tap(find.byKey(const Key('stopGenerationButton')));
        await tester.pump();

        expect(generatingChatNotifier.stopGenerationCalled, isTrue);
      },
    );
  });

  group('AiChatView - Session Management & Isolation', () {
    testWidgets(
      'confirm dialog appears before deleting session (even the last one) and invokes deleteSession on confirm',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        SharedPreferences.setMockInitialValues({});
        final local = await LocalStorageService.init();

        final singleSession = ChatSession(
          id: 'sess-single',
          title: 'Single Last Session',
          serverId: 'srv-test-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final chatNotifier = _MockAiChatNotifier(
          AiChatState(
            sessions: [singleSession],
            activeSessionId: 'sess-single',
            activeAgentProfile: testAgent,
            readyAgents: [testAgent],
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
                    agents: [testAgentRuntime],
                  ),
                ),
              ),
              aiChatProvider.overrideWith(() => chatNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Delete button is rendered even when it is the only session
        final deleteBtn = find.byKey(const Key('delete_session_sess-single'));
        expect(deleteBtn, findsOneWidget);

        // Tap delete -> shows confirmation dialog
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('confirmDeleteSessionButton')),
          findsOneWidget,
        );

        // Cancel does not delete
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(chatNotifier.deleteSessionCalled, isFalse);

        // Tap delete again and confirm
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('confirmDeleteSessionButton')));
        await tester.pumpAndSettle();

        expect(chatNotifier.deleteSessionCalled, isTrue);
        expect(chatNotifier.deletedSessionId, equals('sess-single'));
      },
    );

    testWidgets('shareAgentSessions toggle can be switched', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final local = await LocalStorageService.init();

      final chatNotifier = _MockAiChatNotifier(
        AiChatState(
          sessions: [],
          activeSessionId: null,
          activeAgentProfile: testAgent,
          readyAgents: [testAgent],
          shareAgentSessions: false,
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
                  agents: [testAgentRuntime],
                ),
              ),
            ),
            aiChatProvider.overrideWith(() => chatNotifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final headerShareBtn = find.byKey(const Key('shareSessionsHeaderButton'));
      expect(headerShareBtn, findsOneWidget);

      await tester.tap(headerShareBtn);
      await tester.pumpAndSettle();

      expect(chatNotifier.setShareAgentSessionsCalled, isTrue);
      expect(chatNotifier.setShareAgentSessionsValue, isTrue);
    });

    testWidgets(
      '_handleSend preserves user prompt when send fails or is rejected',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final local = await LocalStorageService.init();

        final chatNotifier = _MockAiChatNotifier(
          AiChatState(
            sessions: [],
            activeSessionId: null,
            activeAgentProfile: testAgent,
            readyAgents: [testAgent],
            isGenerating: false,
          ),
        );
        // Simulate rejection when sendMessage is called
        chatNotifier.onSendMessage = () {
          chatNotifier.state = chatNotifier.state.copyWith(
            lastErrorCode: 'CHAT_SESSION_IDENTITY_MISMATCH',
            isGenerating: false,
          );
        };

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
                    agents: [testAgentRuntime],
                  ),
                ),
              ),
              aiChatProvider.overrideWith(() => chatNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final promptInput = find.byKey(const Key('chatPromptInput'));
        expect(promptInput, findsOneWidget);

        await tester.enterText(promptInput, 'Important unlost prompt');
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('sendMessageButton')));
        await tester.pumpAndSettle();

        expect(chatNotifier.sendMessageCalled, isTrue);
        // Prompt input must still have the text!
        expect(find.text('Important unlost prompt'), findsOneWidget);
      },
    );
  });

  group('AiChatView - Session Identity Mismatch Prompt', () {
    testWidgets(
      'renders friendly message for CHAT_SESSION_IDENTITY_MISMATCH in English and Chinese',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final local = await LocalStorageService.init();

        final mismatchSession = ChatSession(
          id: 'sess-other',
          title: 'Other Server Session',
          serverId: 'srv-other-99',
          agentId: 'builtin-other',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // English test
        final chatNotifierEn = _MockAiChatNotifier(
          AiChatState(
            sessions: [mismatchSession],
            activeSessionId: 'sess-other',
            activeAgentProfile: testAgent,
            readyAgents: [testAgent],
            lastErrorCode: 'CHAT_SESSION_IDENTITY_MISMATCH',
          ),
        );

        await tester.pumpWidget(
          createTestApp(
            locale: const Locale('en'),
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
                    agents: [testAgentRuntime],
                  ),
                ),
              ),
              aiChatProvider.overrideWith(() => chatNotifierEn),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Current server or agent does not match this session\'s bound identity. Switch to the matching server and agent to continue.',
          ),
          findsOneWidget,
        );
        // Raw code should never be displayed
        expect(find.text('CHAT_SESSION_IDENTITY_MISMATCH'), findsNothing);

        // Chinese test
        final chatNotifierZh = _MockAiChatNotifier(
          AiChatState(
            sessions: [mismatchSession],
            activeSessionId: 'sess-other',
            activeAgentProfile: testAgent,
            readyAgents: [testAgent],
            lastErrorCode: 'CHAT_SESSION_IDENTITY_MISMATCH',
          ),
        );

        await tester.pumpWidget(
          createTestApp(
            locale: const Locale('zh'),
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
                    agents: [testAgentRuntime],
                  ),
                ),
              ),
              aiChatProvider.overrideWith(() => chatNotifierZh),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('当前服务器或 Agent 与此会话绑定的身份不匹配，请切换到匹配的服务器和 Agent 后继续。'),
          findsOneWidget,
        );
        expect(find.text('CHAT_SESSION_IDENTITY_MISMATCH'), findsNothing);
      },
    );
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
  bool stopGenerationCalled = false;
  bool bindActiveSessionCalled = false;
  bool deleteSessionCalled = false;
  String? deletedSessionId;
  bool setShareAgentSessionsCalled = false;
  bool? setShareAgentSessionsValue;
  bool sendMessageCalled = false;
  VoidCallback? onSendMessage;

  _MockAiChatNotifier(this._initialState);

  @override
  AiChatState build() => _initialState;

  @override
  Future<void> stopGeneration() async {
    stopGenerationCalled = true;
  }

  String? lastExpectedSessionId;
  String? lastExpectedServerId;

  @override
  Future<void> bindActiveSessionToCurrentServer({
    String? expectedSessionId,
    String? expectedServerId,
  }) async {
    bindActiveSessionCalled = true;
    lastExpectedSessionId = expectedSessionId;
    lastExpectedServerId = expectedServerId;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    deleteSessionCalled = true;
    deletedSessionId = sessionId;
  }

  @override
  Future<void> setShareAgentSessions(bool enabled) async {
    setShareAgentSessionsCalled = true;
    setShareAgentSessionsValue = enabled;
  }

  @override
  Future<void> sendMessage(String text) async {
    sendMessageCalled = true;
    if (onSendMessage != null) {
      onSendMessage!();
    }
  }
}
