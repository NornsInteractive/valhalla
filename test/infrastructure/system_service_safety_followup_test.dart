import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valhalla/core/errors/app_exceptions.dart';
import 'package:valhalla/data/storage/local_storage_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';
import 'package:valhalla/infrastructure/ssh/ssh_host_key_verifier.dart';
import 'package:valhalla/infrastructure/system/service_manager.dart';

/// 记录命令并按需回放结果的 [SSHClientManager]。`ServiceManager` 的全部远端
/// 交互都走 `executeWithLoginShell` 这一条，因此不需要真 SSH 服务器。
class _RecordingSsh extends SSHClientManager {
  _RecordingSsh(LocalStorageService storage)
    : super(SSHHostKeyVerifier(storage));

  final commands = <String>[];
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

/// 造 N 行 journald JSON；`from` 用来造后续页，游标均为唯一 `s=$i`。
List<String> _journalRows(int count, {int from = 1}) => [
  for (var i = from; i < from + count; i++)
    '{"__CURSOR":"s=$i","__REALTIME_TIMESTAMP":"$i","MESSAGE":"line $i",'
        '"_PID":"${1000 + i}","_SYSTEMD_UNIT":"a.service",'
        '"_SYSTEMD_INVOCATION_ID":"inv-$i"}',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServiceManager systemd failure classification', () {
    // 真正的 systemd missing-init 消息里带 "not been booted with systemd"，
    // 必须归类成「本机没有 systemd」而不是笼统查询失败。
    test(
      'a real missing-systemd message maps to SERVICE_UNSUPPORTED',
      () async {
        final ssh = await _manager();
        ssh.responses['list-units'] = const SSHExecutionResult(
          exitCode: 1,
          stdout: '',
          stderr:
              'System has not been booted with systemd (PID 1) is not systemd.',
        );

        await expectLater(
          ServiceManager(ssh).list('srv-1'),
          throwsA(
            isA<SystemExecutionException>().having(
              (e) => e.message,
              'message',
              'SERVICE_UNSUPPORTED',
            ),
          ),
        );
      },
    );

    // 真正需要交互式认证时 systemd 打印 "Interactive authentication required."，
    // 这是权限问题，不能与服务缺失混为一谈。
    test('a real interactive-authentication message maps to '
        'SERVICE_PERMISSION_DENIED', () async {
      final ssh = await _manager();
      ssh.responses['list-units'] = const SSHExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: 'Interactive authentication required.',
      );

      await expectLater(
        ServiceManager(ssh).list('srv-1'),
        throwsA(
          isA<SystemExecutionException>().having(
            (e) => e.message,
            'message',
            'SERVICE_PERMISSION_DENIED',
          ),
        ),
      );
    });
  });

  group('ServiceManager action failure mapping', () {
    // start/stop/restart 之类的动作也必须像 list/logs 一样把远端错误归类：
    // 需要交互式认证时抛 SERVICE_PERMISSION_DENIED；干净的结果要原样返回，
    // 不能被吞成 void 或被改写。
    test('an interactive-auth action failure maps, a clean result passes '
        'through unchanged', () async {
      final ssh = await _manager();
      final manager = ServiceManager(ssh);

      ssh.responses['systemctl restart'] = const SSHExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: 'Interactive authentication required.',
      );
      await expectLater(
        manager.action('srv-1', 'a.service', 'restart'),
        throwsA(
          isA<SystemExecutionException>().having(
            (e) => e.message,
            'message',
            'SERVICE_PERMISSION_DENIED',
          ),
        ),
      );

      ssh.responses['systemctl restart'] = _ok('restarted');
      final result = await manager.action('srv-1', 'a.service', 'restart');
      expect(
        result.exitCode,
        0,
        reason: 'a clean result is returned unchanged',
      );
      expect(result.stdout, 'restarted');
    });
  });

  group('ServiceManager journal pagination bounds', () {
    // 旧页用 --lines=201 的闭区间游标：游标那一行必须被丢掉，净剩正好 200
    // 行，且每一行都唯一——否则翻页会出现重复记录或越界多取。
    test('a 201-line older page with an inclusive cursor yields exactly '
        '200 unique rows', () async {
      const cursor = 's=1';
      final ssh = await _manager();
      ssh.responses['journalctl'] = _ok(
        [
          '{"__CURSOR":"$cursor","MESSAGE":"boundary"}',
          ..._journalRows(200, from: 2),
        ].join('\n'),
      );

      final rows = await ServiceManager(
        ssh,
      ).logs('srv-1', 'a.service', beforeCursor: cursor);

      expect(
        ssh.commands.single,
        contains('--lines=201'),
        reason: 'an older page must ask for a 201-line inclusive window',
      );
      expect(
        rows,
        hasLength(200),
        reason: 'the inclusive cursor row is dropped, leaving exactly 200',
      );
      expect(
        rows.map((r) => r['__CURSOR']).toSet(),
        hasLength(200),
        reason: 'every returned row must be unique',
      );
      expect(
        rows.map((r) => r['__CURSOR']),
        isNot(contains(cursor)),
        reason: 'the boundary cursor row must not be duplicated',
      );
    });

    // 服务端/中间层回回远超 200 行时，解析层必须自己截断，绝不能把多余的
    // 记录吐给调用方。
    test(
      'an oversized fake journal response is capped at 200 records',
      () async {
        const cursor = 's=1';
        final ssh = await _manager();
        ssh.responses['journalctl'] = _ok(
          [
            '{"__CURSOR":"$cursor","MESSAGE":"boundary"}',
            ..._journalRows(300, from: 2),
          ].join('\n'),
        );

        final rows = await ServiceManager(
          ssh,
        ).logs('srv-1', 'a.service', beforeCursor: cursor);

        expect(
          rows.length,
          lessThanOrEqualTo(200),
          reason: 'an oversized response cannot return more than 200 records',
        );
        expect(rows, hasLength(200));
        expect(
          rows.map((r) => r['__CURSOR']).toSet(),
          hasLength(200),
          reason: 'the capped page must still be de-duplicated',
        );
      },
    );
  });
}
