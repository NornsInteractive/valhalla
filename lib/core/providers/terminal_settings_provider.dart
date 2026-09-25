import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_providers.dart';

/// 终端相关的用户设置，独立于 [SettingsNotifier]。
///
/// 单独成家而不是塞进 `settings_provider.dart`：那边的 `SettingsState`
/// 是纯内存的（主题/强调色/语言都不落盘），而 tmux 开关必须持久化。
/// 混在一起会让同一个 state 里出现两种语义。
class TerminalSettings {
  /// 是否用 tmux 承载终端会话。false = 普通 SSH PTY。
  final bool useTmux;

  const TerminalSettings({this.useTmux = false});

  TerminalSettings copyWith({bool? useTmux}) {
    return TerminalSettings(useTmux: useTmux ?? this.useTmux);
  }
}

class TerminalSettingsNotifier extends Notifier<TerminalSettings> {
  @override
  TerminalSettings build() {
    final storage = ref.watch(localStorageServiceProvider);
    return TerminalSettings(useTmux: storage.getUseTmuxForTerminal());
  }

  Future<void> setUseTmux(bool enabled) async {
    // 先改内存再落盘：开关必须立刻响应，写盘失败不该把 UI 卡在旧值上。
    state = state.copyWith(useTmux: enabled);
    await ref.read(localStorageServiceProvider).setUseTmuxForTerminal(enabled);
  }
}

/// 注意：消费方读取本值时应当用 `ref.read` 而不是 `ref.watch`。
///
/// 终端 provider 一旦 watch 它，切换开关就会重建 notifier，把所有标签页
/// 连同回滚缓冲一起丢掉。开关只对之后新建的标签页生效。
final terminalSettingsProvider =
    NotifierProvider<TerminalSettingsNotifier, TerminalSettings>(
      TerminalSettingsNotifier.new,
    );
