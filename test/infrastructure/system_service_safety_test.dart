import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';
import 'package:valhalla/infrastructure/system/service_manager.dart';

/// 记录命令并按需回放结果的 [SSHClientManager]。
///
/// 只覆写 `executeWithLoginShell`：`ServiceManager` 的全部远端交互都走这一条，
/// 其余连接管理路径在这里永远不会被触发，因此不需要真 SSH 服务器，
/// 也永远不会碰到任何真实主机。
class _RecordingSsh extends SSHClientManager {
  _RecordingSsh(LocalStorageService storage) : super(SSHHostKeyVerifier(storage));

  final commands = <String>[];

  /// 命令子串 → 结果。未命中的命令回落到 [fallback]。
  final responses = <String, SSHExecutionResult>{};
  SSHExecutionResult? fallback;

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    commands.add(command);
    for (final entry in responses.entries) {
      if (command.contains(entry.key)) return entry.value;
    }
    return fallback ??
        const SSHExecutionResult(exitCode: 0, stdout: '', stderr: '');
  }
}

SSHExecutionResult _ok(String stdout) =>
    SSHExecutionResult(exitCode: 0, stdout: stdout, stderr: '');

Future<_RecordingSsh> _manager() async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalStorageService(await SharedPreferences.getInstance());
  return _RecordingSsh(storage);
}

/// 造 N 行 journald JSON；`from` 用来造后续页。
List<String> _journalRows(int count, {int from = 1}) => [
  for (var i = from; i < from + count; i++)
    '{"__CURSOR":"s=$i","__REALTIME_TIMESTAMP":"$i","MESSAGE":"line $i",'
    '"_PID":"${1000 + i}","_SYSTEMD_UNIT":"a.service",'
    '"_SYSTEMD_INVOCATION_ID":"inv-$i"}',
];

const _units = '''
sshd.service              loaded active running OpenSSH server daemon
docker.service            loaded failed failed  Docker Application Container Engine
nginx.service             loaded inactive dead   A high performance web server
systemd-fsck-root.service loaded inactive dead   File System Integrity Check
''';

const _unitFiles = '''
nginx.service              enabled
docker.service             enabled
sshd.service               enabled
untouched.service          disabled
''';

void main() {
  group('ServiceManager catalog', () {
    test('merges live unit state with the unit-file startup table', () async {
      final ssh = await _manager();
      ssh.responses['list-unit-files'] = _ok(_unitFiles);
      ssh.responses['list-units'] = _ok(_units);

      final services = await ServiceManager(ssh).list('srv-1');

      expect(
        services.map((s) => s.name).toList(),
        ['docker.service', 'nginx.service', 'sshd.service', 'systemd-fsck-root.service',
          'untouched.service'],
        reason: 'catalog must be sorted and must include unit-file-only units',
      );

      final docker = services.firstWhere((s) => s.name == 'docker.service');
      expect(docker.state, 'failed');
      expect(docker.isFailed, isTrue);
      expect(docker.isRunning, isFalse,
        reason: 'a failed unit must never be reported as running');
      expect(docker.isEnabled, isTrue,
        reason: 'startup state is independent of the current run state');

      final untouched = services.firstWhere((s) => s.name == 'untouched.service');
      expect(untouched.state, 'not-loaded');
      expect(untouched.startup, 'disabled');
      expect(untouched.isEnabled, isFalse);
    });

    test('reports a unit whose unit-file row is missing as unknown startup',
        () async {
      final ssh = await _manager();
      ssh.responses['list-unit-files'] = _ok('sshd.service enabled\n');
      ssh.responses['list-units'] = _ok(_units);

      final services = await ServiceManager(ssh).list('srv-1');
      final docker = services.firstWhere((s) => s.name == 'docker.service');

      expect(docker.startup, 'unknown');
      expect(docker.isEnabled, isFalse,
        reason: 'an unknown startup state must not read as enabled');
    });

    test('transient and stopped states are neither running nor failed', () async {
      final ssh = await _manager();
      ssh.responses['list-unit-files'] = _ok('');
      ssh.responses['list-units'] = _ok(
        'a.service loaded activating start Starting\n'
        'b.service loaded inactive dead Stopped\n',
      );

      final services = await ServiceManager(ssh).list('srv-1');

      expect(services.first.isRunning, isFalse);
      expect(services.first.isFailed, isFalse);
      expect(services.last.isRunning, isFalse);
      expect(services.last.isFailed, isFalse);
    });
  });

  group('ServiceManager failure reporting', () {
    test('maps systemctl absence, denial and generic failure to distinct codes',
        () async {
      final ssh = await _manager();
      ssh.responses['list-units'] = const SSHExecutionResult(
        exitCode: 127,
        stdout: '',
        stderr: 'systemctl: command not found',
      );

      await expectLater(
        ServiceManager(ssh).list('srv-1'),
        throwsA(
          isA<SystemExecutionException>()
              .having((e) => e.message, 'message', 'SERVICE_UNSUPPORTED'),
        ),
      );
    });

    test('reports permission denial separately from a generic failure', () async {
      final denied = await _manager();
      denied.responses['list-units'] = const SSHExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: 'Failed to connect to bus: Access denied',
      );
      await expectLater(
        ServiceManager(denied).list('srv-1'),
        throwsA(
          isA<SystemExecutionException>()
              .having((e) => e.message, 'message', 'SERVICE_PERMISSION_DENIED'),
        ),
      );

      final broken = await _manager();
      broken.responses['list-units'] = const SSHExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: 'System has not been booted',
      );
      await expectLater(
        ServiceManager(broken).list('srv-1'),
        throwsA(
          isA<SystemExecutionException>()
              .having((e) => e.message, 'message', 'SERVICE_QUERY_FAILED')
              .having((e) => e.exitCode, 'exitCode', 1),
        ),
      );
    });

    test('a failing unit-file query fails the whole listing', () async {
      final ssh = await _manager();
      ssh.responses['list-units'] = _ok(_units);
      ssh.responses['list-unit-files'] = const SSHExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: 'Failed to connect to bus: Access denied',
      );

      await expectLater(
        ServiceManager(ssh).list('srv-1'),
        throwsA(isA<SystemExecutionException>()),
      );
      expect(ssh.commands, hasLength(2),
        reason: 'the unit-file query must actually have been attempted');
    });
  });

  group('ServiceManager injection targets', () {
    test('rejects unit names that are not exact systemd unit names', () async {
      const hostile = <String>[
        '',
        'nginx',
        'nginx.service; reboot',
        'nginx.service && id',
        r'nginx.service$(id)',
        r'nginx.service`id`',
        '-rf.service',
        '../nginx.service',
        'ng inx.service',
        'nginx.service\n',
        'nginx.SERVICE',
      ];
      for (final name in hostile) {
        expect(() => ServiceManager.validateService(name), throwsArgumentError,
            reason: 'must reject ${name.replaceAll('\n', r'\n')}');
      }
      final tooLong = '${'a' * 250}.service';
      expect(() => ServiceManager.validateService(tooLong), throwsArgumentError,
          reason: 'the unit name length is capped');
    });

    test('accepts the exact unit names systemd permits', () {
      for (final name in [
        'nginx.service',
        'sshd.service',
        'systemd-fsck-root.service',
        'docker@printer.service',
        'systemd-udevd.service',
        'a_b.service',
      ]) {
        expect(ServiceManager.validateService(name), name);
      }
    });

    test('rejects non-service units such as slices', () {
      // 目录只列 `--type=service`，所以 `.slice`/`.mount` 出现在用户输入里
      // 一定是越界的目标，必须拒绝而不是放行。
      for (final name in ['user-1000.slice', 'home.mount', 'a.target']) {
        expect(() => ServiceManager.validateService(name), throwsArgumentError,
            reason: 'must reject $name');
      }
    });

    test('rejects an action outside the allowlist before touching ssh',
        () async {
      final ssh = await _manager();
      final manager = ServiceManager(ssh);

      for (final action in ['halt', 'poweroff', 'daemon-reload', 'enable --now',
        'start; reboot', 'mask']) {
        expect(() => manager.action('srv-1', 'nginx.service', action),
            throwsArgumentError,
            reason: 'must reject $action');
      }
      expect(ssh.commands, isEmpty,
        reason: 'a rejected action must never reach the remote shell');
    });

    test('quotes the unit name and separates it with --', () async {
      final ssh = await _manager();
      await ServiceManager(ssh).action('srv-1', 'docker@printer.service', 'restart');

      expect(ssh.commands.single,
          "systemctl restart -- 'docker@printer.service'");
    });

    test('rejects a hostile service name in the action path', () async {
      final ssh = await _manager();
      await expectLater(
        () => ServiceManager(ssh).action('srv-1', "a.service'; reboot; '", 'start'),
        throwsArgumentError,
      );
      expect(ssh.commands, isEmpty);
    });
  });

  group('ServiceManager log pagination', () {
    test('the first page asks journalctl for no cursor', () async {
      final ssh = await _manager();
      ssh.responses['journalctl'] = _ok(_journalRows(3).join('\n'));

      await ServiceManager(ssh).logs('srv-1', 'a.service');

      final command = ssh.commands.single;
      expect(command, contains('--reverse'));
      expect(command, contains('--lines=200'));
      expect(command, isNot(contains('--cursor=')),
        reason: 'the first page must not pass an empty cursor to journalctl');
      expect(command, contains("--unit='a.service'"));
    });

    test('a later page passes the cursor through shell quoting', () async {
      final ssh = await _manager();
      ssh.responses['journalctl'] = _ok(_journalRows(3, from: 4).join('\n'));

      await ServiceManager(ssh)
          .logs('srv-1', 'a.service', beforeCursor: 's=3;i=3;b=3');

      expect(ssh.commands.single, contains("--cursor='s=3;i=3;b=3'"));
    });

    test('drops the cursor row so a paged fetch does not duplicate a record',
        () async {
      final ssh = await _manager();
      ssh.responses['journalctl'] = _ok([
        '{"__CURSOR":"s=3","MESSAGE":"boundary"}',
        ..._journalRows(2, from: 4),
        '',
      ].join('\n'));

      final rows = await ServiceManager(ssh)
          .logs('srv-1', 'a.service', beforeCursor: 's=3');

      expect(rows.map((r) => r['__CURSOR']).toList(), ['s=4', 's=5']);
    });

    test('keeps blank lines out and decodes every row', () async {
      final ssh = await _manager();
      ssh.responses['journalctl'] = _ok('\n${_journalRows(2).join('\n')}\n\n');

      final rows = await ServiceManager(ssh).logs('srv-1', 'a.service');

      expect(rows, hasLength(2));
      expect(rows.first['MESSAGE'], 'line 1');
    });

    test('preserves the pid and start identity of each start instance', () async {
      // journalctl 的 `_PID` + `_SYSTEMD_INVOCATION_ID` 正是「这是一次新的
      // start 实例」的判据：服务重启后 PID 与 invocation id 都会变。
      // ServiceManager 必须原样透传，调用层才能把重启画出来。
      final ssh = await _manager();
      ssh.responses['journalctl'] = _ok([
        '{"__CURSOR":"s=1","MESSAGE":"Started a.","_PID":"4200",'
            '"_SYSTEMD_INVOCATION_ID":"inv-1"}',
        '{"__CURSOR":"s=2","MESSAGE":"Stopped a.","_PID":"4200",'
            '"_SYSTEMD_INVOCATION_ID":"inv-1"}',
        '{"__CURSOR":"s=3","MESSAGE":"Started a.","_PID":"4301",'
            '"_SYSTEMD_INVOCATION_ID":"inv-2"}',
      ].join('\n'));

      final rows = await ServiceManager(ssh).logs('srv-1', 'a.service');

      expect(rows.map((r) => r['_PID']).toList(), ['4200', '4200', '4301']);
      expect(
        rows.map((r) => r['_SYSTEMD_INVOCATION_ID']).toList(),
        ['inv-1', 'inv-1', 'inv-2'],
      );
      final starts = rows.where((r) => r['MESSAGE'].toString().startsWith('Started'));
      expect(starts.map((r) => r['_SYSTEMD_INVOCATION_ID']).toSet(), {'inv-1', 'inv-2'},
        reason: 'a restart must be distinguishable from the previous start');
    });

    test('rejects a hostile cursor without reaching the remote shell', () async {
      final ssh = await _manager();
      final manager = ServiceManager(ssh);

      for (final cursor in ['s=1\nrm -rf /', 's=1\x00', 'x' * 1025]) {
        await expectLater(
          () => manager.logs('srv-1', 'a.service', beforeCursor: cursor),
          throwsArgumentError,
          reason: 'must reject $cursor',
        );
      }
      expect(ssh.commands, isEmpty);
    });

    test('rejects a hostile service name before reaching the remote shell',
        () async {
      final ssh = await _manager();
      await expectLater(
        () => ServiceManager(ssh).logs('srv-1', "a.service' ; id ; '"),
        throwsArgumentError,
      );
      expect(ssh.commands, isEmpty);
    });

    test('a failing journalctl surfaces as a query failure', () async {
      final ssh = await _manager();
      ssh.responses['journalctl'] = const SSHExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: 'No journal files were found',
      );

      await expectLater(
        ServiceManager(ssh).logs('srv-1', 'a.service'),
        throwsA(
          isA<SystemExecutionException>()
              .having((e) => e.message, 'message', 'SERVICE_QUERY_FAILED'),
        ),
      );
    });
  });
}