import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart'
    show AcpAuthMethod;
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart';

class _FailureActionsNotifier extends FakeAcpChatNotifier {
  _FailureActionsNotifier(super.initialState);

  final searches = <String>[];
  final selections = <String>[];
  int olderLoads = 0;
  int reconnects = 0;

  void showFailure(String code) => state = state.copyWith(lastErrorCode: code);

  ChatMessage get currentMessage => state.activeSession!.messages.single;

  void updateAuth({
    bool? isLoadingSettings,
    String? authError,
    AuthChallenge? challenge,
  }) {
    state = state.copyWith(
      isLoadingSettings: isLoadingSettings,
      authError: authError,
      authChallenge: challenge,
    );
  }

  @override
  Future<void> searchSessions(String query) async => searches.add(query);

  @override
  Future<void> selectSession(String sessionId) async =>
      selections.add(sessionId);

  @override
  Future<void> loadOlderMessages() async => olderLoads++;

  @override
  Future<bool> reconnectCurrentAgent() async {
    reconnects++;
    return true;
  }
}

final _date = DateTime.utc(2026, 10, 15);

ChatSession _session({
  List<ChatMessage> messages = const [],
  int messageOffset = 0,
  String? agentId,
}) => ChatSession(
  id: 'failure-session',
  title: 'Failure session',
  serverId: harnessServerId,
  agentId: agentId ?? harnessAgent.id,
  participantAgentIds: [harnessAgent.id],
  createdAt: _date,
  updatedAt: _date,
  messageOffset: messageOffset,
  messages: messages,
);

AiChatState _state(ChatSession session, {String? error}) => AiChatState(
  sessions: [session],
  activeSessionId: session.id,
  activeAgentProfile: harnessAgent,
  readyAgents: [harnessAgent],
  shareAgentSessions: true,
  lastErrorCode: error,
);

Future<void> _pumpFailureView(
  WidgetTester tester,
  _FailureActionsNotifier notifier, {
  Size size = const Size(1200, 1000),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await pumpAcpHarness(
    tester,
    child: const AiChatView(),
    notifier: notifier,
    textScaler: textScaler,
  );
  await tester.pumpAndSettle();
}

Finder _retryLoad(WidgetTester tester) {
  final l10n = AppLocalizations.of(tester.element(find.byType(AiChatView)));
  return find.text(l10n.chatFailureActionReloadHistory);
}

ChatMessage _awaitingAuthMessage() => ChatMessage(
  id: 'awaiting-auth',
  agentId: harnessAgent.id,
  role: MessageRole.assistant,
  content: '',
  status: ChatTurnStatus.awaitingAuthentication,
  createdAt: _date,
);

void main() {
  testWidgets('global history retry preserves the current search query', (
    tester,
  ) async {
    final notifier = _FailureActionsNotifier(_state(_session()));
    await _pumpFailureView(tester, notifier);
    await tester.enterText(
      find.byKey(const Key('chat_session_search_input')),
      'incident notes',
    );
    await tester.pumpAndSettle();
    expect(notifier.searches, ['incident notes']);
    notifier.searches.clear();
    notifier.showFailure('CHAT_HISTORY_LOAD_FAILED: fixture read failure');
    await tester.pumpAndSettle();

    final retry = _retryLoad(tester);
    expect(
      retry,
      findsOneWidget,
      reason: 'list errors are global, not messages',
    );
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(notifier.searches, ['incident notes']);
    expect(notifier.selections, isEmpty);
    expect(notifier.olderLoads, 0);
    expect(notifier.sendMessageCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('global initial-message retry selects the same empty session', (
    tester,
  ) async {
    final session = _session();
    final notifier = _FailureActionsNotifier(
      _state(session, error: 'CHAT_MESSAGES_LOAD_FAILED: fixture read failure'),
    );
    await _pumpFailureView(tester, notifier);

    final retry = _retryLoad(tester);
    expect(
      retry,
      findsOneWidget,
      reason: 'an empty session has no failure card',
    );
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(notifier.selections, [session.id]);
    expect(notifier.searches, isEmpty);
    expect(notifier.olderLoads, 0);
    expect(notifier.sendMessageCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('global older-message retry loads only the earlier page', (
    tester,
  ) async {
    final message = ChatMessage(
      id: 'existing-message',
      agentId: harnessAgent.id,
      role: MessageRole.assistant,
      content: 'Already loaded answer',
      createdAt: _date,
    );
    final notifier = _FailureActionsNotifier(
      _state(
        _session(messages: [message], messageOffset: 50),
        error: 'CHAT_MESSAGES_LOAD_FAILED: fixture page failure',
      ),
    );
    await _pumpFailureView(tester, notifier);

    final retry = _retryLoad(tester);
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(notifier.olderLoads, 1);
    expect(notifier.selections, isEmpty);
    expect(notifier.searches, isEmpty);
    expect(notifier.sendMessageCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'remote history failures expose details without a fake local retry',
    (tester) async {
      const codes = [
        'ACP_HISTORY_IMPORT_FAILED: fixture import failure',
        'ACP_HISTORY_IMPORT_INCOMPLETE',
      ];
      final notifier = _FailureActionsNotifier(
        _state(_session(), error: codes.first),
      );
      await _pumpFailureView(tester, notifier);
      final l10n = AppLocalizations.of(tester.element(find.byType(AiChatView)));

      for (final code in codes) {
        notifier.showFailure(code);
        await tester.pumpAndSettle();
        expect(_retryLoad(tester), findsNothing, reason: code);
        final details = find.byTooltip(l10n.chatFailureActionDetails);
        expect(details, findsOneWidget);
        await tester.tap(details);
        await tester.pumpAndSettle();
        expect(find.text(code), findsOneWidget);
        await tester.tap(details);
        await tester.pumpAndSettle();
      }

      expect(notifier.searches, isEmpty);
      expect(notifier.selections, isEmpty);
      expect(notifier.olderLoads, 0);
      expect(notifier.sendMessageCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('exhausted local history exposes details without a no-op retry', (
    tester,
  ) async {
    final message = ChatMessage(
      id: 'all-history-loaded',
      agentId: harnessAgent.id,
      role: MessageRole.assistant,
      content: 'All local history is already loaded',
      createdAt: _date,
    );
    const code = 'CHAT_MESSAGES_LOAD_FAILED: fixture page failure';
    final notifier = _FailureActionsNotifier(
      _state(_session(messages: [message], messageOffset: 0), error: code),
    );
    await _pumpFailureView(tester, notifier);

    expect(_retryLoad(tester), findsNothing);
    final l10n = AppLocalizations.of(tester.element(find.byType(AiChatView)));
    final details = find.byTooltip(l10n.chatFailureActionDetails);
    expect(details, findsOneWidget);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.text(code), findsOneWidget);
    expect(notifier.currentMessage, same(message));
    expect(notifier.searches, isEmpty);
    expect(notifier.selections, isEmpty);
    expect(notifier.olderLoads, 0);
    expect(notifier.sendMessageCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'legacy failure without an Agent ID cannot reconnect another Agent',
    (tester) async {
      final legacy = ChatMessage(
        id: 'legacy-failure',
        role: MessageRole.assistant,
        content: '',
        status: ChatTurnStatus.failed,
        failureCode: 'ACP_TRANSPORT_FAILURE: connection reset',
        createdAt: _date,
      );
      final notifier = _FailureActionsNotifier(
        _state(_session(messages: [legacy], agentId: 'previous-agent')),
      );
      await _pumpFailureView(tester, notifier);

      final action = find.byKey(
        const Key('chat_failure_action_legacy-failure'),
      );
      // A faulty UI must not be able to operate the active Agent through this
      // historical message. The spy keeps that attempted action entirely local.
      if (action.evaluate().isNotEmpty) {
        await tester.tap(action);
        await tester.pumpAndSettle();
      }
      expect(
        notifier.reconnects,
        0,
        reason: 'the failed Agent is not identifiable',
      );
      expect(action, findsNothing);
      final details = find.byKey(
        const Key('chat_failure_details_toggle_legacy-failure'),
      );
      expect(details, findsOneWidget);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text(legacy.failureCode!), findsOneWidget);
      expect(notifier.sendMessageCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'error card fits 320dp at 2x text with 44dp action details and copy targets',
    (tester) async {
      final message = ChatMessage(
        id: 'narrow-failure',
        agentId: harnessAgent.id,
        role: MessageRole.assistant,
        content: '',
        status: ChatTurnStatus.failed,
        failureCode: 'ACP_TRANSPORT_FAILURE: SocketException connection reset',
        createdAt: _date,
      );
      final notifier = _FailureActionsNotifier(
        _state(_session(messages: [message])),
      );
      await _pumpFailureView(
        tester,
        notifier,
        size: const Size(320, 900),
        textScaler: const TextScaler.linear(2),
      );
      final action = find.byKey(
        const Key('chat_failure_action_narrow-failure'),
      );
      final details = find.byKey(
        const Key('chat_failure_details_toggle_narrow-failure'),
      );
      expect(action, findsOneWidget);
      expect(details, findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'collapsed card must fit');
      await tester.ensureVisible(details);
      await tester.pump();
      await tester.tap(details);
      await tester.pump(const Duration(milliseconds: 100));

      final copy = find.byKey(const Key('chat_failure_copy_narrow-failure'));
      expect(copy, findsOneWidget);
      await tester.ensureVisible(copy);
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'expanded details must fit',
      );
      for (final target in [action, details, copy]) {
        final size = tester.getSize(target);
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }

      await tester.ensureVisible(action);
      await tester.pump();
      await tester.tap(action);
      await tester.pump(const Duration(milliseconds: 100));
      expect(notifier.reconnects, 1);
      expect(notifier.sendMessageCalls, 0);
      expect(notifier.currentMessage, same(message));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'auth subscription updates discovery loading without a new message',
    (tester) async {
      final message = _awaitingAuthMessage();
      final notifier = _FailureActionsNotifier(
        _state(_session(messages: [message])),
      );
      await _pumpFailureView(tester, notifier);
      final button = find.byKey(const Key('chat_retry_auth_discovery_button'));
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

      notifier.updateAuth(isLoadingSettings: true);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));

      expect(notifier.currentMessage, same(message));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(
        find.descendant(
          of: button,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(notifier.sendMessageCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'auth subscription updates discovery error without a new message',
    (tester) async {
      final message = _awaitingAuthMessage();
      final notifier = _FailureActionsNotifier(
        _state(_session(messages: [message])),
      );
      await _pumpFailureView(tester, notifier);
      final l10n = AppLocalizations.of(tester.element(find.byType(AiChatView)));
      expect(find.text(l10n.chatAuthConnectionExpired), findsNothing);

      notifier.updateAuth(authError: 'ACP_AUTH_CONNECTION_EXPIRED');
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));

      expect(notifier.currentMessage, same(message));
      expect(find.text(l10n.chatAuthConnectionExpired), findsOneWidget);
      expect(notifier.sendMessageCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'auth subscription updates challenge methods without a new message',
    (tester) async {
      final message = _awaitingAuthMessage();
      final notifier = _FailureActionsNotifier(
        _state(_session(messages: [message])).copyWith(
          authChallenge: AuthChallenge(
            serverId: harnessServerId,
            agentId: harnessAgent.id,
            methods: const [
              AcpAuthMethod(id: 'old-method', name: 'Old method'),
            ],
          ),
        ),
      );
      await _pumpFailureView(tester, notifier);
      expect(find.text('Old method'), findsOneWidget);

      notifier.updateAuth(
        challenge: AuthChallenge(
          serverId: harnessServerId,
          agentId: harnessAgent.id,
          methods: const [
            AcpAuthMethod(id: 'new-method', name: 'Replacement method'),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));

      expect(notifier.currentMessage, same(message));
      expect(find.text('Replacement method'), findsOneWidget);
      expect(find.text('Old method'), findsNothing);
      expect(notifier.sendMessageCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
