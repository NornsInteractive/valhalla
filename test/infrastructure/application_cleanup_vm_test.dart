import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/services/application_compose_service.dart';
import 'package:valhalla/core/services/application_deployment_service.dart';
import 'package:valhalla/core/utils/shell_quote.dart';
import 'package:valhalla/data/models/application_center.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final credentialsPath =
      Platform.environment['VALHALLA_APP_CENTER_VM_CREDENTIALS'];
  final enabled = Platform.environment['VALHALLA_CLEANUP_VM'] == '1';

  for (final mode in ['child', 'root', 'advanced']) {
    final wholeRoot = mode == 'root';
    final advanced = mode == 'advanced';
    test(
      'pinned VM: ${advanced
          ? 'approved shared path and Docker volume'
          : wholeRoot
          ? 'whole dataRoot'
          : 'child-only'} uninstall of new fixture',
      () async {
        const machineId = '3579bace85be432fa7cde6da46ad839b';
        const hostFingerprint =
            'SHA256:j0JCpHOOGNJlL2UDKj5nQnFSJlePw63tPE8Yo4MINtM';
        final credentials =
            jsonDecode(await File(credentialsPath!).readAsString())
                as Map<String, dynamic>;
        expect(credentials['ssh_host'], '127.0.0.1');
        expect(credentials['ssh_port'], 22023);
        expect(credentials['ssh_user'], 'valhalla');
        expect(credentials['machine_id'], machineId);
        expect(credentials['host_fingerprints'], contains(hostFingerprint));
        SharedPreferences.setMockInitialValues({});
        final storage = await LocalStorageService.init();
        final ssh = SSHClientManager(SSHHostKeyVerifier(storage));
        const server = ServerProfile(
          id: 'isolated-cleanup-vm',
          name: 'valhalla-test-vm',
          host: '127.0.0.1',
          port: 22023,
          username: 'valhalla',
        );
        ApplicationDeployment? createdApp;
        addTearDown(() async {
          try {
            final app = createdApp;
            if (app != null && ssh.isConnected(server.id)) {
              // Only this random owned project's containers/network may be
              // removed. Bind data, named volumes and old fixtures are retained.
              final result = await ssh.executeWithLoginShell(
                server.id,
                'if test -e ${cliShellQuote('${app.directory}/.valhalla-app-owner')}; then '
                'test ! -L ${cliShellQuote(app.directory)} && '
                'test ! -L ${cliShellQuote('${app.directory}/.valhalla-app-owner')} && '
                'test "\$(realpath -- ${cliShellQuote(app.directory)})" = ${cliShellQuote(app.directory)} && '
                'test "\$(cat -- ${cliShellQuote('${app.directory}/.valhalla-app-owner')})" = ${cliShellQuote(app.id)} && '
                'docker compose --project-name ${cliShellQuote(app.project)} '
                '-f ${cliShellQuote('${app.directory}/compose.json')} down --timeout 20; fi',
                timeout: const Duration(seconds: 90),
              );
              expect(result.isSuccess, isTrue, reason: result.stderr);
            }
          } finally {
            ssh.dispose();
          }
        });

        await ssh.getOrCreateClient(
          server,
          password: credentials['ssh_password'] as String,
          onConfirmHostKey: (_, _, fingerprint) async =>
              fingerprint == hostFingerprint,
        );
        final identity = await ssh.executeWithLoginShell(
          server.id,
          'hostname; cat /etc/machine-id; test -e /home/valhalla/fixture-ready',
        );
        expect(identity.isSuccess, isTrue);
        expect(identity.stdout.trim().split('\n'), [
          'valhalla-test-vm',
          machineId,
        ]);

        final service = ApplicationDeploymentService(ssh);
        final environment = await service.inspect(server);
        expect(
          environment.ready,
          isTrue,
          reason: environment.blockers.join(', '),
        );
        expect(environment.home, '/home/valhalla');
        final cachedImage = await ssh.executeWithLoginShell(
          server.id,
          'docker image inspect nginx:alpine --format \'{{.Id}}\'',
        );
        expect(
          cachedImage.isSuccess,
          isTrue,
          reason: 'Requires existing VM nginx fixture image',
        );
        expect(cachedImage.stdout.trim(), startsWith('sha256:'));

        final id = ApplicationDeploymentService.newId();
        expect(id, matches(RegExp(r'^[a-f0-9]{32}$')));
        final template = ApplicationTemplate(
          application: CatalogApplication(
            sourceId: 'fixture',
            id: 'selective-cleanup-$id',
            title: 'Selective cleanup $id',
            version: '1',
            contentHash: 'selective-cleanup-v1',
            composeUrl: '',
          ),
          compose: {
            'services': {
              'web': {
                'image': 'nginx:alpine',
                'volumes': [
                  '/DATA/AppData/fixture/selected:/fixture-selected',
                  '/DATA/AppData/fixture/kept:/fixture-kept',
                  'fixture-cache:/var/cache/nginx',
                ],
              },
            },
            'volumes': {'fixture-cache': <String, dynamic>{}},
          },
          metadata: const {},
        );
        final config = ApplicationComposeService.defaults(
          template,
          environment,
          id,
        );
        final root = '/home/valhalla/.local/share/valhalla/apps/$id';
        final selectedPath = '$root/selected';
        final keptPath = '$root/kept';
        // ignore: avoid_print
        print('cleanup VM fixture id=$id root=$root');
        expect(config.dataRoot, root);
        expect(config.mounts.map((mount) => mount.source).toSet(), {
          selectedPath,
          keptPath,
        });
        final absent = await ssh.executeWithLoginShell(
          server.id,
          'test ! -e ${cliShellQuote(root)} && test ! -L ${cliShellQuote(root)}',
        );
        expect(
          absent.isSuccess,
          isTrue,
          reason: 'Never reuse a previous fixture root',
        );

        final intents = <String, ApplicationTask>{};
        Future<ApplicationTask> execute(ApplicationOperationPlan plan) async {
          final task = await service.execute(
            plan,
            persistBeforeLaunch: (intent) async {
              intents[intent.id] = intent;
              await storage.saveApplicationCenterRecords(
                'tasks',
                intent.serverKey,
                intents.values.map((item) => item.toJson()).toList(),
              );
            },
          );
          // ignore: avoid_print
          print('cleanup VM ${plan.operation.name} task=${task.id}');
          expect(intents, contains(task.id));
          final deadline = DateTime.now().add(const Duration(minutes: 3));
          while (true) {
            final latest = await service.readTask(task);
            if (!latest.isBusy) {
              expect(
                latest.stage,
                ApplicationTaskStage.succeeded,
                reason:
                    '${plan.operation.name}: ${latest.stage.name}\n${latest.logTail}',
              );
              expect(latest.exitCode, 0);
              return latest;
            }
            expect(
              DateTime.now().isBefore(deadline),
              isTrue,
              reason: '${plan.operation.name} timed out: ${latest.logTail}',
            );
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
        }

        final install = await service.prepare(
          server,
          environment,
          ApplicationOperation.install,
          template: template,
          configuration: config,
        );
        createdApp = install.deployment;
        expect(createdApp.id, id);
        await execute(install);
        expect(
          (await service.reconcile(createdApp, environment))!.status,
          'running',
        );
        final volume = '${createdApp.project}_fixture-cache';
        final volumeBefore = await ssh.executeWithLoginShell(
          server.id,
          'docker volume inspect --format \'{{.Name}}|{{.Mountpoint}}\' ${cliShellQuote(volume)}',
        );
        expect(volumeBefore.isSuccess, isTrue);
        // ignore: avoid_print
        print(
          'cleanup VM project=${createdApp.project} name=${config.name} '
          'volume=$volume control=${createdApp.directory}',
        );

        final sentinels = [
          '$selectedPath/selected-sentinel',
          '$keptPath/kept-sentinel',
          '$root/root-sentinel',
        ];
        final verifyNewPaths = [
          for (final item in [root, selectedPath, keptPath])
            'test -d ${cliShellQuote(item)} && test ! -L ${cliShellQuote(item)} && '
                'test "\$(realpath -- ${cliShellQuote(item)})" = ${cliShellQuote(item)}',
        ].join(' && ');
        final seed = await ssh.executeWithLoginShell(
          server.id,
          '$verifyNewPaths && '
          '${sentinels.map((item) => "printf '%s' ${cliShellQuote(id)} > ${cliShellQuote(item)}").join(' && ')}',
        );
        expect(seed.isSuccess, isTrue);

        // An unmounted protected descendant must protect its ancestor too.
        final protectedPath = '$root/unmounted/.ssh';
        final seedProtected = await ssh.executeWithLoginShell(
          server.id,
          'test ! -e ${cliShellQuote('$root/unmounted')} && '
          'mkdir -p -- ${cliShellQuote(protectedPath)} && '
          'printf %s ${cliShellQuote(id)} > ${cliShellQuote('$protectedPath/sentinel')}',
        );
        expect(seedProtected.isSuccess, isTrue);
        final protectedPreview = await service.inspectUninstall(
          createdApp,
          environment,
        );
        final protectedRoot = protectedPreview.targets.singleWhere(
          (target) => target.source == root,
        );
        expect(protectedRoot.selectable, isFalse);
        expect(
          protectedRoot.blockedReason,
          'APP_CENTER_CLEANUP_PROTECTED_PATH',
        );
        final removeProtectedFixture = await ssh.executeWithLoginShell(
          server.id,
          'test ! -L ${cliShellQuote(protectedPath)} && '
          'test "\$(cat -- ${cliShellQuote('$protectedPath/sentinel')})" = ${cliShellQuote(id)} && '
          'rm -- ${cliShellQuote('$protectedPath/sentinel')} && '
          'rmdir -- ${cliShellQuote(protectedPath)} ${cliShellQuote('$root/unmounted')}',
        );
        expect(removeProtectedFixture.isSuccess, isTrue);

        // A stopped unrelated container sharing this test bind blocks both the
        // child and its whole-root ancestor, without touching any existing app.
        final sharedName = 'acceptance-shared-${id.substring(0, 12)}';
        var sharedCreated = false;
        addTearDown(() async {
          if (sharedCreated && ssh.isConnected(server.id)) {
            final removed = await ssh.executeWithLoginShell(
              server.id,
              'test "\$(docker inspect --format \'{{index .Config.Labels "acceptance.fixture"}}\' ${cliShellQuote(sharedName)})" = ${cliShellQuote(id)} && '
              'docker rm ${cliShellQuote(sharedName)}',
            );
            expect(removed.isSuccess, isTrue, reason: removed.stderr);
          }
        });
        final sharedCreate = await ssh.executeWithLoginShell(
          server.id,
          'docker create --name ${cliShellQuote(sharedName)} '
          '--label ${cliShellQuote('acceptance.fixture=$id')} '
          '--mount ${cliShellQuote('type=bind,source=${advanced ? selectedPath : keptPath},target=/shared')} nginx:alpine',
        );
        expect(sharedCreate.isSuccess, isTrue, reason: sharedCreate.stderr);
        sharedCreated = true;
        final sharedPreview = await service.inspectUninstall(
          createdApp,
          environment,
        );
        for (final target in sharedPreview.targets.where(
          (item) =>
              [root, advanced ? selectedPath : keptPath].contains(item.source),
        )) {
          expect(target.selectable, isFalse);
          expect(target.blockedReason, 'APP_CENTER_CLEANUP_SHARED_PATH');
        }
        final sharedRemove = await ssh.executeWithLoginShell(
          server.id,
          'test "\$(docker inspect --format \'{{index .Config.Labels "acceptance.fixture"}}\' ${cliShellQuote(sharedName)})" = ${cliShellQuote(id)} && '
          '${advanced ? 'true' : 'docker rm ${cliShellQuote(sharedName)}'}',
        );
        expect(sharedRemove.isSuccess, isTrue, reason: sharedRemove.stderr);
        sharedCreated = advanced;
        // ignore: avoid_print
        print(
          'cleanup VM ${advanced ? 'kept' : 'removed'} stopped shared fixture=$sharedName removed protected fixture=$protectedPath',
        );

        final preview = await service.inspectUninstall(
          createdApp,
          environment,
          allowAdvancedCleanup: advanced,
        );
        expect(preview.inspectionError, isNull);
        final selected = preview.targets.singleWhere(
          (target) => target.source == selectedPath,
        );
        final kept = preview.targets.singleWhere(
          (target) => target.source == keptPath,
        );
        final dataRoot = preview.targets.singleWhere(
          (target) => target.source == root,
        );
        expect(dataRoot.isDataRoot, isTrue);
        expect(dataRoot.selectable, isTrue, reason: dataRoot.blockedReason);
        expect(selected.selectable, isTrue, reason: selected.blockedReason);
        expect(kept.selectable, isTrue, reason: kept.blockedReason);
        final volumeTarget = preview.targets.singleWhere(
          (target) => target.source == volume,
        );
        expect(volumeTarget.kind, 'volume');
        expect(volumeTarget.selectable, advanced);
        if (advanced) {
          expect(preview.allowAdvancedCleanup, isTrue);
          expect(selected.risks, contains('shared'));
          expect(selected.references, isNotEmpty);
          expect(volumeTarget.risks, contains('volume'));
        } else {
          expect(
            preview.targets
                .where(
                  (target) =>
                      ![root, selectedPath, keptPath].contains(target.source),
                )
                .every((target) => !target.selectable),
            isTrue,
          );
        }
        final stillIntact = await ssh.executeWithLoginShell(
          server.id,
          sentinels
              .map(
                (item) =>
                    'test "\$(cat -- ${cliShellQuote(item)})" = ${cliShellQuote(id)}',
              )
              .join(' && '),
        );
        expect(
          stillIntact.isSuccess,
          isTrue,
          reason: 'Inspection must never delete data',
        );

        final selectedTargets = advanced
            ? [selected, volumeTarget]
            : wholeRoot
            ? [dataRoot, selected, kept]
            : [selected];
        final selectedSources = advanced
            ? [selectedPath, volume]
            : wholeRoot
            ? [root]
            : [selectedPath];
        final selection = ApplicationUninstallSelection(
          previewId: preview.id,
          confirmationName: createdApp.name,
          selectedKeys: selectedTargets.map((target) => target.key).toSet(),
          acknowledgedRiskKeys: selectedTargets
              .where((target) => target.requiresRiskAcknowledgement)
              .map((target) => target.key)
              .toSet(),
        );
        final uninstall = await service.prepare(
          server,
          environment,
          ApplicationOperation.uninstall,
          deployment: createdApp,
          uninstallSelection: selection,
        );
        expect(
          uninstall.cleanupPlan!.targets.map((target) => target.source),
          selectedSources,
        );
        final outcome = await execute(uninstall);
        expect(outcome.uninstallCompleted, isTrue);
        expect(outcome.cleanupResults, hasLength(advanced ? 2 : 1));
        if (advanced) {
          expect(
            outcome.cleanupResults.every(
              (result) => result.outcome == ApplicationCleanupOutcome.removed,
            ),
            isTrue,
          );
          final sharedStillPresent = await ssh.executeWithLoginShell(
            server.id,
            'docker inspect --format \'{{index .Config.Labels "acceptance.fixture"}}\' ${cliShellQuote(sharedName)}',
          );
          expect(sharedStillPresent.isSuccess, isTrue);
          expect(sharedStillPresent.stdout.trim(), id);
        } else {
          expect(
            outcome.cleanupResults.single.key,
            wholeRoot ? dataRoot.key : selected.key,
          );
          expect(
            outcome.cleanupResults.single.source,
            wholeRoot ? root : selectedPath,
          );
          expect(
            outcome.cleanupResults.single.outcome,
            ApplicationCleanupOutcome.removed,
          );
        }
        final preserved = await ssh.executeWithLoginShell(
          server.id,
          wholeRoot
              ? 'test ! -e ${cliShellQuote(root)} && test ! -L ${cliShellQuote(root)}'
              : 'test ! -e ${cliShellQuote(selectedPath)} && test ! -L ${cliShellQuote(selectedPath)} && '
                    'test "\$(cat -- ${cliShellQuote('$keptPath/kept-sentinel')})" = ${cliShellQuote(id)} && '
                    'test "\$(cat -- ${cliShellQuote('$root/root-sentinel')})" = ${cliShellQuote(id)}',
        );
        expect(preserved.isSuccess, isTrue);
        final volumeAfter = await ssh.executeWithLoginShell(
          server.id,
          'docker volume inspect --format \'{{.Name}}|{{.Mountpoint}}\' ${cliShellQuote(volume)}',
        );
        expect(volumeAfter.isSuccess, !advanced);
        if (!advanced) expect(volumeAfter.stdout, volumeBefore.stdout);
        expect(await service.reconcile(createdApp, environment), isNull);
        // ignore: avoid_print
        print(
          'cleanup VM removed paths=${selectedSources.join(',')} '
          'container=${config.name} network=${createdApp.project}_default; '
          '${advanced ? 'removed' : 'retained'} named volume=$volume control=${createdApp.directory} '
          '${wholeRoot ? '' : 'and kept=$keptPath root-sentinel=$root/root-sentinel'}',
        );
      },
      skip: credentialsPath == null || !enabled
          ? 'Requires explicitly opted-in pinned disposable cleanup VM'
          : false,
      timeout: const Timeout(Duration(minutes: 8)),
    );
  }
}
