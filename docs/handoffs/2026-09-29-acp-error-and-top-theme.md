# ACP 重复报错与顶部主题快捷入口（UI handoff）

执行者：仅 AgY 历史 Valhalla 会话 `ec81a4be-7543-45ee-8658-f68966f57d3b`，模型 `gemini-3.8-flash-high`，effort `high`。测试、格式化、分析、打包、ADB 均交给 OpenCode `opencode/mimo-v2.6-flash-free`。

## 用户场景与原因

1. ACP 发送失败：`AiChatNotifier.sendMessage` 收到 `ACPErrorEvent` 时，先在助手消息正文末尾追加 `\n\n**Error:** ${event.error}`，又设置 `lastErrorCode: event.error`。`AiChatView` 无条件将 `lastErrorCode` 绘制为消息列表上方的红色 `_buildErrorBanner`，所以同一错误显示两次。连接失败、Agent 未就绪和发送前预检错误可能只在 `lastErrorCode` 中，仍需保留顶部提示。
2. 顶部主题快捷入口：`MainShell` 的手机与宽屏两套顶栏各有一个 `Icons.palette_outlined` 按钮，均调用 `_showThemeQuickSwitch`。用户要求暂时去掉顶部按钮；设置页主题/强调色功能必须保留。
3. 模型清单不是这次 UI 修改目标：CLI Codex 来自 `CodexNativeClient.capabilities()` 的 app-server `model/list`；ACP 来自远端 `codex-acp` 的 session config options。列表不同不意味着 UI 有静态旧数据。本轮不在 UI 注入 CLI 模型到 ACP，也不自动更新远端包。

## 设计与行为

- ACP 顶部错误横幅只在“当前最后一条助手消息已经包含**与 `lastErrorCode` 完全相同的内联错误**”时隐藏。不要对所有 ACP 错误一概隐藏；保持 `lastErrorCode` 本身不变，以免影响输入恢复与其他状态逻辑。内联错误、权限卡、认证卡及正常内容继续原样显示。新消息、切换 Agent/会话时不能靠旧内联错误错误地抑制新横幅。
- 手机与宽屏顶栏移除主题快捷按钮与它专属的间距。删除不再可达的 `_showThemeQuickSwitch` 私有方法及只供该方法使用的 import，避免 dead code；保留设置页入口和持久化主题配置。此处只做减法，沿用现有 Valhalla 排版，不新增组件/颜色/动效。
- 窄屏不溢出，空态无顶部错误时维持原样，按钮移除后其他顶栏操作仍可聚焦和点击；错误横幅的可读性和语义不变。

## 文件边界

- AgY 仅可改：`lib/features/chat/ai_chat_view.dart`、`lib/features/shell/main_shell.dart`。无需改 ARB。
- 禁止改：`lib/core/**`、`lib/data/**`、`lib/infrastructure/**`、`lib/app/**`、`lib/l10n/**`、其他 feature、所有测试、依赖、平台代码与已有未提交业务改动。
- 受影响测试 `test/features/main_shell_top_layout_test.dart`、`test/features/adaptive_dialogs_and_sheets_test.dart` 由 OpenCode 维护，并给 ACP 横幅抑制补一个最小 widget 回归检查；AgY 不执行测试/打包。

## 验收

1. 与最后助手消息内联错误相同的 `lastErrorCode` 不再重复出现在顶部；仅顶部有错误的预检/连接失败仍显示红色横幅。
2. 手机和宽屏顶部均无主题快捷按钮，设置页仍可配置主题。
3. 模型差异须按远端实际 `codex-acp` 版本、其 bundled Codex 与独立 `codex` 版本进一步核对；不能把未核对的远端问题宣称已修复。

## 本轮执行结果（2026-09-29）

- AgY 指定历史会话（Gemini 3.8 Flash / high）仅修改 `ai_chat_view.dart` 和 `main_shell.dart`：对最后助手消息的精确内联错误后缀抑制重复横幅，删除手机与宽屏顶栏主题按钮及不可达的私有快捷面板；设置页未修改。
- OpenCode 指定 MiMo-V2.6 free：`dart format` 两个 UI 文件（0 处变更）、`flutter analyze --no-pub`（无问题）、`flutter test --no-pub test/features/settings_theme_accent_color_test.dart test/features/ai_chat_session_isolation_test.dart`（13 项通过）。
- OpenCode 运行受影响的旧测试组合（`main_shell_top_layout_test.dart`、`adaptive_dialogs_and_sheets_test.dart`、`ai_chat_session_isolation_test.dart`）：24 项通过、6 项失败。失败均因旧测试仍要求顶部主题快捷按钮/面板存在，与新需求冲突。OpenCode MiMo 连续三次在读取测试文件后无响应，没有产出测试更新；因此本轮不能宣称测试门禁全部通过，也尚无新增的 ACP 内联错误专门回归测试。已向用户询问是否允许主 Agent 仅代改这些测试，仍待回复。
- OpenCode 已执行 `flutter build apk --release --no-pub`（成功），在 ADB 设备 `127.0.0.1:14251` 上 `adb install -r`（Success）与 `am start -W`（Status: ok，冷启动）。这不是远端 ACP 对话验收。
- 模型差异的已证实代码路径：CLI Codex 用 app-server `model/list`，ACP 只从远端 `session/new/load/resume` 的 config options 读取；官方 `codex-acp` 会随包携带兼容的 Codex CLI，亦允许通过 `CODEX_PATH` 指向另一个二进制。用户确认 ACP 运行在服务器宿主机，但尚未提供该宿主机相同用户环境的 `codex --version`、`codex-acp --version` 和实际选项，因此旧清单的具体远端成因未确认。不在 UI 拼接两个模型清单或自动升级远端组件。

## 2026-09-30 后续测试维护

OpenCode 指定模型已成功完成此前受阻的主题入口旧测试更新：`main_shell_top_layout_test.dart` 将 4 个不可达面板测试改为 3 个手机/中屏/宽屏无顶部主题快捷按钮断言（其余导航测试保留，15 项通过）；`adaptive_dialogs_and_sheets_test.dart` 更新两项窄/宽屏快捷入口断言（8 项通过）。未跳过测试或恢复用户要求删除的 UI。全量回归另发现 600px 顶栏实际溢出，AgY 已修补；最终门禁与 APK 安装结果见 [容器绑定修复交接](2026-09-30-agent-container-binding.md)。本记录不代表 ACP 远端模型问题已解决。
