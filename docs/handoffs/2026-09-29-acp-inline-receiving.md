# ACP 接收状态移入对话列表（UI handoff）

执行者：仅 `agy` 历史 Valhalla 会话 `ec81a4be-7543-45ee-8658-f68966f57d3b`，模型 `gemini-3.8-flash-high`，effort `high`。测试、格式化、分析、打包和 ADB 由 OpenCode `opencode/mimo-v2.6-flash-free` 执行。

## 目标与触发

用户在 ACP 智能会话发送消息后，等待和接收流式输出时，不希望右上角显示“ACP 流式输出中...”；希望像 CLI 智能会话那样，接收状态显示在对话列表末端。已收到的正文、思考、工具卡和审批卡仍照常显示；停止、完成或失败后立即去除接收提示。

## 设计与现有契约

- 视觉沿用现有 Valhalla 聊天界面的主题色、字号和间距，不引入新色板或新的全局组件。列表末端可复用 CLI 的紧凑进度圈 + 简短占位符；仅一处活动指示，避免双重动画。
- `AiChatState.isGenerating` 是唯一接收状态；`activeSession?.messages` 已包含本次新建的空助手消息，内容流式更新。`_buildMessageList` 当前为 `ListView.builder`，`_buildHeaderBar` 目前含 `if (state.isGenerating)` 的 `PulseDot` 与 `context.l10n.acpStreaming`；CLI 的 `_buildMessagesList` 使用 `itemCount += isSending ? 1 : 0` 并在列表末端绘制进度行。可复用该局部模式，不变更 Provider。
- 无消息或仅新草稿时保留原空态；发送后列表末端显示接收指示。用户上滑看历史时不强制拉到底；接收新内容时现有近底部自动跟随继续适用。完成、取消、认证挑战或错误时不应残留指示。
- 保持流式内容可选择、复制，长列表继续惰性构建；进度指示需有简短语义标签并适配窄屏/深浅主题及 reduced motion。

## 文件边界

- 允许修改：`lib/features/chat/ai_chat_view.dart`。只有确有必要调整文案时，才可修改 `lib/l10n/app_en.arb` 与 `lib/l10n/app_zh.arb`；优先复用已有 `acpStreaming` 键。
- 禁止修改：`lib/core/**`、`lib/data/**`、`lib/infrastructure/**`、`lib/features/chat/cli_chat_view.dart`、所有测试文件、依赖与平台代码。保留现有未提交改动；不可改 Provider 状态语义、消息持久化或发送/停止逻辑。

## 验收与交接

1. 发送中：右上角不再出现“接收中”，对话列表末端有一处清晰、紧凑的接收提示。
2. 流式正文、思考和工具事件到达时，提示和消息不互相遮挡；滚动行为维持原有近底部跟随。
3. 停止、完成、错误、审批或认证挑战后，状态与提示一致，不在旧会话或切换 Agent 后残留。
4. AGY 只报告改动文件和人工检查；不执行测试/打包。由 OpenCode 补/维护 UI 回归测试，执行格式化、`flutter analyze --no-pub`、相关测试、打包及 ADB 验收。

## 本轮结果（2026-09-29）

- AgY 在上述历史会话以 `gemini-3.8-flash-high` / high 修改了 `lib/features/chat/ai_chat_view.dart`，仅删除顶栏接收标记，并给消息列表末尾增加 `isGenerating` 控制的紧凑进度行；保留原有 `acpStreaming` 多语言键、滚动和消息处理逻辑。
- OpenCode 以 `opencode/mimo-v2.6-flash-free` 执行 `dart format lib/features/chat/ai_chat_view.dart`（0 处格式变更）、`flutter analyze --no-pub`（无问题）、`flutter test --no-pub test/features/ai_chat_session_isolation_test.dart test/features/chat_run_settings_test.dart`（12 项通过），以及 `flutter build apk --release --no-pub`（成功）。
- OpenCode 通过 ADB 对 `127.0.0.1:14251` 执行覆盖安装（`Success`）并冷启动 `com.antigravity.valhalla.valhalla/.MainActivity`（`Status: ok`）。
- 原计划补充的接收状态专门 widget 回归测试：OpenCode 的编写请求未产出文件，已停止该请求，不能标记为通过。真实 ACP 服务端流式收发、审批与错误路径仍待有连接的设备人工验收；本轮未向当前 Codex 会话发送测试消息。
