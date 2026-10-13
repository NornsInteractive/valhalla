import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/app/theme.dart';
import 'package:valhalla/core/providers/application_center_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/data/models/application_center.dart';
import 'package:valhalla/features/app_center/widgets/app_task_details_dialog.dart';
import 'package:valhalla/features/app_center/widgets/app_uninstall_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';

import '../support/acp_chat_widget_harness.dart' show loadRealTextFonts;
import '../support/application_center_fakes.dart';

const _eligible = ApplicationCleanupTarget(
  key: 'data',
  source: '/fixture/data',
  serviceTargets: ['web:/data'],
  identity: {'dev': 1, 'ino': 2},
);

class _Connection extends CenterConnection {
  @override
  ServerConnectionState build() =>
      const ServerConnectionState(status: ConnectionStateEnum.connected);
}

class _Center extends ApplicationCenterNotifier {
  final List<ApplicationCleanupTarget> targets;
  final String? inspectionError;
  int inspections = 0;
  bool advancedCleanup = false;
  int retryInspections = 0;
  int preparations = 0;
  int executions = 0;
  ApplicationOperation? operation;
  ApplicationUninstallSelection? selection;
  ApplicationTask? inspectedRetryTask;
  ApplicationTask? detailTask;
  String? observedTask;
  Completer<ApplicationUninstallPreview>? inspectionBarrier;
  Completer<ApplicationOperationPlan>? prepareBarrier;

  _Center({this.targets = const [_eligible], this.inspectionError});

  @override
  String? get serverKey => centerEnvironment().serverKey;

  @override
  void setObservedTask(String? id) => observedTask = id;

  @override
  void clearObservedTask(String id) {
    if (observedTask == id) observedTask = null;
  }

  ApplicationUninstallPreview get preview => ApplicationUninstallPreview(
    id: 'fixture-preview',
    deploymentId: centerDeployment().id,
    deployment: centerDeployment(),
    fingerprint: 'fixture-fingerprint',
    targets: targets,
    createdAt: DateTime.now(),
    inspectionError: inspectionError,
    allowAdvancedCleanup: advancedCleanup,
  );

  ApplicationOperationPlan get plan => ApplicationOperationPlan(
    token: 'fixture-confirmed-plan',
    operation: ApplicationOperation.uninstall,
    deployment: centerDeployment(),
    useSudo: false,
    createdAt: DateTime.now(),
  );

  @override
  ApplicationCenterState build() => ApplicationCenterState(
    environment: centerEnvironment(),
    deployments: [centerDeployment()],
    tasks: [?detailTask],
  );

  @override
  Future<ApplicationUninstallPreview> inspectUninstall(
    ApplicationDeployment deployment, {
    bool allowAdvancedCleanup = false,
  }) async {
    inspections++;
    advancedCleanup = allowAdvancedCleanup;
    return inspectionBarrier == null ? preview : inspectionBarrier!.future;
  }

  @override
  Future<ApplicationUninstallPreview> inspectCleanupRetry(
    ApplicationTask task, {
    bool allowAdvancedCleanup = false,
  }) async {
    retryInspections++;
    advancedCleanup = allowAdvancedCleanup;
    inspectedRetryTask = task;
    return preview;
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
    preparations++;
    this.operation = operation;
    selection = uninstallSelection;
    return prepareBarrier == null ? plan : prepareBarrier!.future;
  }

  @override
  Future<ApplicationTask> execute(ApplicationOperationPlan plan) async {
    executions++;
    return ApplicationTask.fromJson({
      ...centerTask(plan.deployment).toJson(),
      'operation': plan.operation.name,
    });
  }
}

ApplicationTask _retryTask({Map<String, dynamic> changes = const {}}) =>
    ApplicationTask.fromJson({
      ...centerTask(centerDeployment()).toJson(),
      'operation': 'uninstall',
      'stage': 'failed',
      'uninstallCompleted': true,
      'cleanupResults': [
        const ApplicationCleanupResult(
          key: 'data',
          source: '/fixture/data',
          outcome: ApplicationCleanupOutcome.failed,
          reasonCode: 'APP_CENTER_CLEANUP_PATH_CHANGED',
        ).toJson(),
      ],
      ...changes,
    });

void main() {
  Future<({_Connection connection, CenterActiveServer server})> host(
    WidgetTester tester,
    _Center center, {
    bool settle = true,
    ApplicationTask? retryTask,
    ApplicationTask? detailsTask,
    double width = 390,
    double scale = 1,
  }) async {
    await loadRealTextFonts();
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final connection = _Connection();
    final server = CenterActiveServer();
    center.detailTask = detailsTask;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          applicationCenterProvider.overrideWith(() => center),
          activeServerProvider.overrideWith(() => server),
          serverConnectionProvider.overrideWith(() => connection),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(
            brightness: Brightness.light,
            seedColor: Colors.green,
          ),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open-uninstall'),
                onPressed: () => detailsTask != null
                    ? AppTaskDetailsDialog.show(
                        context,
                        taskId: detailsTask.id,
                        initialTask: detailsTask,
                      )
                    : retryTask == null
                    ? AppUninstallDialog.show(
                        context,
                        deployment: centerDeployment(),
                      )
                    : AppUninstallDialog.showRetry(context, task: retryTask),
                child: const Text('Open uninstall'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-uninstall')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    return (connection: connection, server: server);
  }

  FilledButton submit(WidgetTester tester, [String? key]) =>
      tester.widget<FilledButton>(
        find.byKey(Key(key ?? 'app_uninstall_submit_button')),
      );

  testWidgets(
    'partial cleanup results fit 320dp doubled text and retain every outcome',
    (tester) async {
      final outcomes = ApplicationCleanupOutcome.values;
      final task = _retryTask(
        changes: {
          'cleanupResults': [
            for (final outcome in outcomes)
              ApplicationCleanupResult(
                key: outcome.name,
                source: '/fixture/${outcome.name}',
                outcome: outcome,
                reasonCode: outcome == ApplicationCleanupOutcome.failed
                    ? 'APP_CENTER_CLEANUP_PATH_CHANGED'
                    : null,
              ).toJson(),
          ],
        },
      );
      final center = _Center();
      await host(tester, center, detailsTask: task, width: 320, scale: 2);
      expect(center.observedTask, task.id);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AppTaskDetailsDialog)),
      );
      expect(find.text(l10n.appCenterCleanupPartialSummary), findsOneWidget);
      expect(find.text(l10n.appCenterCleanupResultsTitle), findsOneWidget);
      expect(find.text(l10n.appCenterCleanupDeleteFailed), findsOneWidget);
      for (final outcome in outcomes) {
        expect(
          find.widgetWithText(SelectableText, '/fixture/${outcome.name}'),
          findsOneWidget,
        );
      }
      for (final label in [
        l10n.appCenterCleanupPending,
        l10n.appCenterCleanupRemoved,
        l10n.appCenterCleanupAlreadyAbsent,
        l10n.appCenterCleanupRetained,
        l10n.appCenterTaskStageFailed,
      ]) {
        expect(find.text(label), findsWidgets);
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(center.observedTask, isNull);
      expect(center.executions, 0);
    },
  );

  testWidgets(
    'cleanup retry starts unchecked and empty selection only closes',
    (tester) async {
      final center = _Center();
      final task = _retryTask();
      final before = jsonEncode(task.toJson());
      await host(tester, center, retryTask: task);
      expect(center.retryInspections, 1);
      expect(center.inspections, 0);
      expect(identical(center.inspectedRetryTask, task), isTrue);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(
        find.byKey(const Key('app_uninstall_submit_button')),
        findsNothing,
      );
      expect(find.byKey(const Key('app_uninstall_next_button')), findsNothing);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(center.preparations, 0);
      expect(center.executions, 0);
      expect(jsonEncode(task.toJson()), before);
      expect(find.byType(AppUninstallDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cleanup retry requires a fresh nonempty confirmed selection', (
    tester,
  ) async {
    final center = _Center();
    final task = _retryTask();
    final before = jsonEncode(task.toJson());
    await host(tester, center, retryTask: task);
    expect(center.retryInspections, 1);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app_uninstall_next_button')));
    await tester.pumpAndSettle();
    expect(
      submit(tester, 'app_uninstall_confirm_delete_button').onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Cached App');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('app_uninstall_confirm_delete_button')),
    );
    await tester.pumpAndSettle();
    expect(center.operation, ApplicationOperation.uninstall);
    expect(center.selection!.previewId, 'fixture-preview');
    expect(center.selection!.selectedKeys, {'data'});
    expect(center.selection!.confirmationName, 'Cached App');
    expect(center.preparations, 1);
    expect(center.executions, 1);
    expect(jsonEncode(task.toJson()), before);
    expect(tester.takeException(), isNull);
  });

  for (final invalid in <Map<String, dynamic>>[
    {'uninstallCompleted': false},
    {'stage': 'succeeded'},
    {'operation': 'install'},
    {'serverKey': 'foreign-server-key'},
  ]) {
    testWidgets(
      'ineligible cleanup retry ${invalid.keys.single} never inspects or executes',
      (tester) async {
        final center = _Center();
        await host(tester, center, retryTask: _retryTask(changes: invalid));
        expect(center.retryInspections, 0);
        expect(center.inspections, 0);
        expect(center.preparations, 0);
        expect(center.executions, 0);
        expect(find.byType(Checkbox), findsNothing);
        expect(
          find.byKey(const Key('app_uninstall_submit_button')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('app_uninstall_next_button')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('uninstall preserves all data by default', (tester) async {
    final center = _Center();
    await host(tester, center);
    expect(center.inspections, 1);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
    expect(checkbox.onChanged, isNotNull);
    expect(submit(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('app_uninstall_submit_button')));
    await tester.pumpAndSettle();
    expect(center.operation, ApplicationOperation.uninstall);
    expect(center.selection, isNull);
    expect(center.preparations, 1);
    expect(center.executions, 1);
    expect(find.byType(AppUninstallDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocked or unidentified data directories cannot be selected', (
    tester,
  ) async {
    final center = _Center(
      targets: const [
        _eligible,
        ApplicationCleanupTarget(
          key: 'shared',
          source: '/fixture/shared',
          blockedReason: 'APP_CENTER_CLEANUP_SHARED_PATH',
          identity: {'dev': 1, 'ino': 3},
        ),
        ApplicationCleanupTarget(key: 'unknown', source: '/fixture/unknown'),
      ],
    );
    await host(tester, center);
    final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(boxes, hasLength(3));
    expect(boxes.every((box) => box.value == false), isTrue);
    expect(boxes[0].onChanged, isNotNull);
    expect(boxes[1].onChanged, isNull);
    expect(boxes[2].onChanged, isNull);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app_uninstall_next_button')), findsOneWidget);
    expect(find.byKey(const Key('app_uninstall_submit_button')), findsNothing);
    expect(center.preparations, 0);
    expect(center.executions, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'whole data root selection covers children once and remains opt-in',
    (tester) async {
      final center = _Center(
        targets: const [
          _eligible,
          ApplicationCleanupTarget(
            key: 'whole-root',
            source: '/fixture',
            isDataRoot: true,
            serviceTargets: [],
            identity: {'dev': 1, 'ino': 3},
          ),
        ],
      );
      await host(tester, center, width: 430);
      final boxes = find.byType(Checkbox);
      expect(boxes, findsNWidgets(2));
      expect(
        tester.widgetList<Checkbox>(boxes).every((box) => box.value == false),
        isTrue,
      );
      await tester.ensureVisible(boxes.last);
      await tester.tap(boxes.last);
      await tester.pump();
      expect(tester.widget<Checkbox>(boxes.last).value, isTrue);
      await tester.ensureVisible(boxes.first);
      await tester.tap(boxes.first);
      await tester.pump();
      expect(tester.widget<Checkbox>(boxes.first).value, isTrue);
      expect(tester.widget<Checkbox>(boxes.last).onChanged, isNull);
      expect(tester.widget<Checkbox>(boxes.last).value, isTrue);
      await tester.tap(boxes.first);
      await tester.pump();
      expect(tester.widget<Checkbox>(boxes.last).onChanged, isNotNull);
      expect(tester.widget<Checkbox>(boxes.last).value, isFalse);
      expect(center.executions, 0);
      await tester.tap(boxes.first);
      await tester.pump();
      await tester.tap(find.byKey(const Key('app_uninstall_next_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Cached App');
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('app_uninstall_confirm_delete_button')),
      );
      await tester.pumpAndSettle();
      expect(center.selection!.selectedKeys, {'whole-root'});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inspection failure disables deletion but keeps preserve-data exit',
    (tester) async {
      final center = _Center(inspectionError: 'INSPECTION_INCOMPLETE');
      await host(tester, center);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
      expect(submit(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('app_uninstall_submit_button')));
      await tester.pumpAndSettle();
      expect(center.selection, isNull);
      expect(center.executions, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected deletion requires exact app name and explicit risk ack',
    (tester) async {
      final center = _Center(
        targets: const [
          ApplicationCleanupTarget(
            key: 'external-data',
            source: '/fixture/external-data',
            risks: ['external'],
            identity: {'dev': 1, 'ino': 4},
          ),
        ],
      );
      await host(tester, center);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app_uninstall_next_button')));
      await tester.pumpAndSettle();
      const confirmKey = 'app_uninstall_confirm_delete_button';
      expect(submit(tester, confirmKey).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Cached App ');
      await tester.pumpAndSettle();
      expect(submit(tester, confirmKey).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Cached App');
      await tester.pumpAndSettle();
      expect(submit(tester, confirmKey).onPressed, isNull);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(submit(tester, confirmKey).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key(confirmKey)));
      await tester.pumpAndSettle();
      expect(center.preparations, 1);
      expect(center.executions, 1);
      expect(center.selection!.previewId, 'fixture-preview');
      expect(center.selection!.selectedKeys, {'external-data'});
      expect(center.selection!.acknowledgedRiskKeys, {'external-data'});
      expect(center.selection!.confirmationName, 'Cached App');
      expect(find.byType(AppUninstallDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final risk in ['system', 'shared', 'volume']) {
    testWidgets(
      '$risk data is selectable, never selected by default, and requires confirmation',
      (tester) async {
        final center = _Center(
          targets: [
            ApplicationCleanupTarget(
              key: 'advanced',
              source: risk == 'volume' ? 'fixture-volume' : '/fixture/$risk',
              kind: risk == 'volume' ? 'volume' : 'bind',
              risks: [risk],
              identity: const {'fingerprint': 'fixture'},
            ),
          ],
        );
        await host(tester, center);
        expect(center.advancedCleanup, isTrue);
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox)).onChanged,
          isNotNull,
        );
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.tap(find.byKey(const Key('app_uninstall_next_button')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Cached App');
        await tester.pump();
        expect(
          submit(tester, 'app_uninstall_confirm_delete_button').onPressed,
          isNull,
        );
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        expect(
          submit(tester, 'app_uninstall_confirm_delete_button').onPressed,
          isNotNull,
        );
        await tester.tap(
          find.byKey(const Key('app_uninstall_confirm_delete_button')),
        );
        await tester.pumpAndSettle();
        expect(center.selection!.selectedKeys, {'advanced'});
        expect(center.selection!.acknowledgedRiskKeys, {'advanced'});
        expect(center.executions, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final switchServer in [false, true]) {
    testWidgets(
      'prepare ${switchServer ? 'server change' : 'disconnect'} does not execute or stay busy',
      (tester) async {
        final center = _Center()
          ..prepareBarrier = Completer<ApplicationOperationPlan>();
        final controls = await host(tester, center);
        await tester.tap(find.byKey(const Key('app_uninstall_submit_button')));
        await tester.pump();
        expect(center.preparations, 1);
        if (switchServer) {
          controls.server.select(centerServer.copyWith(host: 'other.invalid'));
        } else {
          controls.connection.setConnected(false);
        }
        await tester.pump();
        center.prepareBarrier!.complete(center.plan);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(center.executions, 0);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Returning to the original connection permits explicit reinspection,
        // never automatic execution of the stale plan.
        controls.server.select(centerServer);
        controls.connection.setConnected(true);
        await tester.pumpAndSettle();
        expect(center.executions, 0);
        expect(center.inspections, 1);
        final recheck = find.byKey(const Key('app_uninstall_recheck_button'));
        expect(tester.widget<OutlinedButton>(recheck).onPressed, isNotNull);
        await tester.ensureVisible(recheck);
        await tester.tap(recheck);
        await tester.pumpAndSettle();
        expect(center.inspections, 2);
        expect(center.executions, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'inspection completing after disconnect releases spinner and stale data',
    (tester) async {
      final center = _Center()
        ..inspectionBarrier = Completer<ApplicationUninstallPreview>();
      final controls = await host(tester, center, settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      controls.connection.setConnected(false);
      center.inspectionBarrier!.complete(center.preview);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(center.executions, 0);
      controls.connection.setConnected(true);
      await tester.pumpAndSettle();
      final recheck = find.byKey(const Key('app_uninstall_recheck_button'));
      expect(tester.widget<OutlinedButton>(recheck).onPressed, isNotNull);
      expect(center.inspections, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
