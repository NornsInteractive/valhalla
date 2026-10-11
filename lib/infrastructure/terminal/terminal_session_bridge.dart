import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../../core/utils/tmux_install_planner.dart';
import '../../core/services/app_diagnostics.dart';
import '../../core/utils/tmux_session_planner.dart';
import '../../core/security/agent_command_validator.dart';
import '../../core/utils/shell_quote.dart';
import '../../core/utils/terminal_keys.dart';

enum TerminalConnectionState { connecting, connected, disconnected, error }

/// 终端会话是否运行在 tmux 中。
enum TerminalSessionMode {
  /// 直接开一个普通 PTY。断线后终端内容丢失。
  plain,

  /// 附着到 tmux 会话。断线重连后内容仍在。
  tmux,

  /// 期望用 tmux，但远端没有安装，已降级为 [plain]。
  ///
  /// 单独列出来是因为用户需要知道「这次断线内容会丢」。
  tmuxUnavailable,
}

class TerminalSessionBridge {
  bool _disposed = false;
  int _sessionEpoch = 0;
  final String? launchCommand;

  /// Runs directly over SSH exec with a PTY, without entering shell history.
  final String? remoteExecCommand;
  Timer? _resizeTimer;
  (int, int, int, int)? _sentSize;
  final Terminal terminal;
  final String serverName;

  /// 当前使用的 SSH 客户端。
  ///
  /// 声明为可变：断线重连后必须换成新的客户端，否则终端会一直
  /// 挂着一个已经死掉的 client，表现为「界面活着但敲什么都没反应」。
  SSHClient? sshClient;

  /// 远端服务器 id，用于生成稳定的 tmux 会话名。
  final String serverId;

  /// 终端标识（通常是 tab id），用于区分同一服务器上的多个终端。
  final String terminalId;

  /// 是否优先使用 tmux 保存会话。
  ///
  /// 默认 false：tmux 是 opt-in 能力，由设置页开关决定。忘了显式传参时
  /// 应当落到「普通 SSH PTY」这个安全默认值，而不是意外去探测/使用 tmux。
  final bool preferTmux;

  /// 远端 `tmux` 可执行文件路径；null 表示未探测。
  String? _tmuxPath;

  TerminalSessionMode _mode = TerminalSessionMode.plain;
  TerminalSessionMode get mode => _mode;

  /// 用户已明确拒绝安装，本会话走普通 SSH PTY。
  bool _skipTmuxThisSession = false;

  /// 远端缺 tmux，正在等 UI 询问用户是否安装。此时还没有打开 PTY。
  bool _awaitingTmuxDecision = false;
  bool get awaitingTmuxDecision => _awaitingTmuxDecision;

  /// 探测到的安装命令；无法识别包管理器时为 null。
  ///
  /// 仅当 [awaitingTmuxDecision] 为 true 时有意义。不含展示文案。
  String? proposedInstallCommand;

  SSHSession? _sshSession;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;
  bool _isSessionOpen = false;

  /// PTY 分配（`shell()` / `execute()`）的预算。
  ///
  /// 半开连接上这些调用会永远挂起（TCP 已死但远端无响应，既不返回也不
  /// 抛错），必须加超时，否则重连后终端会停在 connecting 且没有任何报错。
  static const Duration defaultPtyAllocateTimeout = Duration(seconds: 15);

  /// 实际生效的 PTY 分配预算；测试可注入更短的值。
  final Duration ptyAllocateTimeout;

  /// 最近一次的 PTY 尺寸，重连时用它重建会话。
  int _lastWidth = 80;
  int _lastHeight = 24;

  TerminalConnectionState _state = TerminalConnectionState.disconnected;
  TerminalConnectionState get state => _state;

  /// 连接状态变更通知，供弹窗等短生命周期消费者响应断连。
  ///
  /// 现有终端视图忽略此值，行为不变。
  final ValueNotifier<TerminalConnectionState> stateListenable =
      ValueNotifier<TerminalConnectionState>(
        TerminalConnectionState.disconnected,
      );

  void _setState(TerminalConnectionState next) {
    if (_disposed) return;
    _state = next;
    if (stateListenable.value != next) stateListenable.value = next;
  }

  TerminalSessionBridge({
    required this.terminal,
    this.sshClient,
    required this.serverName,
    this.serverId = '',
    this.terminalId = '0',
    this.preferTmux = false,
    this.launchCommand,
    this.remoteExecCommand,
    this.ptyAllocateTimeout = defaultPtyAllocateTimeout,
  }) {
    if (launchCommand != null) AgentCommandValidator.validate(launchCommand!);
    if (remoteExecCommand != null) {
      AgentCommandValidator.validate(remoteExecCommand!);
    }
  }

  Future<void> start({int initialWidth = 80, int initialHeight = 24}) async {
    if (_disposed) return;
    terminal.eraseDisplay();
    terminal.setCursor(0, 0);
    _lastWidth = initialWidth > 0 ? initialWidth : 80;
    _lastHeight = initialHeight > 0 ? initialHeight : 24;

    if (sshClient != null && !sshClient!.isClosed) {
      await _startRealSshSession(_lastWidth, _lastHeight);
    } else {
      _showDisconnectedNotice();
    }
  }

  /// 用户拒绝安装 tmux：立即打开普通 SSH PTY。
  Future<void> proceedWithoutTmux() async {
    _skipTmuxThisSession = true;
    _awaitingTmuxDecision = false;
    proposedInstallCommand = null;

    // 缺 tmux 的路径下现在总是先开好了普通 PTY，所以这里「已经有可用 shell，
    // 只是模式还标着 tmuxUnavailable」。重开一次纯属多余，还会闪屏。
    // 只放行 tmux 模式（那里确实需要从 tmux 切回普通 PTY）。
    if (_isSessionOpen && _mode != TerminalSessionMode.tmux) return;

    if (sshClient == null || sshClient!.isClosed) {
      _showDisconnectedNotice();
      return;
    }
    await _startRealSshSession(_lastWidth, _lastHeight);
  }

  /// 用户确认且远端安装命令已执行成功后，重新探测并尝试附着 tmux。
  Future<void> retryAfterTmuxInstall() async {
    _tmuxPath = null;
    _skipTmuxThisSession = false;
    _awaitingTmuxDecision = false;
    proposedInstallCommand = null;
    if (sshClient == null || sshClient!.isClosed) {
      _showDisconnectedNotice();
      return;
    }
    await _startRealSshSession(_lastWidth, _lastHeight);
  }

  /// 断线重连后换用新的 SSH 客户端并重新建立会话。
  ///
  /// 保留 [terminal] 实例：回滚缓冲是用户的上下文，重建终端会把它清空，
  /// 用户就再也看不到断线之前的输出了。tmux 模式下新会话会自动 attach
  /// 回原来的 tmux session，所以历史输出还能接着往下走。
  Future<void> rebind(SSHClient client) async {
    if (identical(sshClient, client) && _isSessionOpen) return;

    _disposeSession();
    sshClient = client;

    if (client.isClosed) {
      _showDisconnectedNotice();
      return;
    }

    // tmux 路径已探测过就不必再探测：同一台服务器上 tmux 的存在性
    // 不会因为断线而改变。
    _tmuxPath = _mode == TerminalSessionMode.tmux ? _tmuxPath : null;
    await _startRealSshSession(
      _lastWidth,
      _lastHeight,
      preserveScrollback: true,
    );
  }

  /// 探测远端是否装了 tmux。
  ///
  /// 只探测，不安装：用户在决策里明确选了「只提示不自动装」。
  Future<String?> _detectTmux() async {
    if (_tmuxPath != null) return _tmuxPath;
    try {
      // `run` 本身不接受超时参数，用 Future.timeout 兜住探测卡死，
      // 否则探测失败会连带把终端初始化也拖住。
      final result = await sshClient!
          .run(TmuxSessionPlanner.detectCommand)
          .timeout(const Duration(seconds: 10));
      final output = utf8.decode(result, allowMalformed: true);
      if (!TmuxSessionPlanner.isTmuxAvailable(output)) return null;
      _tmuxPath = output.trim().split('\n').first.trim();
      return _tmuxPath;
    } catch (_) {
      // 探测失败按「不可用」处理并降级，绝不因为探测本身而连不上终端。
      return null;
    }
  }

  Future<String?> _detectInstallCommand() async {
    final client = sshClient;
    if (client == null || client.isClosed) return null;
    try {
      final result = await client
          .run(TmuxInstallPlanner.detectPackageManagerCommand)
          .timeout(const Duration(seconds: 10));
      final output = utf8.decode(result, allowMalformed: true);
      return TmuxInstallPlanner.installCommandFor(
        TmuxInstallPlanner.parsePackageManager(output),
      );
    } catch (_) {
      return null;
    }
  }

  /// 后台探测安装命令，完成后推一次状态让 UI 刷新弹窗里的命令文本。
  ///
  /// 单独成方法是为了能用 `unawaited` 调用：探测慢绝不能挡住 PTY 建立。
  Future<void> _probeInstallCommand() async {
    final command = await _detectInstallCommand();
    if (_awaitingTmuxDecision && proposedInstallCommand == null) {
      proposedInstallCommand = command;
      _setState(_state);
    }
  }

  Future<void> _startRealSshSession(
    int width,
    int height, {
    bool preserveScrollback = false,
  }) async {
    if (_disposed) return;
    final epoch = ++_sessionEpoch;
    final client = sshClient;
    bool current() =>
        !_disposed && epoch == _sessionEpoch && identical(client, sshClient);
    // 记住最后一次的尺寸：重连时用它重建 PTY，不然 tmux 会按默认
    // 80x24 重新布局，界面上的窗口大小就会跟实际不符。
    _lastWidth = width > 0 ? width : 80;
    _lastHeight = height > 0 ? height : 24;

    _setState(TerminalConnectionState.connecting);
    terminal.write(
      '\x1b[36m[Connecting to $serverName SSH Shell...]\x1b[0m\r\n',
    );

    final wantTmux = preferTmux && !_skipTmuxThisSession;
    final tmuxPath = wantTmux ? await _detectTmux() : null;
    if (!current()) return;
    final useTmux = tmuxPath != null;

    // 想用 tmux 但远端没有（或探测失败）。这里**不能** return：以前那样做会
    // 让终端停在 connecting 且没有 PTY，调用方（例如 codex login 弹窗）就会
    // 一直转圈、命令永远发不出去。现在照常开一个普通 PTY 保底，同时把
    // awaitingTmuxDecision 置起来让 UI 询问是否安装。
    final needsInstallDecision = wantTmux && !useTmux;

    _awaitingTmuxDecision = needsInstallDecision;
    _mode = useTmux
        ? TerminalSessionMode.tmux
        : (needsInstallDecision
              ? TerminalSessionMode.tmuxUnavailable
              : TerminalSessionMode.plain);

    if (useTmux) {
      terminal.write(
        '\x1b[90m[Attaching tmux session '
        '${TmuxSessionPlanner.sessionName(serverId, terminalId)}]\x1b[0m\r\n',
      );
    }

    try {
      final pty = SSHPtyConfig(
        type: 'xterm-256color',
        width: _lastWidth,
        height: _lastHeight,
      );
      final tmuxCommand = useTmux
          ? TmuxSessionPlanner.attachOrCreateCommand(
              serverId,
              terminalId,
              initialWidth: width,
              initialHeight: height,
            ).replaceFirst('tmux ', '${cliShellQuote(tmuxPath)} ')
          : null;
      final command = remoteExecCommand ?? tmuxCommand;
      final allocation = command == null
          ? client!.shell(pty: pty)
          : client!.execute(command, pty: pty);
      SSHSession session;
      try {
        // 半开连接上 shell()/execute() 会永远挂着；不加超时的话重连后
        // 终端会停在 connecting 且没有任何报错（幽灵终端的另一半）。
        session = await allocation.timeout(ptyAllocateTimeout);
      } on TimeoutException {
        // 超时后底层 future 仍可能迟到完成，迟到的 channel 必须销毁，
        // 不能在服务器上泄漏一个 PTY。
        unawaited(
          allocation.then(
            (lateSession) => _releaseSession(lateSession),
            onError: (Object _) {},
          ),
        );
        // 经由外层既有 catch 统一呈现：error 状态 + 终端诊断行，
        // 且 `current()` 守卫仍然生效（epoch 已变/disposed 时不再写状态）。
        rethrow;
      }
      if (!current()) {
        _releaseSession(session);
        return;
      }
      _sshSession = session;

      _isSessionOpen = true;
      _setState(TerminalConnectionState.connected);

      // 重连时刻意不清屏：回滚缓冲里是断线前的输出，正是用户最需要的
      // 上下文。清掉就变成了「断线前干了什么全看不见」。
      if (!preserveScrollback) {
        terminal.eraseDisplay();
        terminal.setCursor(0, 0);
      }

      _stdoutSub = const Utf8Decoder(allowMalformed: true)
          .bind(_sshSession!.stdout)
          .listen(
            terminal.write,
            onError: (err) {
              terminal.write(
                '\r\n\x1b[31m[SSH Session Error: $err]\x1b[0m\r\n',
              );
              _isSessionOpen = false;
              _setState(TerminalConnectionState.error);
            },
            onDone: () {
              terminal.write(
                '\r\n\x1b[33m[SSH Connection Closed by Remote Host]\x1b[0m\r\n',
              );
              _isSessionOpen = false;
              _setState(TerminalConnectionState.disconnected);
            },
          );

      _stderrSub = const Utf8Decoder(
        allowMalformed: true,
      ).bind(_sshSession!.stderr).listen(terminal.write, onError: (Object error, StackTrace stack) {
        if (!current()) return;
        unawaited(AppDiagnostics.instance.record('terminal.stderr', error, stack));
        _isSessionOpen = false;
        _setState(TerminalConnectionState.error);
      });

      terminal.onOutput = (String data) {
        if (_sshSession != null && _isSessionOpen) {
          _sshSession!.stdin.add(utf8.encode(data));
        }
      };

      terminal.onResize = (int w, int h, int pw, int ph) {
        if (w <= 0 || h <= 0) return;
        _lastWidth = w;
        _lastHeight = h;
        _resizeTimer?.cancel();
        final size = (w, h, pw, ph);
        if (size == _sentSize || !_isSessionOpen) return;
        _resizeTimer = Timer(const Duration(milliseconds: 75), () {
          if (_sshSession != null && _isSessionOpen && size != _sentSize) {
            _sshSession!.resizeTerminal(w, h, pw, ph);
            _sentSize = size;
          }
        });
      };

      // tmux 必须在一个交互式 shell 里启动：`new-session -A` 是前台进程，
      // 直接作为 exec 命令会让 PTY 在没有 shell 的情况下运行，
      // 用户的 shell 配置（PATH/别名）就全没了。
      if (launchCommand != null) {
        _sshSession!.stdin.add(utf8.encode('$launchCommand\n'));
      }

      // 安装命令探测放到最后，并且**不 await**：它最多要等两次 10s 超时的
      // `run`，await 在这里会把这整条初始化（包括 tmux attach）都拖住，
      // 「先开 PTY 保底」就白做了。探测完成后再通知一次，UI 据此刷新弹窗。
      if (needsInstallDecision && proposedInstallCommand == null) {
        unawaited(_probeInstallCommand());
      }
    } catch (e) {
      if (!current()) return;
      _setState(TerminalConnectionState.error);
      terminal.write(
        '\r\n\x1b[31m[Failed to allocate remote PTY: $e]\x1b[0m\r\n',
      );
    }
  }

  void _showDisconnectedNotice() {
    _setState(TerminalConnectionState.disconnected);
    terminal.write(
      '\x1b[33;1mValhalla SSH Terminal\x1b[0m\r\n'
      'Target Server: \x1b[36m$serverName\x1b[0m\r\n'
      'Session Status: \x1b[31mDisconnected\x1b[0m\r\n\r\n'
      '\x1b[90mNo active SSH connection to $serverName.\r\n'
      'Tap [Connect] or [Reconnect] on the top bar to authenticate and establish a live shell.\x1b[0m\r\n',
    );

    terminal.onOutput = (String data) {
      terminal.write(
        '\r\n\x1b[31m[Terminal is offline. Connect to $serverName first.]\x1b[0m\r\n',
      );
    };
  }

  /// 发送指令字符串直接在终端运行
  void sendCommand(String cmd) {
    if (_sshSession != null && _isSessionOpen) {
      _sshSession!.stdin.add(utf8.encode('$cmd\n'));
    } else {
      terminal.write(
        '\r\n\x1b[31m[Cannot execute "$cmd": Server $serverName is not connected.]\x1b[0m\r\n',
      );
    }
  }

  /// 处理移动端按键栏按键映射
  void sendKey(String key, {bool isCtrl = false, bool isAlt = false}) {
    HapticFeedback.lightImpact();
    if (_sshSession != null && _isSessionOpen) {
      sendTerminalAccessoryKey(terminal, key, isCtrl: isCtrl, isAlt: isAlt);
    }
  }

  void pasteText(String text) {
    if (_sshSession != null && _isSessionOpen) {
      terminal.paste(text);
    }
  }

  Future<void> pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      pasteText(data.text!);
    }
  }

  /// 整段终端缓冲的纯文本（含滚动历史）。
  ///
  /// PTY 自动折行（软换行）会被 xterm 重接，因此被折行截断的长链接在这里是
  /// 完整的；CLI 自己插入的硬换行则不会，需由调用方处理。
  String readBufferText() => terminal.buffer.getText();

  /// 把 [text] 写入系统剪贴板，返回写入的字符数。
  ///
  /// [text] 为空时不覆盖剪贴板，返回 0。
  Future<int> copyText(String text) async {
    if (text.isEmpty) return 0;
    await Clipboard.setData(ClipboardData(text: text));
    return text.length;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _disposeSession();
    stateListenable.dispose();
  }

  void _releaseSession(SSHSession session) {
    try {
      // close() sends only EOF. Destroy releases the PTY even when its foreground
      // process does not read stdin; tmux detaches its client and keeps its server.
      session.channel.destroy();
    } catch (error, stack) {
      session.close();
      unawaited(
        AppDiagnostics.instance.record('terminal.cleanup', error, stack),
      );
    }
  }

  /// 拆掉当前 SSH 会话，但保留 [terminal] 与 [stateListenable]。
  ///
  /// 与 [dispose] 的区别是这里不释放对外暴露的资源，
  /// 因此可以安全地在重连时调用。
  void _disposeSession() {
    _sessionEpoch++;
    _resizeTimer?.cancel();
    _resizeTimer = null;
    _sentSize = null;
    _isSessionOpen = false;
    _stdoutSub?.cancel();
    _stdoutSub = null;
    _stderrSub?.cancel();
    _stderrSub = null;
    final session = _sshSession;
    _sshSession = null;
    if (session != null) _releaseSession(session);
  }
}
