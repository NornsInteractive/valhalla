import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/cli_chat_provider.dart';
import 'package:valhalla/core/providers/reconnect_provider.dart';
import 'package:valhalla/core/utils/reconnect_backoff.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/shell/widgets/connection_status_banner.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart';

ServerProfile _server() => const ServerProfile(
  id: 'srv-1',
  name: 'prod',
  host: '10.0.0.1',
  port: 22,
  username: 'dev',
);

/// 顶栏直接读 aiChatProvider / cliChatProvider，测试必须提供替身，
/// 否则真实的 SharedPreferences/DB 依赖会把断言变成初始化失败。
class _AcpBannerNotifier extends FakeAcpChatNotifier {
  _AcpBannerNotifier(super.initialState);

  int recoverCalls = 0;
  int acknowledgeCalls = 0;

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

  @override
  CliChatState build() => initialState;

  @override
  Future<void> recoverConnection() async {
    recoverCalls++;
  }
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
}) {
  return ProviderScope(
    overrides: [
      reconnectControllerProvider.overrideWithValue(controller),
      aiChatProvider.overrideWith(() => acpNotifier ?? _AcpBannerNotifier(ai)),
      cliChatProvider.overrideWith(
        () => cliNotifier ?? _CliBannerNotifier(cli),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ConnectionStatusBanner()),
    ),
  );
}

/// Entrance 是一次性入场动画，横幅要先落位再点。
Future<void> pumpBanner(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
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
        const AiChatState(recoveryStatus: SessionRecoveryStatus.incomplete),
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
        const AiChatState(recoveryStatus: SessionRecoveryStatus.failed),
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
        const CliChatState(recoveryStatus: SessionRecoveryStatus.failed),
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

    testWidgets('连接断开时 recovery reconnecting 不再画无止境的转圈', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          controller: null,
          ai: const AiChatState(
            recoveryStatus: SessionRecoveryStatus.reconnecting,
          ),
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
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('连接横幅缺席时不画重复的 recovery reconnecting 横幅', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          controller: null,
          ai: const AiChatState(
            recoveryStatus: SessionRecoveryStatus.reconnecting,
          ),
        ),
      );
      await pumpBanner(tester);

      expect(find.byKey(const Key('reconnectingBanner')), findsNothing);
      expect(
        find.byKey(const Key('sessionRecoverySyncingBanner')),
        findsNothing,
        reason: '顶栏只保留一条状态，reconnecting 不再重复堆叠',
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
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
}
