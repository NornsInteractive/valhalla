# Remote merge, AgY authentication and install confirmation

Root fetched origin using the existing environment credential without printing
it. HEAD fast-forwarded from 7a4c203 to de37ed6. Preserved ALL prior dirty changes
in stash `valhalla-before-origin-update-20261003`; applied without dropping backup.
No textual conflicts. Auto-merged terminal_provider, dashboard_view, and two
lifecycle tests. Preserve remote mosh locale negotiation, zombie SSH cleanup,
terminal font settings and neofetch sheet alongside local reconnect/cache fixes.
No commit or push requested.

## Ownership and safety

Root owns business/state/repository/docs only. ALL UI owned by AgY original
Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b, CLI model
gemini-3.8-flash-high / effort high. Start console with that conversation only;
never --prompt-interactive or create another conversation. No sandbox flag.
OpenCode owns tests, format/gen-l10n/analyze/build and ADB; main/small model both
opencode/mimo-v2.6-flash-free. No real Codex inference, credential reads/copies,
logout/login/account changes or remote installs. No git mutations by workers.

## Evidence / bounded UI task (AgY)

AgentCommandConfirmDialog currently displays the full multi-kilobyte official
ACP installer as SelectableText inside an unscrollable Column with only maxWidth.
Small phones/large font therefore overflow and hide confirmation actions.
Fix lib/features/agents/agent_command_confirm_dialog.dart using bounded vertical
space and scrolling command/content; keep risk warning, target, selectable full
command and reachable Cancel/Execute; long tokens and large text must not overflow.
Do not truncate security-relevant command or weaken explicit confirmation.

Also audit agent-management official ACP auth label/action routing: no CLI login
success may claim ACP authenticated; unknown is not unauthenticated. Official
auth challenge belongs in ACP chat through advertised methods, not a CLI login
button. Preserve non-ACP CLI login and custom agent behavior. Clarify separate
CLI vs ACP status using l10n if required. UI whitelist: agent_command_confirm_dialog,
agent_management_view, ai_chat_view auth surface only, ARB if required; NO logic,
tests/generated/build. Review auto-merged dashboard UI retaining remote neofetch
and local cached metric fallback; only fix actual merge breakage, no redesign.
Report exact edits and READY at agent-workflow/2026-10-03-agy-ui-status.md.

UI READY report reviewed by root: popup bounded/scrolling + copy preserves command;
unconditional isAgy removed, genuine ACP challenge preserved, remote neofetch
uses same-server cached telemetry. Original AgY console exited; final UI gate open.
Root's invalid null-aware lint findings in the new auth guard are now fixed.
OpenCode may add minimal auth/popup regressions, run final gates and build/ADB.

## Root investigation in progress

Builtin AgY has no loginCheckCommand. No configured check currently means
ready/auth unknown, NOT unauthenticated. User's visible error location/log has
been requested; do not invent a successful auth detection. CLI has no `auth
status` subcommand in current --help. Official server declares ACP methods and
authRequired only comes from the actual -32000 response. Need separate CLI vs
ACP truth; do not copy credentials or auto-authenticate during installation.
User confirms BOTH management and chat show login prompts. Root found a second
concrete mechanism: after a prior -32000, external login followed by successful
session setup left state.authChallenge intact, and later save/context sync was
skipped merely because that stale challenge remained. Root now exposes adapter
authenticationConfirmed using its existing authenticated flag: true only after
actual authenticate RPC or successful session establish, reset on authRequired;
initialize/installation alone remain false. Matching active-agent/server control
updates clear ONLY the stale auth challenge / ACP_AUTH_REQUIRED error after that
positive confirmation. No prompt/new/login during detection, no fake CLI-auth.
OpenCode add mocked external-login/retry success clears card/error without message
duplication; initialize-only keeps challenge; revoked-auth resets confirmation;
unrelated settings/errors/target cannot clear auth. Actual user's token sharing
or remaining -32000 still needs remote logs; do not claim fully solved yet.
Existing remote-session retry also needs positive prompt completion: adapter now
confirms auth on successful prompt RPC result (not timeout/error), and provider
clears matching stale challenge on ACPCompleteEvent too. This covers external
login without replacing an existing remote session. No automatic retry is added.
User clarified host-side chat silently says interrupted, no actual error text.
Root found auth-required event marks assistant INTERRUPTED (false user-cancel).
New ChatTurnStatus.awaitingAuthentication separates actual ACP -32000 from user
stop; persisted optional enum parses alongside old records, no rewrite of old
ambiguous history. Both host/Docker use this shared provider path. Actual remote
cause is still unverified; this is the confirmed code path, not proof of logout.

### Additional AgY UI gate (reopened for auth visibility)

Show awaitingAuthentication as waiting for ACP authentication, NEVER user-stop.
Move/reuse the real auth challenge card near the last pending assistant turn so
auto-scroll doesn't bury it above long conversation; keep a single challenge,
and retain draft/no-messages authentication surface. Actual advertised methods
and explicit Proceed/Cancel must remain usable; real challenge never hidden or
converted into fake CLI login. New en/zh labels via ARB, no root UI edits. Original
Valhalla / same High only. Final tests/build must wait for this additional UI READY.
OpenCode must cover -32000->awaitingAuthentication not interrupted, no automatic
prompt retry/session replacement/login; successful explicit retry clears old card,
failure continues visible; host/Docker target isolation. Old status round-trip.
Auth retry reuses the prior placeholder but now resets its status to streaming;
successful completion becomes completed rather than retaining the old auth/stop
label. Preserve exactly one user message and assistant placeholder, no automatic
resend. Add assertion for final completed status as well as content and counts.
Official registry now lists 1.3.0 (previous pinned installer 1.2.1); update only
with verified distribution layout and backwards-safe custom config preservation.

## OpenCode validation

Logic checks may run while UI is active; no full/build until UI READY/exit.
Review merged terminal/lifecycle state, retain new remote security/locale cases
and local pause/probe semantics. Run mocked mosh/bootstrap/terminal zombie/rebind,
agent authentication/installer tests; no actual remote mosh e2e default override.
Add popup tests narrow screens/large text/long script when UI is ready.
Then final format/l10n/analyze/full, backup prior APK before release. All green ->
build exact metadata/cert/hash/time -> adb install -r only on available existing
device, no uninstall/clear. No new emulator without user direction. If unavailable
report exact blocker. Report agent-workflow/2026-10-03-merge-agy-verification.md.

## Final UI gate opened (2026-10-03)

AgY original Valhalla reports FINAL READY including authentication visibility,
single challenge near pending assistant, narrow-screen wrapping/copy/scroll.
Root reviewed the source and requested console exit before verification.
OpenCode may now run final UI regressions, format, l10n, analyze, full tests,
release APK backup/build/metadata and existing-device ADB checks. Cover the new
awaitingAuthentication JSON round-trip and successful retry completed status.
Use only opencode/mimo-v2.6-flash-free for main and small model. Any functional
failure must be reported; do not weaken assertions, suppress exceptions or
change product/UI code. No real remote inference/credentials/mosh e2e required.

### Gate temporarily blocked: AgY compile fix

OpenCode analyzer found 3 UI errors: ai_chat_view.dart:724 undefined `prev`
(listener variable is `previous`), :2002 nullable shadowed `state` passed to
_isAuthChallengeTargetMessage, :2005 nullable `state.authChallenge`. Root restarted
original AgY to repair ONLY these and rerun readiness handoff. No builds while
errors remain. OpenCode may finish test edits but must not edit UI to resolve.

### Compile gate reopened

AgY fixed previous/currentState references and reported FINAL READY; root exited
the console again. Source is now stable. OpenCode may proceed, with a fresh final
analyze/full test run after these source changes (do not use piped exit 0 as
evidence without pipefail). No UI edits by root/OpenCode.

### Installer overflow gate blocked

OpenCode 320dp/2x-font actual installer test finds RenderFlex overflow 198px.
Source target server label Row has unconstrained label Text plus Expanded info.
AgY original conversation restarted for a narrow fix; stop build until final
READY/exit again. Keep actual clipboard/action and no-overflow assertions.

### Installer gate reopened

AgY replaced the overflowing server-info Row with a wrapping Column, FINAL
READY and root console exit. OpenCode actual 320dp/2x-font test now passes (26
agent-management/widget cases). UI source is stable; final all gates proceed.

### Full-suite harness maintenance authorized

Full suite found missing terminalSettingsProvider fixture injection in
cli_chat_settings_button_test.dart, cli_chat_view_test.dart,
interactive_login_dialog_test.dart, interactive_login_test.dart. These now mount
SharedTerminalCanvas, which intentionally watches persisted font settings.
OpenCode is authorized to fix ONLY these test fixtures with the existing
test/support/fixed_terminal_settings.dart default notifier override (or actual
mock localStorage injection where persistence is the test subject), preserving
all assertions. No production fallback, exception swallowing or skipped tests.
Rerun affected files then final analyze/full. Build only after full passes.

## Final result

OpenCode verified affected 65 cases and full 1713 passed / 18 skipped / 0 failed;
format/l10n/analyze all passed. Release built successfully, bytes 123419671,
UTC mtime 2026-10-03T03:30:19Z, SHA256
23cc6e9175643e5c4b17e6c9fc1e9bb9fec8990566f6556f505d103ceef594a8.
Old APK recoverably backed up. Existing 127.0.0.1:14251 device reconnected,
install -r Success / exit0 and startup alive/frontmost with no observed crash/ANR
in bounded check. Android Debug signing retained. Real user's host/Docker ACP
auth/conversation and mosh e2e remain unverified. HEAD de37ed6, dirty edits and
premerge stash preserved; no commits or pushes. See verification report §16–21.
