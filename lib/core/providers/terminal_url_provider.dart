import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../utils/terminal_url_extractor.dart';

/// 终端缓冲中当前可复制的链接快照。
class TerminalUrlState {
  /// 按出现顺序排列的候选链接。
  final List<ExtractedUrl> candidates;

  const TerminalUrlState({this.candidates = const []});

  /// 最适合提供给用户复制的一条：最后出现的那个。
  ///
  /// 登录流程里最新的链接才有效（旧链接可能已失效）。
  ExtractedUrl? get best => candidates.isEmpty ? null : candidates.last;

  bool get isEmpty => candidates.isEmpty;
  bool get isNotEmpty => candidates.isNotEmpty;
}

/// 监听一个 [Terminal] 的缓冲内容，提取其中的 http(s) 链接。
///
/// xterm 的终端视图没有可用的选中复制能力，所以链接复制改为"自动识别 +
/// 一键复制"：这里负责持续产出最新候选，UI 只负责展示与调用剪贴板。
///
/// 说明：
/// - [Terminal] 用的是 xterm 自己的 `Observable` mixin（普通函数监听器，**不是**
///   Flutter 的 `ChangeNotifier`），所以必须 `addListener` / `removeListener` 配对。
/// - `Terminal.write()` 每次写入都会通知，因此链接出现时能实时感知。
/// - 加了一层防抖：链接可能分多次 write 到达（分片），频繁重算也没必要。
/// - 状态是**同步有值**的，不暴露 loading：初值在任何 build 之前就已产出，
///   因此 UI 不必处理 loading 分支，也不会出现"没人监听就永远挂起"的问题。
final terminalUrlProvider =
    NotifierProvider.family<TerminalUrlNotifier, TerminalUrlState, Terminal>(
      TerminalUrlNotifier.new,
    );

class TerminalUrlNotifier extends Notifier<TerminalUrlState> {
  TerminalUrlNotifier(this.terminal);

  /// 被监听的终端。由 family 工厂注入。
  final Terminal terminal;

  Timer? _debounce;

  @override
  TerminalUrlState build() {
    void onChanged() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), _refresh);
    }

    terminal.addListener(onChanged);
    ref.onDispose(() {
      _debounce?.cancel();
      terminal.removeListener(onChanged);
    });

    // 同步产出初值：不依赖任何异步投递，UI 首帧就有值。
    return _extractState();
  }

  void _refresh() {
    if (!ref.mounted) return;
    state = _extractState();
  }

  TerminalUrlState _extractState() => TerminalUrlState(
    candidates: TerminalUrlExtractor.extract(terminal.buffer.getText()),
  );
}
