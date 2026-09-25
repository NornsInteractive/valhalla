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
  bool connectCalled = false;
  bool disconnectCalled = false;

  _FakeConnectionNotifier(this._initial);

  @override
  ServerConnectionState build() => _initial;

  @override
  Future<bool> connect({
    String? password,
    String? privateKey,
    Future<bool> Function(
      String host,
      String keyType,
      String fingerprintSha256,
    )?
    onConfirmHostKey,
  }) async {
    connectCalled = true;
    return true;
  }

  @override
  void disconnect() {
    disconnectCalled = true;
  }
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
  final List<(String, String?)> rebootCalls = [];
  bool verifyCalled = false;
  Future<void> Function(String expectedServerId, String? sudoPassword)?
  onReboot;

  _FakeServerPowerNotifier({
    ServerPowerState initialState = const ServerPowerState(
      serverId: 'srv-test-1',
    ),
  }) : _internalState = initialState;

  @override
  ServerPowerState build() => _internalState;

  void setTestState(ServerPowerState s) {
    _internalState = s;
    state = s;
  }

  @override
  Future<void> reboot({
    required String expectedServerId,
    String? sudoPassword,
  }) async {
    rebootCalls.add((expectedServerId, sudoPassword));
    if (onReboot != null) {
      await onReboot!(expectedServerId, sudoPassword);
    }
  }

  @override
  Future<void> verifyReboot() async {
    verifyCalled = true;
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
  _FakeConnectionNotifier? connNotifier,
  int terminalCount = 0,
  int agentCount = 0,
  int transferCount = 0,
  VoidCallback? onConnect,
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

  final List<SftpTransfer> transfers = List.generate(
    transferCount,
    (i) => SftpTransfer(
      id: 'tx-$i',
      kind: SftpTransferKind.download,
      remotePath: '/remote/file$i',
      localPath: '/local/file$i',
      status: SftpTransferStatus.running,
    ),
  );

  final effectiveConnNotifier =
      connNotifier ?? _FakeConnectionNotifier(connState);

  return ProviderScope(
    overrides: [
      activeServerProvider.overrideWith(
        () => _FakeActiveServerNotifier(server),
      ),
      serverConnectionProvider.overrideWith(() => effectiveConnNotifier),
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
            uptimeSeconds: 3600,
            load1: 0.5,
            load5: 0.4,
            load15: 0.3,
          ),
        ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DashboardView(onConnect: onConnect),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dashboard Server Reboot UI', () {
    testWidgets('reboot button is hidden when disconnected', (tester) async {
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

      expect(find.byKey(const Key('dashboard_reboot_button')), findsNothing);
    });

    testWidgets(
      'reboot button is visible when connected and shows confirm dialog with counts',
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
            terminalCount: 2,
            agentCount: 3,
            transferCount: 1,
          ),
        );
        await tester.pumpAndSettle();

        final rebootBtn = find.byKey(const Key('dashboard_reboot_button'));
        expect(rebootBtn, findsOneWidget);

        // Tap reboot button
        await tester.tap(rebootBtn);
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
            matching: find.textContaining('root@192.168.1.100:22'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.textContaining('Terminal Sessions: 2'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.textContaining('Agent Sessions: 3'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.textContaining('Active Transfers: 1'),
          ),
          findsOneWidget,
        );

        // Cancel dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(powerNotifier.rebootCalls, isEmpty);
      },
    );

    testWidgets('confirming reboot captures serverId and triggers reboot', (
      tester,
    ) async {
      final server = _testServer();
      final powerNotifier = _FakeServerPowerNotifier();

      powerNotifier.onReboot = (expectedServerId, sudoPassword) async {
        powerNotifier.setTestState(
          const ServerPowerState(
            serverId: 'srv-test-1',
            phase: ServerPowerPhase.accepted,
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

      await tester.tap(find.byKey(const Key('dashboard_reboot_button')));
      await tester.pumpAndSettle();

      // Tap confirm button
      await tester.tap(find.byKey(const Key('reboot_confirm_button')));
      await tester.pumpAndSettle();

      expect(powerNotifier.rebootCalls, hasLength(1));
      expect(powerNotifier.rebootCalls.first.$1, 'srv-test-1');
      expect(powerNotifier.rebootCalls.first.$2, isNull);

      // Verify accepted banner and reconnect button
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('reconnect'), findsWidgets);
    });

    testWidgets('reboot flow prompts for sudo password when required', (
      tester,
    ) async {
      final server = _testServer();
      final powerNotifier = _FakeServerPowerNotifier();

      var callCount = 0;
      powerNotifier.onReboot = (expectedServerId, sudoPassword) async {
        callCount++;
        if (callCount == 1) {
          powerNotifier.setTestState(
            const ServerPowerState(
              serverId: 'srv-test-1',
              phase: ServerPowerPhase.passwordRequired,
              errorCode: 'REBOOT_PASSWORD_REQUIRED',
            ),
          );
        } else {
          powerNotifier.setTestState(
            const ServerPowerState(
              serverId: 'srv-test-1',
              phase: ServerPowerPhase.accepted,
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

      await tester.tap(find.byKey(const Key('dashboard_reboot_button')));
      await tester.pumpAndSettle();

      // Confirm initial reboot
      await tester.tap(find.byKey(const Key('reboot_confirm_button')));
      await tester.pumpAndSettle();

      // Should prompt for password dialog
      expect(find.byKey(const Key('reboot_password_field')), findsOneWidget);

      // Enter single-use password
      await tester.enterText(
        find.byKey(const Key('reboot_password_field')),
        'temp-sudo-pass-123',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reboot_password_confirm_button')));
      await tester.pumpAndSettle();

      // Second reboot call received single-use password
      expect(powerNotifier.rebootCalls, hasLength(2));
      expect(powerNotifier.rebootCalls[1].$1, 'srv-test-1');
      expect(powerNotifier.rebootCalls[1].$2, 'temp-sudo-pass-123');
    });

    testWidgets(
      'reboot outcome unknown shows uncertain result and does not report success or auto-retry',
      (tester) async {
        final server = _testServer();
        final powerNotifier = _FakeServerPowerNotifier();

        powerNotifier.onReboot = (expectedServerId, sudoPassword) async {
          powerNotifier.setTestState(
            const ServerPowerState(
              serverId: 'srv-test-1',
              phase: ServerPowerPhase.unknown,
              errorCode: 'REBOOT_RESULT_UNKNOWN',
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

        await tester.tap(find.byKey(const Key('dashboard_reboot_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reboot_confirm_button')));
        await tester.pumpAndSettle();

        // Exactly one call, no auto retry!
        expect(powerNotifier.rebootCalls, hasLength(1));

        // Result displays uncertainty
        expect(find.textContaining('uncertain'), findsWidgets);
        expect(find.textContaining('succeeded'), findsNothing);
      },
    );

    testWidgets('disconnected screen displays reboot banner with reconnect', (
      tester,
    ) async {
      final server = _testServer();
      final powerNotifier = _FakeServerPowerNotifier(
        initialState: const ServerPowerState(
          serverId: 'srv-test-1',
          phase: ServerPowerPhase.accepted,
        ),
      );

      var reconnectTriggered = false;

      await tester.pumpWidget(
        _buildTestApp(
          server: server,
          connState: const ServerConnectionState(
            status: ConnectionStateEnum.disconnected,
          ),
          powerNotifier: powerNotifier,
          onConnect: () {
            reconnectTriggered = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Banner should be visible on offline state
      expect(find.textContaining('Reboot command accepted'), findsWidgets);
      final reconnectBtn = find.text('Reconnect');
      expect(reconnectBtn, findsWidgets);

      await tester.tap(reconnectBtn.first);
      await tester.pumpAndSettle();

      expect(reconnectTriggered, isTrue);
    });

    testWidgets(
      'reboot button is disabled when phase is submitting, accepted, or unknown',
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
          ),
        );
        await tester.pumpAndSettle();

        // Initially idle -> button is enabled
        final idleBtn = tester.widget<OutlinedButton>(
          find.byKey(const Key('dashboard_reboot_button')),
        );
        expect(idleBtn.onPressed, isNotNull);

        // 1. Submitting -> disabled
        powerNotifier.setTestState(
          const ServerPowerState(
            serverId: 'srv-test-1',
            phase: ServerPowerPhase.submitting,
          ),
        );
        await tester.pump();
        final submittingBtn = tester.widget<OutlinedButton>(
          find.byKey(const Key('dashboard_reboot_button')),
        );
        expect(submittingBtn.onPressed, isNull);

        // 2. Accepted -> disabled
        powerNotifier.setTestState(
          const ServerPowerState(
            serverId: 'srv-test-1',
            phase: ServerPowerPhase.accepted,
          ),
        );
        await tester.pump();
        final acceptedBtn = tester.widget<OutlinedButton>(
          find.byKey(const Key('dashboard_reboot_button')),
        );
        expect(acceptedBtn.onPressed, isNull);

        // 3. Unknown -> disabled
        powerNotifier.setTestState(
          const ServerPowerState(
            serverId: 'srv-test-1',
            phase: ServerPowerPhase.unknown,
          ),
        );
        await tester.pump();
        final unknownBtn = tester.widget<OutlinedButton>(
          find.byKey(const Key('dashboard_reboot_button')),
        );
        expect(unknownBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'reboot failure sanitizes raw REBOOT_* error codes to localized generic message',
      (tester) async {
        final server = _testServer();
        final powerNotifier = _FakeServerPowerNotifier();

        powerNotifier.onReboot = (expectedServerId, sudoPassword) async {
          powerNotifier.setTestState(
            const ServerPowerState(
              serverId: 'srv-test-1',
              phase: ServerPowerPhase.failed,
              errorCode: 'REBOOT_FAILED_SYSTEM_ERROR',
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

        await tester.tap(find.byKey(const Key('dashboard_reboot_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reboot_confirm_button')));
        await tester.pumpAndSettle();

        // Must show localized generic error message
        expect(
          find.text('Reboot failed: CLI operation failed'),
          findsOneWidget,
        );
        // Raw error code string must NEVER be displayed
        expect(find.textContaining('REBOOT_FAILED_SYSTEM_ERROR'), findsNothing);
      },
    );

    testWidgets(
      'reboot verified phase displays verified status and not unverified message',
      (tester) async {
        final server = _testServer();
        final powerNotifier = _FakeServerPowerNotifier();

        powerNotifier.onReboot = (expectedServerId, sudoPassword) async {
          powerNotifier.setTestState(
            const ServerPowerState(
              serverId: 'srv-test-1',
              phase: ServerPowerPhase.verified,
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

        await tester.tap(find.byKey(const Key('dashboard_reboot_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('reboot_confirm_button')));
        await tester.pumpAndSettle();

        // Must show verified message
        expect(
          find.text(
            'Server reboot has been verified; the system is back online.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
