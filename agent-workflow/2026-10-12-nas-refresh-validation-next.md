# Next validation task

Focused files tests: 2 failures in retryFailedBatch positive cases (lines739/781)
are EMPTY fake directory listings, not product defects. New validation correctly
refuses missing sources. Populate env.ops.files with the remaining failed item
before retry; keep the separate source-missing negative test. Recent5 and apps14
already passed in focused logs. All 3 new test files now under main ownership.

UI routing review queued to AgY: Library/Downloads currently bypasses its shell,
removing subsection navigation; zero-source gate also hides Library's submenu.
After AgY fix (nas-library-routing-review.md), test zero-source Library->Downloads
AND back to another Library subsection, not only top-bar offline access. Offline
image mode also being corrected to avoid remote actions/fallback on local failure.

ROOT REVIEW FIX: NasNotifier.openInApp still eagerly acquired remote adapter before
calling the offline-aware player! Root just moved queue adapter acquisition into
on-demand remote playlist pagination with captured-source guards. Add a focused
PROVIDER-level regression invoking real NasNotifier.openInApp with no usable source
adapter and fake player/repository; fake player must receive open. The player-only
local-path test cannot catch this old bug. Also validate local indexed pagination
does not require adapter. Only remote media-server playlist page fetch should.
Reuse ProviderContainer/test NAS infrastructure; a test NasNotifier subclass may
override build for deterministic state, but MUST inherit real openInApp. A fake
player may record open/loadMore. Do not mock the method whose eager adapter bug is
under test. Test source-change refusal when a deferred remote playlist is loaded.

LIVE UPDATE: AgY Phase C finished all authored UI fixes; no UI writer active now.
Phase D localization/restore retry also finished. Root coordinated a one-shot
OpenCode Big Pickle generation/analyze run during test authoring: both exit0,
post-agy-gen.log and post-agy-analyze.log (No issues found, 4.8s). No test execution
or other edits in that run. Re-run final gates after test edits settle as needed.
Files/apps author also finished, all 3 files standalone-analyzer clean. You now
own their test adjustments/execution. Run generation, analyze, targeted widget
regressions and full suite after focused tests. DO NOT assume author's flagged
environment-change defect is valid: the approved contract explicitly allows
changedSections=['environment'] when a secret changes, but never the secret VALUE.
Correct that new test to assert the category is present and values absent. Likewise
record() intentionally validates synchronously; use throwsFormatException on the
closure rather than assuming a Future. No product fix is needed for that API.

Coordination: NAS UI test author is stopped after authored/static-clean handoff.
Main verifier now owns test/features/nas_media_view_test.dart and
nas_navigation_test.dart too. Run them; don't keep reasoning without execution.
All Flutter execution still belongs to main verifier.

Responsive tests must exercise five destinations -> Library subsections, offline
list with no selected source, source/scan/library dialogs at 320dp/2x/RTL. Preserve
old tests' underlying assertions; adapt intentional navigation changes. If new
UI failures remain, report precise locations, do not edit UI. After all gates pass,
read 2026-10-12-nas-refresh-install.md for authorized local Android build/install.

Coordination update: the two NAS drafts are now REWRITTEN and static-clean by
OpenCode Big Pickle; you may RUN test/core/nas_offline_persistence_test.dart and
test/infrastructure/nas_download_validators_test.dart now. Initial full-suite log
captured the earlier broken draft and is stale for those two files. Existing
nas_playback_download_proxy_test expectation 'failure removes partial' must adapt
to approved durable pause/resume: failure preserves partial, explicit retry/restart
cleans/replaces it; don't change product back to destructive failure cleanup.

A separate OpenCode Big Pickle author now owns remote_file_batch_contract_test.dart,
file_recent_directories_test.dart, application_preflight_health_test.dart (read
2026-10-12-files-apps-test-authoring.md); no execution or product edits there. Wait
for authored status before editing those files. You retain all Flutter/generation/
format/build command execution. AgY handles lib/features errors using the analysis
log and 2026-10-12-nas-ui-analysis.md. No concurrent Flutter test commands.

Same OpenCode ownership/model/safety restrictions as original validation handoff.
Root has now patched vendored dartssh2 source + pubspec path but NOT run pub get.
Finish reliable hosted baseline first (immediate listener _settle(client.sftp())
before injected errors; do not classify late test listeners as package bugs).
Then pub get and rerun unchanged assertions against vendored package. Add request
send failure/subsystem rejection tests if absent. Preserve test proof and logs.

Now authorized: generation, formatting only current changed files, analyze,
test authoring/editing test/**, root cause reports; no product edits, no UI edits,
no suppression/exclusions/weakening meaningful assertions, no subagents. AgY is
concurrently changing UI and ARBs. Don't overwrite it. Once Phase B settles run
generation and UI gates again. No build/install yet; full gates first.

Cover new APIs (read code + UI contract handoff):
- NasDownloadService persistence/pause/resume/process restore/restart/checksum,
  partial source mutation/HTTP Range refusal/disk errors/symlink escape,
  completed file removal/no remote adapter during offline media open.
  Validate completion notifications/system open separate from in-app playback.
- Existing NasSourceAdapter fake implementations may need resolveForDownload
  delegate to resolve; keep realistic validators for resume fixtures.
- Incremental nas_download_tasks migration preserves favorites/positions/index.
  nasHomeProvider uses bounded independent category queries and continue-watching.
- File recent dirs per server, last20, rejected path; retryFailedBatch only failures,
  source size/mtime/type mismatch prevents operation, captured server change fails.
- App prepare fresh disk preflight (update fakes with real df header+row), structured
  health docker ps IDs + inspect fields. No English human-readable status parsing.
  zero disk rejects and malformed data fails, comparisons do not expose secrets.
- Terminal delayed resize on dropped session records handled diagnostic, old stream
  callbacks cannot affect replacement connection. ACP close cleanup errors observed.
- New UI 320dp, 2x fonts, RTL, source forms, complete offline list without active
  server; tests adapt intentional new Library destination without dropping coverage.

Report exact analysis/test commands/results/log paths and product defects to root.
Do not claim historical passes. ADB inventory read-only allowed. No user-server
failure injection, no actual Agent prompts, no version bump/push/release/Actions.
