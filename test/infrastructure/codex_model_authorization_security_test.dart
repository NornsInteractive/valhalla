import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/infrastructure/cli/codex_model_authorization.dart';

/// 契约 6：独立的 CodexModelAuthorization 后端。
///
/// 嵌入式 Node 只做静态安全审查，并从 authorize 真正发出的命令里取回脚本；
/// Dart 侧编排用假 SSH + 本机回环回调驱动。
/// 绝不执行真实登录、真实 JWKS 或真实账号推断，也不读取任何真实凭据。
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

  final runtime = CodexModelAuthorization.runtime;

  group('凭据键与命令构造', () {
    test('credentialKey 是 server::agent 的 sha256，彼此隔离', () {
      final one = CodexModelAuthorization.credentialKey(profile());
      expect(one, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(
        one,
        sha256.convert(utf8.encode('srv-1::builtin-codex')).toString(),
      );

      final otherAgent = CodexModelAuthorization.credentialKey(
        AgentProfile(
          id: 'other-agent',
          serverId: 'srv-1',
          name: 'other',
          description: 'other',
          cliCommand: 'codex',
        ),
      );
      final otherServer = CodexModelAuthorization.credentialKey(
        AgentProfile(
          id: 'builtin-codex',
          serverId: 'srv-2',
          name: 'codex',
          description: 'codex',
          cliCommand: 'codex',
        ),
      );
      expect(otherAgent, isNot(one));
      expect(otherServer, isNot(one), reason: '凭据键必须按 server 与 agent 双向隔离');
    });

    test('host 目标走 bash -l -c，docker 目标走 docker exec', () {
      final host = CodexModelAuthorization.remoteCommand(profile(), 'print 1');
      expect(host, startsWith('bash -l -c '));
      expect(host, contains('node -e'));
      expect(host, contains(CodexModelAuthorization.credentialKey(profile())));
      expect(host, isNot(contains('docker exec')));

      final docker = CodexModelAuthorization.remoteCommand(
        profile(executionTarget: 'docker', container: 'codex-box'),
        'print 1',
      );
      expect(docker, contains('docker exec'));
      expect(docker, contains('codex-box'));
      expect(docker, contains('node -e'));
      expect(docker, isNot(contains('bash -l -c ')));
    });

    test('脚本 base64 内联，命令行看不到明文逻辑', () {
      final command = CodexModelAuthorization.remoteCommand(
        profile(),
        'SECRET',
      );
      expect(command, isNot(contains('SECRET')));
      expect(decodeScript(command), 'SECRET');
    });
  });

  group('嵌入式 Node 的静态安全审查', () {
    /// authorize 真正发送的完整脚本（runtime + 授权流程）。
    late String authorizeFlow;

    setUpAll(() async {
      final session = _FakeSession();
      session.onStdinLine = (_) =>
          session.pushLine(jsonEncode({'error': 'AGENT_MODEL_AUTH_DECLINED'}));
      final ssh = _FakeSsh(session);
      try {
        await CodexModelAuthorization.authorize(
          ssh,
          profile(),
          openBrowser: (_) async {},
        ).timeout(const Duration(seconds: 10));
      } catch (_) {
        // 预期以固定错误码结束；这里只要取回命令。
      }
      final sent = decodeScript(ssh.commands.single);
      expect(sent.startsWith(runtime), isTrue, reason: '授权脚本必须以共享运行时开头');
      authorizeFlow = sent.substring(runtime.length).trimLeft();
      expect(authorizeFlow, isNotEmpty);
    });

    test('只用 Node 原生依赖，不存在未发布的 npm 包', () {
      final requires = RegExp(r"require\('([^']+)'\)")
          .allMatches('$runtime\n$authorizeFlow')
          .map((match) => match.group(1)!)
          .toSet();
      expect(requires, equals({'fs', 'path', 'os', 'crypto', 'readline'}));
      for (final banned in const [
        '@siwc/local',
        'jsonwebtoken',
        'node-fetch',
        'jwks-rsa',
        'openid-client',
      ]) {
        expect('$runtime\n$authorizeFlow', isNot(contains(banned)));
      }
    });

    test('HTTPS 端点白名单、超时与响应体上限', () {
      expect(runtime, contains("parsed.protocol !== 'https:'"));
      expect(
        runtime,
        contains("['auth.openai.com', 'api.openai.com'].includes(parsed.host)"),
      );
      expect(runtime, contains('AbortSignal.timeout(15000)'));
      expect(runtime, contains("redirect: 'error'"));
      expect(runtime, contains('2097152'));
      expect(runtime, contains('AGENT_MODEL_ENDPOINT_INVALID'));
      expect(runtime, contains('AGENT_MODEL_RESPONSE_TOO_LARGE'));
      expect(
        RegExp(r"fetch\('[^']*http://").hasMatch(runtime),
        isFalse,
        reason: '不得发起明文 HTTP',
      );
    });

    test('JWKS RS256 校验覆盖 issuer/audience/azp/expiry/nonce/subject', () {
      expect(runtime, contains("header.alg !== 'RS256'"));
      expect(runtime, contains('crypto.verify('));
      expect(runtime, contains("'RSA-SHA256'"));
      expect(
        runtime,
        contains("discovery.issuer !== 'https://auth.openai.com'"),
      );
      expect(runtime, contains('claims.iss !== discovery.issuer'));
      expect(runtime, contains('audiences.includes(clientId)'));
      expect(runtime, contains('claims.azp !== clientId'));
      expect(runtime, contains('claims.exp <= Date.now()/1000'));
      expect(runtime, contains('claims.nbf > Date.now()/1000 + 60'));
      expect(runtime, contains("typeof claims.sub !== 'string'"));
      expect(runtime, contains('claims.nonce !== nonce'));
      expect(runtime, contains("k.kid === header.kid"));
      expect(runtime, contains("k.kty === 'RSA'"));
      expect(runtime, isNot(contains('atob(')), reason: '不得手写 JWT 签名校验');
      expect(runtime, contains('AGENT_MODEL_IDENTITY_INVALID'));
      expect(runtime, contains('AGENT_MODEL_ACCOUNT_MISMATCH'));
    });

    test('存储为 mode 0600 原子写入，目录 0700 且校验属主/权限', () {
      expect(runtime, contains('mode: 0o600'));
      expect(runtime, contains("flag: 'wx'"));
      expect(runtime, contains('renameSync'));
      expect(runtime, contains('mode: 0o700'));
      expect(runtime, contains('stat.mode & 0o077'));
      expect(runtime, contains('stat.uid !== process.getuid()'));
      expect(runtime, contains('AGENT_MODEL_AUTH_STORAGE_UNSAFE'));
      expect(runtime, contains('lstatSync'));
    });

    test('绝不写 Codex 的 auth.json，只读地绑定账号', () {
      expect(
        RegExp(r'(?:write|rename)Sync\([^)]*auth\.json').hasMatch(runtime),
        isFalse,
        reason: 'Codex auth.json 必须只读',
      );
      expect(runtime, contains("fs.readFileSync(path.join(home, 'auth.json')"));
      expect(
        runtime,
        contains("path.join(os.homedir(), '.config', 'valhalla', 'model-auth'"),
      );
      expect(
        RegExp(r'writeFileSync\(authFile').hasMatch(runtime),
        isFalse,
        reason: '凭据只能经 writeRecord 的临时文件原子写入',
      );
    });

    test('刷新与显式交换共用排他锁，不偷锁且有信号清理', () {
      expect(runtime, contains("fs.openSync(lock, 'wx', 0o600)"));
      expect(runtime, contains('AGENT_MODEL_AUTH_BUSY'));
      expect(runtime, contains("['SIGTERM', 'SIGHUP', 'SIGINT']"));
      expect(runtime, contains('releaseLock()'));
      expect(runtime, isNot(contains('O_TRUNC')), reason: '不得通过截断已有锁文件来偷锁');
      expect(RegExp(r'chmodSync\(lock').hasMatch(runtime), isFalse);
      expect(runtime, contains("grant_type: 'refresh_token'"));
      expect(runtime, contains('return withCredentialLock('));
      expect(runtime, contains('chatgpt.tokens.use.direct'));
      expect(runtime, contains('AGENT_MODEL_PLAN_PERMISSION_REQUIRED'));
      expect(runtime, contains('record.expires_at > Date.now() + 60000'));
    });

    test('回调仅限 127.0.0.1 回环、固定路径、PKCE 与单次使用', () {
      expect(authorizeFlow, contains("redirect.protocol !== 'http:'"));
      expect(authorizeFlow, contains("redirect.hostname !== '127.0.0.1'"));
      expect(authorizeFlow, contains("redirect.pathname !== '/auth/callback'"));
      expect(authorizeFlow, contains('redirect.search || redirect.hash'));
      expect(authorizeFlow, contains('callback.origin !== base.origin'));
      expect(authorizeFlow, contains('AGENT_MODEL_CALLBACK_INVALID'));
      expect(
        authorizeFlow,
        contains("callback.searchParams.get('state') !== pending.state"),
      );
      expect(authorizeFlow, contains('AGENT_MODEL_AUTH_DECLINED'));
      expect(authorizeFlow, contains('AGENT_MODEL_CLIENT_MISMATCH'));
      expect(authorizeFlow, contains("code_challenge_method: 'S256'"));
      expect(authorizeFlow, contains('code_verifier'));
      expect(authorizeFlow, contains('crypto.randomBytes(32)'));
      expect(
        authorizeFlow,
        contains('emit({authorizationUrl: url.toString()})'),
      );
      expect(
        RegExp(r"url\.host !== 'auth\.openai.com'").hasMatch(authorizeFlow),
        isTrue,
      );
    });

    test('Phone 只拿到授权 URL，令牌永远不过 SSH', () {
      expect(authorizeFlow, contains('emit({authorized: true})'));
      for (final leaked in const [
        'emit({access_token',
        'emit({refresh_token',
        'emit({id_token',
        'process.stdout.write(data.access_token',
      ]) {
        expect(
          '$runtime\n$authorizeFlow',
          isNot(contains(leaked)),
          reason: '令牌不得回传到手机',
        );
      }
      expect('$runtime\n$authorizeFlow', isNot(contains('chat/completions')));
      expect('$runtime\n$authorizeFlow', isNot(contains('inference(')));
    });
  });

  group('authorize：假 SSH + 本机回环回调', () {
    test('非法 authorizationUrl 一律精确报 ENDPOINT_INVALID，且不启动浏览器', () async {
      // 每个用例只违反一条端点约束，逐条钉住本地抛出的固定码。
      final cases = <String, String Function(String redirect)>{
        '明文 http 端点': (redirect) =>
            'http://evil.example/auth?redirect_uri=$redirect&state=s'
            '&resource=https://api.openai.com/v1',
        '非 auth.openai.com 主机': (redirect) =>
            'https://evil.example/auth?redirect_uri=$redirect&state=s'
            '&resource=https://api.openai.com/v1',
        'redirect_uri 不是本机回环回调': (_) =>
            'https://auth.openai.com/authorize'
            '?redirect_uri=http%3A%2F%2F127.0.0.1%3A1%2Fauth%2Fcallback'
            '&state=s&resource=https://api.openai.com/v1',
        'resource 不是 v1': (redirect) =>
            'https://auth.openai.com/authorize'
            '?redirect_uri=$redirect&state=s&resource=wrong',
      };

      for (final entry in cases.entries) {
        final session = _FakeSession();
        session.onStdinLine = (line) {
          final redirect = (jsonDecode(line) as Map)['redirectUri'] as String;
          session.pushLine(
            jsonEncode({'authorizationUrl': entry.value(redirect)}),
          );
        };
        final browserCalls = <Uri>[];

        await expectLater(
          CodexModelAuthorization.authorize(
            _FakeSsh(session),
            profile(),
            openBrowser: (url) async => browserCalls.add(url),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'AGENT_MODEL_ENDPOINT_INVALID',
            ),
          ),
          reason: '${entry.key} 必须抛出精确固定码，不得折叠成 AUTH_FAILED',
        );
        expect(browserCalls, isEmpty, reason: '非法端点绝不启动浏览器');
        expect(session.closeCount, greaterThanOrEqualTo(1));
      }
    });

    test('授权 URL 缺 state：精确报 CALLBACK_INVALID，且不启动浏览器', () async {
      final session = _FakeSession();
      session.onStdinLine = (line) {
        final redirect = (jsonDecode(line) as Map)['redirectUri'] as String;
        session.pushLine(
          jsonEncode({
            'authorizationUrl':
                'https://auth.openai.com/authorize?redirect_uri=$redirect'
                '&resource=https://api.openai.com/v1',
          }),
        );
      };
      final browserCalls = <Uri>[];

      await expectLater(
        CodexModelAuthorization.authorize(
          _FakeSsh(session),
          profile(),
          openBrowser: (url) async => browserCalls.add(url),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'AGENT_MODEL_CALLBACK_INVALID',
          ),
        ),
        reason: '端点合法但缺 state 必须抛出精确固定码',
      );
      expect(browserCalls, isEmpty, reason: '缺 state 绝不启动浏览器');
      expect(session.closeCount, greaterThanOrEqualTo(1));
    });

    test('authorizationUrl 连 Uri.parse 都过不去：仍折叠成 AUTH_FAILED', () async {
      final session = _FakeSession();
      session.onStdinLine = (_) =>
          session.pushLine(jsonEncode({'authorizationUrl': 'https://[::1'}));
      final browserCalls = <Uri>[];

      await expectLater(
        CodexModelAuthorization.authorize(
          _FakeSsh(session),
          profile(),
          openBrowser: (url) async => browserCalls.add(url),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'AGENT_MODEL_AUTH_FAILED',
          ),
        ),
        reason: '只有那两个本地固定码被保留，其它解析错误必须继续折叠',
      );
      expect(browserCalls, isEmpty, reason: '解析失败绝不启动浏览器');
      expect(session.closeCount, greaterThanOrEqualTo(1));
    });

    test('远端固定错误码原样透出，未知错误折叠成固定失败码', () async {
      const cases = {
        'AGENT_MODEL_AUTH_DECLINED': 'AGENT_MODEL_AUTH_DECLINED',
        'AGENT_MODEL_AUTH_BUSY': 'AGENT_MODEL_AUTH_BUSY',
        'not a code': 'AGENT_MODEL_AUTH_FAILED',
      };
      for (final entry in cases.entries) {
        final session = _FakeSession();
        session.onStdinLine = (_) =>
            session.pushLine(jsonEncode({'error': entry.key}));
        final browserCalls = <Uri>[];

        await expectLater(
          CodexModelAuthorization.authorize(
            _FakeSsh(session),
            profile(),
            openBrowser: (url) async => browserCalls.add(url),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              entry.value,
            ),
          ),
          reason: '远程错误必须映射为受控固定码',
        );
        expect(browserCalls, isEmpty);
        expect(session.closeCount, greaterThanOrEqualTo(1));
      }
    });

    test('授权前取消：关掉通道且绝不启动浏览器', () async {
      final session = _FakeSession();
      final browserCalls = <Uri>[];
      final cancelled = Completer<void>();

      final future = CodexModelAuthorization.authorize(
        _FakeSsh(session),
        profile(),
        openBrowser: (url) async => browserCalls.add(url),
        cancelled: cancelled.future,
      );
      await pumpEventQueue();
      cancelled.complete();

      await expectLater(
        future,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'AGENT_MODEL_AUTH_CANCELLED',
          ),
        ),
      );
      expect(browserCalls, isEmpty, reason: '取消后不得再拉起浏览器');
      expect(session.closeCount, greaterThanOrEqualTo(1));
    });

    test('回环回调只接受一次，取消后通道与监听都关闭', () async {
      final session = _FakeSession();
      final browserCalls = <Uri>[];
      final cancelled = Completer<void>();
      final portHolder = Completer<int>();
      session.onStdinLine = (line) {
        final message = jsonDecode(line) as Map;
        final redirect = message['redirectUri'];
        if (redirect is! String) return;
        final port = Uri.parse(redirect).port;
        if (!portHolder.isCompleted) portHolder.complete(port);
        session.pushLine(
          jsonEncode({
            'authorizationUrl':
                'https://auth.openai.com/authorize?redirect_uri=$redirect'
                '&resource=https%3A%2F%2Fapi.openai.com%2Fv1&state=st-1&nonce=n-1',
          }),
        );
      };

      final future = CodexModelAuthorization.authorize(
        _FakeSsh(session),
        profile(),
        openBrowser: (url) async => browserCalls.add(url),
        cancelled: cancelled.future,
      );

      final port = await portHolder.future.timeout(const Duration(seconds: 5));
      await pumpEventQueue();
      expect(browserCalls, hasLength(1));
      expect(browserCalls.single.scheme, 'https');
      expect(browserCalls.single.host, 'auth.openai.com');

      final client = HttpClient();
      addTearDown(client.close);

      Future<int> get(String uri) async {
        final request = await client.getUrl(Uri.parse(uri));
        final response = await request.close();
        await response.drain<void>();
        return response.statusCode;
      }

      expect(
        await get('http://127.0.0.1:$port/auth/callback?state=st-1&code=abc'),
        HttpStatus.ok,
      );
      expect(
        await get('http://127.0.0.1:$port/auth/callback?state=st-1&code=abc'),
        HttpStatus.badRequest,
        reason: '回调必须单次使用',
      );
      expect(
        await get('http://127.0.0.1:$port/auth/callback?state=other&code=abc'),
        HttpStatus.badRequest,
        reason: 'state 不匹配必须拒绝',
      );
      expect(
        session.stdinLines.where((line) => line.contains('callbackUrl')),
        hasLength(1),
        reason: '只有被接受的那一次回调会被转发给远端',
      );

      cancelled.complete();
      await expectLater(
        future,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'AGENT_MODEL_AUTH_CANCELLED',
          ),
        ),
      );
      expect(session.closeCount, greaterThanOrEqualTo(1));

      await expectLater(
        get('http://127.0.0.1:$port/auth/callback?state=st-1'),
        throwsA(anyOf(isA<SocketException>(), isA<HttpException>())),
        reason: '取消后回环监听必须关闭',
      );
    });

    test('远端成功回执只产生一次浏览器调用并正常结束', () async {
      final session = _FakeSession();
      final browserCalls = <Uri>[];
      final finished = Completer<void>();
      session.onStdinLine = (line) {
        final redirect = (jsonDecode(line) as Map)['redirectUri'] as String;
        session.pushLine(
          jsonEncode({
            'authorizationUrl':
                'https://auth.openai.com/authorize?redirect_uri=$redirect'
                '&resource=https%3A%2F%2Fapi.openai.com%2Fv1&state=st-2&nonce=n-2',
          }),
        );
        session.pushLine(jsonEncode({'authorized': true}));
        if (!finished.isCompleted) finished.complete();
      };

      final future = CodexModelAuthorization.authorize(
        _FakeSsh(session),
        profile(),
        openBrowser: (url) async => browserCalls.add(url),
      );
      await finished.future.timeout(const Duration(seconds: 5));
      await future.timeout(const Duration(seconds: 5));

      expect(browserCalls, hasLength(1));
      expect(session.stdinLines, hasLength(1), reason: '手机只回传回环地址，不回传任何令牌');
      expect(session.stdinLines.single, contains('"redirectUri"'));
      expect(session.closeCount, greaterThanOrEqualTo(1));
    });

    test('stdout 流中断时折叠成固定失败码并关闭通道', () async {
      final session = _FakeSession();
      session.onStdinLine = (_) => session.failStdout('boom');

      await expectLater(
        CodexModelAuthorization.authorize(
          _FakeSsh(session),
          profile(),
          openBrowser: (_) async {},
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'AGENT_MODEL_AUTH_FAILED',
          ),
        ),
      );
      expect(session.closeCount, greaterThanOrEqualTo(1));
    });
  });
}

/// 从远端命令里解出 base64 内联的 Node 脚本。
String decodeScript(String command) {
  final match = RegExp(
    r'Buffer\.from\("([A-Za-z0-9+/=]+)", "base64"\)',
  ).firstMatch(command);
  expect(match, isNotNull, reason: '脚本必须 base64 内联');
  return utf8.decode(base64.decode(match!.group(1)!));
}

class _FakeSession implements SSHSession {
  final _out = StreamController<Uint8List>();
  final _err = StreamController<Uint8List>();
  final _in = StreamController<Uint8List>();
  final _done = Completer<void>();

  int closeCount = 0;
  void Function(String line)? onStdinLine;

  /// Every raw line Dart wrote to the remote process.
  final List<String> stdinLines = [];

  _FakeSession() {
    _in.stream.listen((bytes) {
      final line = utf8.decode(bytes).trim();
      if (line.isEmpty) return;
      stdinLines.add(line);
      onStdinLine?.call(line);
    });
  }

  void pushLine(String line) {
    if (_out.isClosed) return;
    _out.add(Uint8List.fromList(utf8.encode('$line\n')));
  }

  void failStdout(Object error) {
    if (_out.isClosed) return;
    _out.addError(error);
  }

  @override
  Stream<Uint8List> get stdout => _out.stream;

  @override
  Stream<Uint8List> get stderr => _err.stream;

  @override
  StreamSink<Uint8List> get stdin => _in.sink;

  @override
  int? get exitCode => null;

  @override
  Future<void> get done => _done.future;

  @override
  void close() {
    closeCount++;
    if (!_out.isClosed) _out.close();
    if (!_err.isClosed) _err.close();
    if (!_in.isClosed) _in.close();
    if (!_done.isCompleted) _done.complete();
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
