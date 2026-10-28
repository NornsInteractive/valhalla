import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/data/workspace/workspace_gateway.dart';
import 'package:valhalla/features/terminal/terminal_view.dart';
import 'package:valhalla/features/terminal/widgets/terminal_history_drawer.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

import '../support/fixed_terminal_settings.dart';
import '../support/seeded_terminal_notifier.dart';

class _Storage implements LocalStorageService {
  /// Local-only fixture: no workspace sync is configured, so the gateway must
  /// stay null. The terminal provider reads this during build.
  @override
  WorkspaceGateway? workspaceGateway;

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

class _Connected extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: terminalFixtureServer.id,
  );
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
  int refreshes = 0;
  final defaults = <String?>[];
  Completer<void>? renameGate;
  Completer<void>? defaultGate;
  bool failDefault = false;
  final deletions = <(String, bool, String?)>[];
  final unhides = <(String, String?)>[];
  final socketAddAttempts = <(TmuxSocketSource, String?)>[];
  final socketAdds = <(TmuxSocketSource, String?)>[];

  /// Mirrors the production target guard so target switches can be exercised.
  String targetKey = TerminalHistoryRecord.targetFor(terminalFixtureServer);

  @override
  Future<void> deleteHistory(
    String id, {
    bool terminateRemote = false,
    String? expectedTargetKey,
  }) async {
    deletions.add((id, terminateRemote, expectedTargetKey));
    if (expectedTargetKey != null && expectedTargetKey != targetKey) {
      throw StateError('TERMINAL_HISTORY_TARGET_CHANGED');
    }
    final record = state.history.where((r) => r.id == id).firstOrNull;
    if (record == null) return;
    if (terminateRemote) {
      state = state.copyWith(
        historyStatuses: {
          ...state.historyStatuses,
          id: TerminalHistoryStatus.ended,
        },
      );
    } else {
      state = state.copyWith(
        hiddenRecordIds: {...state.hiddenRecordIds, id}.toList(),
      );
    }
  }

  @override
  Future<void> unhideHistory(String id, {String? expectedTargetKey}) async {
    unhides.add((id, expectedTargetKey));
    if (expectedTargetKey != null && expectedTargetKey != targetKey) {
      throw StateError('TERMINAL_HISTORY_TARGET_CHANGED');
    }
    state = state.copyWith(
      hiddenRecordIds: state.hiddenRecordIds
          .where((item) => item != id)
          .toList(),
    );
  }

  @override
  Future<void> addSocketSource(
    TmuxSocketSource source, {
    String? expectedTargetKey,
  }) async {
    socketAddAttempts.add((source, expectedTargetKey));
    if (expectedTargetKey != null && expectedTargetKey != targetKey) {
      throw StateError('TERMINAL_HISTORY_TARGET_CHANGED');
    }
    socketAdds.add((source, expectedTargetKey));
    state = state.copyWith(socketSources: [...state.socketSources, source]);
  }

  @override
  Future<void> ensureInitialized() async => initializations++;
  @override
  Future<void> refreshHistory() async => refreshes++;
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

ProviderContainer _container(_Notifier notifier, {bool connected = false}) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_Storage()),
      activeServerProvider.overrideWith(_Active.new),
      serverListProvider.overrideWith(_Servers.new),
      serverConnectionProvider.overrideWith(
        connected ? _Connected.new : _Connection.new,
      ),
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
    ],
  ),
);

/// Opens the row overflow menu of the first history entry in the drawer.
Future<void> _openRowMenu(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>).first);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

/// Scrolls the history drawer like a user would until [target] is built and
/// on screen. The drawer body is a lazy [CustomScrollView], so entries below
/// the viewport are not built until the list is scrolled.
Future<void> _revealInHistoryDrawer(WidgetTester tester, Finder target) async {
  final list = find
      .descendant(
        of: find.byType(TerminalHistoryDrawer),
        matching: find.byType(Scrollable),
      )
      .first;
  for (var attempt = 0; attempt < 12; attempt++) {
    final matches = target.evaluate();
    if (matches.isNotEmpty) {
      await Scrollable.ensureVisible(matches.first);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(list, const Offset(0, -140));
    await tester.pumpAndSettle();
  }
  fail('history drawer never revealed $target');
}

/// Scrolls the history drawer back to the top, the way a user would when
/// reaching for the search field again.
Future<void> _scrollHistoryDrawerToTop(WidgetTester tester) async {
  final list = find
      .descendant(
        of: find.byType(TerminalHistoryDrawer),
        matching: find.byType(Scrollable),
      )
      .first;
  for (var attempt = 0; attempt < 20; attempt++) {
    final before = tester.state<ScrollableState>(list).position.pixels;
    await tester.drag(list, const Offset(0, 400));
    await tester.pumpAndSettle();
    final after = tester.state<ScrollableState>(list).position.pixels;
    if (after <= before) return;
  }
}

PopupMenuItem<String> _menuItem(WidgetTester tester, String value) =>
    tester.widget<PopupMenuItem<String>>(
      find.byWidgetPredicate(
        (widget) => widget is PopupMenuItem<String> && widget.value == value,
      ),
    );

/// Hosts the history drawer as a real drawer route so row actions that pop
/// the drawer behave like production.
class _DrawerHost extends StatelessWidget {
  const _DrawerHost();

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: const TerminalHistoryDrawer(),
    body: const Center(child: Text('drawer host')),
  );
}

Future<void> _openDrawer(WidgetTester tester) async {
  tester
      .state<ScaffoldState>(
        find
            .descendant(
              of: find.byType(_DrawerHost),
              matching: find.byType(Scaffold),
            )
            .first,
      )
      .openDrawer();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'history drawer hide menu hides the entry without a remote operation',
    (tester) async {
      final record = _record();
      final notifier = _Notifier(
        SshTerminalState(tabs: const [], history: [record]),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(tester, _container(notifier), const _DrawerHost());
      await _openDrawer(tester);
      expect(find.text(record.title), findsOneWidget);
      await _openRowMenu(tester);
      expect(find.text(l10n.terminalHideSession), findsOneWidget);
      await tester.tap(find.text(l10n.terminalHideSession));
      await tester.pumpAndSettle();
      expect(notifier.deletions, <(String, bool, String?)>[
        (record.id, false, record.targetKey),
      ]);
      expect(
        notifier.deletions.single.$2,
        isFalse,
        reason: 'hiding must never terminate the remote session',
      );
      expect(notifier.state.hiddenRecordIds, contains(record.id));
      expect(find.text(record.title), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancelling remote termination confirmation performs no operation',
    (tester) async {
      final record = _record();
      final notifier = _Notifier(
        SshTerminalState(
          tabs: const [],
          history: [record],
          historyStatuses: const {'session-1': TerminalHistoryStatus.available},
        ),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(
        tester,
        _container(notifier, connected: true),
        const _DrawerHost(),
      );
      await _openDrawer(tester);
      await _openRowMenu(tester);
      await tester.tap(find.text(l10n.terminalTerminateSession));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
      await tester.pumpAndSettle();
      expect(notifier.deletions, isEmpty);
      expect(notifier.unhides, isEmpty);
      expect(notifier.state.hiddenRecordIds, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('remote termination confirmation terminates the pinned target', (
    tester,
  ) async {
    final record = _record();
    final notifier = _Notifier(
      SshTerminalState(
        tabs: const [],
        history: [record],
        historyStatuses: const {'session-1': TerminalHistoryStatus.available},
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      _container(notifier, connected: true),
      const _DrawerHost(),
    );
    await _openDrawer(tester);
    await _openRowMenu(tester);
    await tester.tap(find.text(l10n.terminalTerminateSession));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.terminalTerminateSession),
    );
    await tester.pumpAndSettle();
    expect(notifier.deletions, <(String, bool, String?)>[
      (record.id, true, record.targetKey),
    ]);
    expect(
      notifier.state.historyStatuses[record.id],
      TerminalHistoryStatus.ended,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ended history matching an open tab shows the ended badge and never restores',
    (tester) async {
      final record = _record();
      final bridge = _Bridge();
      final notifier = _Notifier(
        SshTerminalState(
          tabs: [
            TerminalTab(
              id: record.id,
              title: 'Terminal',
              terminal: bridge.terminal,
              bridge: bridge,
            ),
          ],
          history: [record],
          historyStatuses: const {'session-1': TerminalHistoryStatus.ended},
        ),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(tester, _container(notifier), const _DrawerHost());
      await _openDrawer(tester);
      expect(find.text(l10n.terminalStatusEndedUnrecoverable), findsOneWidget);
      expect(
        find.text(record.title),
        findsNothing,
        reason: 'an ended record must not be offered as a restorable row',
      );
      await tester.tap(find.text('Terminal'));
      await tester.pumpAndSettle();
      expect(notifier.restores, 0);
      expect(notifier.state.activeTab?.id, record.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unavailable history source is disabled and cannot be restored', (
    tester,
  ) async {
    final record = _record();
    final notifier = _Notifier(
      SshTerminalState(
        tabs: const [],
        history: [record],
        historyStatuses: const {'session-1': TerminalHistoryStatus.unavailable},
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(
      tester,
      _container(notifier, connected: true),
      const _DrawerHost(),
    );
    await _openDrawer(tester);
    expect(
      find.text(l10n.terminalStatusUnavailable),
      findsNWidgets(2),
      reason: 'the group header and the row badge both mark it unavailable',
    );
    await _openRowMenu(tester);
    expect(_menuItem(tester, 'restore').enabled, isFalse);
    expect(_menuItem(tester, 'terminate').enabled, isFalse);
    expect(_menuItem(tester, 'set_default').enabled, isFalse);
    await tester.tap(find.text(l10n.terminalTerminateSession));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text(record.title), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(notifier.restores, 0);
    expect(notifier.deletions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hidden history entry is listed under hidden sessions and can be unhidden',
    (tester) async {
      final record = _record();
      final notifier = _Notifier(
        SshTerminalState(
          tabs: const [],
          history: [record],
          hiddenRecordIds: [record.id],
        ),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await _pump(tester, _container(notifier), const _DrawerHost());
      await _openDrawer(tester);
      expect(
        find.text(record.title),
        findsNothing,
        reason: 'hidden entries are not listed in the main history list',
      );
      await tester.tap(find.byTooltip(l10n.terminalHiddenSessionsTitle));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(record.title), findsOneWidget);
      await tester.tap(
        find
            .ancestor(
              of: find.text(l10n.terminalUnhideSession),
              matching: find.byWidgetPredicate(
                (widget) => widget is TextButton,
              ),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(notifier.unhides, <(String, String?)>[
        (record.id, record.targetKey),
      ]);
      expect(notifier.state.hiddenRecordIds, isEmpty);
      expect(find.text(l10n.terminalNoHiddenSessions), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();
      expect(find.text(record.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('socket source dialog rejects invalid -L and -S input', (
    tester,
  ) async {
    final notifier = _Notifier(SshTerminalState(tabs: const []));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _pump(tester, _container(notifier), const _DrawerHost());
    await _openDrawer(tester);
    await tester.tap(find.byTooltip(l10n.terminalSocketSources));
    await tester.pumpAndSettle();
    final input = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    final add = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byIcon(Icons.add),
    );

    await tester.enterText(input, 'bad name!');
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text(l10n.terminalSocketInvalid), findsOneWidget);
    expect(notifier.socketAdds, isEmpty);

    await tester.tap(find.text(l10n.terminalSocketKindPath));
    await tester.pumpAndSettle();
    await tester.enterText(input, 'relative/path');
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text(l10n.terminalSocketInvalid), findsOneWidget);
    expect(notifier.socketAdds, isEmpty);

    await tester.enterText(input, '/tmp/../evil');
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text(l10n.terminalSocketInvalid), findsOneWidget);
    expect(notifier.socketAdds, isEmpty);

    await tester.enterText(input, '/tmp/ok.sock');
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text(l10n.terminalSocketInvalid), findsNothing);
    expect(notifier.socketAdds, hasLength(1));
    expect(notifier.socketAdds.single.$1.kind, TmuxSocketKind.path);
    expect(notifier.socketAdds.single.$1.value, '/tmp/ok.sock');
    expect(notifier.socketAdds.single.$2, notifier.targetKey);
    expect(tester.takeException(), isNull);
  });

  testWidgets('socket source add is refused after the active target changed', (
    tester,
  ) async {
    final notifier = _Notifier(SshTerminalState(tabs: const []));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final container = _container(notifier);
    await _pump(tester, container, const _DrawerHost());
    await _openDrawer(tester);
    await tester.tap(find.byTooltip(l10n.terminalSocketSources));
    await tester.pumpAndSettle();
    final other = terminalFixtureServer.copyWith(host: '192.0.2.11');
    (container.read(activeServerProvider.notifier) as _Active).select(other);
    notifier.targetKey = TerminalHistoryRecord.targetFor(other);
    await tester.pumpAndSettle();
    final input = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    final add = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byIcon(Icons.add),
    );
    await tester.enterText(input, 'work');
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(notifier.socketAdds, isEmpty);
    expect(notifier.socketAddAttempts, hasLength(1));
    expect(
      notifier.socketAddAttempts.single.$2,
      TerminalHistoryRecord.targetFor(terminalFixtureServer),
    );
    expect(find.text(l10n.terminalErrorTargetChanged), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'drawer history polling stops on close and dispose leaves no ref errors',
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
      final container = _container(notifier);
      await _pump(tester, container, const SshTerminalView());
      final scaffoldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Scaffold && widget.drawer is TerminalHistoryDrawer,
      );
      final canvas = tester.state<TerminalViewState>(find.byType(TerminalView));

      await tester.tap(find.byKey(const Key('terminal_history_button')));
      await tester.pumpAndSettle();
      expect(tester.state<ScaffoldState>(scaffoldFinder).isDrawerOpen, isTrue);
      expect(notifier.refreshes, 1);
      expect(canvas.hasInputConnection, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.pump(const Duration(seconds: 16));
      expect(notifier.refreshes, 2, reason: 'the drawer polls while open');

      await tester.tapAt(const Offset(380, 420));
      await tester.pumpAndSettle();
      expect(tester.state<ScaffoldState>(scaffoldFinder).isDrawerOpen, isFalse);
      await tester.pump(const Duration(seconds: 16));
      expect(notifier.refreshes, 2, reason: 'polling stops with the drawer');

      await _pump(tester, container, const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 16));
      expect(notifier.refreshes, 2, reason: 'dispose cancels the poller');
      expect(canvas.hasInputConnection, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets(
    'history entry and drawer dismissal never reopen the mobile keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = _Bridge();
      bridge.stateListenable.value = TerminalConnectionState.connected;
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
      final search = find.descendant(
        of: find.byType(TerminalHistoryDrawer),
        matching: find.byType(TextField),
      );
      // The drawer body is lazy, so the open entry only exists once the
      // list is scrolled down like a user would.
      await _revealInHistoryDrawer(tester, find.text(openTitle));
      await _revealInHistoryDrawer(tester, find.text(l10n.terminalStatusOpen));
      expect(find.text(l10n.terminalStatusOpen), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      // Scroll back up to the search field before typing in it.
      await _scrollHistoryDrawerToTop(tester);
      await _revealInHistoryDrawer(tester, search);
      await tester.enterText(search, 'قابلة');
      await tester.pumpAndSettle();
      await _revealInHistoryDrawer(tester, find.text(availableTitle));
      await _revealInHistoryDrawer(
        tester,
        find.text(l10n.terminalRestoreSession),
      );
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
