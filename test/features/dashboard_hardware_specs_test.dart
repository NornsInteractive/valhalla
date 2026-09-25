import 'dart:async';

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
import 'package:valhalla/infrastructure/system/system_hardware_service.dart';
import 'package:valhalla/infrastructure/system/system_metrics_sampler.dart';
import 'package:valhalla/l10n/app_localizations.dart';

ServerProfile _testServer({
  String id = 'srv-test-1',
  String name = 'Test Server',
}) => ServerProfile(
  id: id,
  name: name,
  host: '192.168.1.100',
  port: 22,
  username: 'root',
);

class _FakeActiveServerNotifier extends ActiveServerNotifier {
  ServerProfile? _server;
  _FakeActiveServerNotifier(this._server);

  @override
  ServerProfile? build() => _server;

  void setServer(ServerProfile? s) {
    _server = s;
    state = s;
  }
}

class _FakeConnectionNotifier extends ServerConnectionNotifier {
  final ServerConnectionState _conn;
  _FakeConnectionNotifier(this._conn);

  @override
  ServerConnectionState build() => _conn;
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

void main() {
  group('Dashboard Server Hardware Specs', () {
    testWidgets(
      'displays full hardware specs with JetBrains Mono when connected and data loaded',
      (tester) async {
        final server = _testServer();
        final connState = ServerConnectionState(
          status: ConnectionStateEnum.connected,
          activeServerId: server.id,
        );

        const info = SystemHardwareInfo(
          cpuModel: 'AMD EPYC 7763',
          cpuCores: 64,
          memoryTotalKiB: 33554432, // 32 GB
          rootDiskTotalKiB: 524288000, // 500 GB
          distribution: 'Ubuntu 22.04.3 LTS',
          kernel: '5.15.0-88-generic',
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
                (ref) => Stream.value(
                  const SystemMetricsSnapshot(
                    cpuUsedRatio: 0.2,
                    memoryUsedRatio: 0.4,
                    rootDiskUsedPercent: 30,
                    load1: 0.5,
                    load5: 0.3,
                  ),
                ),
              ),
              systemHardwareProvider.overrideWith((ref) async => info),
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

        expect(
          find.byKey(const Key('dashboard_hardware_specs_card')),
          findsOneWidget,
        );

        // CPU
        final cpuFinder = find.byKey(const Key('dashboard_hardware_cpu'));
        expect(cpuFinder, findsOneWidget);
        expect(
          find.descendant(
            of: cpuFinder,
            matching: find.textContaining('AMD EPYC 7763 (64 Cores)'),
          ),
          findsOneWidget,
        );

        // Memory
        final memFinder = find.byKey(const Key('dashboard_hardware_memory'));
        expect(memFinder, findsOneWidget);
        expect(
          find.descendant(of: memFinder, matching: find.text('32.0 GB')),
          findsOneWidget,
        );

        // Disk
        final diskFinder = find.byKey(const Key('dashboard_hardware_disk'));
        expect(diskFinder, findsOneWidget);
        expect(
          find.descendant(of: diskFinder, matching: find.text('500.0 GB')),
          findsOneWidget,
        );

        // OS distribution
        final osFinder = find.byKey(
          const Key('dashboard_hardware_distribution'),
        );
        expect(osFinder, findsOneWidget);
        expect(
          find.descendant(
            of: osFinder,
            matching: find.text('Ubuntu 22.04.3 LTS'),
          ),
          findsOneWidget,
        );

        // Kernel
        final kernelFinder = find.byKey(const Key('dashboard_hardware_kernel'));
        expect(kernelFinder, findsOneWidget);
        expect(
          find.descendant(
            of: kernelFinder,
            matching: find.text('5.15.0-88-generic'),
          ),
          findsOneWidget,
        );

        // Verify JetBrains Mono font family on the value text
        final textWidgets = tester.widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('dashboard_hardware_specs_card')),
            matching: find.byType(Text),
          ),
        );
        final monoText = textWidgets.firstWhere(
          (t) => t.style?.fontFamily == 'JetBrains Mono',
        );
        expect(monoText.data, isNotNull);
      },
    );

    testWidgets(
      'displays fallback unknown when hardware specs fields are null',
      (tester) async {
        final server = _testServer();
        final connState = ServerConnectionState(
          status: ConnectionStateEnum.connected,
          activeServerId: server.id,
        );

        const emptyInfo = SystemHardwareInfo();

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
                (ref) => Stream.value(
                  const SystemMetricsSnapshot(
                    cpuUsedRatio: 0.1,
                    memoryUsedRatio: 0.1,
                    rootDiskUsedPercent: 10,
                    load1: 0.1,
                    load5: 0.1,
                  ),
                ),
              ),
              systemHardwareProvider.overrideWith((ref) async => emptyInfo),
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

        expect(
          find.byKey(const Key('dashboard_hardware_specs_card')),
          findsOneWidget,
        );
        // All fields should show Unknown
        expect(find.text('Unknown'), findsNWidgets(5));
      },
    );

    testWidgets('displays concise loading indicator while loading', (
      tester,
    ) async {
      final server = _testServer();
      final connState = ServerConnectionState(
        status: ConnectionStateEnum.connected,
        activeServerId: server.id,
      );

      final completer = Completer<SystemHardwareInfo>();

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
              (ref) => Stream.value(
                const SystemMetricsSnapshot(
                  cpuUsedRatio: 0.1,
                  memoryUsedRatio: 0.1,
                  rootDiskUsedPercent: 10,
                  load1: 0.1,
                  load5: 0.1,
                ),
              ),
            ),
            systemHardwareProvider.overrideWith((ref) => completer.future),
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
      await tester.pump();

      expect(
        find.byKey(const Key('dashboard_hardware_loading')),
        findsOneWidget,
      );
      expect(find.text('Loading hardware specs...'), findsOneWidget);
    });

    testWidgets('displays concise error message when hardware query fails', (
      tester,
    ) async {
      final server = _testServer();
      final connState = ServerConnectionState(
        status: ConnectionStateEnum.connected,
        activeServerId: server.id,
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
              (ref) => Stream.value(
                const SystemMetricsSnapshot(
                  cpuUsedRatio: 0.1,
                  memoryUsedRatio: 0.1,
                  rootDiskUsedPercent: 10,
                  load1: 0.1,
                  load5: 0.1,
                ),
              ),
            ),
            systemHardwareProvider.overrideWith(
              (ref) => Future<SystemHardwareInfo>.error(
                StateError('HARDWARE_QUERY_FAILED'),
              ),
            ),
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

      expect(find.byKey(const Key('dashboard_hardware_error')), findsOneWidget);
      expect(find.text('Hardware specs unavailable'), findsOneWidget);
    });

    testWidgets('does not render hardware specs when disconnected', (
      tester,
    ) async {
      final server = _testServer();
      final connState = const ServerConnectionState(
        status: ConnectionStateEnum.disconnected,
        activeServerId: null,
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

      expect(
        find.byKey(const Key('dashboard_hardware_specs_card')),
        findsNothing,
      );
      expect(find.byKey(const Key('dashboard_hardware_loading')), findsNothing);
      expect(find.byKey(const Key('dashboard_hardware_error')), findsNothing);
    });

    testWidgets('pull to refresh invalidates systemHardwareProvider', (
      tester,
    ) async {
      final server = _testServer();
      final connState = ServerConnectionState(
        status: ConnectionStateEnum.connected,
        activeServerId: server.id,
      );

      int queryCount = 0;

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
              (ref) => Stream.value(
                const SystemMetricsSnapshot(
                  cpuUsedRatio: 0.1,
                  memoryUsedRatio: 0.1,
                  rootDiskUsedPercent: 10,
                  load1: 0.1,
                  load5: 0.1,
                ),
              ),
            ),
            systemHardwareProvider.overrideWith((ref) async {
              queryCount++;
              return SystemHardwareInfo(
                cpuModel: 'Intel Xeon $queryCount',
                cpuCores: 8,
              );
            }),
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

      expect(queryCount, 1);
      expect(find.textContaining('Intel Xeon 1'), findsOneWidget);

      // Perform pull to refresh
      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(queryCount, 2);
      expect(find.textContaining('Intel Xeon 2'), findsOneWidget);
    });
  });
}
