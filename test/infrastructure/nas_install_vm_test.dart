import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/services/nas_install_service.dart';
import 'package:valhalla/core/utils/shell_quote.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/docker/docker_cli_service.dart';
import 'package:valhalla/infrastructure/nas/nas_http_client.dart';
import 'package:valhalla/infrastructure/nas/nas_ssh_tunnel_service.dart';
import 'package:valhalla/infrastructure/nas/nas_webdav_adapter.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

/// Opt in only against the disposable VM described in the testing guide:
/// VALHALLA_NAS_VM_CREDENTIALS=/tmp/valhalla-test-vm/credentials.json \
///   flutter test test/infrastructure/nas_install_vm_test.dart --reporter expanded
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final credentialsPath = Platform.environment['VALHALLA_NAS_VM_CREDENTIALS'];

  group(
    'real isolated NAS deployment',
    () {
      late SSHClientManager ssh;
      late DockerCliService docker;
      late ServerProfile server;
      late String mediaPath;
      late String rootPrefix;
      late String fixturePassword;
      final runId = DateTime.now().microsecondsSinceEpoch.toString();

      Future<SSHExecutionResult> command(String command) =>
          ssh.executeWithLoginShell(server.id, command);

      NasInstallRequest request(String suffix, NasInstallProduct product) =>
          NasInstallRequest(
            serverId: server.id,
            serverName: server.name,
            product: product,
            mediaPath: mediaPath,
            dataRoot: '$rootPrefix$runId-$suffix',
            port: 18100 + product.index,
          );

      setUpAll(() async {
        final config =
            jsonDecode(await File(credentialsPath!).readAsString())
                as Map<String, dynamic>;
        // Never allow this mutating test to follow an arbitrary server config.
        expect(config['ssh_host'], '127.0.0.1');
        expect(config['ssh_port'], 22023);
        expect(config['ssh_user'], 'valhalla');
        expect(config['machine_id'], isNotEmpty);
        final fingerprints = (config['host_fingerprints'] as List)
            .cast<String>();
        expect(fingerprints, isNotEmpty);
        expect(fingerprints, everyElement(startsWith('SHA256:')));
        mediaPath = config['media_path'] as String;
        rootPrefix = config['data_root_prefix'] as String;
        fixturePassword = config['ssh_password'] as String;
        expect(mediaPath, '/home/valhalla/media');
        expect(rootPrefix, '/home/valhalla/nas-test-');
        SharedPreferences.setMockInitialValues({});
        ssh = SSHClientManager(
          SSHHostKeyVerifier(await LocalStorageService.init()),
        );
        docker = DockerCliService(ssh);
        server = const ServerProfile(
          id: 'isolated-nas-test-vm',
          name: 'valhalla-test-vm',
          host: '127.0.0.1',
          port: 22023,
          username: 'valhalla',
        );
        await ssh.getOrCreateClient(
          server,
          password: config['ssh_password'] as String,
          onConfirmHostKey: (_, _, fingerprint) async =>
              fingerprints.contains(fingerprint),
        );
        final identity = await command(
          'hostname; cat /etc/machine-id; test -e ~/fixture-ready',
        );
        expect(identity.isSuccess, isTrue);
        expect(identity.stdout.trim().split('\n'), [
          'valhalla-test-vm',
          config['machine_id'],
        ]);
      });

      tearDownAll(() => ssh.dispose());

      test(
        'device WebDAV source probes and scans through the actual SSH tunnel',
        () async {
          final previousHttpOverride = HttpOverrides.current;
          HttpOverrides.global = null;
          addTearDown(() => HttpOverrides.global = previousHttpOverride);
          final port = int.parse(
            Platform.environment['VALHALLA_WEBDAV_VM_PORT']!,
          );
          expect(port, 18201);
          final remote = NasSource(
            id: 'device-dav-readonly',
            name: 'Fixture-WebDAV',
            type: NasSourceType.webdav,
            endpoint: 'http://127.0.0.1:$port/',
            rootPath: '/',
            username: 'nas',
            sshServerId: server.id,
          );
          final tunnel = NasSshTunnelService(ssh);
          addTearDown(tunnel.dispose);
          final local = await tunnel.forward(remote);
          final adapter = NasWebDavAdapter(
            NasSource(
              id: remote.id,
              name: remote.name,
              type: remote.type,
              endpoint: local.toString(),
              rootPath: remote.rootPath,
              username: remote.username,
              sshServerId: remote.sshServerId,
              forwardedHost: Uri.parse(remote.endpoint).authority,
            ),
            NasCredentials(password: fixturePassword),
          );
          addTearDown(adapter.dispose);
          await adapter.probe();
          final items =
              (await adapter
                      .scan(
                        const NasScanConfig(includePaths: ['/']),
                        NasCancellation(),
                      )
                      .toList())
                  .expand((batch) => batch)
                  .toList();
          expect(items.map((item) => item.name).toSet(), {
            'Music 60s.mp3',
            'Photo.png',
            'Video 30s.mp4',
          });
          for (final item in items) {
            final resource = await adapter.resolve(item);
            final chunks = await readNasResource(
              resource,
              0,
              32,
              NasCancellation(),
            ).toList();
            expect(chunks.expand((chunk) => chunk).length, 32);
          }
        },
        skip: Platform.environment['VALHALLA_WEBDAV_VM_PORT'] == null
            ? 'Requires the explicit existing device WebDAV fixture port.'
            : false,
        timeout: const Timeout(Duration(minutes: 2)),
      );

      test(
        'read-only reconciliation requires no files or live task processes',
        () async {
          // Represent an interrupted pull whose owned wizard files were removed.
          // No registry access, deployment, or existing device task is involved.
          final target = request('reconcile', NasInstallProduct.jellyfin);
          final id = runId.padRight(48, 'a');
          final project = 'valhalla-nas-${id.substring(0, 12)}';
          final dockerIdentity = await command(
            "docker info --format '{{.ID}}'",
          );
          final machine = await command('cat /etc/machine-id');
          expect(dockerIdentity.isSuccess, isTrue);
          expect(machine.isSuccess, isTrue);
          final retained = '${target.dataRoot}/config/keep.txt';
          expect(
            (await command(
              'mkdir -- ${cliShellQuote(target.dataRoot)} && '
              'mkdir -- ${cliShellQuote('${target.dataRoot}/config')} '
              '${cliShellQuote('${target.dataRoot}/cache')} && '
              'printf retained > ${cliShellQuote(retained)}',
            )).isSuccess,
            isTrue,
          );
          final service = NasInstallService(
            ssh,
            docker,
            recoveredTask: {
              'id': id,
              'serverId': target.serverId,
              'serverName': target.serverName,
              'product': target.product.name,
              'mediaPath': target.mediaPath,
              'dataRoot': target.dataRoot,
              'bindAddress': target.bindAddress,
              'port': target.port,
              'stage': 'needsInspection',
              'interruptedStage': 'pulling',
              'interruptionCode': 'NAS_INSTALL_CANCELLED',
              'targetIdentity':
                  '${machine.stdout.trim()}:${dockerIdentity.stdout.trim()}:fixture',
              'canonicalDataRoot': target.dataRoot,
              'startedAt': DateTime.now().toIso8601String(),
              'cleanupComplete': false,
            },
          );
          addTearDown(service.dispose);
          final ownedFile = '${target.dataRoot}/compose.json';
          expect(
            (await command(
              'printf fixture > ${cliShellQuote(ownedFile)}',
            )).isSuccess,
            isTrue,
          );
          await service.reconcile();
          expect(service.state!.stage, NasInstallStage.needsInspection);
          expect(service.state!.cleanupComplete, isFalse);
          expect(
            (await command('cat -- ${cliShellQuote(ownedFile)}')).stdout,
            'fixture',
          );
          expect(
            (await command('rm -- ${cliShellQuote(ownedFile)}')).isSuccess,
            isTrue,
          );
          expect(
            (await command(
              'chmod 600 -- ${cliShellQuote(target.dataRoot)}',
            )).isSuccess,
            isTrue,
          );
          try {
            await service.reconcile();
            expect(service.state!.stage, NasInstallStage.needsInspection);
            expect(service.state!.cleanupComplete, isFalse);
          } finally {
            expect(
              (await command(
                'chmod 700 -- ${cliShellQuote(target.dataRoot)}',
              )).isSuccess,
              isTrue,
            );
          }
          // Put each marker beyond ordinary ps column widths; never truncate it.
          for (final marker in [project, target.dataRoot]) {
            final child =
                'exec -a ${cliShellQuote('${'x' * 512}$marker')} sleep 90';
            final spawned = await command(
              'nohup bash -c ${cliShellQuote(child)} </dev/null >/dev/null 2>&1 & echo \$!',
            );
            expect(spawned.isSuccess, isTrue);
            final pid = int.parse(spawned.stdout.trim());
            try {
              await service.reconcile();
              expect(service.state!.stage, NasInstallStage.needsInspection);
              expect(service.state!.cleanupComplete, isFalse);
            } finally {
              final process = await command('ps -ww -p $pid -o args=');
              expect(process.stdout, contains(marker));
              expect((await command('kill -TERM -- $pid')).isSuccess, isTrue);
            }
          }
          await service.reconcile();
          expect(service.state!.stage, NasInstallStage.cancelled);
          expect(service.state!.cleanupComplete, isTrue);
          expect(service.state!.requiresReconciliation, isFalse);
          expect(
            (await command('cat -- ${cliShellQuote(retained)}')).stdout,
            'retained',
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );

      test(
        'existing directory is reported and never modified',
        () async {
          final service = NasInstallService(ssh, docker);
          addTearDown(service.dispose);
          final target = request('collision', NasInstallProduct.webdav);
          final marker = '${target.dataRoot}/keep.txt';
          expect(
            (await command(
              'mkdir -- ${cliShellQuote(target.dataRoot)} && '
              'printf keep > ${cliShellQuote(marker)}',
            )).isSuccess,
            isTrue,
          );
          final plan = await service.prepare(
            target,
            webdavPassword: 'isolated-fixture-password',
          );
          expect(plan.blockers, contains('NAS_INSTALL_DIRECTORY_COLLISION'));
          await expectLater(
            service.install(plan, confirmationToken: plan.confirmationToken),
            throwsA(
              isA<NasInstallException>().having(
                (e) => e.code,
                'code',
                'NAS_INSTALL_CONFIRMATION_REQUIRED',
              ),
            ),
          );
          expect(
            (await command('cat -- ${cliShellQuote(marker)}')).stdout,
            'keep',
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );

      test(
        'active pull cancellation returns a visible terminal outcome',
        () async {
          final service = NasInstallService(ssh, docker);
          addTearDown(service.dispose);
          Timer? cancellation;
          final stages = <NasInstallStage>[];
          final subscription = service.states.listen((state) {
            if (state == null) return;
            stages.add(state.stage);
            if (state.stage == NasInstallStage.pulling &&
                state.logTail.toLowerCase().contains('pulling') &&
                cancellation == null) {
              cancellation = Timer(const Duration(milliseconds: 500), () {
                unawaited(service.cancel());
              });
            }
          });
          addTearDown(() async {
            cancellation?.cancel();
            await subscription.cancel();
          });
          final plan = await service.prepare(
            request('cancel', NasInstallProduct.webdav),
            webdavPassword: 'isolated-fixture-password',
          );
          expect(plan.blockers, isEmpty);
          await expectLater(
            service.install(plan, confirmationToken: plan.confirmationToken),
            throwsA(
              isA<NasInstallException>().having(
                (e) => e.code,
                'code',
                'NAS_INSTALL_CANCELLED',
              ),
            ),
          );
          expect(stages, contains(NasInstallStage.pulling));
          expect(service.state!.isBusy, isFalse);
          expect(
            service.state!.stage,
            anyOf(NasInstallStage.cancelled, NasInstallStage.needsInspection),
          );
          expect(
            service.state!.logTail,
            isNot(contains('isolated-fixture-password')),
          );
          if (service.state!.requiresReconciliation) {
            await service.reconcile();
            expect(service.state!.isBusy, isFalse);
          }
          expect(
            (await docker.listContainers(
              server.id,
            )).where((container) => container.name == plan.containerName),
            isEmpty,
          );
          expect(
            (await command('test -d ${cliShellQuote(mediaPath)}')).isSuccess,
            isTrue,
          );
        },
        timeout: const Timeout(Duration(minutes: 5)),
      );

      test(
        'start failure preserves a foreign container created after review',
        () async {
          String? foreignContainerId;
          final service = NasInstallService(
            ssh,
            docker,
            persistTask: (summary) async {
              if (summary['stage'] == NasInstallStage.pulling.name &&
                  foreignContainerId == null) {
                final name =
                    'valhalla-nas-${(summary['id'] as String).substring(0, 12)}';
                final created = await command(
                  'docker create --name ${cliShellQuote(name)} '
                  '--label valhalla.fixture=true busybox:1.37.0 true',
                );
                expect(created.isSuccess, isTrue);
                foreignContainerId = created.stdout.trim();
              }
            },
          );
          addTearDown(() async {
            service.dispose();
            final containerId = foreignContainerId;
            if (containerId != null) {
              expect(
                (await docker.lifecycle(
                  server.id,
                  'rm',
                  containerId,
                )).isSuccess,
                isTrue,
              );
            }
          });
          final plan = await service.prepare(
            request('foreign-container', NasInstallProduct.webdav),
            webdavPassword: 'isolated-fixture-password',
          );
          expect(plan.blockers, isEmpty);
          await expectLater(
            service.install(plan, confirmationToken: plan.confirmationToken),
            throwsA(
              isA<NasInstallException>().having(
                (e) => e.code,
                'code',
                'NAS_INSTALL_START_FAILED',
              ),
            ),
          );
          expect(service.state!.stage, NasInstallStage.needsInspection);
          expect(service.state!.cleanupComplete, isFalse);
          final foreign = await docker.inspect(server.id, foreignContainerId!);
          expect(
            ((foreign['Config'] as Map)['Labels'] as Map)['valhalla.fixture'],
            'true',
          );
          expect(
            (await command('test -d ${cliShellQuote(mediaPath)}')).isSuccess,
            isTrue,
          );
        },
        timeout: const Timeout(Duration(minutes: 15)),
      );

      for (final product in NasInstallProduct.values) {
        test(
          '${product.name} installs and reconciles a persisted health stage',
          () async {
            Map<String, dynamic>? healthSummary;
            final stages = <NasInstallStage>[];
            final service = NasInstallService(
              ssh,
              docker,
              persistTask: (summary) async {
                expect(summary.keys, isNot(contains('password')));
                if (summary['stage'] == NasInstallStage.health.name) {
                  healthSummary = Map.of(summary);
                }
              },
            );
            addTearDown(service.dispose);
            final subscription = service.states.listen((state) {
              if (state == null || stages.lastOrNull == state.stage) return;
              stages.add(state.stage);
              // Only non-secret phase names are printed to the acceptance log.
              // ignore: avoid_print
              print('VM ${product.name}: ${state.stage.name}');
            });
            addTearDown(subscription.cancel);
            final plan = await service.prepare(
              request(product.name, product),
              webdavPassword: product == NasInstallProduct.webdav
                  ? 'isolated-fixture-password'
                  : null,
            );
            expect(plan.blockers, isEmpty);
            final imageExisted = (await command(
              'docker image inspect ${cliShellQuote(plan.pinnedImage)} >/dev/null 2>&1',
            )).isSuccess;
            addTearDown(() async {
              final matching = (await docker.listContainers(
                server.id,
              )).where((container) => container.name == plan.containerName);
              for (final container in matching) {
                final inspected = await docker.inspect(server.id, container.id);
                final labels = (inspected['Config'] as Map)['Labels'] as Map;
                expect(labels['com.valhalla.nas.install'], plan.id);
                await docker.lifecycle(server.id, 'stop', container.id);
                expect(
                  (await docker.lifecycle(
                    server.id,
                    'rm',
                    container.id,
                  )).isSuccess,
                  isTrue,
                );
              }
              // Keep VM disk usage bounded between the three large products.
              // Existing images and images used by another test are preserved.
              if (!imageExisted) {
                await command(
                  'docker image rm ${cliShellQuote(plan.pinnedImage)}',
                );
              }
              await command('sudo -n fstrim /');
            });
            final result = await service.install(
              plan,
              confirmationToken: plan.confirmationToken,
            );
            expect(result.healthy, isTrue);
            expect(service.state!.stage, NasInstallStage.succeeded);
            if (product == NasInstallProduct.emby) {
              final api = result.endpoint.replace(path: '/System/Info/Public');
              final info = await command(
                "curl --noproxy '*' --fail --silent --max-time 10 ${cliShellQuote(api.toString())}",
              );
              expect(info.isSuccess, isTrue);
              expect((jsonDecode(info.stdout) as Map)['Version'], '4.10.0.40');
            }
            if (product == NasInstallProduct.webdav) {
              final authConfig =
                  'printf \'user = "%s:%s"\\n\' '
                  '"\$(cat -- ${cliShellQuote('${plan.request.dataRoot}/webdav-user')})" '
                  '"\$(cat -- ${cliShellQuote('${plan.request.dataRoot}/webdav-password')})"';
              final photo = result.endpoint.replace(path: '/Photo.png');
              final fetched = await command(
                '$authConfig | curl --config - --noproxy \'*\' --fail '
                '--silent --output /dev/null --write-out \'%{http_code}\' '
                '${cliShellQuote(photo.toString())}',
              );
              expect(fetched.isSuccess, isTrue);
              expect(fetched.stdout.trim(), '200');
            }
            expect(
              stages,
              containsAllInOrder([
                NasInstallStage.preflight,
                NasInstallStage.review,
                NasInstallStage.writing,
                NasInstallStage.pulling,
                NasInstallStage.starting,
                NasInstallStage.health,
              ]),
            );
            expect(healthSummary, isNotNull);
            final recovered = NasInstallService(
              ssh,
              docker,
              recoveredTask: healthSummary,
            );
            addTearDown(recovered.dispose);
            expect(recovered.state!.requiresReconciliation, isTrue);
            await recovered.reconcile();
            expect(recovered.state!.stage, NasInstallStage.succeeded);
            expect(recovered.state!.result!.containerId, result.containerId);
            final inspected = await docker.inspect(
              server.id,
              result.containerId,
            );
            final mounts = (inspected['Mounts'] as List).cast<Map>();
            expect(
              mounts.singleWhere(
                (mount) => mount['Destination'] == '/media',
              )['RW'],
              isFalse,
            );
            final labels = (inspected['Config'] as Map)['Labels'] as Map;
            expect(labels['com.valhalla.nas.install'], plan.id);
          },
          timeout: const Timeout(Duration(minutes: 18)),
        );
      }
    },
    skip: credentialsPath == null
        ? 'Requires explicit disposable VM credentials; never runs on user servers.'
        : false,
  );
}
