# ADR-0002: a2a-wrapper 不引入,保留现有 CLI 智能会话架构

| 状态 | 日期 | 决策人 |
|---|---|---|
| 已接受 | 2026-09-26 | durandal 分支维护者 |

## 背景

评估 [shashikanth-gs/a2a-wrapper](https://github.com/shashikanth-gs/a2a-wrapper)
能否替代本项目的 CLI 智能会话子系统 (Codex / OpenCode 结构化接口 +
Claude / agy / 自定义真实终端审批,见 `lib/core/providers/cli_chat_provider.dart`
与 `lib/infrastructure/cli/opencode_native_client.dart`)。

## a2a-wrapper 是什么

TypeScript/Node.js monorepo,把 Claude Code / Codex / OpenCode / Copilot /
Antigravity 包装成 **A2A (Agent2Agent) 协议的独立 HTTP 服务**:
- 以 Express 起 HTTP 服务器,暴露 `.well-known/agent-card.json`,
  客户端走 HTTP JSON-RPC + SSE;
- 各后端需要配置 API Key (ANTHROPIC_API_KEY / OPENAI_API_KEY 等);
- 仅 a2a-claude/a2a-codex/a2a-opencode 等与我们的场景相关。
- MIT 许可。

## 决策: 不引入、不替代

六个理由,任意一条单独成立:

1. **违背"零服务端改造"铁律**。PRD §1.1 将"强制在服务器端安装私有
   Agent 后端、暴露端口"列为行业痛点,这是 Valhalla 的立身之本。
   a2a-wrapper 恰恰要求在服务器部署常驻 Node.js 服务并开放 HTTP 端口。

2. **传输通道倒退**。现有 CLI 会话复用 dartssh2 的 SSH 通道
   (stdio/PTY),加密、防火墙友好、零新增端口;A2A 走 HTTP/SSE,
   需要服务器暴露新端口,PRD 非功能需求明确禁止未认证端口暴露。

3. **原生历史契约破坏**。PRD 与 2026-09-19 需求要求 CLI 智能会话
   "复用官方原生历史"、"原生删除需确认并真的删除远端历史"
   (opencode/codex 的 session list/resume)。a2a-wrapper 是独立服务,
   会话语义归它自己,不读写官方 CLI 历史,验收契约直接无法满足。

4. **审批交互丢失**。手机端"真实终端 + 权限卡片审批"是核心用户故事
   (PRD Story 1)。a2a-claude 是 headless SDK + 服务端 guardrail,
   无法呈现"允许一次/始终允许"的手机端三态审批。

5. **协议栈重复**。项目已有 ACP (acpd) 做结构化协议、真实终端做交互;
   引入 A2A 等于维护第三套协议,且 Flutter 侧还需要自研 A2A HTTP
   客户端 (a2a-wrapper 是服务端,不是 Dart 库),工作量大、收益为负。

6. **认证模型不符**。A2A 要求在服务器明文配置各厂商 API Key;
   现有方案直接使用服务器上已登录的 CLI 凭证,用户无需在两处管理密钥。

## 术语澄清 (2026-09-26 补充)

历史上存在两个缩写为 ACP 的协议,评估时必须区分:

1. **Agent Communication Protocol** (IBM Research / BeeAI, 2025 初) —
   REST 风格 agent↔agent 协议。**已于 2025-08 并入 Linux Foundation
   的 A2A 并停止独立开发**。市面上"ACP 并入 A2A"的新闻全部指它。
   本项目从未使用过这个协议。
2. **Agent Client Protocol** (Zed 主导, agentclientprotocol.com) —
   编辑器/客户端↔agent 会话协议 ("agent 界的 LSP"), JSON-RPC over
   stdio。本项目 `acpd` 包使用的是它,截至本 ADR 撰写仍在活跃开发
   (远程 agent 支持是进行中方向),无并入 A2A 的动向。

生态风险备注: Agent Client Protocol 由 Zed 主导 (单一厂商治理,
Gemini CLI / Claude Code 适配器等采用在增长)。本项目对其暴露面
有限 —— 仅 AI 智能会话页经 `acp_client_adapter.dart` 使用;
CLI 智能会话子系统只借用了 acpd 的 JSON-RPC `Connection` 类,
即使该协议停滞, 替换成本也被隔离在单个 adapter 内。
a2a-wrapper 实现的是 Linux Foundation 的 A2A
(agent↔agent, HTTP), 与上述两者均为不同问题域。

## 结论

现有 CLI 智能会话架构保留不动。a2a-wrapper 适合的场景是
"把 agent 变成可互操作的公网服务",与本产品
"在手机上通过 SSH 安全驱动服务器上已装的 CLI agent" 是不同的问题域。

### 现状事实 (2026-09-26 架构梳理佐证)

- 全部传输走 dartssh2 SSH 通道: Codex 是 SSH stdio 上的 JSON-RPC
  (复用 acpd 的 Connection 做请求关联);OpenCode 更是典范 ——
  在服务器起 `opencode serve --port 0` (仅回环地址),密码经 stdin
  传递 (不进 argv/配置/日志),再经 SSH 本地端口转发
  (`ssh.forwardLocal`) 用标准 HttpClient 访问。HTTP 也能零暴露,
  正是 a2a-wrapper 直连 HTTP 模式做不到的。
- "会话"即官方原生历史 (codex `thread/list`、opencode
  `/experimental/session`、claude SDK `listSessions`),App 本地只存
  选择/草稿/运行设置,删除走官方 CLI (`codex delete --force`) 并带
  二次确认 —— 契约见 handoffs/2026-09-19。
- 兼容面被 `test/features/cli_chat_view_test.dart` 等 5 个测试文件
  钉死;替换传输层需触碰 `_connectOnce`、两个 native client 的
  connect、`openTerminal` 等多处,纯成本、零收益。

若未来确有 A2A 互操作需求 (如把服务器 agent 暴露给第三方编排器),
正确路径是作为**可选的远端服务连接器** (用户自担部署),
而非替换内置 CLI 会话。
