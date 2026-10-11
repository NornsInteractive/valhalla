import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../terminal/terminal_session_bridge.dart';
import '../../core/utils/terminal_keys.dart';
import 'mosh_terminal_bridge.dart';

/// 把 [MoshTerminalBridge] 适配成 [TerminalSessionBridge] 的形状。
///
/// 终端标签页 (TerminalTab) 与视图层只认识 TerminalSessionBridge 这一种
/// 桥；Mosh 桥走适配器后即可复用全部现有会话管道（标签增删、状态监听、
/// 按键栏、剪贴板、快速命令），无需为 Mosh 另开一套标签结构。
///
/// 转发约定：
/// * [state] / [stateListenable] 直通 Mosh 桥，视图层消费方式与 SSH 桥
///   完全一致；
/// * 键盘 / 命令 / 粘贴通过 `terminal.onOutput` 注入 —— Mosh 桥已把
///   `onOutput` 接到会话 `send` 上，未连接时安全地丢弃；
/// * [rebind] 为空操作：Mosh 自带网络漫游，SSH 重连不影响 UDP 会话。
class MoshBridgeAdapter extends TerminalSessionBridge {
  MoshBridgeAdapter({
    required MoshTerminalBridge moshBridge,
    required super.terminal,
    required super.serverName,
    super.serverId,
  }) : _mosh = moshBridge;

  final MoshTerminalBridge _mosh;

  /// 被适配的 Mosh 桥；视图层读取 bootstrap 错误分类时使用。
  MoshTerminalBridge get moshBridge => _mosh;

  @override
  TerminalConnectionState get state => _mosh.state;

  @override
  ValueNotifier<TerminalConnectionState> get stateListenable =>
      _mosh.stateListenable;

  @override
  Future<void> start({int initialWidth = 80, int initialHeight = 24}) =>
      _mosh.start(initialWidth: initialWidth, initialHeight: initialHeight);

  /// Mosh 会话独立于 SSH 存活（漫游重连由协议自己处理），
  /// SSH 断线重连不需要也不应该对它做任何事。
  @override
  Future<void> rebind(SSHClient client) async {}

  /// 通过 `terminal.onOutput` 注入按键序列；Mosh 桥未绑定时为 null，
  /// 输入被安全丢弃（与 SSH 桥未连接时的行为一致）。
  void _sendRaw(String data) {
    final handler = terminal.onOutput;
    if (handler != null) handler(data);
  }

  @override
  void sendKey(String key, {bool isCtrl = false, bool isAlt = false}) {
    HapticFeedback.lightImpact();
    sendTerminalAccessoryKey(terminal, key, isCtrl: isCtrl, isAlt: isAlt);
  }

  @override
  void pasteText(String text) => terminal.paste(text);

  @override
  void sendCommand(String cmd) => _sendRaw('$cmd\n');

  @override
  Future<void> pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      pasteText(text);
    }
  }

  /// Mosh 桥自持生命周期；这里不触碰基类自身的监听器。
  @override
  void dispose() => _mosh.dispose();
}
