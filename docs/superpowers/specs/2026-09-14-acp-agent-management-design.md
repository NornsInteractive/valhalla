# ACP Agent 管理与智能会话设计规格

## 目标

为 Valhalla 增加可配置的 ACP Agent 管理能力。用户可以在每台 SSH 服务器上手动添加 Claude Code、Codex、OpenCode、AGY 或其他支持 ACP 的 Agent；只有在目标服务器上完成 CLI、ACP Adapter 和登录状态检测的 Agent 才显示在聊天切换列表中。缺少依赖或登录状态失效时，应用必须先展示命令并取得用户确认，才允许自动安装或登录。

## 范围与约束

- 首版传输方式仍为现有 SSH 登录 Shell/PTY；不引入新的远端 Daemon。
- Agent 配置按 `serverId` 隔离；同名 Agent 在不同服务器上拥有独立状态。
- 不根据 Agent 名称猜测命令。内置预设提供明确命令，自定义 Agent 必须由用户填写命令。
- 安装、登录和 Agent 执行命令全部经过确认；不静默执行、不伪造成功状态。
- 前端展示只能由 Antigravity 历史会话 `ec81a4be-7543-45ee-8658-f68966f57d3b` 修改，使用模型 `gemini-3.8-flash-high`、推理等级 `high`。Codex 只修改 core/data/infrastructure、测试和文档契约，不直接改页面布局、主题或展示文案。
- 新增文案必须同时写入 `lib/l10n/app_zh.arb` 和 `lib/l10n/app_en.arb`，并重新生成本地化代码。

## 核心领域模型

### `AgentProfile`

持久化字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | `String` | UUID 或稳定的内置 ID |
| `serverId` | `String` | 所属 SSH 服务器 ID |
| `name` | `String` | 用户显示名称 |
| `description` | `String` | 简短说明 |
| `cliCommand` | `String` | CLI 探测命令，例如 `claude`、`codex` |
| `acpCommand` | `String` | ACP stdio 启动命令 |
| `installCommand` | `String?` | 可选安装命令 |
| `loginCheckCommand` | `String?` | 可选登录检查命令 |
| `loginCommand` | `String?` | 可选登录命令 |
| `createdAt` / `updatedAt` | `DateTime` | 配置审计时间 |

内置预设只提供表单初始值，不代表已安装或可用。预设至少包含 Claude Code、OpenAI Codex、OpenCode 和 AGY；用户可复制预设后修改命令，也可从空白表单添加任意 ACP Agent。

### Agent 状态

```text
unknown -> checking -> cliMissing | acpMissing | notLoggedIn | ready | error
```

状态是针对 `(serverId, agentId)` 的运行时结果，不直接持久化为永久真值。重新连接服务器、安装或登录完成后必须重新检测。

## 分层设计

### 数据层

- 新增 `AgentRepository`，使用现有 `LocalStorageService` JSON 存储，键名为 `valhalla_agents_v1`。
- 提供 `getAll(serverId)`, `save(profile)`, `delete(agentId)`, `find(agentId)`。
- 删除 Agent 只删除配置和运行时状态，不删除 `ChatSession`。
- 将旧 `ChatSession.agentType` 迁移到稳定 Agent ID；旧 Claude/Codex/OpenCode 类型映射到对应内置 ID。无法映射的历史会话保留原始名称并在 UI 标记为 Agent 已移除。
- 不为新安装自动创建远端 Agent 记录。

### 远端检测与操作服务

新增 `AgentEnvironmentService`，依赖 `SSHClientManager.executeWithLoginShell`，并返回结构化结果：

```dart
Future<AgentEnvironmentStatus> inspect(
  AgentProfile profile,
  String serverId,
);

Future<SSHExecutionResult> runInstall(
  AgentProfile profile,
  String serverId,
);

Future<SSHExecutionResult> runLogin(
  AgentProfile profile,
  String serverId,
);
```

检测顺序：

1. `command -v <cliCommand>`，非零退出映射为 `cliMissing`。
2. 用受限启动探测验证 `<acpCommand> --help` 或等价无副作用检查，失败映射为 `acpMissing`。
3. 存在 `loginCheckCommand` 时执行它；非零退出映射为 `notLoggedIn`。没有登录检查命令时状态为 `ready`，但 UI 明确标注“未提供登录检查”。

命令参数必须经过 shell 安全校验：拒绝空命令、换行注入和未闭合引号；命令执行设置超时并保留脱敏后的 stdout/stderr。安装与登录命令不在服务层自动调用，必须由上层确认后显式调用。

### 状态层

新增 `AgentRegistryNotifier`：

- 监听 `activeServerProvider` 和 SSH 连接状态。
- 暴露当前服务器的 Agent 列表及每个 Agent 的检测状态、错误摘要、最近检查时间。
- `addAgent` 保存后立即检查；`deleteAgent` 清理状态并刷新列表；`refreshAgent` 只执行只读检查。
- `installAgent`、`loginAgent` 只接受上层已确认的调用，执行后自动 `inspect`。
- 提供 `readyAgents` 派生列表，聊天切换器只能读取该列表。
- 当前 Agent 不可用时阻止发送消息并返回可操作错误，不回退到另一个 Agent。

### ACP 适配层

- `ACPClientAdapter` 改为接收 `AgentProfile`，不再以固定 `AgentType` 决定二进制名称。
- 通过 profile 的 `acpCommand` 启动远端 stdio ACP；初始化、`session/prompt`、权限请求和流式事件继续复用现有 ACP 事件模型。
- 删除“找不到 ACP 就执行内置 SSH 运维模拟流程”的默认分支。缺少 ACP 时返回结构化错误，由 UI 引导安装。
- ACP 启动失败时发送 `ACPErrorEvent` 并完成当前请求，不写入伪造的诊断结果。

### UI 交互契约（交给 Antigravity）

- 设置或聊天 Agent 管理入口显示当前服务器 Agent。
- 添加表单支持四个内置预设和自定义命令字段。
- 列表仅显示当前服务器已添加的 Agent；状态徽标区分检测中、缺 CLI、缺 ACP、未登录、可用和错误。
- 缺少依赖/未登录时显示命令预览、服务器名、风险说明和“执行/取消”按钮。执行后显示实时输出和重新检测结果。
- 删除必须二次确认；删除最后一个 Agent 显示空状态。
- 聊天切换器仅展示 `readyAgents`，无可用 Agent 时提供“管理 Agent”入口。
- 所有展示字符串进入中英文 ARB。

## 安全与错误处理

- 未连接 SSH 时不运行探测、安装或登录命令。
- 安装/登录命令执行前强制确认；危险命令仍遵循现有命令风险分级。
- 远端非零退出、超时、权限拒绝、PTY 不可用均映射为可读错误，并保留脱敏输出供用户诊断。
- 不在日志、聊天消息或持久化配置中保存密码、Token 或完整敏感环境变量。
- 删除 Agent 不影响 SSH 凭据、服务器配置和聊天记录。

## 测试验收标准

### 单元测试

- `AgentProfile` 序列化、反序列化和旧 `AgentType` 迁移。
- `AgentRepository` 按服务器隔离、增删改查和空列表行为。
- 检测结果到 `AgentEnvironmentStatus` 的映射。
- shell 命令校验拒绝注入、空命令和换行。
- 缺 CLI、缺 ACP、未登录、已就绪、超时和非零退出路径。
- 安装/登录服务只在显式调用时执行，并在完成后重新检测。

### Provider/集成测试

- `readyAgents` 只包含当前服务器已添加且就绪的 Agent。
- 切换服务器后列表和状态完全刷新，不复用旧服务器状态。
- 删除最后一个 Agent 后状态为空。
- ACP Adapter 使用 profile 的 `acpCommand`，缺少 ACP 时不执行内置模拟运维流程。

### Flutter 验证

```text
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

## 非目标

- 首版不实现远端 ACP Registry 自动发现。
- 首版不实现跨服务器 Agent 配置同步。
- 首版不自动管理第三方 Token、OAuth 回调或云端账号，只执行用户确认的 CLI 登录流程并显示结果。
