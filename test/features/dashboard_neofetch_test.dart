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
import 'package:valhalla/features/dashboard/widgets/neofetch_sheet.dart';
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

Widget _wrapHarness(SystemHardwareInfo info) {
  final server = _testServer();
  final connState = ServerConnectionState(
    status: ConnectionStateEnum.connected,
    activeServerId: server.id,
  );
  return ProviderScope(
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
  );
}

void main() {
  group('resolveNeofetchArt', () {
    test('matches distro pretty names to the right art', () {
      expect(resolveNeofetchArt('Ubuntu 24.04 LTS'), NeofetchArt.ubuntu);
      expect(resolveNeofetchArt('Debian GNU/Linux 12'), NeofetchArt.debian);
      expect(resolveNeofetchArt('Arch Linux'), NeofetchArt.arch);
      expect(resolveNeofetchArt('Fedora Linux 40'), NeofetchArt.fedora);
      expect(resolveNeofetchArt('CentOS Stream'), NeofetchArt.centos);
      expect(resolveNeofetchArt('Alpine Linux v3.20'), NeofetchArt.alpine);
      expect(resolveNeofetchArt('openSUSE Leap 15'), NeofetchArt.suse);
      expect(resolveNeofetchArt('Raspbian GNU/Linux 11'), NeofetchArt.raspberry);
      expect(resolveNeofetchArt('Rocky Linux 9'), NeofetchArt.centos);
      expect(resolveNeofetchArt('MyCustomOS'), NeofetchArt.tux);
      expect(resolveNeofetchArt(null), NeofetchArt.tux);
    });

    test('maps distro variants and always falls back to tux', () {
      expect(resolveNeofetchArt('Manjaro Linux'), NeofetchArt.arch);
      expect(resolveNeofetchArt('Kali GNU/Linux Rolling'), NeofetchArt.debian);
      expect(
        resolveNeofetchArt('Red Hat Enterprise Linux 9'),
        NeofetchArt.centos,
      );
      expect(resolveNeofetchArt('RHEL 9.4'), NeofetchArt.centos);
      expect(resolveNeofetchArt('AlmaLinux 9'), NeofetchArt.centos);
      expect(resolveNeofetchArt('Deepin 23'), NeofetchArt.tux);
      expect(resolveNeofetchArt(''), NeofetchArt.tux);
    });

    test('art registry stays within bounds and pure ASCII', () {
      for (final art in NeofetchArt.values) {
        final lines = neofetchArtLines(art);
        expect(lines, isNotEmpty, reason: '$art must not be empty');
        expect(lines.length, lessThanOrEqualTo(16), reason: '$art too tall');
        final width = lines.first.length;
        expect(
          width,
          lessThanOrEqualTo(20),
          reason: '$art too wide',
        );
        for (final line in lines) {
          expect(line.length, width, reason: '$art lines not aligned');
          expect(
            RegExp(r'^[\x20-\x7E]+$').hasMatch(line),
            isTrue,
            reason: '$art contains non-ASCII: $line',
          );
        }
      }
    });
  });

  group('Dashboard neofetch sheet', () {
    const info = SystemHardwareInfo(
      cpuModel: 'AMD EPYC 7763',
      cpuCores: 64,
      memoryTotalKiB: 33554432, // 32 GB
      rootDiskTotalKiB: 524288000, // 500 GB
      distribution: 'Ubuntu 22.04.3 LTS',
      kernel: '5.15.0-88-generic',
    );

    testWidgets('tapping OS row opens the neofetch sheet with art and info', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapHarness(info));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('dashboard_hardware_os_tappable')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('dashboard_hardware_os_tappable')),
      );
      await tester.pumpAndSettle();

      // Sheet header
      expect(find.text('System Info'), findsOneWidget);
      // Server name shown as subtitle (also rendered by the dashboard header)
      expect(find.text('Test Server'), findsNWidgets(2));
      // Ubuntu art (single multi-line Text) — the ring of friends stroke
      expect(find.textContaining('---(_)'), findsOneWidget);
      // OS pretty name + kernel appear both in specs row and in the sheet
      expect(find.text('Ubuntu 22.04.3 LTS'), findsNWidgets(2));
      expect(find.text('5.15.0-88-generic'), findsNWidgets(2));
      // Host line from user@host
      expect(find.text('root@192.168.1.100'), findsOneWidget);
      // Memory line: total + used ratio from metrics snapshot
      expect(find.text('32.0 GB · 40.0%'), findsOneWidget);
      // Disk line
      expect(find.textContaining('500.0 GB'), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('System Info'), findsNothing);
    });

    testWidgets('renders without overflow at narrow width (360dp)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrapHarness(info));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const Key('dashboard_hardware_os_tappable')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('System Info'), findsOneWidget);
      expect(find.textContaining('---(_)'), findsOneWidget);
      expect(find.text('root@192.168.1.100'), findsOneWidget);
    });
  });
}
