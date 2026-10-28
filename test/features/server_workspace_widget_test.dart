import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/remote_workspace_provider.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import '../support/acp_chat_widget_harness.dart';

ChatSession _session() => ChatSession(
  id: 'ws-session',
  title: 'ws-session',
  serverId: harnessServerId,
  agentId: harnessAgent.id,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  messages: const [],
);

class _WsNotifier extends FakeAcpChatNotifier {
  _WsNotifier(super.initialState)
    : super(refreshResult: true, refreshError: null);

  int acquireCalls = 0;
  bool acquireResult = true;

  void emit(AiChatState next) => state = next;

  @override
  Future<bool> acquireWorkspaceControl({
    bool takeover = false,
    String? serverId,
    String? sessionId,
  }) async {
    acquireCalls++;
    return acquireResult;
  }
}

void main() {
  group('workspace control badge layout', () {
    for (final width in [320.0, 390.0]) {
      for (final textScale in [1.0, 1.5]) {
        for (final scenario in ['active', 'readonly', 'busy']) {
          testWidgets('no overflow $scenario ${width}px scale$textScale', (
            tester,
          ) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            final state = AiChatState(
              sessions: [_session()],
              activeSessionId: 'ws-session',
              activeAgentProfile: harnessAgent,
              readyAgents: [harnessAgent],
              workspaceHasControl: scenario == 'active',
              workspaceControlBusy: scenario == 'busy',
              workspaceControlOwnerDeviceId: scenario == 'readonly'
                  ? 'device-1234567890'
                  : null,
            );

            final notifier = _WsNotifier(state);
            await pumpAcpHarness(
              tester,
              child: const AiChatView(),
              notifier: notifier,
              textScaler: TextScaler.linear(textScale),
              extraOverrides: [
                remoteWorkspaceProvider.overrideWith(
                  () => _FakeRemoteNotifier(
                    const RemoteWorkspaceState(enabled: true),
                  ),
                ),
              ],
            );
            // The busy scenario shows an indeterminate progress spinner that
            // never settles, so pump a bounded frame instead of pumpAndSettle.
            if (scenario == 'busy') {
              await tester.pump(const Duration(milliseconds: 200));
            } else {
              await tester.pumpAndSettle();
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  testWidgets('local-disabled keeps no badge', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final state = AiChatState(
      sessions: [_session()],
      activeSessionId: 'ws-session',
      activeAgentProfile: harnessAgent,
      readyAgents: [harnessAgent],
      workspaceHasControl: false,
    );
    final notifier = _WsNotifier(state);
    await pumpAcpHarness(
      tester,
      child: const AiChatView(),
      notifier: notifier,
      extraOverrides: [
        remoteWorkspaceProvider.overrideWith(
          () => _FakeRemoteNotifier(const RemoteWorkspaceState(enabled: false)),
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('chat_workspace_control_action_button')),
      findsNothing,
    );
  });

  testWidgets('takeover requires confirm and cancels on origin change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final state = AiChatState(
      sessions: [_session()],
      activeSessionId: 'ws-session',
      activeAgentProfile: harnessAgent,
      readyAgents: [harnessAgent],
      workspaceHasControl: false,
      workspaceControlOwnerDeviceId: 'device-1234567890',
    );
    final notifier = _WsNotifier(state);
    await pumpAcpHarness(
      tester,
      child: const AiChatView(),
      notifier: notifier,
      extraOverrides: [
        remoteWorkspaceProvider.overrideWith(
          () => _FakeRemoteNotifier(const RemoteWorkspaceState(enabled: true)),
        ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('chat_workspace_control_action_button')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Take Over'), findsWidgets);

    // cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(notifier.acquireCalls, 0);

    // reopen and change origin before confirm
    await tester.tap(
      find.byKey(const Key('chat_workspace_control_action_button')),
    );
    await tester.pumpAndSettle();
    notifier.emit(state.copyWith(activeSessionId: 'other-session'));
    await tester.pump();
    await tester.tap(find.text('Take Over'));
    // origin changed, no acquire
    await tester.pumpAndSettle();
    expect(notifier.acquireCalls, 0);
  });

  testWidgets('readonly disables send but draft available', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final state = AiChatState(
      sessions: [_session()],
      activeSessionId: 'ws-session',
      activeAgentProfile: harnessAgent,
      readyAgents: [harnessAgent],
      workspaceHasControl: false,
      workspaceControlOwnerDeviceId: 'device-1234567890',
      draftText: 'draft',
    );
    final notifier = _WsNotifier(state);
    await pumpAcpHarness(
      tester,
      child: const AiChatView(),
      notifier: notifier,
      extraOverrides: [
        remoteWorkspaceProvider.overrideWith(
          () => _FakeRemoteNotifier(const RemoteWorkspaceState(enabled: true)),
        ),
      ],
    );
    await tester.pumpAndSettle();
    final send = tester.widget<IconButton>(
      find.byKey(const Key('sendMessageButton')),
    );
    expect(send.onPressed, isNull);
    expect(find.text('draft'), findsOneWidget);
  });
}

class _FakeRemoteNotifier extends RemoteWorkspaceNotifier {
  _FakeRemoteNotifier(this._state);
  final RemoteWorkspaceState _state;
  final List<WorkspaceDraft> restored = [];

  @override
  RemoteWorkspaceState build() => _state;

  @override
  Future<void> restoreDraft(WorkspaceDraft draft) async {
    restored.add(draft);
  }
}
