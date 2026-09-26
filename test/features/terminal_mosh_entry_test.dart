import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/terminal/terminal_view.dart';
import 'package:valhalla/infrastructure/mosh/mosh_bridge_adapter.dart';
import 'package:valhalla/infrastructure/mosh/mosh_providers.dart';
import 'package:valhalla/infrastructure/mosh/mosh_session_service.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

const _key = 'AAECAwQFBgcICQoLDA0ODw';

const _moshServer = ServerProfile(
  id: 'srv-mosh',
  name: 'roaming-box',
  host: '203.0.113.7',
  username: 'root',
  moshEnabled: true,
  moshServerPath: '/usr/bin/mosh-server',
  moshPortRange: '61000:62000',
);

const _plainServer = ServerProfile(
  id: 'srv-plain',
  name: 'plain-box',
  host: '203.0.113.8',
  username: 'root',
);

class _FakeHandle implements MoshSessionHandle {
  final _stdout = StreamController<List<int>>();
  final _errors = StreamController<Object>();
  final _done = Completer<void>();
  final sent = <List<int>>[];

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> get done => _done.future;

  @override
  void send(List<int> bytes) => sent.add(bytes);

  @override
  void resize(int columns, int rows) {}

  @override
  Future<void> dispose() async {
    if (!_done.isCompleted) _done.complete();
  }
}

class _FakeMoshService implements MoshSessionService {
  MoshBootstrapResult? bootstrapResult;

  final handles = <_FakeHandle>[];
  var bootstrapCalls = 0;
  MoshBootstrapRequest? lastRequest;

  @override
  Future<MoshBootstrapResult> bootstrap(MoshBootstrapRequest request) async {
    bootstrapCalls++;
    lastRequest = request;
    final result = bootstrapResult;
    if (result != null) return result;
    throw StateError('no bootstrap result scripted');
  }

  @override
  Future<MoshSessionHandle> connect(
    MoshEndpoint endpoint, {
    required int columns,
    required int rows,
  }) async {
    final handle = _FakeHandle();
    handles.add(handle);
    return handle;
  }
}

class _FakeActiveServerNotifier extends ActiveServerNotifier {
  _FakeActiveServerNotifier(this._server);

  final ServerProfile? _server;

  @override
  ServerProfile? build() => _server;
}

class _MockTerminalNotifier extends TerminalNotifier {
  _MockTerminalNotifier(this._initial);

  final SshTerminalState _initial;

  @override
  SshTerminalState build() => _initial;
}

Widget _buildTestApp({
  required _FakeMoshService moshService,
  required ServerProfile? activeServer,
  required _MockTerminalNotifier notifier,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      terminalProvider.overrideWith(() => notifier),
      activeServerProvider.overrideWith(
        () => _FakeActiveServerNotifier(activeServer),
      ),
      moshSessionServiceProvider.overrideWithValue(moshService),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SshTerminalView()),
    ),
  );
}

_MockTerminalNotifier _notifierFor({required bool moshAvailable}) {
  final sshBridge = TerminalSessionBridge(
    terminal: Terminal(maxLines: 200),
    serverName: 'test-server',
    serverId: 'srv-1',
  );
  return _MockTerminalNotifier(
    SshTerminalState(
      tabs: [
        TerminalTab(
          id: 'tab-1',
          title: 'bash #1',
          terminal: sshBridge.terminal,
          bridge: sshBridge,
        ),
      ],
      activeTabIndex: 0,
      moshAvailable: moshAvailable,
    ),
  );
}

void main() {
  testWidgets(
    'mosh entry appears for mosh-enabled server and creates a Mosh bridge tab',
    (tester) async {
      final service = _FakeMoshService()
        ..bootstrapResult = MoshBootstrapSuccess(
          endpoint: MoshEndpoint(
            host: _moshServer.host,
            port: 60001,
            key: _key,
          ),
          rawOutput: 'MOSH CONNECT 60001 $_key',
        );
      final notifier = _notifierFor(moshAvailable: true);

      await tester.pumpWidget(
        _buildTestApp(
          moshService: service,
          activeServer: _moshServer,
          notifier: notifier,
        ),
      );
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.byKey(const Key('terminal_new_mosh_tab')), findsOneWidget);

      await tester.tap(find.byKey(const Key('terminal_new_mosh_tab')));
      await tester.pumpAndSettle();

      // A Mosh bridge tab was created and bootstrapped through the service.
      expect(service.bootstrapCalls, 1);
      expect(service.lastRequest!.serverId, 'srv-mosh');
      expect(service.lastRequest!.host, '203.0.113.7');
      expect(service.lastRequest!.serverPath, '/usr/bin/mosh-server');
      expect(service.lastRequest!.portRange, '61000:62000');

      final newTab = notifier.state.tabs.last;
      expect(newTab.bridge, isA<MoshBridgeAdapter>());
      expect(newTab.bridge.state, TerminalConnectionState.connected);
      expect(notifier.state.activeTabIndex, notifier.state.tabs.length - 1);

      // Tab is visually identified with the l10n tag suffix.
      expect(find.textContaining('(${l10n.moshSessionTag})'), findsOneWidget);
    },
  );

  testWidgets(
    'mosh entry is absent when the active server has no mosh enabled',
    (tester) async {
      final service = _FakeMoshService();
      final notifier = _notifierFor(moshAvailable: false);

      await tester.pumpWidget(
        _buildTestApp(
          moshService: service,
          activeServer: _plainServer,
          notifier: notifier,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('terminal_new_mosh_tab')), findsNothing);
      expect(service.bootstrapCalls, 0);
    },
  );

  testWidgets('bootstrap notInstalled shows the friendly install hint notice', (
    tester,
  ) async {
    final service = _FakeMoshService()
      ..bootstrapResult = const MoshBootstrapFailure(
        error: MoshBootstrapError.notInstalled,
      );
    final notifier = _notifierFor(moshAvailable: true);

    await tester.pumpWidget(
      _buildTestApp(
        moshService: service,
        activeServer: _moshServer,
        notifier: notifier,
      ),
    );
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const Key('terminal_new_mosh_tab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('terminalMoshErrorNotice')), findsOneWidget);
    expect(find.text(l10n.moshNotInstalled), findsOneWidget);
  });

  testWidgets('bootstrap timeout shows the UDP troubleshooting notice', (
    tester,
  ) async {
    final service = _FakeMoshService()
      ..bootstrapResult = const MoshBootstrapFailure(
        error: MoshBootstrapError.timeout,
      );
    final notifier = _notifierFor(moshAvailable: true);

    await tester.pumpWidget(
      _buildTestApp(
        moshService: service,
        activeServer: _moshServer,
        notifier: notifier,
      ),
    );
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byKey(const Key('terminal_new_mosh_tab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('terminalMoshErrorNotice')), findsOneWidget);
    expect(find.text(l10n.moshUdpTimeout), findsOneWidget);
  });

  testWidgets(
    'bootstrap start failure shows error state with detail without crashing',
    (tester) async {
      final service = _FakeMoshService()
        ..bootstrapResult = const MoshBootstrapFailure(
          error: MoshBootstrapError.startFailed,
          detail: 'exit code 1: mosh-server crashed',
        );
      final notifier = _notifierFor(moshAvailable: true);

      await tester.pumpWidget(
        _buildTestApp(
          moshService: service,
          activeServer: _moshServer,
          notifier: notifier,
        ),
      );
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.byKey(const Key('terminal_new_mosh_tab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('terminalMoshErrorNotice')), findsOneWidget);
      expect(
        find.text(l10n.moshBootstrapFailed('exit code 1: mosh-server crashed')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('adapter forwards accessory bar keys through the mosh session', (
    tester,
  ) async {
    final service = _FakeMoshService()
      ..bootstrapResult = MoshBootstrapSuccess(
        endpoint: MoshEndpoint(host: _moshServer.host, port: 60001, key: _key),
        rawOutput: 'MOSH CONNECT 60001 $_key',
      );
    final notifier = _notifierFor(moshAvailable: true);

    await tester.pumpWidget(
      _buildTestApp(
        moshService: service,
        activeServer: _moshServer,
        notifier: notifier,
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('terminal_new_mosh_tab')));
    await tester.pumpAndSettle();

    final adapter = notifier.state.tabs.last.bridge as MoshBridgeAdapter;
    final handle = service.handles.single;

    // Accessory bar paths route through terminal.onOutput, which the Mosh
    // bridge wired to session.send.
    adapter.sendCommand('ls -l');
    adapter.sendKey('ESC');
    adapter.sendKey('C', isCtrl: true);

    final sent = handle.sent.map(utf8.decode).join();
    expect(sent, contains('ls -l\n'));
    expect(sent, contains('\x1b'));
    expect(sent, contains('\x03'));
  });
}
