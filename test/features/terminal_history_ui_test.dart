import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/terminal/terminal_view.dart';
import 'package:valhalla/features/terminal/widgets/terminal_history_drawer.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

import '../support/fixed_terminal_settings.dart';
import '../support/seeded_terminal_notifier.dart';

class _Storage implements LocalStorageService {
  @override
  TerminalHistorySnapshot getTerminalHistory(
    String serverId,
    String targetKey,
  ) => const TerminalHistorySnapshot();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Active extends ActiveServerNotifier {
  @override
  ServerProfile build() => terminalFixtureServer;
  void select(ServerProfile server) => state = server;
}

class _Servers extends ServerListNotifier {
  @override
  List<ServerProfile> build() => [terminalFixtureServer];
}

class _Connection extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState();
}

class _Bridge extends TerminalSessionBridge {
  _Bridge({
    this.testMode = TerminalSessionMode.plain,
    super.sessionIntent,
    super.preferTmux,
  }) : super(terminal: Terminal(), serverName: 'fixture');
  final TerminalSessionMode testMode;
  @override
  TerminalSessionMode get mode => testMode;
  @override
  TerminalConnectionState get state => stateListenable.value;
}

class _Notifier extends SeededTerminalNotifier {
  _Notifier(super.initial);
  int initializations = 0;
  int restores = 0;
  int freshStarts = 0;
  final defaults = <String?>[];
  Completer<void>? renameGate;
  Completer<void>? defaultGate;
  bool failDefault = false;
  final deletions = <(String, bool, String?)>[];
  @override
  Future<void> deleteHistory(
    String id, {
    bool terminateRemote = false,
    String? expectedTargetKey,
  }) async {
    deletions.add((id, terminateRemote, expectedTargetKey));
  }

  @override
  Future<void> ensureInitialized() async => initializations++;
  @override
  Future<void> refreshHistory() async {}
  @override
  Future<void> renameTab(String id, String title) async {
    TerminalHistoryRecord.validateTitle(title);
    await renameGate?.future;
  }

  @override
  Future<void> setDefaultHistory(String? id) async {
    defaults.add(id);
    await defaultGate?.future;
    if (failDefault) throw StateError('fixture storage failure');
    state = state.copyWith(
      defaultHistoryId: id,
      clearDefaultHistory: id == null,
    );
  }

  @override
  Future<void> restoreHistory(String id) async => restores++;

  @override
  Future<void> addNewTab([String? customTitle]) async => freshStarts++;
}

TerminalHistoryRecord _record({
  String id = 'session-1',
  String title = 'History fixture',
  int minute = 35,
}) => TerminalHistoryRecord(
  id: id,
  serverId: terminalFixtureServer.id,
  targetKey: TerminalHistoryRecord.targetFor(terminalFixtureServer),
  remoteSessionName: 'valhalla_terminal-fixture_$id',
  title: title,
  createdAt: DateTime.utc(2026, 10, 14),
  lastUsedAt: DateTime.utc(2026, 10, 14, 18, minute),
);

ProviderContainer _container(_Notifier notifier) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_Storage()),
      activeServerProvider.overrideWith(_Active.new),
      serverListProvider.overrideWith(_Servers.new),
      serverConnectionProvider.overrideWith(_Connection.new),
      terminalProvider.overrideWith(() => notifier),
      ...fixedTerminalSettingsOverrides(),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

Widget _dialogButtons() => Consumer(
  builder: (context, ref, _) => Column(
    children: [
      TextButton(
        onPressed: () => showRenameTabDialog(context, ref, 'tab-1', 'Original'),
        child: const Text('Open rename'),
      ),
      TextButton(
        onPressed: () => showStartupSessionDialog(context, ref),
        child: const Text('Open startup'),
      ),
      TextButton(
        onPressed: () => showDeleteHistoryDialog(context, ref, _record()),
        child: const Text('Open delete'),
      ),
    ],
  ),
);

void main() {
  testWidgets('history delete defaults to local-only and pins dialog target', (
    tester,
  ) async {
    final record = _record();
    final notifier = _Notifier(SshTerminalState(tabs: [], history: [record]));
    await _pump(tester, _container(notifier), _dialogButtons());
    await tester.tap(find.text('Open delete'));
    await tester.pumpAndSettle();
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
    expect(
      checkbox.onChanged,
      isNull,
      reason: 'offline cannot terminate remote',
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.widgetWithText(FilledButton, l10n.delete));
    await tester.pumpAndSettle();
    expect(notifier.deletions, [(record.id, false, record.targetKey)]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets(
    'cancelling history delete performs no local or remote operation',
    (tester) async {
      final notifier = _Notifier(
        SshTerminalState(tabs: [], history: [_record()]),
      );
      await _pump(tester, _container(notifier), _dialogButtons());
      await tester.tap(find.text('Open delete'));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
      await tester.pumpAndSettle();
      expect(notifier.deletions, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
  testWidgets(
    'history entry and drawer dismissal never reopen the mobile keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = _Bridge();
      final notifier = _Notifier(
        SshTerminalState(
          tabs: [
            TerminalTab(
              id: 'tab-1',
              title: 'Terminal',
              terminal: bridge.terminal,
              bridge: bridge,
            ),
          ],
        ),
      );
      final output = <String>[];
      bridge.terminal.onOutput = output.add;
      bridge.terminal.write('unchanged terminal output');
      await _pump(tester, _container(notifier), const SshTerminalView());
      final entry = find.byKey(const Key('terminal_history_button'));
      final scaffoldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Scaffold && widget.drawer is TerminalHistoryDrawer,
      );
      final canvas = tester.state<TerminalViewState>(find.byType(TerminalView));

      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(tester.state<ScaffoldState>(scaffoldFinder).isDrawerOpen, isTrue);
      expect(canvas.hasInputConnection, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tapAt(const Offset(380, 420));
      await tester.pumpAndSettle();
      expect(tester.state<ScaffoldState>(scaffoldFinder).isDrawerOpen, isFalse);
      expect(canvas.hasInputConnection, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);

      // Starting with an explicitly opened keyboard must not restore it when
      // the inner drawer closes via the system back path either.
      await tester.tap(
        find.byKey(const Key('terminal_accessory_keyboard_button')),
      );
      await tester.pump();
      await tester.pump();
      expect(canvas.hasInputConnection, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(tester.state<ScaffoldState>(scaffoldFinder).isDrawerOpen, isTrue);
      expect(canvas.hasInputConnection, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.state<ScaffoldState>(scaffoldFinder).isDrawerOpen, isFalse);
      expect(canvas.hasInputConnection, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(output, isEmpty);
      expect(
        bridge.terminal.buffer.getText(),
        contains('unchanged terminal output'),
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    '64 grapheme title retains its full tooltip and other tabs remain reachable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final title = List.generate(
        64,
        (index) => index.isEven ? 'e\u0301' : '👩‍💻',
      ).join();
      expect(title.characters.length, 64);
      expect(TerminalHistoryRecord.validateTitle(title), title);
      final output = <String>[];
      TerminalTab tab(String id, String label) {
        final bridge = _Bridge();
        bridge.terminal.onOutput = output.add;
        return TerminalTab(
          id: id,
          title: label,
          terminal: bridge.terminal,
          bridge: bridge,
        );
      }

      final notifier = _Notifier(
        SshTerminalState(
          tabs: [
            tab('long', title),
            tab('middle', 'Middle terminal'),
            tab('last', 'Other terminal'),
          ],
        ),
      );
      await _pump(tester, _container(notifier), const SshTerminalView());
      final titleText = tester.widget<Text>(find.text(title));
      expect(titleText.maxLines, 1);
      expect(titleText.overflow, TextOverflow.ellipsis);
      expect(tester.getSize(find.text(title)).width, lessThanOrEqualTo(160));
      final tooltip = find.byTooltip(RegExp(RegExp.escape(title)));
      expect(tooltip, findsOneWidget);
      expect(tester.widget<Tooltip>(tooltip).message, contains(title));
      expect(
        tester.state<TooltipState>(tooltip).ensureTooltipVisible(),
        isTrue,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      Tooltip.dismissAllToolTips();
      await tester.pumpAndSettle();

      final first = find.byKey(const ValueKey('terminal_tab_long'));
      final scroller = find.ancestor(
        of: first,
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroller, findsOneWidget);
      final beforeLeft = tester.getRect(first).left;
      await tester.drag(scroller, const Offset(-1000, 0));
      await tester.pumpAndSettle();
      expect(tester.getRect(first).left, lessThan(beforeLeft - 50));
      expect(find.text('Other terminal').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Other terminal'));
      await tester.pump();
      expect(notifier.state.activeTab?.id, 'last');

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final plus = find.byTooltip(l10n.terminalNewTab);
      expect(plus.hitTestable(), findsOneWidget);
      expect(
        find.ancestor(of: plus, matching: find.byType(SingleChildScrollView)),
        findsNothing,
      );
      await tester.tap(plus);
      await tester.pump();
      expect(notifier.freshStarts, 1);
      expect(output, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'hidden terminal stays lazy; active same-ID endpoint change initializes',
    (tester) async {
      final bridge = _Bridge();
      final notifier = _Notifier(
        SshTerminalState(
          tabs: [
            TerminalTab(
              id: 'tab-1',
              title: 'Terminal',
              terminal: bridge.terminal,
              bridge: bridge,
            ),
          ],
        ),
      );
      final container = _container(notifier);
      await _pump(tester, container, const SshTerminalView(active: false));
      expect(notifier.initializations, 0);
      await _pump(tester, container, const SshTerminalView(active: true));
      expect(notifier.initializations, 1);
      await _pump(tester, container, const SshTerminalView(active: true));
      expect(notifier.initializations, 1);
      (container.read(activeServerProvider.notifier) as _Active).select(
        terminalFixtureServer.copyWith(host: '192.0.2.11'),
      );
      await tester.pump();
      await tester.pump();
      expect(notifier.initializations, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fresh tmux does not claim restored; subsequent reconnect does', (
    tester,
  ) async {
    final bridge = _Bridge(testMode: TerminalSessionMode.tmux);
    bridge.stateListenable.value = TerminalConnectionState.connecting;
    final notifier = _Notifier(
      SshTerminalState(
        tabs: [
          TerminalTab(
            id: 'tab-1',
            title: 'Terminal',
            terminal: bridge.terminal,
            bridge: bridge,
          ),
        ],
      ),
    );
    await _pump(tester, _container(notifier), const SshTerminalView());
    bridge.stateListenable.value = TerminalConnectionState.connected;
    await tester.pump();
    expect(find.byKey(const Key('terminalTmuxSessionRestored')), findsNothing);
    bridge.stateListenable.value = TerminalConnectionState.disconnected;
    bridge.stateListenable.value = TerminalConnectionState.connected;
    await tester.pump();
    expect(
      find.byKey(const Key('terminalTmuxSessionRestored')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline uninitialized terminal has no permanent spinner', (
    tester,
  ) async {
    final notifier = _Notifier(SshTerminalState(tabs: const []));
    await _pump(tester, _container(notifier), const SshTerminalView());
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit history restore shows a notice on first attach', (
    tester,
  ) async {
    final bridge = _Bridge(
      testMode: TerminalSessionMode.tmux,
      sessionIntent: TerminalSessionIntent.restoreExisting,
    );
    bridge.stateListenable.value = TerminalConnectionState.connecting;
    final notifier = _Notifier(
      SshTerminalState(
        tabs: [
          TerminalTab(
            id: 'tab-1',
            title: 'Restored terminal',
            terminal: bridge.terminal,
            bridge: bridge,
          ),
        ],
      ),
    );
    await _pump(tester, _container(notifier), const SshTerminalView());
    bridge.stateListenable.value = TerminalConnectionState.connected;
    await tester.pump();
    expect(
      find.byKey(const Key('terminalTmuxSessionRestored')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching tabs clears a different bridge restored notice', (
    tester,
  ) async {
    final restored = _Bridge(testMode: TerminalSessionMode.tmux);
    final fresh = _Bridge(testMode: TerminalSessionMode.tmux);
    restored.stateListenable.value = TerminalConnectionState.connected;
    fresh.stateListenable.value = TerminalConnectionState.connecting;
    final notifier = _Notifier(
      SshTerminalState(
        tabs: [
          TerminalTab(
            id: 'tab-1',
            title: 'Restored terminal',
            terminal: restored.terminal,
            bridge: restored,
          ),
          TerminalTab(
            id: 'tab-2',
            title: 'Fresh terminal',
            terminal: fresh.terminal,
            bridge: fresh,
          ),
        ],
      ),
    );
    await _pump(tester, _container(notifier), const SshTerminalView());
    restored.stateListenable.value = TerminalConnectionState.disconnected;
    restored.stateListenable.value = TerminalConnectionState.connected;
    await tester.pump();
    expect(
      find.byKey(const Key('terminalTmuxSessionRestored')),
      findsOneWidget,
    );
    notifier.selectTab(1);
    await tester.pump();
    expect(find.byKey(const Key('terminalTmuxSessionRestored')), findsNothing);
    fresh.stateListenable.value = TerminalConnectionState.connected;
    await tester.pump();
    expect(find.byKey(const Key('terminalTmuxSessionRestored')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rename cancellation safely completes the exit animation', (
    tester,
  ) async {
    await _pump(
      tester,
      _container(_Notifier(SshTerminalState(tabs: const []))),
      _dialogButtons(),
    );
    await tester.tap(find.text('Open rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Changed');
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late rename failure after dialog dismissal is observed safely', (
    tester,
  ) async {
    final gate = Completer<void>();
    final notifier = _Notifier(SshTerminalState(tabs: const []))
      ..renameGate = gate;
    await _pump(tester, _container(notifier), _dialogButtons());
    await tester.tap(find.text('Open rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Changed');
    await tester.tap(find.text('Save'));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    gate.completeError(StateError('fixture delayed disk failure'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rename completion during dismiss animation does not pop its page',
    (tester) async {
      final gate = Completer<void>();
      final notifier = _Notifier(SshTerminalState(tabs: const []))
        ..renameGate = gate;
      await _pump(
        tester,
        _container(notifier),
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(body: _dialogButtons()),
              ),
            ),
            child: const Text('Open terminal page'),
          ),
        ),
      );
      await tester.tap(find.text('Open terminal page'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Changed');
      await tester.tap(find.text('Save'));
      await tester.pump();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump(const Duration(milliseconds: 10));
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Open rename'), findsOneWidget);
      expect(find.text('Open terminal page'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed default save is caught and selection is retained', (
    tester,
  ) async {
    final notifier = _Notifier(
      SshTerminalState(
        tabs: const [],
        history: [_record()],
        defaultHistoryId: 'session-1',
      ),
    )..failDefault = true;
    await _pump(tester, _container(notifier), _dialogButtons());
    await tester.tap(find.text('Open startup'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('terminal_startup_session_fresh_option')),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(notifier.state.defaultHistoryId, 'session-1');
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
    'default completion during dismiss animation does not pop its page',
    (tester) async {
      final gate = Completer<void>();
      final notifier = _Notifier(
        SshTerminalState(
          tabs: const [],
          history: [_record()],
          defaultHistoryId: 'session-1',
        ),
      )..defaultGate = gate;
      await _pump(
        tester,
        _container(notifier),
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(body: _dialogButtons()),
              ),
            ),
            child: const Text('Open terminal page'),
          ),
        ),
      );
      await tester.tap(find.text('Open terminal page'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open startup'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('terminal_startup_session_fresh_option')),
      );
      await tester.pump();
      expect(notifier.defaults, [null]);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump(const Duration(milliseconds: 10));
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Open startup'), findsOneWidget);
      expect(find.text('Open terminal page'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('startup dialog cannot clear a different target default', (
    tester,
  ) async {
    final notifier = _Notifier(
      SshTerminalState(
        tabs: const [],
        history: [_record()],
        defaultHistoryId: 'session-1',
      ),
    );
    final container = _container(notifier);
    await _pump(tester, container, _dialogButtons());
    await tester.tap(find.text('Open startup'));
    await tester.pumpAndSettle();
    (container.read(activeServerProvider.notifier) as _Active).select(
      terminalFixtureServer.copyWith(host: '192.0.2.11'),
    );
    await tester.pumpAndSettle();
    final fresh = find.byKey(
      const Key('terminal_startup_session_fresh_option'),
    );
    if (fresh.evaluate().isNotEmpty) {
      await tester.tap(fresh);
      await tester.pumpAndSettle();
    }
    expect(notifier.defaults, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ended history cannot restore from its row', (tester) async {
    final notifier = _Notifier(
      SshTerminalState(
        tabs: const [],
        history: [_record()],
        historyStatuses: const {'session-1': TerminalHistoryStatus.ended},
      ),
    );
    await _pump(tester, _container(notifier), const TerminalHistoryDrawer());
    await tester.tap(find.text('History fixture'));
    await tester.pumpAndSettle();
    expect(notifier.restores, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history search keeps offline open tabs separate from recoverable and ended',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = _Bridge();
      final output = <String>[];
      bridge.terminal.onOutput = output.add;
      final notifier = _Notifier(
        SshTerminalState(
          tabs: [
            TerminalTab(
              id: 'open',
              title: 'Open disconnected',
              terminal: bridge.terminal,
              bridge: bridge,
            ),
          ],
          history: [
            _record(id: 'ended', title: 'Ended session', minute: 59),
            _record(id: 'older', title: 'Older unknown', minute: 10),
            _record(id: 'open', title: 'Open disconnected', minute: 1),
            _record(id: 'newer', title: 'Newer available', minute: 30),
          ],
          historyStatuses: const {
            'open': TerminalHistoryStatus.unknown,
            'older': TerminalHistoryStatus.unknown,
            'newer': TerminalHistoryStatus.available,
            'ended': TerminalHistoryStatus.ended,
          },
        ),
      );
      await _pump(tester, _container(notifier), const TerminalHistoryDrawer());
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.terminalStatusOpen), findsOneWidget);
      expect(find.text(l10n.terminalRestoreSession), findsOneWidget);
      expect(find.text(l10n.terminalStatusOffline), findsNWidgets(2));
      final titles = [
        'Open disconnected',
        'Newer available',
        'Older unknown',
        'Ended session',
      ];
      for (var i = 0; i < titles.length - 1; i++) {
        expect(
          tester.getTopLeft(find.text(titles[i])).dy,
          lessThan(tester.getTopLeft(find.text(titles[i + 1])).dy),
        );
      }
      await tester.enterText(find.byType(TextField), '  OLDER  ');
      await tester.pump();
      expect(find.text('Older unknown'), findsOneWidget);
      expect(find.text('Open disconnected'), findsNothing);
      expect(find.text('Ended session'), findsNothing);
      expect(find.text(l10n.terminalStatusOpen), findsNothing);
      expect(find.text(l10n.terminalStatusOffline), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'not-a-session');
      await tester.pump();
      expect(find.text(l10n.stateEmpty), findsOneWidget);
      expect(notifier.restores, 0);
      expect(notifier.freshStarts, 0);
      expect(output, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '320dp 2x RTL history search closes without requesting terminal keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const openTitle = 'جلسة مفتوحة باسم طويل لاختبار العرض';
      const availableTitle = 'جلسة قابلة للاستعادة';
      final bridge = _Bridge(preferTmux: true);
      final output = <String>[];
      bridge.terminal.onOutput = output.add;
      final notifier = _Notifier(
        SshTerminalState(
          tabs: [
            TerminalTab(
              id: 'open',
              title: openTitle,
              terminal: bridge.terminal,
              bridge: bridge,
            ),
          ],
          history: [
            _record(id: 'open', title: openTitle),
            _record(id: 'available', title: availableTitle),
            _record(id: 'ended', title: 'جلسة منتهية'),
          ],
          historyStatuses: const {
            'open': TerminalHistoryStatus.unknown,
            'available': TerminalHistoryStatus.available,
            'ended': TerminalHistoryStatus.ended,
          },
        ),
      );
      await _pump(
        tester,
        _container(notifier),
        const SshTerminalView(),
        locale: const Locale('ar'),
        textScale: 2,
      );
      final canvas = tester.state<TerminalViewState>(find.byType(TerminalView));
      expect(
        find.byTooltip('$openTitle (SSH)'),
        findsOneWidget,
        reason:
            'actual plain mode must not claim tmux from its requested preference',
      );
      await tester.tap(find.byKey(const Key('terminal_history_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
      expect(find.text(l10n.terminalStatusOpen), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      final search = find.descendant(
        of: find.byType(TerminalHistoryDrawer),
        matching: find.byType(TextField),
      );
      await tester.enterText(search, 'قابلة');
      await tester.pumpAndSettle();
      expect(find.text(availableTitle), findsOneWidget);
      expect(find.text(l10n.terminalRestoreSession), findsOneWidget);
      expect(find.text(l10n.terminalStatusOpen), findsNothing);
      expect(tester.takeException(), isNull);
      final scaffold = tester.state<ScaffoldState>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Scaffold && widget.drawer is TerminalHistoryDrawer,
        ),
      );
      scaffold.closeDrawer();
      await tester.pumpAndSettle();
      expect(scaffold.isDrawerOpen, isFalse);
      expect(canvas.hasInputConnection, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(notifier.restores, 0);
      expect(notifier.freshStarts, 0);
      expect(output, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
