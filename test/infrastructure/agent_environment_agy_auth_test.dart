import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valhalla/data/models/agent_profile.dart';
import 'package:valhalla/data/models/builtin_agent_preset.dart';
import 'package:valhalla/infrastructure/acp/agent_environment_service.dart';
import 'package:valhalla/infrastructure/ssh/ssh_client_manager.dart';

/// Interpretation contract for the built-in AGY readiness probe: `missing`
/// means sign-in is required, `saved`/`unknown` are setup evidence only and
/// never a live login proof, and malformed output is never trusted.
SSHExecutionResult _ok(String stdout) =>
    SSHExecutionResult(exitCode: 0, stdout: stdout, stderr: '');

SSHExecutionResult _fail(int code, String stderr) =>
    SSHExecutionResult(exitCode: code, stdout: '', stderr: stderr);

/// Fake executor: longest matching key wins, unmatched commands succeed blank.
class _FakeExecutor implements SshCommandExecutor {
  _FakeExecutor(this._results);

  final Map<String, SSHExecutionResult> _results;
  final List<String> commands = [];

  @override
  bool isConnected(String serverId) => true;

  @override
  SSHClient? getClient(String serverId) => null;

  Future<SSHExecutionResult> _run(String command) async {
    commands.add(command);
    final keys = _results.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      if (command.contains(key)) return _results[key]!;
    }
    return const SSHExecutionResult(exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Future<SSHExecutionResult> executeWithLoginShell(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) => _run(command);

  @override
  Stream<SSHExecutionChunk> executeStreaming(
    String serverId,
    String command, {
    Duration timeout = const Duration(seconds: 30),
    String? sudoPassword,
  }) async* {
    yield SSHExecutionChunk(
      kind: SSHStreamKind.stdout,
      text: (await _run(command)).stdout,
    );
  }
}

AgentProfile _agy({String? loginCheckCommand}) => AgentProfile(
  id: 'builtin-agy',
  serverId: 's',
  name: 'AGY',
  description: '',
  cliCommand: 'agy',
  acpCommand: 'agy_acp_server.par',
  loginCommand: 'agy',
  loginCheckCommand: loginCheckCommand,
);

Map<String, SSHExecutionResult> _results(
  String loginStdout, {
  int loginExit = 0,
}) => {
  'command -v agy_acp_server.par': _ok('/root/.local/bin/agy_acp_server.par'),
  'command -v agy': _ok('/usr/bin/agy'),
  kAntigravityLoginCheckCommand: loginExit == 0
      ? _ok(loginStdout)
      : _fail(loginExit, 'probe crashed'),
};

String _json(String state, {String? authType}) =>
    '{"scope":"antigravity-acp","state":"$state",'
    '"authType":${authType == null ? 'null' : '"$authType"'}}';

void main() {
  test('missing means sign-in is required, not a transport failure', () async {
    final executor = _FakeExecutor(_results(_json('missing')));

    final status = await AgentEnvironmentService(
      executor,
    ).inspect(_agy(loginCheckCommand: kAntigravityLoginCheckCommand), 's');

    expect(status.kind, AgentEnvironmentStatusKind.ready);
    expect(status.detail, 'AGY_ACP_SIGN_IN_REQUIRED');
    expect(status.authentication, AgentAuthenticationStatus.unauthenticated);
    expect(status.diagnosticLog, contains('ACP credential readiness only'));
    expect(executor.commands.last, kAntigravityLoginCheckCommand);
  });

  test('saved is setup evidence and never a login proof', () async {
    final executor = _FakeExecutor(_results(_json('saved')));

    final status = await AgentEnvironmentService(
      executor,
    ).inspect(_agy(loginCheckCommand: kAntigravityLoginCheckCommand), 's');

    expect(status.kind, AgentEnvironmentStatusKind.ready);
    expect(status.detail, 'AGY_ACP_CREDENTIALS_NOT_VALIDATED');
    expect(status.authentication, AgentAuthenticationStatus.unknown);
  });

  test('auth unknown stays unknown rather than authenticated', () async {
    final executor = _FakeExecutor(
      _results(_json('unknown', authType: 'gemini-api-key')),
    );

    final status = await AgentEnvironmentService(
      executor,
    ).inspect(_agy(loginCheckCommand: kAntigravityLoginCheckCommand), 's');

    expect(status.kind, AgentEnvironmentStatusKind.ready);
    expect(
      status.detail,
      'AGY_AUTH_CHECK_UNAVAILABLE',
      reason:
          'an unreadable token file never proves readiness. '
          '${status.diagnosticLog}',
    );
    expect(status.authentication, AgentAuthenticationStatus.unknown);
  });

  test('malformed probe output is rejected as invalid', () async {
    for (final output in [
      'not json',
      '{"scope":"other","state":"saved","authType":null}',
      '{"scope":"antigravity-acp","state":"trusted","authType":null}',
      '[]',
    ]) {
      final status = await AgentEnvironmentService(
        _FakeExecutor(_results(output)),
      ).inspect(_agy(loginCheckCommand: kAntigravityLoginCheckCommand), 's');

      expect(status.detail, 'AGY_AUTH_CHECK_INVALID', reason: output);
      expect(
        status.authentication,
        AgentAuthenticationStatus.unknown,
        reason: output,
      );
    }
  });

  test(
    'a failing probe degrades to unavailable, never to authenticated',
    () async {
      final status = await AgentEnvironmentService(
        _FakeExecutor(_results('', loginExit: 3)),
      ).inspect(_agy(loginCheckCommand: kAntigravityLoginCheckCommand), 's');

      expect(status.kind, AgentEnvironmentStatusKind.ready);
      expect(status.detail, 'AGY_AUTH_CHECK_UNAVAILABLE');
      expect(status.authentication, AgentAuthenticationStatus.unknown);
    },
  );

  test('an unconfigured probe is reported as not configured', () async {
    final status = await AgentEnvironmentService(
      _FakeExecutor(const {}),
    ).inspect(_agy(), 's');

    expect(status.kind, AgentEnvironmentStatusKind.ready);
    expect(status.diagnosticLog, contains('authentication: not configured'));
    expect(status.authentication, AgentAuthenticationStatus.unknown);
  });

  group('validateSavedAuth 只在「saved + OAuth + AgY ACP 就绪」时注入运行', () {
    late List<String> validated;

    setUp(() => validated = <String>[]);

    Future<AgentEnvironmentStatus> inspect(
      String json,
      AgentAuthenticationStatus result, {
      AgentProfile? profile,
      bool requireAcp = true,
    }) async {
      final executor = _FakeExecutor(_results(json));
      final service = AgentEnvironmentService(
        executor,
        validateSavedAuth: (p, method) async {
          validated.add('${p.id}:$method');
          return result;
        },
      );
      return service.inspect(
        profile ?? _agy(loginCheckCommand: kAntigravityLoginCheckCommand),
        's',
        requireAcp: requireAcp,
      );
    }

    test('saved + oauth-personal 认证成功：注入被调用且清掉未验证 detail', () async {
      final status = await inspect(
        _json('saved', authType: 'oauth-personal'),
        AgentAuthenticationStatus.authenticated,
      );

      expect(validated, ['builtin-agy:oauth-personal']);
      expect(status.authentication, AgentAuthenticationStatus.authenticated);
      expect(status.detail, isNull);
      expect(status.kind, AgentEnvironmentStatusKind.ready);
    });

    test('saved + oauth-personal 认证失败（unauthenticated）→ 需要登录', () async {
      final status = await inspect(
        _json('saved', authType: 'oauth-personal'),
        AgentAuthenticationStatus.unauthenticated,
      );

      expect(validated, isNotEmpty);
      expect(status.authentication, AgentAuthenticationStatus.unauthenticated);
      expect(status.detail, 'AGY_ACP_SIGN_IN_REQUIRED');
    });

    test('saved + oauth-personal 认证不确定（unknown）→ 保留未验证 detail', () async {
      final status = await inspect(
        _json('saved', authType: 'oauth-personal'),
        AgentAuthenticationStatus.unknown,
      );

      expect(validated, isNotEmpty);
      expect(status.authentication, AgentAuthenticationStatus.unknown);
      expect(status.detail, 'AGY_ACP_CREDENTIALS_NOT_VALIDATED');
    });

    test('state=unknown 或 missing 不调用注入', () async {
      await inspect(_json('unknown'), AgentAuthenticationStatus.authenticated);
      await inspect(_json('missing'), AgentAuthenticationStatus.authenticated);
      expect(validated, isEmpty, reason: '只有 saved 才重新验证');
    });

    test('authType 不是 oauth-personal/oauth-business 不调用注入', () async {
      await inspect(
        _json('saved', authType: 'gemini-api-key'),
        AgentAuthenticationStatus.authenticated,
      );
      await inspect(
        _json('saved', authType: 'api-key'),
        AgentAuthenticationStatus.authenticated,
      );
      expect(validated, isEmpty);
    });

    test('ACP 缺失时即便 saved 也不调用注入', () async {
      // 命令找不到 ACP 可执行文件 → acpMissingDetail != null。
      final executor = _FakeExecutor({
        'command -v agy_acp_server.par': _fail(127, 'not found'),
        'command -v agy': _ok('/usr/bin/agy'),
        kAntigravityLoginCheckCommand: _ok(
          _json('saved', authType: 'oauth-personal'),
        ),
      });
      final service = AgentEnvironmentService(
        executor,
        validateSavedAuth: (p, method) async {
          validated.add('${p.id}:$method');
          return AgentAuthenticationStatus.authenticated;
        },
      );
      final status = await service.inspect(
        _agy(loginCheckCommand: kAntigravityLoginCheckCommand),
        's',
      );

      expect(validated, isEmpty);
      expect(status.kind, AgentEnvironmentStatusKind.acpMissing);
      expect(
        status.authentication,
        isNot(AgentAuthenticationStatus.authenticated),
      );
    });

    test('requireAcp=false 不调用注入', () async {
      await inspect(
        _json('saved', authType: 'oauth-personal'),
        AgentAuthenticationStatus.authenticated,
        requireAcp: false,
      );
      expect(validated, isEmpty);
    });

    test('非 AgY ACP 的 profile 不调用注入', () async {
      await inspect(
        _json('saved', authType: 'oauth-personal'),
        AgentAuthenticationStatus.authenticated,
        profile: AgentProfile(
          id: 'codex',
          serverId: 's',
          name: 'codex',
          description: '',
          cliCommand: 'codex',
          acpCommand: 'codex-acp --stdio',
          loginCheckCommand: kAntigravityLoginCheckCommand,
        ),
      );
      expect(validated, isEmpty);
    });
  });
}
