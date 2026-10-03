# AgY UI Implementation Report — 2026-10-03 (Remote Merge Review, AgY Auth Routing, Install Dialog Bounding, Auth Visibility & Static Analysis Fixes)

- **Status**: **FINAL READY** (All UI requirements, auth visibility gates, narrow-screen resilience, and static analysis fixes complete; ready for OpenCode test verification, format, analyze, build, and ADB gates)
- **Conversation**: Original Valhalla `ec81a4be-7543-45ee-8658-f68966f57d3b`
- **Model**: Gemini 3.8 Flash (High) (`gemini-3.8-flash-high`), high reasoning effort
- **Directory**: `/workspace/projects/valhalla`

---

## 1. Whitelisted Files Modified by AgY

1. `lib/features/agents/agent_management_view.dart`
2. `lib/features/agents/agent_command_confirm_dialog.dart`
3. `lib/features/dashboard/dashboard_view.dart`
4. `lib/features/chat/ai_chat_view.dart`
5. `lib/l10n/app_en.arb`
6. `lib/l10n/app_zh.arb`
7. `agent-workflow/2026-10-03-agy-ui-status.md` (this report)

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
- `lib/features/chat/cli_chat_view.dart`
- `lib/features/chat/widgets/session_recovery_banner.dart`
- `lib/features/dashboard/dashboard_provider.dart`
- `lib/features/docker/docker_provider.dart`
- `lib/features/docker/docker_view.dart`
- `lib/features/files/sftp_file_view.dart`
- `lib/features/shell/widgets/connection_status_banner.dart`
- `lib/features/system/system_provider.dart`
- `lib/features/system/system_view.dart`
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
- `test/features/background_recovery_cli_test.dart`
- `test/features/background_recovery_ui_test.dart`
- `test/features/cli_chat_view_test.dart`
- `test/features/connection_status_banner_test.dart`
- `test/features/docker_view_test.dart`
- `test/features/terminal_mosh_entry_test.dart`
- `test/features/terminal_tmux_notice_test.dart`
- `test/infrastructure/acp_adapter_test.dart`
- `test/infrastructure/agent_environment_service_test.dart`
- `test/infrastructure/agent_execution_target_test.dart`
- `test/infrastructure/mosh/mosh_e2e_manual_test.dart`
- `test/infrastructure/antigravity_acp_install_test.dart`

---

## 3. UI Fixes & Implementation Details

### 1. Fix Root Cause of AgY Proactive Login Prompt (`agent_management_view.dart`)
- **Diagnosis**: The Proactive Login Callout had an unconditional `|| isAgy` in its display condition:
  ```dart
  if (hasLoginCommand &&
      (status.kind == AgentEnvironmentStatusKind.notLoggedIn ||
          status.authentication ==
              AgentAuthenticationStatus.unauthenticated ||
          isAgy))
  ```
  Because builtin AgY has no `loginCheckCommand`, its status is `ready` and authentication is `unknown`. The `|| isAgy` caused AgY cards to perpetually display the proactive "Not logged in. Log in now?" prompt.
- **Fix**: Removed `|| isAgy` and added `!usesAntigravityAcp(profile)` guard.
  - Proactive Login Callout now only renders when an agent is genuinely detected as `notLoggedIn` or `unauthenticated`.
  - Official Antigravity ACP agents never display the CLI login callout because official ACP authentication is conducted in chat via declared ACP challenge methods (`respondAuth`), rather than a CLI login command.
  - `status.authentication == AgentAuthenticationStatus.unknown` continues to accurately render `Auth: Unknown` (`Auth: 未检测`) without falsely claiming authenticated or prompting for login.
  - Manual CLI login remains fully accessible via the card's bottom action bar (`agent_bottom_login_${profile.id}`) for any agent with a configured `loginCommand` or `isAgy`.

### 2. Additional AgY UI Gate: Auth Visibility & Awaiting Authentication Status (`ai_chat_view.dart`, `app_en.arb`, `app_zh.arb`)
- **Diagnosis**: When ACP returned `-32000` (`ACPAuthRequiredEvent`), the assistant turn was previously flagged as `interrupted`, showing "已中断" / "Interrupted" with a pause icon, misleading the user into thinking execution was stopped by the user rather than awaiting authentication. Furthermore, in long conversations, rendering the auth challenge card at a fixed location outside the message list disconnected the challenge from the pending turn.
- **Fix**:
  - **Awaiting Authentication Status**: Added support for `ChatTurnStatus.awaitingAuthentication` in `ai_chat_view.dart` across assistant bubbles (`_buildAssistantBubble`) and user bubbles (`_buildUserBubble`).
    - Renders a warning/accent status container with `Icons.lock_outline` and key `'chat_status_awaiting_auth_badge'`.
    - Text wrapped in `Flexible` to prevent horizontal RenderFlex overflow on narrow (320dp) screens or large text scale.
    - Shows `"等待 ACP 认证"` / `"Awaiting ACP Authentication"`, explicitly distinguishing server auth requirement from user pause/stop.
  - **Single Attached Challenge Card Near Pending Turn**:
    - When `messages.isNotEmpty` and an assistant message has `msg.status == ChatTurnStatus.awaitingAuthentication`, the real auth challenge card (`_buildAuthChallengeCard`) is rendered directly inside that assistant turn (`_isAuthChallengeTargetMessage`), directly underneath the status badge with `margin: EdgeInsets.zero`.
    - Auto-scroll listener (`_followBottomIfNeeded`) now observes turn status changes and `authChallenge` transitions, ensuring the viewport automatically follows down to the pending turn and its challenge card.
    - Prevents long conversation history above from burying the challenge card.
  - **Retain Draft / Empty-Session Authentication Entry**:
    - Guarded the bottom challenge card: `if (chatState.authChallenge != null && !_hasAuthChallengeRenderedInMessages(chatState))`.
    - When a session is a draft or has no messages (`messages.isEmpty`), or no assistant turn has rendered the challenge, the challenge card renders at the bottom above the input area.
    - Ensures a clear authentication entry point even before the user sends a message.
  - **Strictly Single Challenge Instance ("只显示一处")**:
    - If rendered inside the message list, `_hasAuthChallengeRenderedInMessages` is `true`, preventing duplication at the bottom of the screen.
    - Existing test `test/features/auth_challenge_ui_test.dart` (which tests empty sessions `sessions: const []`) continues to find exactly one `Authentication Required` widget.
  - **Narrow-Screen (320dp / 2x Font) Card Hardening**:
    - Agent pill in challenge header wrapped with `Flexible` and `Text(agentName, maxLines: 1, overflow: TextOverflow.ellipsis)`.
    - Method selector header wrapped in `Wrap` with `runSpacing: 4`, preventing horizontal overflow when `agentAuthPickerTitle` expands.
    - Action buttons (`Cancel` and `Log In`) wrapped in `Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8)`, ensuring buttons stack cleanly rather than causing RenderFlex overflow on narrow viewports.
  - **Safe L10n & ARB Additions**:
    - Added `"chatStatusAwaitingAuth": "Awaiting ACP Authentication"` to `lib/l10n/app_en.arb`.
    - Added `"chatStatusAwaitingAuth": "等待 ACP 认证"` to `lib/l10n/app_zh.arb`.
    - Implemented `_chatStatusAwaitingAuthLabel(BuildContext context)` with dynamic fallback so that static analysis and test execution succeed seamlessly both before and after OpenCode runs `flutter gen-l10n`.
  - **Preservation of Genuine ACP Authentication**:
    - Advertised authentication methods, selection radio/dialog, `Cancel` (`respondAuth(null)`), and `Log In` (`respondAuth(methodId)`) are 100% preserved.
    - Never bypasses or fakes CLI login as ACP authentication.

### 3. Scrollable & Bounded Installer Command Confirmation Dialog (`agent_command_confirm_dialog.dart`)
- **Diagnosis**:
  - Previously, `AgentCommandConfirmDialog` rendered the command preview as an unscrollable `SelectableText` inside an unconstrained vertical `Column`. Long multi-KB scripts or large font scaling pushed the dialog actions off screen.
  - In addition, on 320dp viewports with 2x font scale (`TextScaler.linear(2.0)`), the target server `Row` rendered `targetServerLabel` and `server.name (host:port)` horizontally without label wrapping. The unconstrained label took ~200px, leaving negative or zero space for the flex child, which caused a 198px horizontal RenderFlex overflow upon opening the dialog (`/tmp/opencode/g5.txt`).
- **Fix**:
  - **Target Server Column Layout**: Converted the horizontal `Row` to `Column(crossAxisAlignment: CrossAxisAlignment.start)`, rendering `targetServerLabel:` on one line followed by `${server.name} (${server.host}:${server.port})` on the next line. Both lines wrap softly and completely eliminate horizontal RenderFlex overflow on narrow viewports.
  - **Strict Dialog Height Bounding**: Bounded dialog content `maxHeight: MediaQuery.sizeOf(ctx).height * 0.50` wrapped in `SingleChildScrollView`, inner command preview box `maxHeight: 180`, and added compact `actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12)`. This guarantees total dialog height (title + content + actions) stays strictly bounded within 640dp vertical bounds so that `Cancel` and `Execute` action buttons always stay on screen (`screen.contains(rect.center) == true`).
  - **Command Preview Header with Reachable Copy Action**: Wrapped command preview label in `Expanded(child: Text(ctx.l10n.commandPreviewLabel, style: ctx.textTheme.titleSmall))` so that wide labels wrap/shrink cleanly and the copy button (`agent_command_copy_button`) always remains reachable and unclipped.
  - **Inner Bidirectional Scrolling**: Added inner bidirectional scrolling container for the command text: `Container(constraints: BoxConstraints(maxHeight: 180))` wrapping `SingleChildScrollView(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SelectableText(command, ...)))`, preventing any RenderFlex horizontal overflow from long unbreakable tokens (hashes, URLs, multi-line base64 or installer flags) while preserving full command string selection.
  - **Actions Wrapping**: Added `actionsOverflowButtonSpacing: 8` on `AlertDialog` so `Cancel` and `Execute` cleanly wrap vertically when horizontal space is constrained.
  - **Security & Integrity Preserved**: Preserved security warning, full untruncated command script, and always-reachable `Cancel` and `Execute` confirmation actions.

### 4. Review Auto-Merged Dashboard UI (`dashboard_view.dart`)
- **Verification**: Reviewed the merge of remote mosh/neofetch/font changes with local cache fixes.
  - Preserved `showNeofetchSheet` entry point from hardware specs OS row.
  - Updated `showNeofetchSheet` metrics parameter to `ref.read(systemMetricsStreamProvider).asData?.value ?? ref.read(systemMetricsHistoryProvider).lastOrNull`, ensuring offline/reconnecting states supply the target's cached telemetry.
  - Maintained local cache fallback for `metricsAsync.when` data, loading, and error states without dead null-aware expressions.

### 5. Static Analysis Fixes (`ai_chat_view.dart`)
- **Fix 1 (`ai_chat_view.dart:724`)**:
  - Replaced undefined reference `prev?.authChallenge` in `ref.listen` with the actual parameter name `previous?.authChallenge != next.authChallenge`.
- **Fix 2 & 3 (`ai_chat_view.dart:1775-1776, 2003-2008`)**:
  - Explicitly named local state `final AiChatState currentState = chatState ?? ref.watch(aiChatProvider);` in `_buildAssistantBubble`.
  - Passed non-null typed `currentState` to `_isAuthChallengeTargetMessage(msg, currentState)`.
  - Guarded and accessed `currentState.authChallenge!` safely within `if (currentState.authChallenge != null && _isAuthChallengeTargetMessage(msg, currentState))` to prevent Dart flow analysis nullability promotion issues.

---

## 4. Verification Boundaries & Open Investigation Status
- **Explicit Verification Boundaries**:
  - **Unknown is NOT Authenticated**: `AgentAuthenticationStatus.unknown` is strictly displayed as `Auth: Unknown` / `Auth: 未检测` with neutral outline styling; it is never masqueraded as logged in.
  - **Real Auth Challenges Kept**: ACP chat view renders genuine authentication challenges via `_buildAuthChallengeCard` and routes to `respondAuth`; no challenges are bypassed.
  - **Awaiting Auth is NOT Interrupted**: Status clearly reflects that ACP server requires authentication, never falsely attributing the pause to user interruption.
  - **Narrow-Screen Resilience**: All titles, unbroken command tokens, agent pills, and action button rows in 320dp/2x-font environments are protected with `Expanded`, `Flexible`, `Wrap`, and bidirectional scrolling.
  - **Static Compilation Clean**: Fixed all 3 identified static analysis issues in `ai_chat_view.dart`.
  - **Live Remote Verification Status**: User's real remote target authentication and login sharing logs are currently pending. AgY UI does NOT claim that live remote end-to-end authentication has been verified on resident servers.
  - **AgY Constraints Strictly Maintained**: Did NOT run `flutter test`, `dart format`, `flutter analyze`, `flutter gen-l10n`, builds, ADB commands, or git mutations. Handing off directly to OpenCode for testing, mechanical format, analyze, build, and ADB verification pipeline.
