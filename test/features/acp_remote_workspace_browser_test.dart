import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:valhalla/core/services/remote_browser_service.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/remote_browser.dart';
import 'package:valhalla/widgets/remote_browser_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/features/chat/widgets/remote_workspace_browser_dialog.dart';
import 'package:valhalla/infrastructure/acp/acp_client_adapter.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart';

/// 远端文件/目录浏览选择器的控件回归。
/// 目录数据来自 [FakeWorkspace]，通过内存 SSH 响应走真实浏览适配器。
/// 绝不建立远端 SSH 连接或 ACP 会话。

// Public wrapper + real agentRemoteBrowser/AcpWorkspaceFiles with memory SSH.
AgentProfile _profile() => harnessAgent.copyWith(
  executionTarget: 'docker',
  containerBinding: 'name',
  containerReference: 'test-workspace',
  containerUser: 'dev',
);

class _Chat extends FakeAcpChatNotifier {
  _Chat({bool images = true, bool text = true})
    : super(
        AiChatState(
          activeAgentProfile: _profile(),
          supportsImages: images,
          supportsTextAttachments: text,
        ),
      );
  int legacyReads = 0, createCalls = 0;
  void replace(AiChatState value) => state = value;
  AiChatState get snapshot => state;
  @override
  Future<void> createNewSession([String? title]) async {
    createCalls++;
  }

  @override
  Future<String> resolveWorkspaceDirectory() async {
    legacyReads++;
    throw StateError('Must use shared browser factory');
  }

  @override
  Future<List<SftpFileItem>> listWorkspaceFiles(String path) async {
    legacyReads++;
    throw StateError('Must use real agent browser');
  }
}

class _BrowserFactory extends RemoteBrowserFactory {
  _BrowserFactory(super.ref, this.client, this.returnGate);
  final _WorkspaceClient client;
  final Completer<void>? returnGate;
  final profiles = <AgentProfile>[];
  final sources = <RemoteBrowserSource>[];
  final guards = <bool Function()>[];
  @override
  Future<RemoteBrowserSource> agent({
    required AgentProfile profile,
    required bool Function() isCurrent,
    String? initialPath,
  }) async {
    profiles.add(profile);
    guards.add(isCurrent);
    final source = await agentRemoteBrowser(
      client: client,
      profile: profile,
      targetKey: 'fake-target',
      initialPath: initialPath,
      isCurrent: isCurrent,
    );
    sources.add(source);
    if (returnGate != null) await returnGate!.future;
    return source;
  }
}

class _WorkspaceClient extends Fake implements SSHClient {
  _WorkspaceClient(this.workspace);
  final FakeWorkspace workspace;
  final commands = <String>[];
  final sessions = <_ReplySession>[];
  int closeCalls = 0;
  @override
  bool get isClosed => false;
  @override
  Future<void> close() async {
    closeCalls++;
  }

  String _pathIn(String command, Iterable<String> candidates) {
    final paths = candidates.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return paths.firstWhere(command.contains, orElse: () => '/');
  }

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) async {
    commands.add(command);
    final reply = _ReplySession(() => workspace.cancelCount++);
    sessions.add(reply);
    if (command.contains('pwd -P')) {
      workspace.resolveCount++;
      reply.finish(utf8.encode('${workspace.initialPath}\n'));
    } else if (command.contains('find -H')) {
      final path = _pathIn(command, workspace.directories.keys);
      workspace.listedPaths.add(path);
      Future<void> respond() async {
        final gate = workspace.listGate;
        if (gate != null) await gate.future;
        if (reply.closed) return;
        final error = workspace.failures[path];
        if (error != null) {
          reply.finish(const [], exit: 1, error: error.toString());
          return;
        }
        final records = workspace.directories[path]!.map(
          (item) =>
              '${item.name}\u0000${item.isDirectory ? 'dd' : 'ff'}'
              '\u0000${item.sizeBytes}\u00001759000000\u0000',
        );
        reply.finish(utf8.encode(records.join()));
      }

      unawaited(respond());
    } else if (command.contains('head -c')) {
      final path = _pathIn(command, workspace.previews.keys);
      final preview = workspace.previews[path];
      reply.finish(preview ?? const [], exit: preview == null ? 1 : 0);
    } else {
      throw StateError('Unexpected non-browser command: $command');
    }
    return reply;
  }
}

class _ReplySession extends Fake implements SSHSession {
  _ReplySession(this.onClose);
  final void Function() onClose;
  final _out = StreamController<Uint8List>(),
      _err = StreamController<Uint8List>();
  final _done = Completer<void>();
  bool closed = false, finished = false;
  int _exit = 0;
  @override
  Stream<Uint8List> get stdout => _out.stream;
  @override
  Stream<Uint8List> get stderr => _err.stream;
  @override
  Future<void> get done => _done.future;
  @override
  int? get exitCode => _exit;
  void finish(List<int> output, {int exit = 0, String error = ''}) {
    if (closed || finished) return;
    finished = true;
    _exit = exit;
    _out.add(Uint8List.fromList(output));
    if (error.isNotEmpty) _err.add(Uint8List.fromList(utf8.encode(error)));
    unawaited(_out.close());
    unawaited(_err.close());
    _done.complete();
  }

  @override
  void close() {
    if (closed) return;
    closed = true;
    onClose();
    if (finished) return;
    finished = true;
    unawaited(_out.close());
    unawaited(_err.close());
    _done.complete();
  }
}

class _Harness {
  _Harness(
    this.workspace, {
    this.returnGate,
    bool images = true,
    bool text = true,
  }) : client = _WorkspaceClient(workspace),
       chat = _Chat(images: images, text: text);
  final FakeWorkspace workspace;
  final _WorkspaceClient client;
  final _Chat chat;
  final Completer<void>? returnGate;
  final callerVisible = ValueNotifier(true);
  late _BrowserFactory factory;
  Object? result, error;
  bool completed = false;
  Future<void> mount(
    WidgetTester tester, {
    RemoteBrowserMode mode = RemoteBrowserMode.files,
    String? initialPath,
    Locale locale = const Locale('en'),
  }) async {
    addTearDown(() {
      if (returnGate != null && !returnGate!.isCompleted) {
        returnGate!.complete();
      }
      if (workspace.listGate != null && !workspace.listGate!.isCompleted) {
        workspace.listGate!.complete();
      }
      for (final source in factory.sources) {
        // Closing the fake channels is synchronous; a completed lease future
        // may belong to the widget fake-async zone after the test has ended.
        unawaited(source.dispose());
      }
      callerVisible.dispose();
    });
    await pumpAcpHarness(
      tester,
      notifier: chat,
      locale: locale,
      extraOverrides: [
        remoteBrowserFactoryProvider.overrideWith(
          (ref) => factory = _BrowserFactory(ref, client, returnGate),
        ),
      ],
      child: ValueListenableBuilder<bool>(
        valueListenable: callerVisible,
        builder: (_, visible, child) => visible
            ? Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      try {
                        result = await RemoteWorkspaceBrowserDialog.show(
                          context,
                          initialPath: initialPath,
                          mode: mode,
                        );
                      } catch (caught) {
                        error = caught;
                      } finally {
                        completed = true;
                      }
                    },
                    child: const Text('open'),
                  ),
                ),
              )
            : const Scaffold(body: Text('Caller removed')),
      ),
    );
    await tester.tap(find.text('open'));
    await _frames(tester);
  }
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 350));
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

Future<void> _tapEntry(WidgetTester tester, String name) async {
  final entry = find.text(name).last;
  await tester.ensureVisible(entry);
  await tester.pump();
  await tester.tap(entry);
}

bool _canConfirm(WidgetTester tester) =>
    tester
        .widget<FilledButton>(
          find.byKey(const Key('remote_browser_confirm_button')),
        )
        .onPressed !=
    null;

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

  Future<_Harness> openBrowser(
    WidgetTester tester, {
    required FakeWorkspace workspace,
    RemoteBrowserMode mode = RemoteBrowserMode.files,
    String? initialPath,
    bool images = true,
    bool text = true,
    Locale locale = const Locale('en'),
  }) async {
    final harness = _Harness(workspace, images: images, text: text);
    await harness.mount(
      tester,
      mode: mode,
      initialPath: initialPath,
      locale: locale,
    );
    expect(find.byType(RemoteBrowserDialog), findsOneWidget);
    expect(harness.error, isNull);
    expect(harness.chat.legacyReads, 0);
    return harness;
  }

  bool parentButtonEnabled(WidgetTester tester) {
    final button = tester.widget<IconButton>(
      find.byKey(const Key('remote_browser_up_button')),
    );
    return button.onPressed != null;
  }

  group('根目录与上级导航', () {
    testWidgets('根目录禁用上级按钮，非根目录可 POSIX 上一级', (tester) async {
      final workspace = buildWorkspace(initialPath: '/docs');
      await openBrowser(tester, workspace: workspace, initialPath: '/docs');

      expect(parentButtonEnabled(tester), isTrue);
      expect(find.text('guide.md'), findsOneWidget);

      await tester.tap(find.byKey(const Key('remote_browser_up_button')));
      await _frames(tester);

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

    testWidgets('目录模式不能选择文件，隐藏 . 与 .. 条目', (tester) async {
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
      // 文件可隐藏或灰显，但不能成为目录选择。
      if (find.text('readme.md').evaluate().isNotEmpty) {
        await tester.tap(find.text('readme.md'));
        await _frames(tester);
        expect(find.byIcon(Icons.check_circle), findsNothing);
      }
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
        find.byKey(const Key('remote_browser_search')),
        'readme',
      );
      await _frames(tester);
      expect(find.text('readme.md'), findsOneWidget);
      expect(find.text('docs'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('remote_browser_search')),
        'docs',
      );
      await _frames(tester);
      await tester.tap(find.text('docs', findRichText: false).last);
      await _frames(tester);

      final search = tester.widget<TextField>(
        find.byKey(const Key('remote_browser_search')),
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
      expect(find.byIcon(Icons.grid_view), findsOneWidget);

      await tester.tap(find.byIcon(Icons.grid_view));
      await _frames(tester);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('docs'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.image));
      await _frames(tester);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('docs'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.view_list));
      await _frames(tester);
      expect(find.byType(ListView), findsWidgets);
      expect(find.text('docs'), findsOneWidget);
    });

    testWidgets('图片网格通过 provider 取预览，Widget 不直连 SSH', (tester) async {
      final bytes = await tinyPngBytes(tester);
      final workspace = buildWorkspace();
      workspace.previews['/media/logo.png'] = bytes;

      await openBrowser(tester, workspace: workspace, initialPath: '/media');

      await tester.tap(find.byIcon(Icons.image));
      await _frames(tester);

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
      await _frames(tester);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RemoteBrowserDialog)),
      );
      expect(find.text(l10n.stateError), findsOneWidget);
      final confirm = tester.widget<FilledButton>(
        find.byKey(const Key('remote_browser_confirm_button')),
      );
      expect(confirm.onPressed, isNull);
    });

    testWidgets('关闭后到达的迟到结果被安全丢弃', (tester) async {
      final workspace = buildWorkspace();
      final gate = Completer<void>();
      workspace.listGate = gate;

      await openBrowser(tester, workspace: workspace);
      // 列表仍在等待远端结果时关闭对话框
      await tester.tap(find.byIcon(Icons.close).last);
      await _frames(tester);
      expect(find.byType(RemoteBrowserDialog), findsNothing);

      // 迟到结果到达，不得抛出异常或重建界面
      gate.complete();
      await _frames(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(RemoteBrowserDialog), findsNothing);
      expect(workspace.cancelCount, greaterThan(0));
    });
  });

  group('文件能力与计数', () {
    testWidgets('已用额度与文件大小限制在选择前生效', (tester) async {
      final workspace = buildWorkspace();
      workspace.directories['/docs']!.addAll([
        FakeWorkspace.file(
          'large.md',
          '/docs',
          sizeBytes: AcpPromptAttachment.maxTextBytes + 1,
        ),
        FakeWorkspace.file(
          'large.png',
          '/docs',
          sizeBytes: AcpPromptAttachment.maxImageBytes + 1,
        ),
      ]);
      final harness = await openBrowser(
        tester,
        workspace: workspace,
        initialPath: '/docs',
      );
      for (final name in ['large.md', 'large.png']) {
        if (find.text(name).evaluate().isNotEmpty) {
          await _tapEntry(tester, name);
          await _frames(tester);
        }
      }
      expect(_canConfirm(tester), isFalse);
      await _tapEntry(tester, 'guide.md');
      await _frames(tester);
      expect(_canConfirm(tester), isTrue);

      harness.chat.replace(
        harness.chat.snapshot.copyWith(
          attachments: [
            AcpPromptAttachment(
              name: 'already-attached.md',
              mimeType: 'text/plain',
              bytes: Uint8List(AcpPromptAttachment.maxTextBytes),
            ),
          ],
        ),
      );
      await _frames(tester);
      if (_canConfirm(tester)) {
        await tester.tap(
          find.byKey(const Key('remote_browser_confirm_button')),
        );
        await _frames(tester);
      }
      expect(harness.result, isNull);
      expect(harness.chat.sendMessageCalls, 0);
    });

    testWidgets('无文本能力时只允许支持的图片', (tester) async {
      final harness = await openBrowser(
        tester,
        workspace: buildWorkspace(),
        initialPath: '/docs',
        text: false,
      );
      if (find.text('guide.md').evaluate().isNotEmpty) {
        await _tapEntry(tester, 'guide.md');
        await _frames(tester);
      }
      expect(_canConfirm(tester), isFalse);
      await _tapEntry(tester, 'diagram.png');
      await _frames(tester);
      await tester.tap(find.byKey(const Key('remote_browser_confirm_button')));
      await _frames(tester);
      expect(harness.result, ['/docs/diagram.png']);
    });

    for (final images in [true, false]) {
      testWidgets('图片支持=$images 时文件过滤与计数准确', (tester) async {
        final workspace = buildWorkspace();
        workspace.directories['/docs']!.add(
          FakeWorkspace.file('archive.zip', '/docs'),
        );
        final harness = await openBrowser(
          tester,
          workspace: workspace,
          initialPath: '/docs',
          images: images,
        );
        for (final name in ['guide.md', 'diagram.png', 'archive.zip']) {
          if (find.text(name).evaluate().isNotEmpty) {
            await _tapEntry(tester, name);
            await _frames(tester);
          }
        }
        final expected = ['/docs/guide.md', if (images) '/docs/diagram.png'];
        final l10n = AppLocalizations.of(
          tester.element(find.byType(RemoteBrowserDialog)),
        );
        expect(
          find.text(l10n.remoteBrowserSelectedCount(expected.length)),
          findsOneWidget,
        );
        expect(_canConfirm(tester), isTrue);
        await tester.tap(
          find.byKey(const Key('remote_browser_confirm_button')),
        );
        await _frames(tester);
        expect(harness.result, unorderedEquals(expected));
      });
    }
  });

  group('目标绑定与会话生命周期', () {
    testWidgets('状态更新不使相同执行目标的选择失效', (tester) async {
      final harness = await openBrowser(
        tester,
        workspace: buildWorkspace(),
        initialPath: '/docs',
      );
      await _tapEntry(tester, 'guide.md');
      await _frames(tester);
      harness.chat.replace(
        harness.chat.snapshot.copyWith(
          activeAgentProfile: harness.chat.snapshot.activeAgentProfile!
              .copyWith(),
        ),
      );
      await _frames(tester);
      expect(harness.factory.guards.single(), isTrue);
      await tester.tap(find.byKey(const Key('remote_browser_confirm_button')));
      await _frames(tester);
      expect(harness.result, ['/docs/guide.md']);
      expect(harness.chat.createCalls, 0);
    });

    for (final change in ['container', 'user', 'session', 'draft-directory']) {
      testWidgets('$change 改变后旧浏览器不可确认到新目标', (tester) async {
        final harness = await openBrowser(
          tester,
          workspace: buildWorkspace(),
          initialPath: '/docs',
        );
        await _tapEntry(tester, 'guide.md');
        await _frames(tester);
        expect(_canConfirm(tester), isTrue);
        final state = harness.chat.snapshot;
        final profile = state.activeAgentProfile!;
        harness.chat.replace(switch (change) {
          'container' => state.copyWith(
            activeAgentProfile: profile.copyWith(
              containerReference: 'another-workspace',
            ),
          ),
          'user' => state.copyWith(
            activeAgentProfile: profile.copyWith(containerUser: 'root'),
          ),
          'session' => state.copyWith(activeSessionId: 'another-session'),
          _ => state.copyWith(draftWorkingDirectory: '/another-draft'),
        });
        await _frames(tester);
        expect(harness.factory.guards.single(), isFalse);
        if (find
                .byKey(const Key('remote_browser_confirm_button'))
                .evaluate()
                .isNotEmpty &&
            _canConfirm(tester)) {
          await tester.tap(
            find.byKey(const Key('remote_browser_confirm_button')),
          );
          await _frames(tester);
        }
        expect(harness.result, isNull);
        expect(harness.chat.createCalls, 0);
        expect(harness.chat.sendMessageCalls, 0);
      });
    }

    testWidgets('等待 factory 时离开调用界面不弹迟到窗口且释放 source', (tester) async {
      final gate = Completer<void>();
      final harness = _Harness(buildWorkspace(), returnGate: gate);
      await harness.mount(tester, initialPath: '/');
      expect(harness.factory.sources, hasLength(1));
      expect(find.byType(RemoteBrowserDialog), findsNothing);
      harness.callerVisible.value = false;
      await _frames(tester);
      gate.complete();
      await _frames(tester);
      expect(harness.completed, isTrue);
      expect(harness.error, isNull);
      expect(harness.result, isNull);
      expect(find.byType(RemoteBrowserDialog), findsNothing);
      expect(harness.factory.sources.single.isCurrent, isFalse);
      expect(harness.workspace.listedPaths, isEmpty);
      expect(harness.client.closeCalls, 0);
    });

    testWidgets('取消草稿浏览不创建 ACP/CLI 会话也不发送消息', (tester) async {
      final harness = await openBrowser(tester, workspace: buildWorkspace());
      await tester.tap(find.byIcon(Icons.close).last);
      await _frames(tester);
      expect(harness.completed, isTrue);
      expect(harness.result, isNull);
      expect(harness.chat.snapshot.activeSessionId, isNull);
      expect(harness.chat.snapshot.sessions, isEmpty);
      expect(harness.chat.createCalls, 0);
      expect(harness.chat.sendMessageCalls, 0);
      expect(harness.chat.legacyReads, 0);
      expect(harness.client.commands, isNotEmpty);
      for (final command in harness.client.commands) {
        expect(command, startsWith('docker exec -i'));
        expect(command, contains("--user 'dev'"));
        expect(command, contains("'test-workspace'"));
        expect(command, isNot(contains('harness-acp')));
        expect(command, isNot(contains('harness-cli')));
      }
      expect(harness.factory.sources.single.isCurrent, isFalse);
      expect(harness.client.closeCalls, 0);
    });
  });

  group('本地化', () {
    testWidgets('中文下浏览选择器文案完整', (tester) async {
      await openBrowser(
        tester,
        workspace: buildWorkspace(),
        locale: const Locale('zh'),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(RemoteBrowserDialog)),
      );
      expect(find.text(l10n.remoteBrowserTitle), findsOneWidget);
      expect(find.text(l10n.cancel), findsOneWidget);
      expect(find.text(l10n.remoteBrowserSearchHint), findsOneWidget);
      expect(find.text('remoteBrowserTitle'), findsNothing);
    });
  });
}
