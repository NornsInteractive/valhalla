import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/infrastructure/acp/acp_runtime_service.dart';

import '../support/acp_chat_widget_harness.dart';

class _InteractionNotifier extends FakeAcpChatNotifier {
  _InteractionNotifier(super.initialState)
    : super(refreshResult: true, refreshError: null);

  int inspectRuntimeCalls = 0;
  int deleteSessionCalls = 0;
  int returnToRunningSessionCalls = 0;
  String? deletedSessionId;
  bool? deletedStopAndClearRemote;
  String? deletedExpectedServerKey;
  Object? inspectError;
  List<AcpRuntimeStatus> inspectStatuses = const [];
  Object? deleteError;
  VoidCallback? onSendMessage;

  void emit(AiChatState next) => state = next;

  @override
  Future<void> sendMessage(String text) async {
    sendMessageCalls++;
    onSendMessage?.call();
  }

  @override
  Future<List<AcpRuntimeStatus>> inspectSessionRuntimes(
    String sessionId,
  ) async {
    inspectRuntimeCalls++;
    final error = inspectError;
    if (error != null) throw error;
    return inspectStatuses;
  }

  @override
  Future<void> deleteSession(
    String sessionId, {
    bool stopAndClearRemote = false,
    String? expectedServerKey,
  }) async {
    deleteSessionCalls++;
    deletedSessionId = sessionId;
    deletedStopAndClearRemote = stopAndClearRemote;
    deletedExpectedServerKey = expectedServerKey;
    final error = deleteError;
    if (error != null) throw error;
  }

  @override
  Future<void> returnToRunningSession() async {
    returnToRunningSessionCalls++;
  }
}

ChatSession _session({
  required String id,
  required String title,
  List<ChatMessage> messages = const [],
  Map<String, AgentChatContext> agentContexts = const {},
}) => ChatSession(
  id: id,
  title: title,
  serverId: harnessServerId,
  agentId: harnessAgent.id,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  messages: messages,
  agentContexts: agentContexts,
);

ChatMessage _message({
  required String id,
  required MessageRole role,
  required String content,
}) => ChatMessage(
  id: id,
  role: role,
  content: content,
  status: ChatTurnStatus.completed,
  createdAt: DateTime.now(),
);

void _useSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _openDeleteDialog(WidgetTester tester, String sessionId) async {
  await tester.tap(find.byKey(Key('session_more_menu_$sessionId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('delete_session_$sessionId')));
  await tester.pumpAndSettle();
}

RadioGroup<bool> _deleteRadioGroup(WidgetTester tester) =>
    tester.widget<RadioGroup<bool>>(
      find.byWidgetPredicate((widget) => widget is RadioGroup<bool>),
    );

String _promptText(WidgetTester tester) {
  final editable = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(const Key('chatPromptInput')),
      matching: find.byType(EditableText),
    ),
  );
  return editable.controller.text;
}

void main() {
  group('ACP pending permission presentation', () {
    testWidgets(
      'long permission at 320px and textScale 2 keeps a compact summary and opens bounded details with copy and fixed actions',
      (tester) async {
        _useSurface(tester, const Size(320, 640));

        String? clipboardText;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );

        final longDescription = List.generate(
          24,
          (index) =>
              'The agent needs to inspect protected deployment data segment $index before continuing.',
        ).join(' ');
        final longCommand =
            'sudo /usr/local/bin/deploy-tool --inspect ${List.generate(30, (i) => 'segment-$i').join(' ')}';

        final request = PermissionRequest(
          id: 'perm-long-content',
          toolName: 'Deployment Inspector',
          command: longCommand,
          description: longDescription,
          isDangerous: true,
          options: const [
            ChatPermissionOption(
              id: 'allow_once',
              name: 'Allow once',
              kind: 'allow_once',
            ),
            ChatPermissionOption(
              id: 'allow_session',
              name: 'Allow for session',
              kind: 'allow_session',
            ),
            ChatPermissionOption(
              id: 'reject_once',
              name: 'Reject',
              kind: 'reject_once',
            ),
          ],
        );
        final completer = Completer<String?>();
        final session = _session(
          id: 'sess-permission',
          title: 'Permission',
          messages: [
            _message(
              id: 'perm-msg',
              role: MessageRole.assistant,
              content: 'Waiting for permission.',
            ),
          ],
        );
        final notifier = _InteractionNotifier(
          AiChatState(
            sessions: [session],
            activeSessionId: session.id,
            activeAgentProfile: harnessAgent,
            readyAgents: [harnessAgent],
            pendingPermission: request,
            permissionCompleter: completer,
          ),
        );

        await pumpAcpHarness(
          tester,
          child: const AiChatView(),
          notifier: notifier,
          textScaler: const TextScaler.linear(2),
        );
        await tester.pumpAndSettle();

        final summaryFinder = find.text(longDescription);
        expect(summaryFinder, findsOneWidget);
        final summary = tester.widget<Text>(summaryFinder);
        expect(summary.maxLines, 2);
        expect(summary.overflow, TextOverflow.ellipsis);
        expect(find.text(longCommand), findsNothing);

        final detailsButton = find.byKey(
          const Key('chat_permission_details_button'),
        );
        expect(detailsButton, findsOneWidget);
        await tester.ensureVisible(detailsButton);
        await tester.tap(detailsButton);
        await tester.pumpAndSettle();

        final boundedBox = find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedBox &&
              widget.constraints.maxWidth == 640 &&
              widget.constraints.maxHeight < double.infinity,
        );
        expect(boundedBox, findsOneWidget);
        final constraints = tester
            .widget<ConstrainedBox>(boundedBox)
            .constraints;
        expect(constraints.maxHeight, lessThanOrEqualTo(640 * 0.8));
        expect(find.byType(SingleChildScrollView), findsWidgets);

        expect(find.text(longDescription), findsWidgets);
        expect(find.text(longCommand), findsOneWidget);
        expect(find.text('Copy Command'), findsOneWidget);

        final fixedAction = find.byKey(
          const Key('chat_permission_option_detail_allow_once'),
        );
        expect(fixedAction, findsOneWidget);
        final actionRect = tester.getRect(fixedAction);
        expect(actionRect.bottom, lessThanOrEqualTo(640));

        final copyButton = find.ancestor(
          of: find.text('Copy Command'),
          matching: find.byWidgetPredicate((widget) => widget is TextButton),
        );
        expect(copyButton, findsOneWidget);
        await tester.ensureVisible(copyButton);
        await tester.pumpAndSettle();
        final copyRect = tester.getRect(copyButton);
        expect(
          copyRect.right,
          lessThanOrEqualTo(320),
          reason: 'Copy action must stay reachable at 320px and textScale 2',
        );
        expect(copyRect.bottom, lessThanOrEqualTo(640));

        await tester.tap(copyButton);
        await tester.pump();
        expect(find.text('Command copied to clipboard'), findsOneWidget);
        expect(clipboardText, longCommand);

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ACP running session overlay', () {
    testWidgets(
      'running-session indicator overlays without moving the transcript viewport or scroll position',
      (tester) async {
        _useSurface(tester, const Size(390, 844));

        final messages = List.generate(
          30,
          (index) => _message(
            id: 'run-msg-$index',
            role: index.isEven ? MessageRole.user : MessageRole.assistant,
            content: 'Transcript line $index',
          ),
        );
        final session = _session(
          id: 'sess-visible',
          title: 'Visible Session',
          messages: messages,
        );
        final notifier = _InteractionNotifier(
          AiChatState(
            sessions: [session],
            activeSessionId: session.id,
            activeAgentProfile: harnessAgent,
            readyAgents: [harnessAgent],
          ),
        );

        await pumpAcpHarness(
          tester,
          child: const AiChatView(),
          notifier: notifier,
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));

        final listFinder = find.byKey(
          const ValueKey('message_list_sess-visible'),
        );
        expect(listFinder, findsOneWidget);
        final beforeRect = tester.getRect(listFinder);
        final beforeController = tester
            .widget<ListView>(listFinder)
            .controller!;
        final beforeOffset = beforeController.offset;
        final beforeMaxExtent = beforeController.position.maxScrollExtent;

        notifier.emit(
          notifier.state.copyWith(
            serverRun: const AcpActiveRun(
              serverTargetKey: 'other-target',
              serverId: harnessServerId,
              sessionId: 'sess-background',
              agentId: 'agent-background',
              agentName: 'Background Agent',
              state: 'running',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));

        expect(
          find.byKey(const Key('acp_server_running_banner')),
          findsOneWidget,
        );
        final afterRect = tester.getRect(listFinder);
        final afterController = tester.widget<ListView>(listFinder).controller!;

        expect(afterRect, beforeRect);
        expect(afterController.offset, closeTo(beforeOffset, 0.01));
        expect(
          afterController.position.maxScrollExtent,
          closeTo(beforeMaxExtent, 0.01),
        );
        expect(notifier.returnToRunningSessionCalls, 0);
      },
    );
  });

  group('ACP session deletion safety', () {
    testWidgets(
      'delete defaults to local-only and a runtime inspection error leaves local deletion available',
      (tester) async {
        _useSurface(tester, const Size(1280, 800));

        final session = _session(
          id: 'sess-offline',
          title: 'Offline Managed Session',
          agentContexts: {
            harnessAgent.id: const AgentChatContext(
              persistentRuntimeKey: 'runtime-offline-1',
            ),
          },
        );
        final notifier = _InteractionNotifier(
          AiChatState(
            sessions: [session],
            activeSessionId: session.id,
            activeAgentProfile: harnessAgent,
            readyAgents: [harnessAgent],
          ),
        );
        notifier.inspectError = StateError('SSH_DISCONNECTED');

        await pumpAcpHarness(
          tester,
          child: const AiChatView(),
          notifier: notifier,
        );
        await tester.pumpAndSettle();

        await _openDeleteDialog(tester, session.id);

        expect(notifier.inspectRuntimeCalls, 1);
        expect(
          find.text('Server disconnected. Only local deletion is available.'),
          findsOneWidget,
        );
        expect(_deleteRadioGroup(tester).groupValue, isFalse);
        expect(
          tester
              .widget<RadioListTile<bool>>(
                find.byKey(const Key('delete_session_mode_local_only')),
              )
              .value,
          isFalse,
        );

        await tester.tap(find.byKey(const Key('confirmDeleteSessionButton')));
        await tester.pumpAndSettle();

        expect(notifier.deleteSessionCalls, 1);
        expect(notifier.deletedSessionId, session.id);
        expect(notifier.deletedStopAndClearRemote, isFalse);
        expect(
          notifier.deletedExpectedServerKey,
          harnessServer.connectionKey.toString(),
        );
        expect(
          find.byKey(const Key('confirmDeleteSessionButton')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'selected remote purge failure keeps the delete dialog open and reports the error',
      (tester) async {
        _useSurface(tester, const Size(1280, 800));

        final session = _session(
          id: 'sess-purge',
          title: 'Purge Managed Session',
          agentContexts: {
            harnessAgent.id: const AgentChatContext(
              persistentRuntimeKey: 'runtime-purge-1',
            ),
          },
        );
        final notifier = _InteractionNotifier(
          AiChatState(
            sessions: [session],
            activeSessionId: session.id,
            activeAgentProfile: harnessAgent,
            readyAgents: [harnessAgent],
          ),
        );
        notifier.inspectStatuses = const [
          AcpRuntimeStatus(
            runtimeKey: 'runtime-purge-1',
            state: 'running',
            alive: true,
            childAlive: true,
          ),
        ];
        notifier.deleteError = StateError('ACP_RUNTIME_PURGE_FAILED');

        await pumpAcpHarness(
          tester,
          child: const AiChatView(),
          notifier: notifier,
        );
        await tester.pumpAndSettle();

        await _openDeleteDialog(tester, session.id);
        expect(notifier.inspectRuntimeCalls, 1);
        expect(_deleteRadioGroup(tester).groupValue, isFalse);

        await tester.tap(
          find.byKey(const Key('delete_session_mode_purge_remote')),
        );
        await tester.pumpAndSettle();
        expect(_deleteRadioGroup(tester).groupValue, isTrue);

        await tester.tap(find.byKey(const Key('confirmDeleteSessionButton')));
        await tester.pumpAndSettle();

        expect(notifier.deleteSessionCalls, 1);
        expect(notifier.deletedStopAndClearRemote, isTrue);
        expect(
          notifier.deletedExpectedServerKey,
          harnessServer.connectionKey.toString(),
        );
        expect(
          find.byKey(const Key('confirmDeleteSessionButton')),
          findsOneWidget,
        );
        expect(find.textContaining('ACP_RUNTIME_PURGE_FAILED'), findsOneWidget);
        expect(_deleteRadioGroup(tester).groupValue, isTrue);
      },
    );
  });

  group('ACP server busy send rejection', () {
    testWidgets(
      'SERVER_BUSY rejection restores the typed draft instead of losing it',
      (tester) async {
        _useSurface(tester, const Size(390, 844));

        const draft = 'keep this deployment prompt';
        final session = _session(
          id: 'sess-draft',
          title: 'Draft Session',
          messages: [
            _message(
              id: 'draft-msg',
              role: MessageRole.assistant,
              content: 'Ready.',
            ),
          ],
        );
        final notifier = _InteractionNotifier(
          AiChatState(
            sessions: [session],
            activeSessionId: session.id,
            activeAgentProfile: harnessAgent,
            readyAgents: [harnessAgent],
          ),
        );
        notifier.onSendMessage = () {
          notifier.state = notifier.state.copyWith(
            lastErrorCode: 'ACP_RUNTIME_SERVER_BUSY',
            isGenerating: false,
          );
        };

        await pumpAcpHarness(
          tester,
          child: const AiChatView(),
          notifier: notifier,
        );
        await tester.pumpAndSettle();

        final prompt = find.byKey(const Key('chatPromptInput'));
        expect(prompt, findsOneWidget);
        await tester.enterText(prompt, draft);
        await tester.pumpAndSettle();
        expect(_promptText(tester), draft);

        await tester.tap(find.byKey(const Key('sendMessageButton')));
        await tester.pumpAndSettle();

        expect(notifier.sendMessageCalls, 1);
        expect(_promptText(tester), draft);
        expect(notifier.state.draftText, draft);
      },
    );
  });

  group('ACP unread badge while scrolled up', () {
    testWidgets(
      'prepend older messages does not show badge; append new tail message shows badge count 1; jump-to-latest clears badge and reaches bottom',
      (tester) async {
        _useSurface(tester, const Size(390, 844));

        final initialMessages = List.generate(
          30,
          (index) => _message(
            id: 'init-msg-$index',
            role: index.isEven ? MessageRole.user : MessageRole.assistant,
            content: 'Initial message $index',
          ),
        );
        final session = _session(
          id: 'sess-unread',
          title: 'Unread Test',
          messages: initialMessages,
        ).copyWith(messageOffset: 20, totalMessageCount: 50);
        final notifier = _InteractionNotifier(
          AiChatState(
            sessions: [session],
            activeSessionId: session.id,
            activeAgentProfile: harnessAgent,
            readyAgents: [harnessAgent],
          ),
        );

        await pumpAcpHarness(
          tester,
          child: const AiChatView(),
          notifier: notifier,
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));

        final listFinder = find.byKey(
          const ValueKey('message_list_sess-unread'),
        );
        expect(listFinder, findsOneWidget);
        final listView = tester.widget<ListView>(listFinder);
        final controller = listView.controller!;

        controller.jumpTo(controller.position.maxScrollExtent - 300);
        await tester.pumpAndSettle();
        expect(
          controller.offset,
          lessThan(controller.position.maxScrollExtent - 80),
        );

        final prependedMessages = List.generate(
          10,
          (index) => _message(
            id: 'prepended-msg-$index',
            role: index.isEven ? MessageRole.user : MessageRole.assistant,
            content: 'Prepended older $index',
          ),
        );
        final updatedSession = session.copyWith(
          messageOffset: 10,
          messages: [...prependedMessages, ...initialMessages],
        );
        expect(
          updatedSession.messageOffset + updatedSession.messages.length,
          session.messageOffset + session.messages.length,
        );
        notifier.emit(notifier.state.copyWith(sessions: [updatedSession]));
        await tester.pumpAndSettle();

        final scrollToLatestButton = find.byKey(
          const Key('chat_scroll_to_latest_button'),
        );
        expect(scrollToLatestButton, findsOneWidget);
        final fab = tester.widget<FloatingActionButton>(scrollToLatestButton);
        expect(fab.child, isA<Icon>());
        expect(fab.child, isNot(isA<Badge>()));

        final newTailMessage = _message(
          id: 'new-tail-msg',
          role: MessageRole.assistant,
          content: 'New tail message',
        );
        final sessionWithTail = updatedSession.copyWith(
          messages: [...updatedSession.messages, newTailMessage],
        );
        notifier.emit(notifier.state.copyWith(sessions: [sessionWithTail]));
        await tester.pumpAndSettle();

        tester.widget<FloatingActionButton>(scrollToLatestButton);
        expect(
          find.descendant(
            of: scrollToLatestButton,
            matching: find.byType(Badge),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: scrollToLatestButton, matching: find.text('1')),
          findsOneWidget,
        );

        await tester.tap(scrollToLatestButton);
        await tester.pumpAndSettle();

        expect(
          controller.offset,
          closeTo(controller.position.maxScrollExtent, 1.0),
        );
        expect(scrollToLatestButton, findsNothing);
        expect(find.byType(Badge), findsNothing);
      },
    );
  });

  group('ACP permission detail RTL with IME', () {
    testWidgets(
      'permission detail at 390dp Arabic RTL with IME viewInsets bottom 240 and textScale 1.3 shows bounded dialog with visible actions and reachable copy',
      (tester) async {
        const width = 390.0;
        const height = 844.0;
        const viewInsetBottom = 240.0;
        const textScale = 1.3;

        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = FakeViewPadding(bottom: viewInsetBottom);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.viewInsets = FakeViewPadding.zero;
        });

        String? clipboardText;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );

        final longDescription = List.generate(
          12,
          (index) =>
              'يحتاج الوكيل إلى فحص قطاع بيانات النشر المحمي $index قبل المتابعة.',
        ).join(' ');
        final longCommand =
            'sudo /usr/local/bin/deploy-tool --inspect ${List.generate(20, (i) => 'segment-$i').join(' ')}';

        final request = PermissionRequest(
          id: 'perm-rtl-ime',
          toolName: 'مفتش النشر',
          command: longCommand,
          description: longDescription,
          isDangerous: true,
          options: const [
            ChatPermissionOption(
              id: 'allow_once',
              name: 'السماح مرة واحدة',
              kind: 'allow_once',
            ),
            ChatPermissionOption(
              id: 'allow_session',
              name: 'السماح للجلسة',
              kind: 'allow_session',
            ),
            ChatPermissionOption(
              id: 'reject_once',
              name: 'رفض',
              kind: 'reject_once',
            ),
          ],
        );
        final completer = Completer<String?>();
        final session = _session(
          id: 'sess-permission-rtl',
          title: 'إذن RTL',
          messages: [
            _message(
              id: 'perm-msg-rtl',
              role: MessageRole.assistant,
              content: 'في انتظار الإذن.',
            ),
          ],
        );
        final notifier = _InteractionNotifier(
          AiChatState(
            sessions: [session],
            activeSessionId: session.id,
            activeAgentProfile: harnessAgent,
            readyAgents: [harnessAgent],
            pendingPermission: request,
            permissionCompleter: completer,
          ),
        );

        await pumpAcpHarness(
          tester,
          child: const AiChatView(),
          notifier: notifier,
          locale: const Locale('ar'),
          textScaler: TextScaler.linear(textScale),
        );
        await tester.pumpAndSettle();

        final detailsButton = find.byKey(
          const Key('chat_permission_details_button'),
        );
        expect(detailsButton, findsOneWidget);
        await tester.ensureVisible(detailsButton);
        await tester.tap(detailsButton);
        await tester.pumpAndSettle();

        final boundedBox = find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedBox &&
              widget.constraints.maxWidth == 640 &&
              widget.constraints.maxHeight < double.infinity,
        );
        expect(boundedBox, findsOneWidget);
        final constraints = tester
            .widget<ConstrainedBox>(boundedBox)
            .constraints;
        expect(
          constraints.maxHeight,
          lessThanOrEqualTo((height - viewInsetBottom) * 0.8),
        );

        final copyButton = find.ancestor(
          of: find.byWidgetPredicate(
            (widget) => widget is Text && widget.data?.contains('نسخ') == true,
          ),
          matching: find.byWidgetPredicate((widget) => widget is TextButton),
        );
        expect(copyButton, findsOneWidget);
        await tester.ensureVisible(copyButton);
        await tester.pumpAndSettle();
        final copyRect = tester.getRect(copyButton);
        expect(
          copyRect.right,
          lessThanOrEqualTo(width),
          reason:
              'Copy action must stay reachable at 390dp RTL with IME and textScale 1.3',
        );
        expect(copyRect.bottom, lessThanOrEqualTo(height - viewInsetBottom));

        final allowOnceKey = Key('chat_permission_option_detail_allow_once');
        final allowSessionKey = Key(
          'chat_permission_option_detail_allow_session',
        );
        final rejectKey = Key('chat_permission_option_detail_reject_once');

        final allowOnceFinder = find.byKey(allowOnceKey);
        final allowSessionFinder = find.byKey(allowSessionKey);
        final rejectFinder = find.byKey(rejectKey);
        final cancelFinder = find.byKey(const Key('chat_permission_cancel'));

        expect(allowOnceFinder, findsOneWidget);
        expect(allowSessionFinder, findsOneWidget);
        expect(rejectFinder, findsOneWidget);
        expect(cancelFinder, findsOneWidget);

        for (final finder in [
          allowOnceFinder,
          allowSessionFinder,
          rejectFinder,
          cancelFinder,
        ]) {
          final rect = tester.getRect(finder);
          expect(
            rect.right,
            lessThanOrEqualTo(width),
            reason:
                'Action button must not overflow horizontally at 390dp RTL with IME and textScale 1.3',
          );
          expect(
            rect.bottom,
            lessThanOrEqualTo(height - viewInsetBottom),
            reason:
                'Action button must be above IME viewport at 390dp RTL with IME and textScale 1.3',
          );
        }

        await tester.tap(copyButton);
        await tester.pump();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is SnackBar &&
                widget.content is Text &&
                (widget.content as Text).data?.contains('نسخ') == true,
          ),
          findsOneWidget,
        );
        expect(clipboardText, longCommand);

        expect(tester.takeException(), isNull);
      },
    );
  });
}
