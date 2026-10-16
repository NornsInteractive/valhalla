import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/in_memory_app_settings.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/core/providers/nas_native_install_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/services/nas_native_install_service.dart';
import 'package:valhalla/core/services/remote_browser_service.dart';
import 'package:valhalla/features/nas/widgets/nas_native_install_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import 'package:valhalla/widgets/remote_browser_dialog.dart';

import '../support/acp_chat_widget_harness.dart' show loadRealTextFonts;
import '../support/application_center_fakes.dart';
import '../support/nas_browser_fixture.dart';

class _Plan extends Fake implements NasNativeInstallPlan {
  _Plan(
    this.request, {
    this.existingInstall = false,
    this.extraBlockers = const [],
  });
  final List<String> extraBlockers;
  @override
  final NasNativeInstallRequest request;
  @override
  final bool existingInstall;
  @override
  String get id => 'a' * 32;
  @override
  String get confirmationToken => 'b' * 32;
  @override
  String get targetIdentity => 'c' * 32;
  @override
  DateTime get createdAt => DateTime.now();
  @override
  String get os => 'debian';
  @override
  String get osVersion => '12';
  @override
  String get architecture => 'amd64';
  @override
  String get packageVersion => '12.2.0';
  @override
  Map<String, String> get packageVersions => {
    'jellyfin-server': packageVersion,
  };
  @override
  List<String> get blockers => [
    if (existingInstall) 'NAS_NATIVE_ALREADY_INSTALLED',
    ...extraBlockers,
  ];
  @override
  List<String> get steps => ['NAS_NATIVE_INSTALL_PINNED_PACKAGES'];
  @override
  List<String> get guidance => ['NAS_NATIVE_MEDIA_ACCESS_UNCHANGED'];
  @override
  bool get canInstall => !existingInstall && blockers.isEmpty;
  @override
  Uri get endpoint => Uri.parse('http://127.0.0.1:8096');
}

class _Service extends Fake implements NasNativeInstallService {
  final controller = StreamController<NasNativeInstallTask?>.broadcast();
  NasNativeInstallTask? current;
  bool existingInstall = false;
  List<String> extraBlockers = const [];
  int prepares = 0, executes = 0, cancellations = 0, reconciliations = 0;
  int disposals = 0;

  @override
  NasNativeInstallTask? get state => current;
  @override
  Stream<NasNativeInstallTask?> get states => controller.stream;

  NasNativeInstallTask task(
    NasNativeInstallStage stage, {
    NasNativeInstallPlan? plan,
  }) => NasNativeInstallTask(
    id: 'a' * 32,
    request:
        plan?.request ??
        NasNativeInstallRequest.forServer(centerServer, mediaPath: '/media'),
    stage: stage,
    startedAt: DateTime.now().subtract(const Duration(seconds: 5)),
    updatedAt: DateTime.now(),
    currentCommand: stage == NasNativeInstallStage.installing
        ? 'apt-get install fixture-package'
        : '',
    logTail: stage == NasNativeInstallStage.installing ? 'fixture output' : '',
    requiresReconciliation: stage == NasNativeInstallStage.needsInspection,
    plan: plan,
  );

  void emit(NasNativeInstallTask value) {
    current = value;
    controller.add(value);
  }

  @override
  Future<NasNativeInstallPlan> prepare(NasNativeInstallRequest request) async {
    prepares++;
    final plan = _Plan(
      request,
      existingInstall: existingInstall,
      extraBlockers: extraBlockers,
    );
    emit(task(NasNativeInstallStage.review, plan: plan));
    return plan;
  }

  @override
  Future<NasNativeInstallTask> execute(String confirmationToken) async {
    expect(confirmationToken, 'b' * 32);
    executes++;
    emit(task(NasNativeInstallStage.installing));
    return current!;
  }

  @override
  Future<void> requestCancel() async => cancellations++;
  @override
  Future<void> reconcile() async => reconciliations++;
  @override
  Future<void> refresh() async => reconciliations++;
  @override
  void dispose() => disposals++;
}

void main() {
  Finder filledButtons() =>
      find.byWidgetPredicate((widget) => widget is FilledButton);

  Future<void> pump(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<CenterActiveServer> host(
    WidgetTester tester,
    _Service service, {
    double width = 400,
    double scale = 1,
    Completer<NasNativeInstallService>? deferredService,
    void Function(NasBrowserFixture)? browserCreated,
  }) async {
    await loadRealTextFonts();
    final active = CenterActiveServer();
    final connection = CenterConnection();
    addTearDown(service.controller.close);
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(InMemoryAppSettings.new),
          if (browserCreated != null)
            remoteBrowserFactoryProvider.overrideWith((ref) {
              final factory = NasBrowserFixture(ref);
              browserCreated(factory);
              return factory;
            }),
          activeServerProvider.overrideWith(() => active),
          serverConnectionProvider.overrideWith(() => connection),
          nasNativeInstallServiceProvider.overrideWith(
            (ref) => deferredService?.future ?? Future.value(service),
          ),
          nasNativeInstallTaskProvider.overrideWith((ref) async* {
            yield service.state;
            yield* service.states;
          }),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.buildTheme(
            brightness: Brightness.light,
            seedColor: Colors.green,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => NasNativeInstallDialog.show(context),
                child: const Text('Open fixture'),
              ),
            ),
          ),
        ),
      ),
    );
    ProviderScope.containerOf(
      tester.element(find.byType(TextButton)),
    ).read(serverConnectionProvider);
    connection.setConnected(true);
    await tester.tap(find.text('Open fixture'));
    await pump(tester);
    return active;
  }

  testWidgets(
    'native media picker uses shared host browser without installing',
    (tester) async {
      final service = _Service();
      late NasBrowserFixture browser;
      await host(tester, service, browserCreated: (value) => browser = value);
      await tester.tap(find.byKey(const Key('nas_native_browse_media_path')));
      await settleNasBrowser(tester);
      expect(find.byType(RemoteBrowserDialog), findsOneWidget);
      expect(browser.paths, ['/media', '/']);
      await tester.tap(find.text('Chosen directory'));
      await settleNasBrowser(tester);
      await tester.tap(find.byKey(const Key('remote_browser_confirm_button')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '/chosen',
      );
      expect(browser.sources.single.isCurrent, isFalse);
      expect(service.prepares, 0);
      expect(service.executes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('review task does not hide confirmation or back-to-edit', (
    tester,
  ) async {
    final service = _Service();
    await host(tester, service);
    await tester.tap(filledButtons());
    await pump(tester);
    expect(service.prepares, 1);
    expect(service.current!.stage, NasNativeInstallStage.review);
    expect(filledButtons(), findsOneWidget);
    expect(tester.widget<FilledButton>(filledButtons()).onPressed, isNotNull);
    expect(find.text('debian 12 (amd64)'), findsOneWidget);
    final back = find.byType(TextButton);
    await tester.ensureVisible(back);
    await tester.tap(back);
    await pump(tester);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(service.executes, 0);
  });

  testWidgets(
    'accepted install remains running, cancellable and survives closing',
    (tester) async {
      final service = _Service();
      await host(tester, service);
      await tester.tap(filledButtons());
      await pump(tester);
      await tester.ensureVisible(filledButtons());
      await tester.tap(filledButtons());
      await pump(tester);
      expect(service.executes, 1);
      expect(find.text('apt-get install fixture-package'), findsOneWidget);
      final context = tester.element(find.byType(NasNativeInstallDialog));
      final l10n = AppLocalizations.of(context);
      expect(find.text(l10n.nasInstallStageSucceeded), findsNothing);
      final cancel = find.byWidgetPredicate(
        (widget) => widget is OutlinedButton,
      );
      expect(tester.widget<OutlinedButton>(cancel).onPressed, isNotNull);
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await pump(tester);
      expect(service.cancellations, 0);
      await tester.tap(filledButtons());
      await pump(tester);
      expect(service.cancellations, 1);
      await tester.tap(find.byIcon(Icons.close));
      await pump(tester);
      expect(find.text('Open fixture'), findsOneWidget);
      expect(service.current!.stage, NasNativeInstallStage.installing);
      expect(service.disposals, 0);
    },
  );

  testWidgets('existing install is shown without a mutation confirmation', (
    tester,
  ) async {
    final service = _Service()..existingInstall = true;
    await host(tester, service);
    await tester.tap(filledButtons());
    await pump(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(NasNativeInstallDialog)),
    );
    expect(find.text(l10n.nasNativeExistingInstallTitle), findsOneWidget);
    expect(find.text(l10n.nasNativeExistingInstallExplanation), findsOneWidget);
    expect(find.text(l10n.nasInstallBlockerFailed), findsNothing);
    expect(find.text(l10n.nasInstallConfirmDeploy), findsNothing);
    expect(find.text(l10n.confirm), findsNothing);
    expect(service.executes, 0);
  });

  testWidgets('existing install hides only its informational blocker', (
    tester,
  ) async {
    final service = _Service()
      ..existingInstall = true
      ..extraBlockers = ['NAS_NATIVE_PORT_BUSY'];
    await host(tester, service);
    await tester.tap(filledButtons());
    await pump(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(NasNativeInstallDialog)),
    );
    expect(find.text(l10n.nasNativeExistingInstallExplanation), findsOneWidget);
    expect(find.text(l10n.nasInstallBlockerPort), findsOneWidget);
    expect(find.text(l10n.nasInstallBlockerFailed), findsNothing);
    expect(find.text(l10n.nasInstallConfirmDeploy), findsNothing);
    expect(service.executes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reopening an unconfirmed review keeps the exact plan actionable',
    (tester) async {
      final service = _Service();
      await host(tester, service);
      await tester.tap(filledButtons());
      await pump(tester);
      await tester.tap(find.byIcon(Icons.close));
      await pump(tester);
      await tester.tap(find.text('Open fixture'));
      await pump(tester);
      expect(service.prepares, 1);
      await tester.ensureVisible(filledButtons());
      await tester.tap(filledButtons());
      await pump(tester);
      expect(service.executes, 1);
      expect(service.current!.stage, NasNativeInstallStage.installing);
    },
  );

  testWidgets(
    'recovered task reconciles read-only without repeating installation',
    (tester) async {
      final service = _Service();
      service.current = service.task(NasNativeInstallStage.needsInspection);
      await host(tester, service);
      await tester.ensureVisible(filledButtons());
      await tester.tap(filledButtons());
      await pump(tester);
      expect(service.reconciliations, 1);
      expect(service.executes, 0);
      expect(service.prepares, 0);
      expect(service.current!.id, 'a' * 32);
    },
  );

  testWidgets(
    'target change while awaiting service prevents late reconciliation',
    (tester) async {
      final service = _Service();
      service.current = service.task(NasNativeInstallStage.needsInspection);
      final deferred = Completer<NasNativeInstallService>();
      final active = await host(tester, service, deferredService: deferred);
      await tester.ensureVisible(filledButtons());
      await tester.tap(filledButtons());
      await pump(tester);
      active.select(centerServer.copyWith(host: 'other.invalid'));
      deferred.complete(service);
      await pump(tester);
      expect(service.reconciliations, 0);
      expect(service.executes, 0);
      expect(service.prepares, 0);
    },
  );

  testWidgets('native form and review fit 320dp with doubled text', (
    tester,
  ) async {
    final service = _Service();
    await host(tester, service, width: 320, scale: 2);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(filledButtons());
    await tester.tap(filledButtons());
    await pump(tester);
    expect(find.text('debian 12 (amd64)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('running native task logs fit 320dp with doubled text', (
    tester,
  ) async {
    final service = _Service();
    service.current = service.task(NasNativeInstallStage.installing);
    await host(tester, service, width: 320, scale: 2);
    expect(find.text('apt-get install fixture-package'), findsOneWidget);
    expect(find.text('fixture output'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
