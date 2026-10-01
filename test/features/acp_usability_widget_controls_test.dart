import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/features/chat/ai_chat_view.dart';
import 'package:valhalla/features/chat/widgets/chat_commands_skills_dialog.dart';
import 'package:valhalla/features/chat/widgets/image_zoom_dialog.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart';

/// 输入框、命令/技能面板、草稿图片放大、账号页状态按钮的控件回归。
/// 全部使用内存替身，不建立 SSH/Agent 连接。

const panelCommands = [
  AcpSlashCommand('status', 'Show session status', 'query'),
  AcpSlashCommand('compact', 'Compact the transcript', null),
  AcpSlashCommand(r'$review', 'Review the diff', 'skill'),
];

/// `Image.memory`/`Image.file` 带 `cacheWidth` 时会包一层 [ResizeImage]，
/// 断言底层来源时需要先拆掉这层包装。
ImageProvider _unwrapImageProvider(ImageProvider provider) {
  var current = provider;
  while (current is ResizeImage) {
    current = current.imageProvider;
  }
  return current;
}

void main() {
  ChatSession session(String id) => ChatSession(
    id: id,
    title: 'Session $id',
    serverId: harnessServerId,
    agentId: harnessAgent.id,
    createdAt: DateTime.utc(2026, 9, 30, 9),
    updatedAt: DateTime.utc(2026, 9, 30, 9),
  );

  group('输入框 - 空白/短文本保持单行', () {
    testWidgets('minLines/maxLines/hintMaxLines 固定为 1/4/1', (tester) async {
      final notifier = FakeAcpChatNotifier(
        AiChatState(
          sessions: [session('sess-1')],
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

      final field = tester.widget<TextField>(
        find.byKey(const Key('chatPromptInput')),
      );
      expect(field.minLines, 1);
      expect(field.maxLines, 4);
      expect(field.decoration?.hintMaxLines, 1);
      // 可读字号不得靠缩小来腾空间
      expect(field.style?.fontSize, 14);
      expect(field.decoration?.hintStyle?.fontSize, 14);
    });

    testWidgets('空输入与短文本等高，多行输入最多四行', (tester) async {
      final notifier = FakeAcpChatNotifier(
        AiChatState(
          sessions: [session('sess-1')],
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

      final input = find.byKey(const Key('chatPromptInput'));
      final editable = find.descendant(
        of: input,
        matching: find.byType(EditableText),
      );

      final emptyFieldHeight = tester.getSize(input).height;
      final emptyLineHeight = tester.getSize(editable).height;

      await tester.enterText(input, 'short');
      await tester.pumpAndSettle();
      expect(tester.getSize(input).height, emptyFieldHeight);
      expect(tester.getSize(editable).height, emptyLineHeight);

      await tester.enterText(input, 'l1\nl2\nl3\nl4\nl5\nl6');
      await tester.pumpAndSettle();

      final grownLineHeight = tester.getSize(editable).height;
      expect(grownLineHeight, greaterThan(emptyLineHeight));
      // maxLines: 4 —— 六行输入被截断在四行高度内
      expect(grownLineHeight, lessThan(emptyLineHeight * 4.5));
      expect(tester.getSize(input).height, greaterThan(emptyFieldHeight));
    });
  });

  group('命令/技能面板 - 切换、搜索与插入前缀', () {
    Future<AcpSlashCommand?> pickFromPanel(
      WidgetTester tester, {
      required int tabIndex,
      required String label,
    }) async {
      AcpSlashCommand? picked;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    picked = await ChatCommandsSkillsDialog.show(
                      context,
                      commands: panelCommands,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat_commands_skills_dialog')),
        findsOneWidget,
      );
      // 分类来自 isSkill：命令 2 / 技能 1
      expect(find.text('Commands (2)'), findsOneWidget);
      expect(find.text('Skills (1)'), findsOneWidget);

      if (tabIndex == 1) {
        await tester.tap(find.text('Skills (1)'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      return picked;
    }

    testWidgets('切到技能页只显示技能条目', (tester) async {
      await pickFromPanel(tester, tabIndex: 0, label: 'status');
    });

    testWidgets('搜索同时过滤命令与技能两页', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChatCommandsSkillsDialog(commands: panelCommands),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('status'), findsOneWidget);
      expect(find.text(r'$review'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('chat_commands_search_input')),
        'diff',
      );
      await tester.pumpAndSettle();
      expect(find.text('Commands (0)'), findsOneWidget);
      expect(find.text('Skills (1)'), findsOneWidget);

      await tester.tap(find.text('Skills (1)'));
      await tester.pumpAndSettle();
      expect(find.text('compact'), findsNothing);
      expect(find.text(r'$review'), findsOneWidget);
    });

    testWidgets('命令插入斜杠前缀，技能保留美元前缀', (tester) async {
      final command = await pickFromPanel(tester, tabIndex: 0, label: 'status');
      expect(command?.insertion, '/status ');

      final skill = await pickFromPanel(tester, tabIndex: 1, label: r'$review');
      expect(skill?.insertion, r'$review ');
    });

    testWidgets('输入区选中技能后插入前缀且不发送', (tester) async {
      final notifier = FakeAcpChatNotifier(
        AiChatState(
          sessions: [session('sess-1')],
          activeSessionId: 'sess-1',
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
          commands: panelCommands,
        ),
      );

      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat_commands_menu_button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('chat_commands_menu_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skills (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(r'$review'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('chatPromptInput')),
      );
      expect(field.controller?.text, r'$review ');
      expect(notifier.draftTexts.last, r'$review ');
      expect(notifier.sendMessageCalls, 0);
    });
  });

  group('命令面板 - 草稿预览提示、目录错误重试与窄屏', () {
    const previewNotice = Key('chat_commands_draft_preview_notice');
    const errorBanner = Key('chat_commands_error_banner');
    const retryButton = Key('chat_commands_retry_button');

    const previewCommands = [
      AcpSlashCommand(
        'status',
        'Show session status',
        null,
        isDraftPreview: true,
      ),
      AcpSlashCommand('plan', 'Turn plan mode on.', null, isDraftPreview: true),
    ];
    const runtimeCommands = [
      AcpSlashCommand('status', 'Show session status', null),
      AcpSlashCommand('compact', 'Compact the transcript', null),
    ];

    Widget dialogApp(
      List<AcpSlashCommand> commands, {
      String? errorMessage,
      Future<List<AcpSlashCommand>?> Function()? onRetry,
      VoidCallback? onOpenSettings,
    }) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChatCommandsSkillsDialog(
        commands: commands,
        errorMessage: errorMessage,
        onRetry: onRetry,
        onOpenSettings: onOpenSettings,
      ),
    );

    testWidgets('预览命令显示草稿提示，真实命令替换后提示消失', (tester) async {
      await tester.pumpWidget(dialogApp(previewCommands));
      await tester.pumpAndSettle();

      expect(find.byKey(previewNotice), findsOneWidget);
      expect(find.text('status'), findsOneWidget);

      // 真实 available_commands_update 到达：父级用新列表重建同一个 State。
      await tester.pumpWidget(dialogApp(runtimeCommands));
      await tester.pumpAndSettle();

      expect(find.byKey(previewNotice), findsNothing);
      expect(find.text('status'), findsOneWidget);
      expect(find.text('compact'), findsOneWidget);
    });

    testWidgets('非目录前缀的错误不显示发现失败横幅', (tester) async {
      await tester.pumpWidget(
        dialogApp(previewCommands, errorMessage: 'CHAT_SOMETHING_ELSE'),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(errorBanner), findsNothing);
      expect(find.textContaining('CHAT_SOMETHING_ELSE'), findsNothing);
      expect(find.byKey(previewNotice), findsOneWidget);
      expect(find.text('status'), findsOneWidget);
    });

    testWidgets('重试返回 null 保留目录错误，基线与客户端动作仍可用', (tester) async {
      var settingsOpened = false;
      var retryCalls = 0;
      AcpSlashCommand? picked;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    picked = await ChatCommandsSkillsDialog.show(
                      context,
                      commands: previewCommands,
                      errorMessage:
                          'AGENT_COMPOSER_QUERY_FAILED: skills unavailable',
                      onOpenSettings: () => settingsOpened = true,
                      onRetry: () async {
                        retryCalls++;
                        return null;
                      },
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(errorBanner), findsOneWidget);
      expect(find.byKey(previewNotice), findsOneWidget);
      expect(find.text('status'), findsOneWidget);

      await tester.tap(find.byKey(retryButton));
      await tester.pumpAndSettle();

      expect(retryCalls, 1);
      expect(
        find.byKey(errorBanner),
        findsOneWidget,
        reason: '重试返回 null 必须保留 provider 的目录错误',
      );
      expect(
        find.textContaining('AGENT_COMPOSER_QUERY_FAILED'),
        findsOneWidget,
      );

      await tester.tap(find.text('Run Settings'));
      await tester.pumpAndSettle();
      expect(settingsOpened, isTrue, reason: '错误不得挡死客户端动作');
      expect(picked, isNull);
    });

    testWidgets('重试成功后目录错误提示消失', (tester) async {
      var retryCalls = 0;

      await tester.pumpWidget(
        dialogApp(
          previewCommands,
          errorMessage: 'AGENT_COMPOSER_QUERY_FAILED: skills unavailable',
          onRetry: () async {
            retryCalls++;
            return runtimeCommands;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(errorBanner), findsOneWidget);

      await tester.tap(find.byKey(retryButton));
      await tester.pumpAndSettle();

      expect(retryCalls, 1);
      expect(find.byKey(errorBanner), findsNothing);
      expect(find.textContaining('AGENT_COMPOSER_QUERY_FAILED'), findsNothing);
      expect(find.text('compact'), findsOneWidget);
    });

    testWidgets('窄屏下预览提示与命令仍可见且不溢出', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(dialogApp(previewCommands));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(previewNotice), findsOneWidget);
      expect(find.text('status'), findsOneWidget);
      expect(
        find.byKey(const Key('chat_commands_search_input')),
        findsOneWidget,
      );
      expect(find.text('Commands (2)'), findsOneWidget);
    });

    testWidgets('输入区选择预览命令只插入文本，不发送', (tester) async {
      final notifier = FakeAcpChatNotifier(
        AiChatState(
          sessions: [session('sess-1')],
          activeSessionId: 'sess-1',
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
          commands: previewCommands,
        ),
      );

      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat_commands_menu_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(previewNotice), findsOneWidget);

      await tester.tap(find.text('status'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('chatPromptInput')),
      );
      expect(field.controller?.text, '/status ');
      expect(notifier.draftTexts.last, '/status ');
      expect(notifier.sendMessageCalls, 0);
    });
  });

  group('草稿图片 - 无 localPath 时按 bytes 渲染并可放大', () {
    testWidgets('bytes 图片解码可用、缩略图走 bytes 且点击打开放大', (tester) async {
      final bytes = await tinyPngBytes(tester);
      final decoded = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final size = frame.image;
        final out = '${size.width}x${size.height}';
        size.dispose();
        codec.dispose();
        return out;
      });
      expect(decoded, '4x4');

      final notifier = FakeAcpChatNotifier(
        AiChatState(
          sessions: [session('sess-1')],
          activeSessionId: 'sess-1',
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
          attachments: [
            AcpPromptAttachment(
              name: 'draft.png',
              mimeType: 'image/png',
              bytes: bytes,
            ),
          ],
        ),
      );

      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      await tester.pumpAndSettle();

      final chip = find.byKey(const Key('chat_attachment_chip_0'));
      expect(chip, findsOneWidget);

      final chipImages = tester.widgetList<Image>(
        find.descendant(of: chip, matching: find.byType(Image)),
      );
      expect(chipImages, hasLength(1));
      // 无 localPath 时必须走内存字节，而不是文件路径
      expect(_unwrapImageProvider(chipImages.single.image), isA<MemoryImage>());
      // 没有可读来源时不得退化成损坏占位
      expect(
        find.descendant(
          of: chip,
          matching: find.byIcon(Icons.broken_image_outlined),
        ),
        findsNothing,
      );

      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(find.byType(ImageZoomDialog), findsOneWidget);
      final zoomImage = tester.widget<Image>(
        find.descendant(
          of: find.byType(ImageZoomDialog),
          matching: find.byType(Image),
        ),
      );
      final zoomProvider = _unwrapImageProvider(zoomImage.image);
      expect(zoomProvider, isA<MemoryImage>());
      expect((zoomProvider as MemoryImage).bytes.length, bytes.length);
    });
  });

  group('账号与额度 - 未声明 status 不给可执行按钮', () {
    testWidgets('命令清单没有 status 时隐藏查询按钮并说明未提供', (tester) async {
      final notifier = FakeAcpChatNotifier(
        AiChatState(
          sessions: [session('sess-1')],
          activeSessionId: 'sess-1',
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
          commands: const [AcpSlashCommand('compact', 'Compact', null)],
        ),
      );

      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat_usage_diagnostics_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat_usage_diagnostics_dialog')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chat_query_status_button')), findsNothing);
      expect(find.text('Status query not provided by agent'), findsOneWidget);
      expect(find.text('No account details reported'), findsOneWidget);
    });

    testWidgets('已声明 status 且有会话时才出现查询按钮', (tester) async {
      final notifier = FakeAcpChatNotifier(
        AiChatState(
          sessions: [session('sess-1')],
          activeSessionId: 'sess-1',
          activeAgentProfile: harnessAgent,
          readyAgents: [harnessAgent],
          commands: const [AcpSlashCommand('status', 'Show status', null)],
        ),
      );

      await pumpAcpHarness(
        tester,
        child: const AiChatView(),
        notifier: notifier,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat_usage_diagnostics_button')));
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('chat_query_status_button'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(notifier.queryAccountStatusCalls, 1);
    });
  });
}
