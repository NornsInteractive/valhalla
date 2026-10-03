# Root review of in-progress UI

AgY fix before FINAL READY, no test/gen/format/build/ADB execution:

1. New dynamic-l10n getters + Chinese/English hardcoded try/catch fallbacks are
   not allowed (engineering rules zero hardcoded UI strings) and add hundreds
   of lines. Use direct typed context.l10n getters; write ARB only. OpenCode will
   gen-l10n after you exit; temporarily unresolved getters are expected, do not
   avoid them with dynamic. Preserve older helpers not introduced in this task.
2. `_handleAcpLogin` MUST NEVER auto-select a different server. If current
   server differs, abort with localized target-changed notice. After awaits
   check server/profile before presenting. Popping management simply returns to
   Settings/Dashboard in common path, so login card invisible. Present current
   AiChatView using existing project's navigation/modal pattern, or route/select
   shell ACP tab with an explicit minimal callback; no new navigation architecture.
   Never create session/send on this action; initialize-only selection/discovery.
3. Manual callback dialog controller dispose in finally, clear sensitive text,
   keep scrollable at 320dp/2x text/keyboard. Capture request/server/agent when
   dialog opens; if it changed, abort, don't submit a stale URL to next attempt.
4. Auto-open postframe callback must recheck same authRequest, server/agent,
   isAuthenticating and mounted. Cancel/switch before frame must not open old URL.
   Clear local launch error when authRequest clears/replaced. Reopen/copy/manual
   callback buttons should validate current request as well.
5. Prefer advertised oauth-personal for fresh selection when available (only
   if no existing selected choice); don't invent missing method.
6. Map AGY_AUTH_CHECK_UNAVAILABLE / AGY_AUTH_CHECK_INVALID locally, not raw code.
7. Existing `_handleProceedAuth` await respondAuth may show "retry" on failure
   or cancel. For official AgY show success hint only after challenge cleared,
   no authError and correct current target. Never automatic resend.
8. Manual callback input only accepts a full matching loopback URL. Do not hint
   "URL / code" or raw authorization code: raw codes intentionally cannot prove
   state/port/attempt. Use callback URL only in both ARB languages.
9. Root adds `AiChatState.authenticationConfirmed` runtime flag, actual matching
   ACP RPC success only; reset on required-auth/cancel/adapter reset. The old
   unsent turn stays awaitingAuthentication until user explicitly retries.
   When flag true + no active auth challenge: show existing agentAuthRetryHint
   instead of "awaiting ACP auth" badge; hide discovery-login card (otherwise
   success immediately renders a new login card). No persistent login assumption.
10. MainShell retains AiChatView in IndexedStack. Opening another AiChatView from
    management creates two listeners; avoid duplicate auto browser tabs. Root adds
    `claimAuthBrowserLaunch(AcpOAuthRequest)` synchronous shared claim. In guarded
    postframe callback call it before auto `_launchAuthUrl`; manual reopen does not
    claim. Only one retained/modal view can auto-open each live request.
11. Add `isAuthenticating` to existing input isBusy, run-settings strip busy and
    `_openRunSettings` guards so UI doesn't offer actions provider silently rejects.
    Management must recheck server + selected agent immediately after switchAgent
    await, BEFORE requestAuthentication, not just after that RPC.

## Last-mile source defect (after handoff)

The completion snackbar ref.listen condition near ai_chat_view.dart:755 checks
previous.isAuthenticating/cleared challenge/no authError but NOT
next.authenticationConfirmed. Cancellation also satisfies those conditions.
AgY single surgical change: add `next.authenticationConfirmed` guard to that
success snackbar condition only, update status; no layout/ARB/tests/gen/format.
OpenCode include cancel -> no completion snackbar regression. Tests may proceed
but hold final product format/analyze/build until this followup exited.

Followup source guard confirmed, status updated; original AgY console /exit
returned 0. UI stable again; OpenCode can finish final gates/build/ADB.

Write changed files and caveats into UI status report, wait for root /exit.
