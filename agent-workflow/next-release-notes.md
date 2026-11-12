# Valhalla 1.0.41+42

## SSH 终端 tmux / agy 上下滑动与滚轮翻页修复
- **协议按键编码纠正**：修复 `xterm` 核心鼠标协议层中 `TerminalMouseButton` 将滚轮按键错误编码为 `68/69`（叠加了 Shift 修饰键），导致事件被 tmux 源码机制丢弃的问题。纠正为符合 XTerm / SGR 协议标准的 `64`（Wheel Up）与 `65`（Wheel Down）。
- **tmux copy-mode 顺畅联动**：在运行 `tmux` 以及在 tmux 内部运行 `agy` 等长输出命令行工具时，手指在触控屏上上下拖拽或使用滚轮即可自动进入 tmux copy-mode，顺畅翻阅上方思考与历史输出，滑至底部自动恢复交互。
- **普通鼠标模式坐标修复**：修复普通模式鼠标上报时行号多加 1 的 off-by-one 偏差，精确对齐点击与滚轮行。
- **触控阻尼与动态状态跟踪**：将触控滑动阻尼校准为舒适区间（`effectiveLineHeight * 1.6`），避免单次拖拽过度翻卷；完善 `terminal.mouseMode` 监听，确保远程会话激活鼠标跟踪时手势引擎实时同步。

## 构建与测试
- 静态分析 `flutter analyze` 零告警通过。
- 全量终端回归套件 235 个测试全部通过。
