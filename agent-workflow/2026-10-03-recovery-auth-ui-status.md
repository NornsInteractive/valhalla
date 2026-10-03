# Recovery Auth & Download UI Status Report

- **Status**: COMPLETE
- **Session Conversation ID**: `ec81a4be-7543-45ee-8658-f68966f57d3b`
- **Model**: `gemini-3.8-flash-high` (effort: high)
- **Target Specifications**:
  - `agent-workflow/2026-10-03-recovery-auth-download.md`
- **Timestamp**: 2026-10-03T20:53:30+08:00

---

## 1. Summary of Changes

### A. Single Auth Owner & Login Race Elimination
- **File**: `lib/features/agents/agent_management_view.dart`
  - Replaced multi-stage switch/pop/await orchestration with a single invocation of `AiChatNotifier.requestAuthenticationForAgent(server.id, profile.id)`.
  - Wrapped with `unawaited` and `.catchError((_) {})` so the Future completes in the background regardless of whether `AgentManagementView` is unmounted during navigation.
  - Guarded against `ref` use after disposal: only updates `_isLoggingIn = false` if `mounted` is true; never calls `ref.read` after pop/push.
  - Navigates immediately to chat via `Navigator.pop()` (when modal) or `Navigator.push(AiChatView())` without passing `pop(true)`.
- **File**: `lib/features/chat/ai_chat_view.dart`
  - Removed redundant `autoRequestAuth`, `targetAgentId`, and `targetServerId` constructor parameters from `AiChatView`.
  - Removed redundant post-frame auto-request callback in `initState`.
  - Simplified `_showManageAgentsModal` back to standard `void` navigation without awaiting modal return boolean.
  - Single auth ownership is now cleanly centralized in `AiChatNotifier.requestAuthenticationForAgent`.

### B. ACP Header Layout & Accessibility
- **File**: `lib/features/chat/ai_chat_view.dart`
  - Replaced competing `Flexible` + `Spacer` with a unified `Expanded` wrapper on the agent selector.
  - Added full-name `Tooltip` so truncated agent names can be inspected.
  - Internal `Flexible` text with `TextOverflow.ellipsis` is intended to shrink on 320px screens and 2x text scale; actual overflow/widget/device validation remains owned by OpenCode and is not proven by this edit report.
  - Preserved mobile drawer button, session sharing toggle, and analytics/diagnostics buttons.

### C. SFTP Download Reason Codes & Reconnection Paused State
- **File**: `lib/features/files/sftp_file_view.dart`
  - Localized 8 download reason codes in `_mapErrorMessage` and `_mapTransferError`:
    - `SFTP_DOWNLOAD_DISCONNECTED`
    - `SFTP_DOWNLOAD_PERMISSION_DENIED`
    - `SFTP_DOWNLOAD_NOT_FOUND`
    - `SFTP_DOWNLOAD_TIMEOUT`
    - `SFTP_DOWNLOAD_LOCAL_SPACE`
    - `SFTP_DOWNLOAD_LOCAL_IO`
    - `SFTP_DOWNLOAD_INCOMPLETE`
    - `SFTP_DOWNLOAD_FAILED`
  - Fixed generic failure `sftpDownloadFailed` to be generic ("Download failed" / "下载失败") rather than falsely claiming permissions or local space issues.
  - In `SftpTransferListItem`, tasks paused due to disconnection (`SSH_DISCONNECTED` or `SFTP_DOWNLOAD_DISCONNECTED`) display `transferStatusWaitingConnection` ("Waiting for connection" / "等待连接"), while preserving "Paused" for user-paused transfers.

### D. Standalone OAuth Browser Callback Presentation
- **File**: `lib/features/agents/oauth_callback_page.dart`
  - Pure function `String acpOAuthCallbackPage({required bool success})` returning self-contained HTML.
  - Zero interpolation of URL, code, state, or error (security compliant).
  - Bilingual (English & Chinese) with automatic light/dark theme styling.
  - Success page links `valhalla://oauth-return` and attempts automatic redirection.
- **File**: `lib/main.dart`
  - Injected `acpOAuthPageRendererProvider.overrideWithValue(acpOAuthCallbackPage)` in `ProviderScope` overrides.

### E. Loopback Listener Failure Guard
- **File**: `lib/features/chat/ai_chat_view.dart`
  - Mapped `ACP_AUTH_CALLBACK_LISTENER_FAILED` to `context.l10n.chatAuthCallbackListenerFailed`.
  - Guarded `claimAuthBrowserLaunch`, `_launchAuthUrl`, and manual reopen button with `cur.authError != null` so the browser is never launched when the loopback listener fails to bind.

### F. Localizations & Typed Getters
- **Files**:
  - `lib/l10n/app_en.arb`
  - `lib/l10n/app_zh.arb`
  - `lib/l10n/app_localizations.dart`
  - `lib/l10n/app_localizations_en.dart`
  - `lib/l10n/app_localizations_zh.dart`
  - Added typed getters for all 9 new entries: `sftpDownloadDisconnected`, `sftpDownloadPermissionDenied`, `sftpDownloadNotFound`, `sftpDownloadTimeout`, `sftpDownloadLocalSpace`, `sftpDownloadLocalIo`, `sftpDownloadIncomplete`, `transferStatusWaitingConnection`, `chatAuthCallbackListenerFailed`.

---

## 2. Zero-Execution Verification
- No `flutter test`, `flutter analyze`, `dart format`, `flutter gen-l10n`, `flutter build`, or `adb` commands were executed.
- All existing dirty changes across the repository were preserved.
