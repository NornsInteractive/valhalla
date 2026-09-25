import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/data/models/server_profile.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';
import 'package:valhalla/infrastructure/system/server_power_service.dart';

class _CountPowerDispatches implements SshCommandExecutor {
  _CountPowerDispatches(this.ssh);
  final SSHClientManager ssh;
  int powerDispatches = 0;
  @override
  SSHClient? getClient(String id) => ssh.getClient(id);
  @override
  bool isConnected(String id) => ssh.isConnected(id);
  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String id,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) {
    if (command.contains(ServerPowerService.rebootScript) ||
        command.contains(ServerPowerService.shutdownScript)) {
      powerDispatches++;
    }
    return ssh.executeWithLoginShell(
      id,
      command,
      timeout: timeout,
      sudoPassword: sudoPassword,
    );
  }

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String id,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) => ssh.executeStreaming(
    id,
    command,
    timeout: timeout,
    sudoPassword: sudoPassword,
  );
}

/// Never run concurrently with other VM tests. Opt-in requires BOTH variables:
/// VALHALLA_VM_POWER_TEST=1
/// VALHALLA_OPERATIONS_VM_CREDENTIALS=/tmp/valhalla-test-vm/credentials.json
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final credentialsPath =
      Platform.environment['VALHALLA_OPERATIONS_VM_CREDENTIALS'];
  final enabled =
      Platform.environment['VALHALLA_VM_POWER_TEST'] == '1' &&
      credentialsPath != null;
  test(
    'isolated VM reboot dispatches exactly once and only boot-id change verifies it',
    () async {
      final config =
          jsonDecode(await File(credentialsPath!).readAsString())
              as Map<String, dynamic>;
      expect(config['ssh_host'], '127.0.0.1');
      expect(config['ssh_port'], 22023);
      expect(config['ssh_user'], 'valhalla');
      expect(config['machine_id'], isNotEmpty);
      final fingerprints = (config['host_fingerprints'] as List).cast<String>();
      expect(fingerprints, isNotEmpty);
      SharedPreferences.setMockInitialValues({});
      final ssh = SSHClientManager(
        SSHHostKeyVerifier(await LocalStorageService.init()),
      );
      addTearDown(ssh.dispose);
      const server = ServerProfile(
        id: 'isolated-power-vm',
        name: 'valhalla-test-vm',
        host: '127.0.0.1',
        port: 22023,
        username: 'valhalla',
      );
      Future<void> connect() => ssh.getOrCreateClient(
        server,
        password: config['ssh_password'] as String,
        onConfirmHostKey: (_, _, fingerprint) async =>
            fingerprints.contains(fingerprint),
      );
      await connect();
      final identity = await ssh.executeWithLoginShell(
        server.id,
        'hostname; cat /etc/machine-id; test -e ~/fixture-ready',
      );
      expect(identity.isSuccess, true);
      expect(identity.stdout.trim().split('\n'), [
        'valhalla-test-vm',
        config['machine_id'],
      ]);
      final executor = _CountPowerDispatches(ssh);
      final service = ServerPowerService(executor);
      final before = await service.readBootId(server.id);
      expect(before, isNotNull);
      final capturedClient = ssh.getClient(server.id);

      // This is the sole destructive call. Connection/boot polling never redispatches.
      final outcome = await service.reboot(
        server.id,
        isCurrent: () => identical(ssh.getClient(server.id), capturedClient),
      );
      expect(
        outcome.phase,
        anyOf(ServerPowerPhase.accepted, ServerPowerPhase.unknown),
      );
      expect(outcome.phase, isNot(ServerPowerPhase.verified));
      expect(outcome.bootId, before);
      expect(executor.powerDispatches, 1);
      // Metadata only: no credentials or command output go into acceptance logs.
      // ignore: avoid_print
      print(
        'power dispatch phase=${outcome.phase.name} errorCode=${outcome.errorCode} bootBefore=$before',
      );

      String? after;
      final deadline = DateTime.now().add(const Duration(minutes: 3));
      while (DateTime.now().isBefore(deadline)) {
        ssh.disconnect(server.id);
        await Future<void>.delayed(const Duration(seconds: 2));
        try {
          await connect();
          after = await service.readBootId(server.id);
          if (after != null && after != before) break;
        } catch (_) {
          // During reboot an SSH refusal/disconnect is expected; retry reads only.
        }
      }
      expect(after, isNotNull);
      expect(
        after,
        isNot(before),
        reason: 'Accepted/unknown is not proof of reboot',
      );
      final returnedIdentity = await ssh.executeWithLoginShell(
        server.id,
        'hostname; cat /etc/machine-id; test -e ~/fixture-ready',
      );
      expect(returnedIdentity.isSuccess, true);
      expect(returnedIdentity.stdout.trim().split('\n'), [
        'valhalla-test-vm',
        config['machine_id'],
      ]);
      expect(executor.powerDispatches, 1);
      expect(ssh.isConnected(server.id), true);
      // ignore: avoid_print
      print(
        'power verified bootAfter=$after dispatchCount=${executor.powerDispatches} VM remains running',
      );
    },
    skip: enabled
        ? false
        : 'Requires separate VALHALLA_VM_POWER_TEST=1 and isolated VM credentials',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
