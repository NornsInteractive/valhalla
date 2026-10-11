import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/system/system_provider.dart';
import 'package:valhalla/features/system/system_view.dart';
import 'package:valhalla/infrastructure/system/service_manager.dart';
import 'package:valhalla/l10n/app_localizations.dart';

const _serverId = 'srv-1';

const _server = ServerProfile(
  id: _serverId,
  name: 'test host',
  host: 'one.test',
  username: 'root',
);

const _unit = SystemdServiceInfo(
  name: 'app.service',
  description: 'demo unit',
  state: 'running',
  startup: 'enabled',
);

List<Map<String, dynamic>> _records(int count, {int start = 0}) => [
  for (var i = start; i < start + count; i++)
    {
      '__CURSOR': 'c$i',
      '__REALTIME_TIMESTAMP': '${1728000000000000 + i}',
      'PRIORITY': '6',
      'MESSAGE': 'message-$i',
    },
];

class _FakeActiveServer extends ActiveServerNotifier {
  @override
  ServerProfile? build() => _server;
}

class _FakeConnection extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => const ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: _serverId,
  );
}

class _FakeSystemNotifier extends SystemNotifier {
  _FakeSystemNotifier(this._initial);

  final SystemState _initial;

  final List<({String service, String? beforeCursor})> logCalls = [];
  final List<List<Map<String, dynamic>>> queued = [];
  Completer<void>? logsGate;
  Object? logsError;

  @override
  SystemState build() => _initial;

  @override
  Future<List<Map<String, dynamic>>> serviceLogs(
    String service, {
    String? beforeCursor,
    required Object expectedConnectionKey,
  }) async {
    logCalls.add((service: service, beforeCursor: beforeCursor));
    final gate = logsGate;
    if (gate != null) await gate.future;
    final error = logsError;
    if (error != null) throw error;
    if (queued.isEmpty) return const [];
    return queued.removeAt(0);
  }

  @override
  Future<void> refreshAll({bool quiet = false}) async {}

  @override
  Future<void> refreshProcesses({bool quiet = false}) async {}

  @override
  Future<void> refreshServices({bool quiet = false}) async {}
}

Widget _app({
  required _FakeSystemNotifier notifier,
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return ProviderScope(
    overrides: [
      activeServerProvider.overrideWith(() => _FakeActiveServer()),
      serverConnectionProvider.overrideWith(() => _FakeConnection()),
      systemProvider.overrideWith(() => notifier),
    ],
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
      home: const SystemView(),
    ),
  );
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(SystemView)));

/// Refresh icon of the logs dialog; `find.byIcon` lands on the Icon child, so
/// the IconButton itself has to be reached through its ancestor.
Finder _dialogRefreshButton() => find.ancestor(
  of: find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byIcon(Icons.refresh),
  ),
  matching: find.byType(IconButton),
);

Finder _dialogListScrollable() => find
    .descendant(
      of: find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ListView),
      ),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    )
    .first;

/// `TextButton.icon` produces a `_TextButtonWithIcon` subclass, which
/// `find.byType` (exact runtime type) cannot match; a widget predicate keeps
/// the real callback reachable.
Finder _olderButton(AppLocalizations l10n) => find.ancestor(
  of: find.text(l10n.serviceLogsLoadOlder),
  matching: find.byWidgetPredicate((widget) => widget is TextButton),
);

Future<void> _openLogs(WidgetTester tester, AppLocalizations l10n) async {
  final servicesTab = find.text(l10n.tabServices);
  await tester.ensureVisible(servicesTab);
  await tester.pump();
  await tester.tap(servicesTab);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip(l10n.serviceLogsTitle));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Bounded, lazy-list scroll: the footer is only built once its offset comes
/// inside the viewport, so keep dragging until the label shows up.
Future<void> _revealLoadOlder(
  WidgetTester tester,
  AppLocalizations l10n,
) async {
  await tester.scrollUntilVisible(
    find.text(l10n.serviceLogsLoadOlder),
    300,
    scrollable: _dialogListScrollable(),
    maxScrolls: 120,
  );
  await tester.pumpAndSettle();
}

Future<void> _release(
  WidgetTester tester,
  _FakeSystemNotifier fake,
  Completer<void> gate,
) async {
  gate.complete();
  fake.logsGate = null;
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'initial 200 logs stay gated and duplicate callbacks cannot overlap',
    (tester) async {
      final fake = _FakeSystemNotifier(const SystemState(services: [_unit]));
      fake.queued.add(_records(200));
      final gate = Completer<void>();
      fake.logsGate = gate;

      await tester.pumpWidget(_app(notifier: fake));
      final l10n = _l10n(tester);

      await _openLogs(tester, l10n);

      expect(fake.logCalls, hasLength(1));
      expect(fake.logCalls.single.service, _unit.name);
      expect(fake.logCalls.single.beforeCursor, isNull);
      expect(
        tester.widget<IconButton>(_dialogRefreshButton()).onPressed,
        isNull,
        reason: 'refresh must stay disabled while the first page is gated',
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('message-0'), findsNothing);

      await _release(tester, fake, gate);

      expect(fake.logCalls, hasLength(1), reason: 'still a single request');
      expect(find.text('message-0'), findsOneWidget);
      expect(
        tester.widget<IconButton>(_dialogRefreshButton()).onPressed,
        isNotNull,
      );

      // Queue the short older page before it can be asked for, then capture the
      // two real callbacks while they are still enabled.
      fake.queued.add(_records(3, start: 1000));
      await _revealLoadOlder(tester, l10n);
      final olderCallback = tester
          .widget<TextButton>(_olderButton(l10n))
          .onPressed!;
      final refreshCallback = tester
          .widget<IconButton>(_dialogRefreshButton())
          .onPressed!;

      // A fresh gate makes the older request hang; the captured callbacks are
      // then exercised twice each while it is still in flight.
      final olderGate = Completer<void>();
      fake.logsGate = olderGate;
      olderCallback();
      olderCallback();
      refreshCallback();
      refreshCallback();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        fake.logCalls,
        hasLength(2),
        reason: 'only the older request may start; the duplicates add nothing',
      );
      expect(
        fake.logCalls.last.beforeCursor,
        'c199',
        reason: 'older page must carry the cursor of the last kept record',
      );

      await _release(tester, fake, olderGate);

      expect(
        fake.logCalls,
        hasLength(2),
        reason: 'no request was ever duplicated',
      );
      expect(find.text('message-1000'), findsOneWidget);
      expect(
        find.text(l10n.serviceLogsLoadOlder),
        findsNothing,
        reason: 'a short tail page offers no further older load',
      );
    },
  );

  testWidgets(
    'older failure keeps the initial rows and offers a localized retry',
    (tester) async {
      final fake = _FakeSystemNotifier(const SystemState(services: [_unit]));
      fake.queued.add(_records(200));
      final gate = Completer<void>();
      fake.logsGate = gate;

      await tester.pumpWidget(_app(notifier: fake));
      final l10n = _l10n(tester);

      await _openLogs(tester, l10n);
      await _release(tester, fake, gate);
      expect(find.text('message-0'), findsOneWidget);

      fake.logsError = const ValidationException('SERVICE_QUERY_FAILED');
      await _revealLoadOlder(tester, l10n);
      await tester.tap(find.text(l10n.serviceLogsLoadOlder));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(fake.logCalls, hasLength(2));
      expect(
        find.text(l10n.serviceQueryFailed),
        findsOneWidget,
        reason: 'the failure must surface as the localized query error',
      );
      expect(
        find.textContaining('SERVICE_QUERY_FAILED'),
        findsNothing,
        reason: 'the raw exception must never reach the dialog',
      );
      expect(
        find.widgetWithText(TextButton, l10n.sftpRefresh),
        findsOneWidget,
        reason: 'a retry stays available while the rows are kept',
      );

      await tester.scrollUntilVisible(
        find.text('message-0'),
        -300,
        scrollable: _dialogListScrollable(),
        maxScrolls: 120,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('message-0'),
        findsOneWidget,
        reason: 'the first visible message survives the failed older load',
      );
    },
  );

  testWidgets('320dp 2x text scale and RTL lay the logs dialog out cleanly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Diagnostic hook for the AgY-owned layout bug: forward to the framework
    // handler (nothing is suppressed) and log the full details of every error.
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      previousOnError?.call(details);
      FlutterError.dumpErrorToConsole(details, forceReport: true);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    final fake = _FakeSystemNotifier(const SystemState(services: [_unit]));
    fake.queued.add(_records(2));
    final gate = Completer<void>();
    fake.logsGate = gate;

    await tester.pumpWidget(
      _app(notifier: fake, locale: const Locale('ar'), textScale: 2),
    );
    final l10n = _l10n(tester);

    await _openLogs(tester, l10n);
    await _release(tester, fake, gate);

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(Directionality.of(tester.element(dialog)), TextDirection.rtl);
    expect(
      find.descendant(of: dialog, matching: find.textContaining(_unit.name)),
      findsOneWidget,
      reason: 'the unit name stays in the dialog title under RTL',
    );
    expect(find.text('message-0'), findsOneWidget);
    expect(find.text('message-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
