import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/repositories/chat_repository.dart';
import 'package:valhalla/features/chat/widgets/chat_history_search_dialog.dart';

import '../support/acp_chat_widget_harness.dart';

/// Local fake only. The shared harness is intentionally left untouched; this
/// subclass supplies the search surface and a mutable workspace selection key.
class _FakeChatNotifier extends FakeAcpChatNotifier {
  _FakeChatNotifier(super.initialState) : super(refreshResult: true);

  String serverId = 'srv-a';
  String agentId = 'agent-a';
  String workspacePath = '/workspace-a';
  bool shareSessions = false;

  @override
  String get workspaceSelectionKey =>
      '$serverId::$agentId::$workspacePath::$shareSessions';

  final List<_SearchCall> searches = [];
  final List<ChatSearchHit> windows = [];
  final List<int> toolOffsets = [];
  final Map<String, ChatSearchPage> pages = {};

  Completer<void>? searchGate;
  Completer<void>? windowGate;
  ChatSession? Function(ChatSearchHit hit)? windowBuilder;
  ChatToolOutputPage Function(int offset)? toolPageBuilder;

  int selectSessionCalls = 0;

  @override
  Future<ChatSearchPage> searchMessages(
    String query, {
    bool allSessions = false,
    String? cursor,
    required String expectedTarget,
  }) async {
    searches.add(
      _SearchCall(
        query: query,
        allSessions: allSessions,
        cursor: cursor,
        expectedTarget: expectedTarget,
      ),
    );
    if (expectedTarget != workspaceSelectionKey) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    final gate = searchGate;
    if (gate != null) await gate.future;
    if (expectedTarget != workspaceSelectionKey) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    return pages[query] ?? const ChatSearchPage([], null);
  }

  @override
  Future<ChatSession?> loadSearchWindow(
    ChatSearchHit hit, {
    required String expectedTarget,
  }) async {
    windows.add(hit);
    if (expectedTarget != workspaceSelectionKey) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    final gate = windowGate;
    if (gate != null) await gate.future;
    if (expectedTarget != workspaceSelectionKey) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    return windowBuilder?.call(hit);
  }

  @override
  Future<ChatToolOutputPage> loadSearchToolOutput(
    ChatSearchHit hit, {
    required String expectedTarget,
    int? offset,
  }) async {
    if (expectedTarget != workspaceSelectionKey) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    final start = offset ?? (hit.matchOffset > 60 ? hit.matchOffset - 60 : 0);
    toolOffsets.add(start);
    return toolPageBuilder?.call(start) ??
        const ChatToolOutputPage('needle', null);
  }

  @override
  Future<void> selectSession(String sessionId) async {
    selectSessionCalls++;
  }
}

class _SearchCall {
  const _SearchCall({
    required this.query,
    required this.allSessions,
    required this.cursor,
    required this.expectedTarget,
  });

  final String query;
  final bool allSessions;
  final String? cursor;
  final String expectedTarget;
}

ChatMessage _message(
  String id,
  String content, {
  List<ToolExecution> tools = const [],
}) => ChatMessage(
  id: id,
  role: MessageRole.assistant,
  content: content,
  toolExecutions: tools,
  createdAt: DateTime.utc(2026, 1, 1),
);

ChatSession _session(List<ChatMessage> messages) => ChatSession(
  id: 'sess-a',
  title: 'Session A',
  serverId: harnessServerId,
  agentId: harnessAgent.id,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  messages: messages,
);

ChatSearchHit _hit({
  String messageId = 'msg-target',
  String source = 'message',
  String? toolId,
  int matchOffset = 0,
  String excerpt = 'needle in message',
}) => ChatSearchHit(
  sessionId: 'sess-a',
  messageId: messageId,
  title: 'Session A',
  role: MessageRole.assistant,
  sequence: 0,
  createdAt: DateTime.utc(2026, 1, 1),
  matchOffset: matchOffset,
  source: source,
  excerpt: excerpt,
  toolId: toolId,
);

AiChatState _state() => AiChatState(
  sessions: [
    _session([_message('active-message', 'active session body')]),
  ],
  activeSessionId: 'sess-a',
  activeAgentProfile: harnessAgent,
  readyAgents: [harnessAgent],
  draftText: 'keep-draft',
  draftWorkingDirectory: '/workspace-a',
);

_FakeChatNotifier _notifier() => _FakeChatNotifier(_state());

Future<void> _pumpDialog(
  WidgetTester tester,
  _FakeChatNotifier notifier, {
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await pumpAcpHarness(
    tester,
    child: const ChatHistorySearchDialog(),
    notifier: notifier,
    textScaler: textScaler,
  );
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(const Key('chat_search_input')), query);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

String _tall(String tag) {
  final lines = List.generate(
    40,
    (index) => '$tag line $index lorem ipsum dolor sit amet consectetur',
  );
  return '```\n${lines.join('\n')}\n```';
}

void main() {
  testWidgets('300ms debounce issues exactly one search and passes scope', (
    tester,
  ) async {
    final notifier = _notifier();
    notifier.pages['needle'] = ChatSearchPage([
      _hit(excerpt: 'needle in message'),
    ], null);
    await _pumpDialog(tester, notifier);

    await tester.enterText(find.byKey(const Key('chat_search_input')), 'n');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byKey(const Key('chat_search_input')), 'ne');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const Key('chat_search_input')),
      'needle',
    );
    await tester.pump(const Duration(milliseconds: 299));

    expect(
      notifier.searches,
      isEmpty,
      reason: 'no query may be issued before the 300ms debounce elapses',
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(notifier.searches, hasLength(1));
    expect(notifier.searches.single.query, 'needle');
    expect(notifier.searches.single.allSessions, isFalse);
    expect(
      notifier.searches.single.expectedTarget,
      notifier.workspaceSelectionKey,
    );

    // Current session scope is the default; switching to current server must
    // re-issue the same query with the server-wide flag.
    await tester.tap(find.text('Current Server'));
    await tester.pumpAndSettle();

    expect(notifier.searches, hasLength(2));
    expect(notifier.searches.last.query, 'needle');
    expect(notifier.searches.last.allSessions, isTrue);
    expect(
      notifier.searches.last.expectedTarget,
      notifier.workspaceSelectionKey,
    );
  });

  testWidgets('clearing while a search is pending cannot repopulate results', (
    tester,
  ) async {
    final notifier = _notifier();
    final gate = Completer<void>();
    notifier.searchGate = gate;
    notifier.pages['needle'] = ChatSearchPage([
      _hit(excerpt: 'needle stale result'),
      _hit(messageId: 'msg-2', excerpt: 'needle stale result 2'),
    ], null);
    await _pumpDialog(tester, notifier);

    await tester.enterText(
      find.byKey(const Key('chat_search_input')),
      'needle',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(notifier.searches, hasLength(1));

    // The clear button only exists after the searching state rebuild.
    expect(find.byIcon(Icons.clear), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump(const Duration(milliseconds: 300));

    // The old request completes after the clear; its hits must be discarded.
    gate.complete();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('results found'),
      findsNothing,
      reason: 'stale completion must not restore the result count after clear',
    );
    expect(
      find.textContaining('needle stale result', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('new query keeps previous results visible but not clickable', (
    tester,
  ) async {
    final notifier = _notifier();
    notifier.pages['alpha'] = ChatSearchPage([
      _hit(excerpt: 'alpha previous result'),
    ], null);
    notifier.pages['beta'] = ChatSearchPage([
      _hit(messageId: 'msg-beta', excerpt: 'beta new result'),
    ], null);
    await _pumpDialog(tester, notifier);

    await _search(tester, 'alpha');
    expect(
      find.textContaining('alpha previous result', findRichText: true),
      findsOneWidget,
    );

    final gate = Completer<void>();
    notifier.searchGate = gate;
    await tester.enterText(find.byKey(const Key('chat_search_input')), 'beta');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      find.textContaining('alpha previous result', findRichText: true),
      findsOneWidget,
      reason: 'previous hits should stay visible while the new query loads',
    );

    await tester.tap(
      find.textContaining('alpha previous result', findRichText: true).first,
    );
    await tester.pump();

    expect(find.text('Message Context Preview'), findsNothing);
    expect(notifier.windows, isEmpty);

    gate.complete();
    await tester.pumpAndSettle();
  });

  // A server, Agent, workspace or shared-session policy change all alter the
  // workspace selection key. Any in-flight query captured before the change
  // must be rejected rather than populating the new scope.
  final mutations = <(String, void Function(_FakeChatNotifier))>[
    ('server', (notifier) => notifier.serverId = 'srv-b'),
    ('Agent', (notifier) => notifier.agentId = 'agent-b'),
    ('workspace', (notifier) => notifier.workspacePath = '/workspace-b'),
    ('shared policy', (notifier) => notifier.shareSessions = true),
  ];

  for (final (name, mutate) in mutations) {
    testWidgets('$name change invalidates an in-flight query', (tester) async {
      final notifier = _notifier();
      final gate = Completer<void>();
      notifier.searchGate = gate;
      notifier.pages['needle'] = ChatSearchPage([_hit()], null);
      await _pumpDialog(tester, notifier);

      await tester.enterText(
        find.byKey(const Key('chat_search_input')),
        'needle',
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(notifier.searches, hasLength(1));
      expect(
        notifier.searches.single.expectedTarget,
        notifier.workspaceSelectionKey,
      );

      mutate(notifier);
      gate.complete();
      await tester.pumpAndSettle();

      expect(
        notifier.searches.single.expectedTarget,
        isNot(notifier.workspaceSelectionKey),
      );
      expect(
        find.text('Session or server changed during search'),
        findsOneWidget,
      );
      expect(find.textContaining('results found'), findsNothing);
    });
  }

  testWidgets('workspace change invalidates an in-flight reader', (
    tester,
  ) async {
    final notifier = _notifier();
    notifier.pages['needle'] = ChatSearchPage([_hit()], null);
    notifier.windowBuilder = (_) =>
        _session([_message('msg-target', 'TARGET-MARKER')]);
    await _pumpDialog(tester, notifier);

    await _search(tester, 'needle');
    final gate = Completer<void>();
    notifier.windowGate = gate;
    await tester.tap(
      find.textContaining('needle in message', findRichText: true).first,
    );
    await tester.pump();
    expect(notifier.windows, hasLength(1));

    notifier.workspacePath = '/workspace-b';
    gate.complete();
    await tester.pumpAndSettle();

    expect(
      find.text('Session or server changed during search'),
      findsOneWidget,
    );
    expect(find.text('TARGET-MARKER', findRichText: true), findsNothing);
  });

  testWidgets('reader makes the target directly visible among tall messages', (
    tester,
  ) async {
    final notifier = _notifier();
    notifier.pages['needle'] = ChatSearchPage([
      _hit(messageId: 'msg-target', excerpt: 'needle target hit'),
    ], null);
    final messages = <ChatMessage>[
      for (var i = 0; i < 15; i++) _message('before-$i', _tall('BEFORE-$i')),
      _message('msg-target', 'TARGET-MARKER'),
      for (var i = 0; i < 15; i++) _message('after-$i', _tall('AFTER-$i')),
    ];
    expect(messages, hasLength(31));
    notifier.windowBuilder = (_) => _session(messages);
    await _pumpDialog(tester, notifier);

    await _search(tester, 'needle');
    await tester.tap(
      find.textContaining('needle target hit', findRichText: true).first,
    );
    await tester.pumpAndSettle();

    final target = find.text('TARGET-MARKER', findRichText: true);
    expect(
      target,
      findsOneWidget,
      reason: 'the hit message must be built after the window loads',
    );
    expect(
      target.hitTestable(),
      findsOneWidget,
      reason: 'the hit message must be directly visible, not just estimated',
    );

    final rect = tester.getRect(target);
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
  });

  testWidgets('tool hit loads output around the match and follows next page', (
    tester,
  ) async {
    final notifier = _notifier();
    notifier.pages['needle'] = ChatSearchPage([
      _hit(
        messageId: 'msg-tool',
        source: 'tool',
        toolId: 'tool-1',
        matchOffset: 5000,
        excerpt: 'needle in tool output',
      ),
    ], null);
    notifier.windowBuilder = (_) => _session([
      _message(
        'msg-tool',
        'tool execution',
        tools: const [
          ToolExecution(
            id: 'tool-1',
            name: 'grep',
            command: 'grep needle file',
            output: 'needle',
            hasMoreOutput: true,
          ),
        ],
      ),
    ]);
    notifier.toolPageBuilder = (offset) => offset == 4940
        ? const ChatToolOutputPage('tool page one needle', 9000)
        : const ChatToolOutputPage('tool page two needle', null);
    await _pumpDialog(tester, notifier);

    await _search(tester, 'needle');
    await tester.tap(
      find.textContaining('needle in tool output', findRichText: true).first,
    );
    await tester.pumpAndSettle();

    expect(
      notifier.toolOffsets,
      [4940],
      reason: 'initial page must start 60 runes before the match offset',
    );
    expect(
      find.textContaining('tool page one needle', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(notifier.toolOffsets, [4940, 9000]);
    expect(
      find.textContaining('tool page two needle', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('closing reader retains query/results and never mutates chat', (
    tester,
  ) async {
    final notifier = _notifier();
    notifier.pages['needle'] = ChatSearchPage([
      _hit(excerpt: 'needle retained result'),
    ], null);
    notifier.windowBuilder = (_) =>
        _session([_message('msg-target', 'needle in reader body')]);
    await _pumpDialog(tester, notifier);

    await _search(tester, 'needle');
    expect(notifier.searches, hasLength(1));
    await tester.tap(
      find.textContaining('needle retained result', findRichText: true).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Message Context Preview'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to Results'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('chat_search_input')),
    );
    expect(field.controller!.text, 'needle');
    expect(find.text('1 results found'), findsOneWidget);
    expect(
      find.textContaining('needle retained result', findRichText: true),
      findsOneWidget,
    );
    expect(notifier.searches, hasLength(1));

    // Reading is read-only: active session, draft and send path stay untouched.
    expect(notifier.state.activeSessionId, 'sess-a');
    expect(notifier.state.draftText, 'keep-draft');
    expect(notifier.sendMessageCalls, 0);
    expect(notifier.draftTexts, isEmpty);
    expect(notifier.selectSessionCalls, 0);
  });

  testWidgets('320dp at text scale 1.5 does not overflow', (tester) async {
    final notifier = _notifier();
    notifier.pages['needle'] = ChatSearchPage([
      _hit(excerpt: 'needle compact result'),
    ], null);
    notifier.windowBuilder = (_) =>
        _session([_message('msg-target', 'needle in compact reader')]);
    await _pumpDialog(
      tester,
      notifier,
      size: const Size(320, 640),
      textScaler: const TextScaler.linear(1.5),
    );

    await _search(tester, 'needle');
    expect(
      tester.takeException(),
      isNull,
      reason: 'search list must not overflow at 320dp / text scale 1.5',
    );

    await tester.tap(
      find.textContaining('needle compact result', findRichText: true).first,
    );
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'reader must not overflow at 320dp / text scale 1.5',
    );
  });
}
