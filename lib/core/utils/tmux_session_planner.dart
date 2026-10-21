import 'shell_quote.dart';
import '../../data/models/tmux_socket_source.dart';

export '../../data/models/tmux_socket_source.dart';

/// 终端会话在 tmux 中的命名与命令构造（纯逻辑）。
///
/// 抽成独立单元有两个理由：
/// 1. 新建始终使用App专用socket；外部会话仅通过明确来源与已校验身份操作。
/// 2. 无副作用，测试可以直接断言生成的命令字符串。
abstract final class TmuxSessionPlanner {
  static String socketArguments(TmuxSocketSource socket) =>
      socket.kind == TmuxSocketKind.app
      ? '-L valhalla'
      : socket.kind == TmuxSocketKind.standard
      ? '-L default'
      : '${socket.kind == TmuxSocketKind.path ? '-S' : '-L'} ${cliShellQuote(socket.value)}';

  static String existingCommand(
    String verb,
    String name, {
    TmuxSocketSource socket = TmuxSocketSource.app,
    TmuxSessionIdentity? identity,
  }) {
    if (!const [
      'attach-session',
      'has-session',
      'kill-session',
    ].contains(verb)) {
      throw ArgumentError('TMUX_INVALID_OPERATION');
    }
    identity?.validate();
    if (identity == null && socket.id != TmuxSocketSource.app.id) {
      throw ArgumentError('TMUX_INVALID_SESSION_IDENTITY');
    }
    if (identity == null) _validateName(name);
    final target = identity?.sessionId ?? '=$name';
    return 'tmux ${socketArguments(socket)} $verb -t ${cliShellQuote(target)}';
  }

  static String discoverCommand(TmuxSocketSource socket) =>
      "tmux ${socketArguments(socket)} list-sessions -F '#{session_id}\t#{session_created}\t#{session_attached}\t#{pid}\t#{socket_path}\t#{session_name}'";

  static String identityCommand(
    TmuxSocketSource socket,
    TmuxSessionIdentity identity,
  ) {
    identity.validate();
    return 'tmux ${socketArguments(socket)} display-message -p -t ${cliShellQuote(identity.sessionId)} '
        "'#{session_id}\t#{session_created}\t#{pid}\t#{socket_path}'";
  }

  /// 专用 tmux socket 名。
  ///
  /// `-L <name>` 让 tmux 使用 `$TMPDIR/tmux-<uid>/<name>` 而不是默认 socket，
  /// 从而与用户自己的 tmux 隔离；用户明确选择外部历史时使用其配置的socket。
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
  static bool isOwnSession(String name) =>
      RegExp(r'^valhalla_[A-Za-z0-9_-]+$').hasMatch(name);

  static bool isSessionForServer(String name, String serverId) {
    final prefix = sessionName(serverId, '');
    return isOwnSession(name) &&
        name.startsWith(prefix) &&
        name.length > prefix.length;
  }

  /// 新建不能复用同名会话；名称由调用方的独立 UUID 生成。
  static String createCommand(
    String serverId,
    String terminalId, {
    int initialWidth = 80,
    int initialHeight = 24,
  }) {
    final name = sessionName(serverId, terminalId);
    final width = initialWidth > 0 ? initialWidth : 80;
    final height = initialHeight > 0 ? initialHeight : 24;
    return 'tmux -L $socketName new-session -s ${cliShellQuote(name)} '
        '-x $width -y $height';
  }

  /// 只附着精确名称，不创建、不分离其他客户端。
  static String attachCommand(String name) {
    _validateName(name);
    return 'tmux -L $socketName attach-session -t ${cliShellQuote('=$name')}';
  }

  static String hasSessionCommand(String name) {
    _validateName(name);
    return 'tmux -L $socketName has-session -t ${cliShellQuote('=$name')}';
  }

  static String killSessionCommand(String name) {
    _validateName(name);
    return 'tmux -L $socketName kill-session -t ${cliShellQuote('=$name')}';
  }

  static const listSessionsCommand =
      "tmux -L $socketName list-sessions -F '#{session_name}\t#{session_created}\t#{session_attached}'";

  static void _validateName(String name) {
    if (!isOwnSession(name)) throw ArgumentError('TMUX_INVALID_SESSION_NAME');
  }

  /// 仅检测 tmux 是否存在（不安装、不改动任何会话）。
  static const detectCommand = 'command -v tmux';

  /// 解析 `command -v tmux` 的输出，判断 tmux 是否可用。
  ///
  /// 只认绝对路径，避免把 shell 的错误信息误判成可执行文件。
  static bool isTmuxAvailable(String? detectOutput) {
    final path = detectOutput?.trim() ?? '';
    if (path.isEmpty) return false;
    return path.startsWith('/') && !RegExp(r'[\r\n\x00]').hasMatch(path);
  }
}
