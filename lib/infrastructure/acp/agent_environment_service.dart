import 'dart:async';
import 'dart:convert';

import '../../core/errors/app_exceptions.dart';
import '../../core/logging/sanitizer.dart';
import '../../core/security/agent_command_validator.dart';
import '../../data/models/agent_profile.dart';
import '../../data/models/builtin_agent_preset.dart';
import '../../core/utils/shell_quote.dart';
import '../cli/agent_execution_target.dart';
import '../ssh/ssh_client_manager.dart';

/// Agent 远端环境检测结果分类。
enum AgentEnvironmentStatusKind {
  unknown,
  checking,
  cliMissing,
  acpMissing,
  notLoggedIn,
  ready,
  error,
}

enum AgentAuthenticationStatus { unknown, authenticated, unauthenticated }

/// 针对 `(serverId, agentId)` 的运行时检测结果，不持久化为永久真值。
class AgentEnvironmentStatus {
  final AgentEnvironmentStatusKind kind;

  /// 成功探测的脱敏摘要（`cliCommand` 路径）。
  final String? version;

  /// 失败步骤的脱敏输出尾部，或稳定 reason code（如 `SSH_DISCONNECTED`）。
  final String? detail;

  /// 本次探测的脱敏、限长步骤日志；只存在于运行时状态，不持久化。
  final String diagnosticLog;

  final DateTime checkedAt;
  final AgentAuthenticationStatus authentication;

  const AgentEnvironmentStatus({
    required this.kind,
    this.version,
    this.detail,
    this.diagnosticLog = '',
    required this.checkedAt,
    this.authentication = AgentAuthenticationStatus.unknown,
  });

  AgentEnvironmentStatus copyWith({
    AgentEnvironmentStatusKind? kind,
    String? version,
    String? detail,
    bool clearDetail = false,
    String? diagnosticLog,
    DateTime? checkedAt,
    AgentAuthenticationStatus? authentication,
  }) {
    return AgentEnvironmentStatus(
      kind: kind ?? this.kind,
      version: version ?? this.version,
      detail: clearDetail ? null : (detail ?? this.detail),
      diagnosticLog: diagnosticLog ?? this.diagnosticLog,
      checkedAt: checkedAt ?? this.checkedAt,
      authentication: authentication ?? this.authentication,
    );
  }

  static AgentEnvironmentStatus unknown() => AgentEnvironmentStatus(
    kind: AgentEnvironmentStatusKind.unknown,
    checkedAt: DateTime.now(),
  );
}

/// 通过既有 SSH 登录 Shell 检测、安装和登录 ACP Agent。
///
/// 不自动安装或发起交互登录；[inspect] 可复验已保存的官方凭据，但收到
/// 新授权挑战即停止。安装与交互登录由上层确认后显式调用，所有远端命令
/// 输出已由 [SshCommandExecutor] 脱敏。
class AgentEnvironmentService {
  AgentEnvironmentService(this._ssh, {this.validateSavedAuth});

  final Future<AgentAuthenticationStatus> Function(AgentProfile, String)?
  validateSavedAuth;

  final SshCommandExecutor _ssh;

  static const checkTimeout = Duration(seconds: 20);
  static const installTimeout = Duration(minutes: 10);
  static const loginTimeout = Duration(minutes: 10);

  /// 只读探测。检测顺序：CLI → ACP → 登录检查。
  Future<AgentEnvironmentStatus> inspect(
    AgentProfile profile,
    String serverId, {
    bool requireAcp = true,
  }) async {
    final diagnostics = <String>[];
    void note(String value) {
      if (diagnostics.length < 32) {
        diagnostics.add(LogSanitizer.sanitize(value));
      }
    }

    String output(SSHExecutionResult result) => _tail(
      [
        result.stdout,
        result.stderr,
      ].where((value) => value.isNotEmpty).join('\n'),
    );
    final containerTarget = profile.executionTarget == 'docker'
        ? 'container ${profile.containerReference?.trim().isEmpty ?? true ? '<missing>' : profile.containerReference!.trim()}${profile.containerUser?.trim().isNotEmpty == true ? ' as ${profile.containerUser!.trim()}' : ''}'
        : 'remote host';
    Future<SSHExecutionResult> probe(
      String step,
      String command, {
      String? requestedCommand,
      String? target,
    }) async {
      note('$step: target ${target ?? containerTarget}');
      note('$step: requested command: ${requestedCommand ?? command}');
      note('$step: transport command: $command');
      note('$step: running');
      final result = await _ssh.executeWithLoginShell(
        serverId,
        command,
        timeout: checkTimeout,
      );
      note(
        '$step: exit ${result.exitCode}${output(result).isEmpty ? '' : ' — ${output(result)}'}',
      );
      return result;
    }

    AgentEnvironmentStatus finish(
      AgentEnvironmentStatusKind kind, {
      String? version,
      String? detail,
      AgentAuthenticationStatus authentication =
          AgentAuthenticationStatus.unknown,
    }) => _status(
      kind,
      version: version,
      detail: detail,
      authentication: authentication,
      diagnosticLog: diagnostics.join('\n'),
    );
    if (!_ssh.isConnected(serverId)) {
      note('ssh: disconnected');
      return finish(
        AgentEnvironmentStatusKind.error,
        detail: 'SSH_DISCONNECTED',
      );
    }

    try {
      if (profile.executionTarget == 'docker') {
        final reference = profile.containerReference?.trim();
        if (reference == null || reference.isEmpty) {
          note('container: reference missing');
          return finish(
            AgentEnvironmentStatusKind.error,
            detail: 'AGENT_CONTAINER_INVALID',
          );
        }
        final container = await probe(
          'container running state',
          'docker inspect --format ${cliShellQuote('{{.State.Running}}')} '
              '${cliShellQuote(reference)}',
          target: 'remote host (Docker daemon)',
        );
        if (!container.isSuccess || container.stdout.trim() != 'true') {
          return finish(
            AgentEnvironmentStatusKind.error,
            detail: container.isSuccess
                ? 'AGENT_CONTAINER_NOT_RUNNING'
                : 'AGENT_CONTAINER_NOT_FOUND',
          );
        }
        if (profile.containerUser?.trim().isNotEmpty == true) {
          final user = await probe(
            'container user',
            agentTargetCommand(profile, 'id -u'),
            requestedCommand: 'id -u',
          );
          if (!user.isSuccess) {
            return finish(
              AgentEnvironmentStatusKind.error,
              detail: 'AGENT_CONTAINER_USER_UNAVAILABLE',
            );
          }
        }
      }
      AgentCommandValidator.validate(profile.cliCommand);
      if (!RegExp(r'^[A-Za-z0-9_./+-]+$').hasMatch(profile.cliCommand)) {
        throw const ValidationException(
          'CLI must be an executable name or path',
          'CLI_EXECUTABLE_INVALID',
        );
      }
      final cli = await probe(
        'cli availability',
        agentTargetCommand(profile, 'command -v ${profile.cliCommand}'),
        requestedCommand: 'command -v ${profile.cliCommand}',
      );
      if (!cli.isSuccess) {
        return finish(
          AgentEnvironmentStatusKind.cliMissing,
          detail: _tail(cli.stderr.isNotEmpty ? cli.stderr : cli.stdout),
        );
      }

      String? acpMissingDetail;
      final acpCommand = profile.acpCommand;
      if (requireAcp && acpCommand != null && acpCommand.trim().isNotEmpty) {
        // 探测 ACP 二进制是否存在。
        //
        // 不能用 `<acpCommand> --help`：ACP 适配器没有标准 help，执行后会直接
        // 启动 JSON-RPC 服务并挂起（直到超时），从而被误判为「未安装」。
        // 改为取命令首 token 作为可执行文件名，用 `command -v` 做纯查找探测。
        final acpBinary = acpCommand.trim().split(RegExp(r'\s+')).first;
        AgentCommandValidator.validate(acpBinary);
        if (!RegExp(r'^[A-Za-z0-9_./+-]+$').hasMatch(acpBinary)) {
          throw const ValidationException(
            'ACP executable is invalid',
            'ACP_EXECUTABLE_INVALID',
          );
        }
        final acp = await probe(
          'acp availability',
          agentTargetCommand(
            profile,
            acpBinary == 'agy_acp_server.par' && usesAntigravityAcp(profile)
                ? antigravityAcpLookupCommand
                : 'command -v $acpBinary',
          ),
          requestedCommand: 'command -v $acpBinary',
        );
        if (!acp.isSuccess) {
          acpMissingDetail = _tail(
            [
              acp.stdout,
              acp.stderr,
            ].where((value) => value.isNotEmpty).join('\n'),
          );
        }
      }

      final configuredLoginCheck = profile.loginCheckCommand;
      final loginCheck =
          configuredLoginCheck != null &&
              RegExp(r'(^|\s)--version(\s|$)').hasMatch(configuredLoginCheck)
          ? (profile.cliCommand == 'codex' ? 'codex login status' : null)
          : configuredLoginCheck;
      if (loginCheck == null || loginCheck.trim().isEmpty) {
        note('authentication: not configured');
        return finish(
          acpMissingDetail == null
              ? AgentEnvironmentStatusKind.ready
              : AgentEnvironmentStatusKind.acpMissing,
          version: _tail(cli.stdout),
          detail: acpMissingDetail,
        );
      }

      AgentCommandValidator.validate(loginCheck);
      final login = await probe(
        'authentication',
        agentTargetCommand(profile, loginCheck),
        requestedCommand: loginCheck,
      );
      if (loginCheck.trim() == kAntigravityLoginCheckCommand.trim()) {
        // Storage presence is useful setup evidence, never a live login proof.
        if (!login.isSuccess) {
          return finish(
            acpMissingDetail == null
                ? AgentEnvironmentStatusKind.ready
                : AgentEnvironmentStatusKind.acpMissing,
            version: _tail(cli.stdout),
            detail: acpMissingDetail ?? 'AGY_AUTH_CHECK_UNAVAILABLE',
          );
        }
        try {
          final result = jsonDecode(login.stdout);
          if (result is! Map ||
              result['scope'] != 'antigravity-acp' ||
              !{'missing', 'saved', 'unknown'}.contains(result['state'])) {
            throw const FormatException('AGY_AUTH_CHECK_INVALID');
          }
          final missing =
              requireAcp &&
              usesAntigravityAcp(profile) &&
              result['state'] == 'missing';
          note(
            'authentication: ACP credential readiness only; CLI login is separate',
          );
          var authentication = missing
              ? AgentAuthenticationStatus.unauthenticated
              : AgentAuthenticationStatus.unknown;
          if (result['state'] == 'saved' &&
              acpMissingDetail == null &&
              requireAcp &&
              usesAntigravityAcp(profile) &&
              {
                'oauth-personal',
                'oauth-business',
              }.contains(result['authType']) &&
              validateSavedAuth != null) {
            authentication = await validateSavedAuth!(
              profile,
              result['authType'] as String,
            );
            note(
              'authentication: saved credential official RPC check ${authentication.name}',
            );
          }
          return finish(
            acpMissingDetail != null
                ? AgentEnvironmentStatusKind.acpMissing
                : AgentEnvironmentStatusKind.ready,
            version: _tail(cli.stdout),
            detail:
                acpMissingDetail ??
                (authentication == AgentAuthenticationStatus.authenticated
                    ? null
                    : authentication ==
                          AgentAuthenticationStatus.unauthenticated
                    ? 'AGY_ACP_SIGN_IN_REQUIRED'
                    : result['state'] == 'saved'
                    ? 'AGY_ACP_CREDENTIALS_NOT_VALIDATED'
                    : 'AGY_AUTH_CHECK_UNAVAILABLE'),
            authentication: authentication,
          );
        } on FormatException {
          return finish(
            acpMissingDetail == null
                ? AgentEnvironmentStatusKind.ready
                : AgentEnvironmentStatusKind.acpMissing,
            version: _tail(cli.stdout),
            detail: acpMissingDetail ?? 'AGY_AUTH_CHECK_INVALID',
          );
        }
      }
      if (profile.cliCommand == 'claude' &&
          loginCheck == 'claude auth status --json') {
        if (!login.isSuccess && login.exitCode != 1) {
          return finish(
            AgentEnvironmentStatusKind.error,
            detail: 'AUTH_CHECK_UNSUPPORTED_OR_FAILED',
          );
        }
        try {
          final result = jsonDecode(login.stdout) as Map<String, dynamic>;
          if (result['loggedIn'] is! bool) {
            return finish(
              AgentEnvironmentStatusKind.error,
              detail: 'AUTH_CHECK_RESPONSE_INVALID',
            );
          }
          final loggedIn = result['loggedIn'] == true;
          return finish(
            acpMissingDetail != null
                ? AgentEnvironmentStatusKind.acpMissing
                : (loggedIn
                      ? AgentEnvironmentStatusKind.ready
                      : AgentEnvironmentStatusKind.notLoggedIn),
            version: _tail(cli.stdout),
            detail: acpMissingDetail,
            authentication: loggedIn
                ? AgentAuthenticationStatus.authenticated
                : AgentAuthenticationStatus.unauthenticated,
          );
        } on FormatException {
          return finish(
            AgentEnvironmentStatusKind.error,
            detail: 'AUTH_CHECK_RESPONSE_INVALID',
          );
        } on TypeError {
          return finish(
            AgentEnvironmentStatusKind.error,
            detail: 'AUTH_CHECK_RESPONSE_INVALID',
          );
        }
      }
      if (!login.isSuccess) {
        return finish(
          acpMissingDetail == null
              ? AgentEnvironmentStatusKind.notLoggedIn
              : AgentEnvironmentStatusKind.acpMissing,
          authentication: AgentAuthenticationStatus.unauthenticated,
          detail:
              acpMissingDetail ??
              _tail(
                [
                  login.stdout,
                  login.stderr,
                ].where((value) => value.isNotEmpty).join('\n'),
              ),
        );
      }

      return finish(
        acpMissingDetail == null
            ? AgentEnvironmentStatusKind.ready
            : AgentEnvironmentStatusKind.acpMissing,
        version: _tail(cli.stdout),
        detail: acpMissingDetail,
        authentication: AgentAuthenticationStatus.authenticated,
      );
    } on AppException catch (e) {
      note('validation: ${e.message}');
      return finish(AgentEnvironmentStatusKind.error, detail: e.message);
    } on TimeoutException {
      note('probe: timeout');
      return finish(
        AgentEnvironmentStatusKind.error,
        detail: 'AGENT_ENVIRONMENT_CHECK_TIMEOUT',
      );
    } catch (error) {
      note('probe: ${error.runtimeType}');
      return finish(
        AgentEnvironmentStatusKind.error,
        detail: 'AGENT_ENVIRONMENT_CHECK_FAILED',
      );
    }
  }

  /// 仅由上层确认后显式调用；缺命令则拒绝。
  Future<SSHExecutionResult> runInstall(AgentProfile profile, String serverId) {
    AgentCommandValidator.require(
      profile.installCommand,
      label: 'installCommand',
    );
    return _ssh.executeWithLoginShell(
      serverId,
      agentTargetCommand(profile, profile.installCommand!),
      timeout: installTimeout,
    );
  }

  /// 执行一条调用方选定的安装命令（用于安装 CLI 或 ACP 组件）。
  ///
  /// 上层根据检测结果决定传 `installCommand` 还是 `acpInstallCommand`；
  /// 命令为空或含不安全字符时抛 [ValidationException]。
  Future<SSHExecutionResult> runInstallCommand(
    AgentProfile profile,
    String serverId, {
    required String command,
  }) {
    AgentCommandValidator.require(command, label: 'installCommand');
    return _ssh.executeWithLoginShell(
      serverId,
      agentTargetCommand(profile, command),
      timeout: installTimeout,
    );
  }

  /// 与 [runInstallCommand] 相同的校验与超时，但**实时**推送输出片段，
  /// 供 UI 展示安装进度。
  Stream<String> streamInstallCommand(
    AgentProfile profile,
    String serverId, {
    required String command,
  }) {
    AgentCommandValidator.require(command, label: 'installCommand');
    return _ssh
        .executeStreaming(
          serverId,
          agentTargetCommand(profile, command),
          timeout: installTimeout,
        )
        .map((chunk) => chunk.text);
  }

  /// 非交互式执行登录命令，缺命令则拒绝。
  ///
  /// 注意：所有内置 Agent 的 loginCommand（`claude login`、`codex login`、
  /// `opencode auth login`）都是需要 TTY 的交互式流程（浏览器 OAuth / 输入
  /// 验证码），用本方法执行只会拿到挂起的进程或误报成功。UI 必须走
  /// `showInteractiveLoginDialog` 打开交互式终端；本方法仅为将来存在真正
  /// 非交互登录方式的 Agent 保留，目前无生产调用方。
  Future<SSHExecutionResult> runLogin(AgentProfile profile, String serverId) {
    AgentCommandValidator.require(profile.loginCommand, label: 'loginCommand');
    return _ssh.executeWithLoginShell(
      serverId,
      agentTargetCommand(profile, profile.loginCommand!),
      timeout: loginTimeout,
    );
  }

  AgentEnvironmentStatus _status(
    AgentEnvironmentStatusKind kind, {
    String? version,
    String? detail,
    String diagnosticLog = '',
    AgentAuthenticationStatus authentication =
        AgentAuthenticationStatus.unknown,
  }) {
    return AgentEnvironmentStatus(
      kind: kind,
      version: version?.trim().isEmpty ?? true ? null : version!.trim(),
      detail: detail?.trim().isEmpty ?? true ? null : detail!.trim(),
      diagnosticLog: diagnosticLog,
      checkedAt: DateTime.now(),
      authentication: authentication,
    );
  }

  /// 取输出尾部若干行，避免把整段远端输出带入 UI 状态。
  String _tail(String output, {int maxLines = 5}) {
    final lines = output
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .toList();
    final tail = lines.length <= maxLines
        ? lines.join('\n')
        : lines.sublist(lines.length - maxLines).join('\n');
    return LogSanitizer.sanitize(tail);
  }
}
