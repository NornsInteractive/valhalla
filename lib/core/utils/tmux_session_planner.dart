import 'dart:convert';

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

  /// 发现/身份查询的线上帧版本。
  ///
  /// - v1：直接按原始 U+001F 切分。
  /// - v2：tmux 会把 `-F` 输出里的不可打印字节转义成 `\NNN`（三位八进制），
  ///   并把字面反斜杠转义成 `\\`；我们用作分隔符的 U+001F 属于不可打印字节，
  ///   因此真实响应里分隔符是四字符序列 `\037`（反斜杠 + `0` + `3` + `7`），
  ///   而不是单个 0x1F 字节。v2 在切分前先调用 [decodeTmuxFormatEscapes] 还原，
  ///   同时继续兼容仍返回原始 0x1F 的响应。
  static const int framingVersion = 2;

  /// 协议输出字段分隔符（逻辑分隔符）。
  ///
  /// 使用单个 UNIT SEPARATOR (U+001F)。tmux 的会话名可以包含制表符、空格、
  /// 任意 UTF-8、甚至换行，因此用空白/制表符做分隔符会把一条合法记录拆成
  /// 多条字段而误报 `TMUX_HISTORY_INVALID_RESPONSE`。
  ///
  /// 注意：**不能**假设 tmux 会话名或 socket 路径是「不能含 U+001F 的
  /// NUL 结尾 C 字符串」——会话名允许任意字节，tmux 会把这些不可打印字节
  /// 转义后再输出。所以真正的分隔符在线上会以字面量 `\037` 出现，解析前必须
  /// 先经过 [decodeTmuxFormatEscapes]（见 [framingVersion] v2）。
  static const String fieldSeparator = '\u001f';

  /// 还原 tmux `-F` 输出中的转义。
  ///
  /// tmux 在格式化输出时会把不可打印字节转义为 `\NNN`（三位八进制），并把
  /// 字面反斜杠转义为 `\\`。解码规则严格对应 tmux 的转义方式：
  /// - `\\`   -> 单个反斜杠
  /// - `\NNN` -> 三位八进制对应的字节（例如 `\037` -> 0x1F 分隔符）
  /// - 其它内容（含原始 0x1F、普通文本）原样保留
  ///
  /// 只变换真正的转义序列，绝不会把 name/socket 里的普通字符「顺手替换」掉：
  /// 对本应用生成的会话名（`[A-Za-z0-9_-]`）与文件系统 socket 路径而言解码
  /// 是恒等操作；对不含反斜杠的响应直接原样返回，因此含原始 0x1F 的旧响应
  /// 完全向后兼容。
  static String decodeTmuxFormatEscapes(String raw) {
    if (!raw.contains(r'\')) return raw;
    final bytes = <int>[];
    var i = 0;
    final n = raw.length;
    while (i < n) {
      final c = raw.codeUnitAt(i);
      if (c == 0x5c) {
        // 反斜杠：优先处理转义的反斜杠与三位八进制字节。
        if (i + 1 < n && raw.codeUnitAt(i + 1) == 0x5c) {
          bytes.add(0x5c);
          i += 2;
          continue;
        }
        if (i + 3 < n) {
          final d1 = raw.codeUnitAt(i + 1);
          final d2 = raw.codeUnitAt(i + 2);
          final d3 = raw.codeUnitAt(i + 3);
          if (_isOctal(d1) && _isOctal(d2) && _isOctal(d3)) {
            bytes.add((d1 - 0x30) * 64 + (d2 - 0x30) * 8 + (d3 - 0x30));
            i += 4;
            continue;
          }
        }
        // 未知转义：保留反斜杠本身，避免吞掉数据。
        bytes.add(0x5c);
        i += 1;
        continue;
      }
      if (c < 0x80) {
        bytes.add(c);
        i += 1;
        continue;
      }
      // 非 ASCII：原始字符已是解码后的码点，重新编码成 UTF-8 字节以保持一致。
      if (c >= 0xD800 &&
          c <= 0xDBFF &&
          i + 1 < n &&
          raw.codeUnitAt(i + 1) >= 0xDC00 &&
          raw.codeUnitAt(i + 1) <= 0xDFFF) {
        bytes.addAll(
          utf8.encode(String.fromCharCodes([c, raw.codeUnitAt(i + 1)])),
        );
        i += 2;
        continue;
      }
      bytes.addAll(utf8.encode(String.fromCharCode(c)));
      i += 1;
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static bool _isOctal(int c) => c >= 0x30 && c <= 0x37;

  static String discoverCommand(TmuxSocketSource socket) =>
      'tmux ${socketArguments(socket)} list-sessions -F '
      "'#{session_id}$fieldSeparator#{session_created}$fieldSeparator"
      "#{session_attached}$fieldSeparator#{pid}$fieldSeparator"
      "#{socket_path}$fieldSeparator#{session_name}'";

  static String identityCommand(
    TmuxSocketSource socket,
    TmuxSessionIdentity identity,
  ) {
    identity.validate();
    return 'tmux ${socketArguments(socket)} display-message -p -t ${cliShellQuote(identity.sessionId)} '
        "'#{session_id}$fieldSeparator#{session_created}$fieldSeparator"
        "#{pid}$fieldSeparator#{socket_path}'";
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
