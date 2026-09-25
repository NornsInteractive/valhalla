import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/server_power_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/providers/terminal_provider.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/dashboard/dashboard_provider.dart';
import 'package:valhalla/features/dashboard/dashboard_view.dart';
import 'package:valhalla/infrastructure/system/system_metrics_sampler.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:xterm/xterm.dart';

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

class _FakeBridge extends TerminalSessionBridge {
  _FakeBridge() : super(terminal: Terminal(), serverName: 'test-server') {
    stateListenable.value = TerminalConnectionState.connected;
  }
  @override
  TerminalConnectionState get state => TerminalConnectionState.connected;
}

class _FakeServerPowerNotifier extends ServerPowerNotifier {
  ServerPowerState _internalState;
  final List<(String, String?)> shutdownCalls = [];
  Future<void> Function(String expectedServerId, String? sudoPassword)?
  onShutdown;

  _FakeServerPowerNotifier({
    ServerPowerState initialState = const ServerPowerState(
      serverId: 'srv-test-1',
      action: ServerPowerAction.shutdown,
    ),
  }) : _internalState = initialState;

  @override
  ServerPowerState build() => _internalState;

  void setTestState(ServerPowerState s) {
    _internalState = s;
    state = s;
  }

  @override
  Future<void> shutdown({
    required String expectedServerId,
    String? sudoPassword,
  }) async {
    shutdownCalls.add((expectedServerId, sudoPassword));
    if (onShutdown != null) {
      await onShutdown!(expectedServerId, sudoPassword);
    }
  }
}

class _FakeTerminalNotifier extends TerminalNotifier {
  final SshTerminalState _initial;
  _FakeTerminalNotifier(this._initial);
  @override
  SshTerminalState build() => _initial;
}

class _FakeAiChatNotifier extends AiChatNotifier {
  final AiChatState _initial;
  final int mockActiveConnectionCount;
  _FakeAiChatNotifier(this._initial, {this.mockActiveConnectionCount = 0});
  @override
  AiChatState build() => _initial;
  @override
  int get activeConnectionCount => mockActiveConnectionCount;
}

class _FakeCliChatNotifier extends CliChatNotifier {
  final int mockActiveConnectionCount;
  _FakeCliChatNotifier({this.mockActiveConnectionCount = 0});
  @override
  CliChatState build() => const CliChatState();
  @override
  int get activeConnectionCount => mockActiveConnectionCount;
}

class _FakeSftpNotifier extends SftpNotifier {
  final SftpState _initial;
  _FakeSftpNotifier(this._initial);
  @override
  SftpState build() => _initial;
}

Widget _buildTestApp({
  required ServerProfile? server,
  required ServerConnectionState connState,
  required _FakeServerPowerNotifier powerNotifier,
  int terminalCount = 0,
  int agentCount = 0,
  int transferCount = 0,
}) {
  final terminals = List.generate(terminalCount, (i) {
    final b = _FakeBridge();
    return TerminalTab(
      id: 'tab-$i',
      title: 'Term $i',
      terminal: b.terminal,
      bridge: b,
    );
  });

  final sessions = List.generate(
    agentCount,
    (i) => ChatSession(
      id: 'session-$i',
      serverId: server?.id ?? '',
      agentType: AgentType.claudeCode,
      title: 'Session $i',
      messages: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );

  final transfers = List.generate(
    transferCount,
    (i) => SftpTransfer(
      id: 'tx-$i',
      kind: SftpTransferKind.download,
      remotePath: '/remote/file$i',
      localPath: '/local/file$i',
      status: SftpTransferStatus.running,
    ),
  );

  return ProviderScope(
    overrides: [
      activeServerProvider.overrideWith(
        () => _FakeActiveServerNotifier(server),
      ),
      serverConnectionProvider.overrideWith(
        () => _FakeConnectionNotifier(connState),
      ),
      serverPowerProvider.overrideWith(() => powerNotifier),
      terminalProvider.overrideWith(
        () => _FakeTerminalNotifier(SshTerminalState(tabs: terminals)),
      ),
      aiChatProvider.overrideWith(
        () => _FakeAiChatNotifier(
          AiChatState(sessions: sessions),
          mockActiveConnectionCount: agentCount,
        ),
      ),
      cliChatProvider.overrideWith(
        () => _FakeCliChatNotifier(mockActiveConnectionCount: 0),
      ),
      sftpProvider.overrideWith(
        () => _FakeSftpNotifier(SftpState(transfers: transfers)),
      ),
      systemMetricsStreamProvider.overrideWith(
        (ref) => Stream.value(
          const SystemMetricsSnapshot(
            cpuUsedRatio: 0.25,
            memoryUsedRatio: 0.45,
            rootDiskUsedPercent: 60,
            uptimeSeconds: 7200,
            load1: 0.5,
            load5: 0.4,
            load15: 0.3,
          ),
        ),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DashboardView(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard Server Shutdown UI', () {
    testWidgets('shutdown button is hidden when disconnected', (tester) async {
      final server = _testServer();
      final powerNotifier = _FakeServerPowerNotifier();

      await tester.pumpWidget(
        _buildTestApp(
          server: server,
          connState: const ServerConnectionState(
            status: ConnectionStateEnum.disconnected,
          ),
          powerNotifier: powerNotifier,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard_shutdown_button')), findsNothing);
    });

    testWidgets(
      'shutdown button is visible when connected and shows confirm dialog with counts',
      (tester) async {
        final server = _testServer();
        final powerNotifier = _FakeServerPowerNotifier();

        await tester.pumpWidget(
          _buildTestApp(
            server: server,
            connState: const ServerConnectionState(
              status: ConnectionStateEnum.connected,
            ),
            powerNotifier: powerNotifier,
            terminalCount: 3,
            agentCount: 2,
            transferCount: 4,
          ),
        );
        await tester.pumpAndSettle();

        final shutdownBtn = find.byKey(const Key('dashboard_shutdown_button'));
        expect(shutdownBtn, findsOneWidget);

        await tester.tap(shutdownBtn);
        await tester.pumpAndSettle();

        // Verify dialog opens
        final dialogFinder = find.byType(AlertDialog);
        expect(dialogFinder, findsOneWidget);
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.textContaining('Target Server: Production Server'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.textContaining('Terminal Sessions: 3'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.textContaining('Agent Sessions: 2'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.textContaining('Active Transfers: 4'),
          ),
          findsOneWidget,
        );

        // Cancel dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(powerNotifier.shutdownCalls, isEmpty);
      },
    );

    testWidgets(
      'confirming shutdown triggers shutdown and does not attempt reboot verification or reconnect',
      (tester) async {
        final server = _testServer();
        final powerNotifier = _FakeServerPowerNotifier();

        powerNotifier.onShutdown = (expectedServerId, sudoPassword) async {
          powerNotifier.setTestState(
            const ServerPowerState(
              serverId: 'srv-test-1',
              phase: ServerPowerPhase.accepted,
              action: ServerPowerAction.shutdown,
            ),
          );
        };

        await tester.pumpWidget(
          _buildTestApp(
            server: server,
            connState: const ServerConnectionState(
              status: ConnectionStateEnum.connected,
            ),
            powerNotifier: powerNotifier,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('dashboard_shutdown_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('shutdown_confirm_button')));
        await tester.pumpAndSettle();

        expect(powerNotifier.shutdownCalls, hasLength(1));
        expect(powerNotifier.shutdownCalls.first.$1, 'srv-test-1');

        // Verify accepted feedback shown without reconnect button
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text(
            'Shutdown command accepted; shutdown completion has not been verified.',
          ),
          findsWidgets,
        );
        expect(find.text('Reconnect'), findsNothing);
      },
    );

    testWidgets(
      'disconnected screen displays shutdown banner without reconnect button',
      (tester) async {
        final server = _testServer();
        final powerNotifier = _FakeServerPowerNotifier(
          initialState: const ServerPowerState(
            serverId: 'srv-test-1',
            phase: ServerPowerPhase.accepted,
            action: ServerPowerAction.shutdown,
          ),
        );

        await tester.pumpWidget(
          _buildTestApp(
            server: server,
            connState: const ServerConnectionState(
              status: ConnectionStateEnum.disconnected,
            ),
            powerNotifier: powerNotifier,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Shutdown command accepted; shutdown completion has not been verified.',
          ),
          findsOneWidget,
        );
        // Shutdown banner must NOT display a reconnect button
        expect(find.text('Reconnect'), findsNothing);
      },
    );

    testWidgets(
      'shutdown outcome unknown shows non-assertive warning without auto-retry or reconnect',
      (tester) async {
        final server = _testServer();
        final powerNotifier = _FakeServerPowerNotifier();

        powerNotifier.onShutdown = (expectedServerId, sudoPassword) async {
          powerNotifier.setTestState(
            const ServerPowerState(
              serverId: 'srv-test-1',
              phase: ServerPowerPhase.unknown,
              action: ServerPowerAction.shutdown,
              errorCode: 'SHUTDOWN_RESULT_UNKNOWN',
            ),
          );
        };

        await tester.pumpWidget(
          _buildTestApp(
            server: server,
            connState: const ServerConnectionState(
              status: ConnectionStateEnum.connected,
            ),
            powerNotifier: powerNotifier,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('dashboard_shutdown_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('shutdown_confirm_button')));
        await tester.pumpAndSettle();

        // Exactly one call, no automatic retry
        expect(powerNotifier.shutdownCalls, hasLength(1));
        expect(powerNotifier.shutdownCalls.first.$1, 'srv-test-1');

        // SnackBar must use warning color and non-assertive unknown text
        final snackBarFinder = find.byType(SnackBar);
        expect(snackBarFinder, findsOneWidget);
        final snackBar = tester.widget<SnackBar>(snackBarFinder);
        expect(snackBar.backgroundColor, const Color(0xFFF59E0B));
        expect(snackBar.action, isNull);

        // Header banner and snackbar display unknown message
        const unknownText =
            'Shutdown result unknown: The command may have been sent but cannot be confirmed. Please check manually; it will not be retried automatically.';
        expect(find.text(unknownText), findsWidgets);

        // No reconnect button anywhere
        expect(find.text('Reconnect'), findsNothing);
      },
    );

    testWidgets(
      'disconnected screen displays shutdown unknown banner with warning color and without reconnect button',
      (tester) async {
        final server = _testServer();
        final powerNotifier = _FakeServerPowerNotifier(
          initialState: const ServerPowerState(
            serverId: 'srv-test-1',
            phase: ServerPowerPhase.unknown,
            action: ServerPowerAction.shutdown,
          ),
        );

        await tester.pumpWidget(
          _buildTestApp(
            server: server,
            connState: const ServerConnectionState(
              status: ConnectionStateEnum.disconnected,
            ),
            powerNotifier: powerNotifier,
          ),
        );
        await tester.pumpAndSettle();

        const unknownText =
            'Shutdown result unknown: The command may have been sent but cannot be confirmed. Please check manually; it will not be retried automatically.';
        expect(find.text(unknownText), findsOneWidget);
        expect(find.text('Reconnect'), findsNothing);
      },
    );

    testWidgets(
      'shutdown flow prompts for sudo password when required and accepts single-use password',
      (tester) async {
        final server = _testServer();
        final powerNotifier = _FakeServerPowerNotifier();

        var callCount = 0;
        powerNotifier.onShutdown = (expectedServerId, sudoPassword) async {
          callCount++;
          if (callCount == 1) {
            powerNotifier.setTestState(
              const ServerPowerState(
                serverId: 'srv-test-1',
                phase: ServerPowerPhase.passwordRequired,
                action: ServerPowerAction.shutdown,
                errorCode: 'SHUTDOWN_PASSWORD_REQUIRED',
              ),
            );
          } else {
            powerNotifier.setTestState(
              const ServerPowerState(
                serverId: 'srv-test-1',
                phase: ServerPowerPhase.accepted,
                action: ServerPowerAction.shutdown,
              ),
            );
          }
        };

        await tester.pumpWidget(
          _buildTestApp(
            server: server,
            connState: const ServerConnectionState(
              status: ConnectionStateEnum.connected,
            ),
            powerNotifier: powerNotifier,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('dashboard_shutdown_button')));
        await tester.pumpAndSettle();

        // Confirm initial shutdown
        await tester.tap(find.byKey(const Key('shutdown_confirm_button')));
        await tester.pumpAndSettle();

        // Password dialog must appear with shutdown title and message
        expect(
          find.text('Sudo Password Required for Shutdown'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Root privileges are required to shut down the server. Please enter the sudo password (used once, not saved):',
          ),
          findsOneWidget,
        );

        // Compatible keys for password field
        expect(
          find.byKey(const Key('shutdown_password_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('shutdown_sudo_password_input')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('reboot_password_field')), findsOneWidget);

        // Enter single-use password
        await tester.enterText(
          find.byKey(const Key('shutdown_password_field')),
          'temp-shutdown-pass-999',
        );
        await tester.pumpAndSettle();

        // Confirm using shutdown confirm button key (also compatible with reboot key)
        expect(
          find.byKey(const Key('shutdown_password_confirm_button')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('shutdown_password_confirm_button')),
        );
        await tester.pumpAndSettle();

        // Second call received single-use password
        expect(powerNotifier.shutdownCalls, hasLength(2));
        expect(powerNotifier.shutdownCalls[1].$1, 'srv-test-1');
        expect(powerNotifier.shutdownCalls[1].$2, 'temp-shutdown-pass-999');

        // Accepted feedback shown
        expect(
          find.text(
            'Shutdown command accepted; shutdown completion has not been verified.',
          ),
          findsWidgets,
        );
      },
    );
  });
}
