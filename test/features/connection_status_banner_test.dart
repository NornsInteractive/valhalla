import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/agent_update_provider.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/reconnect_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/sftp_provider.dart';
import 'package:valhalla/core/utils/reconnect_backoff.dart';
import 'package:valhalla/core/utils/session_recovery_summary.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/chat_session.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/shell/widgets/connection_status_banner.dart';
import 'package:valhalla/features/docker/docker_provider.dart';
import 'package:valhalla/features/system/system_provider.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart';

ServerProfile _server() => const ServerProfile(
  id: 'srv-1',
  name: 'prod',
  host: '10.0.0.1',
  port: 22,
  username: 'dev',
);

AgentProfile _agent(String mode) => AgentProfile(
  id: '$mode-agent',
  serverId: _server().id,
  name: '$mode agent',
  description: '',
  cliCommand: 'codex',
  acpCommand: 'fixture-acp',
);

AiChatState _acpRecovery(
  SessionRecoveryStatus status, {
  String sessionId = 'acp-session',
  String title = 'ACP session',
}) => AiChatState(
  recoveryStatus: status,
  activeAgentProfile: _agent('acp'),
  activeSessionId: sessionId,
  draftText: 'unsent draft',
  sessions: [
    ChatSession(
      id: sessionId,
      title: title,
      serverId: _server().id,
      agentId: 'acp-agent',
      createdAt: DateTime.utc(2026, 10, 15),
      updatedAt: DateTime.utc(2026, 10, 15),
    ),
  ],
);

CliChatState _cliRecovery(
  SessionRecoveryStatus status, {
  String sessionId = 'cli-session',
  String title = 'CLI session',
}) => CliChatState(
  recoveryStatus: status,
  serverId: _server().id,
  activeAgent: _agent('cli'),
  activeSession: NativeCliSession(id: sessionId, title: title),
);

class _ActiveBannerServer extends ActiveServerNotifier {
  _ActiveBannerServer(this.initial);
  final ServerProfile initial;
  @override
  ServerProfile build() => initial;
  void select(ServerProfile server) => state = server;
}

class _BannerConnection extends ServerConnectionNotifier {
  @override
  ServerConnectionState build() => ServerConnectionState(
    activeServerId: _server().id,
    status: ConnectionStateEnum.connected,
  );
}

class _BannerSftp extends SftpNotifier {
  @override
  SftpState build() => const SftpState();
}

class _BannerDocker extends DockerNotifier {
  @override
  DockerState build() => const DockerState();
}

class _BannerSystem extends SystemNotifier {
  @override
  SystemState build() => const SystemState();
}

class _BannerUpdates extends AgentUpdatesNotifier {
  _BannerUpdates({this.available = false});
  final bool available;
  int dismissCalls = 0;
  @override
  AgentUpdatesState build() => !available
      ? const AgentUpdatesState()
      : AgentUpdatesState(
          showUpdateNotices: true,
          noticeDay: '2026-10-15',
          agents: {
            'fixture': AgentUpdateEntry(
              report: AgentUpdateReport(
                agentId: 'fixture',
                targetKey: 'fixture-target',
                checkedAt: DateTime.utc(2026, 10, 15),
                components: const [
                  AgentComponentUpdate(
                    component: AgentUpdateComponent.cli,
                    status: AgentUpdateStatus.available,
                    installedVersion: '1.0.0',
                    latestVersion: '1.1.0',
                  ),
                ],
              ),
            ),
          },
        );

  @override
  Future<void> dismissUpdateNotice() async {
    dismissCalls++;
    state = const AgentUpdatesState();
  }
}

/// 顶栏直接读 aiChatProvider / cliChatProvider，测试必须提供替身，
/// 否则真实的 SharedPreferences/DB 依赖会把断言变成初始化失败。
class _AcpBannerNotifier extends FakeAcpChatNotifier {
  _AcpBannerNotifier(super.initialState);

  int recoverCalls = 0;
  int acknowledgeCalls = 0;

  void replace(AiChatState next) => state = next;

  @override
  Future<void> recoverConnection() async {
    recoverCalls++;
  }

  @override
  void acknowledgeAcpSessionRestart() {
    acknowledgeCalls++;
    state = state.copyWith(acpSessionRestartDetected: false);
  }
}

class _CliBannerNotifier extends CliChatNotifier {
  _CliBannerNotifier(this.initialState);

  final CliChatState initialState;
  int recoverCalls = 0;
  int sendCalls = 0;

  void replace(CliChatState next) => state = next;

  @override
  CliChatState build() => initialState;

  @override
  Future<void> recoverConnection() async {
    recoverCalls++;
  }

  @override
  Future<void> sendMessage(String text) async => sendCalls++;
}

class _FakeReconnectController extends ReconnectController {
  _FakeReconnectController({
    ReconnectState initialState = const ReconnectState(),
    bool initialUserIntent = true,
    bool hasEverStarted = true,
  }) : _testState = initialState,
       _testUserIntent = initialUserIntent,
       _testHasEverStarted = hasEverStarted,
       super(connectAttempt: (_) async {});

  ReconnectState _testState;
  bool _testUserIntent;
  final bool _testHasEverStarted;

  @override
  ReconnectState get state => _testState;

  @override
  bool get userIntent => _testUserIntent;

  @override
  bool get hasEverStarted => _testHasEverStarted;

  void setTestState(ReconnectState newState) {
    _testState = newState;
    debugEmit(newState);
  }

  void setTestUserIntent(bool intent) {
    _testUserIntent = intent;
  }
}

Widget _buildTestApp({
  required ReconnectController? controller,
  AiChatState ai = const AiChatState(),
  CliChatState cli = const CliChatState(),
  _AcpBannerNotifier? acpNotifier,
  _CliBannerNotifier? cliNotifier,
  _ActiveBannerServer? activeServer,
  _BannerUpdates? updates,
  SessionRecoveryMode? mode,
  Locale locale = const Locale('en'),
  double textScale = 1,
  Widget? beforeBanner,
}) {
  return ProviderScope(
    overrides: [
      reconnectControllerProvider.overrideWithValue(controller),
      activeServerProvider.overrideWith(
        () => activeServer ?? _ActiveBannerServer(_server()),
      ),
      serverConnectionProvider.overrideWith(_BannerConnection.new),
      sftpProvider.overrideWith(_BannerSftp.new),
      dockerProvider.overrideWith(_BannerDocker.new),
      systemProvider.overrideWith(_BannerSystem.new),
      agentUpdatesProvider.overrideWith(() => updates ?? _BannerUpdates()),
      aiChatProvider.overrideWith(() => acpNotifier ?? _AcpBannerNotifier(ai)),
      cliChatProvider.overrideWith(
        () => cliNotifier ?? _CliBannerNotifier(cli),
      ),
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
      home: Scaffold(
        body: beforeBanner == null
            ? ConnectionStatusBanner(mode: mode)
            : Column(
                children: [
                  beforeBanner,
                  ConnectionStatusBanner(mode: mode),
                ],
              ),
      ),
    ),
  );
}

/// Entrance 是一次性入场动画，横幅要先落位再点。
Future<void> pumpBanner(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('update notice priority', () {
    testWidgets(
      'SSH and session recovery always take precedence over update notice',
      (tester) async {
        final controller = _FakeReconnectController(
          initialState: const ReconnectState(status: ReconnectStatus.connected),
        );
        final acp = _AcpBannerNotifier(const AiChatState());
        final updates = _BannerUpdates(available: true);
        await tester.pumpWidget(
          _buildTestApp(
            controller: controller,
            acpNotifier: acp,
            updates: updates,
          ),
        );
        await pumpBanner(tester);
        expect(
          find.byKey(const Key('agentUpdateNoticeBanner')),
          findsOneWidget,
        );
        controller.setTestState(
          const ReconnectState(status: ReconnectStatus.reconnecting),
        );
        await pumpBanner(tester);
        expect(find.byKey(const Key('reconnectingBanner')), findsOneWidget);
        expect(find.byKey(const Key('agentUpdateNoticeBanner')), findsNothing);
        controller.setTestState(
          const ReconnectState(
            status: ReconnectStatus.failed,
            retryable: false,
          ),
        );
        await pumpBanner(tester);
        expect(find.byKey(const Key('hostKeyChangedBanner')), findsOneWidget);
        expect(find.byKey(const Key('agentUpdateNoticeBanner')), findsNothing);
        controller.setTestState(
          const ReconnectState(status: ReconnectStatus.reconnecting),
        );
        await pumpBanner(tester);
        controller.setTestState(
          const ReconnectState(status: ReconnectStatus.connected),
        );
        await pumpBanner(tester);
        expect(find.byKey(const Key('reconnectedBanner')), findsOneWidget);
        expect(find.byKey(const Key('agentUpdateNoticeBanner')), findsNothing);
        await tester.pump(const Duration(seconds: 3));
        for (final phase in {
          SessionRecoveryStatus.reconnecting: 'sessionRecoverySyncingBanner',
          SessionRecoveryStatus.syncing: 'sessionRecoverySyncingBanner',
          SessionRecoveryStatus.incomplete: 'sessionRecoveryIncompleteBanner',
          SessionRecoveryStatus.failed: 'sessionRecoveryFailedBanner',
        }.entries) {
          acp.replace(_acpRecovery(phase.key));
          await pumpBanner(tester);
          expect(find.byKey(Key(phase.value)), findsOneWidget);
          expect(
            find.byKey(const Key('agentUpdateNoticeBanner')),
            findsNothing,
          );
        }
        acp.replace(const AiChatState(acpSessionRestartDetected: true));
        await pumpBanner(tester);
        expect(
          find.byKey(const Key('acpSessionRestartNotice')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('agentUpdateNoticeBanner')), findsNothing);
        acp.replace(const AiChatState());
        await pumpBanner(tester);
        expect(
          find.byKey(const Key('agentUpdateNoticeBanner')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('dismissAgentUpdateNoticeButton')),
        );
        await pumpBanner(tester);
        expect(updates.dismissCalls, 1);
        expect(find.byKey(const Key('agentUpdateNoticeBanner')), findsNothing);
        expect(acp.sendMessageCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    for (final locale in [const Locale('de'), const Locale('ar')]) {
      testWidgets('320dp 2x $locale update notice remains dismissible', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final updates = _BannerUpdates(available: true);
        await tester.pumpWidget(
          _buildTestApp(
            controller: null,
            updates: updates,
            locale: locale,
            textScale: 2,
          ),
        );
        await pumpBanner(tester);
        expect(tester.takeException(), isNull);
        final dismiss = find.byKey(const Key('dismissAgentUpdateNoticeButton'));
        expect(dismiss.hitTestable(), findsOneWidget);
        await tester.tap(dismiss);
        await pumpBanner(tester);
        expect(updates.dismissCalls, 1);
        expect(find.byKey(const Key('agentUpdateNoticeBanner')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ConnectionStatusBanner', () {
    testWidgets(
      'degrades to SizedBox.shrink() when reconnectControllerProvider is null',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(controller: null));
        await tester.pumpAndSettle();

        expect(find.byType(ConnectionStatusBanner), findsOneWidget);
        expect(find.byType(Container), findsNothing);
        expect(find.byKey(const Key('reconnectingBanner')), findsNothing);
        expect(find.byKey(const Key('reconnectedBanner')), findsNothing);
        expect(find.byKey(const Key('hostKeyChangedBanner')), findsNothing);
        expect(find.byKey(const Key('disconnectedManualBanner')), findsNothing);
      },
    );

    testWidgets(
      'renders reconnecting banner with attempt count and countdown',
      (tester) async {
        final controller = _FakeReconnectController(
          initialState: const ReconnectState(
            status: ReconnectStatus.reconnecting,
            attempt: 2,
            nextDelay: Duration(seconds: 8),
          ),
        );

        await tester.pumpWidget(_buildTestApp(controller: controller));
        await tester.pump();

        expect(find.byKey(const Key('reconnectingBanner')), findsOneWidget);
        expect(find.text('Reconnecting… (attempt 2)'), findsOneWidget);
        expect(find.text('(8s)'), findsOneWidget);
        expect(find.byIcon(Icons.sync), findsOneWidget);

        // Advance by 1 second, countdown ticks to (7s)
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('(7s)'), findsOneWidget);
      },
    );

    testWidgets(
      'shows sshStatusReconnected when transitioning from reconnecting to connected, and hides after 2 seconds',
      (tester) async {
        final controller = _FakeReconnectController(
          initialState: const ReconnectState(
            status: ReconnectStatus.reconnecting,
            attempt: 1,
          ),
        );

        await tester.pumpWidget(_buildTestApp(controller: controller));
        await tester.pump();
        expect(find.byKey(const Key('reconnectingBanner')), findsOneWidget);

        // Now connection recovers
        controller.setTestState(
          const ReconnectState(status: ReconnectStatus.connected),
        );
        await tester.pump();

        // Transient reconnected banner appears
        expect(find.byKey(const Key('reconnectedBanner')), findsOneWidget);
        expect(find.text('Connection restored'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

        // Wait 1 second - still visible
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(const Key('reconnectedBanner')), findsOneWidget);

        // Wait another 1.1 seconds - auto hides
        await tester.pump(const Duration(milliseconds: 1100));
        expect(find.byKey(const Key('reconnectedBanner')), findsNothing);
      },
    );

    testWidgets('renders permanent hostKeyChanged banner when not retryable', (
      tester,
    ) async {
      final controller = _FakeReconnectController(
        initialState: const ReconnectState(
          status: ReconnectStatus.failed,
          retryable: false,
          errorMessage: 'HostKeyMismatchException',
        ),
      );

      await tester.pumpWidget(_buildTestApp(controller: controller));
      await tester.pump();

      expect(find.byKey(const Key('hostKeyChangedBanner')), findsOneWidget);
      expect(
        find.text('Host key changed — connection refused'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.gpp_bad_outlined), findsOneWidget);
    });

    testWidgets(
      'renders permanent disconnectedManual banner when userIntent is false',
      (tester) async {
        // 用户曾经连过，然后主动断开：userIntent 被清掉、状态回到 idle。
        final controller = _FakeReconnectController(
          initialState: const ReconnectState(status: ReconnectStatus.idle),
          initialUserIntent: false,
          hasEverStarted: true,
        );

        await tester.pumpWidget(_buildTestApp(controller: controller));
        await tester.pump();

        expect(
          find.byKey(const Key('disconnectedManualBanner')),
          findsOneWidget,
        );
        expect(find.text('Disconnected'), findsOneWidget);
        expect(find.byIcon(Icons.link_off), findsOneWidget);
      },
    );

    testWidgets('冷启动不显示任何横幅（未做过任何操作的 controller）', (tester) async {
      // 真实控制器初始就是 userIntent=false + idle。若界面只看 userIntent，
      // 冷启动第一帧就会错误地挂一条「已断开」。
      final controller = ReconnectController(connectAttempt: (_) async {});
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildTestApp(controller: controller));
      await tester.pump();

      expect(controller.userIntent, isFalse);
      expect(controller.hasEverStarted, isFalse);
      expect(find.byKey(const Key('disconnectedManualBanner')), findsNothing);
      expect(find.byKey(const Key('reconnectingBanner')), findsNothing);
      expect(find.byKey(const Key('hostKeyChangedBanner')), findsNothing);
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('用户主动断开后才显示「已断开」', (tester) async {
      final controller = ReconnectController(connectAttempt: (_) async {});
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildTestApp(controller: controller));
      await tester.pump();
      expect(find.byKey(const Key('disconnectedManualBanner')), findsNothing);

      // 连接后用户主动断开。
      controller.start(_server());
      controller.markConnected();
      await tester.pump();
      expect(find.byKey(const Key('disconnectedManualBanner')), findsNothing);

      controller.userDisconnect();
      await tester.pump();
      expect(
        find.byKey(const Key('disconnectedManualBanner')),
        findsOneWidget,
        reason: '用户主动断开必须明确告知',
      );
    });

    testWidgets('does not show banner when connected and userIntent is true', (
      tester,
    ) async {
      final controller = _FakeReconnectController(
        initialState: const ReconnectState(status: ReconnectStatus.connected),
        initialUserIntent: true,
      );

      await tester.pumpWidget(_buildTestApp(controller: controller));
      await tester.pump();

      expect(find.byType(Container), findsNothing);
    });

    testWidgets('完整生命周期后 banner 出现，卸载时释放订阅', (tester) async {
      final controller = ReconnectController(connectAttempt: (_) async {});
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildTestApp(controller: controller));
      await tester.pump();
      expect(controller.listenerCount, 1, reason: '挂载后应当订阅上');

      controller.start(_server());
      await tester.pump();
      controller.markConnected();
      await tester.pump();
      controller.userDisconnect();
      await tester.pump();

      expect(find.byKey(const Key('disconnectedManualBanner')), findsOneWidget);

      // 卸载后必须解除订阅，否则控制器会一直持有已销毁的 widget。
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(controller.listenerCount, 0);
    });

    testWidgets('控制器从有变无时不残留旧订阅', (tester) async {
      final controller = ReconnectController(connectAttempt: (_) async {});
      addTearDown(controller.dispose);

      // 先挂载带控制器的版本，再切到 null。
      await tester.pumpWidget(_buildTestApp(controller: controller));
      await tester.pump();
      expect(controller.listenerCount, 1);

      await tester.pumpWidget(_buildTestApp(controller: null));
      await tester.pump();

      expect(controller.listenerCount, 0, reason: 'build 提前返回前必须先解除旧订阅');
      expect(find.byType(Container), findsNothing);
    });
  });

  group('ConnectionStatusBanner 顶栏承载恢复状态（controller 为 null）', () {
    testWidgets('controller 为 null 时 idle 恢复什么都不画', (tester) async {
      await tester.pumpWidget(_buildTestApp(controller: null));
      await pumpBanner(tester);

      expect(find.byType(ConnectionStatusBanner), findsOneWidget);
      expect(find.byType(Container), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('controller 为 null 时 syncing 仍然显示转圈横幅', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          controller: null,
          ai: const AiChatState(recoveryStatus: SessionRecoveryStatus.syncing),
        ),
      );
      await pumpBanner(tester);

      expect(
        find.byKey(const Key('sessionRecoverySyncingBanner')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('sessionRecoverySyncingBanner')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: '同步中的状态必须一直可见，哪怕自动重连控制器没开',
      );
    });

    testWidgets('controller 为 null 时 incomplete 显示并接上重试', (tester) async {
      final acp = _AcpBannerNotifier(
        _acpRecovery(SessionRecoveryStatus.incomplete),
      );
      await tester.pumpWidget(
        _buildTestApp(controller: null, acpNotifier: acp),
      );
      await pumpBanner(tester);

      expect(
        find.byKey(const Key('sessionRecoveryIncompleteBanner')),
        findsOneWidget,
      );
      final retry = tester.widget<TextButton>(
        find.byKey(const Key('sessionRecoveryRetryButton')),
      );
      expect(retry.onPressed, isNotNull, reason: 'retry must be actionable');

      await tester.tap(find.byKey(const Key('sessionRecoveryRetryButton')));
      await tester.pump();
      expect(
        acp.recoverCalls,
        1,
        reason: 'one tap triggers exactly one recovery',
      );
    });

    testWidgets('controller 为 null 时 failed 显示并接上重试', (tester) async {
      final acp = _AcpBannerNotifier(
        _acpRecovery(SessionRecoveryStatus.failed),
      );
      await tester.pumpWidget(
        _buildTestApp(controller: null, acpNotifier: acp),
      );
      await pumpBanner(tester);

      expect(
        find.byKey(const Key('sessionRecoveryFailedBanner')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('sessionRecoveryRetryButton')),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('sessionRecoveryRetryButton')));
      await tester.pump();
      expect(acp.recoverCalls, 1);
    });

    testWidgets('controller 为 null 且 ACP 空闲时，CLI 的 failed 重试走 CLI 入口', (
      tester,
    ) async {
      final cli = _CliBannerNotifier(
        _cliRecovery(SessionRecoveryStatus.failed),
      );
      await tester.pumpWidget(
        _buildTestApp(controller: null, cliNotifier: cli),
      );
      await pumpBanner(tester);

      expect(
        find.byKey(const Key('sessionRecoveryFailedBanner')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('sessionRecoveryRetryButton')));
      await tester.pump();
      expect(cli.recoverCalls, 1, reason: 'CLI 恢复状态必须打到 CLI 的恢复入口');
    });

    testWidgets('controller 为 null 时上下文丢失提示可被确认并消失', (tester) async {
      final acp = _AcpBannerNotifier(
        const AiChatState(acpSessionRestartDetected: true),
      );
      await tester.pumpWidget(
        _buildTestApp(controller: null, acpNotifier: acp),
      );
      await pumpBanner(tester);

      expect(find.byKey(const Key('acpSessionRestartNotice')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('acknowledgeAcpSessionRestartBannerButton')),
      );
      await tester.pump();

      expect(acp.acknowledgeCalls, 1, reason: '确认必须真的调用 acknowledge');
      expect(
        find.byKey(const Key('acpSessionRestartNotice')),
        findsNothing,
        reason: '确认之后提示必须消失',
      );
    });

    testWidgets('用户主动断开时 SSH 状态优先于 recovery reconnecting', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          controller: _FakeReconnectController(initialUserIntent: false),
          ai: _acpRecovery(SessionRecoveryStatus.reconnecting),
        ),
      );
      await pumpBanner(tester);

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'a user-initiated disconnect must not keep promising to retry',
      );
      expect(
        find.byKey(const Key('sessionRecoveryRetryButton')),
        findsNothing,
        reason: 'offline is a state, not a failure to retry',
      );
      expect(find.byKey(const Key('disconnectedManualBanner')), findsOneWidget);
    });

    testWidgets('连接横幅缺席时仍显示非 idle recovery reconnecting', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          controller: null,
          ai: _acpRecovery(SessionRecoveryStatus.reconnecting),
        ),
      );
      await pumpBanner(tester);

      expect(find.byKey(const Key('reconnectingBanner')), findsNothing);
      expect(
        find.byKey(const Key('sessionRecoverySyncingBanner')),
        findsOneWidget,
        reason: '非 idle 会话恢复不能因 SSH 控制器缺席而消失',
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('传输层重连结束后 syncing 补上，恢复状态不会被顶栏吞掉', (tester) async {
      final controller = _FakeReconnectController(
        initialState: const ReconnectState(
          status: ReconnectStatus.reconnecting,
          attempt: 1,
        ),
      );
      final acp = _AcpBannerNotifier(
        const AiChatState(recoveryStatus: SessionRecoveryStatus.syncing),
      );

      await tester.pumpWidget(
        _buildTestApp(controller: controller, acpNotifier: acp),
      );
      await tester.pump();
      expect(find.byKey(const Key('reconnectingBanner')), findsOneWidget);

      controller.setTestState(
        const ReconnectState(status: ReconnectStatus.connected),
      );
      await tester.pump();
      expect(find.byKey(const Key('reconnectedBanner')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2100));

      expect(find.byKey(const Key('reconnectedBanner')), findsNothing);
      expect(
        find.byKey(const Key('sessionRecoverySyncingBanner')),
        findsOneWidget,
        reason: '同步没结束，传输层恢复之后必须接着显示',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('sessionRecoverySyncingBanner')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    });
  });

  group('recovery details target routing', () {
    testWidgets(
      'closing recovery details does not restore mobile keyboard',
      (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          _buildTestApp(
            controller: null,
            ai: _acpRecovery(SessionRecoveryStatus.failed),
            beforeBanner: TextField(
              key: const Key('recovery_search'),
              focusNode: focus,
            ),
          ),
        );
        await pumpBanner(tester);
        await tester.tap(find.byKey(const Key('recovery_search')));
        await tester.pump();
        expect(focus.hasFocus, isTrue);
        await tester.tap(find.byKey(const Key('sessionRecoveryFailedBanner')));
        await pumpBanner(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        final dialog = tester.element(find.byType(AlertDialog));
        Navigator.of(dialog).pop();
        await pumpBanner(tester);
        expect(focus.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    for (final mode in SessionRecoveryMode.values) {
      testWidgets('two recovery rows retry only ${mode.name}', (tester) async {
        final acp = _AcpBannerNotifier(
          _acpRecovery(SessionRecoveryStatus.failed),
        );
        final cli = _CliBannerNotifier(
          _cliRecovery(SessionRecoveryStatus.incomplete),
        );
        await tester.pumpWidget(
          _buildTestApp(
            controller: null,
            acpNotifier: acp,
            cliNotifier: cli,
            mode: mode,
          ),
        );
        await pumpBanner(tester);
        final bannerKey = mode == SessionRecoveryMode.acp
            ? 'sessionRecoveryFailedBanner'
            : 'sessionRecoveryIncompleteBanner';
        await tester.tap(find.byKey(Key(bannerKey)));
        await pumpBanner(tester);
        expect(find.textContaining('ACP: ACP session'), findsOneWidget);
        expect(find.textContaining('CLI: CLI session'), findsOneWidget);
        expect(
          find.byKey(const Key('connectionDetailsRetryButton')),
          findsNothing,
        );
        await tester.tap(find.byKey(Key('${mode.name}RecoveryRetryButton')));
        await pumpBanner(tester);
        expect(acp.recoverCalls, mode == SessionRecoveryMode.acp ? 1 : 0);
        expect(cli.recoverCalls, mode == SessionRecoveryMode.cli ? 1 : 0);
        expect(acp.sendMessageCalls, 0);
        expect(cli.sendCalls, 0);
        expect(acp.state.draftText, 'unsent draft');
        expect(tester.takeException(), isNull);
      });

      testWidgets('stale ${mode.name} row cannot retry a replacement session', (
        tester,
      ) async {
        final acp = _AcpBannerNotifier(
          _acpRecovery(SessionRecoveryStatus.failed),
        );
        final cli = _CliBannerNotifier(
          _cliRecovery(SessionRecoveryStatus.failed),
        );
        await tester.pumpWidget(
          _buildTestApp(controller: null, acpNotifier: acp, cliNotifier: cli),
        );
        await pumpBanner(tester);
        await tester.tap(find.byKey(const Key('sessionRecoveryFailedBanner')));
        await pumpBanner(tester);
        final staleRetry = tester
            .widget<TextButton>(
              find.byKey(Key('${mode.name}RecoveryRetryButton')),
            )
            .onPressed!;
        // Exercise a target update before the next frame replaces the old row.
        if (mode == SessionRecoveryMode.acp) {
          acp.replace(
            _acpRecovery(SessionRecoveryStatus.failed, sessionId: 'new-acp'),
          );
        } else {
          cli.replace(
            _cliRecovery(SessionRecoveryStatus.failed, sessionId: 'new-cli'),
          );
        }
        staleRetry();
        await pumpBanner(tester);
        expect(acp.recoverCalls, 0);
        expect(cli.recoverCalls, 0);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('same-ID server endpoint swap invalidates a rendered retry', (
      tester,
    ) async {
      final active = _ActiveBannerServer(_server());
      final acp = _AcpBannerNotifier(
        _acpRecovery(SessionRecoveryStatus.failed),
      );
      await tester.pumpWidget(
        _buildTestApp(controller: null, acpNotifier: acp, activeServer: active),
      );
      await pumpBanner(tester);
      await tester.tap(find.byKey(const Key('sessionRecoveryFailedBanner')));
      await pumpBanner(tester);
      final staleRetry = tester
          .widget<TextButton>(find.byKey(const Key('acpRecoveryRetryButton')))
          .onPressed!;
      active.select(_server().copyWith(host: '192.0.2.22'));
      staleRetry();
      await pumpBanner(tester);
      expect(acp.recoverCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'preferred reconnecting session keeps the other failure actionable',
      (tester) async {
        final acp = _AcpBannerNotifier(
          _acpRecovery(SessionRecoveryStatus.reconnecting),
        );
        final cli = _CliBannerNotifier(
          _cliRecovery(SessionRecoveryStatus.failed),
        );
        await tester.pumpWidget(
          _buildTestApp(
            controller: null,
            acpNotifier: acp,
            cliNotifier: cli,
            mode: SessionRecoveryMode.acp,
          ),
        );
        await pumpBanner(tester);
        await tester.tap(find.byKey(const Key('sessionRecoverySyncingBanner')));
        await pumpBanner(tester);
        expect(find.textContaining('ACP: ACP session'), findsOneWidget);
        expect(find.textContaining('CLI: CLI session'), findsOneWidget);
        expect(find.byKey(const Key('acpRecoveryRetryButton')), findsNothing);
        expect(
          find.byKey(const Key('connectionDetailsRetryButton')),
          findsNothing,
        );
        acp.replace(
          _acpRecovery(SessionRecoveryStatus.syncing, title: 'Updated ACP'),
        );
        await tester.pump();
        expect(find.textContaining('ACP: Updated ACP'), findsOneWidget);
        expect(find.textContaining('ACP: ACP session'), findsNothing);
        await tester.tap(find.byKey(const Key('cliRecoveryRetryButton')));
        await pumpBanner(tester);
        expect(acp.recoverCalls, 0);
        expect(cli.recoverCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );

    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets('320dp 2x ${locale.languageCode} long recovery details fit', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final longTitle = List.filled(10, 'long session name').join(' ');
        await tester.pumpWidget(
          _buildTestApp(
            controller: null,
            activeServer: _ActiveBannerServer(
              _server().copyWith(name: longTitle),
            ),
            ai: _acpRecovery(
              SessionRecoveryStatus.failed,
              title: longTitle,
            ).copyWith(acpSessionRestartDetected: true),
            cli: _cliRecovery(
              SessionRecoveryStatus.incomplete,
              title: longTitle,
            ),
            textScale: 2,
            locale: locale,
          ),
        );
        await pumpBanner(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('sessionRecoveryFailedBanner')),
            matching: find.byIcon(Icons.error_outline),
          ),
        );
        await pumpBanner(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        final retry = find.byKey(const Key('cliRecoveryRetryButton'));
        await tester.ensureVisible(retry);
        await pumpBanner(tester);
        expect(tester.getSize(retry).height, greaterThanOrEqualTo(44));
        expect(retry.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
