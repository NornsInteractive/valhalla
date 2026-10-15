import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';

import '../support/acp_chat_widget_harness.dart';

class _StreamingNotifier extends FakeAcpChatNotifier {
  _StreamingNotifier(super.initialState);

  void replaceMessages(List<ChatMessage> messages, {int? messageOffset}) {
    final active = state.activeSession!;
    state = state.copyWith(
      sessions: [
        active.copyWith(messages: messages, messageOffset: messageOffset),
      ],
    );
  }
}

void main() {
  testWidgets('prepending history preserves existing message elements', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final date = DateTime.utc(2026, 10, 15);
    ChatMessage message(String id) => ChatMessage(
      id: id,
      agentId: harnessAgent.id,
      role: MessageRole.assistant,
      content: 'Answer $id',
      createdAt: date,
    );
    final current = message('current');
    final session = ChatSession(
      id: 'prepend-test',
      title: 'History',
      serverId: harnessServerId,
      agentId: harnessAgent.id,
      createdAt: date,
      updatedAt: date,
      messages: [current],
      messageOffset: 2,
    );
    final notifier = _StreamingNotifier(
      AiChatState(
        sessions: [session],
        activeSessionId: session.id,
        activeAgentProfile: harnessAgent,
        readyAgents: [harnessAgent],
      ),
    );
    await pumpAcpHarness(tester, child: const AiChatView(), notifier: notifier);
    await tester.pumpAndSettle();
    final currentFinder = find.byKey(
      const ValueKey('prepend-test_assistant_msg_current'),
    );
    final original = tester.element(currentFinder);
    notifier.replaceMessages([message('older'), current], messageOffset: 1);
    await tester.pumpAndSettle();
    expect(identical(original, tester.element(currentFinder)), isTrue);
    // Exhausting history removes the load-older row and changes the offset again.
    notifier.replaceMessages([
      message('oldest'),
      message('older'),
      current,
    ], messageOffset: 0);
    await tester.pumpAndSettle();
    expect(identical(original, tester.element(currentFinder)), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'streaming rebuilds only the changed message, not the composer or history',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final date = DateTime.utc(2026, 10, 15);
      final completed = ChatMessage(
        id: 'completed',
        agentId: harnessAgent.id,
        role: MessageRole.assistant,
        content: 'Previous answer',
        createdAt: date,
      );
      var streaming = ChatMessage(
        id: 'streaming',
        agentId: harnessAgent.id,
        role: MessageRole.assistant,
        content: 'Current answer',
        status: ChatTurnStatus.streaming,
        createdAt: date,
      );
      final session = ChatSession(
        id: 'stream-test',
        title: 'Stable history title',
        serverId: harnessServerId,
        agentId: harnessAgent.id,
        createdAt: date,
        updatedAt: date,
        messages: [completed, streaming],
      );
      final notifier = _StreamingNotifier(
        AiChatState(
          sessions: [session],
          activeSessionId: session.id,
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
          isGenerating: true,
        ),
      );
      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      // The receiving indicator intentionally never settles while generating.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final inputFinder = find.byKey(const Key('chatPromptInput'));
      final historyFinder = find.byKey(const Key('chat_session_search_input'));
      final inputBefore = tester.widget(inputFinder);
      final historyBefore = tester.widget(historyFinder);
      const oldKey = ValueKey('stream-test_assistant_msg_completed');
      const currentKey = ValueKey('stream-test_assistant_msg_streaming');
      expect(find.byKey(oldKey), findsOneWidget);
      expect(find.byKey(currentKey), findsOneWidget);

      var rootBuilds = 0;
      var oldMessageBuilds = 0;
      var streamingBuilds = 0;
      final previousHook = debugOnRebuildDirtyWidget;
      addTearDown(() => debugOnRebuildDirtyWidget = previousHook);
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previousHook?.call(element, builtOnce);
        if (element.widget is AiChatView) rootBuilds++;
        if (element.widget.key == oldKey) oldMessageBuilds++;
        if (element.widget.key == currentKey) streamingBuilds++;
      };
      for (var i = 0; i < 6; i++) {
        streaming = streaming.copyWith(content: 'Current answer chunk $i');
        notifier.replaceMessages([completed, streaming]);
        await tester.pump(const Duration(milliseconds: 60));
      }

      expect(
        rootBuilds,
        0,
        reason: 'token updates must not rebuild the whole page',
      );
      expect(oldMessageBuilds, 0);
      expect(
        streamingBuilds,
        greaterThan(0),
        reason: 'the new content must render',
      );
      expect(identical(inputBefore, tester.widget(inputFinder)), isTrue);
      expect(identical(historyBefore, tester.widget(historyFinder)), isTrue);
      expect(
        find.textContaining('Current answer chunk 5', findRichText: true),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
