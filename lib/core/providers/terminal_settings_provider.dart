import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_providers.dart';

enum TerminalDirectionPadMode { fixed, flow, hidden }

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

  static const defaultPinnedKeys = [
    'ESC',
    'TAB',
    'CTRL',
    'SHIFT',
    'ALT',
    'PASTE',
    'ARROWS',
  ];
  static const availableKeys = [
    ...defaultPinnedKeys,
    'FN',
    'Ctrl+C',
    '↑',
    '↓',
    '←',
    '→',
    'HOME',
    'END',
    'PGUP',
    'PGDN',
    'INSERT',
    'DELETE',
    'BACKSPACE',
    'ENTER',
    'Ctrl+A',
    'Ctrl+E',
    'Ctrl+U',
    'Ctrl+K',
    'Ctrl+W',
    'Ctrl+R',
    'Ctrl+D',
    'Ctrl+Z',
    '/',
    '-',
    '_',
    '|',
    '~',
    '.',
    ':',
    '=',
    'F1',
    'F2',
    'F3',
    'F4',
    'F5',
    'F6',
    'F7',
    'F8',
    'F9',
    'F10',
    'F11',
    'F12',
  ];
  final List<String> pinnedKeys;
  final TerminalDirectionPadMode? _directionPadMode;
  final int? directionKeySeedColorValue;

  TerminalDirectionPadMode get directionPadMode =>
      _directionPadMode ??
      (pinnedKeys.contains('ARROWS')
          ? TerminalDirectionPadMode.fixed
          : TerminalDirectionPadMode.hidden);

  const TerminalSettings({
    this.useTmux = false,
    this.fontSize = 13,
    this.pinnedKeys = defaultPinnedKeys,
    TerminalDirectionPadMode? directionPadMode,
    this.directionKeySeedColorValue,
  }) : _directionPadMode = directionPadMode;

  TerminalSettings copyWith({
    bool? useTmux,
    int? fontSize,
    List<String>? pinnedKeys,
    TerminalDirectionPadMode? directionPadMode,
    int? directionKeySeedColorValue,
    bool clearDirectionKeySeedColor = false,
  }) {
    return TerminalSettings(
      useTmux: useTmux ?? this.useTmux,
      fontSize: fontSize ?? this.fontSize,
      pinnedKeys: pinnedKeys ?? this.pinnedKeys,
      directionPadMode: directionPadMode ?? _directionPadMode,
      directionKeySeedColorValue: clearDirectionKeySeedColor
          ? null
          : directionKeySeedColorValue ?? this.directionKeySeedColorValue,
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
      pinnedKeys: List.unmodifiable(
        (storage.getTerminalPinnedKeys() ?? TerminalSettings.defaultPinnedKeys)
            .where(TerminalSettings.availableKeys.contains)
            .toSet(),
      ),
      directionPadMode: TerminalDirectionPadMode.values
          .where((mode) => mode.name == storage.getTerminalDirectionPadMode())
          .firstOrNull,
      directionKeySeedColorValue: storage
          .getTerminalDirectionKeySeedColorValue(),
    );
  }

  Future<void> setPinnedKeys(List<String> keys) async {
    final valid = keys
        .where(TerminalSettings.availableKeys.contains)
        .toSet()
        .toList();
    await ref.read(localStorageServiceProvider).setTerminalPinnedKeys(valid);
    if (ref.mounted) {
      final storage = ref.read(localStorageServiceProvider);
      state = state.copyWith(
        pinnedKeys: List.unmodifiable(valid),
        directionPadMode:
            TerminalDirectionPadMode.values
                .where(
                  (mode) => mode.name == storage.getTerminalDirectionPadMode(),
                )
                .firstOrNull ??
            (valid.contains('ARROWS')
                ? TerminalDirectionPadMode.fixed
                : TerminalDirectionPadMode.hidden),
      );
    }
  }

  /// Save the complete dialog in one record; failures must not partially apply.
  Future<void> setAccessorySettings({
    required List<String> pinnedKeys,
    required TerminalDirectionPadMode directionPadMode,
    required int? directionKeySeedColorValue,
  }) async {
    final valid = pinnedKeys
        .where(TerminalSettings.availableKeys.contains)
        .toSet()
        .toList();
    await ref
        .read(localStorageServiceProvider)
        .setTerminalAccessorySettings(
          pinnedKeys: valid,
          directionPadMode: directionPadMode.name,
          directionKeySeedColorValue: directionKeySeedColorValue,
        );
    if (ref.mounted) {
      state = state.copyWith(
        pinnedKeys: List.unmodifiable(valid),
        directionPadMode: directionPadMode,
        directionKeySeedColorValue: directionKeySeedColorValue,
        clearDirectionKeySeedColor: directionKeySeedColorValue == null,
      );
    }
  }

  Future<void> resetPinnedKeys() =>
      setPinnedKeys(TerminalSettings.defaultPinnedKeys);

  Future<void> setUseTmux(bool enabled) async {
    await ref.read(localStorageServiceProvider).setUseTmuxForTerminal(enabled);
    if (ref.mounted) state = state.copyWith(useTmux: enabled);
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
