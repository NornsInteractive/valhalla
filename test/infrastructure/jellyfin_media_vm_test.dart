import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/services/application_catalog_service.dart';
import 'package:valhalla/core/services/application_compose_service.dart';
import 'package:valhalla/core/services/application_deployment_service.dart';
import 'package:valhalla/core/utils/shell_quote.dart';
import 'package:valhalla/data/models/application_center.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/nas/nas_http_client.dart';
import 'package:valhalla/infrastructure/nas/nas_media_server_adapter.dart';
import 'package:valhalla/infrastructure/nas/nas_ssh_tunnel_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';

// Mutates only the pinned disposable VM. Never initializes an existing unknown
// account. All login secrets remain in a private local fixture record, not logs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final credentials = Platform.environment['VALHALLA_NAS_VM_CREDENTIALS'];
  final enabled = Platform.environment['VALHALLA_JELLYFIN_MEDIA_VM'] == '1';
  final privateRoot = Platform.environment['VALHALLA_JELLYFIN_PRIVATE_DIR'];

  group(
    'pinned Jellyfin source acceptance',
    () {
      late _Vm vm;
      setUp(() async {
        vm = await _Vm.connect(credentials!, privateRoot!);
      });
      tearDown(() => vm.dispose());

      test(
        'new native deployment authenticates, browses and reads media',
        () async {
          final taskId = Platform.environment['VALHALLA_JELLYFIN_NATIVE_TASK'];
          expect(taskId, matches(RegExp(r'^[a-f0-9]{32}$')));
          final proof = await vm.command(
            'sudo -n cat /var/lib/valhalla-native-jellyfin/$taskId/state.json',
          );
          expect(proof.isSuccess, isTrue);
          final state = jsonDecode(proof.stdout) as Map;
          expect(state['stage'], 'succeeded');
          final ownerResult = await vm.command(
            'sudo -n cat /var/lib/valhalla-native-jellyfin/$taskId/owner.json',
          );
          expect(ownerResult.isSuccess, isTrue);
          final owner = jsonDecode(ownerResult.stdout) as Map;
          expect(owner['id'], taskId);
          expect(owner['targetIdentity'], _Vm._machineId);
          expect(owner['mediaPath'], '/home/valhalla/media');
          for (final package in (owner['packageVersions'] as Map).entries) {
            expect(package.key, matches(RegExp(r'^[a-z0-9-]+$')));
            final installed = await vm.command(
              'dpkg-query -W -f=\'\${Version}\' ${cliShellQuote(package.key as String)}',
            );
            expect(installed.isSuccess, isTrue);
            expect(installed.stdout.trim(), package.value);
          }
          expect(
            (await vm.command(
              'systemctl is-active jellyfin.service',
            )).stdout.trim(),
            'active',
          );
          await vm.verifySource(
            port: 8096,
            mediaPath: await vm.prepareMediaFixture('native-$taskId'),
            fixtureId: 'native-$taskId',
            privateFile: File('${vm.privateRoot.path}/native-jellyfin.json'),
            expectedServerId: '02d150f902b64507a9f780d86eebdcee',
          );
        },
        timeout: const Timeout(Duration(minutes: 8)),
      );

      test(
        'application center software profile deploys and reads media',
        () async {
          final service = ApplicationDeploymentService(vm.ssh);
          final environment = await service.inspect(_Vm.server);
          expect(
            environment.ready,
            isTrue,
            reason: environment.blockers.join(', '),
          );
          final appId = ApplicationDeploymentService.newId();
          final mediaFixture = await vm.prepareMediaFixture('docker-$appId');
          final catalog = ApplicationCatalogService(
            directoryProvider: () async => vm.privateRoot,
          );
          final template = await catalog.template(
            CatalogApplication(
              sourceId: ApplicationSource.official.id,
              id: 'org.icewhale.jellyfin',
              title: 'Jellyfin fixture $appId',
              composeUrl:
                  'https://raw.githubusercontent.com/IceWhaleTech/CasaOS-AppStore/gh-pages/apps/org.icewhale.jellyfin/docker-compose.yml',
            ),
          );
          expect(
            ApplicationComposeService.supportsJellyfinSoftwareMode(template),
            isTrue,
          );
          final defaults = ApplicationComposeService.defaults(
            template,
            environment,
            appId,
            jellyfinSoftwareMode: true,
          );
          final configuration = defaults.copyWith(
            ports: [
              for (var i = 0; i < defaults.ports.length; i++)
                ApplicationPort(
                  service: defaults.ports[i].service,
                  target: defaults.ports[i].target,
                  published: 18497 + i,
                  protocol: defaults.ports[i].protocol,
                  bindAddress: '127.0.0.1',
                ),
            ],
            mounts: [
              for (final mount in defaults.mounts)
                ApplicationMount(
                  service: mount.service,
                  target: mount.target,
                  source: mount.target == '/Media'
                      ? mediaFixture
                      : mount.source,
                  readOnly: mount.target == '/Media' || mount.readOnly,
                ),
            ],
          );
          expect(
            (await vm.command(
              'test ! -e ${cliShellQuote(defaults.dataRoot)}',
            )).isSuccess,
            isTrue,
          );
          final plan = await service.prepare(
            _Vm.server,
            environment,
            ApplicationOperation.install,
            template: template,
            configuration: configuration,
          );
          final services =
              (jsonDecode(plan.composeJson) as Map)['services'] as Map;
          for (final raw in services.values) {
            final entry = raw as Map;
            expect(entry.containsKey('devices'), isFalse);
            final mounts = entry['volumes'] as List;
            expect(
              mounts.where((m) => (m as Map)['target'] == '/opt/vc/lib'),
              isEmpty,
            );
            final media = mounts.cast<Map>().singleWhere(
              (m) => m['target'] == '/Media',
            );
            expect(media['read_only'], isTrue);
            expect(media['source'], mediaFixture);
            expect(
              (entry['ports'] as List).cast<Map>().every(
                (p) => p['host_ip'] == '127.0.0.1',
              ),
              isTrue,
            );
          }
          final app = plan.deployment;
          ApplicationTask? launched;
          addTearDown(() async {
            // Wait for the detached worker before down so a late up cannot
            // recreate the fixture after teardown. Never kill arbitrary jobs.
            final intent = launched;
            if (intent != null) {
              var task = await service.readTask(intent);
              if (task.canCancel) await service.cancel(task);
              final stopBy = DateTime.now().add(const Duration(minutes: 5));
              while (task.isBusy && DateTime.now().isBefore(stopBy)) {
                await Future<void>.delayed(const Duration(seconds: 2));
                task = await service.readTask(intent);
              }
              expect(
                task.isBusy,
                isFalse,
                reason:
                    'Do not race compose down against a live fixture worker.',
              );
            }
            // No volume/data deletion. Guard exact ownership before stopping this
            // test's project, even when an assertion failed midway through launch.
            final result = await vm.command(
              'if test -e ${cliShellQuote('${app.directory}/.valhalla-app-owner')}; then '
              'test ! -L ${cliShellQuote(app.directory)} && '
              'test ! -L ${cliShellQuote('${app.directory}/.valhalla-app-owner')} && '
              'test "\$(realpath -- ${cliShellQuote(app.directory)})" = ${cliShellQuote(app.directory)} && '
              'test "\$(cat -- ${cliShellQuote('${app.directory}/.valhalla-app-owner')})" = ${cliShellQuote(app.id)} && '
              'docker compose --project-name ${cliShellQuote(app.project)} '
              '-f ${cliShellQuote('${app.directory}/compose.json')} down --timeout 20; fi',
            );
            expect(result.isSuccess, isTrue, reason: result.stderr);
          });
          final task = await service.execute(
            plan,
            persistBeforeLaunch: (intent) async {
              launched = intent;
              await vm.storage.saveApplicationCenterRecords(
                'tasks',
                intent.serverKey,
                [intent.toJson()],
              );
            },
          );
          // ignore: avoid_print
          print('Docker Jellyfin fixture app=${app.id} task=${task.id}');
          launched = task;
          final deadline = DateTime.now().add(const Duration(minutes: 15));
          var current = await service.readTask(task);
          var lastStage = '';
          while (current.isBusy && DateTime.now().isBefore(deadline)) {
            if (current.stage.name != lastStage) {
              lastStage = current.stage.name;
              // ignore: avoid_print
              print('Docker Jellyfin stage=$lastStage');
            }
            await Future<void>.delayed(const Duration(seconds: 3));
            current = await service.readTask(task);
          }
          expect(
            current.stage,
            ApplicationTaskStage.succeeded,
            reason:
                '${current.stage.name} ${current.exitCode}\n${current.logTail}',
          );
          final port = configuration.ports
              .singleWhere((p) => p.target == 8096)
              .published;
          await vm.verifySource(
            port: port,
            mediaPath: '/Media',
            fixtureId: 'docker-$appId',
            privateFile: File('${vm.privateRoot.path}/docker-$appId.json'),
          );
        },
        timeout: const Timeout(Duration(minutes: 23)),
      );
      test(
        'owned Docker fixture resumes authenticated source acceptance',
        () async {
          final appId =
              Platform.environment['VALHALLA_JELLYFIN_DOCKER_APP_ID']!;
          final installTask =
              Platform.environment['VALHALLA_JELLYFIN_DOCKER_INSTALL_TASK']!;
          expect(appId, matches(RegExp(r'^[a-f0-9]{32}$')));
          expect(installTask, matches(RegExp(r'^[a-f0-9]{32}$')));
          final directory =
              '/home/valhalla/.local/share/valhalla/app-center/deployments/$appId';
          final manifest = await vm.command(
            'cat -- ${cliShellQuote('$directory/deployment.json')}',
          );
          expect(manifest.isSuccess, isTrue);
          final app = ApplicationDeployment.fromJson(
            jsonDecode(manifest.stdout) as Map<String, dynamic>,
          );
          expect(app.id, appId);
          expect(app.directory, directory);
          expect(app.project, 'valhalla-app-$appId');
          expect(app.serverId, _Vm.server.id);
          expect(app.sourceId, ApplicationSource.official.id);
          expect(app.appId, 'org.icewhale.jellyfin');
          final service = ApplicationDeploymentService(vm.ssh);
          final environment = await service.inspect(_Vm.server);
          expect(app.targetIdentity, environment.targetIdentity);
          expect(app.serverKey, environment.serverKey);
          expect(await service.reconcile(app, environment), isNotNull);
          final original =
              '/home/valhalla/.local/share/valhalla/app-center/tasks/$installTask';
          expect(
            (await vm.command(
              'cmp -- ${cliShellQuote('$original/compose.next.json')} ${cliShellQuote('$directory/compose.json')} && cmp -- ${cliShellQuote('$original/deployment.next.json')} ${cliShellQuote('$directory/deployment.json')}',
            )).isSuccess,
            isTrue,
            reason:
                'Resume only the exact recorded fixture, never replaced state.',
          );
          addTearDown(() async {
            // Ownership and immutable original compose were verified above; no
            // data/volume/image deletion and no native-service modifications.
            expect(await service.reconcile(app, environment), isNotNull);
            final stopped = await vm.command(
              'docker compose --project-name ${cliShellQuote(app.project)} -f ${cliShellQuote('$directory/compose.json')} down --timeout 20',
            );
            expect(stopped.isSuccess, isTrue, reason: stopped.stderr);
          });
          // This recovery-only setup recreates containers removed by the prior
          // test's down. It does not claim to validate the app's start action,
          // which deliberately requires existing containers to pin images.
          final restored = await vm.ssh.executeWithLoginShell(
            _Vm.server.id,
            'docker compose --project-name ${cliShellQuote(app.project)} '
            '-f ${cliShellQuote('$directory/compose.json')} '
            'up --detach --no-build --pull never --wait --wait-timeout 120',
            timeout: const Duration(minutes: 3),
          );
          expect(restored.isSuccess, isTrue, reason: restored.stderr);
          await vm.verifySource(
            port: 18497,
            mediaPath: '/Media',
            fixtureId: 'docker-$appId',
            privateFile: File('${vm.privateRoot.path}/docker-$appId.json'),
          );
        },
        skip:
            Platform.environment['VALHALLA_JELLYFIN_DOCKER_APP_ID'] == null ||
                Platform.environment['VALHALLA_JELLYFIN_DOCKER_INSTALL_TASK'] ==
                    null
            ? 'Requires exact owned installation identity for failure recovery.'
            : false,
        timeout: const Timeout(Duration(minutes: 12)),
      );
    },
    skip: !enabled || credentials == null || privateRoot == null
        ? 'Requires explicit pinned VM media acceptance and private credential directory.'
        : false,
  );
}

class _Vm {
  static const _machineId = '3579bace85be432fa7cde6da46ad839b';
  static const _fingerprint =
      'SHA256:j0JCpHOOGNJlL2UDKj5nQnFSJlePw63tPE8Yo4MINtM';
  static const server = ServerProfile(
    id: 'isolated-jellyfin-media-vm',
    name: 'valhalla-test-vm',
    host: '127.0.0.1',
    port: 22023,
    username: 'valhalla',
  );
  final SSHClientManager ssh;
  final LocalStorageService storage;
  final Directory privateRoot;
  final HttpOverrides? previousHttpOverride;
  _Vm(this.ssh, this.storage, this.privateRoot, this.previousHttpOverride);

  static Future<_Vm> connect(String credentialsPath, String privatePath) async {
    final config =
        jsonDecode(await File(credentialsPath).readAsString()) as Map;
    expect(config['ssh_host'], server.host);
    expect(config['ssh_port'], server.port);
    expect(config['ssh_user'], server.username);
    expect(config['machine_id'], _machineId);
    expect(config['host_fingerprints'], contains(_fingerprint));
    final directory = Directory(privatePath);
    expect(await directory.exists(), isTrue);
    expect(
      (await directory.stat()).mode & 0x3f,
      0,
      reason: 'Fixture credentials require a private directory before writes.',
    );
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.init();
    final ssh = SSHClientManager(SSHHostKeyVerifier(storage));
    await ssh.getOrCreateClient(
      server,
      password: config['ssh_password'] as String,
      onConfirmHostKey: (_, _, fingerprint) async =>
          fingerprint == _fingerprint,
    );
    final identity = await ssh.executeWithLoginShell(
      server.id,
      'hostname; cat /etc/machine-id; test -e /home/valhalla/fixture-ready',
    );
    expect(identity.isSuccess, isTrue);
    expect(identity.stdout.trim().split('\n'), [
      'valhalla-test-vm',
      _machineId,
    ]);
    final previous = HttpOverrides.current;
    HttpOverrides.global = null;
    return _Vm(ssh, storage, directory, previous);
  }

  Future<SSHExecutionResult> command(String text) => ssh.executeWithLoginShell(
    server.id,
    text,
    timeout: const Duration(seconds: 90),
  );

  Future<String> prepareMediaFixture(String fixtureId) async {
    expect(fixtureId, matches(RegExp(r'^(native|docker)-[a-f0-9]{32}$')));
    final root = '/home/valhalla/nas-test-media-$fixtureId';
    final marker = '$root/.valhalla-media-fixture';
    final prepared = await command(
      'if test -e ${cliShellQuote(root)}; then '
      'test ! -L ${cliShellQuote(root)} && test ! -L ${cliShellQuote(marker)} && '
      'test "\$(realpath -- ${cliShellQuote(root)})" = ${cliShellQuote(root)} && '
      'test "\$(cat -- ${cliShellQuote(marker)})" = ${cliShellQuote(fixtureId)}; '
      'else mkdir -m 755 -- ${cliShellQuote(root)} && '
      'printf %s ${cliShellQuote(fixtureId)} > ${cliShellQuote(marker)}; fi',
    );
    expect(prepared.isSuccess, isTrue);
    for (final sub in [
      'PhotosVideos',
      'Music',
      'Music/Fixture Artist',
      'Music/Fixture Artist/Fixture Album',
    ]) {
      final path = '$root/$sub';
      expect(
        (await command(
          'if test -e ${cliShellQuote(path)}; then test -d ${cliShellQuote(path)} && test ! -L ${cliShellQuote(path)}; else mkdir -m 755 -- ${cliShellQuote(path)}; fi',
        )).isSuccess,
        isTrue,
      );
    }
    for (final entry in _mediaFiles.entries) {
      final original = '/home/valhalla/media/${entry.key}';
      final target = '$root/${entry.value}';
      final copied = await command(
        'if test -e ${cliShellQuote(target)}; then '
        'test -f ${cliShellQuote(target)} && test ! -L ${cliShellQuote(target)} && cmp -- ${cliShellQuote(original)} ${cliShellQuote(target)}; '
        'else cp -- ${cliShellQuote(original)} ${cliShellQuote(target)} && chmod 644 -- ${cliShellQuote(target)}; fi',
      );
      expect(copied.isSuccess, isTrue);
    }
    return root;
  }

  static const _mediaFiles = {
    'Photo.png': 'PhotosVideos/Photo.png',
    'Video 30s.mp4': 'PhotosVideos/Video 30s.mp4',
    'Music 60s.mp3': 'Music/Fixture Artist/Fixture Album/Music 60s.mp3',
  };

  Future<void> verifySource({
    required int port,
    required String mediaPath,
    required String fixtureId,
    required File privateFile,
    String? expectedServerId,
  }) async {
    final tunnel = NasSshTunnelService(ssh);
    addTearDown(tunnel.dispose);
    final remote = NasSource(
      id: fixtureId,
      name: 'Jellyfin acceptance',
      type: NasSourceType.jellyfin,
      endpoint: 'http://127.0.0.1:$port/',
      sshServerId: server.id,
    );
    final local = await tunnel.forward(remote);
    final http = NasHttpClient(local, headers: {'Host': '127.0.0.1:$port'});
    addTearDown(http.close);
    final readyBy = DateTime.now().add(const Duration(minutes: 3));
    Map<String, dynamic>? info;
    String? observedServerId;
    var reportedPending = false;
    while (info == null && DateTime.now().isBefore(readyBy)) {
      try {
        final response = await http.open(
          'GET',
          local.resolve('System/Info/Public'),
        );
        final body = await utf8.decoder.bind(response.decodedBytes).join();
        final candidate =
            jsonDecode(body.isEmpty ? '{}' : body) as Map<String, dynamic>;
        final identity = candidate['Id'] ?? candidate['id'];
        if (identity is String && identity.isNotEmpty) {
          observedServerId ??= identity;
          expect(
            identity,
            observedServerId,
            reason: 'Jellyfin changed identity while starting.',
          );
        }
        if (candidate['Id'] is String &&
            (candidate['Id'] as String).isNotEmpty &&
            candidate['Version'] is String &&
            candidate['StartupWizardCompleted'] is bool) {
          info = candidate;
        } else {
          if (!reportedPending) {
            // This unauthenticated public payload never contains login secrets.
            // ignore: avoid_print
            print(
              'Jellyfin public metadata not ready: status=${response.status} payload=${jsonEncode(candidate)}',
            );
            reportedPending = true;
          }
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      } on NasHttpException {
        await Future<void>.delayed(const Duration(seconds: 2));
      } on SocketException {
        await Future<void>.delayed(const Duration(seconds: 2));
      } on HttpException {
        await Future<void>.delayed(const Duration(seconds: 2));
      } on TimeoutException {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    expect(info, isNotNull, reason: 'Jellyfin API must become ready.');
    final serverId = info!['Id'];
    expect(serverId, isA<String>());
    if (expectedServerId != null) expect(serverId, expectedServerId);
    // Routes are verified against the installed native OpenAPI and official
    // Jellyfin v10.11.10 StartupController / LibraryStructureController source.
    // Generating the entire OpenAPI document is not part of app source setup.
    // ignore: avoid_print
    print(
      '$fixtureId public API ready, version=${info['Version']} serverId=$serverId',
    );

    late Map<String, dynamic> account;
    if (await privateFile.exists()) {
      expect((await privateFile.stat()).mode & 0x3f, 0);
      account =
          jsonDecode(await privateFile.readAsString()) as Map<String, dynamic>;
      expect(account['serverId'], serverId);
      expect(account['fixtureId'], fixtureId);
    } else {
      expect(
        info['StartupWizardCompleted'],
        isFalse,
        reason: 'Never initialize or overwrite an existing unknown account.',
      );
      final response = await http.open('GET', local.resolve('Users/Public'));
      final users =
          jsonDecode(await utf8.decoder.bind(response.decodedBytes).join())
              as List;
      expect(users.length, lessThanOrEqualTo(1));
      expect(
        users.every((u) => (u as Map)['HasPassword'] == false),
        isTrue,
        reason: 'A password-protected existing account must never be replaced.',
      );
      account = {
        'serverId': serverId,
        'fixtureId': fixtureId,
        'username': 'fixture-${fixtureId.substring(0, 14)}',
        'password': base64UrlEncode(
          List<int>.generate(32, (_) => Random.secure().nextInt(256)),
        ),
      };
      await privateFile.create(exclusive: true);
      expect(
        (await Process.run('chmod', ['600', privateFile.path])).exitCode,
        0,
      );
      await privateFile.writeAsString(jsonEncode(account), flush: true);
      await http.json('GET', local.resolve('Startup/User'));
      await http.json(
        'POST',
        local.resolve('Startup/User'),
        body: {'Name': account['username'], 'Password': account['password']},
      );
    }
    NasSource source([String? userId]) => NasSource(
      id: fixtureId,
      name: remote.name,
      type: remote.type,
      endpoint: local.toString(),
      sshServerId: server.id,
      username: account['username'] as String,
      userId: userId,
      forwardedHost: '127.0.0.1:$port',
    );
    // ignore: avoid_print
    print('$fixtureId authenticating through product adapter');
    final login = await NasMediaServerAdapter.authenticate(
      source(),
      account['password'] as String,
    );
    final admin = NasHttpClient(
      local,
      headers: {
        'Host': '127.0.0.1:$port',
        'Authorization':
            'MediaBrowser Client="Valhalla fixture", Device="Isolated VM", DeviceId="$fixtureId", Version="1.0.0", Token="${login.credentials.token}"',
      },
    );
    addTearDown(admin.close);
    if (info['StartupWizardCompleted'] == false) {
      await admin.json('POST', local.resolve('Startup/Complete'));
    }
    final foldersResponse = await admin.open(
      'GET',
      local.resolve('Library/VirtualFolders'),
    );
    final folders =
        jsonDecode(await utf8.decoder.bind(foldersResponse.decodedBytes).join())
            as List;
    for (final collection in ['homevideos', 'music']) {
      final name = '$fixtureId-$collection';
      final path =
          '$mediaPath/${collection == 'music' ? 'Music' : 'PhotosVideos'}';
      final existing = folders
          .cast<Map>()
          .where((f) => f['Name'] == name)
          .toList();
      if (existing.isNotEmpty) {
        expect(existing, hasLength(1));
        final locations = (existing.single['Locations'] as List).cast<String>();
        if (locations.length == 1 && locations.single == path) continue;
        // Only migrate this run's two initially overlapping fixture references.
        // Jellyfin's official route removes a virtual folder, not media files.
        expect(fixtureId, startsWith('native-'));
        expect(locations, ['/home/valhalla/media']);
        await admin.json(
          'DELETE',
          local
              .resolve('Library/VirtualFolders')
              .replace(
                queryParameters: {'name': name, 'refreshLibrary': 'false'},
              ),
        );
      }
      await admin.json(
        'POST',
        local
            .resolve('Library/VirtualFolders')
            .replace(
              queryParameters: {
                'name': name,
                'collectionType': collection,
                'refreshLibrary': 'true',
              },
            ),
        body: {
          'LibraryOptions': {
            'PathInfos': [
              {'Path': path},
            ],
            'EnablePhotos': true,
            'EnableRealtimeMonitor': false,
            'SaveLocalMetadata': false,
            'EnableInternetProviders': false,
            'EnableChapterImageExtraction': false,
            'EnableTrickplayImageExtraction': false,
            'MetadataSavers': <String>[],
            'SaveSubtitlesWithMedia': false,
            'SaveLyricsWithMedia': false,
            'TypeOptions': [
              for (final type in [
                'Video',
                'Movie',
                'MusicVideo',
                'Audio',
                'MusicAlbum',
                'MusicArtist',
                'Photo',
              ])
                {
                  'Type': type,
                  'MetadataFetchers': <String>[],
                  'ImageFetchers': <String>[],
                },
            ],
          },
        },
      );
    }
    final adapter = NasMediaServerAdapter(
      source(login.userId),
      login.credentials,
    );
    addTearDown(adapter.dispose);
    await adapter.probe();
    // ignore: avoid_print
    print('$fixtureId product probe passed; scanning media');
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    var items = <NasMediaItem>[];
    while (DateTime.now().isBefore(deadline)) {
      items =
          (await adapter
                  .scan(
                    const NasScanConfig(includePaths: ['/']),
                    NasCancellation(),
                  )
                  .toList())
              .expand((page) => page)
              .toList();
      if (items.map((i) => i.kind).toSet().containsAll(NasMediaKind.values)) {
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    expect(
      items.map((i) => i.kind).toSet(),
      containsAll(NasMediaKind.values),
      reason: 'The real source must expose photo, audio and video fixtures.',
    );
    for (final entry in {
      'Photo.png': NasMediaKind.image,
      'Music 60s.mp3': NasMediaKind.audio,
      'Video 30s.mp4': NasMediaKind.video,
    }.entries) {
      final item = items.firstWhere(
        (i) =>
            i.sourcePath == '$mediaPath/${_mediaFiles[entry.key]}' &&
            i.kind == entry.value,
      );
      final resource = await adapter.resolve(item);
      for (final start in [0, 1024]) {
        final bytes = (await readNasResource(
          resource,
          start,
          start + 32,
          NasCancellation(),
        ).toList()).expand((chunk) => chunk).toList();
        final expected = await command(
          'dd if=${cliShellQuote('/home/valhalla/media/${entry.key}')} bs=1 skip=$start count=32 status=none | base64 -w0',
        );
        expect(expected.isSuccess, isTrue);
        expect(
          bytes,
          base64Decode(expected.stdout.trim()),
          reason: '${entry.value.name} byte range $start',
        );
        expect(bytes.length, 32);
      }
      // ignore: avoid_print
      print(
        '$fixtureId ${entry.value.name}: authenticated browse + two exact byte ranges passed',
      );
    }
  }

  void dispose() {
    ssh.dispose();
    HttpOverrides.global = previousHttpOverride;
  }
}
