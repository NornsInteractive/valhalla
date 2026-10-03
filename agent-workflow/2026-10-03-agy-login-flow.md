# AgY CLI / ACP login investigation and fix

User: CLI is logged in; Agent management has no login-check command; sending
ACP still asks to log in. User now authorizes existing ADB server `racknerd`,
already configured/connected, as target for device investigation and validation.

Ownership: root business/infrastructure/docs only. UI and ARB exclusively original
AgY Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b, gemini-3.8-flash-high / high.
All tests/format/gen/analyze/build/APK/ADB by OpenCode main and small
opencode/mimo-v2.6-flash-free. Preserve dirty tree, app data and existing sessions.

## Initial device evidence task (read-only)

OpenCode use existing 127.0.0.1:14251 device, connect once if needed. Inspect app
on `racknerd`: server identity, agent management AgY configuration (CLI, ACP,
login check/login commands, host vs Docker, execution user), detection log and
current ACP auth challenge. Screenshots/UI hierarchy okay; redact account/token
and private host details in report. Do not expose credentials, application raw
databases or shell environment values. Refresh Agent check is allowed, no install,
sign-in/out, existing session deletion/modification or inference until root
identifies exact target. Never touch current running Codex conversations.
No builds yet; root is investigating product changes. Save evidence to
agent-workflow/2026-10-03-agy-login-device.md and return findings.

## Confirmed source evidence

Official downloaded 1.2.1 archive (temporary only, not installed or executed):
https://dl.google.com/agy-extensions/releases/linux/agy-acp-server-1.2.1-linux-x86_64.zip
Extracted ACP source: /tmp/valhalla-agy-auth-source.dU074x/source/google3/cloud/developer_experience/antigravity_extensions/acp_server/
ccpa_connection/oauth_manager.py explicitly chooses keychain account
`antigravity-acp`, distinct from CLI account `antigravity`; its token file is
GEMINI_HOME/antigravity-acp/acp_token.json (default ~/.gemini). Do not copy tokens.
server.py authenticate immediately acquires/refreshes official OAuth, persists
auth.type; without selection/settings it returns auth_required. OAuth prints
the authorization URL on stderr and binds 127.0.0.1 random port in the execution
environment. App currently records method but delays RPC to next send, and
buffers stderr solely into diagnostics: no remote browser/callback path.
Do not invent agy auth status or count CLI executable/model listing as ACP auth.

## Implementation contract — UI handoff

Root has implemented (not yet verified):

- `AiChatState.authRequest` (AcpOAuthRequest, official validated Google HTTPS
  authorizationUrl, target loopback redirectUri/state), `isAuthenticating`,
  `authError`; runtime only, no credentials persisted on phone.
- `respondAuth(methodId)` now immediately calls official AgY authenticate RPC,
  without waiting for another send. `respondAuth(null)` cancels auth safely.
- `requestAuthentication()` initialize-only discovery, no session/new/load/prompt;
  can restore a missing auth card after navigation / provide an explicit ACP
  sign-in action. Advertised methods only, do not fabricate personal Google OAuth.
- `submitAuthCallback(String)` validates URI/port/state and forwards via SSH stdin
  to original host/container/user loopback. Phone mirrors the official random
  port so browser redirects can finish automatically; manual paste is fallback.
- Success clears card, preserves messages/draft, never auto-resends user text.
- Built-in AgY read-only login-check metadata checks ACP settings + credential
  file existence, not token contents/validity. Missing means ACP setup needed;
  saved means NOT yet live verified; custom checks preserved. Agent stays
  selectable when binary-ready so user can complete ACP sign-in.
- `url_launcher: ^6.3.2` added (6.3.3 requires newer Dart); OpenCode resolves. Use official
  `launchUrl(url, mode: LaunchMode.externalApplication)`; direct launch + fallback,
  no handwritten platform channels/canLaunch precheck. Google requires browser,
  not embedded webview. Do not put auth URL/code/state into logs/snackbars/report.

AgY scope ONLY lib/features UI and ARB; do NOT run tests/format/analyze/build/ADB.
Implement minimal changes in ACP auth card: busy/progress, disabled repeated
login/method picker, cancel, auto-open once when NEW validated authRequest arrives
from this user-initiated attempt (including automatic authenticate after their
explicit previous choice), reopen browser + copy link fallback, masked callback
input dialog with submit/cancel. Handle launch false/errors with local generic
localized message, no URL logging. Inline authError only, no duplicate top error.
Explain CLI/ACP separate; actual advertised method names kept. Preserve existing
non-AgY flow. Ensure card remains accessible after navigating away/back even if
assistant is awaiting auth but provider challenge temporarily absent: explicit
retry/discover (`requestAuthentication`) instead of dead waiting chip.
Management distinguish "CLI login" from "ACP login" for official AgY; add ACP
action opening/selecting current agent chat then requestAuthentication, avoiding
auth on a different selected server. Display missing vs saved/unverified check
details without claiming current live login. Keep card narrow/large text safe.
Write READY / changed files / caveats to
agent-workflow/2026-10-03-agy-login-ui-status.md, then wait and /exit when told.

## OpenCode verification contract

Model main/small opencode/mimo-v2.6-flash-free; keep existing session. Test files
owned by OpenCode only. Add focused regression tests: immediate authenticate RPC
without session/new/load/prompt; method validation/cancel/retry/target change;
transport stderr fragmented line -> raw validated request + sanitized diagnostics;
OAuth URL/callback allowlist, matching port/path/state, duplicate query rejection,
secret never in command/log, host and Docker same-user callback routing; loopback
cleanup; built-in readiness missing/saved/unavailable, migration after existing
backfill-complete + custom command preserved; auth card opens browser once, launch
fallback/manual callback, no duplicate error, phone small viewport.
No real inference/history mutations or credentials login on this Codex runtime.
Python filesystem fixtures use an isolated `GEMINI_HOME` only, never overwrite
HOME/CODEX_HOME or read actual credentials; dummy files need only exist.
Report source defects to root/AgY instead of editing product lib/ARB.
Do not full build until UI READY and AgY cleanly exited. Then gen-l10n, format,
analyze zero, affected tests, full suite, release APK. Retain prior APK, record
mtime UTC/size/hash/cert. ADB install -r only existing 127.0.0.1:14251, keep app
data, stop on signature mismatch. On racknerd inspect refreshed AgY auth log;
explicit ACP login via init-only entry/card is permitted to prove browser opens
Google authorize. Never enter credentials/complete authorization on user's
behalf, never post a message to existing conversations. Do not publish OAuth
URLs/state/codes or screenshots containing them. Record browser launch verified
separately from actual user account completion (pending user).

## Root phase-1 review / remaining acceptance

66 focused cases pass; dependency resolves at url_launcher 6.3.2. Four provider
multiline if infos reported by OpenCode have now been braced by root; recheck.
New `authenticationConfirmed` is live runtime evidence only, reset on new adapter,
cancel/reset/auth_required. `claimAuthBrowserLaunch(request)` global synchronous
claim prevents two retained/modal views from opening two tabs; manual reopen is
independent. Test these plus loopback bind/valid callback/invalid callback/close,
and UI launch once/fallback/cancel/auth retry hint. Callback HTTP response is
deliberately empty, no secret or extra browser UI from infrastructure; browser
instructions belong to AgY ARB. Test full mixed code+error/duplicate callback keys
as well as individual duplication. In Python fixtures don't repurpose HOME:
use GEMINI_HOME pointing to dummy isolated fixture only. Replace current test
HOME overrides with GEMINI_HOME fixtures, retain legacy-default path proof by
source inspection or injected fake Path semantics, not real credentials.
When device browser launch is verified leave Google authorization to user. You
may return to app and explicitly cancel the test auth attempt to clean up only
that pending login (not any chat/session). Do not alter account/browser data.

## Root handoff checkpoint

AgY original ec81a4be... / gemini-3.8-flash-high / high FINAL READY all 11 review
items; console `/exit` returned 0. UI is now stable for OpenCode gen-l10n and
full gates. Root inspected source and gate report; no tests executed by root.
UI report says no git commands, but console did perform read-only git diff/status
inspection; no git mutation and no product tests/builds by AgY were observed.
OpenCode phase1 report used shell append for late report sections and temporary
child HOME fixtures despite intended Edit/GEMINI_HOME constraints; no real
credential reads/changes. Phase2 explicitly corrects tests and uses proper edits.
Do not describe these exceptions as full command compliance.

Phase2 analyzer caught 7 source issues: root converts switchAgent to Future<void>
and awaits local history settle (fixes both await-void and auth-init/session
selection race). Six UI/ARB issues are being corrected by original AgY per
2026-10-03-agy-login-ui-gate-fixes.md. Hold final gates/build until it exits;
continue authoring tests. No UI edits by OpenCode/root.

UI gate fixes now confirmed in source; original AgY console /exit returned 0.
All final gates can proceed. Repeat gen-l10n after restored EN legacy key.

Root read-only fulltest.log review: first two full-suite failures are stale
expectations: agent_repository_test.dart:53 profile equality now must include
default loginCheckCommand; auth_challenge_ui_test.dart:547 expects immediate
"After logging in..." after method selection with no actual authentication
confirmation. Update fixture to simulate isAuthenticating then actual confirmed
success and assert hint only afterwards, none on selection/cancel. Do not weaken
success checks or change product semantics to satisfy stale fixture.

## Installed checkpoint / last-mile continuation

OpenCode phase2 finished exit0: full analyze zero, 1795 pass / 18 skip / 0 fail,
release build and install-r successful. APK 123736478 bytes / 05:40:52Z,
SHA256 3e748162ab1dc2a29649073d581d73b91d529f6e614251dc078bb64f304b424a.
racknerd explicit Google login moved foreground to Chrome at official auth
endpoint; user consent not entered. Returning preserved chat; cancel restored
request-auth action without send/new/history mutations. Separate SSH closed
unhandled diagnostic observed before this auth action remains unlocated.

Phase2 left planned widget fallback/manual/small-screen proofs unwritten. Root
requested last-mile tests-only contract 2026-10-03-agy-login-last-mile.md. Runner
34562 was interrupted SIGINT exit130 before tests/edits to clarify the direct
test dependency and stop repeated plugin exploration; not a failing test gate.
Continued SAME OpenCode session with main/small MiMo free, not a duplicate runner.
Root declared already-resolved url_launcher_platform_interface 2.3.2 as direct
dev_dependency for a standard platform fake; runtime sources/package versions
remain unchanged. Final validation/report corrections pending this continuation.

## Final installed checkpoint (supersedes pending checkpoints above)

Original AgY returned FINAL READY and exited 0 after three UI repairs: callback
controller disposal awaits DialogRoute.completed; draft auth card is scroll-bounded;
composer directory row has outer and inner flex constraints for 320dp / 2x text.
The 53px overflow was a real reproduced defect fixed by AgY, not a transient cured
by formatting. OpenCode owns all new test changes and execution; no root UI edits.

Final OpenCode main/small model remained opencode/mimo-v2.6-flash-free. Eight strict
browser/manual/cancel/confirmed-success/narrow-screen widget cases passed, with
three consecutive focused repeats. Four older taps needed ensureVisible under the
new scroll constraint; their behavior assertions were retained. Full suite 1803
pass / 18 skip / 0 fail; analyze zero issues; gen-l10n and explicitly authorized
format paths pass. Temporary isolated PROBE removed, diagnostic evidence retained.

Release APK: 123736478 bytes, mtime 2026-10-03T06:44:39Z (14:44:39 +0800),
SHA256 6ff2244ea5cf00db417c3b956b5aa7f2d5332610f1da5bc7315c40e8aa13035e.
The 13:40 stage package is retained as app-release.apk.bak-20261003-144316;
its hash differs despite matching byte size. Release build still uses Android
Debug signing, identical to the installed package; not a store-signed release.
ADB install-r succeeded; installed base.apk re-pull matches the new hash;
lastUpdateTime 2026-10-03 14:45:52 +0800. Startup succeeded, MainActivity foreground,
process alive; bounded 45s log capture had no observed Android fatal or ANR.

Browser opening on racknerd was verified on the 13:40 stage package; final package
received install/startup checks only, no new account/OAuth/remote actions. Google
consent, real authorization callback/token exchange, actual inference and Docker
device end-to-end auth remain unverified/pending user. The earlier SSH close
dart.unhandled finding has no established underlying cause and is not fixed by
this login task. No git commit/push, uninstall, app-data clear or history changes.

See 2026-10-03-agy-login-verification.md sections 19–20 and device evidence section
13 for measured gates and disclosed OpenCode file-edit method exceptions.
