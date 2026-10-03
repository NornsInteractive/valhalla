# Official Antigravity ACP, ordered output and stable reconnect

User approved official ACP and event-order interleaving. Preserve existing dirty
Antigravity template/repository/launcher/auth UI/test changes; no rollback/reset.
Root owns business/state/data/infrastructure. AgY owns ALL UI and ARB changes.
OpenCode owns tests, mechanical format, gen-l10n, analyze, builds and ADB.

## Root contract (implemented)

- Add optional ChatMessage.contentBlocks: ChatContentBlockType.text/tool,
  ChatContentBlock.text(start,end) references UTF-16 offsets in message.content;
  ChatContentBlock.tool(toolId) references message.toolExecutions. No duplicated
  stored text. `orderedContentBlocks` gives validated new ordering or legacy
  tools-then-text fallback. New text adjacent to text coalesces; tool first-seen
  anchors once; status updates never reorder. Preserve old JSON/history.
- ChatTurnStatus.unknown means transport lost, NOT user cancellation. Only actual
  cancellation is interrupted. Keep content/drafts/history when connection changes.
- Agent statuses retained offline; remote operations must still check connection.
- Docker/system state depends only on server connectionKey; reconnect refreshes
  quietly without blanking lists/filter/selection. Failed refresh retains data.
- Dashboard uses last good per-target data during offline/reconnect, then replaces
  on success. No stale target results. SFTP preserves path/filter/editor/list.
- Recovery coalesced; no ordinary completed-thread replay on every disconnect.
  Needed recovery retains one replay adapter, ends capture before normal chat,
  does not start another ACP process/load same history twice. No resend/new/cancel.
- No remote resident service, real prompts/login/token reads/history edits/install
  on current Codex/AgY agent. Independent mocked protocol proves behavior; real
  target verification only with separately authorized test target.

## AgY task — original Valhalla ONLY

Conversation ec81a4be-7543-45ee-8658-f68966f57d3b;
Gemini3.8Flash/high, CLI model gemini-3.8-flash-high / effort high.
Use interactive console; NEVER --prompt-interactive. Preserve existing changes.

UI whitelist: ai_chat_view.dart, cli_chat_view.dart, main_shell.dart,
dashboard_view.dart, docker_view.dart, system_view.dart, sftp_file_view.dart,
agent_management_view.dart, widgets/session_recovery_banner.dart,
shell/widgets/connection_status_banner.dart,
app_en.arb/app_zh.arb, and this task's UI status report only.
Do NOT edit providers/models/infrastructure/tests/generated files; no tests,
formatter, gen-l10n, builds, ADB or git. No scope beyond approved four issues.

1. Render assistant text and tool cards in msg.orderedContentBlocks order;
   substring text block start/end, resolve tool ID. Stable keys per message/block
   and tool. Preserve thinking/plan/attachments/copy/selectable Markdown/errors;
   status update must not jump tool above previously visible text or autoscroll
   when user is reading older messages. No guessing old-record chronology.
2. Only shell TOP BAR reports reconnect/offline/sync/incomplete/failed, with
   tappable details + recovery retry. Remove inline recovery/context restart/
   connection warnings for transient connection state from ACP and CLI view.
   Actual conversation/tool/auth errors still belong in their respective UI.
3. ALL views keep current content during reconnect/offline, not full-screen
   OfflineStateView/empty/loading replacement. Disable remote-execution buttons
   when disconnected; editing/copy/browsing already cached local data stays usable.
   Initial no-server state may retain existing empty UI. Do not expose stale data
   across a real server switch. Keep connection status only at shell top, except
   explicit operation errors and requested diagnostics/details.
4. Preserve current official Antigravity auth UI fix: official ACP authentication
   must not run CLI login. Show only advertised ACP features, no fake models.

Report READY only after inspecting all whitelist call sites and diffs, list exact
files and preserved dirty changes in agent-workflow/2026-10-02-acp-reconnect-ui-status.md.
Root API may not exist yet: wait for contentBlocks contract above; do not implement
business API in UI. Exit original conversation after READY.

Root API now exists. For Dashboard current metric fallback use
`metricsAsync.asData?.value ?? ref.watch(systemMetricsHistoryProvider).lastOrNull`
while same server reconnects; history is already scoped to connectionKey.
Hardware/disk/process providers now retain last successful per-target data.

## Root business READY for logic verification (2026-10-02)

Source changes now available: blocks recorded in live and replay paths; late tool
updates remain in original owner; successful replay adapter retained; capture ends
before normal chat; failed/incomplete automatic attempts not re-run just by resumed.
History snapshot of unknown/streaming turn retains unknown status (not proof of
remote completion), recovery marks incomplete and allows explicit retry. Old
interrupted messages remain compatible. Actual user cancellation stays interrupted.
Completed idle threads do not replay on each disconnect; next Send restores lazily.
Paused stops retry timer; foreground verifies existing SSH first, only then allows
retry. Disconnected cached agent status stays intact; operations still guard live
connection. Docker/system quiet refresh and stale result guards are present.
SFTP/data/terminal preserve same-endpoint state; true target switch still clears.
Official Antigravity only shows model choices from actual declared ACP config;
no discovery session is created. Codex independent model/list unchanged.

OpenCode may compile-check logic and add/run focused regressions now. Respect
AgY UI ownership; no full/build/ADB until UI READY and AgY exited. If compile errors
are test overrides changed by new named quiet parameter, update override signatures
narrowly, preserving assertions. Business defects -> report root; UI defects -> AgY.

## OpenCode verification contract

Main/small opencode/mimo-v2.6-flash-free; no paid substitution. Write tests via
Edit/apply_patch only. Reuse harnesses. Initial logic tests while UI underway,
then final UI/full gates only after UI READY and AgY exits. Tests cover ordering,
status anchoring, JSON compatibility/replay dedupe, actual loss vs healthy paused,
single recovery adapter/load, no prompt/new/cancel/replay approvals, immutable
target guards, retained Docker/system/SFTP/metrics/agent state, stale async results.
Review existing dirty Antigravity mocked install tests; no actual remote install.
Do not weaken unrelated assertions, skip tests or call real Codex inference.

All GREEN -> recoverable old APK backup -> fresh release -> actual hash/size/mtime/
signing -> adb install -r existing 127.0.0.1:14251 (no uninstall/clear) -> finite
startup crash/ANR check. Log exact command exits/counts in verification report.
No git commit/push this task. Stop at verified install or report exact blocker.

### Verification clarifications

Completed idle thread fixtures must now assert idle/no replay. Keep actual failure
coverage by seeding unknown/streaming turns, not deleting failure/retry/id/content
assertions. Unknown snapshot stays unknown: history alone cannot prove completion.
Paused/detached retain foreground service and connection intent, but postpone retry
until foreground verification. Test harnesses must override required providers;
do not add UI catches that swallow provider initialization failures to pass tests.
Root fixed the misplaced dart:async import in system_provider.dart and the
ai_chat_provider curly-braces lint. UI compile issues belong to AgY.
Automatic recovery while idle only considers unknown/streaming, never an actual
user-cancelled interrupted turn. Explicit retry still supports old interrupted
records. Include cancellation followed by paused/resumed with no replay regression.
Root review: newly added lifecycle counter assertions must be exact/runnable,
not tautologies such as attempts >= 0. Use the existing scheduler seam to assert
no attempts during pause and exactly one after failed foreground verification.
Successful replay now retains the adapter: expect no extra resume/process after
load; unsupported replay must likewise use the retained initialized transport.

## Final UI gate opened by root

AgY reported FINAL UI READY in the original Valhalla / specified High model and
exited its console with exit 0 after root review. No UI writer is active. OpenCode
may now maintain UI test harnesses, mechanically format changed Dart files,
generate localization, analyze and run the full suite. Update obsolete recovery
widget tests to assert no inline banners AND cover the global top surface (null
controller with ACP failed/sync/incomplete, context-loss acknowledgement, retry).
Retain copy/selection/attachments/approval safety and actual text/tool/text order
checks. Product changes still require root (business) or original AgY (UI).
Record actual Flutter command exit status, not a successful tail/tee pipeline;
set pipefail or save PIPESTATUS before another command. Do not build/ADB until
all final checks pass; retain prior APK and user app data. Real ACP remains untested.
AgY's self-report says no git commands; console evidence actually includes
read-only git status/grep/diff/log inspections, not git mutations. No commit,
push, reset or revert was performed. Treat its READY as source review, not tests.

### Final verification editing correction

Root observed OpenCode using a Python writer to replace a recovery test group,
despite the edit-tool requirement. The narrow test changes are preserved for
review; this is not product/UI editing. Root stopped that inference turn (exit
130, not a Flutter test result). Subsequent hand-authored test/report edits MUST
use Edit/apply_patch; no Python/sed/perl/cat shell file writes. Standard Dart
format/gen-l10n remain allowed mechanical generators. Complete the remaining two
CLI test fixtures and final gates without repeating whole-repository discovery.

Root addressed the eight production curly-braces lint findings after the first
final analyze (ai_chat_provider, chat_session, dashboard_provider, system_provider),
without behavior/UI changes. OpenCode owns removal of its unused test import,
then rerun format/analyze/full on this updated source before release/ADB.

## Delivery checkpoint

AgY UI is finished and exited. OpenCode MiMo free reports final full tests
1664 passed / 17 existing skips / 0 failed, analyze zero issues, gen-l10n and
release build exit 0. Final format-only recheck after root brace edits is clean;
the untracked Antigravity install test is included. No product edits after build.
APK: 123304935 bytes, UTC mtime 2026-10-02T10:55:18Z, SHA-256
6dfed53b4e8f14241a9c200e2c841c54aadc5a56f3b81b8e43c7ea8f1b3dd4b9.
Release still uses the existing Android Debug certificate / version 1.0.0+1.

ADB install/startup is NOT complete: original 127.0.0.1:14251 refuses connection,
device list empty, get-state exit 1. No uninstall or data clear. Await restored
device or user-provided address; let OpenCode do the signature-safe install -r
and finite startup/crash/ANR verification. Do not start a replacement emulator,
push/commit, or claim real remote ACP compatibility without additional evidence.
