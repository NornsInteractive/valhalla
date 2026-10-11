# 2026-10-11 completion contract

User approved all nine workstreams. Base d1826c5, clean worktree. This is an
implementation task, not authority to publish or run paid cloud builds.

## Ownership and execution

- Codex: core/data/infrastructure/native business bridges and documentation.
  Business-only providers in features/dashboard/dashboard_provider.dart,
  features/docker/docker_provider.dart and features/system/system_provider.dart
  are explicitly Codex-owned this round; AgY owns their UI consumers.
  Vendored xterm core/input encoding is business logic: cursor-key mode must
  follow DECCKM independently from numeric keypad mode (no presentation edits).
- UI, interaction and authored localization: original AgY Valhalla conversation
  ec81a4be-7543-45ee-8658-f68966f57d3b, gemini-3.8-flash-high, effort high only.
- OpenCode: write/run tests, format, generate localizations, analyze, local build,
  verify and data-preserving ADB. Confirmed-free main/small model required;
  authorized fallback opencode/step-5-preview-free, catalog zero prices verified.
  Focused verification may also use opencode/space-bunny-free (main and small),
  zero input/output/cache prices and official Zen free table rechecked this turn;
  the slow exploratory verifier was stopped, not counted as completed evidence.
  Space Bunny later returned Rate limit / RetryError; its pending tasks were
  stopped. MiMo-V2.6-Flash Free main/small restored for bounded follow-up after
  fresh local cost (all zero) and official Zen free-table verification. No paid
  fallback is authorized or used.
  LongCat 2.5 Preview Free (main and small) was subsequently confirmed at zero
  prices and used for the bounded draft/transfer follow-up when those models
  were rate limited. The first run exposed two current-branch transfer failures;
  they remain gate failures until their fixes are rerun, not dismissed as old.
- No live development Agent prompts/history edits, no production mutations for
  tests, no app uninstall/data clear, no shared cache deletion, no release/push.

## Accepted scope

1. Same-target reconnect keeps content/selection/drafts; cold start restores
   bounded cached dashboard/file/container/service data keyed by connection
   identity. Respect startup page settings; stale is not online. Diagnose
   unhandled SSH errors; never replay prompts, approvals or side effects.
2. Mobile dialogs/drawers/navigation/resume never reopen underlying keyboard.
   Only explicit input tap or keyboard button opens it; desktop hardware input
   and terminal long-press selection remain usable.
3. Shared terminal toolbar: pinned/reorderable keys, keyboard/more controls,
   navigation/editing/symbol/function panels, 44dp targets, repeat arrows,
   one-shot/locked Ctrl+Alt, correct xterm encoding, multiline paste confirmation.
   User addendum: switching away/back must preserve each terminal's scrollback
   position; terminals following the tail continue following new output. Cover
   page/tab switches, offstage updates and viewport changes without jumping to
   the top or forcing historical readers to the bottom.
4. ACP: host/container user identity, real auth/model/runtime/stream/approval/
   cancellation/recovery checks; no discovery sessions; bounded history and
   incremental output, inline single errors, explicit retries.
5. File editor: revision conflict detection, same-directory temporary write,
   safe replacement preserving permissions/link semantics, drafts and unsaved
   exit confirmation; unsupported safe replacement must not truncate originals.
   User addendum: shown hidden files use subdued, readable icon/text colors,
   not disabled controls. Persist explicit list/grid selection; keep filtering,
   sorting, selection, symlink navigation and file actions identical.
6. Durable transfer records and explicit resume after restart; source/partial
   validation for range downloads/uploads, temporary upload commit, collision
   policy, truthful notifications and only verified completed-file opening.
7. System services: real startup states, distinguish unsupported/permission/
   failure/empty, bounded logs, action busy and exact target validation; process
   termination rechecks identity. No destructive automatic retry.
8. NAS: retain experimental defaults/protocols; visible thumbnail work priority,
   cancellation/cache control, bounded scan/search, player recovery/audio focus/
   headphones; isolated fixtures and measured performance, no runtime claims
   based on build-only checks.
9. About GitHub entry and updates: 24h background + manual check, optional auto
   toggle, stable Releases API + ETag; update.json for version/build/commit and
   exact platform/arch/name/size/hash (+ Android code/cert). Same-version updates
   require increasing build. Legacy no-manifest compares version only. Stream
   download with .part/hash/cancel/retry/resume; no bundled token. Android
   validate identity/signature then explicit system installer; desktop download
   and reveal/open, Store builds route Store; no unsigned iOS install.

## Checks and rollout

Focused regression proof per workstream, then full tests/analyze. Narrow-screen,
large-font, desktop keyboard and localization checks. Isolated exact-source local
Android build, existing signature-compatible test APK if needed, install -r on
explicit connected device. Existing user Google consent is never automated.
No new database dependency; reuse storage with bounded/versioned records. Docs,
roadmap and current status reflect actual evidence, not historical checkboxes.

## Progress

Terminal scroll retention: six OpenCode regressions passed, including an actual
long A / short B / A tab-switch reproducer. Explicit mobile IME intent is patched
by AgY and under verification. Shared toolbar/paste UI remains in progress.
Remote hidden-file subdued styling and persisted list/grid switching are
implemented by AgY; all 17 authored locales updated. OpenCode file-view suite:
29 passed, including hidden text/icon styling, unchanged action/selection
controls, mobile list/grid toggling and persisted preference failure/rebuild.
Terminal IME and scroll focused suites: 14 passed. Key/model/storage suites:
94 passed. Transport/generator suites: 42 Dart and 27 Python passed. Initial
file/system/NAS suites: 128 passed (overlaps existing suites; do not sum into
a full-suite count). Subsequent integrity/race hardening needs another gate.
Business implementations pending final gates: bounded target-isolated page
caches, encrypted file drafts/revision-safe atomic save, persisted resumable
transfers, truthful service catalogs/busy/logs/PID identity, thumbnail scheduling
and cache APIs, stable GitHub updater/native Android checks/manifest generator.
Updater UI is implemented by AgY, including all 17 authored locales, and awaits
OpenCode generation/widget verification. Editor/services/NAS consumer UI and
terminal/global-input corrections remain pending. No final build, ADB,
real-server acceptance, push or release has been claimed or performed this round.

Post-terminal UI verification found new compile blockers (wrong theme import and
nullable tab reference) and invalid AlertDialog intrinsic/Spacer layout. These
are assigned to the original AgY, not silently fixed by Codex. Desktop IME/key
tests pass independently; scratch-only partial success is not a workspace gate.
See terminal-final-validation and terminal-ui-followup. Nonterminal mobile input
route/lifecycle safeguards have a separate global-input-ui handoff.

AgY's updater run ended with an individual-quota limit (about one hour to reset).
The original Valhalla conversation/model/effort remain mandatory. No substitute
UI author or silent Codex UI edits are permitted; account restoration requested.
Business fixes and confirmed-free OpenCode verification continue independently.

Draft checkpoint recovery: two follow-up tests pass after fixture repair. Latest
transfer follow-up initially reported 70 passed / 2 failed: uncaught integrity
error on reveal (business fix applied) and an invalid completed-download fixture
that precreated the final destination and auto-finished before writing .part
(fixture repair delegated). No all-green claim until exact-source rerun.

Exact-source follow-up command now passes: 102 tests, zero failures across
ai_chat_draft_failure, sftp_transfer_records, sftp_provider and sftp_file_view.
The managed-download fixture now writes only .part before completion and checks
the final file/hash after completion; native reveal failure is covered too.
This supersedes the two failures above, not the remaining UI/full-suite gates.
Immediate update-download pause/resume now waits for the old writer to close;
opening uses the captured validated path/artifact, not later mutable UI state.
Those updater changes are assigned a separate regression gate before acceptance.

Latest OpenCode localization generation exited 0; analyzer snapshot exited 1
with 60 issues, including seven UI compile errors. Three core brace infos were
then fixed without a rerun. See latest-diagnostic for the exact boundaries.
Atomic-editor infrastructure/new updater-provider regression authoring did not
finish; no test file or result is claimed from those stopped attempts. Resume
those gates after original AgY restoration, not by treating the existing model/
HTTP suite as provider proof. There is still no final package or ADB install.

User requested AgY UI execution again: restarted agy CLI on the same original
conversation with --model gemini-3.8-flash-high --effort high. Init and subsequent
agent/tool events confirm the correct conversation/model and successful work
resumption; previous quota is no longer treated as the current blocker. First
bounded phase repairs terminal compilation/dialog layout and file readability,
plus the updater nonexistent Close getter. OpenCode follows with verification.

Additional user requirement: SSH canvas taps no longer request mobile IME;
the existing keyboard control is pinned at the lower-right outside horizontally
scrolling keys, enabled only by the SSH caller. Original AgY implemented this
and all 17 localized keyboard labels/paste metadata. OpenCode source gate passed
generation, six-file formatting and targeted terminal/root-focus analysis (0
issues). OpenCode's actual SSH toolbar suite now passes all 17 cases, including
Android/iOS tap opt-out, explicit keyboard open/close, real 320dp/text-scale-2
geometry and Windows ordinary/CJK/hardware input. AgY repaired the 10 remaining
localized updater labels; regenerated catalogs pass all 9 parity tests and the
six-target terminal/root/test analyzer exits 0 after a style-only local-function
repair; its identity-guard test also passes. The latest recorded joint nine-file gate
reports 131 passes / 1 failure: pinned-key persisted reorder remains unresolved
after two fixture iterations; do not assume it is only a fixture problem. See
`2026-10-11-ssh-keyboard-validation.md`; no new package/device or whole-app
acceptance follows from these bounded checks.
