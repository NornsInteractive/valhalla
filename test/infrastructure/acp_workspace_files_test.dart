import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/acp/acp_workspace_files.dart';

/// 远端工作目录读取的边界回归测试。
///
/// 只用内存 fake SSH：docker 目标走 `client.execute`（NUL 分隔的 find 输出），
/// 覆盖路径规范化/拒绝、MIME 判定、目录列表排序与根目录行为、
/// 读取限额以及取消（close）语义。
void main() {
  AgentProfile dockerProfile() => AgentProfile(
    id: 'builtin-codex',
    serverId: 'srv-1',
    name: 'codex',
    description: 'test',
    cliCommand: 'cli',
    acpCommand: 'acp --stdio',
    executionTarget: 'docker',
    containerBinding: 'name',
    containerReference: 'valhalla-agent',
  );

  /// find -printf '%f\\0%y\\0%s\\0%T@\\0' 的一条记录。
  String record(
    String name, {
    bool directory = false,
    int size = 1,
    int mtime = 1756000000,
  }) => '$name\u0000${directory ? 'd' : 'f'}\u0000$size\u0000$mtime\u0000';

  group('normalize', () {
    test('绝对路径被规范化，去掉重复斜杠与 .', () {
      expect(AcpWorkspaceFiles.normalize('/root'), '/root');
      expect(AcpWorkspaceFiles.normalize('/root//work/'), '/root/work');
      expect(AcpWorkspaceFiles.normalize('/root/./work'), '/root/work');
      expect(AcpWorkspaceFiles.normalize('/root/work/..'), '/root');
      expect(AcpWorkspaceFiles.normalize('/'), '/');
    });

    test('相对路径、换行、NUL 一律拒绝（路径注入防护）', () {
      expect(
        () => AcpWorkspaceFiles.normalize('root/work'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => AcpWorkspaceFiles.normalize('../etc'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => AcpWorkspaceFiles.normalize('/root\nrm -rf /'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => AcpWorkspaceFiles.normalize('/root\u0000/etc'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => AcpWorkspaceFiles.normalize(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('父级导航被折叠，绝不会逃出根目录', () {
      expect(AcpWorkspaceFiles.normalize('/..'), '/');
      expect(AcpWorkspaceFiles.normalize('/root/../..'), '/');
      expect(AcpWorkspaceFiles.normalize('/../etc/passwd'), '/etc/passwd');
      expect(
        AcpWorkspaceFiles.normalize('/root/work/../../../etc').startsWith('/'),
        isTrue,
      );
    });

    test(r'含空格、引号、$ 的合法目录名保持原样（后续会被 shell 引号保护）', () {
      expect(
        AcpWorkspaceFiles.normalize(r"/root/my work/it's $dir"),
        r"/root/my work/it's $dir",
      );
    });
  });

  group('mimeType', () {
    test('常见图片扩展名映射为 image/*', () {
      expect(AcpWorkspaceFiles.mimeType('a.png'), 'image/png');
      expect(AcpWorkspaceFiles.mimeType('a.JPG'), 'image/jpeg');
      expect(AcpWorkspaceFiles.mimeType('a.jpeg'), 'image/jpeg');
      expect(AcpWorkspaceFiles.mimeType('a.webp'), 'image/webp');
      expect(AcpWorkspaceFiles.mimeType('a.gif'), 'image/gif');
      expect(AcpWorkspaceFiles.mimeType('a.bmp'), 'image/bmp');
    });

    test('可预览文本映射为 text/plain，其余为 null（不可附加）', () {
      expect(AcpWorkspaceFiles.mimeType('notes.md'), 'text/plain');
      expect(AcpWorkspaceFiles.mimeType('main.dart'), 'text/plain');
      expect(AcpWorkspaceFiles.mimeType('archive.zip'), isNull);
      expect(AcpWorkspaceFiles.mimeType('binary.bin'), isNull);
      expect(AcpWorkspaceFiles.mimeType('noext'), isNull);
    });

    test('.txt.png 只按最后一个扩展名判定，不会被伪装绕过', () {
      expect(AcpWorkspaceFiles.mimeType('evil.png.txt'), 'text/plain');
      expect(AcpWorkspaceFiles.mimeType('evil.txt.png'), 'image/png');
    });
  });

  group('docker 目标下的 list / read', () {
    late _FakeExecClient client;
    late AcpWorkspaceFiles files;

    setUp(() {
      client = _FakeExecClient();
      files = AcpWorkspaceFiles(client, dockerProfile());
    });

    tearDown(() => files.close());

    test('NUL 字段解析，目录优先再按名称排序，根目录不列 . 与 ..', () async {
      client.setStdout(
        'find',
        utf8.encode(
          record('readme.md', size: 12) +
              record('.', directory: true, size: 4096) +
              record('..', directory: true, size: 4096) +
              record('src', directory: true, size: 4096) +
              record('Assets', directory: true, size: 4096) +
              record('main.dart', size: 4096),
        ),
      );

      final items = await files.list('/root');

      expect(items.map((item) => item.name), [
        'Assets',
        'src',
        'main.dart',
        'readme.md',
      ]);
      expect(items.where((item) => item.isDirectory).map((i) => i.name), [
        'Assets',
        'src',
      ]);
      expect(items.first.path, '/root/Assets');
      expect(items.first.sizeBytes, 4096);
      expect(items.first.formattedSize, isNotEmpty);
      expect(items.last.modifiedEpoch, 1756000000);
      expect(client.commandsFor('find').last, contains("'/root'"));
    });

    test('文件名带空格、引号、换行时按 NUL 字段保真', () async {
      client.setStdout(
        'find',
        utf8.encode(record('my report (final).md', size: 7)),
      );

      final items = await files.list('/root/work');
      expect(items.single.name, 'my report (final).md');
      expect(items.single.path, '/root/work/my report (final).md');
      expect(items.single.sizeBytes, 7);
    });

    test('特殊字符路径被 shell 引号包裹，不做名字插值', () async {
      client.setStdout('find', Uint8List(0));
      await files.list(r"/root/it's \$dir");
      final command = client.commandsFor('find').last;
      expect(command, contains("'/root/it"), reason: '路径必须整体单引号');
      expect(command, contains(r'\$dir'), reason: r'$ 不得被 shell 展开');
      expect(command, isNot(contains(' && rm')));
      expect(command, contains('test -d'));
      expect(command, contains('test -r'));
    });

    test('缺少字段的残缺记录被忽略，不产生半截条目', () async {
      client.setStdout(
        'find',
        utf8.encode('${record('good', size: 1)}truncated\u0000f\u0000'),
      );
      final items = await files.list('/root');
      expect(items.map((item) => item.name), ['good']);
    });

    test('非法路径在发起任何远端命令之前就被拒绝', () async {
      await expectLater(
        files.list('relative/path'),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        files.read('/root/x\nid', 1024),
        throwsA(isA<ArgumentError>()),
      );
      expect(client.commands, isEmpty);
    });

    test('读取超过限额时报 ACP_ATTACHMENT_TOO_LARGE', () async {
      client.setStdout('head', Uint8List(64));
      await expectLater(
        files.read('/root/big.bin', 32),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ACP_ATTACHMENT_TOO_LARGE',
          ),
        ),
      );
    });

    test('读取远端命令失败时报 ACP_FILE_READ_FAILED', () async {
      client.setStdout('head', Uint8List(0));
      client.exitCode = 1;
      await expectLater(
        files.read('/root/missing.txt', 1024),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ACP_FILE_READ_FAILED',
          ),
        ),
      );
    });

    test('close 之后所有读取立即以 ACP_FILE_READ_CANCELLED 失败', () async {
      files.close();
      await expectLater(
        files.read('/root/x.txt', 1024),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'ACP_FILE_READ_CANCELLED',
          ),
        ),
      );
      await expectLater(files.list('/root'), throwsA(isA<StateError>()));
      await expectLater(files.defaultDirectory(), throwsA(isA<StateError>()));
      expect(client.commands, isEmpty);
    });
  });
}

/// 记录命令并按关键字返回可配置输出的最小 SSH 客户端。
class _FakeExecClient implements SSHClient {
  final List<String> commands = [];
  final Map<String, Uint8List> _stdout = {};
  int exitCode = 0;

  /// `pwd -P` 的输出，单独配置。
  Uint8List pwdOutput = Uint8List(0);

  void setStdout(String keyword, Uint8List value) => _stdout[keyword] = value;

  List<String> commandsFor(String keyword) => commands
      .where((command) => command.contains(keyword))
      .toList(growable: false);

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) {
    commands.add(command);
    final out = command.contains('pwd -P')
        ? pwdOutput
        : _stdout.entries
              .firstWhere(
                (entry) => command.contains(entry.key),
                orElse: () => MapEntry(' ', Uint8List(0)),
              )
              .value;
    return Future<SSHSession>.value(_FakeSession(out, exitCode));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSession implements SSHSession {
  _FakeSession(Uint8List out, this._exitCode) {
    _stdout.add(out);
    scheduleMicrotask(_finish);
  }

  final int? _exitCode;
  final _stdout = StreamController<Uint8List>();
  final _stderr = StreamController<Uint8List>();
  final _done = Completer<void>();
  bool _finished = false;

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    if (!_stdout.isClosed) await _stdout.close();
    if (!_stderr.isClosed) await _stderr.close();
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  Future<void> get done => _done.future;

  @override
  int? get exitCode => _exitCode;

  @override
  void close() {
    if (_finished) return;
    _finished = true;
    if (!_done.isCompleted) _done.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
