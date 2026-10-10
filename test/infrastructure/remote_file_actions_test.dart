import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/infrastructure/sftp/remote_file_actions.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

/// 只记录命令、不做任何真实远端动作的替身。
class _RecordingExecutor implements SshCommandExecutor {
  _RecordingExecutor();

  final List<({String serverId, String command})> calls = [];
  SSHExecutionResult result = const SSHExecutionResult(
    exitCode: 0,
    stdout: '',
    stderr: '',
  );
  Object? throwing;

  @override
  bool isConnected(String serverId) => true;

  @override
  SSHClient? getClient(String serverId) => null;

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async {
    calls.add((serverId: serverId, command: command));
    final failure = throwing;
    if (failure != null) throw failure;
    return result;
  }

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) => const Stream<SSHExecutionChunk>.empty();
}

String _reasonOf(void Function() body) {
  try {
    body();
  } on FormatException catch (error) {
    return error.message.toString();
  }
  return '<no FormatException>';
}

void main() {
  group('RemoteFileActions.command 参数校验', () {
    test('只接受 copy / move，delete 与 download 直接拒绝', () {
      expect(
        () => RemoteFileActions.command(
          RemoteFileAction.delete,
          '/srv/a.txt',
          '/srv',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => RemoteFileActions.command(
          RemoteFileAction.download,
          '/srv/a.txt',
          '/srv',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        RemoteFileActions.command(
          RemoteFileAction.copy,
          '/srv/a.txt',
          '/var/backups',
        ),
        contains('cp -a'),
      );
      expect(
        RemoteFileActions.command(
          RemoteFileAction.move,
          '/srv/a.txt',
          '/var/backups',
        ),
        contains('mv -n -T'),
      );
    });

    test('相对路径、空字节、文件根目录都被拒绝', () {
      for (final source in ['srv/a.txt', '', '/srv/a\x00.txt']) {
        expect(
          _reasonOf(
            () => RemoteFileActions.command(
              RemoteFileAction.copy,
              source,
              '/var/backups',
            ),
          ),
          'FILE_PATH_INVALID',
          reason: '源路径 $source 必须被拒绝',
        );
      }
      expect(
        _reasonOf(
          () => RemoteFileActions.command(
            RemoteFileAction.copy,
            '/srv/a.txt',
            'backups',
          ),
        ),
        'FILE_PATH_INVALID',
      );
      expect(
        _reasonOf(
          () => RemoteFileActions.command(
            RemoteFileAction.copy,
            '/',
            '/var/backups',
          ),
        ),
        'FILE_ROOT_OPERATION_DENIED',
      );
    });

    test('目标是源自身或其后代时拒绝，兄弟目录允许', () {
      expect(
        _reasonOf(
          () => RemoteFileActions.command(
            RemoteFileAction.copy,
            '/srv/app.log',
            '/srv',
          ),
        ),
        'FILE_TARGET_IS_SOURCE',
      );
      expect(
        _reasonOf(
          () => RemoteFileActions.command(
            RemoteFileAction.move,
            '/srv/app.log',
            '/srv/app.log',
          ),
        ),
        'FILE_TARGET_IS_SOURCE',
      );
      expect(
        _reasonOf(
          () => RemoteFileActions.command(
            RemoteFileAction.copy,
            '/srv/tree',
            '/srv/tree/inner',
          ),
        ),
        'FILE_TARGET_IS_SOURCE',
        reason: '复制目录到自己的后代会造成无限递归，必须在本地就拒绝',
      );
      expect(
        _reasonOf(
          () => RemoteFileActions.command(
            RemoteFileAction.move,
            '/srv/tree',
            '/srv/tree',
          ),
        ),
        'FILE_TARGET_IS_SOURCE',
      );

      final sibling = RemoteFileActions.command(
        RemoteFileAction.copy,
        '/srv/app.log',
        '/var/backups',
      );
      expect(sibling, contains("dest='/var/backups/app.log'"));
      expect(
        RemoteFileActions.command(
          RemoteFileAction.copy,
          '/srv/app.log',
          '/srv/app.log.d',
        ),
        isNotEmpty,
      );
    });

    test('命令带 set -eu、不覆盖语义与目录存在性前置检查', () {
      final script = RemoteFileActions.command(
        RemoteFileAction.copy,
        '/srv/app.log',
        '/var/backups',
      );
      expect(script, contains('set -eu'));
      expect(script, contains(r'[ -d "$parent" ] || exit 1'));
      expect(script, contains('mv -n -T'));
      expect(script, isNot(contains('--force')));
      expect(script, isNot(contains(r'rm -rf -- "$src"')));
    });

    test('路径中的单引号被转义，不会逃出单引号上下文', () {
      final script = RemoteFileActions.command(
        RemoteFileAction.move,
        "/srv/it's a file.log",
        "/var/backups/it's",
      );
      expect(script, contains(r"src='/srv/it'\''s a file.log'"));
      expect(script, contains(r"parent='/var/backups/it'\''s'"));
      expect(
        script,
        isNot(contains("src='/srv/it's a file.log'")),
        reason: '未转义的单引号会让远端命令被重新切词',
      );
    });
  });

  group('RemoteFileActions.execute 结果映射', () {
    late _RecordingExecutor executor;
    late RemoteFileActions actions;

    setUp(() {
      executor = _RecordingExecutor();
      actions = RemoteFileActions(executor);
    });

    test('VALHALLA_FILE_COMPLETED -> completed 且不带错误', () async {
      executor.result = const SSHExecutionResult(
        exitCode: 0,
        stdout: 'noise\n\nVALHALLA_FILE_COMPLETED\n',
        stderr: '',
      );
      final result = await actions.execute(
        'srv-1',
        RemoteFileAction.copy,
        '/srv/a.txt',
        '/var/backups',
      );
      expect(result.outcome, RemoteFileOutcome.completed);
      expect(result.error, isNull);
      expect(result.path, '/srv/a.txt');
      expect(executor.calls.single.serverId, 'srv-1');
    });

    test('VALHALLA_FILE_SKIPPED -> skipped + FILE_TARGET_EXISTS', () async {
      executor.result = const SSHExecutionResult(
        exitCode: 0,
        stdout: 'VALHALLA_FILE_SKIPPED',
        stderr: '',
      );
      final result = await actions.execute(
        'srv-1',
        RemoteFileAction.move,
        '/srv/a.txt',
        '/var/backups',
      );
      expect(result.outcome, RemoteFileOutcome.skipped);
      expect(result.error, 'FILE_TARGET_EXISTS');
    });

    test('非零退出码 -> failed 并带上退出码与 stderr', () async {
      executor.result = const SSHExecutionResult(
        exitCode: 1,
        stdout: '',
        stderr: 'mv: cannot move\n',
      );
      final result = await actions.execute(
        'srv-1',
        RemoteFileAction.move,
        '/srv/a.txt',
        '/var/backups',
      );
      expect(result.outcome, RemoteFileOutcome.failed);
      expect(result.error, contains('FILE_OPERATION_FAILED'));
      expect(result.error, contains('exit 1'));
      expect(result.error, contains('cannot move'));
    });

    test('退出码为 0 但没有完成标记时不得声称成功', () async {
      executor.result = const SSHExecutionResult(
        exitCode: 0,
        stdout: 'something else entirely',
        stderr: '',
      );
      final result = await actions.execute(
        'srv-1',
        RemoteFileAction.copy,
        '/srv/a.txt',
        '/var/backups',
      );
      expect(result.outcome, RemoteFileOutcome.failed);
    });

    test('执行器抛异常时异常向上传播，由调用方记为单项失败', () async {
      executor.throwing = StateError('channel closed');
      await expectLater(
        actions.execute('srv-1', RemoteFileAction.copy, '/a', '/b'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('RemoteFileActions.command 生成的脚本语义（临时目录内本地执行）', () {
    late Directory root;
    late bool coreutilsReady;

    setUpAll(() {
      coreutilsReady =
          !Platform.isWindows &&
          Process.runSync('sh', [
                '-c',
                'command -v mktemp >/dev/null && command -v realpath >/dev/null && command -v cp >/dev/null && command -v mv >/dev/null && cp --version | grep -q "GNU"',
              ]).exitCode ==
              0;
    });

    setUp(() {
      // 只在新建的临时目录里建夹具，绝不触碰用户文件。
      root = Directory.systemTemp.createTempSync(
        'valhalla_remote_file_actions_',
      );
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    ProcessResult runScript(
      RemoteFileAction action,
      String source,
      String target,
    ) {
      return Process.runSync('sh', [
        '-c',
        RemoteFileActions.command(action, source, target),
      ], workingDirectory: root.path);
    }

    void writeFile(String relative, String content) {
      final file = File('${root.path}$relative');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    test('copy 复制普通文件并回显 COMPLETED', () {
      if (!coreutilsReady) {
        markTestSkipped('需要 GNU coreutils 与 sh 才能在本地复现远端脚本');
        return;
      }
      writeFile('/srv/app.log', 'hello');
      Directory('${root.path}/var/backups').createSync(recursive: true);

      final result = runScript(
        RemoteFileAction.copy,
        '${root.path}/srv/app.log',
        '${root.path}/var/backups',
      );
      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout.trimRight(), endsWith('VALHALLA_FILE_COMPLETED'));
      expect(
        File('${root.path}/var/backups/app.log').readAsStringSync(),
        'hello',
      );
      expect(
        File('${root.path}/srv/app.log').existsSync(),
        isTrue,
        reason: 'copy 不得移动或删除源文件',
      );
    });

    test('copy 遇到已存在的目标时跳过且不覆盖内容', () {
      if (!coreutilsReady) return markTestSkipped('需要 GNU coreutils 与 sh');
      writeFile('/srv/app.log', 'fresh');
      writeFile('/var/backups/app.log', 'original');

      final result = runScript(
        RemoteFileAction.copy,
        '${root.path}/srv/app.log',
        '${root.path}/var/backups',
      );
      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout.trimRight(), endsWith('VALHALLA_FILE_SKIPPED'));
      expect(
        File('${root.path}/var/backups/app.log').readAsStringSync(),
        'original',
      );
    });

    test('move 移动文件并回显 COMPLETED', () {
      if (!coreutilsReady) return markTestSkipped('需要 GNU coreutils 与 sh');
      writeFile('/srv/app.log', 'payload');
      Directory('${root.path}/var/backups').createSync(recursive: true);

      final result = runScript(
        RemoteFileAction.move,
        '${root.path}/srv/app.log',
        '${root.path}/var/backups',
      );
      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout.trimRight(), endsWith('VALHALLA_FILE_COMPLETED'));
      expect(
        File('${root.path}/var/backups/app.log').readAsStringSync(),
        'payload',
      );
      expect(File('${root.path}/srv/app.log').existsSync(), isFalse);
    });

    test('源缺失、目标目录缺失都失败且不产生目标文件', () {
      if (!coreutilsReady) return markTestSkipped('需要 GNU coreutils 与 sh');
      Directory('${root.path}/var/backups').createSync(recursive: true);

      final missing = runScript(
        RemoteFileAction.copy,
        '${root.path}/srv/none.log',
        '${root.path}/var/backups',
      );
      expect(missing.exitCode, isNot(0));
      expect(missing.stdout, isNot(contains('VALHALLA_FILE_')));
      expect(File('${root.path}/var/backups/none.log').existsSync(), isFalse);

      final missingDir = runScript(
        RemoteFileAction.copy,
        '${root.path}/srv/app.log',
        '${root.path}/var/absent',
      );
      expect(missingDir.exitCode, isNot(0));
    });

    test('递归复制目录保留结构，且不跟随符号链接展开内容', () {
      if (!coreutilsReady) return markTestSkipped('需要 GNU coreutils 与 sh');
      writeFile('/srv/tree/a.txt', 'A');
      writeFile('/srv/tree/nested/b.txt', 'B');
      Link(
        '${root.path}/srv/tree/link.txt',
      ).createSync('${root.path}/var/backups/app.log');
      Directory('${root.path}/var/backups').createSync(recursive: true);
      writeFile('/var/backups/app.log', 'target');

      final result = runScript(
        RemoteFileAction.copy,
        '${root.path}/srv/tree',
        '${root.path}/var/backups',
      );
      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout.trimRight(), endsWith('VALHALLA_FILE_COMPLETED'));
      expect(
        File('${root.path}/var/backups/tree/a.txt').readAsStringSync(),
        'A',
      );
      expect(
        File('${root.path}/var/backups/tree/nested/b.txt').readAsStringSync(),
        'B',
      );
      final copiedLink = Link('${root.path}/var/backups/tree/link.txt');
      expect(copiedLink.existsSync(), isTrue);
      expect(
        copiedLink.targetSync(),
        '${root.path}/var/backups/app.log',
        reason: '符号链接必须原样复制，不能把目标内容展开进目录树',
      );
    });

    test('经由符号链接指向后代目录时脚本仍然拒绝执行', () {
      if (!coreutilsReady) return markTestSkipped('需要 GNU coreutils 与 sh');
      // 静态检查看不出这条：/srv/link 是指向 /srv/real 的符号链接，
      // 因此 /srv/link/inner 在真实路径上就是 /srv/real/inner。
      writeFile('/srv/real/a.txt', 'A');
      Directory('${root.path}/srv/real/inner').createSync(recursive: true);
      Link('${root.path}/srv/link').createSync('${root.path}/srv/real');

      final result = runScript(
        RemoteFileAction.copy,
        '${root.path}/srv/real',
        '${root.path}/srv/link/inner',
      );
      expect(result.exitCode, isNot(0));
      expect(
        Directory('${root.path}/srv/real/inner/real').existsSync(),
        isFalse,
        reason: '不得把目录复制进自己的后代',
      );
    });

    test('直接指向自身后代的目录在生成命令阶段就被拒绝', () {
      if (!coreutilsReady) return markTestSkipped('需要 GNU coreutils 与 sh');
      writeFile('/srv/tree/a.txt', 'A');
      Directory('${root.path}/srv/tree/inner').createSync(recursive: true);

      expect(
        _reasonOf(
          () => runScript(
            RemoteFileAction.copy,
            '${root.path}/srv/tree',
            '${root.path}/srv/tree/inner',
          ),
        ),
        'FILE_TARGET_IS_SOURCE',
      );
      expect(File('${root.path}/srv/tree/inner/tree').existsSync(), isFalse);
    });

    test('临时暂存目录在结束后被清理', () {
      if (!coreutilsReady) return markTestSkipped('需要 GNU coreutils 与 sh');
      writeFile('/srv/app.log', 'hello');
      Directory('${root.path}/var/backups').createSync(recursive: true);

      runScript(
        RemoteFileAction.copy,
        '${root.path}/srv/app.log',
        '${root.path}/var/backups',
      );
      final leftovers = Directory('${root.path}/var/backups')
          .listSync()
          .map((entry) => entry.path.split('/').last)
          .where((name) => name.startsWith('.valhalla-copy.'))
          .toList();
      expect(leftovers, isEmpty);
    });
  });
}
