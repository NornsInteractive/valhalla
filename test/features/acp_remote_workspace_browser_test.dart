import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/features/chat/widgets/remote_workspace_browser_dialog.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart';

/// 远端文件/目录浏览选择器的控件回归。
/// 目录数据全部来自内存替身 [FakeWorkspace]，绝不建立 SSH 连接。

void main() {
  FakeWorkspace buildWorkspace({String initialPath = '/'}) {
    final workspace = FakeWorkspace(initialPath: initialPath);
    workspace
      ..add('/', [
        FakeWorkspace.dir('docs', '/'),
        FakeWorkspace.dir('media', '/'),
        FakeWorkspace.file('readme.md', '/'),
      ])
      ..add('/docs', [
        FakeWorkspace.dir('deep', '/docs'),
        FakeWorkspace.file('guide.md', '/docs'),
        FakeWorkspace.file('diagram.png', '/docs', sizeBytes: 2048),
      ])
      ..add('/docs/deep', [FakeWorkspace.file('nested.md', '/docs/deep')])
      ..add('/media', [
        FakeWorkspace.file('logo.png', '/media', sizeBytes: 900),
      ]);
    return workspace;
  }

  Future<void> openBrowser(
    WidgetTester tester, {
    required FakeWorkspace workspace,
    RemoteBrowserMode mode = RemoteBrowserMode.files,
    String? initialPath,
    bool settle = true,
  }) async {
    final notifier = FakeAcpChatNotifier(
      const AiChatState(supportsImages: true, supportsTextAttachments: true),
      workspace: workspace,
    );
    await pumpAcpHarness(
      tester,
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => RemoteWorkspaceBrowserDialog.show(
                context,
                initialPath: initialPath,
                mode: mode,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      notifier: notifier,
    );
    await tester.tap(find.text('open'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // 列表请求被 gate 挂起时不能用 pumpAndSettle（进度指示器永不静止）
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.byKey(const Key('remote_workspace_browser_dialog')),
      findsOneWidget,
    );
  }

  bool parentButtonEnabled(WidgetTester tester) {
    final button = tester.widget<IconButton>(
      find.byKey(const Key('chat_browser_parent_button')),
    );
    return button.onPressed != null;
  }

  group('根目录与上级导航', () {
    testWidgets('根目录禁用上级按钮，非根目录可 POSIX 上一级', (tester) async {
      final workspace = buildWorkspace(initialPath: '/docs');
      await openBrowser(tester, workspace: workspace, initialPath: '/docs');

      expect(parentButtonEnabled(tester), isTrue);
      expect(find.text('guide.md'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat_browser_parent_button')));
      await tester.pumpAndSettle();

      expect(workspace.listedPaths, containsAllInOrder(['/docs', '/']));
      expect(parentButtonEnabled(tester), isFalse);
      expect(find.text('media'), findsOneWidget);
    });

    testWidgets('默认打开自动 resolve，不把「默认(/)」当路径传入', (tester) async {
      final workspace = buildWorkspace(initialPath: '/docs');
      await openBrowser(tester, workspace: workspace);

      expect(workspace.resolveCount, 1);
      expect(workspace.listedPaths, ['/docs']);
      expect(find.text('guide.md'), findsOneWidget);
    });

    testWidgets('目录模式只列目录，隐藏 . 与 .. 条目', (tester) async {
      final workspace = buildWorkspace();
      // 即使远端返回了 . / ..，界面也不得把它们当条目展示
      workspace.add('/', [
        const SftpFileItem(
          name: '.',
          path: '/.',
          isDirectory: true,
          sizeBytes: 0,
          formattedSize: '-',
          permissions: 'drwxr-xr-x',
          modified: '2026-09-30 10:00',
        ),
        const SftpFileItem(
          name: '..',
          path: '/..',
          isDirectory: true,
          sizeBytes: 0,
          formattedSize: '-',
          permissions: 'drwxr-xr-x',
          modified: '2026-09-30 10:00',
        ),
        FakeWorkspace.dir('docs', '/'),
        FakeWorkspace.dir('media', '/'),
        FakeWorkspace.file('readme.md', '/'),
      ]);

      await openBrowser(
        tester,
        workspace: workspace,
        mode: RemoteBrowserMode.directory,
      );

      expect(find.text('docs'), findsOneWidget);
      expect(find.text('media'), findsOneWidget);
      // 文件在目录模式不可见，根目录也不出现 . / ..
      expect(find.text('readme.md'), findsNothing);
      expect(find.text('.'), findsNothing);
      expect(find.text('..'), findsNothing);
      expect(find.text('No files found'), findsNothing);
    });
  });

  group('切目录清筛选与独立搜索', () {
    testWidgets('搜索后进入子目录，筛选被清空', (tester) async {
      final workspace = buildWorkspace();
      await openBrowser(tester, workspace: workspace);

      await tester.enterText(
        find.byKey(const Key('chat_browser_search_input')),
        'readme',
      );
      await tester.pumpAndSettle();
      expect(find.text('readme.md'), findsOneWidget);
      expect(find.text('docs'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('chat_browser_search_input')),
        '',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('docs'));
      await tester.pumpAndSettle();

      final search = tester.widget<TextField>(
        find.byKey(const Key('chat_browser_search_input')),
      );
      expect(search.controller?.text, isEmpty);
      // 未加筛选时子目录内容全部可见
      expect(find.text('guide.md'), findsOneWidget);
      expect(find.text('diagram.png'), findsOneWidget);
      expect(find.text('deep'), findsOneWidget);
    });
  });

  group('三视图切换', () {
    testWidgets('列表/卡片/图片三种视图可切换且都渲染条目', (tester) async {
      final workspace = buildWorkspace();
      await openBrowser(tester, workspace: workspace);

      // 默认列表视图
      expect(find.byType(ListView), findsWidgets);
      expect(find.byType(GridView), findsNothing);
      expect(find.byIcon(Icons.view_list), findsOneWidget);
      expect(find.byIcon(Icons.grid_view), findsOneWidget);
      expect(find.byIcon(Icons.image), findsOneWidget);

      await tester.tap(find.byIcon(Icons.grid_view));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('docs'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.image));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('docs'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.view_list));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsWidgets);
      expect(find.text('docs'), findsOneWidget);
    });

    testWidgets('图片网格通过 provider 取预览，Widget 不直连 SSH', (tester) async {
      final bytes = await tinyPngBytes(tester);
      final workspace = buildWorkspace();
      workspace.previews['/media/logo.png'] = bytes;

      await openBrowser(tester, workspace: workspace, initialPath: '/media');

      await tester.tap(find.byIcon(Icons.image));
      await tester.pumpAndSettle();

      final thumbnail = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Image),
      );
      expect(thumbnail, findsOneWidget);
    });
  });

  group('失败目录与迟到结果', () {
    testWidgets('读取失败的目录不允许确认并显示错误', (tester) async {
      final workspace = buildWorkspace();
      workspace.failures['/docs'] = StateError('ACP_FILE_READ_FAILED');

      await openBrowser(
        tester,
        workspace: workspace,
        mode: RemoteBrowserMode.directory,
      );

      await tester.tap(find.text('docs'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ACP_FILE_READ_FAILED'), findsOneWidget);
      final confirm = tester.widget<FilledButton>(
        find.byKey(const Key('chat_select_directory_confirm_button')),
      );
      expect(confirm.onPressed, isNull);
    });

    testWidgets('关闭后到达的迟到结果被安全丢弃', (tester) async {
      final workspace = buildWorkspace();
      final gate = Completer<void>();
      workspace.listGate = gate;

      await openBrowser(tester, workspace: workspace, settle: false);
      // 列表仍在等待远端结果时关闭对话框
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('remote_workspace_browser_dialog')),
        findsNothing,
      );

      // 迟到结果到达，不得抛出异常或重建界面
      gate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('remote_workspace_browser_dialog')),
        findsNothing,
      );
      expect(workspace.cancelCount, greaterThan(0));
    });
  });

  group('本地化', () {
    testWidgets('中文下浏览选择器文案完整', (tester) async {
      final workspace = buildWorkspace();
      final notifier = FakeAcpChatNotifier(
        const AiChatState(supportsImages: true, supportsTextAttachments: true),
        workspace: workspace,
      );

      await pumpAcpHarness(
        tester,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => RemoteWorkspaceBrowserDialog.show(
                  context,
                  mode: RemoteBrowserMode.files,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        notifier: notifier,
        locale: const Locale('zh'),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('remote_workspace_browser_dialog')),
        findsOneWidget,
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(RemoteWorkspaceBrowserDialog)),
      );
      expect(l10n.chatRemoteBrowserTitle, '远端工作区');
      expect(find.text(l10n.chatRemoteBrowserTitle), findsOneWidget);
      expect(find.text(l10n.cancel), findsOneWidget);
      expect(find.text(l10n.chatSearchFilesHint), findsOneWidget);
    });
  });
}
