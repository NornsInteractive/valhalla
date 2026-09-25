/// 终端会话在 tmux 中的命名与命令构造（纯逻辑）。
///
/// 抽成独立单元有两个理由：
/// 1. 命令拼装是安全敏感点 —— 必须保证**永远**只操作独立 socket，
///    绝不能碰到默认 socket（那是用户自己 tmux 会话所在的地方）；
/// 2. 无副作用，测试可以直接断言生成的命令字符串。
abstract final class TmuxSessionPlanner {
  /// 专用 tmux socket 名。
  ///
  /// `-L <name>` 让 tmux 使用 `$TMPDIR/tmux-<uid>/<name>` 而不是默认 socket，
  /// 从而与用户自己的 tmux 完全隔离。任何 tmux 调用都必须带上它。
  static const socketName = 'valhalla';

  /// 会话名前缀，便于在 `tmux -L valhalla ls` 里识别归属。
  static const sessionPrefix = 'valhalla';

  /// 由服务器与终端标识生成稳定的 tmux 会话名。
  ///
  /// 会话名里只允许出现安全字符：tmux 的 `-s` 参数会被 shell 解析，
  /// 而 serverId 可能来自用户输入，因此这里做白名单过滤而不是转义。
  static String sessionName(String serverId, String terminalId) {
    final raw = '${sessionPrefix}_${serverId}_$terminalId';
    final sanitized = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return sanitized;
  }

  /// 是否应把某个会话名视为本应用创建。
  static bool isOwnSession(String name) => name.startsWith('${sessionPrefix}_');

  /// 构造「附着或新建」命令。
  ///
  /// `new-session -A -s <name>`：存在就 attach，不存在就创建 —— 正是
  /// 「断线重连后终端内容还在」的关键。
  ///
  /// [initialWidth]/[initialHeight] 只作用于新建的会话；attach 已有会话时
  /// tmux 会沿用该会话自己的尺寸。
  static String attachOrCreateCommand(
    String serverId,
    String terminalId, {
    int initialWidth = 80,
    int initialHeight = 24,
  }) {
    final name = sessionName(serverId, terminalId);
    final width = initialWidth > 0 ? initialWidth : 80;
    final height = initialHeight > 0 ? initialHeight : 24;
    // -L 必须在最前，且与子命令之间用空格分隔。
    return 'tmux -L $socketName new-session -A -s $name '
        '-x $width -y $height';
  }

  /// 仅检测 tmux 是否存在（不安装、不改动任何会话）。
  static const detectCommand = 'command -v tmux';

  /// 解析 `command -v tmux` 的输出，判断 tmux 是否可用。
  ///
  /// 只认绝对路径，避免把 shell 的错误信息误判成可执行文件。
  static bool isTmuxAvailable(String? detectOutput) {
    final path = detectOutput?.trim() ?? '';
    if (path.isEmpty) return false;
    return path.startsWith('/');
  }
}
