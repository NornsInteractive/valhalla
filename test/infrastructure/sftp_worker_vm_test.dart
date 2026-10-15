import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/core/utils/file_integrity.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/sftp/isolated_sftp_client_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';
import 'package:valhalla/infrastructure/ssh/ssh_transfer_connection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final credentials = Platform.environment['VALHALLA_NAS_VM_CREDENTIALS'];
  test(
    'real encrypted worker upload/download, key auth, host pin and concurrent main SSH',
    () async {
      final config =
          jsonDecode(await File(credentials!).readAsString())
              as Map<String, dynamic>;
      expect(config['ssh_host'], '127.0.0.1');
      expect(config['ssh_port'], 22023);
      expect(config['ssh_user'], 'valhalla');
      expect(config['ssh_key'], '/tmp/valhalla-test-vm/id_ed25519');
      final pins = (config['host_fingerprints'] as List).cast<String>();
      expect(pins, isNotEmpty);
      SharedPreferences.setMockInitialValues({});
      final manager = SSHClientManager(
        SSHHostKeyVerifier(await LocalStorageService.init()),
      );
      addTearDown(manager.dispose);
      const server = ServerProfile(
        id: 'worker-vm',
        name: 'worker-vm',
        host: '127.0.0.1',
        port: 22023,
        username: 'valhalla',
      );
      await manager.getOrCreateClient(
        server,
        password: config['ssh_password'] as String,
        onConfirmHostKey: (_, _, pin) async => pins.contains(pin),
      );
      final identity = await manager.executeWithLoginShell(
        server.id,
        'hostname; cat /etc/machine-id; id -un; test -e ~/fixture-ready',
      );
      expect(identity.exitCode, 0);
      expect(identity.stdout.trim().split('\n'), [
        'valhalla-test-vm',
        config['machine_id'],
        'valhalla',
      ]);
      expect(manager.transferConnectionFor(server), isNotNull);
      expect(
        manager.transferConnectionFor(server.copyWith(username: 'other')),
        isNull,
      );

      final local = await Directory.systemTemp.createTemp(
        'valhalla_real_worker_',
      );
      addTearDown(() => local.delete(recursive: true));
      final id = const Uuid().v4();
      final remote = '/home/valhalla/worker-transfer-$id.bin';
      final source = File('${local.path}/source');
      await source.writeAsBytes(
        Uint8List.fromList(List.generate(2 * 1024 * 1024, (i) => i % 251)),
      );
      var service = IsolatedSftpClientService(
        manager.getClient(server.id),
        connectionFor: () => manager.transferConnectionFor(server),
      );
      var uploaded = false;
      try {
        final upload = await service.startResumableUpload(
          source.path,
          remote,
          transferId: id,
          onSource: (_) {},
        );
        await upload.done.timeout(const Duration(seconds: 40));
        uploaded = true;
        expect(upload.transferredBytes, 2 * 1024 * 1024);
        expect(manager.isConnected(server.id), isTrue);
        service.dispose();
        manager.disconnect(server.id);
        expect(manager.transferConnectionFor(server), isNull);

        final keyServer = server.copyWith(
          authType: AuthType.privateKey,
          privateKeyPath: config['ssh_key'] as String,
        );
        await manager.getOrCreateClient(
          keyServer,
          privateKey: await File(config['ssh_key'] as String).readAsString(),
          onConfirmHostKey: (_, _, pin) async => pins.contains(pin),
        );
        final connection = manager.transferConnectionFor(keyServer)!;
        expect(connection.privateKey, isNotNull);
        service = IsolatedSftpClientService(
          manager.getClient(server.id),
          connectionFor: () => manager.transferConnectionFor(keyServer),
        );
        var ticks = 0;
        var worstGap = 0;
        var last = 0;
        final clock = Stopwatch()..start();
        final heartbeat = Timer.periodic(const Duration(milliseconds: 8), (_) {
          final now = clock.elapsedMicroseconds;
          if (now - last > worstGap) worstGap = now - last;
          last = now;
          ticks++;
        });
        final target = File('${local.path}/download');
        try {
          final download = await service.startResumableDownload(
            remote,
            target.path,
            onSource: (_) {},
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
          final commandClock = Stopwatch()..start();
          final response = await manager.executeWithLoginShell(
            server.id,
            'printf main-responsive',
          );
          expect(response.stdout, 'main-responsive');
          final commandMs = commandClock.elapsedMilliseconds;
          await download.done.timeout(const Duration(seconds: 40));
          expect(download.transferredBytes, 2 * 1024 * 1024);
          expect(ticks, greaterThan(5));
          // This is a real fixture measurement, not a machine-specific pass threshold.
          debugPrint(
            'SFTP_WORKER_MEASUREMENT bytes=${download.transferredBytes} '
            'downloadMs=${clock.elapsedMilliseconds} ticks=$ticks '
            'worstEventGapMs=${worstGap / 1000} mainCommandMs=$commandMs',
          );
        } finally {
          heartbeat.cancel();
        }
        expect(await fileSha256(target.path), await fileSha256(source.path));
        expect(manager.isConnected(server.id), isTrue);

        final wrong = SshTransferConnection(
          host: connection.host,
          port: connection.port,
          username: connection.username,
          password: connection.password,
          privateKey: connection.privateKey,
          hostKeyType: connection.hostKeyType,
          hostKeyFingerprint: Uint8List.fromList(connection.hostKeyFingerprint)
            ..[0] ^= 1,
        );
        final rejected = IsolatedSftpClientService(
          manager.getClient(server.id),
          connectionFor: () => wrong,
        );
        try {
          final failure = await rejected.startDownload(
            remote,
            '${local.path}/rejected',
          );
          await expectLater(
            failure.done,
            throwsA(isA<SSHConnectionException>()),
          );
          expect(await File('${local.path}/rejected').exists(), isFalse);
          expect(manager.isConnected(server.id), isTrue);
        } finally {
          rejected.dispose();
        }
      } finally {
        if (uploaded && service.isRealConnected) {
          await service.deleteFile(remote);
        }
        if (service.isRealConnected) {
          await service.discardUploadPartial(remote, id);
        }
        service.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: credentials == null ? 'Requires disposable VM fixture' : false,
  );
}
