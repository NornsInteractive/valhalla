import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/infrastructure/acp/acp_workspace_files.dart';
import '../support/acp_chat_widget_harness.dart';

class _EditorNotifier extends FakeAcpChatNotifier {
  _EditorNotifier(super.initialState)
    : super(refreshResult: true, refreshError: null);

  void emit(AiChatState next) => state = next;

  final List<String> savedContents = [];
  final List<String?> readExpectedTargets = [];
  bool conflictOnSave = false;
  int readCount = 0;
  String? _lastSavedContent;

  AcpTextSnapshot _snapshot({
    required String path,
    required String content,
    required bool canSave,
  }) => AcpTextSnapshot(
    path: path,
    targetPath: path,
    content: content,
    revision: canSave ? 'rev-1' : '',
    executionKey: 'exec-key',
    owner: this,
  );

  @override
  Future<AcpTextSnapshot> readWorkspaceText(
    String path, {
    String? expectedTarget,
  }) async {
    if (expectedTarget != workspaceSelectionKey) {
      throw StateError('ACP_TARGET_CHANGED');
    }
    readExpectedTargets.add(expectedTarget);
    readCount++;
    if (path.contains('readonly')) {
      return _snapshot(path: path, content: 'readonly content', canSave: false);
    }
    return _snapshot(
      path: path,
      content: _lastSavedContent ?? 'ORIGINAL_LINE_TO_DELETE\nstable line',
      canSave: true,
    );
  }

  @override
  Future<void> saveWorkspaceText(
    AcpTextSnapshot snapshot,
    String content,
  ) async {
    if (conflictOnSave) {
      throw StateError('ACP_FILE_EDIT_CONFLICT');
    }
    savedContents.add(content);
    _lastSavedContent = content;
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
  workingDirectory: '/',
);

/// Pumps frames until [finder] matches, so tests wait for the real UI state
/// instead of guessing with arbitrary sleeps. The loading dialog owns an
/// indefinite spinner, so `pumpAndSettle` cannot be used while it is open.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 40,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.pump();
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsWidgets, reason: 'UI did not reach the expected state');
}

Finder _inDialog(Finder matching) =>
    find.descendant(of: find.byType(Dialog), matching: matching);

Future<_EditorNotifier> _pumpEditor(
  WidgetTester tester, {
  required String link,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final notifier = _EditorNotifier(
    AiChatState(
      sessions: [_session('editor-session')],
      activeSessionId: 'editor-session',
      activeAgentProfile: harnessAgent,
      readyAgents: [harnessAgent],
    ),
  );

  await pumpAcpHarness(tester, child: const AiChatView(), notifier: notifier);
  await tester.pumpAndSettle();

  notifier.emit(
    notifier.state.copyWith(
      sessions: [
        _session('editor-session').copyWith(
          messages: [
            ChatMessage(
              id: 'msg-links',
              role: MessageRole.assistant,
              content: link,
              createdAt: DateTime.now(),
            ),
          ],
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text(link.replaceAll(RegExp(r'^\[|\]\(.*$'), '')));
  await _pumpUntilFound(tester, _inDialog(find.byType(TextField)));
  return notifier;
}

void main() {
  testWidgets('readonly file snapshot opens read-only editor without Save', (
    tester,
  ) async {
    await _pumpEditor(tester, link: '[Open readonly](/workspace/readonly.txt)');

    final field = tester.widget<TextField>(_inDialog(find.byType(TextField)));
    expect(field.readOnly, isTrue);
    expect(_inDialog(find.text('Save')), findsNothing);
  });

  testWidgets(
    'editable file shows diff before confirm and saves with same target',
    (tester) async {
      final notifier = await _pumpEditor(
        tester,
        link: '[Open editable](/workspace/editable.txt)',
      );
      final selectionKey = notifier.workspaceSelectionKey;

      await tester.enterText(
        _inDialog(find.byType(TextField)),
        'stable line\nNEW_LINE_TO_ADD',
      );
      await tester.pump();

      await tester.tap(_inDialog(find.text('Save')));
      final confirmDialog = find.byType(AlertDialog);
      await _pumpUntilFound(tester, confirmDialog);

      // The confirmation dialog itself must show the real diff: the deleted
      // original line in red and the added line in green, not just a prompt.
      expect(
        find.descendant(
          of: confirmDialog,
          matching: find.text('ORIGINAL_LINE_TO_DELETE'),
        ),
        findsOneWidget,
        reason:
            'the deleted original line must be visible in the confirm dialog',
      );
      expect(
        find.descendant(
          of: confirmDialog,
          matching: find.text('NEW_LINE_TO_ADD'),
        ),
        findsOneWidget,
        reason: 'the new line must be visible in the confirm dialog',
      );

      await tester.tap(
        find.descendant(of: confirmDialog, matching: find.text('Confirm')),
      );
      await _pumpUntilFound(tester, find.text('File saved successfully'));

      expect(notifier.savedContents, ['stable line\nNEW_LINE_TO_ADD']);
      expect(notifier.readExpectedTargets, hasLength(2));
      expect(notifier.readExpectedTargets, everyElement(selectionKey));

      // The post-save reread returns the content that was actually saved, so the
      // editor is no longer dirty and Save is disabled.
      expect(_inDialog(find.text('Save')), findsOneWidget);
      final saveButton = tester.widget<FilledButton>(
        find.ancestor(
          of: _inDialog(find.text('Save')),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(saveButton.onPressed, isNull);

      // Conflict retains the draft and surfaces the error without closing.
      notifier.conflictOnSave = true;
      await tester.enterText(
        _inDialog(find.byType(TextField)),
        'conflict draft content',
      );
      await tester.pump();

      await tester.tap(_inDialog(find.text('Save')));
      await _pumpUntilFound(tester, confirmDialog);
      await tester.tap(
        find.descendant(of: confirmDialog, matching: find.text('Confirm')),
      );
      await _pumpUntilFound(
        tester,
        find.textContaining('ACP_FILE_EDIT_CONFLICT'),
      );

      expect(notifier.savedContents, ['stable line\nNEW_LINE_TO_ADD']);

      // The editor may still be showing the diff; switch back to the text view
      // and prove the draft is still there.
      if (_inDialog(find.text('Edit')).evaluate().isNotEmpty) {
        await tester.tap(_inDialog(find.text('Edit')));
        await tester.pump();
      }
      final draftField = tester.widget<TextField>(
        _inDialog(find.byType(TextField)),
      );
      expect(draftField.controller?.text, 'conflict draft content');
    },
  );
}
