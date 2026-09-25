import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/server_power_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/dashboard/dashboard_provider.dart';
import 'package:valhalla/features/dashboard/dashboard_view.dart';
import 'package:valhalla/features/dashboard/widgets/metric_trend_dialog.dart';
import 'package:valhalla/features/dashboard/widgets/network_details_modal.dart';
import 'package:valhalla/infrastructure/system/disk_usage_service.dart';
import 'package:valhalla/infrastructure/system/process_service.dart';
import 'package:valhalla/infrastructure/system/system_metrics_sampler.dart';
import 'package:valhalla/l10n/app_localizations.dart';

ServerProfile _testServer() => const ServerProfile(
  id: 'srv-test-1',
  name: 'Production Server',
  host: '192.168.1.100',
  port: 22,
  username: 'root',
);

class _FakeActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _initial;
  _FakeActiveServerNotifier(this._initial);
  @override
  ServerProfile? build() => _initial;
}

class _FakeConnectionNotifier extends ServerConnectionNotifier {
  final ServerConnectionState _initial;
  _FakeConnectionNotifier(this._initial);
  @override
  ServerConnectionState build() => _initial;
}

class _FakeTerminalNotifier extends TerminalNotifier {
  @override
  SshTerminalState build() => SshTerminalState(tabs: const []);
}

class _FakeAiChatNotifier extends AiChatNotifier {
  @override
  AiChatState build() => const AiChatState();
}

class _FakeCliChatNotifier extends CliChatNotifier {
  @override
  CliChatState build() =>
      const CliChatState(serverId: 'srv-test-1', agents: []);
}

class _FakeSftpNotifier extends SftpNotifier {
  @override
  SftpState build() => const SftpState();
}

class _FakeServerPowerNotifier extends ServerPowerNotifier {
  @override
  ServerPowerState build() => const ServerPowerState();
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  SystemMetricsSnapshot snapshot = const SystemMetricsSnapshot(
    cpuUsedRatio: 0.35,
    memoryUsedRatio: 0.55,
    rootDiskUsedPercent: 60,
    load1: 1.25,
    load5: 0.85,
  ),
  List<ProcessInfo> processes = const [
    ProcessInfo(
      pid: 101,
      cpuPercent: 55.0,
      memoryPercent: 15.0,
      rssKiB: 150000,
      state: 'R',
      command: 'valhalla-worker',
    ),
    ProcessInfo(
      pid: 102,
      cpuPercent: 12.0,
      memoryPercent: 30.0,
      rssKiB: 300000,
      state: 'S',
      command: 'database-engine',
    ),
  ],
  RootDiskUsage diskUsage = const RootDiskUsage(
    totalKiB: 104857600, // 100 GB
    usedKiB: 41943040, // 40 GB
    availableKiB: 62914560, // 60 GB
    partial: false,
    directories: [
      DirectoryUsage('/var', 20971520),
      DirectoryUsage('/usr', 10485760),
    ],
  ),
  bool isConnected = true,
}) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final server = _testServer();
  final connState = ServerConnectionState(
    status: isConnected
        ? ConnectionStateEnum.connected
        : ConnectionStateEnum.disconnected,
    activeServerId: isConnected ? server.id : null,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeServerProvider.overrideWith(
          () => _FakeActiveServerNotifier(server),
        ),
        serverConnectionProvider.overrideWith(
          () => _FakeConnectionNotifier(connState),
        ),
        systemMetricsStreamProvider.overrideWith(
          (ref) => Stream.value(snapshot),
        ),
        resourceProcessesProvider.overrideWith(
          (ref) => Stream.value(processes),
        ),
        rootDiskUsageProvider.overrideWith((ref) async => diskUsage),
        terminalProvider.overrideWith(_FakeTerminalNotifier.new),
        aiChatProvider.overrideWith(_FakeAiChatNotifier.new),
        cliChatProvider.overrideWith(_FakeCliChatNotifier.new),
        sftpProvider.overrideWith(_FakeSftpNotifier.new),
        serverPowerProvider.overrideWith(_FakeServerPowerNotifier.new),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DashboardView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Dashboard Resource Usage Sheet', () {
    testWidgets(
      'tapping CPU card opens resource sheet with CPU stats and process list sorted by CPU',
      (tester) async {
        await _pumpDashboard(tester);

        final cpuCard = find.byKey(const Key('dashboard_metric_cpu'));
        expect(cpuCard, findsOneWidget);

        await tester.tap(cpuCard);
        await tester.pumpAndSettle();

        // Modal sheet is open
        expect(find.byType(MetricTrendSheet), findsOneWidget);
        expect(find.textContaining('valhalla-worker'), findsOneWidget);
        expect(find.textContaining('database-engine'), findsOneWidget);
        expect(find.textContaining('PID 101'), findsOneWidget);
        expect(find.textContaining('CPU 55.0%'), findsOneWidget);

        // Verify close button closes modal
        final closeButton = find.byIcon(Icons.close);
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        expect(find.byType(MetricTrendSheet), findsNothing);
      },
    );

    testWidgets(
      'tapping Memory card opens resource sheet with memory stats and process list sorted by RSS',
      (tester) async {
        await _pumpDashboard(tester);

        final memoryCard = find.byKey(const Key('dashboard_metric_memory'));
        expect(memoryCard, findsOneWidget);

        await tester.tap(memoryCard);
        await tester.pumpAndSettle();

        // Modal sheet is open
        expect(find.byType(MetricTrendSheet), findsOneWidget);
        expect(find.textContaining('55.0%'), findsWidgets); // Used %
        expect(find.textContaining('45.0%'), findsWidgets); // Available %
        expect(find.textContaining('100%'), findsWidgets); // Total %
        expect(find.textContaining('database-engine'), findsOneWidget);
        expect(find.textContaining('valhalla-worker'), findsOneWidget);

        // Close modal
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.byType(MetricTrendSheet), findsNothing);
      },
    );

    testWidgets(
      'tapping Disk card opens resource sheet with disk usage and directory breakdown',
      (tester) async {
        await _pumpDashboard(tester);

        final diskCard = find.byKey(const Key('dashboard_metric_disk'));
        expect(diskCard, findsOneWidget);

        await tester.tap(diskCard);
        await tester.pumpAndSettle();

        // Modal sheet is open
        expect(find.byType(MetricTrendSheet), findsOneWidget);
        expect(find.byKey(const Key('disk_directories_list')), findsOneWidget);
        expect(find.text('/var'), findsOneWidget);
        expect(find.text('/usr'), findsOneWidget);

        // Refresh button exists
        final refreshButton = find.byKey(const Key('disk_refresh_button'));
        expect(refreshButton, findsOneWidget);
        await tester.tap(refreshButton);
        await tester.pumpAndSettle();

        // Close modal
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.byType(MetricTrendSheet), findsNothing);
      },
    );

    testWidgets(
      'shows partial scan warning banner when disk usage is partial',
      (tester) async {
        await _pumpDashboard(
          tester,
          diskUsage: const RootDiskUsage(
            totalKiB: 104857600,
            usedKiB: 41943040,
            availableKiB: 62914560,
            partial: true,
            directories: [DirectoryUsage('/var', 20971520)],
          ),
        );

        await tester.tap(find.byKey(const Key('dashboard_metric_disk')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('disk_partial_banner')), findsOneWidget);
      },
    );

    testWidgets('displays stopped banner when disconnected', (tester) async {
      final server = _testServer();
      const connState = ServerConnectionState(
        status: ConnectionStateEnum.disconnected,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerProvider.overrideWith(
              () => _FakeActiveServerNotifier(server),
            ),
            serverConnectionProvider.overrideWith(
              () => _FakeConnectionNotifier(connState),
            ),
            resourceProcessesProvider.overrideWith(
              (ref) => Stream.value(const <ProcessInfo>[]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: MetricTrendSheet(type: MetricTrendType.cpu)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('uptime is displayed in server header card', (tester) async {
      await _pumpDashboard(tester);

      final uptimeChip = find.byKey(const Key('dashboard_server_uptime'));
      expect(uptimeChip, findsOneWidget);
    });

    testWidgets(
      'network card displays waiting for second sample on initial sample',
      (tester) async {
        const snap = SystemMetricsSnapshot(
          primaryNetworkInterface: 'eth0',
          networkCounters: {'eth0': (1000, 2000)},
          networkRates: {},
        );

        await _pumpDashboard(tester, snapshot: snap);

        expect(find.text('Waiting for second sample'), findsOneWidget);
        expect(find.text('Interface: eth0'), findsOneWidget);
        expect(find.text('0 B/s'), findsNothing);
        expect(find.text('Interface: default'), findsNothing);
      },
    );

    testWidgets(
      'network card displays unavailable and no default route when interface missing',
      (tester) async {
        const snap = SystemMetricsSnapshot(
          primaryNetworkInterface: null,
          networkCounters: {},
          networkRates: {},
        );

        await _pumpDashboard(tester, snapshot: snap);

        expect(find.text('Unavailable'), findsOneWidget);
        expect(find.text('No default route'), findsOneWidget);
        expect(find.text('0 B/s'), findsNothing);
        expect(find.text('Interface: default'), findsNothing);
      },
    );

    testWidgets(
      'network card displays genuine 0 B/s when second sample rate is 0',
      (tester) async {
        const snap = SystemMetricsSnapshot(
          primaryNetworkInterface: 'eth0',
          networkCounters: {'eth0': (1000, 2000)},
          networkRates: {
            'eth0': NetworkRate(rxBytesPerSecond: 0.0, txBytesPerSecond: 0.0),
          },
        );

        await _pumpDashboard(tester, snapshot: snap);

        expect(find.text('0 B/s'), findsNWidgets(2));
        expect(find.text('Interface: eth0'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping network card opens network details modal and shows waiting for second sample',
      (tester) async {
        const snap = SystemMetricsSnapshot(
          primaryNetworkInterface: 'eth0',
          networkCounters: {'eth0': (1000, 2000)},
          networkRates: {},
        );

        await _pumpDashboard(tester, snapshot: snap);

        final networkCard = find.byKey(const Key('dashboard_metric_network'));
        expect(networkCard, findsOneWidget);

        await tester.tap(networkCard);
        await tester.pumpAndSettle();

        expect(find.byType(NetworkDetailsModal), findsOneWidget);
        expect(find.text('Waiting for second sample'), findsWidgets);
      },
    );
  });
}
