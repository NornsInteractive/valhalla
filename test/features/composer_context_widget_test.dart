import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/features/chat/widgets/image_zoom_dialog.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';

import '../support/acp_chat_widget_harness.dart';

const _promptKey = Key('chatPromptInput');
const _clearDirKey = Key('chat_clear_draft_working_dir_button');
const _workingDirKey = Key('chat_working_dir_button');
const _attachmentsKey = Key('chat_attachments_button');

class _ContextNotifier extends FakeAcpChatNotifier {
  _ContextNotifier(super.initialState);

  void emit(AiChatState next) => state = next;
}

AiChatState _draftState({
  List<AcpSlashCommand> commands = const [],
  List<AcpPromptAttachment> attachments = const [],
  String? directory,
  String draftText = '',
  bool supportsImages = false,
  bool supportsTextAttachments = false,
}) => AiChatState(
  activeAgentProfile: harnessAgent,
  readyAgents: [harnessAgent],
  commands: commands,
  attachments: attachments,
  draftWorkingDirectory: directory,
  draftText: draftText,
  supportsImages: supportsImages,
  supportsTextAttachments: supportsTextAttachments,
);

ChatSession _session() => ChatSession(
  id: 'session-1',
  title: 'Existing session',
  serverId: harnessServerId,
  agentId: harnessAgent.id,
  workingDirectory: '/srv/session',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  messages: const [],
);

Future<void> _pumpChat(
  WidgetTester tester,
  _ContextNotifier notifier, {
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
    child: const AiChatView(),
    notifier: notifier,
    textScaler: textScaler,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('known skill tokens', () {
    testWidgets('show a chip and deleting it keeps the rest of the draft', (
      tester,
    ) async {
      final notifier = _ContextNotifier(
        _draftState(
          commands: const [
            AcpSlashCommand(r'$review', 'Review the diff', 'skill'),
            AcpSlashCommand('status', 'Show session status', 'query'),
          ],
        ),
      );
      await _pumpChat(tester, notifier);

      await tester.enterText(
        find.byKey(_promptKey),
        r'please $review this change',
      );
      await tester.pumpAndSettle();

      final chip = find.byKey(const Key(r'chat_skill_chip_$review'));
      expect(chip, findsOneWidget);
      expect(
        find.descendant(of: chip, matching: find.text(r'$review')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key(r'chat_remove_skill_$review')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byKey(_promptKey));
      expect(field.controller?.text, 'please this change');
      expect(chip, findsNothing);
      expect(notifier.draftTexts.last, 'please this change');

      await tester.enterText(
        find.byKey(_promptKey),
        r'please $unknown this change',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key(r'chat_skill_chip_$unknown')), findsNothing);

      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets(
      'removing a skill keeps newlines and indentation and shifts the cursor',
      (tester) async {
        final notifier = _ContextNotifier(
          _draftState(
            commands: const [
              AcpSlashCommand(r'$review', 'Review the diff', 'skill'),
            ],
          ),
        );
        await _pumpChat(tester, notifier);

        const before = 'first\n  \$review next\nlast';
        const after = 'first\n  next\nlast';
        await tester.enterText(find.byKey(_promptKey), before);
        await tester.pumpAndSettle();

        final editable = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(_promptKey),
            matching: find.byType(EditableText),
          ),
        );
        final tokenEnd = before.indexOf(r'$review') + r'$review'.length;
        editable.controller.selection = TextSelection.collapsed(
          offset: tokenEnd,
        );
        await tester.pump();

        expect(
          find.byKey(const Key(r'chat_skill_chip_$review')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key(r'chat_remove_skill_$review')));
        await tester.pumpAndSettle();

        final field = tester.widget<TextField>(find.byKey(_promptKey));
        expect(
          field.controller?.text,
          after,
          reason: '删除 skill 只能去掉 token 本身，不能吃掉换行或缩进',
        );
        expect(
          field.controller?.selection.baseOffset,
          after.indexOf('next'),
          reason: '光标必须按删除的长度左移，而不是停在旧绝对偏移',
        );
        expect(notifier.draftTexts.last, after);
        expect(notifier.state.draftText, after);

        await tester.pump(const Duration(milliseconds: 500));
      },
    );
    testWidgets(
      'removing a skill at the end of an indented line keeps indentation and newlines',
      (tester) async {
        final notifier = _ContextNotifier(
          _draftState(
            commands: const [
              AcpSlashCommand(r'$review', 'Review the diff', 'skill'),
            ],
          ),
        );
        await _pumpChat(tester, notifier);

        Future<void> removeAtLineEnd(String before, String after) async {
          await tester.enterText(find.byKey(_promptKey), before);
          await tester.pumpAndSettle();

          final editable = tester.widget<EditableText>(
            find.descendant(
              of: find.byKey(_promptKey),
              matching: find.byType(EditableText),
            ),
          );
          final tokenStart = before.indexOf(r'$review');
          editable.controller.selection = TextSelection.collapsed(
            offset: tokenStart + r'$review'.length,
          );
          await tester.pump();

          expect(
            find.byKey(const Key(r'chat_skill_chip_$review')),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key(r'chat_remove_skill_$review')));
          await tester.pumpAndSettle();

          final field = tester.widget<TextField>(find.byKey(_promptKey));
          expect(
            field.controller?.text,
            after,
            reason: '行尾删除只能去掉 token，不能吃掉前面的缩进或换行',
          );
          expect(
            field.controller?.selection.baseOffset,
            tokenStart,
            reason: '光标必须停在删除区间起点，也就是原缩进末尾',
          );
          expect(notifier.draftTexts.last, after);
          expect(notifier.state.draftText, after);
        }

        // token 独占行尾：保留缩进与后面的换行。
        await removeAtLineEnd('first\n\t  \$review\nlast', 'first\n\t  \nlast');
        // token 后最多再吃掉一个横向空格，但换行必须保留。
        await removeAtLineEnd(
          'alpha\n    \$review \nomega',
          'alpha\n    \nomega',
        );

        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });

  group('draft working directory', () {
    testWidgets('clearing it keeps draft text and attachments', (tester) async {
      final notifier = _ContextNotifier(
        _draftState(
          directory: '/srv/project',
          draftText: 'unsent draft',
          supportsTextAttachments: true,
          attachments: [
            AcpPromptAttachment(
              name: 'notes.txt',
              mimeType: 'text/plain',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
          ],
        ),
      );
      await _pumpChat(tester, notifier);

      expect(find.byKey(_clearDirKey), findsOneWidget);
      expect(find.text('/srv/project'), findsOneWidget);
      expect(find.byKey(const Key('chat_attachment_chip_0')), findsOneWidget);

      await tester.tap(find.byKey(_clearDirKey));
      await tester.pumpAndSettle();

      expect(find.byKey(_clearDirKey), findsNothing);
      expect(find.text('/srv/project'), findsNothing);
      expect(find.text('Default (/)'), findsOneWidget);
      expect(notifier.state.draftWorkingDirectory, isNull);

      final field = tester.widget<TextField>(find.byKey(_promptKey));
      expect(field.controller?.text, 'unsent draft');
      expect(notifier.state.attachments, hasLength(1));
      expect(find.byKey(const Key('chat_attachment_chip_0')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('an existing active session directory stays immutable', (
      tester,
    ) async {
      final session = _session();
      final notifier = _ContextNotifier(
        AiChatState(
          sessions: [session],
          activeSessionId: session.id,
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
          draftWorkingDirectory: '/srv/draft',
        ),
      );
      await _pumpChat(tester, notifier);

      expect(find.byKey(_clearDirKey), findsNothing);
      expect(find.text('/srv/session'), findsOneWidget);

      await tester.tap(find.byKey(_workingDirKey));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(notifier.state.activeSession?.workingDirectory, '/srv/session');
      expect(notifier.state.draftWorkingDirectory, '/srv/draft');
    });
  });

  group('draft attachments', () {
    testWidgets(
      'image preview still opens and both attachments can be removed',
      (tester) async {
        final bytes = await tinyPngBytes(tester);
        final notifier = _ContextNotifier(
          _draftState(
            supportsImages: true,
            supportsTextAttachments: true,
            attachments: [
              AcpPromptAttachment(
                name: 'draft.png',
                mimeType: 'image/png',
                bytes: bytes,
              ),
              AcpPromptAttachment(
                name: 'notes.txt',
                mimeType: 'text/plain',
                bytes: Uint8List.fromList([4, 5, 6]),
              ),
            ],
          ),
        );
        await _pumpChat(tester, notifier);

        final imageChip = find.byKey(const Key('chat_attachment_chip_0'));
        final textChip = find.byKey(const Key('chat_attachment_chip_1'));
        expect(imageChip, findsOneWidget);
        expect(textChip, findsOneWidget);
        expect(
          find.descendant(
            of: imageChip,
            matching: find.byIcon(Icons.broken_image_outlined),
          ),
          findsNothing,
        );

        await tester.tap(imageChip);
        await tester.pumpAndSettle();
        expect(find.byType(ImageZoomDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ImageZoomDialog),
            matching: find.byType(Image),
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(
            of: find.byType(ImageZoomDialog),
            matching: find.byIcon(Icons.close),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ImageZoomDialog), findsNothing);

        await tester.tap(
          find.descendant(of: textChip, matching: find.byIcon(Icons.close)),
        );
        await tester.pumpAndSettle();
        expect(notifier.state.attachments, hasLength(1));
        expect(notifier.state.attachments.single.name, 'draft.png');
        expect(textChip, findsNothing);

        await tester.tap(
          find.descendant(of: imageChip, matching: find.byIcon(Icons.close)),
        );
        await tester.pumpAndSettle();
        expect(notifier.state.attachments, isEmpty);
        expect(imageChip, findsNothing);
      },
    );
  });

  group('capabilities', () {
    testWidgets(
      'attachment menu preserves capability gating and creates no session',
      (tester) async {
        final notifier = _ContextNotifier(_draftState());
        await _pumpChat(tester, notifier);

        PopupMenuItem<String> item(String label) {
          final finder = find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate(
              (widget) => widget is PopupMenuItem<String>,
            ),
          );
          return tester.widget<PopupMenuItem<String>>(finder.first);
        }

        await tester.tap(find.byKey(_attachmentsKey));
        await tester.pumpAndSettle();
        expect(item('Attach local image').enabled, isFalse);
        expect(item('Attach local text file').enabled, isFalse);
        expect(item('Attach remote text file').enabled, isFalse);
        expect(find.text('Refresh'), findsOneWidget);
        expect(notifier.state.sessions, isEmpty);
        expect(notifier.state.activeSessionId, isNull);

        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();

        notifier.emit(notifier.state.copyWith(supportsTextAttachments: true));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_attachmentsKey));
        await tester.pumpAndSettle();
        expect(item('Attach local image').enabled, isFalse);
        expect(item('Attach local text file').enabled, isTrue);
        expect(item('Attach remote text file').enabled, isTrue);
        expect(find.text('Refresh'), findsNothing);

        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();

        notifier.emit(
          notifier.state.copyWith(
            supportsImages: true,
            supportsTextAttachments: false,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_attachmentsKey));
        await tester.pumpAndSettle();
        expect(item('Attach local image').enabled, isTrue);
        expect(item('Attach local text file').enabled, isFalse);
        expect(item('Attach remote text file').enabled, isFalse);

        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
      },
    );
  });

  group('narrow and large text', () {
    testWidgets('320dp at text scale 1.5 does not overflow the composer', (
      tester,
    ) async {
      const longSkill =
          r'$a_very_long_skill_name_that_must_wrap_without_overflow';
      final notifier = _ContextNotifier(
        _draftState(
          commands: const [
            AcpSlashCommand(longSkill, 'A long skill name', 'skill'),
          ],
          directory: '/srv/a/very/long/working/directory/for/the/draft',
          supportsImages: true,
          supportsTextAttachments: true,
          attachments: [
            AcpPromptAttachment(
              name: 'a-very-long-attachment-name-that-should-ellipsize.txt',
              mimeType: 'text/plain',
              bytes: Uint8List.fromList([7, 8, 9]),
            ),
          ],
        ),
      );

      await _pumpChat(
        tester,
        notifier,
        size: const Size(320, 640),
        textScaler: const TextScaler.linear(1.5),
      );

      await tester.enterText(find.byKey(_promptKey), 'please $longSkill now');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(Key('chat_skill_chip_$longSkill')), findsOneWidget);
      expect(find.byKey(const Key('chat_attachment_chip_0')), findsOneWidget);
      expect(find.byKey(_clearDirKey), findsOneWidget);
      expect(find.byKey(_promptKey), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
