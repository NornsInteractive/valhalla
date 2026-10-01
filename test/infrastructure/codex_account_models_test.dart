import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/cli/codex_account_models.dart';
import 'package:valhalla/infrastructure/cli/codex_model_authorization.dart';

/// 契约 1：默认 ACP Codex 目录来自 CodexAccountModels.query。
///
/// 只覆盖纯解析 + 本地命令构造 + 用假 SSH 通道驱动的边界与关闭语义。
/// 不触碰真实 HTTPS、真实凭据或真实会话。
void main() {
  AgentProfile profile({String executionTarget = 'host', String? container}) =>
      AgentProfile(
        id: 'builtin-codex',
        serverId: 'srv-1',
        name: 'codex',
        description: 'codex',
        cliCommand: 'codex',
        acpCommand: 'acp --stdio',
        executionTarget: executionTarget,
        containerBinding: 'name',
        containerReference: container,
      );

  final key = sha256.convert(utf8.encode('subject-1:acct-1')).toString();

  group('CodexAccountModels.parse：账户目录', () {
    test('只接受 visibility=list 的账户模型，其余被过滤', () {
      final caps = CodexAccountModels.parse({
        'accountKey': key,
        'models': [
          {
            'slug': 'gpt-5-codex',
            'display_name': 'GPT-5 Codex',
            'visibility': 'list',
          },
          {'slug': 'hidden', 'display_name': 'Hidden', 'visibility': 'hidden'},
          {'slug': 'no-visibility', 'display_name': 'No visibility'},
          {'slug': 'gpt-5', 'display_name': 'GPT-5', 'visibility': 'list'},
        ],
      });

      expect(caps.models.map((option) => option.id), ['gpt-5-codex', 'gpt-5']);
      expect(caps.models.first.label, 'GPT-5 Codex');
      expect(caps.catalogAccountKey, key);
    });

    test('顺序原样保留，slug 重复时首见优先', () {
      final caps = CodexAccountModels.parse({
        'models': [
          {'slug': 'z-model', 'display_name': 'Z', 'visibility': 'list'},
          {'slug': 'a-model', 'display_name': 'A', 'visibility': 'list'},
          {
            'slug': 'z-model',
            'display_name': 'Z duplicate',
            'visibility': 'list',
          },
        ],
      });

      expect(caps.models.map((option) => option.id), ['z-model', 'a-model']);
      expect(caps.models.first.label, 'Z', reason: '去重保留第一次出现的展示名');
    });

    test('缺字段或空 slug 的条目被静默丢弃', () {
      final caps = CodexAccountModels.parse({
        'models': [
          'not-a-map',
          {'slug': '', 'display_name': 'Empty', 'visibility': 'list'},
          {'slug': 'no-name', 'visibility': 'list'},
          {'display_name': 'No slug', 'visibility': 'list'},
          {'slug': 'ok', 'display_name': 'OK', 'visibility': 'list'},
        ],
      });

      expect(caps.models.map((option) => option.id), ['ok']);
    });

    test('API-key 的 data[] 不会被误当成账户目录', () {
      // /v1/models 的 API-key 形状是 data[]；账户目录是 models[]。
      expect(
        () => CodexAccountModels.parse({
          'data': [
            {'id': 'gpt-5-codex', 'object': 'model'},
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'AGENT_MODEL_INVALID_RESPONSE',
          ),
        ),
      );
    });

    test('models 不是列表时报固定无效响应码', () {
      expect(
        () => CodexAccountModels.parse({'models': 'nope'}),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'AGENT_MODEL_INVALID_RESPONSE',
          ),
        ),
      );
    });

    test('远端错误码映射成固定码，toString 不泄漏响应体', () {
      try {
        CodexAccountModels.parse({
          'error': 'AGENT_MODEL_AUTH_UNAVAILABLE',
          'accountKey': key,
          'body': 'Bearer sk-secret raw-http-body',
        });
        fail('必须抛出 ModelCatalogQueryException');
      } on ModelCatalogQueryException catch (error) {
        expect(error.code, 'AGENT_MODEL_AUTH_UNAVAILABLE');
        expect(error.accountKey, key);
        expect(error.toString(), 'AGENT_MODEL_AUTH_UNAVAILABLE');
        expect(error.toString(), isNot(contains('sk-secret')));
        expect(error.toString(), isNot(contains('Bearer')));
      }
    });

    test('非固定格式的 error 不被当成受控错误码', () {
      expect(
        () => CodexAccountModels.parse({'error': 'boom: token=abc'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('accountKey 只接受 64 位十六进制，否则为 null', () {
      for (final bad in ['short', 'z' * 64, 'g${'0' * 63}', 'a' * 65]) {
        expect(
          CodexAccountModels.parse({
            'accountKey': bad,
            'models': const [],
          }).catalogAccountKey,
          isNull,
          reason: '非法 accountKey 必须被拒绝而不是原样透传',
        );
      }
      expect(
        CodexAccountModels.parse({'models': const []}).catalogAccountKey,
        isNull,
      );
    });
  });

  group('CodexAccountModels.query：通道边界与关闭', () {
    test('成功时跳过横幅、读取末尾 JSON、排空 stderr 并关闭通道', () async {
      final session = _FakeSession()
        ..pushLine('bash: no job control in this shell')
        ..pushLine(
          jsonEncode({
            'accountKey': key,
            'models': [
              {
                'slug': 'gpt-5-codex',
                'display_name': 'GPT-5 Codex',
                'visibility': 'list',
              },
            ],
          }),
        )
        ..finishStdout()
        ..pushStderr('benign banner')
        ..finishStderr()
        ..exitCode = 0
        ..completeDone();
      final ssh = _FakeSsh(session);

      final caps = await CodexAccountModels.query(ssh, profile());

      expect(caps.models.single.id, 'gpt-5-codex');
      expect(caps.catalogAccountKey, key);
      expect(session.closeCount, 1, reason: '成功路径必须关闭 SSH 通道');
      expect(ssh.commands.single, contains('node -e'));
    });

    test('非零退出码报固定错并关闭通道', () async {
      final session = _FakeSession()
        ..pushLine('{"models":[]}')
        ..finishStdout()
        ..exitCode = 3
        ..completeDone();

      await expectLater(
        CodexAccountModels.query(_FakeSsh(session), profile()),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'AGENT_MODEL_RUNTIME_UNAVAILABLE',
          ),
        ),
      );
      expect(session.closeCount, 1);
    });

    test('无有效 JSON 行时报固定无效响应并关闭通道', () async {
      final session = _FakeSession()
        ..pushLine('just some banner text')
        ..finishStdout()
        ..exitCode = 0
        ..completeDone();

      await expectLater(
        CodexAccountModels.query(_FakeSsh(session), profile()),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'AGENT_MODEL_INVALID_RESPONSE',
          ),
        ),
      );
      expect(session.closeCount, 1);
    });

    test('超过 2MiB 的响应被拒绝并关闭通道', () async {
      final session = _FakeSession()
        ..pushBytes(Uint8List(2 * 1024 * 1024 + 1))
        ..finishStdout()
        ..exitCode = 0
        ..completeDone();

      await expectLater(
        CodexAccountModels.query(_FakeSsh(session), profile()),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'AGENT_MODEL_RESPONSE_TOO_LARGE',
          ),
        ),
      );
      expect(session.closeCount, 1);
    });

    test('stdout 抛错时仍关闭通道', () async {
      final session = _FakeSession()..failStdout(StateError('channel blew up'));

      await expectLater(
        CodexAccountModels.query(_FakeSsh(session), profile()),
        throwsA(isA<StateError>()),
      );
      expect(session.closeCount, 1, reason: '失败路径同样不得留下孤儿通道');
    });
  });

  group('CodexAccountModels.command：远端命令不泄漏', () {
    test('脚本以 base64 内联，命令里看不到端点/令牌明文', () {
      final command = CodexAccountModels.command(profile());

      expect(command, contains('node -e'));
      expect(
        command,
        contains(CodexModelAuthorization.credentialKey(profile())),
      );
      expect(command, isNot(contains('api.openai.com')));
      expect(command, isNot(contains('auth.openai.com')));
      expect(command, isNot(contains('Bearer ')));

      final script = embeddedScript(command);
      expect(script, contains('https://api.openai.com/v1/models'));
      expect(script, contains("visibility === 'list'"));
      expect(
        script,
        isNot(contains('app-server')),
        reason: '目录查询不得退回 app-server model/list',
      );
      expect(script, isNot(contains('session/')), reason: '目录查询不得触碰任何会话方法');
      expect(
        script,
        isNot(contains('thread/')),
        reason: '目录查询不得触碰任何 thread 方法',
      );
    });

    test('host 执行目标包 bash -l -c，docker 目标包 docker exec', () {
      final host = CodexAccountModels.command(profile());
      expect(host, startsWith('bash -l -c '));
      expect(host, isNot(contains('docker exec')));

      final docker = CodexAccountModels.command(
        profile(executionTarget: 'docker', container: 'codex-box'),
      );
      expect(docker, contains('docker exec'));
      expect(docker, contains('codex-box'));
      expect(docker, contains('node -e'));
    });
  });
}

/// 从远端命令里解出 base64 内联的 Node 脚本。
String embeddedScript(String command) {
  final match = RegExp(
    r'Buffer\.from\("([A-Za-z0-9+/=]+)", "base64"\)',
  ).firstMatch(command);
  expect(match, isNotNull, reason: '脚本必须 base64 内联，避免明文出现在进程列表');
  return utf8.decode(base64.decode(match!.group(1)!));
}

class _FakeSession implements SSHSession {
  final _out = StreamController<Uint8List>();
  final _err = StreamController<Uint8List>();
  final _in = StreamController<Uint8List>();
  final _done = Completer<void>();

  @override
  int? exitCode;
  int closeCount = 0;

  void pushLine(String line) =>
      pushBytes(Uint8List.fromList(utf8.encode('$line\n')));

  void pushBytes(Uint8List bytes) {
    if (!_out.isClosed) _out.add(bytes);
  }

  void failStdout(Object error) {
    if (!_out.isClosed) _out.addError(error);
  }

  void finishStdout() {
    if (!_out.isClosed) _out.close();
  }

  void pushStderr(String text) {
    if (!_err.isClosed) _err.add(Uint8List.fromList(utf8.encode(text)));
  }

  void finishStderr() {
    if (!_err.isClosed) _err.close();
  }

  void completeDone() {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Stream<Uint8List> get stdout => _out.stream;

  @override
  Stream<Uint8List> get stderr => _err.stream;

  @override
  StreamSink<Uint8List> get stdin => _in.sink;

  @override
  Future<void> get done => _done.future;

  @override
  void close() {
    closeCount++;
    finishStdout();
    finishStderr();
    if (!_in.isClosed) _in.close();
    completeDone();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSsh implements SSHClient {
  _FakeSsh(this.session);

  final SSHSession session;
  final List<String> commands = [];

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) {
    commands.add(command);
    return Future<SSHSession>.value(session);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
