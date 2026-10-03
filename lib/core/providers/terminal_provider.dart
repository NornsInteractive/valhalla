import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../security/agent_command_validator.dart';
import '../services/app_diagnostics.dart';
import '../../infrastructure/mosh/mosh_bridge_adapter.dart';
import '../../infrastructure/mosh/mosh_providers.dart';
import '../../infrastructure/mosh/mosh_session_service.dart';
import '../../infrastructure/mosh/mosh_terminal_bridge.dart';
import '../../infrastructure/terminal/terminal_session_bridge.dart';
import 'server_provider.dart';
import 'storage_providers.dart';
import 'terminal_settings_provider.dart';

/// 远端缺 tmux 时给 UI 的安装询问契约。不含任何展示文案。
class TmuxInstallOffer {
  /// 将要执行的安装命令；无法识别包管理器时为 null。
  final String? installCommand;
  final bool isInstalling;

  /// 稳定错误码，由 UI 映射 ARB。例如 `TMUX_INSTALL_UNSUPPORTED`、
  /// `TMUX_INSTALL_FAILED`、`SSH_DISCONNECTED`。
  final String? errorCode;

  const TmuxInstallOffer({
    this.installCommand,
    this.isInstalling = false,
    this.errorCode,
  });

  TmuxInstallOffer copyWith({
    String? installCommand,
    bool? isInstalling,
    String? errorCode,
    bool clearError = false,
  }) {
    return TmuxInstallOffer(
      installCommand: installCommand ?? this.installCommand,
      isInstalling: isInstalling ?? this.isInstalling,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}

class TerminalTab {
  final String id;
  final String title;
  final Terminal terminal;
  final TerminalSessionBridge bridge;

  TerminalTab({
    required this.id,
    required this.title,
    required this.terminal,
    required this.bridge,
  });
}

class SshTerminalState {
  int get activeConnectionCount => tabs
      .where((tab) => tab.bridge.state == TerminalConnectionState.connected)
      .length;
  final List<TerminalTab> tabs;
  final int activeTabIndex;
  final bool isCtrlActive;
  final bool isAltActive;
  final TmuxInstallOffer? tmuxInstallOffer;

  /// 当前激活的服务器是否开启了 Mosh (true 时新建会话入口出现 Mosh 选项)。
  final bool moshAvailable;

  SshTerminalState({
    required this.tabs,
    this.activeTabIndex = 0,
    this.isCtrlActive = false,
    this.isAltActive = false,
    this.tmuxInstallOffer,
    this.moshAvailable = false,
  });

  TerminalTab? get activeTab =>
      tabs.isNotEmpty && activeTabIndex >= 0 && activeTabIndex < tabs.length
      ? tabs[activeTabIndex]
      : null;

  SshTerminalState copyWith({
    List<TerminalTab>? tabs,
    int? activeTabIndex,
    bool? isCtrlActive,
    bool? isAltActive,
    TmuxInstallOffer? tmuxInstallOffer,
    bool clearTmuxInstallOffer = false,
    bool? moshAvailable,
  }) {
    return SshTerminalState(
      tabs: tabs ?? this.tabs,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      isCtrlActive: isCtrlActive ?? this.isCtrlActive,
      isAltActive: isAltActive ?? this.isAltActive,
      tmuxInstallOffer: clearTmuxInstallOffer
          ? null
          : (tmuxInstallOffer ?? this.tmuxInstallOffer),
      moshAvailable: moshAvailable ?? this.moshAvailable,
    );
  }
}

class TerminalNotifier extends Notifier<SshTerminalState> {
  @override
  SshTerminalState build() {
    ref.watch(activeServerProvider.select((server) => server?.connectionKey));
    final activeServer = ref.read(activeServerProvider);
    final sshManager = ref.watch(sshClientManagerProvider);
    final connState = ref.read(serverConnectionProvider);
    final serverName = activeServer?.name ?? 'No Server';
    final sshClient = (activeServer != null && connState.isConnected)
        ? sshManager.getClient(activeServer.id)
        : null;

    ref.listen(serverConnectionProvider, (prev, next) {
      if (next.isConnected && prev?.isConnected != true) {
        unawaited(rebindAfterReconnect());
      }
    });

    final initialTab = _createTab(
      'main [bash]',
      serverName: serverName,
      serverId: activeServer?.id ?? '',
      terminalId: '0',
      sshClient: sshClient,
      preferTmux: ref.read(terminalSettingsProvider).useTmux,
    );
    unawaited(
      initialTab.bridge.start().then((_) {
        if (ref.mounted) _syncTmuxOffer();
      }),
    );

    return SshTerminalState(
      tabs: [initialTab],
      activeTabIndex: 0,
      moshAvailable: activeServer?.moshEnabled ?? false,
    );
  }

  void _syncTmuxOffer() {
    final bridge = state.activeTab?.bridge;
    if (bridge != null && bridge.awaitingTmuxDecision) {
      state = state.copyWith(
        tmuxInstallOffer: TmuxInstallOffer(
          installCommand: bridge.proposedInstallCommand,
        ),
      );
    } else {
      state = state.copyWith(clearTmuxInstallOffer: true);
    }
  }

  /// 用户拒绝安装：当前标签页走普通 SSH PTY。
  Future<void> skipTmuxInstall() async {
    final tab = state.activeTab;
    if (tab == null) return;
    await tab.bridge.proceedWithoutTmux();
    _syncTmuxOffer();
  }

  /// 用户确认安装。命令来自 [TmuxInstallOffer.installCommand]。
  ///
  /// 不在这里弹出 UI。失败只写稳定 [TmuxInstallOffer.errorCode]。
  Future<void> confirmTmuxInstall() async {
    final offer = state.tmuxInstallOffer;
    final tab = state.activeTab;
    final server = ref.read(activeServerProvider);
    if (offer == null || tab == null) return;

    final command = offer.installCommand;
    if (command == null || command.trim().isEmpty) {
      state = state.copyWith(
        tmuxInstallOffer: offer.copyWith(errorCode: 'TMUX_INSTALL_UNSUPPORTED'),
      );
      return;
    }

    if (server == null || !ref.read(serverConnectionProvider).isConnected) {
      state = state.copyWith(
        tmuxInstallOffer: offer.copyWith(errorCode: 'SSH_DISCONNECTED'),
      );
      return;
    }

    try {
      AgentCommandValidator.validate(command);
    } catch (_) {
      state = state.copyWith(
        tmuxInstallOffer: offer.copyWith(errorCode: 'TMUX_INSTALL_UNSUPPORTED'),
      );
      return;
    }

    state = state.copyWith(
      tmuxInstallOffer: offer.copyWith(isInstalling: true, clearError: true),
    );

    final result = await ref
        .read(sshClientManagerProvider)
        .executeWithLoginShell(
          server.id,
          command,
          timeout: const Duration(minutes: 5),
        );

    if (!result.isSuccess) {
      state = state.copyWith(
        tmuxInstallOffer: offer.copyWith(
          isInstalling: false,
          errorCode: 'TMUX_INSTALL_FAILED',
        ),
      );
      return;
    }

    await tab.bridge.retryAfterTmuxInstall();
    _syncTmuxOffer();
  }

  TerminalTab _createTab(
    String title, {
    required String serverName,
    required String serverId,
    required String terminalId,
    dynamic sshClient,
    required bool preferTmux,
  }) {
    final terminal = Terminal(maxLines: 1500);
    final bridge = TerminalSessionBridge(
      terminal: terminal,
      sshClient: sshClient,
      serverName: serverName,
      // serverId + terminalId 决定 tmux 会话名。不传的话所有标签页
      // 都会落到同一个会话上，第二个标签页会直接接管第一个的会话。
      serverId: serverId,
      terminalId: terminalId,
      preferTmux: preferTmux,
    );

    return TerminalTab(
      id: 'tab-${DateTime.now().millisecondsSinceEpoch}-${title.hashCode}',
      title: title,
      terminal: terminal,
      bridge: bridge,
    );
  }

  void selectTab(int index) {
    if (index >= 0 && index < state.tabs.length) {
      state = state.copyWith(activeTabIndex: index);
    }
  }

  void addNewTab([String? customTitle]) {
    final activeServer = ref.read(activeServerProvider);
    final sshManager = ref.read(sshClientManagerProvider);
    final serverName = activeServer?.name ?? 'localhost';
    final sshClient = activeServer != null
        ? sshManager.getClient(activeServer.id)
        : null;

    final index = state.tabs.length + 1;
    final title = customTitle ?? 'bash #$index';
    final tab = _createTab(
      title,
      serverName: serverName,
      serverId: activeServer?.id ?? '',
      // 用「第几个标签页」而不是标题做 id：标题可以被用户改成一样，
      // 那样两个标签页会共用一个 tmux 会话。
      terminalId: '$index',
      sshClient: sshClient,
      // 开关只对之后新建的标签页生效；已在运行的标签页保持原有模式，
      // 重建会清掉它们的回滚缓冲，还可能掐断远端的前台进程。
      preferTmux: ref.read(terminalSettingsProvider).useTmux,
    );
    unawaited(
      tab.bridge.start().then((_) {
        if (ref.mounted) _syncTmuxOffer();
      }),
    );

    state = state.copyWith(
      tabs: [...state.tabs, tab],
      activeTabIndex: state.tabs.length,
    );
  }

  /// 新建一个 Mosh 会话标签页。
  ///
  /// [sessionTag] 来自 l10n (`moshSessionTag`)，用作标签标题后缀以区分
  /// SSH 标签页。bootstrap 参数取当前激活服务器的 Mosh 配置；缺省字段
  /// 落到 MoshBootstrapRequest 的内置默认 (`mosh-server` / `60000:61000`)。
  void addMoshTab([String? sessionTag]) {
    final activeServer = ref.read(activeServerProvider);
    final index = state.tabs.length + 1;
    final tag = sessionTag ?? 'mosh';
    final serverName = activeServer?.name ?? 'localhost';
    final terminal = Terminal(maxLines: 1500);
    final moshBridge = MoshTerminalBridge(
      terminal: terminal,
      sessionService: ref.read(moshSessionServiceProvider),
      request: MoshBootstrapRequest(
        serverId: activeServer?.id ?? '',
        host: activeServer?.host ?? '',
        serverPath: activeServer?.moshServerPath ?? 'mosh-server',
        portRange: activeServer?.moshPortRange ?? '60000:61000',
      ),
      serverName: serverName,
    );
    final bridge = MoshBridgeAdapter(
      moshBridge: moshBridge,
      terminal: terminal,
      serverName: serverName,
      serverId: activeServer?.id ?? '',
    );
    final tab = TerminalTab(
      id: 'tab-${DateTime.now().millisecondsSinceEpoch}-mosh-$index',
      title: 'bash #$index ($tag)',
      terminal: terminal,
      bridge: bridge,
    );

    unawaited(
      tab.bridge.start().then((_) {
        if (ref.mounted) _syncTmuxOffer();
      }),
    );

    state = state.copyWith(
      tabs: [...state.tabs, tab],
      activeTabIndex: state.tabs.length,
    );
  }

  void closeTab(int index) {
    if (state.tabs.length <= 1) return; // 保留至少一个 Tab
    final tabToClose = state.tabs[index];
    tabToClose.bridge.dispose();

    final newTabs = state.tabs.where((t) => t.id != tabToClose.id).toList();
    final newActive = state.activeTabIndex >= newTabs.length
        ? newTabs.length - 1
        : state.activeTabIndex;

    state = state.copyWith(tabs: newTabs, activeTabIndex: newActive);
  }

  void toggleCtrl() {
    HapticFeedback.mediumImpact();
    state = state.copyWith(isCtrlActive: !state.isCtrlActive);
  }

  void toggleAlt() {
    HapticFeedback.mediumImpact();
    state = state.copyWith(isAltActive: !state.isAltActive);
  }

  void sendKey(String key, {bool isCtrl = false, bool isAlt = false}) {
    final activeTab = state.activeTab;
    if (activeTab != null) {
      activeTab.bridge.sendKey(
        key,
        isCtrl: isCtrl || state.isCtrlActive,
        isAlt: isAlt || state.isAltActive,
      );
      if (state.isCtrlActive || state.isAltActive) {
        state = state.copyWith(isCtrlActive: false, isAltActive: false);
      }
    }
  }

  void sendCommand(String cmd) {
    final activeTab = state.activeTab;
    if (activeTab != null) {
      activeTab.bridge.sendCommand(cmd);
    }
  }

  Future<void> pasteClipboard() async {
    final activeTab = state.activeTab;
    if (activeTab != null) {
      await activeTab.bridge.pasteClipboard();
    }
  }

  /// 重连成功后把每个标签页重新挂到新的 SSH 客户端上。
  ///
  /// 不重新挂的话，标签页会一直握着那个已经死掉的 `SSHClient`：
  /// 界面看起来是活的，实际敲什么都不会有反应。这是断线重连最典型的
  /// 「幽灵终端」现象。
  ///
  /// 用 tmux 承载的会话会自动 attach 回原来的 tmux session，
  /// 所以这里不需要（也不应该）重建 [Terminal] 实例 —— 重建会把
  /// 回滚缓冲全部丢掉，用户就看不到断线前的输出了。
  Future<void> rebindAfterReconnect() async {
    final activeServer = ref.read(activeServerProvider);
    if (activeServer == null) return;

    final sshManager = ref.read(sshClientManagerProvider);
    final sshClient = sshManager.getClient(activeServer.id);
    if (sshClient == null) return;

    await rebindTabsAfterReconnect(state.tabs, sshClient);

    // 重连会重新走一遍 tmux 决策，awaitingTmuxDecision 可能从 false 变 true
    // （或反之）。不同步的话弹窗会滞留或该出现时不出现。
    _syncTmuxOffer();
  }
}

/// 把 [tabs] 逐个重新挂到 [sshClient] 上。
///
/// 单个标签页 rebind 抛异常绝不能拖垮其余标签页（否则第一个坏标签页会让
/// 后面所有标签页都握着死连接）：记录诊断、往该标签页终端写一行诊断信息，
/// 然后继续处理剩下的。遍历用快照，重连期间用户新建/关闭标签页也不会
/// 触发 ConcurrentModificationError。
Future<void> rebindTabsAfterReconnect(
  Iterable<TerminalTab> tabs,
  SSHClient sshClient,
) async {
  for (final tab in List.of(tabs)) {
    try {
      await tab.bridge.rebind(sshClient);
    } catch (error, stack) {
      unawaited(
        AppDiagnostics.instance.record('terminal.rebind', error, stack),
      );
      tab.terminal.write(
        '\r\n\x1b[31m[Reconnect failed for this tab: $error]\x1b[0m\r\n',
      );
    }
  }
}

final terminalProvider = NotifierProvider<TerminalNotifier, SshTerminalState>(
  () {
    return TerminalNotifier();
  },
);
