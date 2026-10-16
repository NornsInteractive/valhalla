import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:valhalla/data/models/nas_media.dart';
import 'package:valhalla/data/models/nas_source.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/nas/nas_scan_service.dart';
import 'package:valhalla/infrastructure/nas/nas_sftp_adapter.dart';
import 'package:valhalla/infrastructure/nas/nas_http_client.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final credentials = Platform.environment['VALHALLA_NAS_VM_CREDENTIALS'];
  test(
    'isolated encrypted scan delivers 10000 bounded records, main SSH stays responsive, cancellation closes worker',
    () async {
      final config =
          jsonDecode(await File(credentials!).readAsString())
              as Map<String, dynamic>;
      expect(config['ssh_host'], '127.0.0.1');
      expect(config['ssh_port'], 22023);
      expect(config['ssh_user'], 'valhalla');
      SharedPreferences.setMockInitialValues({});
      final manager = SSHClientManager(
        SSHHostKeyVerifier(await LocalStorageService.init()),
      );
      addTearDown(manager.dispose);
      const server = ServerProfile(
        id: 'nas-scan-vm',
        name: 'nas-scan-vm',
        host: '127.0.0.1',
        port: 22023,
        username: 'valhalla',
      );
      await manager.getOrCreateClient(
        server,
        password: config['ssh_password'] as String,
        onConfirmHostKey: (_, _, fingerprint) async =>
            (config['host_fingerprints'] as List).contains(fingerprint),
      );
      final identity = await manager.executeWithLoginShell(
        server.id,
        'hostname; cat /etc/machine-id; id -un',
      );
      expect(identity.stdout.trim().split('\n'), [
        'valhalla-test-vm',
        config['machine_id'],
        'valhalla',
      ]);
      final create = await manager.executeWithLoginShell(
        server.id,
        'mktemp -d /home/valhalla/valhalla-nas-scan-test.XXXXXX',
      );
      final fixture = create.stdout.trim();
      expect(
        RegExp(
          r'^/home/valhalla/valhalla-nas-scan-test\.[A-Za-z0-9]+$',
        ).hasMatch(fixture),
        isTrue,
      );
      addTearDown(() async {
        await manager.executeWithLoginShell(
          server.id,
          "python3 -c 'import pathlib,sys; p=pathlib.Path(sys.argv[1]); [f.unlink() for f in p.iterdir()]; p.rmdir()' '$fixture'",
        );
      });
      final populated = await manager.executeWithLoginShell(
        server.id,
        "python3 -c 'import pathlib,sys; p=pathlib.Path(sys.argv[1]); [(p/(str(i)+\".jpg\")).touch() for i in range(10000)]' '$fixture'",
      );
      expect(populated.exitCode, 0);
      final scan = NasScanService(manager);
      final cancellation = NasCancellation();
      var count = 0, batches = 0, pulses = 0;
      final heartbeat = Timer.periodic(
        const Duration(milliseconds: 5),
        (_) => pulses++,
      );
      addTearDown(heartbeat.cancel);
      final clock = Stopwatch()..start();
      await for (final batch in scan.scanBatches(
        server.id,
        NasScanConfig(includePaths: [fixture]),
        cancellation,
      )) {
        expect(batch.length, lessThanOrEqualTo(256));
        count += batch.length;
        batches++;
        if (batches == 1) {
          final ping = await manager.executeWithLoginShell(
            server.id,
            'printf scan-main-responsive',
          );
          expect(ping.stdout, 'scan-main-responsive');
        }
      }
      expect(count, 10000);
      expect(batches, 40);
      expect(pulses, greaterThan(0));
      final previewFile = await manager.executeWithLoginShell(
        server.id,
        "printf preview-payload > '$fixture/0.jpg'; stat -c %Y '$fixture/0.jpg'",
      );
      final media = NasMediaItem(
        serverId: server.id,
        path: '$fixture/0.jpg',
        kind: NasMediaKind.image,
        sizeBytes: 15,
        modifiedEpoch: int.parse(previewFile.stdout.trim()),
      );
      final adapter = NasSftpAdapter(
        NasSource(
          id: server.id,
          name: 'fixture',
          type: NasSourceType.sftp,
          sshServerId: server.id,
        ),
        manager,
      );
      final preview = await adapter.thumbnail(media);
      expect(preview, isNotNull);
      final content = <int>[];
      await for (final bytes in readNasResource(
        preview!,
        0,
        15,
        NasCancellation(),
      )) {
        content.addAll(bytes);
      }
      expect(utf8.decode(content), 'preview-payload');
      final stop = NasCancellation();
      var received = 0;
      await expectLater(() async {
        await for (final batch in scan.scanBatches(
          server.id,
          NasScanConfig(includePaths: [fixture]),
          stop,
        )) {
          received += batch.length;
          stop.cancel();
        }
      }(), throwsA(isA<NasCancelled>()));
      expect(received, 256);
      final ping = await manager.executeWithLoginShell(
        server.id,
        'printf scan-cancel-responsive',
      );
      expect(ping.stdout, 'scan-cancel-responsive');
      // Report timings as observations, not hardware-independent performance gates.
      debugPrint(
        'NAS_SCAN_VM records=$count batches=$batches elapsedMs=${clock.elapsedMilliseconds} mainHeartbeat=$pulses',
      );
    },
    skip: credentials == null ? 'Requires isolated test VM credentials' : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
