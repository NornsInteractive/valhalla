import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/core/providers/application_center_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/providers/storage_providers.dart';
import 'package:valhalla/data/models/application_center.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/features/app_center/widgets/app_installed_tab.dart';
import 'package:valhalla/features/app_center/widgets/app_access_info_dialog.dart';
import 'package:valhalla/features/app_center/widgets/app_store_tab.dart';
import 'package:valhalla/features/app_center/application_center_view.dart';
import 'package:valhalla/features/app_center/widgets/app_details_dialog.dart';
import 'package:valhalla/features/app_center/widgets/app_task_details_dialog.dart';
import 'package:valhalla/features/app_center/widgets/app_center_error_resolver.dart';
import 'package:valhalla/features/app_center/widgets/app_operation_wizard_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';
import '../support/application_center_fakes.dart';
import '../support/acp_chat_widget_harness.dart' show loadRealTextFonts;

class _Center extends ApplicationCenterNotifier {
  _Center({this.empty = false});
  final bool empty;
  int prepared = 0, executions = 0, cancellations = 0, refreshes = 0;
  int accessReads = 0, opens = 0;
  ApplicationConfiguration? preparedConfiguration;
  ApplicationAccessInfo? accessResult;
  String? openedDirectUrl;
  final List<String?> refreshedSourceIds = [];
  Completer<void>? catalogRefreshBarrier;
  String? observed;
  @override
  void setObservedTask(String? taskId) => observed = taskId;
  @override
  void clearObservedTask(String taskId) {
    if (observed == taskId) observed = null;
  }

  @override
  ApplicationCenterState build() => ApplicationCenterState(
    environment: centerEnvironment(),
    deployments: empty ? [] : [centerDeployment()],
    catalog: [centerApp],
  );
  @override
  Future<ApplicationEnvironment> inspectEnvironment({
    String? sudoPassword,
  }) async => state.environment!;
  @override
  Future<ApplicationTemplate> loadTemplate(
    CatalogApplication application,
  ) async => centerTemplate;
  @override
  Future<void> refreshServer() async {
    refreshes++;
    state = state.copyWith(refreshing: false);
  }

  @override
  Future<void> refreshCatalog({String? sourceId}) async {
    refreshedSourceIds.add(sourceId);
    state = state.copyWith(loadingCatalog: true);
    await catalogRefreshBarrier?.future;
    state = state.copyWith(loadingCatalog: false);
  }

  void setSourceFailureFixture() => state = state.copyWith(
    sources: const [
      ApplicationSource(
        id: 'fixture',
        name: 'Failed source',
        url: 'https://failed.invalid',
      ),
      ApplicationSource(
        id: 'healthy',
        name: 'Healthy source',
        url: 'https://healthy.invalid',
      ),
    ],
    catalog: const [
      centerApp,
      CatalogApplication(
        sourceId: 'healthy',
        id: 'healthy-app',
        title: 'Healthy app',
        composeUrl: '',
      ),
    ],
    sourceErrors: const {
      'fixture': 'APP_CENTER_SOURCE_UNAVAILABLE: DNS failed failed.invalid',
    },
  );

  void replaceTasks(List<ApplicationTask> tasks) =>
      state = state.copyWith(tasks: tasks);
  void setSourceError() =>
      state = state.copyWith(sourceErrors: {'fixture': 'unreachable'});
  void setDeployments(List<ApplicationDeployment> apps) =>
      state = state.copyWith(deployments: apps);
  void setCatalog(List<CatalogApplication> apps) =>
      state = state.copyWith(catalog: apps);
  @override
  Future<ApplicationAccessInfo> accessInfo(
    ApplicationDeployment deployment,
  ) async {
    accessReads++;
    return accessResult!;
  }

  @override
  Future<void> openApplication(
    ApplicationDeployment deployment, {
    String? directUrl,
  }) async {
    opens++;
    openedDirectUrl = directUrl;
  }

  @override
  Future<ApplicationTask> execute(ApplicationOperationPlan plan) async {
    executions++;
    final task = centerTask(plan.deployment);
    state = state.copyWith(tasks: [task], deployments: [plan.deployment]);
    return task;
  }

  @override
  Future<void> cancelTask(ApplicationTask task) async {
    cancellations++;
    throw const ApplicationCenterException('APP_CENTER_NOT_CONNECTED');
  }

  @override
  Future<ApplicationOperationPlan> prepare(
    ApplicationOperation operation, {
    ApplicationTemplate? template,
    ApplicationConfiguration? configuration,
    ApplicationDeployment? deployment,
    String? sudoPassword,
    ApplicationUninstallSelection? uninstallSelection,
  }) async {
    prepared++;
    preparedConfiguration = configuration;
    return CenterDeploymentService().prepare(
      centerServer,
      centerEnvironment(),
      operation,
      template: template,
      configuration: configuration,
      uninstallSelection: uninstallSelection,
    );
  }
}

void main() {
  Future<void> host(
    WidgetTester tester,
    _Center notifier, {
    double scale = 1,
    bool connected = true,
    bool installed = false,
    bool fullView = false,
    double width = 320,
    double? contentWidth,
    Locale locale = const Locale('en'),
    LocalStorageService? storageOverride,
  }) async {
    await loadRealTextFonts();
    if (storageOverride == null) SharedPreferences.setMockInitialValues({});
    final storage =
        storageOverride ??
        LocalStorageService(await SharedPreferences.getInstance());
    tester.view.physicalSize = Size(width, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          applicationCenterProvider.overrideWith(() => notifier),
          activeServerProvider.overrideWith(CenterActiveServer.new),
          serverConnectionProvider.overrideWith(() => _Connection(connected)),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(
            brightness: Brightness.light,
            seedColor: Colors.green,
          ),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: fullView
              ? Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: contentWidth,
                    child: const ApplicationCenterView(),
                  ),
                )
              : installed
              ? const Scaffold(body: AppInstalledTab())
              : Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => AppOperationWizardDialog.show(
                          context,
                          operation: ApplicationOperation.install,
                          catalogApp: centerApp,
                        ),
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
    if (!installed && !fullView) {
      await tester.tap(find.text('Open'));
    }
    await tester.pumpAndSettle();
  }

  Future<void> chooseSshAccess(WidgetTester tester) async {
    final choice = find.byType(ChoiceChip).first;
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.pumpAndSettle();
  }

  testWidgets('new installation requires explicit access choice', (
    tester,
  ) async {
    final notifier = _Center();
    await host(tester, notifier);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await chooseSshAccess(tester);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(notifier.prepared, 0);
  });

  testWidgets('320dp and 2x text do not overflow the config wizard', (
    tester,
  ) async {
    await host(tester, _Center(), scale: 2);
    expect(find.byType(AppOperationWizardDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'opening does not show keyboard; editing survives provider refresh',
    (tester) async {
      final notifier = _Center();
      await host(tester, notifier);
      expect(tester.testTextInput.isVisible, false);
      final field = find.byKey(const ValueKey('port-web/80/tcp'));
      await tester.enterText(field, '9090');
      final editable = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, true);
      await notifier.refreshServer();
      await tester.pump();
      expect(tester.widget<TextFormField>(field).controller!.text, '9090');
      expect(editable.focusNode.hasFocus, true);
    },
  );
  testWidgets('cleared port is rejected before preparing a deployment', (
    tester,
  ) async {
    final notifier = _Center();
    await host(tester, notifier);
    await chooseSshAccess(tester);
    await tester.enterText(find.byKey(const ValueKey('port-web/80/tcp')), '');
    final button = find.byType(FilledButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(notifier.prepared, 0);
    expect(find.textContaining('APP_CENTER_PORT_INVALID'), findsOneWidget);
  });
  testWidgets('actual installed cards remain visible offline', (tester) async {
    await host(tester, _Center(), connected: false, installed: true);
    expect(find.text('Cached App'), findsOneWidget);
    expect(
      tester
          .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>))
          .enabled,
      false,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stop confirmation cancellation never prepares or executes', (
    tester,
  ) async {
    final notifier = _Center();
    await host(tester, notifier, installed: true);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(AppInstalledTab)),
    );
    await tester.tap(find.byTooltip(l10n.appCenterStop));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Fixture'), findsWidgets);
    await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
    await tester.pumpAndSettle();
    expect(notifier.prepared, 0);
    expect(notifier.executions, 0);
    expect(tester.testTextInput.isVisible, false);
  });

  testWidgets(
    'multiservice installed card at desktop 2x expands without overflow',
    (tester) async {
      final notifier = _Center();
      await host(tester, notifier, installed: true, width: 1200, scale: 2);
      final json = centerDeployment().toJson();
      json['name'] =
          'A very long self-hosted application name for overflow coverage';
      json['services'] = List.generate(
        5,
        (i) => ApplicationServiceHealth(
          name: 'long-service-name-$i',
          state: 'running',
          health: 'healthy',
        ).toJson(),
      );
      notifier.setDeployments([ApplicationDeployment.fromJson(json)]);
      await tester.pumpAndSettle();
      expect(find.textContaining('long self-hosted'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('store to details to install, live result then installed tab', (
    tester,
  ) async {
    final notifier = _Center(empty: true);
    await host(tester, notifier, fullView: true);
    await tester.tap(find.text('Fixture App'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDetailsDialog), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(AppDetailsDialog)),
    );
    await tester.tap(find.text(l10n.appCenterInstall));
    await tester.pumpAndSettle();
    expect(find.byType(AppOperationWizardDialog), findsOneWidget);
    await chooseSshAccess(tester);
    await tester.tap(find.widgetWithText(FilledButton, l10n.appCenterNext));
    await tester.pumpAndSettle();
    expect(notifier.prepared, 1);
    final execute = find.widgetWithText(
      FilledButton,
      l10n.appCenterConfirmAndExecute,
    );
    await tester.tap(execute);
    await tester.tap(execute);
    await tester.pump();
    expect(notifier.executions, 1);
    expect(find.text(l10n.appCenterTaskStageQueued), findsWidgets);
    final clockAheadTask = centerTask(centerDeployment()).copyWith(
      stage: ApplicationTaskStage.pulling,
      lastOutputAt: DateTime.now().add(const Duration(seconds: 30)),
    );
    notifier.replaceTasks([clockAheadTask]);
    await tester.pump();
    final progressContext = tester.element(
      find.byType(AppOperationWizardDialog),
    );
    expect(
      find.text('${progressContext.appCenterLastOutputLabel}: 0s'),
      findsOneWidget,
    );
    final task = centerTask(
      centerDeployment(),
    ).copyWith(stage: ApplicationTaskStage.succeeded, exitCode: 0);
    notifier.replaceTasks([task]);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(AppOperationWizardDialog));
    await tester.tap(
      find.widgetWithText(FilledButton, context.appCenterViewInstalledLabel),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppOperationWizardDialog), findsNothing);
    expect(find.text('Cached App'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search survives tab switch and source refresh error', (
    tester,
  ) async {
    final notifier = _Center(empty: true);
    await host(tester, notifier, fullView: true, width: 800);
    final field = find.byType(TextField);
    await tester.enterText(field, 'Fixture');
    tester.testTextInput.hide();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ApplicationCenterView)),
    );
    await tester.tap(find.text(l10n.appCenterTabTasks));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.appCenterTabStore));
    await tester.pumpAndSettle();
    notifier.setSourceError();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Fixture',
    );
    expect(find.text('Fixture App'), findsOneWidget);
    expect(tester.testTextInput.isVisible, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'details loaded on old server cannot install after target switch',
    (tester) async {
      final notifier = _Center(empty: true);
      await host(tester, notifier, fullView: true);
      await tester.tap(find.text('Fixture App'));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AppDetailsDialog));
      final l10n = AppLocalizations.of(context);
      final container = ProviderScope.containerOf(context);
      (container.read(activeServerProvider.notifier) as CenterActiveServer)
          .select(centerServer.copyWith(id: 'other', host: 'other.invalid'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.appCenterInstall));
      await tester.pumpAndSettle();
      expect(find.byType(AppOperationWizardDialog), findsNothing);
      expect(notifier.executions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unknown task rechecks only and exposes selectable logs', (
    tester,
  ) async {
    final notifier = _Center();
    await host(tester, notifier, installed: true);
    final task = centerTask(centerDeployment()).copyWith(
      stage: ApplicationTaskStage.needsInspection,
      logTail: 'fixture task log',
    );
    notifier.replaceTasks([task]);
    final context = tester.element(find.byType(AppInstalledTab));
    AppTaskDetailsDialog.show(context, taskId: task.id);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(SelectableText, 'fixture task log'),
      findsOneWidget,
    );
    final details = tester.element(find.byType(AppTaskDetailsDialog));
    await tester.tap(find.text(details.appCenterRecheckTaskLabel));
    await tester.pumpAndSettle();
    expect(notifier.refreshes, 1);
    expect(notifier.executions, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('task cancellation error handled without uncaught async error', (
    tester,
  ) async {
    final notifier = _Center();
    await host(tester, notifier, installed: true);
    final task = centerTask(centerDeployment());
    notifier.replaceTasks([task]);
    AppTaskDetailsDialog.show(
      tester.element(find.byType(AppInstalledTab)),
      taskId: task.id,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(AppTaskDetailsDialog)),
    );
    await tester.tap(find.text(l10n.appCenterCancelTask));
    await tester.pump(const Duration(milliseconds: 400));
    expect(notifier.cancellations, 1);
    expect(find.text(l10n.appCenterErrorNotConnected), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp 2x RTL store remains usable', (tester) async {
    await host(
      tester,
      _Center(empty: true),
      fullView: true,
      scale: 2,
      locale: const Locale('ar'),
    );
    expect(find.text('Fixture App'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline task details disable cancellation', (tester) async {
    final notifier = _Center();
    await host(tester, notifier, installed: true, connected: false);
    final task = centerTask(centerDeployment());
    notifier.replaceTasks([task]);
    AppTaskDetailsDialog.show(
      tester.element(find.byType(AppInstalledTab)),
      taskId: task.id,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final l10n = AppLocalizations.of(
      tester.element(find.byType(AppTaskDetailsDialog)),
    );
    final button = find.ancestor(
      of: find.text(l10n.appCenterCancelTask),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    expect(notifier.cancellations, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live applying stage removes cancellation from wizard', (
    tester,
  ) async {
    final notifier = _Center(empty: true);
    await host(tester, notifier);
    await chooseSshAccess(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(AppOperationWizardDialog)),
    );
    await tester.tap(find.text(l10n.appCenterNext));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.appCenterConfirmAndExecute));
    await tester.pump();
    expect(find.text(l10n.appCenterCancelTask), findsOneWidget);
    notifier.replaceTasks([
      centerTask(
        centerDeployment(),
      ).copyWith(stage: ApplicationTaskStage.applying),
    ]);
    await tester.pump();
    expect(find.text(l10n.appCenterCancelTask), findsNothing);
    expect(notifier.executions, 1);
    expect(tester.takeException(), isNull);
  });

  Finder storeDescendant(Finder matching) =>
      find.descendant(of: find.byType(AppStoreTab), matching: matching);
  Future<void> toggleStore(WidgetTester tester) async {
    final icon =
        storeDescendant(find.byIcon(Icons.grid_view)).evaluate().isNotEmpty
        ? storeDescendant(find.byIcon(Icons.grid_view))
        : storeDescendant(find.byIcon(Icons.view_list));
    await tester.ensureVisible(icon);
    await tester.tap(icon);
    await tester.pumpAndSettle();
  }

  List<CatalogApplication> catalog(int count) => List.generate(
    count,
    (i) => CatalogApplication(
      sourceId: 'fixture',
      id: 'app-$i',
      title: 'Catalog item ${i.toString().padLeft(3, '0')}',
      category: i.isEven ? 'Media' : 'Tools',
      summary: 'A fixture application for list and grid browsing.',
      composeUrl: '',
    ),
  );

  for (final width in [320.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'store list fits content at ${width.toInt()}dp and ${scale}x text',
        (tester) async {
          final notifier = _Center(empty: true);
          await host(
            tester,
            notifier,
            fullView: true,
            width: width,
            scale: scale,
          );
          notifier.setCatalog([
            CatalogApplication.fromJson({
              ...catalog(1).single.toJson(),
              'summary': 'Short summary',
              'version': '1.2.3',
            }),
          ]);
          await tester.pumpAndSettle();
          final card = find
              .ancestor(
                of: find.text('Catalog item 000'),
                matching: find.byType(InkWell),
              )
              .first;
          final bounds = tester.getRect(card);
          final metadata = find.descendant(
            of: card,
            matching: find.text('fixture'),
          );
          expect(bounds.height, greaterThanOrEqualTo(48));
          if (scale == 1) expect(bounds.height, lessThan(100));
          expect(
            bounds.bottom - tester.getBottomLeft(metadata).dy,
            lessThanOrEqualTo(12),
            reason: 'short descriptions must not leave an empty footer',
          );
          expect(tester.widget<Text>(find.text('Short summary')).maxLines, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('store grid has two compact cards at ${width.toInt()}dp', (
      tester,
    ) async {
      final notifier = _Center(empty: true);
      await host(tester, notifier, fullView: true, width: width);
      notifier.setCatalog(catalog(4));
      await tester.pumpAndSettle();
      final first = find.text('Catalog item 000');
      final second = find.text('Catalog item 001');
      expect(tester.getTopLeft(first).dx, tester.getTopLeft(second).dx);
      expect(
        tester.getTopLeft(first).dy,
        lessThan(tester.getTopLeft(second).dy),
      );
      await toggleStore(tester);
      expect(storeDescendant(find.byType(GridView)), findsOneWidget);
      expect(
        tester.getTopLeft(first).dx,
        lessThan(tester.getTopLeft(second).dx),
      );
      expect(
        tester.getTopLeft(first).dy,
        closeTo(tester.getTopLeft(second).dy, 1),
      );
      final card = find
          .ancestor(of: first, matching: find.byType(InkWell))
          .first;
      final icon = find.descendant(of: card, matching: find.byIcon(Icons.apps));
      expect(icon, findsOneWidget);
      expect(tester.getSize(icon).width, lessThanOrEqualTo(32));
      final titleBounds = tester.getRect(first);
      final iconBounds = tester.getRect(icon);
      expect(titleBounds.top, lessThan(iconBounds.bottom));
      expect(
        titleBounds.bottom,
        greaterThan(iconBounds.top),
        reason: 'icon and title must share a row, even when the title wraps',
      );
      expect(tester.getSize(card).height, inInclusiveRange(112, 128));
      expect(
        tester.getTopLeft(first).dx,
        greaterThan(tester.getTopLeft(icon).dx),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('store first toggle uses body width rather than viewport width', (
    tester,
  ) async {
    final notifier = _Center(empty: true);
    await host(tester, notifier, fullView: true, width: 640, contentWidth: 560);
    notifier.setCatalog(catalog(4));
    await tester.pumpAndSettle();
    expect(storeDescendant(find.byType(ListView)), findsOneWidget);
    await toggleStore(tester);
    expect(storeDescendant(find.byType(GridView)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.5, 2.0]) {
    testWidgets('compact store fits long title and status at ${scale}x', (
      tester,
    ) async {
      final notifier = _Center(empty: true);
      await host(
        tester,
        notifier,
        fullView: true,
        width: 320,
        scale: scale,
        locale: const Locale('vi'),
      );
      notifier.setCatalog([
        CatalogApplication.fromJson({
          ...catalog(1).single.toJson(),
          'title':
              'Very long two line application name requiring measured height',
          'architectures': ['incompatible-fixture-architecture'],
        }),
      ]);
      await tester.pumpAndSettle();
      await toggleStore(tester);
      expect(storeDescendant(find.byType(GridView)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('store grid bounds long version metadata at narrow large text', (
    tester,
  ) async {
    final notifier = _Center(empty: true);
    await host(tester, notifier, fullView: true, width: 320, scale: 2);
    notifier.setCatalog([
      CatalogApplication.fromJson({
        ...catalog(1).single.toJson(),
        'version': '2026.10.13-long-build-identifier-amd64-release',
      }),
    ]);
    await tester.pumpAndSettle();
    await toggleStore(tester);
    expect(storeDescendant(find.byType(GridView)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'source failure retry targets only that source and preserves other apps',
    (tester) async {
      final notifier = _Center(empty: true)
        ..catalogRefreshBarrier = Completer<void>();
      await host(tester, notifier, fullView: true, width: 800);
      notifier.setSourceFailureFixture();
      await tester.pumpAndSettle();
      expect(find.text('Healthy app'), findsOneWidget);
      final context = tester.element(find.byType(AppStoreTab));
      final retry = storeDescendant(
        find.widgetWithText(TextButton, context.appCenterRetryLabel),
      );
      expect(retry, findsOneWidget);
      int storeTabIndex() =>
          (find.byType(TabBar).evaluate().first.widget as TabBar)
              .controller!
              .index;
      expect(storeTabIndex(), 0);
      expect(
        retry.hitTestable(),
        findsOneWidget,
        reason:
            'retry must already be visible: global ensureVisible scrolls '
            'the enclosing tab PageView away from the Store tab',
      );
      await tester.tap(retry);
      await tester.pump();
      expect(storeTabIndex(), 0);
      expect(notifier.refreshedSourceIds, ['fixture']);
      expect(find.text('Healthy app'), findsOneWidget);
      expect(find.text('Fixture App'), findsOneWidget);
      expect(tester.widget<TextButton>(retry).onPressed, isNull);
      notifier.catalogRefreshBarrier!.complete();
      await tester.pumpAndSettle();
      expect(storeTabIndex(), 0);
      expect(find.text('Healthy app'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'store view persists across remount and preserves search/category',
    (tester) async {
      final notifier = _Center(empty: true);
      await host(tester, notifier, fullView: true);
      notifier.setCatalog(catalog(8));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AppStoreTab));
      final storage = ProviderScope.containerOf(
        context,
      ).read(localStorageServiceProvider);
      await tester.enterText(
        storeDescendant(find.byType(TextField)),
        'Catalog',
      );
      tester.testTextInput.hide();
      await tester.tap(
        storeDescendant(find.byType(DropdownButton<String>)).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Media').last);
      await tester.pumpAndSettle();
      await toggleStore(tester);
      expect(storage.getApplicationStoreViewMode(), 'grid');
      expect(storeDescendant(find.byType(GridView)), findsOneWidget);
      expect(
        tester
            .widget<TextField>(storeDescendant(find.byType(TextField)))
            .controller!
            .text,
        'Catalog',
      );
      expect(
        tester
            .widget<DropdownButton<String>>(
              storeDescendant(find.byType(DropdownButton<String>)).first,
            )
            .value,
        'Media',
      );
      expect(find.text('Catalog item 001'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await host(
        tester,
        _Center(empty: true),
        fullView: true,
        storageOverride: storage,
      );
      expect(storeDescendant(find.byType(GridView)), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 812.0, 1100.0]) {
    for (final distance in [950.0, 4800.0]) {
      testWidgets(
        'store list/grid keeps visible application anchor at ${width.toInt()}dp after ${distance.toInt()}px',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            'valhalla_app_store_view_mode_v1': 'list',
          });
          final storage = LocalStorageService(
            await SharedPreferences.getInstance(),
          );
          final notifier = _Center(empty: true);
          await host(
            tester,
            notifier,
            fullView: true,
            width: width,
            storageOverride: storage,
          );
          notifier.setCatalog(catalog(160));
          await tester.pumpAndSettle();
          final list = storeDescendant(find.byType(ListView));
          await tester.drag(list, Offset(0, -distance));
          await tester.pumpAndSettle();
          final viewport = tester.getRect(list);
          final visible =
              find.textContaining('Catalog item').evaluate().where((element) {
                final bounds = tester.getRect(find.byWidget(element.widget));
                return bounds.top >= viewport.top &&
                    bounds.bottom <= viewport.bottom;
              }).toList()..sort(
                (a, b) => tester
                    .getTopLeft(find.byWidget(a.widget))
                    .dy
                    .compareTo(tester.getTopLeft(find.byWidget(b.widget)).dy),
              );
          expect(visible, isNotEmpty);
          final anchor = (visible.first.widget as Text).data!;
          expect(anchor, isNot('Catalog item 000'));
          await toggleStore(tester);
          final grid = storeDescendant(find.byType(GridView));
          expect(grid, findsOneWidget);
          expect(
            find.text(anchor),
            findsOneWidget,
            reason: 'switch must retain the currently visible application',
          );
          expect(
            tester.getRect(grid).overlaps(tester.getRect(find.text(anchor))),
            true,
          );
          await toggleStore(tester);
          expect(find.text(anchor), findsOneWidget);
          expect(
            tester
                .getRect(storeDescendant(find.byType(ListView)))
                .overlaps(tester.getRect(find.text(anchor))),
            true,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'failed view persistence surfaces failure without unhandled async error',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = _FailingViewStorage(
        await SharedPreferences.getInstance(),
      );
      await host(
        tester,
        _Center(empty: true),
        fullView: true,
        storageOverride: storage,
      );
      await toggleStore(tester);
      expect(storeDescendant(find.byType(ListView)), findsOneWidget);
      expect(find.textContaining('fixture write failure'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'live task command is selectable/copyable; sync failure retains output and dispose clears observation',
    (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final notifier = _Center();
      await host(tester, notifier, installed: true);
      const command = 'docker compose --project-name fixture pull';
      final task = centerTask(centerDeployment()).copyWith(
        stage: ApplicationTaskStage.pulling,
        currentCommand: command,
        commandStartedAt: DateTime.now(),
        lastOutputAt: DateTime.now().add(const Duration(seconds: 30)),
        logTail: 'Pulling image\nLayer one complete',
      );
      notifier.replaceTasks([task]);
      AppTaskDetailsDialog.show(
        tester.element(find.byType(AppInstalledTab)),
        taskId: task.id,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(notifier.observed, task.id);
      expect(find.text('0s'), findsOneWidget);
      final selectable = find.widgetWithText(SelectableText, command);
      expect(selectable, findsOneWidget);
      final commandCard = find
          .ancestor(of: selectable, matching: find.byType(Container))
          .first;
      final copy = find.descendant(
        of: commandCard,
        matching: find.byIcon(Icons.copy),
      );
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pump();
      expect(copied, [command]);
      notifier.replaceTasks([
        task.copyWith(syncError: 'APP_CENTER_NOT_CONNECTED'),
      ]);
      await tester.pump();
      expect(find.widgetWithText(SelectableText, command), findsOneWidget);
      expect(find.widgetWithText(SelectableText, task.logTail), findsOneWidget);
      expect(find.textContaining('APP_CENTER_NOT_CONNECTED'), findsOneWidget);
      Navigator.of(tester.element(find.byType(AppTaskDetailsDialog))).pop();
      await tester.pumpAndSettle();
      expect(notifier.observed, isNull);
      expect(notifier.executions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  String taskLogs(int count) =>
      List.generate(count, (index) => 'Downloading layer $index').join('\n');

  Future<ScrollController> openLongTask(
    WidgetTester tester,
    _Center notifier,
    ApplicationTask task,
  ) async {
    await host(tester, notifier, installed: true, width: 800);
    notifier.replaceTasks([task]);
    AppTaskDetailsDialog.show(
      tester.element(find.byType(AppInstalledTab)),
      taskId: task.id,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final panel = find.descendant(
      of: find.byType(AppTaskDetailsDialog),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView && widget.controller != null,
      ),
    );
    expect(panel, findsOneWidget);
    final controller = tester.widget<SingleChildScrollView>(panel).controller!;
    expect(controller.position.maxScrollExtent, greaterThan(100));
    return controller;
  }

  testWidgets('existing task output initially shows the latest log lines', (
    tester,
  ) async {
    final task = centerTask(
      centerDeployment(),
    ).copyWith(stage: ApplicationTaskStage.pulling, logTail: taskLogs(120));
    final controller = await openLongTask(tester, _Center(), task);
    expect(
      controller.offset,
      closeTo(controller.position.maxScrollExtent, 1),
      reason:
          'existing logs need initial follow, not only a later provider event',
    );
    Navigator.of(tester.element(find.byType(AppTaskDetailsDialog))).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('new logs preserve user scroll until follow latest is selected', (
    tester,
  ) async {
    final notifier = _Center();
    final task = centerTask(
      centerDeployment(),
    ).copyWith(stage: ApplicationTaskStage.pulling, logTail: taskLogs(120));
    final controller = await openLongTask(tester, notifier, task);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    controller.jumpTo(80);
    await tester.pump();
    notifier.replaceTasks([task.copyWith(logTail: taskLogs(130))]);
    await tester.pump();
    await tester.pump();
    expect(controller.offset, closeTo(80, 1));
    final follow = find.descendant(
      of: find.byType(AppTaskDetailsDialog),
      matching: find.byIcon(Icons.arrow_downward),
    );
    expect(follow, findsOneWidget);
    await tester.ensureVisible(follow);
    await tester.tap(follow);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.offset, closeTo(controller.position.maxScrollExtent, 1));
    notifier.replaceTasks([task.copyWith(logTail: taskLogs(140))]);
    await tester.pump();
    await tester.pump();
    expect(controller.offset, closeTo(controller.position.maxScrollExtent, 1));
    Navigator.of(tester.element(find.byType(AppTaskDetailsDialog))).pop();
    await tester.pumpAndSettle();
    expect(notifier.observed, isNull);
    expect(tester.takeException(), isNull);
  });

  ApplicationAccessInfo accessFixture({bool publicManagement = false}) =>
      ApplicationAccessInfo(
        ports: [
          const ApplicationPort(
            service: 'web',
            target: 80,
            published: 18080,
            bindAddress: '0.0.0.0',
          ),
          ApplicationPort(
            service: 'admin',
            target: 81,
            published: 18081,
            bindAddress: publicManagement ? '0.0.0.0' : '127.0.0.1',
          ),
        ],
        services: const [
          ApplicationServiceHealth(
            name: 'web',
            state: 'running',
            health: 'healthy',
          ),
          ApplicationServiceHealth(name: 'admin', state: 'running'),
        ],
        managementPort: ApplicationPort(
          service: 'admin',
          target: 81,
          published: 18081,
          bindAddress: publicManagement ? '0.0.0.0' : '127.0.0.1',
        ),
        sshEndpoint: Uri.parse('https://127.0.0.1:18081/admin?view=1'),
        probeStatus: ApplicationAccessProbeStatus.reachable,
        checkedAt: DateTime.utc(2026, 10, 12),
        httpStatus: 200,
      );
  Future<void> openAccess(WidgetTester tester) async {
    AppAccessInfoDialog.show(
      tester.element(find.byType(AppInstalledTab)),
      deployment: centerDeployment(),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'access info is read-only and private management opens through existing SSH path',
    (tester) async {
      final notifier = _Center()..accessResult = accessFixture();
      await host(tester, notifier, installed: true, width: 800);
      await openAccess(tester);
      expect(notifier.accessReads, 1);
      expect(notifier.prepared, 0);
      expect(notifier.executions, 0);
      expect(find.textContaining('0.0.0.0:18080'), findsOneWidget);
      expect(find.textContaining('127.0.0.1:18081 →'), findsOneWidget);
      final context = tester.element(find.byType(AppAccessInfoDialog));
      final open = find
          .widgetWithText(
            FilledButton,
            AppLocalizations.of(context).appCenterOpen,
          )
          .first;
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(
        notifier.opens,
        1,
        reason:
            'must use notifier.openApplication, not launch remote localhost on device',
      );
      expect(notifier.openedDirectUrl, isNull);
      expect(
        find.textContaining('fixture.invalid:18081'),
        findsNothing,
        reason:
            'loopback-only management port is not an external access candidate',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'public management candidate preserves scheme path and IPv6 host',
    (tester) async {
      final notifier = _Center()
        ..accessResult = accessFixture(publicManagement: true);
      await host(tester, notifier, installed: true, width: 800);
      await openAccess(tester);
      final field = find.descendant(
        of: find.byType(AppAccessInfoDialog),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, '2001:db8::7');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(
        find.text('https://[2001:db8::7]:18081/admin?view=1'),
        findsOneWidget,
      );
      expect(
        notifier.accessReads,
        1,
        reason: 'editing a candidate must not probe arbitrary external hosts',
      );
      expect(notifier.executions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'access diagnostics cannot open stale endpoints after server switch',
    (tester) async {
      final notifier = _Center()
        ..accessResult = accessFixture(publicManagement: true);
      await host(tester, notifier, installed: true, width: 800);
      await openAccess(tester);
      final context = tester.element(find.byType(AppAccessInfoDialog));
      final l10n = AppLocalizations.of(context);
      final container = ProviderScope.containerOf(context);
      (container.read(activeServerProvider.notifier) as CenterActiveServer)
          .select(centerServer.copyWith(id: 'other', host: 'other.invalid'));
      await tester.pumpAndSettle();
      final controls = find.descendant(
        of: find.byType(AppAccessInfoDialog),
        matching: find.widgetWithText(FilledButton, l10n.appCenterOpen),
      );
      for (final button in tester.widgetList<FilledButton>(controls)) {
        expect(
          button.onPressed,
          isNull,
          reason:
              'diagnostics from a different server must not remain actionable',
        );
      }
      expect(find.text(l10n.appCenterErrorTargetChanged), findsOneWidget);
      expect(notifier.opens, 0);
      expect(notifier.accessReads, 1);
      expect(notifier.executions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('access mixed ports fit 320dp 2x RTL without exceptions', (
    tester,
  ) async {
    final notifier = _Center()
      ..accessResult = accessFixture(publicManagement: true);
    await host(
      tester,
      notifier,
      installed: true,
      scale: 2,
      locale: const Locale('ar'),
    );
    await openAccess(tester);
    expect(find.byType(AppAccessInfoDialog), findsOneWidget);
    expect(notifier.accessReads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editing host port retains per-port binding override through preview',
    (tester) async {
      final notifier = _Center();
      await host(tester, notifier);
      await chooseSshAccess(tester);
      final dropdown = find.byType(DropdownButtonFormField<String?>);
      final externalOption = tester
          .widget<DropdownButton<String?>>(
            find.descendant(
              of: dropdown,
              matching: find.byType(DropdownButton<String?>),
            ),
          )
          .items!
          .singleWhere((item) => item.value == '0.0.0.0')
          .child;
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.byWidget(externalOption).last);
      await tester.pumpAndSettle();
      final port = find.byKey(const ValueKey('port-web/80/tcp'));
      await tester.ensureVisible(port);
      await tester.enterText(port, '19090');
      tester.testTextInput.hide();
      final next = find.widgetWithText(FilledButton, 'Next');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(notifier.prepared, 1);
      expect(notifier.preparedConfiguration!.bindAddress, '127.0.0.1');
      expect(
        notifier.preparedConfiguration!.ports.single.bindAddress,
        '0.0.0.0',
      );
      expect(notifier.preparedConfiguration!.ports.single.published, 19090);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing binding after numeric edit and variable rebase keeps both edits',
    (tester) async {
      final notifier = _Center();
      await host(tester, notifier);
      await chooseSshAccess(tester);
      final port = find.byKey(const ValueKey('port-web/80/tcp'));
      await tester.ensureVisible(port);
      await tester.enterText(port, '19091');
      tester.testTextInput.hide();
      final dropdown = find.byType(DropdownButtonFormField<String?>);
      final externalOption = tester
          .widget<DropdownButton<String?>>(
            find.descendant(
              of: dropdown,
              matching: find.byType(DropdownButton<String?>),
            ),
          )
          .items!
          .singleWhere((item) => item.value == '0.0.0.0')
          .child;
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.byWidget(externalOption).last);
      await tester.pumpAndSettle();
      final timezone = find.byKey(const ValueKey('var-TZ'));
      await tester.ensureVisible(timezone);
      await tester.enterText(timezone, 'Europe/Paris');
      tester.testTextInput.hide();
      await tester.pump();
      expect(tester.widget<TextFormField>(port).controller!.text, '19091');
      final next = find.widgetWithText(FilledButton, 'Next');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(notifier.preparedConfiguration!.ports.single.published, 19091);
      expect(
        notifier.preparedConfiguration!.ports.single.bindAddress,
        '0.0.0.0',
      );
      expect(notifier.preparedConfiguration!.variables['TZ'], 'Europe/Paris');
      expect(tester.takeException(), isNull);
    },
  );
}

class _FailingViewStorage extends LocalStorageService {
  _FailingViewStorage(super.preferences);
  @override
  Future<void> setApplicationStoreViewMode(String value) async =>
      throw StateError('fixture write failure');
}

class _Connection extends ServerConnectionNotifier {
  _Connection(this.connected);
  final bool connected;
  @override
  ServerConnectionState build() => ServerConnectionState(
    status: connected
        ? ConnectionStateEnum.connected
        : ConnectionStateEnum.disconnected,
  );
}
