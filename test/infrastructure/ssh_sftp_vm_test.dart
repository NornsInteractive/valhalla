import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm/xterm.dart';
import 'package:valhalla/core/utils/shell_quote.dart';
import 'package:valhalla/infrastructure/terminal/terminal_session_bridge.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';
import 'package:valhalla/infrastructure/sftp/sftp_client_service.dart';

/// Opt-in fixture check; the credentials and ssh-keygen pins are produced by
/// the disposable VM setup, never copied from an existing user server.
/// VALHALLA_NAS_VM_CREDENTIALS=/tmp/valhalla-test-vm/credentials.json \
///   flutter test test/infrastructure/ssh_sftp_vm_test.dart --reporter expanded
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final credentialsPath = Platform.environment['VALHALLA_NAS_VM_CREDENTIALS'];
  test(
    'isolated VM host-key wait, streaming, cancel, SFTP CRUD and bad authentication',
    () async {
      final config =
          jsonDecode(await File(credentialsPath!).readAsString())
              as Map<String, dynamic>;
      expect(config['ssh_host'], '127.0.0.1');
      expect(config['ssh_port'], 22023);
      expect(config['ssh_user'], 'valhalla');
      expect(config['machine_id'], matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(config['ssh_known_hosts'], '/tmp/valhalla-test-vm/known_hosts');
      final fingerprints = (config['host_fingerprints'] as List).cast<String>();
      expect(fingerprints, isNotEmpty);
      expect(
        fingerprints,
        everyElement(matches(RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$'))),
      );
      // Verify independently of dartssh2 and the app's fingerprint conversion.
      final pins = await Process.run('ssh-keygen', [
        '-lf',
        config['ssh_known_hosts'] as String,
        '-E',
        'sha256',
      ]);
      expect(pins.exitCode, 0);
      final pinnedFingerprints = (pins.stdout as String)
          .trim()
          .split('\n')
          .map((line) => line.trim().split(RegExp(r'\s+'))[1])
          .toSet();
      expect(pinnedFingerprints, isNotEmpty);
      expect(pinnedFingerprints.every(fingerprints.contains), isTrue);
      final serverPins = await Process.run('ssh', [
        '-F',
        '/tmp/valhalla-test-vm/ssh_config',
        '-o',
        'StrictHostKeyChecking=yes',
        '-o',
        'HostKeyAlgorithms=ssh-ed25519',
        '-o',
        'HostName=127.0.0.1',
        '-p',
        '22023',
        '-l',
        'valhalla',
        'valhalla-test-vm',
        r'for key in /etc/ssh/ssh_host_*_key.pub; do ssh-keygen -lf "$key" -E sha256; done',
      ]);
      expect(serverPins.exitCode, 0);
      final negotiatedPins = (serverPins.stdout as String)
          .trim()
          .split('\n')
          .map((line) => line.trim().split(RegExp(r'\s+'))[1])
          .toSet();
      expect(negotiatedPins, unorderedEquals(fingerprints));
      SharedPreferences.setMockInitialValues({});
      final manager = SSHClientManager(
        SSHHostKeyVerifier(await LocalStorageService.init()),
        authenticationTimeout: const Duration(seconds: 10),
      );
      addTearDown(manager.dispose);
      const server = ServerProfile(
        id: 'isolated-stability',
        name: 'valhalla-test-vm',
        host: '127.0.0.1',
        port: 22023,
        username: 'valhalla',
      );
      var approvalWaited = false;
      await manager.getOrCreateClient(
        server,
        password: config['ssh_password'] as String,
        onConfirmHostKey: (_, _, fingerprint) async {
          if (!negotiatedPins.contains(fingerprint)) return false;
          await Future<void>.delayed(const Duration(seconds: 11));
          approvalWaited = true;
          return true;
        },
      );
      expect(approvalWaited, isTrue);
      final identity = await manager.executeWithLoginShell(
        server.id,
        'hostname; cat /etc/machine-id; id -un; test -e ~/fixture-ready',
      );
      expect(identity.isSuccess, isTrue);
      expect(identity.stdout.trim().split('\n'), [
        'valhalla-test-vm',
        config['machine_id'],
        'valhalla',
      ]);
      final marker =
          'valhalla-terminal-dispose-${DateTime.now().microsecondsSinceEpoch}';
      final bridge = TerminalSessionBridge(
        terminal: Terminal(maxLines: 100),
        sshClient: manager.getClient(server.id),
        serverName: server.name,
        remoteExecCommand:
            'bash -c ${cliShellQuote('printf "DISPOSE_PID=%s\\n" "\$\$"; exec -a $marker sleep 30')}',
      );
      int? ownedPid;
      try {
        await bridge.start();
        for (var attempt = 0; attempt < 50; attempt++) {
          final match = RegExp(
            r'DISPOSE_PID=(\d+)',
          ).firstMatch(bridge.readBufferText());
          if (match != null) {
            ownedPid = int.parse(match.group(1)!);
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(ownedPid, isNotNull);
        bridge.dispose();
        expect(
          (await manager.executeWithLoginShell(
            server.id,
            'printf usable',
          )).stdout,
          'usable',
        );
        var stopped = false;
        for (var attempt = 0; attempt < 15; attempt++) {
          final process = await manager.executeWithLoginShell(
            server.id,
            'ps -p $ownedPid -o args=',
          );
          if (process.stdout.trim() != '$marker 30') {
            stopped = true;
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(
          stopped,
          isTrue,
          reason:
              'Closing the terminal must release its sleeping foreground process',
        );
      } finally {
        bridge.dispose();
        if (ownedPid != null) {
          final process = await manager.executeWithLoginShell(
            server.id,
            'ps -p $ownedPid -o args=',
          );
          if (process.stdout.trim() == '$marker 30') {
            await manager.executeWithLoginShell(
              server.id,
              'kill -TERM $ownedPid',
            );
          }
        }
      }
      final output = await manager
          .executeStreaming(
            server.id,
            "printf 'password=sec'; sleep 0.05; printf 'ret\\n'; printf 'stderr\\n' >&2; exit 7",
          )
          .toList();
      expect(output.last.exitCode, 7);
      expect(output.map((e) => e.text).join(), isNot(contains('secret')));
      expect(
        output
            .where((e) => e.kind == SSHStreamKind.stderr)
            .map((e) => e.text)
            .join(),
        'stderr\n',
      );
      final ready = Completer<void>();
      final sub = manager
          .executeStreaming(
            server.id,
            "printf 'ready\\n'; sleep 30; printf 'late\\n'",
          )
          .listen((chunk) {
            if (chunk.text.contains('ready') && !ready.isCompleted) {
              ready.complete();
            }
          });
      await ready.future.timeout(const Duration(seconds: 5));
      await sub.cancel().timeout(const Duration(seconds: 2));
      expect(
        (await manager.executeWithLoginShell(server.id, 'printf alive')).stdout,
        'alive',
      );
      final service = SftpClientService(manager.getClient(server.id));
      final path =
          '/home/valhalla/ssh-stability-${DateTime.now().microsecondsSinceEpoch}.txt';
      final directory = '$path.dir';
      try {
        await service.createDirectory(directory);
        await service.writeFileContent(path, 'UTF-8 中文');
        expect(await service.readFileContent(path), 'UTF-8 中文');
        await service.rename(path, '$directory/renamed.txt');
        expect(
          (await service.listFiles(directory)).map((e) => e.name),
          contains('renamed.txt'),
        );
        await service.deleteFile('$directory/renamed.txt');
        final created = await manager.executeWithLoginShell(
          server.id,
          'head -c 1048577 /dev/zero > "$path"',
        );
        expect(created.exitCode, 0);
        await expectLater(
          service.readFileContent(path),
          throwsA(isA<SFTPException>()),
        );
      } finally {
        service.dispose();
        final cleanup = await manager.executeWithLoginShell(
          server.id,
          "rm -f -- '$path' '$directory/renamed.txt'; if test -d '$directory'; then rmdir -- '$directory'; fi",
        );
        expect(cleanup.isSuccess, isTrue);
      }
      final oldClient = manager.getClient(server.id)!;
      await expectLater(
        manager.getOrCreateClient(
          server.copyWith(port: 1),
          password: config['ssh_password'] as String,
        ),
        throwsA(isA<SSHConnectionException>()),
      );
      expect(oldClient.isClosed, isTrue);
      expect(manager.isConnected(server.id), isFalse);
      await expectLater(
        manager.getOrCreateClient(
          server,
          password: 'deliberately-wrong-fixture-password',
        ),
        throwsA(isA<SSHAuthException>()),
      );
      expect(manager.isConnected(server.id), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: credentialsPath == null
        ? 'Requires the disposable VM fixture'
        : false,
  );
}
