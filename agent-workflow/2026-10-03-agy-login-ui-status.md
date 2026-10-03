# AgY ACP Login Flow — UI Handoff Status Report

- **Status**: READY
- **Session Conversation ID**: `ec81a4be-7543-45ee-8658-f68966f57d3b`
- **Model**: `gemini-3.8-flash-high` (effort: high)
- **Target Contracts**:
  - `agent-workflow/2026-10-03-agy-login-flow.md`
  - `agent-workflow/2026-10-03-agy-login-ui-review.md`
  - `agent-workflow/2026-10-03-agy-login-ui-gate-fixes.md`
- **Timestamp**: 2026-10-03T13:21:00+08:00

---

## 1. Scope & Changed Files

Per the implementation, review, and analyze gate fix contracts, modifications were strictly limited to `lib/features/` UI presentation and ARB localization files. No business logic, data models, infrastructure adapters, or test files were modified. No tests, analyzers, formatters, code generators (`flutter gen-l10n`), builds, or ADB commands were executed.

### Changed Files:
1. `lib/l10n/app_en.arb`:
   - Added all 22 required keys for the ACP login and review flow.
   - Restored original HEAD `chatCommandsDraftPreviewNotice` that was dropped during earlier additions.
   - Refined `chatAuthManualCallbackDesc`, `chatAuthCallbackInputLabel`, `chatAuthCallbackInputHint`, and `chatAuthCallbackInvalidError` to strictly accept and prompt for a complete loopback redirect URL only (`http://127.0.0.1:PORT/...?code=...&state=...`), explicitly rejecting raw authorization codes to avoid state mismatch or cross-auth confusion.
   - Added `agentTargetChangedNotice`, `agentAgyAuthCheckUnavailable`, and `agentAgyAuthCheckInvalid`.
2. `lib/l10n/app_zh.arb`:
   - Added corresponding Chinese translations for all 22 keys with identical semantics and strict full loopback URL guidance (`http://127.0.0.1:端口/...?code=...&state=...`).
3. `lib/features/chat/ai_chat_view.dart`:
   - Replaced all temporary dynamic l10n fallback helper getters with direct typed `context.l10n.<getter>` / `dialogCtx.l10n.<getter>`. Preserved older helpers not introduced in this task (`_chatStatusAwaitingAuthLabel`).
   - In `ref.listen<AiChatState>`:
     - Automatically resets `_authLaunchError = null` when `authRequest` is cleared or replaced.
     - Auto-open postframe callback verifies `mounted`, `isAuthenticating`, matching `authRequest`, matching `serverId`, and matching `agentId` before launching external browser.
     - Displays completion snackbar (`agentAuthRetryHint`) for AgY only after `previous.isAuthenticating && !next.isAuthenticating`, `previous.authChallenge != null`, `next.authChallenge == null`, `next.authenticationConfirmed == true`, `next.authError == null`, and server matches active server (prevents false positive success snackbar when auth is cancelled).
     - In auto-open postframe callback: calls synchronous dedup method `ref.read(aiChatProvider.notifier).claimAuthBrowserLaunch(newAuthRequest)` after target and state validation; only launches browser if claim succeeds, preventing multiple tabs when `AiChatView` instances in `IndexedStack` and pushed routes listen concurrently. Manual reopen remains unclaim-gated.
   - In `_buildAuthChallengeCard`:
     - Default method selection prefers advertised `'oauth-personal'` if available in `challenge.methods`, falling back to the first available method; does not invent missing methods.
     - Fixed `RadioGroup<String>.onChanged` to always supply non-null callback, returning early if `isAuthenticating`. Added `enabled: !isAuthenticating` to each `Radio<String>` child.
     - Copy link button uses `snackContext.l10n.agentLoginTerminalUrlCopied` (replacing missing `copiedToClipboard`) and guards async callback with `if (mounted && snackContext.mounted)` after capturing `final snackContext = context`.
     - Validates current request identity (`cur.authRequest == authRequest && cur.isAuthenticating`) on reopen browser, copy link, and manual callback buttons.
     - Removed immediate success/retry hint on clicking proceed for AgY.
   - In `_showManualCallbackDialog`:
     - Controller lifecycle is strictly managed with `try ... finally { controller.clear(); controller.dispose(); }` to wipe sensitive callback URLs from memory.
     - Content is wrapped in `SingleChildScrollView` for narrow viewports (320dp), large fonts (2x), and keyboard overlay safety.
     - Captures `capturedRequest`, `capturedServerId`, and `capturedAgentId` on open; aborts submission if active state has changed.
   - In `_buildAssistantBubble` & `_buildUserBubble`:
     - Supported root's `AiChatState.authenticationConfirmed` runtime flag.
     - When `authenticationConfirmed == true` and `authChallenge == null`: displays `agentAuthRetryHint` in place of the "awaiting ACP auth" badge with primary styling and checkmark icon.
     - Hides `_buildAwaitingAuthDiscoveryAction` when `authenticationConfirmed` is true to prevent immediately showing a new login card upon successful authentication.
   - Input & Action Guards:
     - Added `state.isAuthenticating` to `isBusy` in `_buildInputArea`, `ChatRunSettingsStrip`, `ChatUsageDiagnosticsDialog`, and `_openRunSettings` guards so the UI consistently disables sending, settings tuning, and status diagnostics while authentication is in progress.
4. `lib/features/agents/agent_management_view.dart`:
   - Added `onNavigateToChat` callback parameter: `const AgentManagementView({super.key, this.onNavigateToChat});`.
   - Removed all dynamic fallback helper methods; replaced with direct typed `context.l10n.<getter>`.
   - In `_mapStatusDetail`: mapped `AGY_AUTH_CHECK_UNAVAILABLE` to `context.l10n.agentAgyAuthCheckUnavailable`, `AGY_AUTH_CHECK_INVALID` to `context.l10n.agentAgyAuthCheckInvalid`, `AGY_ACP_SIGN_IN_REQUIRED` to `context.l10n.agentAgyAcpSignInRequired`, and `AGY_ACP_CREDENTIALS_NOT_VALIDATED` to `context.l10n.agentAgyAcpCredentialsSaved`.
   - In `_handleAcpLogin`:
     - Checks `activeServer?.id != server.id`; aborts with `context.l10n.agentTargetChangedNotice` snackbar if server differs (never auto-switches active server).
     - Switches agent (`await ref.read(aiChatProvider.notifier).switchAgent(profile.id)`), immediately re-verifies `activeServer?.id == server.id && activeAgent?.id == profile.id` BEFORE calling `requestAuthentication()`, and re-verifies again after `requestAuthentication()` completes (never creates session or sends messages).
     - If `widget.onNavigateToChat != null`, pops modal and invokes callback. If `widget.onNavigateToChat == null` (e.g. from Settings), pushes `AiChatView` via standard `MaterialPageRoute` so the ACP login card is directly presented.

---

## 2. Review Checklist Verification

| # | Requirement | Implementation Status |
|---|---|---|
| 1 | No dynamic l10n getters + no hardcoded English/Chinese try/catch fallbacks; direct typed `context.l10n` | Verified. 20 dynamic helpers removed; older `_chatStatusAwaitingAuthLabel` preserved. |
| 2 | `_handleAcpLogin` never auto-selects server, aborts on mismatch with notice, presents `AiChatView` | Verified. Mismatch check with `agentTargetChangedNotice`, re-checks post-await, pops/calls callback or pushes `AiChatView`. |
| 3 | Manual callback controller dispose in finally, clear sensitive text, scrollable at 320dp/2x, capture target | Verified. `try/finally` with `clear()` & `dispose()`, `SingleChildScrollView`, aborts on request/server/agent drift. |
| 4 | Auto-open postframe checks authRequest, server, agent, isAuthenticating, mounted; clear error on reset; guard buttons | Verified. Postframe guards applied, `_authLaunchError = null` on authRequest change, buttons validate current request. |
| 5 | Prefer advertised `oauth-personal` for fresh selection | Verified. Checks `challenge.methods.any((m) => m.id == 'oauth-personal')` before falling back to first method. |
| 6 | Map `AGY_AUTH_CHECK_UNAVAILABLE` and `AGY_AUTH_CHECK_INVALID` locally | Verified. Mapped in `_mapStatusDetail` with ARB strings in both `app_en.arb` and `app_zh.arb`. |
| 7 | Success hint timing for AgY: only after challenge cleared without authError | Verified. Immediate hint removed in `_handleProceedAuth` for AgY; verified clearance hint handled in `ref.listen` with `next.authenticationConfirmed` guard. |
| 8 | Manual callback accepts full loopback URL only; no raw code hints | Verified. Prompt, label, and hint updated to complete `http://127.0.0.1:PORT/...?code=...&state=...` URL only in EN and ZH ARBs; raw codes rejected. |
| 9 | Runtime flag `AiChatState.authenticationConfirmed` support | Verified. Badge switches to `agentAuthRetryHint` and discovery-login card is hidden when flag is true. |
| 10 | Browser auto-open deduplication via `claimAuthBrowserLaunch` | Verified. Postframe callback claims request on notifier after identity checks; only launches if claimed. Manual reopen not claimed. |
| 11 | Guard `isAuthenticating` across input `isBusy`, `ChatRunSettingsStrip`, and `_openRunSettings`; pre-RPC server/agent check in management | Verified. Added `isAuthenticating` to input and settings strip busy states; management re-verifies active server and profile immediately after `switchAgent` before `requestAuthentication`. |
| 12 | Analyze gate fixes (EN ARB restoration, clipboard getter/guard, RadioGroup callback/enabled) | Verified. Restored `chatCommandsDraftPreviewNotice`; reused `agentLoginTerminalUrlCopied` with `mounted && snackContext.mounted` guard; non-null `RadioGroup.onChanged` with guard and `Radio.enabled: !isAuthenticating`. |

---

## 3. Caveats & Post-Handoff Next Steps

1. **Typed Localization Generation**:
   Direct typed calls to newly introduced ARB getters (`context.l10n.chatAuthWaitingForBrowser`, `context.l10n.agentTargetChangedNotice`, etc.) are written directly in the code per the engineering contract. OpenCode will run `flutter gen-l10n` after exit to generate `AppLocalizations` implementations.
2. **Zero Execution Guarantee**:
   No flutter analyze, tests, formatters, code generators, builds, or git commands were run during this session.
3. **Ready for Root Exit**:
   All UI handoff requirements, review adjustments, and analyze gate fixes are completed. Awaiting root exit.
