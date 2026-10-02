import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:valhalla/core/providers/terminal_settings_provider.dart';

/// 固定字号的 [TerminalSettingsNotifier] 替身。
///
/// `SharedTerminalCanvas` 会 watch `terminalSettingsProvider`，而真实的
/// notifier build 时要读 `localStorageServiceProvider`——那些只测渲染、
/// 没有注入存储的宿主（mosh 入口、tmux 提示、交互式登录、CLI 聊天等）
/// 会因此抛 `UnimplementedError`。这个替身不碰存储，让纯 UI 宿主可以
/// 直接 pump 画布；需要验证真实持久化路径的用例请继续 override
/// `localStorageServiceProvider`。
class FixedTerminalSettingsNotifier extends TerminalSettingsNotifier {
  final bool initialUseTmux;
  final int initialFontSize;

  FixedTerminalSettingsNotifier({this.initialUseTmux = false, this.initialFontSize = 13});

  @override
  TerminalSettings build() =>
      TerminalSettings(useTmux: initialUseTmux, fontSize: initialFontSize);

  @override
  Future<void> setUseTmux(bool enabled) async {
    state = state.copyWith(useTmux: enabled);
  }

  @override
  Future<void> setFontSize(int value) async {
    state = state.copyWith(
      fontSize: value.clamp(
        TerminalSettingsNotifier.minFontSize,
        TerminalSettingsNotifier.maxFontSize,
      ),
    );
  }
}

/// 一步到位的 provider override，宿主测试直接塞进 `ProviderScope.overrides`。
List<Override> fixedTerminalSettingsOverrides({int fontSize = 13}) => [
  terminalSettingsProvider.overrideWith(
    () => FixedTerminalSettingsNotifier(initialFontSize: fontSize),
  ),
];
