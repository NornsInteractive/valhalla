import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/core/providers/nas_install_provider.dart';
import 'package:valhalla/core/providers/server_provider.dart';
import 'package:valhalla/core/services/nas_install_service.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/features/nas/widgets/nas_install_dialog.dart';
import 'package:valhalla/l10n/app_localizations.dart';

class FakeNasInstallPlan implements NasInstallPlan {
  @override
  final String id;
  @override
  final NasInstallRequest request;
  @override
  final String pinnedImage;
  @override
  final String composePreview;
  @override
  final List<String> steps;
  @override
  final List<String> blockers;
  @override
  final List<String> guidance;
  @override
  final String confirmationToken;
  @override
  final DateTime createdAt;
  @override
  final String targetIdentity;

  FakeNasInstallPlan({
    this.id = 'plan-id-123456789012',
    required this.request,
    this.pinnedImage = 'jellyfin/jellyfin:10.9.11',
    this.composePreview =
        'version: "3.8"\nservices:\n  jellyfin:\n    image: jellyfin/jellyfin:10.9.11',
    this.steps = const [
      'NAS_INSTALL_CREATE_PRIVATE_DIRECTORY',
      'NAS_INSTALL_WRITE_COMPOSE',
    ],
    this.blockers = const [],
    this.guidance = const ['NAS_INSTALL_SSH_TUNNEL_REQUIRED'],
    this.confirmationToken = 'token-123',
    DateTime? createdAt,
    this.targetIdentity = 'machine-1',
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  String get containerName => 'valhalla-nas-${id.substring(0, 12)}';

  @override
  bool get canInstall => blockers.isEmpty;
}

class FakeNasInstallService extends Fake implements NasInstallService {
  NasInstallTask? currentTask;
  final StreamController<NasInstallTask?> taskController =
      StreamController<NasInstallTask?>.broadcast();

  NasInstallRequest? lastPrepareRequest;
  NasInstallPlan? lastInstallPlan;
  NasInstallPlan? lastDiscardPlan;
  bool cancelCalled = false;
  bool reconcileCalled = false;

  bool delayInstall = false;
  Completer<NasInstallResult>? installCompleter;
  String? installErrorCode;

  @override
  NasInstallTask? get state => currentTask;

  @override
  Stream<NasInstallTask?> get states => taskController.stream;

  @override
  Future<NasInstallPlan> prepare(
    NasInstallRequest request, {
    String? webdavPassword,
  }) async {
    lastPrepareRequest = request;
    final plan = FakeNasInstallPlan(request: request);
    currentTask = NasInstallTask(
      id: 'task-test-123456789012',
      request: request,
      stage: NasInstallStage.review,
      startedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      plan: plan,
    );
    taskController.add(currentTask);
    return plan;
  }

  @override
  Future<NasInstallResult> install(
    NasInstallPlan plan, {
    required String confirmationToken,
  }) async {
    lastInstallPlan = plan;

    if (installErrorCode != null) {
      currentTask = NasInstallTask(
        id: plan.id,
        request: plan.request,
        stage: NasInstallStage.needsInspection,
        startedAt: plan.createdAt,
        updatedAt: DateTime.now(),
        plan: plan,
        requiresReconciliation: true,
        errorCode: installErrorCode,
        cleanupComplete: false,
      );
      taskController.add(currentTask);
      throw Exception(installErrorCode);
    }

    if (delayInstall) {
      currentTask = NasInstallTask(
        id: plan.id,
        request: plan.request,
        stage: NasInstallStage.pulling,
        startedAt: plan.createdAt,
        updatedAt: DateTime.now(),
        plan: plan,
        logTail: 'Pulling container image in progress...',
      );
      taskController.add(currentTask);
      installCompleter = Completer<NasInstallResult>();
      return installCompleter!.future;
    }

    final result = NasInstallResult(
      containerId: 'container-sha256-abcdef123456',
      endpoint: Uri.parse('http://127.0.0.1:${plan.request.port}'),
      dataRoot: plan.request.dataRoot,
      healthy: true,
    );
    currentTask = NasInstallTask(
      id: plan.id,
      request: plan.request,
      stage: NasInstallStage.succeeded,
      startedAt: plan.createdAt,
      updatedAt: DateTime.now(),
      plan: plan,
      result: result,
      cleanupComplete: true,
    );
    taskController.add(currentTask);
    return result;
  }

  @override
  Future<void> cancel() async {
    cancelCalled = true;
    if (currentTask != null) {
      currentTask = NasInstallTask(
        id: currentTask!.id,
        request: currentTask!.request,
        stage: NasInstallStage.cancelled,
        startedAt: currentTask!.startedAt,
        updatedAt: DateTime.now(),
        cleanupComplete: true,
      );
      taskController.add(currentTask);
    }
    if (installCompleter != null && !installCompleter!.isCompleted) {
      installCompleter!.completeError(Exception('NAS_INSTALL_CANCELLED'));
    }
  }

  @override
  Future<NasInstallTask> reconcile() async {
    reconcileCalled = true;
    if (currentTask != null) {
      currentTask = NasInstallTask(
        id: currentTask!.id,
        request: currentTask!.request,
        stage: NasInstallStage.succeeded,
        startedAt: currentTask!.startedAt,
        updatedAt: DateTime.now(),
        requiresReconciliation: false,
      );
      taskController.add(currentTask);
    }
    return currentTask!;
  }

  @override
  void discard(NasInstallPlan plan) {
    lastDiscardPlan = plan;
    currentTask = null;
    taskController.add(null);
  }
}

final _testServer1 = ServerProfile(
  id: 'srv-1',
  name: 'Primary Server',
  host: '192.168.1.100',
  port: 22,
  username: 'admin',
);

final _testServer2 = ServerProfile(
  id: 'srv-2',
  name: 'Secondary Server',
  host: '192.168.1.101',
  port: 22,
  username: 'admin',
);

class _FakeServerListNotifier extends ServerListNotifier {
  final List<ServerProfile> _servers;
  _FakeServerListNotifier(this._servers);
  @override
  List<ServerProfile> build() => _servers;
}

class _FakeActiveServerNotifier extends ActiveServerNotifier {
  final ServerProfile? _server;
  _FakeActiveServerNotifier(this._server);
  @override
  ServerProfile? build() => _server;
}

Widget _buildTestApp({
  required FakeNasInstallService service,
  List<ServerProfile>? servers,
  ServerProfile? activeServer,
}) {
  return ProviderScope(
    overrides: [
      nasInstallServiceProvider.overrideWith((ref) => service),
      nasInstallTaskProvider.overrideWith((ref) => service.states),
      serverListProvider.overrideWith(
        () => _FakeServerListNotifier(servers ?? [_testServer1, _testServer2]),
      ),
      activeServerProvider.overrideWith(
        () => _FakeActiveServerNotifier(activeServer ?? _testServer1),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open_dialog_button'),
                onPressed: () => NasInstallDialog.show(context),
                child: const Text('Open Dialog'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  group('NasInstallDialog Widget Tests', () {
    testWidgets('strict port range validation rejects out of range values', (
      tester,
    ) async {
      final service = FakeNasInstallService();

      await tester.pumpWidget(_buildTestApp(service: service));
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.byKey(const Key('open_dialog_button')));
      await tester.pumpAndSettle();

      final portField = find.byKey(const Key('nas_install_port_field'));
      expect(portField, findsOneWidget);

      // Enter invalid port: 0
      await tester.enterText(portField, '0');
      await tester.tap(find.byKey(const Key('nas_install_prepare_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Port must be between 1 and 65535').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('nas_install_local_error')).hitTestable(),
        findsOneWidget,
      );
      expect(service.lastPrepareRequest, isNull);

      // Enter invalid port: 70000
      await tester.enterText(portField, '70000');
      await tester.tap(find.byKey(const Key('nas_install_prepare_button')));
      await tester.pumpAndSettle();

      expect(find.text('Port must be between 1 and 65535'), findsOneWidget);
      expect(service.lastPrepareRequest, isNull);

      // Enter invalid port: abc
      await tester.enterText(portField, 'abc');
      await tester.tap(find.byKey(const Key('nas_install_prepare_button')));
      await tester.pumpAndSettle();

      expect(find.text('Port must be between 1 and 65535'), findsOneWidget);
      expect(service.lastPrepareRequest, isNull);

      // Enter valid port: 8096
      await tester.enterText(portField, '8096');
      await tester.tap(find.byKey(const Key('nas_install_prepare_button')));
      await tester.pumpAndSettle();

      expect(service.lastPrepareRequest, isNotNull);
      expect(service.lastPrepareRequest!.port, 8096);
    });

    testWidgets('captures immutable request and moves to plan review view', (
      tester,
    ) async {
      final service = FakeNasInstallService();

      await tester.pumpWidget(_buildTestApp(service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_dialog_button')));
      await tester.pumpAndSettle();

      // Fill form values
      await tester.enterText(
        find.byKey(const Key('nas_install_media_path_field')),
        '/srv/storage/movies',
      );
      await tester.enterText(
        find.byKey(const Key('nas_install_data_root_field')),
        '/var/lib/nas-data/jellyfin',
      );
      await tester.enterText(
        find.byKey(const Key('nas_install_bind_address_field')),
        '0.0.0.0',
      );
      await tester.enterText(
        find.byKey(const Key('nas_install_port_field')),
        '8096',
      );

      // Click Prepare Plan
      await tester.tap(find.byKey(const Key('nas_install_prepare_button')));
      await tester.pumpAndSettle();

      // Verifies captured request
      expect(service.lastPrepareRequest!.mediaPath, '/srv/storage/movies');
      expect(
        service.lastPrepareRequest!.dataRoot,
        '/var/lib/nas-data/jellyfin',
      );
      expect(service.lastPrepareRequest!.bindAddress, '0.0.0.0');
      expect(service.lastPrepareRequest!.port, 8096);
      expect(service.lastPrepareRequest!.serverName, 'Primary Server');

      // Verifies plan review displays explicit details
      expect(find.text('Primary Server'), findsOneWidget);
      expect(find.text('JELLYFIN'), findsOneWidget);
      expect(find.text('jellyfin/jellyfin:10.9.11'), findsOneWidget);
      expect(find.text('/srv/storage/movies'), findsOneWidget);
      expect(find.text('/var/lib/nas-data/jellyfin'), findsOneWidget);
      expect(find.text('0.0.0.0:8096'), findsOneWidget);
      expect(
        find.byKey(const Key('nas_install_compose_preview')),
        findsOneWidget,
      );

      // Confirm install
      final confirmBtn = find.byKey(const Key('nas_install_confirm_button'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(service.lastInstallPlan, isNotNull);
      // Succeeded stage must NOT display rollback cleanup text
      expect(find.text('Rollback cleanup completed'), findsNothing);
      expect(find.text('Rollback cleanup incomplete'), findsNothing);
    });

    testWidgets(
      'plan review shows blockers and disables confirm button when blocked',
      (tester) async {
        final service = FakeNasInstallService();

        final req = NasInstallRequest(
          serverId: 'srv-1',
          serverName: 'Primary Server',
          product: NasInstallProduct.jellyfin,
          mediaPath: '/media',
          dataRoot: '/data',
          bindAddress: '127.0.0.1',
          port: 8096,
        );

        final blockedPlan = FakeNasInstallPlan(
          request: req,
          blockers: [
            'NAS_INSTALL_DOCKER_REQUIRED',
            'NAS_INSTALL_PORT_IN_USE',
            'NAS_INSTALL_IMAGE_UNAVAILABLE',
          ],
        );

        service.currentTask = NasInstallTask(
          id: 'task-blocked',
          request: req,
          stage: NasInstallStage.review,
          startedAt: DateTime.now(),
          updatedAt: DateTime.now(),
          plan: blockedPlan,
        );

        await tester.pumpWidget(_buildTestApp(service: service));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_dialog_button')));
        await tester.pumpAndSettle();

        // Verifies blockers title and blocker texts
        expect(find.text('Deployment Blockers'), findsOneWidget);
        expect(
          find.text('Docker Engine is required on target server'),
          findsOneWidget,
        );
        expect(
          find.text('Selected port is already in use on target server'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Failed to verify container image. Check image name, network connectivity, and server architecture, then retry.',
          ),
          findsOneWidget,
        );

        // Confirm button should be disabled
        final confirmBtn = tester.widget<FilledButton>(
          find.byKey(const Key('nas_install_confirm_button')),
        );
        expect(confirmBtn.onPressed, isNull);

        // Discard button resets to form
        final discardBtn = find.byKey(const Key('nas_install_discard_button'));
        expect(discardBtn, findsOneWidget);
        await tester.tap(discardBtn);
        await tester.pumpAndSettle();

        expect(service.lastDiscardPlan, blockedPlan);
      },
    );

    testWidgets('retains active task across dialog dismiss and reopen', (
      tester,
    ) async {
      final service = FakeNasInstallService();
      final req = NasInstallRequest(
        serverId: 'srv-1',
        serverName: 'Primary Server',
        product: NasInstallProduct.emby,
        mediaPath: '/media',
        dataRoot: '/var/lib/emby',
        bindAddress: '127.0.0.1',
        port: 8096,
      );

      service.currentTask = NasInstallTask(
        id: 'task-active-1',
        request: req,
        stage: NasInstallStage.pulling,
        startedAt: DateTime.now().subtract(const Duration(seconds: 45)),
        updatedAt: DateTime.now(),
        logTail:
            'Pulling library image...\nDigest: sha256:abc\nStatus: Downloaded',
      );

      await tester.pumpWidget(_buildTestApp(service: service));
      await tester.pumpAndSettle();

      // 1. Open dialog
      await tester.tap(find.byKey(const Key('open_dialog_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Observes pulling stage and log tail
      expect(find.text('Pulling Image'), findsOneWidget);
      expect(find.textContaining('Pulling library image...'), findsOneWidget);

      // 2. Dismiss dialog via close icon button
      final closeIconFinder = find.byIcon(Icons.close);
      expect(closeIconFinder, findsOneWidget);
      await tester.tap(closeIconFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog is closed
      expect(find.byKey(const Key('nas_install_dialog')), findsNothing);

      // 3. Reopen dialog
      await tester.tap(find.byKey(const Key('open_dialog_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dialog is visible again and still observing the same active task
      expect(find.byKey(const Key('nas_install_dialog')), findsOneWidget);
      expect(find.text('Pulling Image'), findsOneWidget);
      expect(find.textContaining('Pulling library image...'), findsOneWidget);
    });

    testWidgets('cancel and reconcile actions trigger service methods', (
      tester,
    ) async {
      final service = FakeNasInstallService();
      final req = NasInstallRequest(
        serverId: 'srv-1',
        serverName: 'Primary Server',
        product: NasInstallProduct.jellyfin,
        mediaPath: '/media',
        dataRoot: '/var/lib/jellyfin',
        bindAddress: '127.0.0.1',
        port: 8096,
      );

      // Task in starting stage (canCancel is true)
      service.currentTask = NasInstallTask(
        id: 'task-cancelable',
        request: req,
        stage: NasInstallStage.starting,
        startedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        logTail: 'Starting container...',
      );

      await tester.pumpWidget(_buildTestApp(service: service));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_dialog_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap cancel button
      final cancelBtn = find.byKey(const Key('nas_install_cancel_task_button'));
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(service.cancelCalled, isTrue);

      // Now set task needing reconciliation
      service.currentTask = NasInstallTask(
        id: 'task-interrupted',
        request: req,
        stage: NasInstallStage.needsInspection,
        startedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        requiresReconciliation: true,
        errorCode: 'NAS_INSTALL_INTERRUPTED',
        cleanupComplete: false,
      );
      service.taskController.add(service.currentTask);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Error code and cleanup status are displayed
      expect(find.text('Rollback cleanup incomplete'), findsOneWidget);

      // Tap reconcile button
      final reconcileBtn = find.byKey(
        const Key('nas_install_reconcile_button'),
      );
      expect(reconcileBtn, findsOneWidget);
      await tester.tap(reconcileBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(service.reconcileCalled, isTrue);
    });

    testWidgets(
      'starts deployment and cancels in the same window without closing or reopening',
      (tester) async {
        final service = FakeNasInstallService();

        await tester.pumpWidget(_buildTestApp(service: service));
        await tester.pumpAndSettle();

        // 1. Open dialog and enter valid values
        await tester.tap(find.byKey(const Key('open_dialog_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('nas_install_prepare_button')));
        await tester.pumpAndSettle();

        // 2. Review view is displayed
        expect(
          find.byKey(const Key('nas_install_confirm_button')),
          findsOneWidget,
        );

        // Configure delayed install to simulate real long-running operation
        service.delayInstall = true;

        // 3. Confirm and start install
        await tester.tap(find.byKey(const Key('nas_install_confirm_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // 4. In the SAME window, active task progress is shown while install is in-flight
        expect(find.text('Pulling Image'), findsOneWidget);
        expect(
          find.textContaining('Pulling container image in progress...'),
          findsOneWidget,
        );

        // Cancel button MUST be enabled even while install is in-flight!
        final cancelBtnFinder = find.byKey(
          const Key('nas_install_cancel_task_button'),
        );
        expect(cancelBtnFinder, findsOneWidget);
        expect(
          tester.widget<OutlinedButton>(cancelBtnFinder).onPressed,
          isNotNull,
        );

        // 5. Tap cancel in the same window
        await tester.tap(cancelBtnFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Verify service was cancelled and UI reflects cancellation
        expect(service.cancelCalled, isTrue);
        expect(find.text('Deployment Cancelled'), findsOneWidget);
      },
    );

    testWidgets(
      'real failure-first lifecycle: error displayed, new deployment disabled while reconciliation required, reconcile recovers',
      (tester) async {
        final service = FakeNasInstallService();

        await tester.pumpWidget(_buildTestApp(service: service));
        await tester.pumpAndSettle();

        // 1. Open dialog and prepare plan
        await tester.tap(find.byKey(const Key('open_dialog_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('nas_install_prepare_button')));
        await tester.pumpAndSettle();

        // Configure real failure with NAS_INSTALL_CONNECTION_CHANGED
        service.installErrorCode = 'NAS_INSTALL_CONNECTION_CHANGED';

        // 2. Confirm install -> encounters failure
        await tester.tap(find.byKey(const Key('nas_install_confirm_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // 3. Displays localized blocker error near status
        expect(
          find.text(
            'Target server connection changed; verify remote state before proceeding',
          ),
          findsOneWidget,
        );
        expect(find.text('Rollback cleanup incomplete'), findsOneWidget);

        // 4. New Deployment button is DISABLED while requiresReconciliation is true
        final newDeployBtn = tester.widget<OutlinedButton>(
          find.byKey(const Key('nas_install_new_deployment_button')),
        );
        expect(newDeployBtn.onPressed, isNull);

        // 5. Reconcile button is available
        final reconcileBtn = find.byKey(
          const Key('nas_install_reconcile_button'),
        );
        expect(reconcileBtn, findsOneWidget);
        await tester.tap(reconcileBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(service.reconcileCalled, isTrue);

        // 6. Reconciliation succeeded: New Deployment is now ENABLED
        final newDeployBtnAfter = tester.widget<OutlinedButton>(
          find.byKey(const Key('nas_install_new_deployment_button')),
        );
        expect(newDeployBtnAfter.onPressed, isNotNull);

        // Tapping New Deployment resets to clean form view
        await tester.tap(
          find.byKey(const Key('nas_install_new_deployment_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('nas_install_prepare_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'new deployment button respects combination of requiresReconciliation and stage',
      (tester) async {
        final service = FakeNasInstallService();
        final req = NasInstallRequest(
          serverId: 'srv-1',
          serverName: 'Primary Server',
          product: NasInstallProduct.jellyfin,
          mediaPath: '/media',
          dataRoot: '/data',
          bindAddress: '127.0.0.1',
          port: 8096,
        );

        // Case 1: stage == needsInspection && requiresReconciliation == true
        service.currentTask = NasInstallTask(
          id: 'task-inspect-reconcile-needed',
          request: req,
          stage: NasInstallStage.needsInspection,
          startedAt: DateTime.now(),
          updatedAt: DateTime.now(),
          requiresReconciliation: true,
          errorCode: 'NAS_INSTALL_CONNECTION_CHANGED',
          cleanupComplete: false,
        );

        await tester.pumpWidget(
          _buildTestApp(
            service: service,
            servers: [_testServer1],
            activeServer: _testServer1,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_dialog_button')));
        await tester.pumpAndSettle();

        // 1. Stage and localized blocker error are displayed
        expect(find.text('Requires Inspection'), findsOneWidget);
        expect(
          find.text(
            'Target server connection changed; verify remote state before proceeding',
          ),
          findsOneWidget,
        );
        expect(find.text('Rollback cleanup incomplete'), findsOneWidget);

        // 2. When requiresReconciliation == true, New Deployment button is DISABLED
        var newDeployBtn = tester.widget<OutlinedButton>(
          find.byKey(const Key('nas_install_new_deployment_button')),
        );
        expect(newDeployBtn.onPressed, isNull);

        // Case 2: stage == needsInspection && requiresReconciliation == false
        // (e.g. read-only verification finished cleanly without requiring state reconciliation)
        service.currentTask = NasInstallTask(
          id: 'task-inspect-clean',
          request: req,
          stage: NasInstallStage.needsInspection,
          startedAt: DateTime.now(),
          updatedAt: DateTime.now(),
          requiresReconciliation: false,
          errorCode: 'NAS_INSTALL_CONNECTION_CHANGED',
          cleanupComplete: true,
        );
        service.taskController.add(service.currentTask);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // 3. Inspection warning is preserved
        expect(find.text('Requires Inspection'), findsOneWidget);
        expect(
          find.text(
            'Target server connection changed; verify remote state before proceeding',
          ),
          findsOneWidget,
        );

        // 4. When requiresReconciliation == false, New Deployment button is now ENABLED
        newDeployBtn = tester.widget<OutlinedButton>(
          find.byKey(const Key('nas_install_new_deployment_button')),
        );
        expect(newDeployBtn.onPressed, isNotNull);

        // 5. Tapping New Deployment resets view to clean configuration form
        await tester.tap(
          find.byKey(const Key('nas_install_new_deployment_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('nas_install_prepare_button')),
          findsOneWidget,
        );
      },
    );

    testWidgets('360px logical width with large text scale does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = FakeNasInstallService();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.4),
          ),
          child: _buildTestApp(service: service),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.byKey(const Key('open_dialog_button')));
      await tester.pumpAndSettle();

      // Form view at 360 width
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '360px width with WebDAV and port 0 shows visible hitTestable error without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final service = FakeNasInstallService();

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(360, 640)),
            child: _buildTestApp(service: service),
          ),
        );
        await tester.pumpAndSettle();

        // Open dialog
        await tester.tap(find.byKey(const Key('open_dialog_button')));
        await tester.pumpAndSettle();

        // Switch to WebDAV product
        await tester.tap(find.text('WebDAV'));
        await tester.pumpAndSettle();

        // Fill WebDAV password and invalid port 0
        final passwordField = find.byKey(
          const Key('nas_install_webdav_password_field'),
        );
        expect(passwordField, findsOneWidget);
        await tester.enterText(passwordField, 'secret123456');

        final portField = find.byKey(const Key('nas_install_port_field'));
        expect(portField, findsOneWidget);
        await tester.enterText(portField, '0');

        // Tap prepare button
        final prepareBtn = find.byKey(const Key('nas_install_prepare_button'));
        expect(prepareBtn, findsOneWidget);
        await tester.tap(prepareBtn);
        await tester.pumpAndSettle();

        // Error container and message must be visible on screen and hitTestable
        expect(
          find.byKey(const Key('nas_install_local_error')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.text('Port must be between 1 and 65535').hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
