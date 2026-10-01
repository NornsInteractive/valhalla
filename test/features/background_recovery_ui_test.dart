import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/core/providers/agent_registry_provider.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/features/chat/widgets/session_recovery_banner.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart';
import '../support/temp_chat_db.dart';

/// Background recovery widget regression: what the user can see and do while a
/// turn is being recovered.
///
/// No SSH, no agent, no network: the chat notifier and the connection state are
/// in-memory fakes, and the assertions are on the rendered widget tree (keys,
/// enabled/disabled state, invoked callbacks) rather than on source text.

const _reconnectingBanner = Key('sessionRecoveryReconnectingBanner');
const _syncingBanner = Key('sessionRecoverySyncingBanner');
const _incompleteBanner = Key('sessionRecoveryIncompleteBanner');
const _failedBanner = Key('sessionRecoveryFailedBanner');
const _offlineBanner = Key('sessionRecoveryOfflineBanner');
const _retryButton = Key('sessionRecoveryRetryButton');
const _recoveryBannerSlot = Key('aiChatSessionRecoveryBanner');
const _promptInput = Key('chatPromptInput');
const _sendButton = Key('sendMessageButton');

/// Connection state the test can move between connected/connecting/offline.
class FakeConnectionNotifier extends ServerConnectionNotifier {
  FakeConnectionNotifier(this._initial);

  ServerConnectionState _initial;

  @override
  ServerConnectionState build() => _initial;

  void set(ConnectionStateEnum status) {
    _initial = _initial.copyWith(status: status);
    state = _initial;
  }
}

class RecoveryChatNotifier extends FakeAcpChatNotifier {
  RecoveryChatNotifier(super.initialState);

  int recoverConnectionCalls = 0;

  void emit(AiChatState next) => state = next;

  @override
  Future<void> recoverConnection() async {
    recoverConnectionCalls++;
  }
}

ChatMessage _message(
  String id,
  String content, {
  MessageRole role = MessageRole.assistant,
}) => ChatMessage(
  id: id,
  role: role,
  content: content,
  agentId: harnessAgent.id,
  createdAt: DateTime.utc(2026, 9, 30, 10),
);

ChatSession _session(String id, {List<ChatMessage> messages = const []}) =>
    ChatSession(
      id: id,
      title: 'Session $id',
      serverId: harnessServerId,
      agentId: harnessAgent.id,
      createdAt: DateTime.utc(2026, 9, 30, 9),
      updatedAt: DateTime.utc(2026, 9, 30, 10),
      messages: messages,
    );

/// Minimal host for the banner alone: theme + l10n + connection state.
Widget _bannerHost(
  SessionRecoveryStatus status,
  ConnectionStateEnum conn, {
  VoidCallback? onRetry,
}) => ProviderScope(
  overrides: [
    serverConnectionProvider.overrideWith(
      () => FakeConnectionNotifier(ServerConnectionState(status: conn)),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.buildTheme(
      brightness: Brightness.dark,
      seedColor: AppAccentColor.cyberEmerald.color,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SessionRecoveryBanner(status: status, onRetry: onRetry ?? () {}),
    ),
  ),
);

/// The real chat view under a connection state the test drives.
///
/// Same in-memory doubles as [pumpAcpHarness] (temp chat DB, fake active
/// server, fake agent registry, fake chat notifier, production theme + fonts);
/// the only difference is the connection notifier, because Riverpod rejects
/// overriding the same provider twice in one container, so a second override
/// cannot be layered on top of the shared harness.
Future<void> pumpChatView(
  WidgetTester tester, {
  required RecoveryChatNotifier notifier,
  required FakeConnectionNotifier connection,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await LocalStorageService.init();
  await loadRealTextFonts();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tempChatRepositoryOverride(),
        localStorageServiceProvider.overrideWithValue(storage),
        activeServerProvider.overrideWith(HarnessActiveServerNotifier.new),
        serverConnectionProvider.overrideWith(() => connection),
        agentRegistryProvider.overrideWith(HarnessAgentRegistryNotifier.new),
        aiChatProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp(
        theme: AppTheme.buildTheme(
          brightness: Brightness.dark,
          seedColor: AppAccentColor.cyberEmerald.color,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AiChatView(),
      ),
    ),
  );
}

/// A `CircularProgressIndicator` ticks forever, so a banner that shows one can
/// never be settled. Two frames are enough for the tree to be up to date.
Future<void> pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('SessionRecoveryBanner - recovery state contract', () {
    testWidgets('idle renders nothing at all', (tester) async {
      await tester.pumpWidget(
        _bannerHost(SessionRecoveryStatus.idle, ConnectionStateEnum.connected),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SessionRecoveryBanner), findsOneWidget);
      expect(find.byKey(_offlineBanner), findsNothing);
      expect(find.byKey(_reconnectingBanner), findsNothing);
      expect(find.byKey(_syncingBanner), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('incomplete offers a working retry action', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _bannerHost(
          SessionRecoveryStatus.incomplete,
          ConnectionStateEnum.connected,
          onRetry: () => retries++,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_incompleteBanner), findsOneWidget);
      final retry = tester.widget<TextButton>(find.byKey(_retryButton));
      expect(retry.onPressed, isNotNull, reason: 'retry must be actionable');

      await tester.tap(find.byKey(_retryButton));
      await tester.pumpAndSettle();
      expect(retries, 1, reason: 'one tap triggers exactly one recovery');
    });

    testWidgets('failed offers a working retry action', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _bannerHost(
          SessionRecoveryStatus.failed,
          ConnectionStateEnum.connected,
          onRetry: () => retries++,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_failedBanner), findsOneWidget);
      expect(
        tester.widget<TextButton>(find.byKey(_retryButton)).onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(_retryButton));
      await tester.pumpAndSettle();
      expect(retries, 1);
    });

    testWidgets(
      'reconnecting is suppressed while the connection banner is up',
      (tester) async {
        await tester.pumpWidget(
          _bannerHost(
            SessionRecoveryStatus.reconnecting,
            ConnectionStateEnum.connecting,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(_reconnectingBanner),
          findsNothing,
          reason: 'the global connection banner already says reconnecting',
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets('reconnecting is shown when the connection banner is absent', (
      tester,
    ) async {
      // Control for the case above: suppression must be conditioned on the
      // active connection banner, not unconditional.
      await tester.pumpWidget(
        _bannerHost(
          SessionRecoveryStatus.reconnecting,
          ConnectionStateEnum.connected,
        ),
      );
      await pumpFrames(tester);

      expect(find.byKey(_reconnectingBanner), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_reconnectingBanner),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'a manual disconnect shows offline instead of an endless spinner',
      (tester) async {
        await tester.pumpWidget(
          _bannerHost(
            SessionRecoveryStatus.reconnecting,
            ConnectionStateEnum.disconnected,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(_offlineBanner), findsOneWidget);
        expect(find.byKey(_reconnectingBanner), findsNothing);
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason:
              'a user-initiated disconnect must not keep promising to retry',
        );
        expect(
          find.byKey(_retryButton),
          findsNothing,
          reason: 'offline is a state, not a failure to retry',
        );
      },
    );

    testWidgets(
      'syncing stays visible even while the connection is reconnecting',
      (tester) async {
        await tester.pumpWidget(
          _bannerHost(
            SessionRecoveryStatus.syncing,
            ConnectionStateEnum.connecting,
          ),
        );
        await pumpFrames(tester);

        expect(
          find.byKey(_syncingBanner),
          findsOneWidget,
          reason: 'only reconnecting is suppressed, not syncing',
        );
        expect(
          find.descendant(
            of: find.byKey(_syncingBanner),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('AiChatView - conversation survives recovery', () {
    /// Pumps the real chat view with a two-message conversation and a
    /// connection the test can move.
    Future<(RecoveryChatNotifier, FakeConnectionNotifier)> pumpChat(
      WidgetTester tester, {
      required AiChatState initial,
      ConnectionStateEnum conn = ConnectionStateEnum.connected,
    }) async {
      final notifier = RecoveryChatNotifier(initial);
      final connection = FakeConnectionNotifier(
        ServerConnectionState(status: conn),
      );
      await pumpChatView(tester, notifier: notifier, connection: connection);
      return (notifier, connection);
    }

    AiChatState baseState(SessionRecoveryStatus recovery) => AiChatState(
      recoveryStatus: recovery,
      sessions: [
        _session(
          'sess-1',
          messages: [
            _message('m1', 'deploy the nightly build', role: MessageRole.user),
            _message('m2', 'the nightly build is green'),
          ],
        ),
      ],
      activeSessionId: 'sess-1',
      activeAgentProfile: harnessAgent,
      readyAgents: [harnessAgent],
    );

    testWidgets('messages stay on screen through reconnect and sync', (
      tester,
    ) async {
      final (notifier, _) = await pumpChat(
        tester,
        initial: baseState(SessionRecoveryStatus.idle),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('user_msg_m1')), findsOneWidget);
      expect(find.byKey(const ValueKey('assistant_msg_m2')), findsOneWidget);

      notifier.emit(baseState(SessionRecoveryStatus.reconnecting));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(const ValueKey('user_msg_m1')),
        findsOneWidget,
        reason: 'recovering must never blank the visible conversation',
      );
      expect(find.byKey(const ValueKey('assistant_msg_m2')), findsOneWidget);
      expect(find.text('the nightly build is green'), findsOneWidget);
      expect(find.byKey(_reconnectingBanner), findsOneWidget);

      notifier.emit(baseState(SessionRecoveryStatus.syncing));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const ValueKey('user_msg_m1')), findsOneWidget);
      expect(find.byKey(const ValueKey('assistant_msg_m2')), findsOneWidget);
      expect(find.text('the nightly build is green'), findsOneWidget);
      expect(find.byKey(_syncingBanner), findsOneWidget);
    });

    testWidgets('recovery while the connection banner is up stays quiet', (
      tester,
    ) async {
      final (notifier, connection) = await pumpChat(
        tester,
        initial: baseState(SessionRecoveryStatus.idle),
      );
      await tester.pumpAndSettle();

      notifier.emit(baseState(SessionRecoveryStatus.reconnecting));
      connection.set(ConnectionStateEnum.connecting);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(_recoveryBannerSlot), findsOneWidget);
      expect(
        find.byKey(_reconnectingBanner),
        findsNothing,
        reason:
            'no duplicate reconnecting notice next to the connection banner',
      );
      expect(
        find.byKey(const ValueKey('assistant_msg_m2')),
        findsOneWidget,
        reason: 'the conversation is still readable while reconnecting',
      );
    });

    testWidgets(
      'a manual disconnect shows offline and keeps the conversation',
      (tester) async {
        final (notifier, connection) = await pumpChat(
          tester,
          initial: baseState(SessionRecoveryStatus.idle),
        );
        await tester.pumpAndSettle();

        notifier.emit(baseState(SessionRecoveryStatus.reconnecting));
        connection.set(ConnectionStateEnum.disconnected);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byKey(_offlineBanner), findsOneWidget);
        expect(find.byKey(_reconnectingBanner), findsNothing);
        expect(
          find.byKey(const ValueKey('assistant_msg_m2')),
          findsOneWidget,
          reason: 'going offline is not a reason to lose the transcript',
        );
      },
    );
  });

  group('AiChatView - draft stays usable while sending is disabled', () {
    testWidgets(
      'offline keeps the draft readable and editable, send disabled',
      (tester) async {
        final notifier = RecoveryChatNotifier(
          AiChatState(
            recoveryStatus: SessionRecoveryStatus.idle,
            sessions: [_session('sess-1')],
            activeSessionId: 'sess-1',
            activeAgentProfile: harnessAgent,
            readyAgents: [harnessAgent],
            draftText: 'half written question',
          ),
        );
        await pumpChatView(
          tester,
          notifier: notifier,
          connection: FakeConnectionNotifier(
            const ServerConnectionState(
              status: ConnectionStateEnum.disconnected,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final field = tester.widget<TextField>(find.byKey(_promptInput));
        expect(
          field.enabled,
          isTrue,
          reason: 'an offline server must not lock the composer',
        );
        expect(
          tester.widget<TextField>(find.byKey(_promptInput)).controller?.text,
          'half written question',
          reason: 'the draft the user already typed stays visible',
        );
        expect(
          tester.widget<IconButton>(find.byKey(_sendButton)).onPressed,
          isNull,
          reason: 'sending is what is disabled, not the draft',
        );

        await tester.enterText(
          find.byKey(_promptInput),
          'edited while offline',
        );
        await tester.pumpAndSettle();

        expect(
          notifier.draftTexts.last,
          'edited while offline',
          reason: 'the composer still reports edits while offline',
        );
        expect(
          tester.widget<TextField>(find.byKey(_promptInput)).enabled,
          isTrue,
        );
        expect(
          tester.widget<IconButton>(find.byKey(_sendButton)).onPressed,
          isNull,
        );
        expect(
          notifier.sendMessageCalls,
          0,
          reason: 'an offline composer must not silently send',
        );
      },
    );

    testWidgets('reconnecting the server re-enables sending', (tester) async {
      final connection = FakeConnectionNotifier(
        const ServerConnectionState(status: ConnectionStateEnum.disconnected),
      );
      final notifier = RecoveryChatNotifier(
        AiChatState(
          sessions: [_session('sess-1')],
          activeSessionId: 'sess-1',
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
          draftText: 'queued question',
        ),
      );
      await pumpChatView(tester, notifier: notifier, connection: connection);
      await tester.pumpAndSettle();

      expect(
        tester.widget<IconButton>(find.byKey(_sendButton)).onPressed,
        isNull,
      );

      connection.set(ConnectionStateEnum.connected);
      await tester.pumpAndSettle();

      expect(
        tester.widget<IconButton>(find.byKey(_sendButton)).onPressed,
        isNotNull,
        reason:
            'send follows the connection, proving the disable was offline-only',
      );
    });
  });

  group('AiChatView - recovery retry is wired to recovery', () {
    for (final status in [
      SessionRecoveryStatus.incomplete,
      SessionRecoveryStatus.failed,
    ]) {
      testWidgets('${status.name} exposes a retry that recovers', (
        tester,
      ) async {
        final notifier = RecoveryChatNotifier(
          AiChatState(
            recoveryStatus: status,
            sessions: [
              _session(
                'sess-1',
                messages: [_message('m1', 'kept while partial')],
              ),
            ],
            activeSessionId: 'sess-1',
            activeAgentProfile: harnessAgent,
            readyAgents: [harnessAgent],
          ),
        );
        await pumpChatView(
          tester,
          notifier: notifier,
          connection: FakeConnectionNotifier(
            const ServerConnectionState(status: ConnectionStateEnum.connected),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            status == SessionRecoveryStatus.incomplete
                ? _incompleteBanner
                : _failedBanner,
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextButton>(find.byKey(_retryButton)).onPressed,
          isNotNull,
        );

        await tester.tap(find.byKey(_retryButton));
        await tester.pumpAndSettle();

        expect(notifier.recoverConnectionCalls, 1);
        expect(
          find.byKey(const ValueKey('assistant_msg_m1')),
          findsOneWidget,
          reason: 'a partial recovery must not hide what was already received',
        );
      });
    }
  });
}
