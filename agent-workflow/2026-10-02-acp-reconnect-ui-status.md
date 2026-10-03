# AgY UI Implementation Report — 2026-10-02 (Official Antigravity ACP, Ordered Blocks & Shell Top Bar Reconnect)

- **Status**: **FINAL UI READY** (UI whitelist changes complete and verified; ready for OpenCode test verification, format, analyze, build, and ADB gates)
- **Conversation**: Original Valhalla `ec81a4be-7543-45ee-8658-f68966f57d3b`
- **Model**: Gemini 3.8 Flash (High) (`gemini-3.8-flash-high`), high reasoning effort
- **Directory**: `/workspace/projects/valhalla`

---

## 1. Whitelisted Files Modified by AgY

1. `lib/features/chat/ai_chat_view.dart`
2. `lib/features/chat/cli_chat_view.dart`
3. `lib/features/chat/widgets/session_recovery_banner.dart`
4. `lib/features/dashboard/dashboard_view.dart`
5. `lib/features/docker/docker_view.dart`
6. `lib/features/system/system_view.dart`
7. `lib/features/files/sftp_file_view.dart`
8. `lib/features/agents/agent_management_view.dart`
9. `lib/features/shell/widgets/connection_status_banner.dart`
10. `agent-workflow/2026-10-02-acp-reconnect-ui-status.md` (this report)

*Note: No providers, models, infrastructure, tests, or generated files were modified by AgY.*

---

## 2. Preserved Dirty Changes

All pre-existing dirty changes across the repository were strictly preserved without rollback, reset, formatting, or regression:
- `docs/00-rules/01-project-engineering-rules.md`
- `docs/00-rules/02-frontend-design-and-ui-rules.md`
- `docs/01-requirements/01-prd-product-requirements.md`
- `docs/02-architecture/02-protocols-and-interfaces.md`
- `docs/03-development/04-implementation-status.md`
- `lib/core/providers/agent_registry_provider.dart`
- `lib/core/providers/ai_chat_provider.dart`
- `lib/core/providers/connection_lifecycle_provider.dart`
- `lib/core/providers/reconnect_provider.dart`
- `lib/core/providers/sftp_provider.dart`
- `lib/core/providers/terminal_provider.dart`
- `lib/data/models/agent_profile.dart`
- `lib/data/models/builtin_agent_preset.dart`
- `lib/data/models/chat_session.dart`
- `lib/data/repositories/agent_repository.dart`
- `lib/data/repositories/chat_repository.dart`
- `lib/features/dashboard/dashboard_provider.dart`
- `lib/features/docker/docker_provider.dart`
- `lib/features/system/system_provider.dart`
- `lib/infrastructure/acp/acp_client_adapter.dart`
- `lib/infrastructure/acp/agent_environment_service.dart`
- `lib/infrastructure/cli/agent_execution_target.dart`
- `test/core/agent_chat_eligibility_test.dart`
- `test/core/agent_registry_provider_test.dart`
- `test/core/ai_chat_provider_test.dart`
- `test/core/background_recovery_chat_state_test.dart`
- `test/core/background_recovery_lifecycle_test.dart`
- `test/core/connection_lifecycle_test.dart`
- `test/data/agent_repository_test.dart`
- `test/data/builtin_agent_preset_test.dart`
- `test/data/chat_message_contract_test.dart`
- `test/data/chat_recovery_merge_test.dart`
- `test/features/auth_challenge_ui_test.dart`
- `test/features/docker_view_test.dart`
- `test/infrastructure/acp_adapter_test.dart`
- `test/infrastructure/agent_environment_service_test.dart`
- `test/infrastructure/agent_execution_target_test.dart`
- `test/infrastructure/antigravity_acp_install_test.dart`
- `agent-workflow/2026-10-02-acp-and-reconnect.md`

---

## 3. UI Contract Verification & Implementation Details

### Item 1: Interleaved Message & Tool Ordering (`ai_chat_view.dart`)
- **Ordered Content Blocks**: `_buildAssistantBubble` iterates through `msg.orderedContentBlocks`:
  - `ChatContentBlockType.tool`: Maps tool execution via `toolsById[block.toolId]`. Renders full tool execution card with stable key `Key('tool_${block.toolId}')`, maintaining all status badges, arguments, results, and error details. Status updates anchor in place without reordering or jumping above visible text.
  - `ChatContentBlockType.text`: Slices UTF-16 text range safely via `msg.content.substring(block.start, block.end)` and renders via `_buildTextBlock` with stable key `ValueKey('msg_${msg.id}_block_${block.start}')` (messageId+start only, omitting end to preserve identity as streaming appends tokens).
- **Selectable Text & Full Message Copy**:
  - `_buildTextBlock` renders `MarkdownBody` with `selectable: true` allowing arbitrary user text selection.
  - Full-message copy action preserved at the bottom of the assistant card (`Clipboard.setData(ClipboardData(text: msg.content))`) when `msg.content.isNotEmpty`.
- **Accessory Blocks Preserved**: Retained thinking accordion (`_ThinkingBlock`), execution plans (`_ExecutionPlanView`), attachments list (`_buildMessageAttachments`), turn status banners (interrupted / failed), and assistant message actions.
- **Send Guards Preserved**: Preserved `canSend` check in `_buildInputArea` and `_handleSend()` guard checking live connection and recovery states.

### Item 2: Shell Top Bar Single Status Surface & Elimination of Duplicate Recovery Notices
- **Global Shell Status Banner (`connection_status_banner.dart`)**:
  - `controller == null` does NOT return `SizedBox.shrink()` early; session recovery (syncing, incomplete, failed) and context loss notices display reliably even when auto-reconnect controller is disabled or null.
  - Connection status reflects `serverConnectionProvider`, with `controller` used strictly as optional countdown source.
  - Unified status reporting at the shell top bar for:
    - Transport reconnecting (`reconnectingBanner`) with countdown timer.
    - Transient recovered confirmation (`reconnectedBanner`).
    - Permanent host key changed warning (`hostKeyChangedBanner`).
    - Manual user disconnect (`disconnectedManualBanner`).
    - ACP / CLI session recovery syncing (`sessionRecoverySyncingBanner`).
    - ACP / CLI session recovery incomplete (`sessionRecoveryIncompleteBanner` with `sessionRecoveryRetryButton`).
    - ACP / CLI session recovery failed (`sessionRecoveryFailedBanner` with `sessionRecoveryRetryButton`).
    - ACP session restart / context lost (`acpSessionRestartNotice` banner with dismiss action calling `ref.read(aiChatProvider.notifier).acknowledgeAcpSessionRestart()`).
  - **Clean Imports & No Exception Swallowing**: Removed unnecessary `session_recovery_status.dart` import. Watches `aiChatProvider` and `cliChatProvider` directly without swallowing exceptions; test harness dependencies are maintained by OpenCode.
  - **Tappable Details Dialog**: Entire banner is interactive via `InkWell`. Tapping opens an `AlertDialog` detailing active server name, host:port, connection state, ACP/CLI recovery status, context loss alert, direct link to `DiagnosticsView.show(context)`, acknowledge button calling `acknowledgeAcpSessionRestart()`, and transport/session retry button calling `connect()` / `recoverConnection()`.
- **Complete De-duplication of Recovery Notices**:
  - `ai_chat_view.dart`: Removed inline `SessionRecoveryBanner` call and cleaned unused import. Suppressed transient `AiChatNotifier.disconnectedCode` inline error banner. Removed inline `_AcpSessionNoticeBar`.
  - `cli_chat_view.dart`: Removed both desktop and mobile inline `SessionRecoveryBanner` calls and cleaned unused `state_views.dart` and `session_recovery_banner.dart` imports. Cleaned unused `connState` variable. Suppressed transient `CLI_DISCONNECTED` snackbar. Fixed missing closing brace on empty sessions check.
  - `session_recovery_banner.dart`: Replaced implementation with a lightweight placeholder returning `const SizedBox.shrink()` and cleaned all unused imports.
  - `agent_management_view.dart`: Removed inlined `sshDisconnectedAgentWarning` banner.
  - `sftp_file_view.dart`: Suppressed inline `SSH_DISCONNECTED` banner in `_buildErrorBanner`.

### Item 3: Retain Cached Content Offline & Disable Remote Execution
- **`dashboard_view.dart`**:
  - Snapshot resolution: `metricsAsync.asData?.value ?? ref.watch(systemMetricsHistoryProvider).lastOrNull`.
  - In `metricsAsync.when`: data (`snap`) passes non-nullable `SystemMetricsSnapshot` directly (avoiding `dead_null_aware_expression`), while `loading` (`snapshot`) and `error` (`snapshot`) fall back to the last known metrics for the target server, ensuring telemetry, uptime, and charts never blank or flash `--` during transport reconnects on the same endpoint.
- **`cli_chat_view.dart`**: Removed full-screen `OfflineStateView` in `build`; only shows empty state when `activeServer == null && cliState.agents.isEmpty`. Retains cached sessions and message logs. Disables remote session creation and prompt submission when disconnected (`isBusy` incorporates `!isConnected`, SDK install checks `isConnected`). Local draft editing, browsing, and copying remain interactive.
- **`docker_view.dart`**: Removed full-screen `OfflineStateView`; shows empty state only when `activeServer == null`. Retains cached containers, filters, and logs. Top refresh button disabled when disconnected. In container cards, `isRemoteDisabled = isContainerBusy || !isConnected` disables remote lifecycle operations (start, stop, restart, remove, inspect, logs, terminal) while keeping container selection, search, and filter chips responsive.
- **`system_view.dart`**: Removed full-screen `OfflineStateView`; shows empty state only when `activeServer == null`. Retains cached processes and services. Top refresh button disabled when disconnected. Process termination menu disabled (`enabled: isConnected`). Service lifecycle buttons (start, stop, restart, reload) disabled when disconnected (`isConnected ? ... : null`).
- **`sftp_file_view.dart`**: Retains cached directory listing, breadcrumb path, search, and editor. Remote mutations and directory navigation are disabled when `!isConnected`.
- **`agent_management_view.dart`**: Retains cached agent cards and detected environment status. Auto-install and login actions disabled when disconnected with explanatory tooltip.

### Item 4: Official Antigravity ACP Authentication Guard
- In `ai_chat_view.dart`, preserved `!usesAntigravityAcp(profile)` guard ensuring official Antigravity ACP authentication does not attempt CLI login. Only advertised ACP features are presented.

---

## 4. Verification Boundaries
- **AgY Constraints Strictly Maintained**:
  - Did NOT run `flutter test`, `dart format`, `flutter analyze`, `flutter gen-l10n`, builds, ADB commands, or git commands.
  - Preserved all existing dirty changes across the workspace.
  - Final UI readiness achieved. Handing off directly to OpenCode for testing, mechanical format, analyze, build, and ADB verification pipeline.
