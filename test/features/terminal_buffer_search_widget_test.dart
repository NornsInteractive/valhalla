import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/providers/terminal_settings_provider.dart';
import 'package:valhalla/features/terminal/widgets/shared_terminal_canvas.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

const _searchInputKey = Key('terminal_search_input');
const _prevButtonKey = Key('terminal_search_prev_button');
const _nextButtonKey = Key('terminal_search_next_button');
const _followButtonKey = Key('terminal_search_follow_button');
const _closeButtonKey = Key('terminal_search_close_button');

final _baseHighlightColor = Colors.amber.withValues(alpha: 0.35);
final _activeHighlightColor = Colors.orangeAccent.withValues(alpha: 0.8);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'local query highlights every match and prev/next moves the active one',
    (tester) async {
      final terminal = Terminal(maxLines: 100)
        ..write('alpha needle one\r\nbeta needle two\r\nneedle three');
      final controller = TerminalController();

      await tester.pumpWidget(_canvas(terminal, controller: controller));
      await tester.pumpAndSettle();
      await _search(tester, 'needle');

      // One amber highlight per match plus one orange active highlight.
      expect(controller.highlights, hasLength(4));
      expect(_baseHighlights(controller), hasLength(3));
      expect(_activeHighlights(controller), hasLength(1));

      final base = _baseHighlights(controller);
      expect(
        base.map((h) => _highlightText(terminal, h)).toList(),
        ['needle', 'needle', 'needle'],
        reason: 'every highlight must cover the exact matched text',
      );
      expect(base.map((h) => h.p1.y).toList(), [0, 1, 2]);

      final firstActive = _activeHighlights(controller).single;
      expect(_highlightText(terminal, firstActive), 'needle');
      expect(firstActive.p1.y, 0);

      await tester.tap(find.byKey(_nextButtonKey));
      await tester.pumpAndSettle();
      expect(_activeHighlights(controller), hasLength(1));
      expect(_activeHighlights(controller).single.p1.y, 1);
      expect(controller.highlights, hasLength(4));

      await tester.tap(find.byKey(_prevButtonKey));
      await tester.pumpAndSettle();
      expect(_activeHighlights(controller).single.p1.y, 0);

      // Previous from the first match wraps to the last one.
      await tester.tap(find.byKey(_prevButtonKey));
      await tester.pumpAndSettle();
      expect(_activeHighlights(controller).single.p1.y, 2);
    },
  );

  testWidgets(
    'search interactions never emit terminal key or output commands',
    (tester) async {
      final terminal = Terminal(maxLines: 100)
        ..write('needle alpha\r\nneedle beta');
      final controller = TerminalController();
      final keys = <String>[];
      final output = <String>[];
      terminal.onOutput = output.add;

      await tester.pumpWidget(
        _canvas(
          terminal,
          controller: controller,
          onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) =>
              keys.add(key),
        ),
      );
      await tester.pumpAndSettle();

      await _search(tester, 'needle');
      await tester.tap(find.byKey(_nextButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_prevButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_followButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_closeButtonKey));
      await tester.pumpAndSettle();

      expect(keys, isEmpty, reason: 'search must stay local, never call onKey');
      expect(
        output,
        isEmpty,
        reason: 'search must not write to the remote PTY',
      );
      expect(find.byKey(_searchInputKey), findsNothing);
    },
  );

  testWidgets(
    'closing search while a search is pending adds no late highlights',
    (tester) async {
      final terminal = Terminal(maxLines: 600);
      for (var i = 0; i < 300; i++) {
        terminal.write('needle line $i\r\n');
      }
      final controller = TerminalController();

      await tester.pumpWidget(_canvas(terminal, controller: controller));
      await tester.pumpAndSettle();

      final state = _state(tester);
      state.openSearch();
      await tester.pump();
      await tester.enterText(find.byKey(_searchInputKey), 'needle');
      await tester.pump();

      // Re-open while the query is already present to start the search without
      // waiting for the 200 ms debounce; close synchronously before it resolves.
      state.openSearch();
      state.closeSearch();

      await tester.pumpAndSettle();

      expect(find.byKey(_searchInputKey), findsNothing);
      expect(
        controller.highlights,
        isEmpty,
        reason: 'a search that resolves after close must not paint highlights',
      );
    },
  );

  testWidgets(
    'clearing the query while a search is pending adds no highlights',
    (tester) async {
      final terminal = Terminal(maxLines: 600);
      for (var i = 0; i < 300; i++) {
        terminal.write('needle line $i\r\n');
      }
      final controller = TerminalController();

      await tester.pumpWidget(_canvas(terminal, controller: controller));
      await tester.pumpAndSettle();

      final state = _state(tester);
      state.openSearch();
      await tester.pump();
      await tester.enterText(find.byKey(_searchInputKey), 'needle');
      await tester.pump();

      state.openSearch(); // start the pending search immediately

      var maxHighlights = 0;
      void observe() {
        if (controller.highlights.length > maxHighlights) {
          maxHighlights = controller.highlights.length;
        }
      }

      controller.addListener(observe);
      addTearDown(() => controller.removeListener(observe));

      // Clear through the real text input path; onChanged schedules the clearing
      // search while the previous one is still in flight.
      tester.testTextInput.enterText('');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(
        maxHighlights,
        0,
        reason: 'the stale in-flight search must not paint even transiently',
      );
      expect(controller.highlights, isEmpty);
    },
  );

  testWidgets('switching terminals keeps an independent query per terminal', (
    tester,
  ) async {
    final terminalA = Terminal(maxLines: 100)..write('alpha needle');
    final terminalB = Terminal(maxLines: 100)
      ..write('beta needle and needle again');
    final controller = TerminalController();

    await tester.pumpWidget(_canvas(terminalA, controller: controller));
    await tester.pumpAndSettle();
    await _search(tester, 'needle');
    expect(controller.highlights, hasLength(2));

    await tester.pumpWidget(_canvas(terminalB, controller: controller));
    await tester.pumpAndSettle();

    // B starts with its own empty query; the panel may remain open.
    _ensureSearchOpen(tester);
    await tester.pumpAndSettle();
    expect(_queryText(tester), isEmpty);
    expect(controller.highlights, isEmpty);

    // Typing in B searches B only, never reusing A's results.
    await tester.enterText(find.byKey(_searchInputKey), 'needle');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(controller.highlights, hasLength(3));
    final aLines = terminalA.buffer.lines.toList().toSet();
    for (final highlight in controller.highlights) {
      expect(_highlightText(terminalB, highlight), 'needle');
      expect(
        aLines.contains(highlight.p1.line),
        isFalse,
        reason: 'old buffer anchors must never be reused',
      );
      expect(
        identical(highlight.p1.line, terminalB.buffer.lines[highlight.p1.y]),
        isTrue,
      );
    }

    // Switching back restores A's remembered query and its own matches.
    await tester.pumpWidget(_canvas(terminalA, controller: controller));
    await tester.pumpAndSettle();

    _ensureSearchOpen(tester);
    await tester.pumpAndSettle();

    expect(_queryText(tester), 'needle');
    expect(controller.highlights, hasLength(2));
    final bLines = terminalB.buffer.lines.toList().toSet();
    for (final highlight in controller.highlights) {
      expect(_highlightText(terminalA, highlight), 'needle');
      expect(
        bLines.contains(highlight.p1.line),
        isFalse,
        reason: 'B anchors must never leak into A',
      );
      expect(
        identical(highlight.p1.line, terminalA.buffer.lines[highlight.p1.y]),
        isTrue,
      );
    }
  });

  testWidgets(
    'switching terminals during a pending search leaves the new terminal clean',
    (tester) async {
      final terminalA = Terminal(maxLines: 600);
      for (var i = 0; i < 300; i++) {
        terminalA.write('needle old $i\r\n');
      }
      final terminalB = Terminal(maxLines: 100)..write('new content only');
      final controller = TerminalController();

      await tester.pumpWidget(_canvas(terminalA, controller: controller));
      await tester.pumpAndSettle();

      final state = _state(tester);
      state.openSearch();
      await tester.pump();
      await tester.enterText(find.byKey(_searchInputKey), 'needle');
      await tester.pump();
      state.openSearch(); // start the search immediately, still in flight

      final aLines = terminalA.buffer.lines.toList().toSet();
      final bLines = terminalB.buffer.lines.toList().toSet();
      final seenHighlights = <TerminalHighlight>{};
      var staleAHighlightsIntoB = 0;
      void observe() {
        final current = controller.highlights.toSet();
        final added = current.difference(seenHighlights);
        seenHighlights
          ..clear()
          ..addAll(current);
        // Removing A's highlights while B takes over is ordinary cleanup, and
        // A may legitimately finish before B is actually selected.
        if (added.isEmpty ||
            !state.mounted ||
            !identical(state.widget.terminal, terminalB)) {
          return;
        }
        for (final highlight in added) {
          if (aLines.contains(highlight.p1.line) &&
              !bLines.contains(highlight.p1.line)) {
            staleAHighlightsIntoB++;
          }
        }
      }

      controller.addListener(observe);
      addTearDown(() => controller.removeListener(observe));

      await tester.pumpWidget(_canvas(terminalB, controller: controller));
      await _drain(tester);

      // The panel may stay open, but B must own neither the query nor matches.
      _ensureSearchOpen(tester);
      await tester.pump();
      expect(_queryText(tester), isEmpty);
      expect(
        controller.highlights,
        isEmpty,
        reason: 'a result for the previous terminal must be discarded',
      );
      expect(
        staleAHighlightsIntoB,
        0,
        reason: 'A must never add new anchors once B is selected',
      );

      // Drain any remaining chunked search work and re-check the contract.
      await _drain(tester);
      expect(controller.highlights, isEmpty);
      expect(staleAHighlightsIntoB, 0);
    },
  );

  testWidgets(
    'reopening an empty search after closing a pending one shows no spinner',
    (tester) async {
      final terminal = Terminal(maxLines: 600);
      for (var i = 0; i < 300; i++) {
        terminal.write('needle line $i\r\n');
      }
      final controller = TerminalController();

      await tester.pumpWidget(_canvas(terminal, controller: controller));
      await tester.pumpAndSettle();

      final state = _state(tester);
      state.openSearch();
      await tester.pump();
      await tester.enterText(find.byKey(_searchInputKey), 'needle');
      await tester.pump();

      state.openSearch(); // start the search immediately
      state.closeSearch();
      await tester.pump();

      state.openSearch();
      await tester.pump();

      expect(_queryText(tester), isEmpty);
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'a cancelled pending search must not leave a loading spinner',
      );
      expect(controller.highlights, isEmpty);

      await _drain(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(controller.highlights, isEmpty);
    },
  );

  testWidgets(
    'resuming after a backgrounded pending search clears the spinner without requesting the IME',
    (tester) async {
      final terminal = Terminal(maxLines: 600);
      for (var i = 0; i < 300; i++) {
        terminal.write('needle line $i\r\n');
      }
      final controller = TerminalController();
      final output = <String>[];
      terminal.onOutput = output.add;

      await tester.pumpWidget(_canvas(terminal, controller: controller));
      await tester.pumpAndSettle();

      final state = _state(tester);
      state.openSearch();
      await tester.pump();
      await tester.enterText(find.byKey(_searchInputKey), 'needle');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      state.openSearch(); // start a fresh search that stays in flight

      // Restore the binding to resumed even if an assertion fails mid-test.
      addTearDown(() {
        final binding = tester.binding;
        if (binding.lifecycleState == AppLifecycleState.resumed) return;
        if (binding.lifecycleState == AppLifecycleState.paused) {
          binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        }
        if (binding.lifecycleState == AppLifecycleState.hidden) {
          binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        }
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      });

      // Walk the framework's valid lifecycle path into the background.
      for (final lifecycle in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(lifecycle);
      }
      await tester.pump();

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);

      // And back out through the only valid path to resumed.
      for (final lifecycle in const [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(lifecycle);
      }
      await tester.pump();
      await _drain(tester);

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'resuming must not revive a cancelled search spinner',
      );
      expect(
        tester.testTextInput.isVisible,
        isFalse,
        reason: 'resuming must not request the terminal IME',
      );
      expect(output, isEmpty);
    },
  );

  testWidgets(
    'trimming old matches during an open search refreshes without detached anchors',
    (tester) async {
      final terminal = Terminal(maxLines: 100);
      for (var i = 0; i < 200; i++) {
        terminal.write('needle old $i\r\n');
      }
      final controller = TerminalController();

      await tester.pumpWidget(_canvas(terminal, controller: controller));
      await tester.pumpAndSettle();
      await _search(tester, 'needle');
      expect(controller.highlights, isNotEmpty);

      // Push real output until every originally searched line is trimmed away.
      for (var i = 0; i < 200; i++) {
        terminal.write('needle fresh $i\r\n');
      }
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final liveLines = terminal.buffer.lines.toList();
      final expectedMatches = liveLines.fold<int>(
        0,
        (count, line) => count + 'needle'.allMatches(line.getText()).length,
      );
      expect(expectedMatches, greaterThan(0));
      expect(
        controller.highlights,
        hasLength(expectedMatches + 1),
        reason: 'refresh must replace stale anchors, not accumulate new ones',
      );

      for (final highlight in controller.highlights) {
        expect(highlight.p1.attached, isTrue);
        expect(highlight.p2.attached, isTrue);
        expect(
          identical(highlight.p1.line, terminal.buffer.lines[highlight.p1.y]),
          isTrue,
          reason: 'every highlight must target a live buffer line',
        );
        expect(_highlightText(terminal, highlight), 'needle');
      }
    },
  );

  testWidgets(
    'appending output keeps anchors stable and preserves the manual position',
    (tester) async {
      final terminal = Terminal(maxLines: 100)
        ..write('needle zero\r\nneedle one\r\nneedle two');
      final controller = TerminalController();

      await tester.pumpWidget(_canvas(terminal, controller: controller));
      await tester.pumpAndSettle();
      await _search(tester, 'needle');

      await tester.tap(find.byKey(_nextButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_nextButtonKey));
      await tester.pumpAndSettle();
      expect(_activeHighlights(controller).single.p1.y, 2);

      terminal.write('\r\nunrelated output');
      await tester.pumpAndSettle();

      expect(controller.highlights, hasLength(4));
      expect(
        _baseHighlights(controller).map((h) => h.p1.y).toList(),
        [0, 1, 2],
        reason: 'appending must not move existing match anchors',
      );
      expect(
        _activeHighlights(controller).single.p1.y,
        2,
        reason: 'appending must not reset the manually selected match',
      );

      // Previous from the third match goes to the second, not back to first.
      await tester.tap(find.byKey(_prevButtonKey));
      await tester.pumpAndSettle();
      expect(_activeHighlights(controller).single.p1.y, 1);
    },
  );

  testWidgets(
    'overwriting a matched row invalidates instead of highlighting it',
    (tester) async {
      final terminal = Terminal(maxLines: 100)..write('needle here');
      final controller = TerminalController();

      await tester.pumpWidget(_canvas(terminal, controller: controller));
      await tester.pumpAndSettle();
      await _search(tester, 'needle');
      expect(controller.highlights, hasLength(2));

      terminal.write('\rXXXXXX');
      await tester.pump();
      expect(terminal.buffer.lines[0].getText(), startsWith('XXXXXX'));

      await tester.tap(find.byKey(_nextButtonKey));
      await tester.pumpAndSettle();

      expect(
        controller.highlights,
        isEmpty,
        reason:
            'stale cell positions must never be highlighted after a rewrite',
      );
      expect(_activeHighlights(controller), isEmpty);
    },
  );

  testWidgets('alternate buffer never reuses main-buffer match positions', (
    tester,
  ) async {
    final terminal = Terminal(maxLines: 100)..write('needle main');
    final controller = TerminalController();

    await tester.pumpWidget(_canvas(terminal, controller: controller));
    await tester.pumpAndSettle();
    await _search(tester, 'needle');
    final mainLine = terminal.buffer.lines[0];
    expect(controller.highlights, hasLength(2));

    terminal.useAltBuffer();
    terminal.write('needle alt');
    await tester.pump();

    await tester.tap(find.byKey(_nextButtonKey));
    await tester.pumpAndSettle();

    expect(controller.highlights, hasLength(2));
    for (final highlight in controller.highlights) {
      expect(_highlightText(terminal, highlight), 'needle');
      expect(
        identical(highlight.p1.line, mainLine),
        isFalse,
        reason: 'the old main-buffer line must not be highlighted',
      );
      expect(
        identical(highlight.p1.line, terminal.buffer.lines[highlight.p1.y]),
        isTrue,
        reason: 'highlights must target the active alternate buffer',
      );
    }
  });

  testWidgets('follow button returns the terminal to the latest line', (
    tester,
  ) async {
    final terminal = Terminal(maxLines: 400)..write('needle at the top\r\n');
    for (var i = 0; i < 220; i++) {
      terminal.write('filler line $i\r\n');
    }
    final controller = TerminalController();

    await tester.pumpWidget(_canvas(terminal, controller: controller));
    await tester.pumpAndSettle();

    final scrollController = tester
        .widget<TerminalView>(find.byType(TerminalView))
        .scrollController!;
    expect(scrollController.position.maxScrollExtent, greaterThan(0));

    await _search(tester, 'needle');
    expect(
      scrollController.position.pixels,
      lessThan(scrollController.position.maxScrollExtent),
      reason: 'jumping to the first match should leave the latest line',
    );

    await tester.tap(find.byKey(_followButtonKey));
    await tester.pumpAndSettle();
    expect(
      scrollController.position.pixels,
      scrollController.position.maxScrollExtent,
    );

    terminal.write('brand new output\r\n');
    await tester.pumpAndSettle();
    expect(
      scrollController.position.pixels,
      scrollController.position.maxScrollExtent,
      reason: 'follow mode must stay pinned to the newest output',
    );
  });

  testWidgets('Ctrl+Shift+F opens search and Ctrl+F remains a remote command', (
    tester,
  ) async {
    final terminal = Terminal(maxLines: 100)..write('content');
    final controller = TerminalController();
    final keys = <String>[];
    final output = <String>[];
    terminal.onOutput = output.add;

    await tester.pumpWidget(
      _canvas(
        terminal,
        controller: controller,
        onKey: (key, {isCtrl = false, isAlt = false, isShift = false}) =>
            keys.add(key),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TerminalView));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(_state(tester).isSearchOpen, isTrue);
    expect(find.byKey(_searchInputKey), findsOneWidget);
    expect(keys, isEmpty);
    expect(output, isEmpty);

    _state(tester).closeSearch();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TerminalView));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(
      _state(tester).isSearchOpen,
      isFalse,
      reason: 'plain Ctrl+F must stay available to the remote shell',
    );
    expect(output, contains('\x06'));
    expect(keys, isEmpty);

    // Terminal taps arm a double-tap timer that must be drained.
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('Cmd+F opens search on macOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final terminal = Terminal(maxLines: 100)..write('content');
    final controller = TerminalController();
    final output = <String>[];
    terminal.onOutput = output.add;

    await tester.pumpWidget(_canvas(terminal, controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TerminalView));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(_state(tester).isSearchOpen, isTrue);
    expect(find.byKey(_searchInputKey), findsOneWidget);
    expect(output, isEmpty);

    debugDefaultTargetPlatformOverride = null;
    // Drain the double-tap timer armed by the terminal tap.
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('320dp with large text does not overflow the search bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final terminal = Terminal(maxLines: 100)..write('needle');
    final controller = TerminalController();

    await tester.pumpWidget(
      _canvas(
        terminal,
        controller: controller,
        width: 320,
        height: 640,
        textScale: 2.0,
      ),
    );
    await tester.pumpAndSettle();

    _state(tester).openSearch();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(_searchInputKey), findsOneWidget);
    expect(find.byKey(_prevButtonKey), findsOneWidget);
    expect(find.byKey(_nextButtonKey), findsOneWidget);
    expect(find.byKey(_followButtonKey), findsOneWidget);
    expect(find.byKey(_closeButtonKey), findsOneWidget);

    final inputRect = tester.getRect(find.byKey(_searchInputKey));
    expect(inputRect.left, greaterThanOrEqualTo(0));
    expect(inputRect.right, lessThanOrEqualTo(320));
    final closeRect = tester.getRect(find.byKey(_closeButtonKey));
    expect(closeRect.left, greaterThanOrEqualTo(0));
    expect(closeRect.right, lessThanOrEqualTo(320));
  });

  testWidgets('closing search does not request the terminal IME', (
    tester,
  ) async {
    final terminal = Terminal(maxLines: 100)..write('content');
    final controller = TerminalController();
    final output = <String>[];
    terminal.onOutput = output.add;

    await tester.pumpWidget(_canvas(terminal, controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('terminal_accessory_keyboard_button')),
    );
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    _state(tester).openSearch();
    await tester.pumpAndSettle();
    expect(find.byKey(_searchInputKey), findsOneWidget);

    await tester.tap(find.byKey(_closeButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_searchInputKey), findsNothing);
    expect(
      tester.testTextInput.isVisible,
      isFalse,
      reason: 'closing search must not reopen the terminal keyboard',
    );
    expect(output, isEmpty);
  });
}

Widget _canvas(
  Terminal terminal, {
  required TerminalController controller,
  void Function(String key, {bool isCtrl, bool isAlt, bool isShift})? onKey,
  double width = 800,
  double height = 600,
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      terminalSettingsProvider.overrideWith(() => _FixedFontSizeNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: SharedTerminalCanvas(
              terminal: terminal,
              controller: controller,
              onKey:
                  onKey ??
                  (_, {isCtrl = false, isAlt = false, isShift = false}) {},
              onPaste: () async {},
            ),
          ),
        ),
      ),
    ),
  );
}

SharedTerminalCanvasState _state(WidgetTester tester) =>
    tester.state<SharedTerminalCanvasState>(find.byType(SharedTerminalCanvas));

Future<void> _search(WidgetTester tester, String query) async {
  _state(tester).openSearch();
  await tester.pump();
  await tester.enterText(find.byKey(_searchInputKey), query);
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pumpAndSettle();
}

void _ensureSearchOpen(WidgetTester tester) {
  if (!_state(tester).isSearchOpen) {
    _state(tester).openSearch();
  }
}

String _queryText(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(_searchInputKey)).controller!.text;

Future<void> _drain(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

List<TerminalHighlight> _baseHighlights(TerminalController controller) =>
    controller.highlights
        .where((highlight) => highlight.color == _baseHighlightColor)
        .toList();

List<TerminalHighlight> _activeHighlights(TerminalController controller) =>
    controller.highlights
        .where((highlight) => highlight.color == _activeHighlightColor)
        .toList();

String _highlightText(Terminal terminal, TerminalHighlight highlight) =>
    terminal.buffer.getText(highlight.range!);

class _FixedFontSizeNotifier extends TerminalSettingsNotifier {
  @override
  TerminalSettings build() => TerminalSettings(useTmux: false, fontSize: 13);
}
