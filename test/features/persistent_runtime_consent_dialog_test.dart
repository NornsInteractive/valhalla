import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/ai_chat_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/chat/widgets/persistent_runtime_consent_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';

const _cancelKey = Key('persistentRuntimeCancelButton');
const _enableKey = Key('persistentRuntimeEnableButton');

ServerProfile _serverFixture() => ServerProfile(
  id: 'fixture-server',
  name: 'Fixture Server',
  host: '127.0.0.1',
  port: 22,
  username: 'fixture',
);

class _FakeActiveServer extends ActiveServerNotifier {
  _FakeActiveServer();

  @override
  ServerProfile? build() => _serverFixture();
}

class _FakeAiChatNotifier extends AiChatNotifier {
  final bool _success;

  _FakeAiChatNotifier({required bool success}) : _success = success;

  @override
  AiChatState build() => AiChatState(persistentRuntimeSetupRequired: true);

  @override
  Future<bool> approvePersistentRuntime() async {
    if (_success) {
      state = state.copyWith(persistentRuntimeSetupRequired: false);
    }
    return _success;
  }
}

class _Observer extends NavigatorObserver {
  int popCount = 0;
  int pushCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    popCount++;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    pushCount++;
  }
}

Future<void> _pumpSentinelAndShowDialog(
  WidgetTester tester, {
  required bool approveSuccess,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  final observer = _Observer();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeServerProvider.overrideWith(_FakeActiveServer.new),
        aiChatProvider.overrideWith(
          () => _FakeAiChatNotifier(success: approveSuccess),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [observer],
        home: const _SentinelRoute(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  final context = tester.element(find.byType(_SentinelRoute));
  unawaited(PersistentRuntimeConsentDialog.show(context));
  await tester.pumpAndSettle();
  expect(find.byType(PersistentRuntimeConsentDialog), findsOneWidget);
  expect(observer.pushCount, 2);
}

class _SentinelRoute extends StatelessWidget {
  const _SentinelRoute();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Sentinel')));
}

void main() {
  group('Persistent Runtime Consent Dialog', () {
    testWidgets('cancel closes dialog once (sentinel remains)', (tester) async {
      await _pumpSentinelAndShowDialog(tester, approveSuccess: false);

      await tester.tap(find.byKey(_cancelKey));
      await tester.pumpAndSettle();

      expect(find.byType(PersistentRuntimeConsentDialog), findsNothing);
      expect(find.byType(_SentinelRoute), findsOneWidget);
    });

    testWidgets('enable closes dialog once on success (sentinel remains)', (
      tester,
    ) async {
      await _pumpSentinelAndShowDialog(tester, approveSuccess: true);

      await tester.tap(find.byKey(_enableKey));
      await tester.pumpAndSettle();

      expect(find.byType(PersistentRuntimeConsentDialog), findsNothing);
      expect(find.byType(_SentinelRoute), findsOneWidget);
    });

    testWidgets('approval failure keeps dialog open at 320dp scale 2.0', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpSentinelAndShowDialog(
        tester,
        approveSuccess: false,
        textScale: 2.0,
      );

      await tester.tap(find.byKey(_enableKey));
      await tester.pumpAndSettle();

      expect(find.byType(PersistentRuntimeConsentDialog), findsOneWidget);

      await tester.ensureVisible(find.byKey(_enableKey));
      expect(
        tester.widget<FilledButton>(find.byKey(_enableKey)).enabled,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(_enableKey)).height,
        greaterThanOrEqualTo(44.0),
      );
    });

    testWidgets('NavigatorObserver verifies cancel pops only dialog once', (
      tester,
    ) async {
      final observer = _Observer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerProvider.overrideWith(_FakeActiveServer.new),
            aiChatProvider.overrideWith(
              () => _FakeAiChatNotifier(success: false),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            navigatorObservers: [observer],
            home: const _SentinelRoute(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(_SentinelRoute));
      unawaited(PersistentRuntimeConsentDialog.show(context));
      await tester.pumpAndSettle();

      expect(find.byType(PersistentRuntimeConsentDialog), findsOneWidget);
      expect(observer.pushCount, 2);
      expect(observer.popCount, 0);

      await tester.tap(find.byKey(_cancelKey));
      await tester.pumpAndSettle();

      expect(find.byType(PersistentRuntimeConsentDialog), findsNothing);
      expect(find.byType(_SentinelRoute), findsOneWidget);
      expect(observer.popCount, 1);
    });

    testWidgets('NavigatorObserver verifies success pops only dialog once', (
      tester,
    ) async {
      final observer = _Observer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeServerProvider.overrideWith(_FakeActiveServer.new),
            aiChatProvider.overrideWith(
              () => _FakeAiChatNotifier(success: true),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            navigatorObservers: [observer],
            home: const _SentinelRoute(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(_SentinelRoute));
      unawaited(PersistentRuntimeConsentDialog.show(context));
      await tester.pumpAndSettle();

      expect(find.byType(PersistentRuntimeConsentDialog), findsOneWidget);
      expect(observer.pushCount, 2);
      expect(observer.popCount, 0);

      await tester.tap(find.byKey(_enableKey));
      await tester.pumpAndSettle();

      expect(find.byType(PersistentRuntimeConsentDialog), findsNothing);
      expect(find.byType(_SentinelRoute), findsOneWidget);
      expect(observer.popCount, 1);
    });
  });
}
