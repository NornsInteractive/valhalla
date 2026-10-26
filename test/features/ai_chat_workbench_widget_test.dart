import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import '../support/acp_chat_widget_harness.dart';

class _WorkbenchNotifier extends FakeAcpChatNotifier {
  _WorkbenchNotifier(super.initialState, {super.workspace})
    : super(refreshResult: true, refreshError: null);

  void emit(AiChatState next) => state = next;

  @override
  Future<String> resolveWorkspaceDirectory() async {
    workspace?.resolveCount++;
    if (state.activeSessionId == 'session-b') return '/other';
    return '/workspace';
  }
}

ChatSession _session(String id) => ChatSession(
  id: id,
  title: id,
  serverId: harnessServerId,
  agentId: harnessAgent.id,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  messages: const [],
);

void main() {
  testWidgets(
    'mobile workbench tabs switch content without duplicate scroll controllers',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final workspace = FakeWorkspace(initialPath: '/workspace');
      workspace.add('/workspace', [
        FakeWorkspace.file('alpha.txt', '/workspace'),
      ]);

      final notifier = _WorkbenchNotifier(
        AiChatState(
          sessions: [_session('workbench-session')],
          activeSessionId: 'workbench-session',
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
        ),
        workspace: workspace,
      );

      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat_workbench_toggle_button')));
      await tester.pumpAndSettle();

      expect(find.text('alpha.txt'), findsOneWidget);

      await tester.tap(find.text('Tasks & Tools'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No active tasks'), findsOneWidget);

      await tester.tap(find.text('Context'));
      await tester.pumpAndSettle();
      expect(find.text('Harness Server'), findsOneWidget);

      await tester.tap(find.text('Files'));
      await tester.pumpAndSettle();
      expect(find.text('alpha.txt'), findsOneWidget);
    },
  );

  testWidgets('deferred file request cannot overwrite after target switch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final gate = Completer<void>();
    final workspace = FakeWorkspace(initialPath: '/workspace');
    workspace.listGate = gate;
    workspace.add('/workspace', [FakeWorkspace.file('old.txt', '/workspace')]);
    workspace.add('/other', [FakeWorkspace.file('new.txt', '/other')]);

    final notifier = _WorkbenchNotifier(
      AiChatState(
        sessions: [_session('session-a')],
        activeSessionId: 'session-a',
        activeAgentProfile: harnessAgent,
        readyAgents: [harnessAgent],
        draftWorkingDirectory: '/workspace',
      ),
      workspace: workspace,
    );

    await pumpAcpHarness(tester, child: const AiChatView(), notifier: notifier);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_workbench_toggle_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    notifier.emit(
      notifier.state.copyWith(
        sessions: [_session('session-b')],
        activeSessionId: 'session-b',
        draftWorkingDirectory: '/other',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Old response must not land.
    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('new.txt'), findsOneWidget);
    expect(find.text('old.txt'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('workbench tabs stay laid out at 390dp with 2x text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final workspace = FakeWorkspace(initialPath: '/workspace');
    workspace.add('/workspace', [
      FakeWorkspace.file('alpha.txt', '/workspace'),
    ]);

    final notifier = _WorkbenchNotifier(
      AiChatState(
        sessions: [_session('workbench-session')],
        activeSessionId: 'workbench-session',
        activeAgentProfile: harnessAgent,
        readyAgents: [harnessAgent],
      ),
      workspace: workspace,
    );

    await pumpAcpHarness(
      tester,
      child: const AiChatView(),
      notifier: notifier,
      textScaler: const TextScaler.linear(2),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('chat_workbench_toggle_button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Tasks & Tools'), findsOneWidget);
    expect(find.text('Context'), findsOneWidget);
    expect(find.text('alpha.txt'), findsOneWidget);

    await tester.tap(find.text('Tasks & Tools'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('No active tasks'), findsOneWidget);

    await tester.tap(find.text('Context'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
