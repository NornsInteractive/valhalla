import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/agent_profile.dart';
import '../../infrastructure/acp/agent_environment_service.dart';
import '../errors/app_exceptions.dart';
import 'infrastructure_providers.dart';
import 'server_provider.dart';
import 'storage_providers.dart';

/// 描述一个 Agent 在当前服务器上的运行时状态。
class AgentRuntimeState {
  final AgentProfile profile;
  final AgentEnvironmentStatus status;
  final bool isInstalling;
  final bool isLoggingIn;

  /// 稳定 reason code（非本地化文案），由 UI 映射 ARB。
  final String? errorMessage;

  const AgentRuntimeState({
    required this.profile,
    required this.status,
    this.isInstalling = false,
    this.isLoggingIn = false,
    this.errorMessage,
  });

  bool get isReady => status.kind == AgentEnvironmentStatusKind.ready;

  AgentRuntimeState copyWith({
    AgentProfile? profile,
    AgentEnvironmentStatus? status,
    bool? isInstalling,
    bool? isLoggingIn,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AgentRuntimeState(
      profile: profile ?? this.profile,
      status: status ?? this.status,
      isInstalling: isInstalling ?? this.isInstalling,
      isLoggingIn: isLoggingIn ?? this.isLoggingIn,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// 当前服务器已添加 Agent 的集合与每个 Agent 的检测状态。
class AgentRegistryState {
  final String? serverId;
  final List<AgentRuntimeState> agents;
  final bool isLoading;

  const AgentRegistryState({
    this.serverId,
    this.agents = const [],
    this.isLoading = false,
  });

  /// 派生列表：仅包含当前服务器已添加且就绪的 Agent。
  List<AgentProfile> get readyAgents => agents
      .where(
        (agent) =>
            agent.isReady &&
            agent.profile.serverId == serverId &&
            (agent.profile.acpCommand?.trim().isNotEmpty ?? false),
      )
      .map((agent) => agent.profile)
      .toList();

  AgentRuntimeState? findRuntime(String agentId) {
    for (final agent in agents) {
      if (agent.profile.id == agentId) return agent;
    }
    return null;
  }

  AgentRegistryState copyWith({
    String? serverId,
    bool clearServerId = false,
    List<AgentRuntimeState>? agents,
    bool? isLoading,
  }) {
    return AgentRegistryState(
      serverId: clearServerId ? null : (serverId ?? this.serverId),
      agents: agents ?? this.agents,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 管理当前服务器 Agent 列表与检测状态。
///
/// 监听 `activeServerProvider`：切换服务器时整体重建，绝不复用其它服务器的
/// 运行时状态。监听 `serverConnectionProvider`：SSH 连上后自动检测一次，断连
/// 时把运行时结果重置为 unknown（不触碰网络，也不重建本 provider）。
class AgentRegistryNotifier extends Notifier<AgentRegistryState> {
  int _environmentEpoch = 0;
  static const disconnectedCode = 'SSH_DISCONNECTED';

  @override
  AgentRegistryState build() {
    _environmentEpoch++;
    ref.watch(activeServerProvider.select((s) => s?.connectionKey));
    final server = ref.read(activeServerProvider);
    final repo = ref.watch(agentRepositoryProvider);

    // 连接状态变化的两个职责，都放在这一个监听里：
    //   - 断开：把上一次的运行时检测结果清空（全 unknown + 断连 reason code）。
    //   - 连上（首次连接或重连）：自动检测一次，用户不必再去点「检测状态」。
    //
    // 这里刻意**不** `ref.watch(serverConnectionProvider)`，也不用
    // `ref.invalidateSelf()`：两者都会让本 provider 在连接变化时重建，而重建
    // 会清掉本元素 `dependents` 里的订阅（Riverpod 文档："Listeners will
    // automatically be removed when the provider rebuilds"），回调永远来不及
    // 跑——表现为「自动检测」完全失效，且没有任何报错。改用 `weak: true` 只能
    // 让回调收到**第一次**变化，weak 订阅在重建后不会被重新接线，重连那次依旧
    // 收不到。所以正解是根本不重建：由监听自己调 `_markAllDisconnected()` 重置。
    //
    // 另注意要裸调 refresh()，不能 ref.read(agentRegistryProvider.notifier)：
    // 那会让 provider 依赖自己，Riverpod 断言 "A provider cannot depend on
    // itself" 失败，而断言在 unawaited 里被静默吞掉。
    ref.listen(serverConnectionProvider, (prev, next) {
      if (prev?.isConnected == true && !next.isConnected) {
        _environmentEpoch++;
        _markAllDisconnected();
        return;
      }
      if (next.isConnected && prev?.isConnected != true) {
        unawaited(refresh());
      }
    });

    if (server == null) {
      return const AgentRegistryState();
    }

    final agents = repo
        .getAll(server.id)
        .map(
          (profile) => AgentRuntimeState(
            profile: profile,
            status: AgentEnvironmentStatus.unknown(),
          ),
        )
        .toList();

    return AgentRegistryState(serverId: server.id, agents: agents);
  }

  bool get _isConnected {
    final serverId = state.serverId;
    if (serverId == null) return false;
    // The connection notifier can briefly lag the SSH manager while a command
    // channel is being opened/reused. Agent execution already trusts the
    // executor, so status probes must use the same source of truth.
    final executorConnected = ref
        .read(sshCommandExecutorProvider)
        .isConnected(serverId);
    return executorConnected || ref.read(serverConnectionProvider).isConnected;
  }

  /// 只读检测：刷新所有 Agent 的环境状态。
  Future<void> refresh() async {
    final epoch = _environmentEpoch;
    final serverId = state.serverId;
    if (serverId == null) return;

    if (!_isConnected) {
      _markAllDisconnected();
      return;
    }

    state = state.copyWith(isLoading: true);
    final service = ref.read(agentEnvironmentServiceProvider);
    final updated = <AgentRuntimeState>[];
    for (final agent in state.agents) {
      final status = await service.inspect(agent.profile, serverId);
      if (!ref.mounted ||
          epoch != _environmentEpoch ||
          state.serverId != serverId) {
        return;
      }
      updated.add(
        agent.copyWith(
          status: status,
          clearError: status.kind == AgentEnvironmentStatusKind.ready,
        ),
      );
    }
    state = state.copyWith(
      agents: state.agents.map((current) {
        final checked = updated
            .where((entry) => entry.profile.id == current.profile.id)
            .firstOrNull;
        return checked == null
            ? current
            : current.copyWith(
                status: checked.status,
                clearError:
                    checked.status.kind == AgentEnvironmentStatusKind.ready,
              );
      }).toList(),
      isLoading: false,
    );
  }

  /// 只读检测单个 Agent。
  Future<void> refreshAgent(String agentId) async {
    final epoch = _environmentEpoch;
    final serverId = state.serverId;
    final runtime = state.findRuntime(agentId);
    if (serverId == null || runtime == null) return;

    if (!_isConnected) {
      _replace(
        runtime.copyWith(
          status: AgentEnvironmentStatus.unknown(),
          errorMessage: disconnectedCode,
        ),
      );
      return;
    }

    final service = ref.read(agentEnvironmentServiceProvider);
    final status = await service.inspect(runtime.profile, serverId);
    if (!ref.mounted ||
        epoch != _environmentEpoch ||
        state.serverId != serverId) {
      return;
    }
    _replace(
      runtime.copyWith(
        status: status,
        clearError: status.kind == AgentEnvironmentStatusKind.ready,
      ),
    );
  }

  /// 保存配置后立即检测；绝不自动安装。
  Future<void> addAgent(AgentProfile profile) async {
    if (state.serverId == null || profile.serverId != state.serverId) {
      throw const ValidationException('AGENT_SERVER_CHANGED');
    }
    final repo = ref.read(agentRepositoryProvider);
    await repo.save(profile);
    if (!ref.mounted || state.serverId != profile.serverId) return;

    final runtime = AgentRuntimeState(
      profile: profile,
      status: AgentEnvironmentStatus.unknown(),
    );
    state = state.copyWith(agents: [...state.agents, runtime]);
    await refreshAgent(profile.id);
  }

  /// Edits only an existing profile on the active server; session identity stays
  /// stable, while probe results are discarded and recomputed.
  Future<void> updateAgent(AgentProfile profile) async {
    final current = state.findRuntime(profile.id);
    if (state.serverId == null ||
        profile.serverId != state.serverId ||
        current == null ||
        current.isInstalling ||
        current.isLoggingIn) {
      throw const ValidationException('AGENT_EDIT_UNAVAILABLE');
    }
    _environmentEpoch++;
    await ref.read(agentRepositoryProvider).save(profile);
    if (!ref.mounted || state.serverId != profile.serverId) return;
    _replace(
      AgentRuntimeState(
        profile: profile,
        status: AgentEnvironmentStatus.unknown(),
      ),
    );
    await refreshAgent(profile.id);
  }

  /// 删除配置与运行时状态；不影响 ChatSession / SSH 凭据。
  Future<void> deleteAgent(String agentId) async {
    final serverId = state.serverId;
    if (serverId == null) return;
    await ref.read(agentRepositoryProvider).delete(serverId, agentId);
    if (!ref.mounted || state.serverId != serverId) return;
    state = state.copyWith(
      agents: state.agents.where((a) => a.profile.id != agentId).toList(),
    );
  }

  /// 仅由 UI 确认后调用；执行安装命令并重新检测。
  ///
  /// 兼容入口：等价于 [installForCurrentStatus]，保留供既有调用方使用。
  Future<void> installAgent(String agentId) => installForCurrentStatus(agentId);

  /// 按当前缺失状态选择安装命令并执行，随后重新探测。
  ///
  /// - `cliMissing` → `installCommand`
  /// - `acpMissing` → `acpInstallCommand ?? installCommand`
  /// - 其它状态（`ready`/`notLoggedIn`/`unknown`/...）→ no-op，
  ///   避免在无需安装时误执行命令。
  ///
  /// 无可用命令时写入稳定 reason code（`CMD_MISSING:installCommand`），
  /// 绝不静默失败。
  Future<void> installForCurrentStatus(String agentId) async {
    final serverId = state.serverId;
    final runtime = state.findRuntime(agentId);
    if (serverId == null || runtime == null) return;

    if (!_isConnected) {
      _replace(runtime.copyWith(errorMessage: disconnectedCode));
      return;
    }

    final command = _installCommandFor(runtime);
    if (command == null || command.trim().isEmpty) {
      _replace(
        runtime.copyWith(
          errorMessage: 'CMD_MISSING:installCommand',
          isInstalling: false,
        ),
      );
      return;
    }

    _replace(runtime.copyWith(isInstalling: true, clearError: true));
    final service = ref.read(agentEnvironmentServiceProvider);
    final log = ref.read(installLogProvider.notifier);
    log.start(agentId);
    try {
      await for (final chunk in service.streamInstallCommand(
        runtime.profile,
        serverId,
        command: command,
      )) {
        log.append(chunk);
      }
      log.flush();

      final after = state.findRuntime(agentId);
      if (after != null) {
        _replace(after.copyWith(isInstalling: false, clearError: true));
      }
      await refreshAgent(agentId);
    } on AppException catch (e) {
      final after = state.findRuntime(agentId);
      if (after != null) {
        _replace(after.copyWith(isInstalling: false, errorMessage: e.message));
      }
    }
  }

  /// 按缺失状态挑安装命令；仅 `cliMissing`/`acpMissing` 可安装。
  String? _installCommandFor(AgentRuntimeState runtime) {
    final profile = runtime.profile;
    switch (runtime.status.kind) {
      case AgentEnvironmentStatusKind.cliMissing:
        return profile.installCommand ?? profile.acpInstallCommand;
      case AgentEnvironmentStatusKind.acpMissing:
        return profile.acpInstallCommand ?? profile.installCommand;
      case AgentEnvironmentStatusKind.unknown:
      case AgentEnvironmentStatusKind.checking:
      case AgentEnvironmentStatusKind.notLoggedIn:
      case AgentEnvironmentStatusKind.ready:
      case AgentEnvironmentStatusKind.error:
        return null;
    }
  }

  /// 交互式登录流程结束后调用：仅重新探测环境态。
  ///
  /// 登录命令本身由 UI 在**交互式终端弹窗**中执行（`codex login` 这类 TUI
  /// 需要真实 TTY 与用户操作，无法用后台 exec 完成）。本方法只负责在用户
  /// 完成操作后重跑 `loginCheckCommand`，据以判定 `ready` / `notLoggedIn`。
  Future<void> loginAgent(String agentId) async {
    final serverId = state.serverId;
    final runtime = state.findRuntime(agentId);
    if (serverId == null || runtime == null) return;

    if (!_isConnected) {
      _replace(runtime.copyWith(errorMessage: disconnectedCode));
      return;
    }

    await refreshAgent(agentId);
  }

  void _markAllDisconnected() {
    state = state.copyWith(
      agents: state.agents
          .map(
            (a) => a.copyWith(
              status: AgentEnvironmentStatus.unknown(),
              errorMessage: disconnectedCode,
            ),
          )
          .toList(),
    );
  }

  void _replace(AgentRuntimeState runtime) {
    if (!ref.mounted || state.serverId != runtime.profile.serverId) return;
    state = state.copyWith(
      agents: state.agents
          .map((a) => a.profile.id == runtime.profile.id ? runtime : a)
          .toList(),
    );
  }
}

final agentRegistryProvider =
    NotifierProvider<AgentRegistryNotifier, AgentRegistryState>(
      AgentRegistryNotifier.new,
    );

/// 一次安装过程的实时输出日志。
class InstallLog {
  /// 正在安装（或最近一次安装）的 Agent id；无日志时为 null。
  final String? agentId;

  /// 已完整接收的输出行。
  final List<String> lines;

  /// 是否因超出上限丢弃了较早的行。
  final bool truncated;

  const InstallLog({
    this.agentId,
    this.lines = const [],
    this.truncated = false,
  });

  bool get isEmpty => lines.isEmpty;

  InstallLog copyWith({
    String? agentId,
    List<String>? lines,
    bool? truncated,
    bool clearAgentId = false,
  }) {
    return InstallLog(
      agentId: clearAgentId ? null : (agentId ?? this.agentId),
      lines: lines ?? this.lines,
      truncated: truncated ?? this.truncated,
    );
  }

  static const empty = InstallLog();
}

/// 安装输出的**独立**状态，避免每来一行就重建整个 Agent 列表。
///
/// 只保留最近一次安装的日志（UI 同时只会展示一个安装过程），并带上限，
/// 防止 `npm install` 这类输出把内存撑爆。
class InstallLogNotifier extends Notifier<InstallLog> {
  /// 保留的最大行数；超出后从头丢弃并置 [InstallLog.truncated]。
  static const maxLines = 2000;

  /// 尚未遇到换行的尾片段，等下个片段拼接后再成行。
  String _pending = '';

  @override
  InstallLog build() => InstallLog.empty;

  /// 开始一次新的安装，清空旧日志。
  void start(String agentId) {
    _pending = '';
    state = InstallLog(agentId: agentId);
  }

  /// 追加一段流式输出，按换行切分为整行。
  void append(String chunk) {
    if (chunk.isEmpty) return;

    final combined = _pending + chunk;
    final parts = combined.split('\n');
    // 最后一段没有以换行结尾，留到下次拼接。
    _pending = parts.removeLast();

    if (parts.isEmpty) return;

    final next = [...state.lines, ...parts];
    final overflow = next.length > maxLines;
    state = state.copyWith(
      lines: overflow ? next.sublist(next.length - maxLines) : next,
      truncated: state.truncated || overflow,
    );
  }

  /// 流结束时把残留的尾片段补成最后一行。
  void flush() {
    if (_pending.isEmpty) return;
    final line = _pending;
    _pending = '';
    append('$line\n');
  }

  void clear() {
    _pending = '';
    state = InstallLog.empty;
  }
}

final installLogProvider = NotifierProvider<InstallLogNotifier, InstallLog>(
  InstallLogNotifier.new,
);
