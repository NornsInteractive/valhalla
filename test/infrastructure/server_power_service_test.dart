import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/system/server_power_service.dart';

class _Executor implements SshCommandExecutor {
  String uid = '0';
  bool connected = true;
  Object? dispatchError;
  SSHExecutionResult result = const SSHExecutionResult(
    exitCode: 0,
    stdout: '',
    stderr: '',
  );
  final commands = <String>[];
  String? password;
  @override
  bool isConnected(String id) => connected;
  @override
  SSHClient? getClient(String id) => null;
  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String id,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    commands.add(command);
    if (command.startsWith('cat ')) {
      return const SSHExecutionResult(
        exitCode: 0,
        stdout: '11111111-1111-4111-8111-111111111111\n',
        stderr: '',
      );
    }
    if (command == 'id -u') {
      return SSHExecutionResult(exitCode: 0, stdout: uid, stderr: '');
    }
    password = sudoPassword;
    if (dispatchError != null) throw dispatchError!;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'root dispatches once and records boot identity, not verified success',
    () async {
      final fake = _Executor();
      final outcome = await ServerPowerService(
        fake,
      ).reboot('a', isCurrent: () => true);
      expect(outcome.phase, ServerPowerPhase.accepted);
      expect(outcome.bootId, '11111111-1111-4111-8111-111111111111');
      expect(fake.commands.last, "sh -c '${ServerPowerService.rebootScript}'");
      expect(fake.commands.last, isNot(contains('sudo')));
      expect(ServerPowerService.rebootScript, contains('else exec shutdown'));
    },
  );
  test(
    'sudo requests an ephemeral password and sends it only through executor stdin',
    () async {
      final fake = _Executor()
        ..uid = '1000'
        ..result = const SSHExecutionResult(
          exitCode: 1,
          stdout: '',
          stderr: 'sudo: a password is required',
        );
      final service = ServerPowerService(fake);
      expect(
        (await service.reboot('a', isCurrent: () => true)).phase,
        ServerPowerPhase.passwordRequired,
      );
      expect(fake.commands.last, startsWith('LC_ALL=C sudo -n -- '));
      fake.result = const SSHExecutionResult(
        exitCode: 0,
        stdout: '',
        stderr: '',
      );
      expect(
        (await service.reboot(
          'a',
          sudoPassword: 'secret',
          isCurrent: () => true,
        )).phase,
        ServerPowerPhase.accepted,
      );
      expect(fake.password, 'secret');
      expect(fake.commands.join(), isNot(contains('secret')));
    },
  );
  test('disconnect after dispatch is unknown and never retries', () async {
    final fake = _Executor()..dispatchError = StateError('closed');
    expect(
      (await ServerPowerService(fake).reboot('a', isCurrent: () => true)).phase,
      ServerPowerPhase.unknown,
    );
    expect(fake.commands, hasLength(3));
  });
  test(
    'changed server, invalid identity, and multiline password never dispatch',
    () async {
      final fake = _Executor();
      final service = ServerPowerService(fake);
      expect(
        (await service.reboot('a', isCurrent: () => false)).errorCode,
        'REBOOT_SERVER_CHANGED',
      );
      expect(fake.commands, hasLength(2));
      fake.commands.clear();
      fake.uid = 'bad uid';
      expect(
        (await service.reboot('a', isCurrent: () => true)).errorCode,
        'REBOOT_IDENTITY_FAILED',
      );
      expect(fake.commands, hasLength(2));
      fake.commands.clear();
      expect(
        (await service.reboot(
          'a',
          sudoPassword: 'a\nreboot',
          isCurrent: () => true,
        )).errorCode,
        'REBOOT_PASSWORD_INVALID',
      );
      expect(fake.commands, isEmpty);
    },
  );
  test('permission errors do not execute shutdown fallback', () async {
    final fake = _Executor()
      ..uid = '1000'
      ..result = const SSHExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: 'permission denied',
      );
    expect(
      (await ServerPowerService(fake).reboot('a', isCurrent: () => true)).phase,
      ServerPowerPhase.failed,
    );
    expect(fake.commands, hasLength(3));
  });

  test(
    'shutdown dispatches poweroff once and preserves unknown result',
    () async {
      final fake = _Executor();
      final service = ServerPowerService(fake);
      expect(
        (await service.shutdown('a', isCurrent: () => true)).phase,
        ServerPowerPhase.accepted,
      );
      expect(
        fake.commands.last,
        "sh -c '${ServerPowerService.shutdownScript}'",
      );
      expect(ServerPowerService.shutdownScript, contains('systemctl poweroff'));
      fake.commands.clear();
      fake.dispatchError = StateError('connection closed');
      final unknown = await service.shutdown('a', isCurrent: () => true);
      expect(unknown.phase, ServerPowerPhase.unknown);
      expect(unknown.errorCode, 'SHUTDOWN_RESULT_UNKNOWN');
      expect(fake.commands, hasLength(3));
    },
  );

  test(
    'shutdown rejects changed target and invalid password before dispatch',
    () async {
      final fake = _Executor();
      final service = ServerPowerService(fake);
      expect(
        (await service.shutdown('a', isCurrent: () => false)).errorCode,
        'SHUTDOWN_SERVER_CHANGED',
      );
      fake.commands.clear();
      expect(
        (await service.shutdown(
          'a',
          sudoPassword: 'bad\nvalue',
          isCurrent: () => true,
        )).errorCode,
        'SHUTDOWN_PASSWORD_INVALID',
      );
      expect(fake.commands, isEmpty);
    },
  );
}
