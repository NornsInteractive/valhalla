/// SSH 连接成功后探测远端是否具备本 app 依赖的工具（纯逻辑）。
///
/// 抽成独立单元的理由：
/// 1. 命令拼接与输出解析是纯函数，测试可直接断言，无需真实 SSH；
/// 2. 「输出里没出现的工具」必须与「明确报告缺失的工具」区分开 ——
///    这是最容易写错、也最容易让上层误判的地方。
library;

/// 本 app 真正依赖的远端工具。
///
/// 只收录「某个功能硬依赖它」的工具；[awk]/[df]/[cut]/`printf`/`kill` 这类
/// 标准 POSIX 小工具、以及只在安装时一次性用到的 `curl`/`npm`/包管理器
/// 都不在此列。
enum RemoteTool {
  /// 所有非交互命令都被包成 `bash -l -c`，ACP 也用它启动。
  ///
  /// 这条本质上是「哨兵」：如果 `bash -l -c` 能跑通，bash 必然存在。保留它
  /// 只为报告统一，上层不应把「bash 缺失」当作可行动的信号。
  bash,

  /// Docker 页。
  docker,

  /// 服务管理页。
  systemctl,

  /// 进程列表。
  ps,

  /// 可选的 tmux 终端。
  tmux,
}

/// 一次探测的结果。
///
/// [available] 与 [missing] 是**互斥但不必穷尽**的：某个工具可能两者都不在，
/// 表示这次探测没拿到它的结论（输出被截断、命令中途失败等）。
/// 上层必须把这种情况当作「未知」，绝不能当作「不可用」。
class ToolProbeResult {
  /// 探测到可用的工具 → 可执行文件绝对路径。
  final Map<RemoteTool, String> available;

  /// 远端**明确报告**缺失的工具。
  final Set<RemoteTool> missing;

  /// 是否一个合法结果行都没解析出来。
  ///
  /// 用来区分「探测本身失败」与「所有工具都缺失」：banner 噪声、命令报错、
  /// 输出被截断都会落到这里。
  final bool unusable;

  const ToolProbeResult({
    this.available = const {},
    this.missing = const {},
    this.unusable = false,
  });

  bool isAvailable(RemoteTool tool) => available.containsKey(tool);

  /// 明确缺失。注意与 `!isAvailable` 不同：后者包含「未知」。
  bool isMissing(RemoteTool tool) => missing.contains(tool);

  /// 这次探测有没有给出结论（无论可用还是缺失）。
  bool hasVerdictFor(RemoteTool tool) => isAvailable(tool) || isMissing(tool);
}

/// 工具探测的命令构造与输出解析。
abstract final class ToolProbe {
  /// 每条结果行的前缀。`bash -l -c` 会 source 用户的 profile，可能往 stdout
  /// 打 banner，用前缀框架把这些噪声行区分掉。
  static const linePrefix = 'TOOL:';

  /// 一条命令测完全部工具，避免 N 次 SSH 往返。
  ///
  /// 用 `command -v` 而非 `which`：前者是 shell 内建，且与仓库既有探测
  /// （`TmuxSessionPlanner.detectCommand`、agent 环境检测）保持一致。
  ///
  /// 无论工具是否存在都以 `printf` 输出、循环正常结束，所以退出码恒为 0；
  /// 缺工具不会让整条命令变成失败。
  static String get command {
    final names = RemoteTool.values.map((t) => t.name).join(' ');
    return 'for t in $names; do '
        'p=\$(command -v "\$t" 2>/dev/null || true); '
        "if [ -n \"\$p\" ]; then printf '$linePrefix%s:OK:%s\\n' \"\$t\" \"\$p\"; "
        "else printf '$linePrefix%s:MISSING:\\n' \"\$t\"; fi; "
        'done';
  }

  /// 解析探测输出。
  ///
  /// 只认 `TOOL:<name>:<verdict>:<path>` 形式的行，其余一律忽略（profile
  /// banner、警告等）。无法识别的工具名与裁决也忽略。
  ///
  /// 关键约定：**输出里没有出现的工具既不记为可用、也不记为缺失**。远端输出
  /// 被截断时，绝不能因此认为工具不存在。
  static ToolProbeResult parse(String? stdout) {
    final available = <RemoteTool, String>{};
    final missing = <RemoteTool>{};

    final text = stdout ?? '';
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (!line.startsWith(linePrefix)) continue;

      final parts = line.split(':');
      // 期望至少 4 段：TOOL / name / verdict / path(可为空)。
      // 路径本身可能含 ':'，所以尾段要重新拼回去。
      if (parts.length < 4) continue;

      final tool = _toolByName(parts[1]);
      if (tool == null) continue;

      switch (parts[2]) {
        case 'OK':
          final path = parts.sublist(3).join(':').trim();
          // 报 OK 但没给路径，说明这一行不可信，按「无结论」处理。
          if (path.isNotEmpty) available[tool] = path;
        case 'MISSING':
          missing.add(tool);
      }
    }

    return ToolProbeResult(
      available: available,
      missing: missing,
      unusable: available.isEmpty && missing.isEmpty,
    );
  }

  static RemoteTool? _toolByName(String name) {
    for (final tool in RemoteTool.values) {
      if (tool.name == name) return tool;
    }
    return null;
  }
}
