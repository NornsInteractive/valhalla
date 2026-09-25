# 智能会话：身份、恢复与取消交接

## 已落地的后端契约

- 会话持久化 `serverId`、`agentId`、`workingDirectory`、`remoteSessionId`。旧 JSON 无服务器绑定时保留 `null`，禁止自动猜测。
- 发送必须匹配当前服务器与 Agent；分别返回 `CHAT_SERVER_BINDING_REQUIRED` / `CHAT_SESSION_IDENTITY_MISMATCH`。
- `bindActiveSessionToCurrentServer()` 只绑定未绑定会话。UI 必须先显示服务器名称并要求确认。
- `stopGeneration()` 取消权限与认证等待、停止 ACP、保存已接收内容。请求 epoch 屏蔽迟到事件；断线也调用同一收尾路径。
- Adapter 按服务器、Agent、本地会话隔离；远端会话 ID 从当前本地会话读取，旧服务器+Agent 全局键不再用于恢复。
- 恢复仅在方法不支持（JSON-RPC -32601）时从 load 转 resume；其他错误直接上报。两者均不支持时要求显式重启，不静默新建。
- CLI-only Agent 保留管理能力，但不进入 ACP 聊天切换列表。
- 环境检测独立记录认证 `unknown/authenticated/unauthenticated`；版本检查不能证明登录。旧 Codex 版本检查转换为只读登录状态检测，其他版本检查跳过。

## 前端实施约束

仅由 Antigravity 历史 Valhalla 会话 `ec81a4be-7543-45ee-8658-f68966f57d3b` 修改展示层。模型 `gemini-3.8-flash-high`，推理 `high`。当前委派：生成时停止按钮、旧会话显式绑定确认、身份不匹配友好提示、中英文文案与 UI 测试。后端开发者不得直接编辑展示层。

## 验证与未交付范围

2026-09-18：修复后 `flutter analyze --no-pub` 无问题，全量 Flutter 测试 637 项通过（接手基线 624），Android debug APK 构建通过，`git diff --check` 通过。这不等于真实 SSH/ACP 服务验收。新增回归覆盖 CLI-only 排除、身份 JSON 兼容、登录/版本分离、查找命令注入、通道创建失败收尾、同一 Agent 多会话隔离、绑定身份校验，以及 5 项 UI 回归。

停止按钮、旧会话绑定确认和中英文身份错误提示已由指定 agy 会话落地，5 项专项 widget 测试通过；绑定确认传递已确认服务器和会话 ID。

尚未完成：发送被拒绝时输入保留、工作目录与远端历史入口、动态模型/模式/配置同步、Drift 数据迁移与回滚、传输重试/覆盖/临时文件策略、Linux/Windows 真机及真实服务器集成验证。Adapter 已提供配置/模式接口，但未接入 UI，不能标记业务功能完成。
