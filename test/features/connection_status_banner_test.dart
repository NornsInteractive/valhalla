import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/reconnect_provider.dart';
import 'package:valhalla/core/utils/reconnect_backoff.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/shell/widgets/connection_status_banner.dart';
import 'package:valhalla/l10n/app_localizations.dart';

ServerProfile _server() => const ServerProfile(
  id: 'srv-1',
  name: 'prod',
  host: '10.0.0.1',
  port: 22,
  username: 'dev',
);

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

Widget _buildTestApp({required ReconnectController? controller}) {
  return ProviderScope(
    overrides: [reconnectControllerProvider.overrideWithValue(controller)],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ConnectionStatusBanner()),
    ),
  );
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
}
