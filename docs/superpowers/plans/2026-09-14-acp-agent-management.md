# ACP Agent Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让用户按 SSH 服务器手动注册 Claude Code、Codex、OpenCode、AGY 或任意 ACP Agent，并在远端依赖和登录状态确认可用后，将其安全地加入智能会话切换列表。

**Architecture:** 新增按服务器隔离的 `AgentProfile`/`AgentRepository`，由 `AgentEnvironmentService` 通过现有 SSH 登录 Shell/PTY 检测、安装和登录。`AgentRegistryNotifier` 管理运行时状态，ACP Adapter 接收 profile 的 ACP 命令；UI 由指定 Antigravity 会话消费 Provider 契约并实现表单、状态、确认弹窗和聊天切换器。

**Tech Stack:** Flutter 3.44.2, Dart 3.10.0, Riverpod, SharedPreferences JSON storage, dartssh2, acpd, xterm, Flutter Material 3, ARB localization.

**Spec:** `docs/superpowers/specs/2026-09-14-acp-agent-management-design.md`

## Global Constraints

- 首版只使用现有 SSH 登录 Shell/PTY，不引入远端专有 Daemon。
- Agent 配置按 `serverId` 隔离；状态针对 `(serverId, agentId)`，不把检测结果永久当作真值。
- 不根据名称猜测命令；自定义 Agent 必须显式填写 CLI、ACP、安装和登录命令。
- 安装、登录和 Agent 执行命令执行前必须展示命令并取得用户确认。
- 前端展示只能由 Antigravity 会话 `ec81a4be-7543-45ee-8658-f68966f57d3b` 修改，命令使用 `agy --conversation ... --model gemini-3.8-flash-high --effort high --mode accept-edits`。
- Codex 不直接修改页面布局、主题或展示文案；前端文案由 Antigravity 写入中英文 ARB。
- 所有新增生产代码先写失败测试并确认 RED，再写最小实现；每个任务完成后运行针对性测试。
- 不保存密码、Token 或完整敏感环境变量；所有 SSH 输出经过现有脱敏器。

---

### Task 1: AgentProfile 与持久化仓储

**Files:**
- Create: `lib/data/models/agent_profile.dart`
- Create: `lib/data/repositories/agent_repository.dart`
- Modify: `lib/data/storage/local_storage_service.dart`
- Modify: `lib/core/providers/storage_providers.dart`
- Test: `test/data/agent_repository_test.dart`

**Interfaces:**
- `AgentProfile({required id, required serverId, required name, required description, required cliCommand, required acpCommand, installCommand, loginCheckCommand, loginCommand, createdAt, updatedAt})` with `toJson/fromJson`.
- `AgentRepository.getAll(String serverId) -> List<AgentProfile>`
- `AgentRepository.find(String serverId, String agentId) -> AgentProfile?`
- `AgentRepository.save(AgentProfile profile) -> Future<void>`
- `AgentRepository.delete(String serverId, String agentId) -> Future<void>`
- `agentRepositoryProvider -> AgentRepository`

- [ ] **Step 1: Write failing tests** for profile round-trip, server isolation, save/update/delete, empty storage, and malformed JSON fallback.
- [ ] **Step 2: Run `flutter test test/data/agent_repository_test.dart`** and confirm failure because the model/repository/provider do not exist.
- [ ] **Step 3: Implement the model and repository** using `valhalla_agents_v1`; never return another server's records.
- [ ] **Step 4: Run the targeted tests** and confirm all pass.
- [ ] **Step 5: Add migration tests** mapping legacy `ChatSession.agentType` values to stable built-in IDs without altering message history.
- [ ] **Step 6: Implement migration in the repository layer** as a one-time read/write transformation with deterministic IDs: `builtin-claude-code`, `builtin-codex`, `builtin-opencode`, `builtin-agy`.
- [ ] **Step 7: Run `flutter test test/data/agent_repository_test.dart test/data/models_test.dart`**.

### Task 2: Safe command validation and remote environment service

**Files:**
- Create: `lib/core/security/agent_command_validator.dart`
- Create: `lib/infrastructure/acp/agent_environment_service.dart`
- Modify: `lib/core/providers/infrastructure_providers.dart`
- Test: `test/core/agent_command_validator_test.dart`
- Test: `test/infrastructure/agent_environment_service_test.dart`

**Interfaces:**
- `AgentCommandValidator.validate(String command) -> void` throws `ValidationException` for empty commands, newlines, NUL bytes, or unbalanced quotes.
- `AgentEnvironmentStatusKind { unknown, checking, cliMissing, acpMissing, notLoggedIn, ready, error }`.
- `AgentEnvironmentStatus({required kind, version, detail, checkedAt})`.
- `AgentEnvironmentService.inspect(AgentProfile profile, String serverId) -> Future<AgentEnvironmentStatus>`.
- `AgentEnvironmentService.runInstall(AgentProfile profile, String serverId) -> Future<SSHExecutionResult>`.
- `AgentEnvironmentService.runLogin(AgentProfile profile, String serverId) -> Future<SSHExecutionResult>`.

- [ ] **Step 1: Write validator tests** for accepted commands and each rejected injection shape.
- [ ] **Step 2: Run the validator test** and confirm RED.
- [ ] **Step 3: Implement the validator** with explicit character checks and quote-balance scanning; do not attempt shell parsing or command rewriting.
- [ ] **Step 4: Run validator tests** and confirm GREEN.
- [ ] **Step 5: Write service tests** with a fake command executor covering CLI missing, ACP missing, not logged in, ready, timeout, non-zero exit, and disconnected SSH.
- [ ] **Step 6: Run service tests** and confirm RED because the service is absent.
- [ ] **Step 7: Implement `AgentEnvironmentService`** on `SSHClientManager.executeWithLoginShell`; run `command -v`, ACP help probe, and optional login check in order; apply a finite timeout and return sanitized output.
- [ ] **Step 8: Implement explicit `runInstall`/`runLogin`** that reject missing commands and never call automatically from `inspect`.
- [ ] **Step 9: Run both targeted test files** and confirm GREEN.

### Task 3: Agent registry state and server lifecycle integration

**Files:**
- Create: `lib/core/providers/agent_registry_provider.dart`
- Modify: `lib/core/providers/server_provider.dart`
- Modify: `lib/core/providers/storage_providers.dart`
- Test: `test/core/agent_registry_provider_test.dart`

**Interfaces:**
- `AgentRuntimeState({required profile, required status, isInstalling, isLoggingIn, errorMessage})`.
- `AgentRegistryState({required serverId, required agents, isLoading})`.
- `AgentRegistryNotifier.refresh() -> Future<void>`
- `AgentRegistryNotifier.addAgent(AgentProfile) -> Future<void>`
- `AgentRegistryNotifier.deleteAgent(String agentId) -> Future<void>`
- `AgentRegistryNotifier.installAgent(String agentId) -> Future<void>`
- `AgentRegistryNotifier.loginAgent(String agentId) -> Future<void>`
- `AgentRegistryNotifier.readyAgents -> List<AgentProfile>`
- `agentRegistryProvider -> AgentRegistryState`

- [ ] **Step 1: Write provider tests** for server isolation, add-then-inspect, ready filtering, delete-last empty state, server switch refresh, and install/login transitions.
- [ ] **Step 2: Run the provider test** and confirm RED.
- [ ] **Step 3: Implement the notifier** with dependencies injected through providers; invalidate/refresh when `activeServerProvider` changes.
- [ ] **Step 4: Ensure `readyAgents` excludes every non-ready status** and no fallback Agent is selected.
- [ ] **Step 5: Run targeted provider tests** and confirm GREEN.
- [ ] **Step 6: Add connection lifecycle behavior**: disconnected SSH marks entries unknown and blocks inspect/install/login with a user-actionable error.
- [ ] **Step 7: Run all agent unit/provider tests**.

### Task 4: ACP Adapter profile-based startup

**Files:**
- Modify: `lib/infrastructure/acp/acp_client_adapter.dart`
- Modify: `lib/core/providers/ai_chat_provider.dart`
- Modify: `lib/data/models/chat_session.dart`
- Modify: `lib/data/repositories/chat_repository.dart`
- Test: `test/infrastructure/acp_adapter_test.dart`
- Test: `test/core/ai_chat_provider_test.dart`

**Interfaces:**
- `ACPClientAdapter({required AgentProfile profile, required SSHClient sshClient, workingDirectory})`.
- `AiChatState.activeAgentProfile -> AgentProfile?` and `switchAgent(String agentId)`.
- `ChatSession.agentId` persists the stable Agent ID while legacy `agentType` remains readable during migration.

- [ ] **Step 1: Add failing adapter tests** asserting the exact profile `acpCommand` is started and missing ACP produces `ACPErrorEvent` without invoking the SSH diagnostic fallback.
- [ ] **Step 2: Run adapter tests** and confirm RED against the fixed `AgentType`/fallback implementation.
- [ ] **Step 3: Refactor the adapter** to use `AgentProfile.acpCommand`; preserve ACP event parsing, permission requests, and stream completion.
- [ ] **Step 4: Remove the built-in fake SSH Ops fallback**; return structured missing-ACP errors.
- [ ] **Step 5: Update chat state/session persistence** to use `agentId`, migrate legacy sessions, and block send when the selected Agent is not ready.
- [ ] **Step 6: Run adapter, chat, model, and repository tests** and confirm GREEN.

### Task 5: Antigravity UI handoff and implementation

**Files owned by Antigravity only:**
- `lib/features/agents/**`
- `lib/features/chat/ai_chat_view.dart`
- `lib/features/settings/settings_view.dart`
- `lib/widgets/**` (UI-only additions)
- `lib/l10n/app_zh.arb`
- `lib/l10n/app_en.arb`
- Generated localization files
- UI-specific tests

**Required provider contract:** consume `agentRegistryProvider`, `readyAgents`, `AgentEnvironmentStatusKind`, and notifier methods from Tasks 2–4; do not change core/data/infrastructure APIs.

- [ ] **Step 1: Launch only the approved Valhalla conversation** with `agy --conversation ec81a4be-7543-45ee-8658-f68966f57d3b --model gemini-3.8-flash-high --effort high --mode accept-edits`.
- [ ] **Step 2: Send the exact UI brief**: Agent management entry, built-in presets (Claude/Codex/OpenCode/AGY), custom form, per-server status badges, command preview confirmation for install/login, output/recheck, delete confirmation, empty state, and chat switcher limited to `readyAgents`.
- [ ] **Step 3: Require Antigravity to run `dart format`, `flutter analyze`, and UI tests**, reporting modified files; reject edits outside the allowed UI/localization scope.
- [ ] **Step 4: Inspect the diff** and verify no core/data/infrastructure/pubspec/non-UI test files were edited by the UI session.

### Task 6: Integration tests, documentation, and release gate

**Files:**
- Modify: `docs/03-development/04-implementation-status.md`
- Modify: `docs/04-testing-and-deployment/01-testing-strategy-and-testcases.md`
- Create: `test/integration/agent_chat_flow_test.dart`

- [ ] **Step 1: Write an integration test** covering add Agent → inspect → ready list → select → send prompt with the correct profile command, plus missing-login confirmation path.
- [ ] **Step 2: Run it and confirm RED** until Tasks 1–4 contracts are integrated.
- [ ] **Step 3: Implement only test fixtures/adapters needed to exercise the existing contracts**, never fake a production remote success path.
- [ ] **Step 4: Run the full suite:**

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

- [ ] **Step 5: Update testing matrix** with Agent detection, install/login confirmation, server isolation, and ACP startup failure cases.
- [ ] **Step 6: Update implementation status** with completed Agent management capabilities and known non-goals.
- [ ] **Step 7: Inspect `git diff --stat` and `git status`**, verify no secrets, generated build outputs, or forbidden UI/backend cross-edits.

