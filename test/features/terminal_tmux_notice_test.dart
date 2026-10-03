import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/features/terminal/terminal_view.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

class _FakeBridge extends TerminalSessionBridge {
  _FakeBridge({
    TerminalSessionMode initialMode = TerminalSessionMode.plain,
    TerminalConnectionState initialState = TerminalConnectionState.connected,
    bool awaitingTmuxDecision = false,
  }) : _testMode = initialMode,
       _testAwaiting = awaitingTmuxDecision,
       super(terminal: Terminal(), serverName: 'test-server') {
    stateListenable.value = initialState;
  }

  TerminalSessionMode _testMode;
  bool _testAwaiting;

  @override
  TerminalSessionMode get mode => _testMode;

  @override
  bool get awaitingTmuxDecision => _testAwaiting;

  void setTestMode(TerminalSessionMode m) {
    _testMode = m;
  }

  void setTestState(TerminalConnectionState s) {
    stateListenable.value = s;
  }

  void setAwaitingTmuxDecision(bool awaiting) {
    _testAwaiting = awaiting;
  }
}

class _MockTerminalNotifier extends TerminalNotifier {
  final SshTerminalState _initial;
  bool skipCalled = false;
  bool confirmCalled = false;

  _MockTerminalNotifier(this._initial);

  @override
  SshTerminalState build() => _initial;

  @override
  Future<void> skipTmuxInstall() async {
    skipCalled = true;
  }

  @override
  Future<void> confirmTmuxInstall() async {
    confirmCalled = true;
  }
}

/// 画布会 watch 字号；这些用例不测字号，给固定值以免整棵树去读还没初始化的
/// LocalStorageService（会以 ProviderException 炸掉整个 build）。
class _FixedTerminalSettingsNotifier extends TerminalSettingsNotifier {
  @override
  TerminalSettings build() => const TerminalSettings();
}

Widget _buildTestApp({
  required _FakeBridge bridge,
  TmuxInstallOffer? tmuxInstallOffer,
  _MockTerminalNotifier? notifier,
  Locale locale = const Locale('en'),
}) {
  final tab = TerminalTab(
    id: 'tab-1',
    title: 'bash',
    terminal: bridge.terminal,
    bridge: bridge,
  );
  final state = SshTerminalState(
    tabs: [tab],
    activeTabIndex: 0,
    tmuxInstallOffer: tmuxInstallOffer,
  );
  final actualNotifier = notifier ?? _MockTerminalNotifier(state);

  return ProviderScope(
    overrides: [
      terminalProvider.overrideWith(() => actualNotifier),
      terminalSettingsProvider.overrideWith(_FixedTerminalSettingsNotifier.new),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SshTerminalView()),
    ),
  );
}

void main() {
  group('SshTerminalView tmux status notice', () {
    testWidgets(
      'shows terminalTmuxMissingNotice when tmuxUnavailable and dismisses on close',
      (tester) async {
        final bridge = _FakeBridge(
          initialMode: TerminalSessionMode.tmuxUnavailable,
        );

        await tester.pumpWidget(_buildTestApp(bridge: bridge));
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(
          find.byKey(const Key('terminalTmuxMissingNotice')),
          findsOneWidget,
        );
        expect(find.text(l10n.terminalTmuxMissingNotice), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

        // Tap close button
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        expect(
          find.byKey(const Key('terminalTmuxMissingNotice')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'shows terminalTmuxSessionRestored on reconnect and hides after 2 seconds',
      (tester) async {
        final bridge = _FakeBridge(
          initialMode: TerminalSessionMode.tmux,
          initialState: TerminalConnectionState.disconnected,
        );

        await tester.pumpWidget(_buildTestApp(bridge: bridge));
        await tester.pump();

        expect(
          find.byKey(const Key('terminalTmuxSessionRestored')),
          findsNothing,
        );

        // Transition to connected
        bridge.setTestState(TerminalConnectionState.connected);
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(
          find.byKey(const Key('terminalTmuxSessionRestored')),
          findsOneWidget,
        );
        expect(find.text(l10n.terminalTmuxSessionRestored), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

        // Wait 1 second - still visible
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.byKey(const Key('terminalTmuxSessionRestored')),
          findsOneWidget,
        );

        // Wait another 1.1 seconds - auto hides
        await tester.pump(const Duration(milliseconds: 1100));
        expect(
          find.byKey(const Key('terminalTmuxSessionRestored')),
          findsNothing,
        );
      },
    );

    testWidgets('shows nothing when bridge mode is plain', (tester) async {
      final bridge = _FakeBridge(
        initialMode: TerminalSessionMode.plain,
        initialState: TerminalConnectionState.connected,
      );

      await tester.pumpWidget(_buildTestApp(bridge: bridge));
      await tester.pump();

      expect(find.byKey(const Key('terminalTmuxMissingNotice')), findsNothing);
      expect(
        find.byKey(const Key('terminalTmuxSessionRestored')),
        findsNothing,
      );
    });

    testWidgets(
      'install offer shown when tmuxInstallOffer is set and hides missing notice',
      (tester) async {
        final bridge = _FakeBridge(
          initialMode: TerminalSessionMode.tmuxUnavailable,
          initialState: TerminalConnectionState.connected,
        );

        const offer = TmuxInstallOffer(
          installCommand: 'apt-get update && apt-get install -y tmux',
        );

        await tester.pumpWidget(
          _buildTestApp(bridge: bridge, tmuxInstallOffer: offer),
        );
        await tester.pump();

        expect(find.byKey(const Key('tmuxInstallOfferDialog')), findsOneWidget);
        expect(
          find.text('apt-get update && apt-get install -y tmux'),
          findsOneWidget,
        );
        // The old missing tmux notice must NOT be shown when the install offer is present
        expect(
          find.byKey(const Key('terminalTmuxMissingNotice')),
          findsNothing,
        );
      },
    );

    testWidgets('confirm calls confirmTmuxInstall', (tester) async {
      final bridge = _FakeBridge(
        initialMode: TerminalSessionMode.tmuxUnavailable,
        initialState: TerminalConnectionState.connected,
      );

      const offer = TmuxInstallOffer(
        installCommand: 'apt-get update && apt-get install -y tmux',
      );

      final tab = TerminalTab(
        id: 'tab-1',
        title: 'bash',
        terminal: bridge.terminal,
        bridge: bridge,
      );
      final notifier = _MockTerminalNotifier(
        SshTerminalState(
          tabs: [tab],
          activeTabIndex: 0,
          tmuxInstallOffer: offer,
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          bridge: bridge,
          tmuxInstallOffer: offer,
          notifier: notifier,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('tmuxInstallOfferDialog')), findsOneWidget);

      final confirmBtn = find.widgetWithText(FilledButton, 'Install tmux');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pump();

      expect(notifier.confirmCalled, isTrue);
    });

    testWidgets('skip calls skipTmuxInstall', (tester) async {
      final bridge = _FakeBridge(
        initialMode: TerminalSessionMode.tmuxUnavailable,
        initialState: TerminalConnectionState.connected,
      );

      const offer = TmuxInstallOffer(
        installCommand: 'apt-get update && apt-get install -y tmux',
      );

      final tab = TerminalTab(
        id: 'tab-1',
        title: 'bash',
        terminal: bridge.terminal,
        bridge: bridge,
      );
      final notifier = _MockTerminalNotifier(
        SshTerminalState(
          tabs: [tab],
          activeTabIndex: 0,
          tmuxInstallOffer: offer,
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          bridge: bridge,
          tmuxInstallOffer: offer,
          notifier: notifier,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('tmuxInstallOfferDialog')), findsOneWidget);

      final skipBtn = find.widgetWithText(TextButton, 'Skip (Use Plain Shell)');
      expect(skipBtn, findsOneWidget);
      await tester.tap(skipBtn);
      await tester.pump();

      expect(notifier.skipCalled, isTrue);
    });

    testWidgets(
      'terminal remains visible and interactive when tmux install prompt is shown',
      (tester) async {
        final bridge = _FakeBridge(
          initialMode: TerminalSessionMode.tmuxUnavailable,
          initialState: TerminalConnectionState.connected,
          awaitingTmuxDecision: true,
        );

        const offer = TmuxInstallOffer(
          installCommand: 'apt-get update && apt-get install -y tmux',
        );

        await tester.pumpWidget(
          _buildTestApp(bridge: bridge, tmuxInstallOffer: offer),
        );
        await tester.pump();

        // TerminalView and non-blocking dialog card are both visible
        expect(find.byType(TerminalView), findsOneWidget);
        expect(find.byKey(const Key('tmuxInstallOfferDialog')), findsOneWidget);

        // 关键：终端必须真的能收到输入，而不只是「存在于树上」。
        // 只断言两者都渲染是不够的——盖一层全屏遮罩同样能让两个 widget 并存，
        // 而且 tester.tapAt 命中遮罩时**不会**报错（这条测试最初就是这么假的）。
        //
        // 做法：点终端顶部（询问卡片锚定在底部，不会盖到那里），再确认终端
        // 自己的 input handler 收到了事件。
        //
        // 为什么这样能抓到遮挡层：焦点是靠点击转移的。如果上面压了一层全屏
        // barrier / 半透明 scrim / GestureDetector(opaque)，点击会被它吃掉，
        // 终端的 FocusNode 拿不到焦点，进而没有 TextInputConnection，
        // 后面的 enterText 就传不到 terminal.onOutput。
        final terminalFinder = find.byType(TerminalView);
        final terminalTopLeft = tester.getTopLeft(terminalFinder);
        // 卡片是 Positioned(bottom: 8) 的，顶部区域必然露在卡片之外。
        final uncoveredPoint = terminalTopLeft + const Offset(60, 30);

        var inputReceived = StringBuffer();
        bridge.terminal.onOutput = inputReceived.write;

        await tester.tapAt(uncoveredPoint);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // 点击必须落在终端自己身上，而不是被上面的卡片或任何遮挡层截走。
        // 这里不引用 xterm 内部的 RenderTerminal（4.0.0 没有导出它），
        // 改用「命中路径顶端不是卡片」+「焦点确实转移到终端」来判定。
        final hitResult = HitTestResult();
        WidgetsBinding.instance.hitTestInView(
          hitResult,
          uncoveredPoint,
          View.of(tester.element(terminalFinder)).viewId,
        );
        final topTarget = hitResult.path.first.target;
        expect(
          topTarget.runtimeType.toString(),
          isNot(contains('RenderParagraph')),
          reason: '命中被卡片文字吃掉，说明卡片覆盖到了终端顶部',
        );
        expect(
          topTarget.runtimeType.toString(),
          'RenderTerminal',
          reason: '该点必须由终端自己接收命中，被遮挡说明卡片变成了全屏 barrier',
        );

        // 询问卡片不能因为点击终端而消失。
        expect(find.byKey(const Key('tmuxInstallOfferDialog')), findsOneWidget);

        // 终端必须已经拿到焦点，并且能把文本输入送到 onOutput。
        // 焦点是靠点击转移的：若上面压了全屏遮挡层，这里拿不到焦点，
        // enterText 也就到不了 onOutput。
        expect(
          FocusManager.instance.primaryFocus,
          isNotNull,
          reason: '点击终端后必须有焦点节点',
        );
        tester.testTextInput.enterText('x');
        await tester.pump();
        expect(
          inputReceived.toString(),
          contains('x'),
          reason: '终端必须能收到输入，否则说明上面压了遮挡层',
        );

        // xterm 的 TerminalGestureDetector 会在单击后挂一个 kDoubleTapTimeout
        // (300ms) 的定时器等待第二击。测试结束前把它跑完，否则框架会报
        // "A Timer is still pending even after the widget tree was disposed"。
        await tester.pump(const Duration(milliseconds: 400));
      },
    );

    testWidgets(
      'does not mention disconnected when awaitingTmuxDecision is true (EN)',
      (tester) async {
        final bridge = _FakeBridge(
          initialMode: TerminalSessionMode.tmuxUnavailable,
          initialState: TerminalConnectionState.connected,
          awaitingTmuxDecision: true,
        );

        const offer = TmuxInstallOffer(
          installCommand: 'apt-get update && apt-get install -y tmux',
        );

        await tester.pumpWidget(
          _buildTestApp(
            bridge: bridge,
            tmuxInstallOffer: offer,
            locale: const Locale('en'),
          ),
        );
        await tester.pump();

        expect(
          find.textContaining('Disconnected', findRichText: true),
          findsNothing,
        );
        expect(
          find.textContaining('disconnected', findRichText: true),
          findsNothing,
        );
        expect(
          find.textContaining('offline', findRichText: true),
          findsNothing,
        );
      },
    );

    testWidgets('does not mention 未连接 when awaitingTmuxDecision is true (ZH)', (
      tester,
    ) async {
      final bridge = _FakeBridge(
        initialMode: TerminalSessionMode.tmuxUnavailable,
        initialState: TerminalConnectionState.connected,
        awaitingTmuxDecision: true,
      );

      const offer = TmuxInstallOffer(
        installCommand: 'apt-get update && apt-get install -y tmux',
      );

      await tester.pumpWidget(
        _buildTestApp(
          bridge: bridge,
          tmuxInstallOffer: offer,
          locale: const Locale('zh'),
        ),
      );
      await tester.pump();

      expect(find.textContaining('未连接', findRichText: true), findsNothing);
      expect(find.textContaining('离线', findRichText: true), findsNothing);
    });

    testWidgets(
      'shows progress when probing installCommand without declaring unsupported early',
      (tester) async {
        final bridge = _FakeBridge(
          initialMode: TerminalSessionMode.tmuxUnavailable,
          initialState: TerminalConnectionState.connected,
          awaitingTmuxDecision: true,
        );

        const probingOffer = TmuxInstallOffer(installCommand: null);

        final tab = TerminalTab(
          id: 'tab-1',
          title: 'bash',
          terminal: bridge.terminal,
          bridge: bridge,
        );
        final notifier = _MockTerminalNotifier(
          SshTerminalState(
            tabs: [tab],
            activeTabIndex: 0,
            tmuxInstallOffer: probingOffer,
          ),
        );

        await tester.pumpWidget(
          _buildTestApp(
            bridge: bridge,
            tmuxInstallOffer: probingOffer,
            notifier: notifier,
          ),
        );
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Does NOT assert unsupported early
        expect(find.text(l10n.terminalTmuxInstallUnsupported), findsNothing);
        // CircularProgressIndicator is displayed for probing
        expect(find.byType(CircularProgressIndicator), findsWidgets);

        // Confirm button is disabled while command is null
        final confirmBtn = find.widgetWithText(FilledButton, 'Install tmux');
        expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNull);

        // Skip button is still enabled
        final skipBtn = find.widgetWithText(
          TextButton,
          'Skip (Use Plain Shell)',
        );
        expect(tester.widget<TextButton>(skipBtn).onPressed, isNotNull);
      },
    );

    testWidgets(
      'shows unsupported error only when errorCode is TMUX_INSTALL_UNSUPPORTED',
      (tester) async {
        final bridge = _FakeBridge(
          initialMode: TerminalSessionMode.tmuxUnavailable,
          initialState: TerminalConnectionState.connected,
          awaitingTmuxDecision: true,
        );

        const unsupportedOffer = TmuxInstallOffer(
          installCommand: null,
          errorCode: 'TMUX_INSTALL_UNSUPPORTED',
        );

        await tester.pumpWidget(
          _buildTestApp(bridge: bridge, tmuxInstallOffer: unsupportedOffer),
        );
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.terminalTmuxInstallUnsupported), findsOneWidget);
      },
    );
  });
}
