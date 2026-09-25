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
import 'package:valhalla/infrastructure/system/system_metrics_sampler.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/status_badge.dart';

ServerProfile _testServer({
  String username = 'root',
  String host = 'production.extremely-long-hostname.example.com',
  int port = 2222,
}) => ServerProfile(
  id: 'srv-test-1',
  name: 'Primary Cluster Server',
  host: host,
  port: port,
  username: username,
);

class _FakeActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _server;
  _FakeActiveServerNotifier(this._server);
  @override
  ServerProfile? build() => _server;
}

class _FakeConnectionNotifier extends ServerConnectionNotifier {
  final ServerConnectionState _state;
  _FakeConnectionNotifier(this._state);
  @override
  ServerConnectionState build() => _state;
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

class _FakeTerminalNotifier extends TerminalNotifier {
  @override
  SshTerminalState build() => SshTerminalState(tabs: const []);
}

class _FakeServerPowerNotifier extends ServerPowerNotifier {
  @override
  ServerPowerState build() => const ServerPowerState();
}

Future<void> _pumpDashboardHeader(
  WidgetTester tester, {
  required ServerConnectionState connState,
  ServerProfile? server,
  Size size = const Size(800, 600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final targetServer = server ?? _testServer();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeServerProvider.overrideWith(
          () => _FakeActiveServerNotifier(targetServer),
        ),
        serverConnectionProvider.overrideWith(
          () => _FakeConnectionNotifier(connState),
        ),
        aiChatProvider.overrideWith(() => _FakeAiChatNotifier()),
        cliChatProvider.overrideWith(() => _FakeCliChatNotifier()),
        sftpProvider.overrideWith(() => _FakeSftpNotifier()),
        terminalProvider.overrideWith(() => _FakeTerminalNotifier()),
        serverPowerProvider.overrideWith(() => _FakeServerPowerNotifier()),
        systemMetricsStreamProvider.overrideWith(
          (ref) => Stream.value(
            const SystemMetricsSnapshot(
              cpuUsedRatio: 0.2,
              memoryUsedRatio: 0.4,
              rootDiskUsedPercent: 50,
            ),
          ),
        ),
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
  group('Dashboard Server Header StatusBadge & Layout', () {
    testWidgets(
      'StatusBadge is placed on the address row next to username@host:port, not in action buttons',
      (tester) async {
        await _pumpDashboardHeader(
          tester,
          connState: const ServerConnectionState(
            status: ConnectionStateEnum.connected,
          ),
        );

        final badgeFinder = find.byType(StatusBadge);
        expect(badgeFinder, findsOneWidget);

        final badge = tester.widget<StatusBadge>(badgeFinder);
        expect(badge.label, 'Connected');
        expect(badge.type, StatusType.online);

        // Verify StatusBadge is in a Row with the address
        final addressTextFinder = find.text(
          'root@production.extremely-long-hostname.example.com:2222',
        );
        expect(addressTextFinder, findsOneWidget);

        final addressRowFinder = find.ancestor(
          of: addressTextFinder,
          matching: find.byType(Row),
        );
        expect(addressRowFinder, findsWidgets);

        // The StatusBadge should be a descendant of the same address Row
        expect(
          find.descendant(of: addressRowFinder.first, matching: badgeFinder),
          findsOneWidget,
        );

        // Verify actionButtons row (Wrap) contains reboot/shutdown/disconnect but NOT StatusBadge
        final actionButtonsWrapFinder = find.byWidgetPredicate((w) {
          if (w is Wrap) {
            return w.children.any(
              (child) =>
                  child.key == const Key('dashboard_reboot_button') ||
                  child.key == const Key('dashboard_disconnect_button'),
            );
          }
          return false;
        });
        expect(actionButtonsWrapFinder, findsOneWidget);

        final wrapWidget = tester.widget<Wrap>(actionButtonsWrapFinder);
        final wrapContainsStatusBadge = wrapWidget.children.any(
          (child) => child is StatusBadge,
        );
        expect(
          wrapContainsStatusBadge,
          isFalse,
          reason: 'actionButtons row must no longer contain StatusBadge',
        );
      },
    );

    testWidgets(
      'narrow viewport truncates server address with ellipsis while StatusBadge remains visible without overflow',
      (tester) async {
        await _pumpDashboardHeader(
          tester,
          size: const Size(280, 600),
          connState: const ServerConnectionState(
            status: ConnectionStateEnum.connected,
          ),
        );

        // No flutter layout overflow errors should have occurred
        expect(tester.takeException(), isNull);

        // Address text widget has overflow set to TextOverflow.ellipsis
        final addressFinder = find.byWidgetPredicate((w) {
          if (w is Text &&
              w.data != null &&
              w.data!.contains('extremely-long-hostname')) {
            return w.overflow == TextOverflow.ellipsis;
          }
          return false;
        });
        expect(addressFinder, findsOneWidget);

        // StatusBadge is still rendered and fully visible
        final badgeFinder = find.byType(StatusBadge);
        expect(badgeFinder, findsOneWidget);
        expect(tester.getTopLeft(badgeFinder).dx, greaterThan(0));
      },
    );

    testWidgets(
      'disconnected state shows offline StatusBadge beside address and connect button in actions row without badge',
      (tester) async {
        await _pumpDashboardHeader(
          tester,
          connState: const ServerConnectionState(
            status: ConnectionStateEnum.disconnected,
          ),
        );

        final badgeFinder = find.byType(StatusBadge);
        expect(badgeFinder, findsOneWidget);

        final badge = tester.widget<StatusBadge>(badgeFinder);
        expect(badge.label, 'Disconnected');
        expect(badge.type, StatusType.offline);

        // Action buttons Wrap contains Connect Now button
        final actionButtonsWrapFinder = find.byWidgetPredicate((w) {
          if (w is Wrap) {
            return find
                .descendant(
                  of: find.byWidget(w),
                  matching: find.text('Connect Now'),
                )
                .evaluate()
                .isNotEmpty;
          }
          return false;
        });
        expect(actionButtonsWrapFinder, findsOneWidget);

        // Connect now button is present in actionButtons row
        expect(
          find.descendant(
            of: actionButtonsWrapFinder,
            matching: find.text('Connect Now'),
          ),
          findsOneWidget,
        );

        final wrapWidget = tester.widget<Wrap>(actionButtonsWrapFinder);
        expect(wrapWidget.children.any((c) => c is StatusBadge), isFalse);
      },
    );
  });
}
