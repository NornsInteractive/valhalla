import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/features/terminal/terminal_view.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

import '../support/fixed_terminal_settings.dart';

class _Bridge extends TerminalSessionBridge {
  _Bridge() : super(terminal: Terminal(), serverName: 'test');

  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _Notifier extends TerminalNotifier {
  _Notifier(this.initial);

  final SshTerminalState initial;

  @override
  SshTerminalState build() => initial;
}

TerminalTab _tab(String id) {
  final bridge = _Bridge();
  return TerminalTab(
    id: id,
    title: id,
    terminal: bridge.terminal,
    bridge: bridge,
  );
}

Future<void> _pump(WidgetTester tester, _Notifier notifier) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        terminalProvider.overrideWith(() => notifier),
        terminalSettingsProvider.overrideWith(
          FixedTerminalSettingsNotifier.new,
        ),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SshTerminalView()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'clicking close on the selected Windows tab removes its session',
    (tester) async {
      final first = _tab('first');
      final second = _tab('second');
      final notifier = _Notifier(
        SshTerminalState(tabs: [first, second], activeTabIndex: 1),
      );
      await _pump(tester, notifier);

      final close = find.descendant(
        of: find.ancestor(
          of: find.text('second'),
          matching: find.byType(InputChip),
        ),
        matching: find.byIcon(Icons.close),
      );
      await tester.tap(close);
      await tester.pump();

      expect(notifier.state.tabs, [first]);
      expect(notifier.state.activeTab, same(first));
      expect((second.bridge as _Bridge).disposed, isTrue);
      expect((first.bridge as _Bridge).disposed, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      first.bridge.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'closing a tab before the active tab preserves the same session',
    (tester) async {
      final tabs = [_tab('first'), _tab('second'), _tab('third')];
      final notifier = _Notifier(
        SshTerminalState(tabs: tabs, activeTabIndex: 1),
      );
      await _pump(tester, notifier);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('terminal_tab_first')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();

      expect(notifier.state.tabs, [tabs[1], tabs[2]]);
      expect(notifier.state.activeTab, same(tabs[1]));
      expect(notifier.state.activeTabIndex, 0);
      expect((tabs[0].bridge as _Bridge).disposed, isTrue);
      expect((tabs[1].bridge as _Bridge).disposed, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (final tab in tabs) {
        tab.bridge.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'closing the active middle tab selects the next and removes stale tmux offer',
    (tester) async {
      final tabs = [_tab('first'), _tab('second'), _tab('third')];
      final notifier = _Notifier(
        SshTerminalState(
          tabs: tabs,
          activeTabIndex: 1,
          tmuxInstallOffer: const TmuxInstallOffer(
            installCommand: 'install-tmux-for-second',
          ),
        ),
      );
      await _pump(tester, notifier);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('terminal_tab_second')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();

      expect(notifier.state.tabs, [tabs[0], tabs[2]]);
      expect(notifier.state.activeTab, same(tabs[2]));
      expect(notifier.state.tmuxInstallOffer, isNull);
      expect(find.byKey(const Key('tmuxInstallOfferDialog')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (final tab in tabs) {
        tab.bridge.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'closing a later inactive tab keeps the active session and tmux offer',
    (tester) async {
      final tabs = [_tab('first'), _tab('second'), _tab('third')];
      const offer = TmuxInstallOffer(installCommand: 'install-tmux-for-first');
      final notifier = _Notifier(
        SshTerminalState(tabs: tabs, tmuxInstallOffer: offer),
      );
      await _pump(tester, notifier);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('terminal_tab_third')),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();

      expect(notifier.state.tabs, [tabs[0], tabs[1]]);
      expect(notifier.state.activeTab, same(tabs[0]));
      expect(notifier.state.tmuxInstallOffer, same(offer));
      expect((tabs[2].bridge as _Bridge).disposed, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      for (final tab in tabs) {
        tab.bridge.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'the last tab stays open and invalid close indices are ignored',
    (tester) async {
      final first = _tab('first');
      final second = _tab('second');
      final notifier = _Notifier(SshTerminalState(tabs: [first, second]));
      await _pump(tester, notifier);
      notifier.closeTab(-1);
      notifier.closeTab(2);
      expect(notifier.state.tabs, [first, second]);
      notifier.closeTab(1);
      await tester.pump();

      final chip = tester.widget<InputChip>(find.byType(InputChip));
      expect(chip.onDeleted, isNull);
      notifier.closeTab(0);
      expect(notifier.state.tabs, [first]);
      expect((first.bridge as _Bridge).disposed, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      first.bridge.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'Windows clear repaints immediately and clears scrollback only for the active tab',
    (tester) async {
      final tabs = [_tab('first'), _tab('second')];
      final notifier = _Notifier(
        SshTerminalState(tabs: tabs, activeTabIndex: 1),
      );
      await _pump(tester, notifier);
      tabs[0].terminal.write('keep first session output');
      final terminal = tabs[1].terminal;
      terminal.write(
        List.generate(100, (index) => 'old output $index\r\n').join(),
      );
      await tester.pump();
      expect(terminal.buffer.scrollBack, greaterThan(0));
      final sent = <String>[];
      terminal.onOutput = sent.add;
      var repaints = 0;
      void onChanged() => repaints++;
      terminal.addListener(onChanged);

      await tester.tap(find.byTooltip('Clear'));
      await tester.pump();

      expect(repaints, 1);
      expect(terminal.buffer.getText().trim(), isEmpty);
      expect(terminal.buffer.scrollBack, 0);
      expect(terminal.buffer.cursorX, 0);
      expect(terminal.buffer.cursorY, 0);
      expect(
        tabs[0].terminal.buffer.getText(),
        contains('keep first session output'),
      );
      expect((tabs[1].bridge as _Bridge).disposed, isFalse);
      expect(notifier.state.activeTab, same(tabs[1]));
      expect(sent, isEmpty);
      terminal.write('output after clear');
      await tester.pump();
      expect(terminal.buffer.getText(), contains('output after clear'));
      expect(tester.takeException(), isNull);
      terminal.removeListener(onChanged);
      await tester.pumpWidget(const SizedBox());
      for (final tab in tabs) {
        tab.bridge.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'Android retains the existing terminal tab layout',
    (tester) async {
      final tabs = [_tab('first'), _tab('second')];
      final notifier = _Notifier(SshTerminalState(tabs: tabs));
      await _pump(tester, notifier);
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      expect(find.byType(InputChip), findsNothing);
      await tester.pumpWidget(const SizedBox());
      for (final tab in tabs) {
        tab.bridge.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
