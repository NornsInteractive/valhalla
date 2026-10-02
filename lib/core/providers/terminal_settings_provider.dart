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

  /// 终端字体大小（9..24）。默认 13，与 xterm 的默认字号一致。
  final int fontSize;

  const TerminalSettings({this.useTmux = false, this.fontSize = 13});

  TerminalSettings copyWith({bool? useTmux, int? fontSize}) {
    return TerminalSettings(
      useTmux: useTmux ?? this.useTmux,
      fontSize: fontSize ?? this.fontSize,
    );
  }
}

class TerminalSettingsNotifier extends Notifier<TerminalSettings> {
  /// 字号合法区间，与 [LocalStorageService.getTerminalFontSize] 的校验一致。
  static const int minFontSize = 9;
  static const int maxFontSize = 24;

  @override
  TerminalSettings build() {
    final storage = ref.watch(localStorageServiceProvider);
    return TerminalSettings(
      useTmux: storage.getUseTmuxForTerminal(),
      fontSize: storage.getTerminalFontSize(),
    );
  }

  Future<void> setUseTmux(bool enabled) async {
    // 先改内存再落盘：开关必须立刻响应，写盘失败不该把 UI 卡在旧值上。
    state = state.copyWith(useTmux: enabled);
    await ref.read(localStorageServiceProvider).setUseTmuxForTerminal(enabled);
  }

  /// 设置终端字体大小。越界值夹回 [minFontSize, maxFontSize] 再生效，
  /// 内存与落盘用的是同一个夹紧后的值，两边不会漂移。
  Future<void> setFontSize(int value) async {
    final clamped = value.clamp(minFontSize, maxFontSize);
    // 先改内存再落盘：与 setUseTmux 同理，写盘失败不卡 UI。
    state = state.copyWith(fontSize: clamped);
    await ref.read(localStorageServiceProvider).setTerminalFontSize(clamped);
  }
}

/// 注意：消费方读取本值时应当用 `ref.read` 而不是 `ref.watch`。
///
/// 终端 provider 一旦 watch 它，切换开关就会重建 notifier，把所有标签页
/// 连同回滚缓冲一起丢掉。开关只对之后新建的标签页生效。
///
/// 例外：`SharedTerminalCanvas` watch [TerminalSettings.fontSize] 是安全且
/// 有意的——它只是渲染末端的叶子节点，rebuild 只影响 TerminalView 的样式，
/// 不会重建 Terminal 本体；改字号反而需要它实时生效（PTY 尺寸经既有
/// onResize 链路自动同步）。
final terminalSettingsProvider =
    NotifierProvider<TerminalSettingsNotifier, TerminalSettings>(
      TerminalSettingsNotifier.new,
    );
