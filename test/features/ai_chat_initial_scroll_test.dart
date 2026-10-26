import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import '../support/acp_chat_widget_harness.dart';

class ScrollTestNotifier extends FakeAcpChatNotifier {
  ScrollTestNotifier(super.initialState, {super.workspace})
    : super(refreshResult: true, refreshError: null);

  void emit(AiChatState next) => state = next;
}

ChatSession makeSession({
  required String id,
  required String title,
  List<ChatMessage> messages = const [],
}) => ChatSession(
  id: id,
  title: title,
  serverId: harnessServerId,
  agentId: harnessAgent.id,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  messages: messages,
);

ChatMessage makeMsg({
  required String id,
  required MessageRole role,
  required String content,
  ChatTurnStatus status = ChatTurnStatus.completed,
}) => ChatMessage(
  id: id,
  role: role,
  content: content,
  status: status,
  createdAt: DateTime.now(),
);

ScrollController getScrollController(WidgetTester tester) {
  final listView = tester.widget<ListView>(find.byType(ListView).first);
  return listView.controller!;
}

Future<void> pumpAndSettleBounded(
  WidgetTester tester, {
  int pumps = 8,
  int ms = 16,
}) async {
  for (var i = 0; i < pumps; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

void setupView(
  WidgetTester tester, {
  Size size = const Size(800, 600),
  double dpr = 1.0,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('AiChatView Initial Scroll Behavior', () {
    testWidgets(
      'preloaded >=50 variable height messages shows newest at bottom',
      (tester) async {
        setupView(tester, size: const Size(390, 844), dpr: 1.0);

        final messages = <ChatMessage>[];
        for (var i = 0; i < 60; i++) {
          final isUser = i % 2 == 0;
          final lines = (i % 7) + 1;
          final content = List.generate(
            lines,
            (l) => '${isUser ? "User" : "Assistant"} $i line $l',
          ).join('\n');
          messages.add(
            makeMsg(
              id: 'msg-$i',
              role: isUser ? MessageRole.user : MessageRole.assistant,
              content: content,
            ),
          );
        }
        final session = makeSession(
          id: 'sess-preload',
          title: 'Preload',
          messages: messages,
        );
        final notifier = ScrollTestNotifier(
          AiChatState(
            sessions: [session],
            activeSessionId: 'sess-preload',
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

        final controller = getScrollController(tester);
        expect(controller.hasClients, isTrue);
        expect(controller.position.maxScrollExtent, greaterThan(0));
        final atBottom =
            (controller.position.maxScrollExtent - controller.offset).abs() <=
            1.0;
        expect(
          atBottom,
          isTrue,
          reason: 'Should be clamped to bottom with newest message visible',
        );
      },
    );

    testWidgets('delayed first history arrival shows bottom after load', (
      tester,
    ) async {
      setupView(tester);

      final session = makeSession(
        id: 'sess-delayed',
        title: 'Delayed',
        messages: [],
      );
      final notifier = ScrollTestNotifier(
        AiChatState(
          sessions: [session],
          activeSessionId: 'sess-delayed',
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

      final delayedMessages = <ChatMessage>[];
      for (var i = 0; i < 30; i++) {
        final isUser = i % 2 == 0;
        final lines = (i % 5) + 1;
        final content = List.generate(
          lines,
          (l) => '${isUser ? "Hist User" : "Hist Asst"} $i line $l',
        ).join('\n');
        delayedMessages.add(
          makeMsg(
            id: 'hist-$i',
            role: isUser ? MessageRole.user : MessageRole.assistant,
            content: content,
          ),
        );
      }
      notifier.emit(
        notifier.state.copyWith(
          sessions: [session.copyWith(messages: delayedMessages)],
          activeSessionId: 'sess-delayed',
        ),
      );
      await tester.pumpAndSettle();

      final controller = getScrollController(tester);
      expect(controller.hasClients, isTrue);
      final atBottom =
          (controller.position.maxScrollExtent - controller.offset).abs() <=
          1.0;
      expect(
        atBottom,
        isTrue,
        reason: 'Should clamp to bottom after delayed history arrives',
      );
    });

    testWidgets('switch populated sessions shows newest message', (
      tester,
    ) async {
      setupView(tester);

      final messages1 = <ChatMessage>[];
      for (var i = 0; i < 20; i++) {
        messages1.add(
          makeMsg(
            id: 's1-$i',
            role: i % 2 == 0 ? MessageRole.user : MessageRole.assistant,
            content: 'Session 1 msg $i',
          ),
        );
      }
      final messages2 = <ChatMessage>[];
      for (var i = 0; i < 25; i++) {
        messages2.add(
          makeMsg(
            id: 's2-$i',
            role: i % 2 == 0 ? MessageRole.user : MessageRole.assistant,
            content: 'Session 2 msg $i',
          ),
        );
      }
      final sess1 = makeSession(
        id: 'sess-1',
        title: 'Session 1',
        messages: messages1,
      );
      final sess2 = makeSession(
        id: 'sess-2',
        title: 'Session 2',
        messages: messages2,
      );

      final notifier = ScrollTestNotifier(
        AiChatState(
          sessions: [sess1, sess2],
          activeSessionId: 'sess-1',
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

      notifier.emit(
        notifier.state.copyWith(
          sessions: [sess1, sess2],
          activeSessionId: 'sess-2',
        ),
      );
      await tester.pumpAndSettle();

      final controller = getScrollController(tester);
      expect(controller.hasClients, isTrue);
      final atBottom =
          (controller.position.maxScrollExtent - controller.offset).abs() <=
          1.0;
      expect(
        atBottom,
        isTrue,
        reason: 'Should show newest message when switching sessions',
      );
    });

    testWidgets(
      'rapid session switching stale callbacks cannot move new view',
      (tester) async {
        setupView(tester);

        final sessions = List.generate(5, (idx) {
          final msgs = <ChatMessage>[];
          for (var i = 0; i < 10; i++) {
            msgs.add(
              makeMsg(
                id: 's$idx-$i',
                role: i % 2 == 0 ? MessageRole.user : MessageRole.assistant,
                content: 'S$idx M$i',
              ),
            );
          }
          return makeSession(
            id: 'sess-$idx',
            title: 'Session $idx',
            messages: msgs,
          );
        });

        final notifier = ScrollTestNotifier(
          AiChatState(
            sessions: sessions,
            activeSessionId: 'sess-0',
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

        for (var i = 1; i < sessions.length; i++) {
          notifier.emit(
            notifier.state.copyWith(
              sessions: sessions,
              activeSessionId: 'sess-$i',
            ),
          );
          await tester.pump(const Duration(milliseconds: 5));
        }
        await tester.pumpAndSettle();

        final controller = getScrollController(tester);
        expect(controller.hasClients, isTrue);
        final atBottom =
            (controller.position.maxScrollExtent - controller.offset).abs() <=
            1.0;
        expect(
          atBottom,
          isTrue,
          reason: 'Rapid switches should not leave stale scroll position',
        );
      },
    );

    testWidgets('manual scroll up then stream append preserves position', (
      tester,
    ) async {
      setupView(tester);

      final messages = <ChatMessage>[];
      for (var i = 0; i < 20; i++) {
        messages.add(
          makeMsg(
            id: 'm-$i',
            role: i % 2 == 0 ? MessageRole.user : MessageRole.assistant,
            content: 'Msg $i',
          ),
        );
      }
      final session = makeSession(
        id: 'sess-scroll',
        title: 'Scroll',
        messages: messages,
      );
      final notifier = ScrollTestNotifier(
        AiChatState(
          sessions: [session],
          activeSessionId: 'sess-scroll',
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

      final controller = getScrollController(tester);
      controller.jumpTo(controller.position.maxScrollExtent * 0.3);
      await tester.pumpAndSettle();

      final userScrollPos = controller.offset;
      expect(
        userScrollPos,
        lessThan(controller.position.maxScrollExtent * 0.5),
      );

      notifier.emit(
        notifier.state.copyWith(
          sessions: [
            session.copyWith(
              messages: [
                ...messages,
                makeMsg(
                  id: 'new-1',
                  role: MessageRole.assistant,
                  content: 'New stream msg',
                  status: ChatTurnStatus.streaming,
                ),
              ],
            ),
          ],
          activeSessionId: 'sess-scroll',
          isGenerating: true,
        ),
      );
      await pumpAndSettleBounded(tester);

      expect(
        controller.offset,
        closeTo(userScrollPos, 5.0),
        reason: 'User scroll position should be preserved on append',
      );
    });

    testWidgets('last message bubble bottom inside viewport and fully opaque', (
      tester,
    ) async {
      setupView(tester);

      final messages = <ChatMessage>[];
      for (var i = 0; i < 40; i++) {
        final isUser = i % 2 == 0;
        final lines = (i % 5) + 1;
        final content = List.generate(
          lines,
          (l) => '${isUser ? "User" : "Assistant"} $i line $l',
        ).join('\n');
        messages.add(
          makeMsg(
            id: 'msg-$i',
            role: isUser ? MessageRole.user : MessageRole.assistant,
            content: content,
          ),
        );
      }
      final session = makeSession(
        id: 'sess-viewport',
        title: 'Viewport',
        messages: messages,
      );
      final notifier = ScrollTestNotifier(
        AiChatState(
          sessions: [session],
          activeSessionId: 'sess-viewport',
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

      final controller = getScrollController(tester);
      expect(controller.hasClients, isTrue);
      expect(controller.position.maxScrollExtent, greaterThan(0));

      final viewportRect = tester.getRect(find.byType(ListView).first);

      final lastMsgKey = ValueKey('assistant_msg_msg-39');
      final lastMsgFinder = find.byKey(lastMsgKey);
      expect(lastMsgFinder, findsOneWidget);

      final lastMsgRect = tester.getRect(lastMsgFinder);

      expect(
        lastMsgRect.bottom,
        lessThanOrEqualTo(viewportRect.bottom + 1),
        reason: 'Last message bottom should be at or above viewport bottom',
      );
      expect(
        lastMsgRect.bottom,
        greaterThan(viewportRect.top),
        reason: 'Last message bottom should be below viewport top',
      );

      final hiddenOpacity = find.ancestor(
        of: lastMsgFinder,
        matching: find.byWidgetPredicate(
          (widget) => widget is Opacity && widget.opacity == 0,
        ),
      );
      expect(
        hiddenOpacity,
        findsNothing,
        reason: 'Message list visibility must not depend on opacity gating',
      );
    });

    testWidgets('variable-height final tall message bottom inside viewport', (
      tester,
    ) async {
      setupView(tester);

      final messages = <ChatMessage>[];
      for (var i = 0; i < 10; i++) {
        messages.add(
          makeMsg(
            id: 'pre-$i',
            role: i % 2 == 0 ? MessageRole.user : MessageRole.assistant,
            content: 'Pre $i',
          ),
        );
      }
      final tallContent = List.generate(200, (l) => 'Tall line $l').join('\n');
      messages.add(
        makeMsg(
          id: 'tall-final',
          role: MessageRole.assistant,
          content: tallContent,
        ),
      );

      final session = makeSession(
        id: 'sess-tall',
        title: 'Tall Final',
        messages: messages,
      );
      final notifier = ScrollTestNotifier(
        AiChatState(
          sessions: [session],
          activeSessionId: 'sess-tall',
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

      final controller = getScrollController(tester);
      expect(controller.hasClients, isTrue);
      expect(controller.position.maxScrollExtent, greaterThan(0));

      final atBottom =
          (controller.position.maxScrollExtent - controller.offset).abs() <=
          1.0;
      expect(
        atBottom,
        isTrue,
        reason: 'Tall final message should be visible at bottom',
      );

      final viewportRect = tester.getRect(find.byType(ListView).first);

      final tallMsgKey = ValueKey('assistant_msg_tall-final');
      final tallMsgFinder = find.byKey(tallMsgKey);
      expect(tallMsgFinder, findsOneWidget);

      final tallMsgRect = tester.getRect(tallMsgFinder);

      expect(
        tallMsgRect.bottom,
        lessThanOrEqualTo(viewportRect.bottom + 1),
        reason: 'Tall message bottom should be at or above viewport bottom',
      );
      expect(
        tallMsgRect.bottom,
        greaterThan(viewportRect.top),
        reason: 'Tall message bottom should be below viewport top',
      );
    });
  });
}
