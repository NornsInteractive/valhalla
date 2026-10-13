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
import '../support/application_paths_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final credentialsPath =
      Platform.environment['VALHALLA_APP_CENTER_VM_CREDENTIALS'];
  const pinnedMachineId = '3579bace85be432fa7cde6da46ad839b';
  const pinnedFingerprint =
      'SHA256:j0JCpHOOGNJlL2UDKj5nQnFSJlePw63tPE8Yo4MINtM';
  test(
    'pinned VM: read-only identity gate',
    () async {
      final credentials =
          jsonDecode(await File(credentialsPath!).readAsString())
              as Map<String, dynamic>;
      expect(credentials['ssh_host'], '127.0.0.1');
      expect(credentials['ssh_port'], 22023);
      expect(credentials['ssh_user'], 'valhalla');
      expect(credentials['machine_id'], pinnedMachineId);
      expect(credentials['host_fingerprints'], contains(pinnedFingerprint));
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      final ssh = SSHClientManager(SSHHostKeyVerifier(storage));
      addTearDown(ssh.dispose);
      const server = ServerProfile(
        id: 'isolated-readonly-vm',
        name: 'valhalla-test-vm',
        host: '127.0.0.1',
        port: 22023,
        username: 'valhalla',
      );
      var observed = '';
      await ssh.getOrCreateClient(
        server,
        password: credentials['ssh_password'] as String,
        onConfirmHostKey: (_, _, fingerprint) async {
          observed = fingerprint;
          return fingerprint == pinnedFingerprint;
        },
      );
      expect(observed, pinnedFingerprint);
      final identity = await ssh.executeWithLoginShell(
        server.id,
        'hostname; cat /etc/machine-id; test -e /home/valhalla/fixture-ready',
      );
      expect(identity.isSuccess, isTrue);
      expect(identity.stdout.trim().split('\n'), [
        'valhalla-test-vm',
        pinnedMachineId,
      ]);
      // ignore: avoid_print
      print(
        'VM read-only pin verified machine=$pinnedMachineId hostkey=$observed',
      );
    },
    skip: credentialsPath == null ? 'Requires the pinned disposable VM' : false,
  );
  test(
    'pinned VM: actual deployment, private config, reconnect, update, restore, data-preserving uninstall',
    () async {
      final credentials =
          jsonDecode(await File(credentialsPath!).readAsString())
              as Map<String, dynamic>;
      expect(credentials['ssh_host'], '127.0.0.1');
      expect(credentials['ssh_port'], 22023);
      expect(credentials['ssh_user'], 'valhalla');
      expect(credentials['machine_id'], pinnedMachineId);
      expect(credentials['host_fingerprints'], contains(pinnedFingerprint));
      SharedPreferences.setMockInitialValues({});
      final storage = await LocalStorageService.init();
      var ssh = SSHClientManager(SSHHostKeyVerifier(storage));
      const server = ServerProfile(
        id: 'isolated-center-vm',
        name: 'valhalla-test-vm',
        host: '127.0.0.1',
        port: 22023,
        username: 'valhalla',
      );
      Future<void> connect() async {
        await ssh.getOrCreateClient(
          server,
          password: credentials['ssh_password'] as String,
          onConfirmHostKey: (_, _, fingerprint) async =>
              fingerprint == pinnedFingerprint,
        );
        final identity = await ssh.executeWithLoginShell(
          server.id,
          'hostname; cat /etc/machine-id; test -e ~/fixture-ready',
        );
        expect(identity.isSuccess, true);
        expect(identity.stdout.trim().split('\n'), [
          'valhalla-test-vm',
          pinnedMachineId,
        ]);
      }

      await connect();
      var service = ApplicationDeploymentService(ssh);
      var env = await service.inspect(server);
      expect(env.ready, true, reason: env.blockers.join(', '));
      // Preview the reported app against real SSH/Docker without installing it.
      final npmId = ApplicationDeploymentService.newId();
      final npmDefault = ApplicationComposeService.defaults(
        nginxProxyTemplate,
        env,
        npmId,
      );
      final npmInput = npmDefault.copyWith(
        name: 'acceptance-npm-${npmId.substring(0, 12)}',
        dataRoot: '${npmDefault.dataRoot}/',
        ports: [
          for (var i = 0; i < npmDefault.ports.length; i++)
            ApplicationPort(
              service: npmDefault.ports[i].service,
              target: npmDefault.ports[i].target,
              published: 18121 + i,
              bindAddress: npmDefault.ports[i].target == 81
                  ? '127.0.0.1'
                  : '0.0.0.0',
            ),
        ],
        mounts: [
          for (final m in npmDefault.mounts)
            ApplicationMount(
              service: m.service,
              source: '${m.source}/',
              target: m.target,
              readOnly: m.readOnly,
            ),
        ],
      );
      final absentBefore = await ssh.executeWithLoginShell(
        server.id,
        'test ! -e ${cliShellQuote(npmDefault.dataRoot)}',
      );
      expect(absentBefore.isSuccess, true);
      final npmPlan = await service.prepare(
        server,
        env,
        ApplicationOperation.install,
        template: nginxProxyTemplate,
        configuration: npmInput,
      );
      expect(npmPlan.configuration!.dataRoot, npmDefault.dataRoot);
      final npmVolumes =
          (jsonDecode(npmPlan.composeJson)
                  as Map)['services']['nginxproxymanager']['volumes']
              as List;
      expect(npmVolumes.map((v) => v['source']), [
        '${npmDefault.dataRoot}/data',
        '${npmDefault.dataRoot}/etc/letsencrypt',
      ]);
      expect(npmVolumes.map((v) => v['target']), ['/data', '/etc/letsencrypt']);
      final npmPorts =
          (jsonDecode(npmPlan.composeJson)
                  as Map)['services']['nginxproxymanager']['ports']
              as List;
      expect(
        npmPorts.singleWhere((port) => port['target'] == 81)['host_ip'],
        '127.0.0.1',
      );
      expect(
        npmPorts
            .where((port) => port['target'] != 81)
            .every((port) => port['host_ip'] == '0.0.0.0'),
        true,
      );
      final absentAfter = await ssh.executeWithLoginShell(
        server.id,
        'test ! -e ${cliShellQuote(npmDefault.dataRoot)}',
      );
      expect(absentAfter.isSuccess, true);
      final id = ApplicationDeploymentService.newId();
      final fixtureName = 'acceptance-${id.substring(0, 12)}';
      final localPort =
          20000 + int.parse(id.substring(0, 4), radix: 16) % 10000;
      final publicPort = localPort + 1;
      final template = ApplicationTemplate(
        application: const CatalogApplication(
          sourceId: 'fixture',
          id: 'nginx',
          title: 'Fixture',
          version: '1',
          contentHash: 'v1',
          composeUrl: '',
        ),
        compose: {
          'x-casaos': {'main': 'web'},
          'services': {
            'web': {
              'image': 'nginx:alpine',
              'container_name': 'original-web',
              'labels': {'acceptance.fixture': id},
              'networks': {
                'fixture': {
                  'aliases': ['existing-web-alias'],
                },
              },
              'ports': ['$localPort:80'],
              'volumes': ['/DATA/AppData/fixture:/data'],
              'environment': {'TOKEN': 'original'},
            },
            'public': {
              'image': 'nginx:alpine',
              'container_name': 'original-public',
              'labels': {'acceptance.fixture': id},
              'networks': {
                'fixture': {
                  'aliases': ['existing-public-alias'],
                },
              },
              'ports': ['$publicPort:80'],
            },
          },
          'networks': {'fixture': <String, dynamic>{}},
        },
        metadata: const {},
      );
      final defaults = ApplicationComposeService.defaults(template, env, id);
      final config = defaults.copyWith(
        name: fixtureName,
        ports: [
          for (final port in defaults.ports)
            ApplicationPort(
              service: port.service,
              target: port.target,
              published: port.published,
              protocol: port.protocol,
              bindAddress: port.service == 'public' ? '0.0.0.0' : '127.0.0.1',
            ),
        ],
      );
      expect(config.mainService, 'web');
      final contenderId = ApplicationDeploymentService.newId();
      final contender = ApplicationComposeService.defaults(
        template,
        env,
        contenderId,
      ).copyWith(name: fixtureName);
      // Prepare while the name is genuinely free; execute must recheck it later.
      final contenderPlan = await service.prepare(
        server,
        env,
        ApplicationOperation.install,
        template: template,
        configuration: contender,
      );
      final intents = <String, ApplicationTask>{};
      ApplicationDeployment? app;
      var sawLiveCommandAndOutput = false;
      Future<ApplicationTask> run(
        ApplicationOperation operation, {
        ApplicationTemplate? next,
        ApplicationConfiguration? configuration,
      }) async {
        // ignore: avoid_print
        print('isolated app center: ${operation.name}');
        final plan = await service.prepare(
          server,
          env,
          operation,
          template: next ?? template,
          configuration: configuration,
          deployment: app,
        );
        final task = await service.execute(
          plan,
          persistBeforeLaunch: (intent) async {
            intents[intent.id] = intent;
            await storage.saveApplicationCenterRecords(
              'tasks',
              intent.serverKey,
              intents.values.map((t) => t.toJson()).toList(),
            );
          },
        );
        app ??= plan.deployment;
        // ignore: avoid_print
        print(
          'center VM fixture id=${app!.id} project=${app!.project} '
          'name=$fixtureName data=${config.dataRoot} control=${app!.directory} task=${task.id}',
        );
        expect(intents.containsKey(task.id), true);
        final deadline = DateTime.now().add(const Duration(minutes: 3));
        while (true) {
          final current = await service.readTask(task);
          if (current.isBusy &&
              current.currentCommand.isNotEmpty &&
              current.logTail.isNotEmpty &&
              current.lastOutputAt != null) {
            sawLiveCommandAndOutput = true;
          }
          if (!current.isBusy) {
            expect(
              current.stage,
              ApplicationTaskStage.succeeded,
              reason:
                  '${operation.name}: ${current.stage.name} ${current.exitCode}\n${current.logTail}',
            );
            expect(current.currentCommand, contains('docker compose'));
            expect(current.commandStartedAt, isNotNull);
            expect(current.lastOutputAt, isNotNull);
            expect(current.lastSyncedAt, isNotNull);
            expect(current.logTail, contains('[exit 0]'));
            expect(current.logTail, isNot(contains('TOKEN=')));
            return current;
          }
          expect(
            DateTime.now().isBefore(deadline),
            true,
            reason: 'task timed out: ${operation.name}',
          );
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }

      addTearDown(() async {
        if (app != null) {
          final result = await ssh.executeWithLoginShell(
            server.id,
            'test ! -L ${cliShellQuote(app!.directory)} && '
            'test "\$(cat -- ${cliShellQuote('${app!.directory}/.valhalla-app-owner')})" = ${cliShellQuote(app!.id)} && '
            'docker compose --project-name ${cliShellQuote(app!.project)} -f ${cliShellQuote('${app!.directory}/compose.json')} down --timeout 20',
          );
          expect(result.isSuccess, isTrue, reason: result.stderr);
        }
        ssh.dispose();
      });
      final installed = await run(
        ApplicationOperation.install,
        configuration: config,
      );
      expect((await service.reconcile(app!, env))!.status, 'running');
      Future<void> inspectNamesAndAliases() async {
        final inspected = await ssh.executeWithLoginShell(
          server.id,
          'docker inspect ${cliShellQuote(fixtureName)} ${cliShellQuote('$fixtureName-public')}',
        );
        expect(inspected.isSuccess, isTrue, reason: inspected.stderr);
        final containers = (jsonDecode(inspected.stdout) as List).cast<Map>();
        for (final item in containers) {
          final labels = item['Config']['Labels'] as Map;
          final svc = labels['com.docker.compose.service'] as String;
          expect(
            item['Name'],
            svc == 'web' ? '/$fixtureName' : '/$fixtureName-public',
          );
          expect(labels['com.valhalla.app.instance'], id);
          expect(labels['com.docker.compose.project'], app!.project);
          expect(labels['acceptance.fixture'], id);
          final networks = item['NetworkSettings']['Networks'] as Map;
          expect(networks.keys, ['${app!.project}_fixture']);
          expect(
            networks.values.single['Aliases'],
            containsAll([svc, 'original-$svc', 'existing-$svc-alias']),
          );
        }
      }

      await inspectNamesAndAliases();
      final conflict = throwsA(
        predicate(
          (Object error) =>
              error.toString().contains('APP_CENTER_CONTAINER_NAME_CONFLICT'),
        ),
      );
      await expectLater(
        service.prepare(
          server,
          env,
          ApplicationOperation.install,
          template: template,
          configuration: contender,
        ),
        conflict,
      );
      var persistedContender = false;
      await expectLater(
        service.execute(
          contenderPlan,
          persistBeforeLaunch: (_) async {
            persistedContender = true;
          },
        ),
        conflict,
      );
      expect(persistedContender, isFalse);
      final untouchedContender = await ssh.executeWithLoginShell(
        server.id,
        'test ! -e ${cliShellQuote(contender.dataRoot)} && '
        'test ! -e ${cliShellQuote(contenderPlan.deployment.directory)}',
      );
      expect(untouchedContender.isSuccess, isTrue);
      final access = await service.accessInfo(app!, env);
      expect(access.probeStatus, ApplicationAccessProbeStatus.reachable);
      expect(access.httpStatus, 200);
      expect(access.managementPort!.service, 'web');
      expect(
        access.ports.singleWhere((port) => port.service == 'web').bindAddress,
        '127.0.0.1',
      );
      expect(
        access.ports
            .singleWhere((port) => port.service == 'public')
            .bindAddress,
        '0.0.0.0',
      );
      final networkAccess = await ssh.executeWithLoginShell(
        server.id,
        '''host=\$(hostname -I | awk '{print \$1}'); test -n "\$host" && test "\$host" != 127.0.0.1 && curl --noproxy '*' --max-time 5 --fail --silent "http://\$host:$publicPort/" >/dev/null && { if curl --noproxy '*' --max-time 2 --fail --silent "http://\$host:$localPort/" >/dev/null; then exit 1; else exit 0; fi; }''',
      );
      expect(
        networkAccess.isSuccess,
        true,
        reason:
            'public endpoint must answer on VM interface while loopback-only endpoint remains inaccessible there',
      );
      expect((await service.configuration(app!)).dataRoot, config.dataRoot);
      expect(
        (await service.configuration(app!)).environment['web']!['TOKEN'],
        'original',
      );
      expect(
        (await service.installedTemplate(app!)).application.contentHash,
        'v1',
      );
      final response = await ssh.executeWithLoginShell(
        server.id,
        'curl --fail --silent http://127.0.0.1:$localPort/ >/dev/null && printf sentinel > ${cliShellQuote('${config.dataRoot}/sentinel')}',
      );
      expect(response.isSuccess, true);
      ssh.dispose();
      ssh = SSHClientManager(SSHHostKeyVerifier(storage));
      await connect();
      service = ApplicationDeploymentService(ssh);
      env = await service.inspect(server);
      expect(
        (await service.readTask(intents[installed.id]!)).stage,
        ApplicationTaskStage.succeeded,
      );
      await run(ApplicationOperation.stop);
      expect((await service.reconcile(app!, env))!.status, 'stopped');
      // Docker ps -a Go-template inventory must include stopped names as well.
      await expectLater(
        service.prepare(
          server,
          env,
          ApplicationOperation.install,
          template: template,
          configuration: contender,
        ),
        conflict,
      );
      await run(ApplicationOperation.start);
      await run(
        ApplicationOperation.configure,
        configuration: config.copyWith(
          environment: {
            'web': {'TOKEN': 'edited'},
          },
        ),
      );
      expect(
        (await service.configuration(app!)).environment['web']!['TOKEN'],
        'edited',
      );
      final restartedTask = await run(ApplicationOperation.restart);
      expect(restartedTask.exitCode, 0);
      final restartedApp = await service.reconcile(app!, env);
      expect(restartedApp!.status, 'running');
      final readTask = await service.readTask(restartedTask);
      expect(readTask.stage, ApplicationTaskStage.succeeded);
      final http = await ssh.executeWithLoginShell(
        server.id,
        'curl --retry 5 --retry-connrefused --fail --silent http://127.0.0.1:$localPort/ >/dev/null',
      );
      expect(http.isSuccess, true);
      expect(await service.logs(app!, env), contains('GET / HTTP'));
      final updatedTemplate = ApplicationTemplate(
        application: const CatalogApplication(
          sourceId: 'fixture',
          id: 'nginx',
          title: 'Fixture',
          version: '2',
          contentHash: 'v2',
          composeUrl: '',
        ),
        compose: template.compose,
        metadata: const {},
      );
      await run(
        ApplicationOperation.update,
        next: updatedTemplate,
        configuration: config,
      );
      app = await service.reconcile(app!, env);
      expect(app!.version, '2');
      await run(ApplicationOperation.restore);
      app = await service.reconcile(app!, env);
      expect(app!.version, '1');
      expect(
        (await service.configuration(app!)).environment['web']!['TOKEN'],
        'edited',
      );
      expect(
        (await service.installedTemplate(app!)).application.contentHash,
        'v1',
      );
      await inspectNamesAndAliases();
      await run(ApplicationOperation.uninstall);
      expect(await service.reconcile(app!, env), isNull);
      final sentinel = await ssh.executeWithLoginShell(
        server.id,
        'cat -- ${cliShellQuote('${config.dataRoot}/sentinel')}',
      );
      expect(sentinel.stdout.trim(), 'sentinel');
      // ignore: avoid_print
      print(
        'center VM removed containers=$fixtureName,$fixtureName-public '
        'network=${app!.project}_fixture; retained data=${config.dataRoot} control=${app!.directory}',
      );
      expect(
        sawLiveCommandAndOutput,
        true,
        reason:
            'real readTask must expose command and output before the task terminates',
      );
    },
    skip: credentialsPath == null ? 'Requires the pinned disposable VM' : false,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
