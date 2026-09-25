import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/tool_probe.dart';
import 'infrastructure_providers.dart';
import 'server_provider.dart';

/// 远端工具可用性的当前快照。
///
/// **仅供内部状态使用** —— 目前没有任何 UI 消费它。若将来要在界面上展示，
/// 需要由前端会话补 ARB 文案，不要在这里塞本地化字符串。
class ToolAvailability {
  /// 探测到可用 → 可执行文件绝对路径。
  final Map<RemoteTool, String> available;

  /// 远端**明确报告**缺失的工具。
  final Set<RemoteTool> missing;

  final bool isProbing;

  /// 探测本身失败（超时 / 传输错误 / 输出不可解析）。
  ///
  /// 与「工具缺失」严格区分：一次失败的探测**不能**被读成「什么都没有」，
  /// 否则上层会误判远端环境。此时 [available] 与 [missing] 都为空。
  final bool probeFailed;

  const ToolAvailability({
    this.available = const {},
    this.missing = const {},
    this.isProbing = false,
    this.probeFailed = false,
  });

  bool isAvailable(RemoteTool tool) => available.containsKey(tool);

  /// 明确缺失。注意 `!isAvailable(tool)` 的含义更宽，还包含「未知」。
  bool isMissing(RemoteTool tool) => missing.contains(tool);

  /// 是否已给出结论（不论可用还是缺失）。
  bool hasVerdictFor(RemoteTool tool) => isAvailable(tool) || isMissing(tool);

  /// 尚未连接或还没探测过时的初值。
  static const unknown = ToolAvailability();

  ToolAvailability copyWith({
    Map<RemoteTool, String>? available,
    Set<RemoteTool>? missing,
    bool? isProbing,
    bool? probeFailed,
  }) {
    return ToolAvailability(
      available: available ?? this.available,
      missing: missing ?? this.missing,
      isProbing: isProbing ?? this.isProbing,
      probeFailed: probeFailed ?? this.probeFailed,
    );
  }
}

/// SSH 连接成功后自动探测一次远端工具可用性。
///
/// 与 Agent 环境检测是**两套独立机制**：这里关心的是「app 自己的功能依赖的
/// 工具」，与用户配置的 agent 无关。两者各自监听连接状态、并发发起，
/// 不互相调用、也不互相等待 —— agent 检测可能要跑 N×20s，没理由让这条
/// 单命令探测排在它后面。
class ToolAvailabilityNotifier extends Notifier<ToolAvailability> {
  /// 单命令探测很快，10s 足够；超时按探查失败处理而不是「全部缺失」。
  static const probeTimeout = Duration(seconds: 10);

  @override
  ToolAvailability build() {
    ref.watch(activeServerProvider);

    ref.listen(serverConnectionProvider, (prev, next) {
      // 只在「变为已连接」的那一刻触发，同时覆盖首次连接与重连；
      // 已连接期间的无关状态抖动（例如 errorMessage 更新）不重复探测。
      if (next.isConnected && prev?.isConnected != true) {
        // 直接调 this，不能 ref.read 自己 —— Riverpod 会断言
        // "A provider cannot depend on itself"。
        unawaited(probeNow());
      }
    });

    return ToolAvailability.unknown;
  }

  /// 立即探测一次。可由 UI 或测试显式调用。
  Future<void> probeNow() async {
    final server = ref.read(activeServerProvider);
    final connection = ref.read(serverConnectionProvider);

    if (server == null || !connection.isConnected) {
      // 没连上就没有结论可言，保持未知而不是编造「全部缺失」。
      state = ToolAvailability.unknown;
      return;
    }

    state = state.copyWith(
      isProbing: true,
      probeFailed: false,
      available: const {},
      missing: const {},
    );

    final executor = ref.read(sshCommandExecutorProvider);
    try {
      final result = await executor.executeWithLoginShell(
        server.id,
        ToolProbe.command,
        timeout: probeTimeout,
      );

      if (!result.isSuccess) {
        state = const ToolAvailability(probeFailed: true);
        return;
      }

      final parsed = ToolProbe.parse(result.stdout);
      state = parsed.unusable
          // 一行都没解析出来：这是探测失败，不是「所有工具都不存在」。
          ? const ToolAvailability(probeFailed: true)
          : ToolAvailability(
              available: parsed.available,
              missing: parsed.missing,
            );
    } catch (_) {
      // 超时以异常形式抛出（executeWithLoginShell 内部 Timer）。任何异常都
      // 归为探测失败，绝不退化成「远端什么都没有」。
      state = const ToolAvailability(probeFailed: true);
    }
  }
}

final toolAvailabilityProvider =
    NotifierProvider<ToolAvailabilityNotifier, ToolAvailability>(
      ToolAvailabilityNotifier.new,
    );
