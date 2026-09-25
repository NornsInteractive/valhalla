import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_providers.dart';

/// App 启动时自动连接哪个 SSH 配置。
enum AutoConnectMode {
  /// 用户指定的固定配置。
  fixed,

  /// 最近一次成功连接过的配置。
  lastConnected,
}

/// 自动连接设置。
///
/// [fixedServerId] 只在 [AutoConnectMode.fixed] 下有意义；切回
/// [AutoConnectMode.lastConnected] 时不清空它，这样用户来回切换开关不会
/// 丢掉之前选好的服务器。
class AutoConnectSettings {
  final AutoConnectMode mode;

  /// 「固定默认 SSH」指定的配置 id；null 表示尚未指定。
  final String? fixedServerId;

  const AutoConnectSettings({
    this.mode = AutoConnectMode.lastConnected,
    this.fixedServerId,
  });

  AutoConnectSettings copyWith({AutoConnectMode? mode, String? fixedServerId}) {
    return AutoConnectSettings(
      mode: mode ?? this.mode,
      fixedServerId: fixedServerId ?? this.fixedServerId,
    );
  }
}

/// 存储里 `mode` 字段的合法字面量。
///
/// 用 [AutoConnectMode.name] 做映射，避免手写字符串与枚举名漂移。
String _modeToStorage(AutoConnectMode mode) => mode.name;

/// 把存储里的字符串解析回枚举。
///
/// 未知值（历史遗留、手改、未来版本写下的新模式）一律回落到
/// [AutoConnectMode.lastConnected]：这是默认值，也是两个选项里「更不容易
/// 意外连到错误服务器」的那个——固定模式指向的 id 可能已被删除。
AutoConnectMode _modeFromStorage(String raw) {
  for (final mode in AutoConnectMode.values) {
    if (mode.name == raw) return mode;
  }
  return AutoConnectMode.lastConnected;
}

class AutoConnectSettingsNotifier extends Notifier<AutoConnectSettings> {
  @override
  AutoConnectSettings build() {
    final storage = ref.watch(localStorageServiceProvider);
    return AutoConnectSettings(
      mode: _modeFromStorage(storage.getAutoConnectMode()),
      fixedServerId: storage.getAutoConnectServerId(),
    );
  }

  Future<void> setMode(AutoConnectMode mode) async {
    // 先改内存再落盘：开关必须立刻响应，写盘失败不该把 UI 卡在旧值上。
    state = state.copyWith(mode: mode);
    await ref
        .read(localStorageServiceProvider)
        .setAutoConnectMode(_modeToStorage(mode));
  }

  /// 指定（或传 null 取消）固定连接的服务器。
  Future<void> setFixedServerId(String? id) async {
    state = AutoConnectSettings(mode: state.mode, fixedServerId: id);
    await ref.read(localStorageServiceProvider).setAutoConnectServerId(id);
  }
}

/// 注意：消费方读取本值时应当用 `ref.read` 而不是 `ref.watch`。
///
/// 启动钩子在 initState 里只跑一次，没有重建需求；而设置页只需要能读能写。
/// 一旦让某处 `ref.watch` 它，写设置就会连同 watch 者一起重建。
final autoConnectSettingsProvider =
    NotifierProvider<AutoConnectSettingsNotifier, AutoConnectSettings>(
      AutoConnectSettingsNotifier.new,
    );
