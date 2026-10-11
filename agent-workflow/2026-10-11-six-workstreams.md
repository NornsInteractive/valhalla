# Six workstreams after v1.0.4

Base b97a02c; clean at start. User confirmed all six groups and then requested
ADB installation before authorizing implementation. This addendum permits a
local Android test build/install-r after full gates, not a release or git push.
No Actions, cloud build, paid model, uninstall/data-clear or shared-cache cleanup.
Keep version/signing unless a data-preserving test package requires the already
authorized original debug signature; never change the public release certificate.

## Ownership

Codex: core/data/infrastructure, documentation, and business-only
features/system/system_provider.dart. AgY: UI, authored ARB, exact original
Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b, gemini-3.8-flash-high / high.
OpenCode: test authoring/running, formatting/generation/analyze/performance,
build/package validation/ADB. MiMo free first, earlier authorized confirmed-free
fallback only if necessary, main and small models explicit with zero cost.
No real production mutations or development Agent prompts/history modifications.

## Implementation and acceptance

1. Processes/services/container actions bind confirmations to captured target;
   process PID/start identity required. Busy/real startup state/errors and bounded
   service logs have usable UI. Never auto-retry destructive actions.
2. File editor uses captured editor token for save/close/discard; drafts flush
   before closing with Keep draft. Every exit offers Save/Keep/Discard. Remote
   revision conflict never overwrites. Persisted transfers resume explicitly,
   old writers settle before new writers, validated files only can open.
3. Same-target recovery retains content/selection/drafts/scroll. Cold snapshots
   visibly cached/partial, not live. ACP/Agent host-container-user identity,
   auth/model/draft tools/approvals/output/cancel/recovery mock regressions;
   discovery never creates sessions; no automatic prompt/approval replay.
4. Updater provider race/cancel/restore/double-writer checks, failure preserves
   content; existing 24h opt-in policy, manifest/hash/cert validation and explicit
   installer. No credentials bundled and no silent installers.
5. NAS visible owner-bound stable thumbnail Futures, release on dispose/change,
   cache usage/budget/clear, bounded indexes/queues and explicit playback retry
   at existing position/queue. Experimental remains default-off. No new daemon.
6. 320dp/2x fonts, desktop keyboard and RTL/localization/menu/input/scroll
   regressions. Update roadmap/requirements/handoff/verification truthfully.

## Provider contract already added

- SftpNotifier.saveFileContent(path,text,{required editorToken}). Capture token
  immediately after initiating openFileForEditing, before await; reject late
  results/server changes even if pathname matches. All actual UI save paths must
  carry token; OpenCode updates fixtures, preserving assertions.
- flushEditorDraft({required editorToken}) waits for queued encrypted writes,
  surfaces SFTP_DRAFT_SAVE_FAILED and rejects expired editor. Keep draft calls
  updateEditorDraft -> await flush -> closeFileEditor(token), no pop on failure.
- SystemNotifier.terminateProcess(pid,{force,required expectedStartedAt,
  required expectedConnectionKey}); startup may be null but operation is refused.
- performServiceAction(unit,action,{required expectedConnectionKey}) and
  serviceLogs(unit,{beforeCursor,required expectedConnectionKey}) reject changed
  targets. Use captured server.connectionKey before confirmation/dialog awaits.
- Existing NAS provider exposes thumbnailPath(item,{owner}), releaseThumbnail,
  thumbnailCacheUsage, thumbnailCacheBudget, setThumbnailCacheBudget and
  clearThumbnailCache. Player.retry preserves queue/quality/current position.

## Gates

New failing regression first where practical, then focused proof; complete
foreground full suite with natural end, zero whole-app analyzer, 17-locale parity
and isolated 10k-media index/cache performance report. No old2441 baseline reused
as current acceptance. Explicit environment skips never silently counted passed.
Then OpenCode selects exact connected ADB serial, verifies ABI/version/signature,
local exact-source compatible package, install-r, read-only UI smoke. Production
power/service/container/history mutations and Google consent aren't automated.
Unavailable device or original AgY session blocks only their necessary gates;
report genuinely unfinished scope rather than claiming implementation complete.

Status: business interfaces patched; initial file/service UI and 17-locale keys
written, but review corrections and Phase B consumers remain pending. Original
AgY job exited 3 with Individual quota reached (about 33 minutes to reset).
User switched accounts and requested a restart; the original conversation/model/
effort has been restarted at 06:14 UTC. Never take over UI edits.
OpenCode focused file/draft tests are running; no complete gate/build/install yet.

MiMo Phase 1 and Phase 2 wrapper deadlines expired (exit124); preserve partial
results instead of claiming completed jobs. Phase2 individual 18-file/225-test
passes and actual10k fixture measurements recorded in six-nas-acp-validation.md;
one combined29-test attempt failed and its history is being reconciled. User's
earlier confirmed-free fallback permission applied to Step5 Preview Free, verified
zero input/output/cache costs locally and official Zen pricing on 2026-10-11.
Both main and small models explicit in config; no paid title model/cloudbuild.

Business follow-up: draft deletion now serializes with queued writes and save
rechecks token after remote await; stale same-path saves cannot delete new drafts.
Updater rechecks provider lifetime before native metadata and before storage
after HTTP. ServiceManager maps actual non-systemd-init/missing-bus messages to
SERVICE_UNSUPPORTED and interactive-auth failures to SERVICE_PERMISSION_DENIED.
OpenCode should add literal-message regressions without changing the existing
generic shortened-error fixture expectation.

Journal older-page follow-up: journalctl cursor is inclusive. Request 201 raw
rows on subsequent pages, drop the cursor row and cap delivered records at 200.
This prevents a full older page of 199 records from falsely looking like EOF;
initial page still requests 200. Regression must cover 201 inclusive records and
oversized fake output, preserving existing cursor/injection tests.

06:40 UTC review: AgY wrote Phase B but its completion report overstated the
confirmation lock, thumbnail disposal and dashboard changes. Second review
requires correcting those exact omissions through the same conversation only.
Restarted follow-up read the latest review, then returned quota exit3 with about
5m36s to reset. Wait original session; no Codex takeover of UI. MiMo UI test
author deadline expired without an authored file (exit124); the confirmed-free
Step5 delegate now extends the existing fixture rather than duplicating it.
ADB preflight reconnected 127.0.0.1:14251, no installation performed yet.

07:27 UTC progress: AgY original conversation completed editor-local failure
Messenger and save-specific fallback; OpenCode is rerunning unchanged widget
assertions. Latest draft/transfer focused file is 38/38, service safety file
5/5. Preliminary lib analyzer has zero issues, locale parity9/9 and thumbnail
lifecycle4/4; these are not whole-project gates. Additional updater tests and
service log UI authoring remain active. Read-only ADB preflight confirmed
127.0.0.1:14251 is the actual adb transport; EMULATOR37X1X11X0 is hardware
property metadata, not an adb selector. Installed APK real certificate matches
original debug keystore, version1.0.3/code4004; no new package installed.

08:14 UTC: final AgY card-header Wrap correction has now passed actual
service UI3/3 at320dp/2x/RTL plus busy-exclusion and retained-log retry. Header
Row, not the earlier guessed tab renderer, was proved by full creator trace.
Updater/provider plus notes parser56/56 pass (8provider/48service parser), zero
owned-file analyzer issues, deterministic fake writer-open acknowledgment.
The whole-project gate executor is waiting for the last test writer to exit;
no full-suite/build/install result yet. Keep old failed/interrupted evidence.

First whole-project gate naturally completed: gen-l10n and whole analyzer exit0;
full suite 2484 passed,18 skipped,11 failed. Preserve unfiltered
`/tmp/opencode/six-final-gates/full-suite.log`; no build or installation occurred.
Six older test files need narrowly scoped fixture updates for storage/cache
initialization, captured proxy cleanup and the richer localized upload error.
Two OpenCode free delegates own those test-only changes; UI/core are not changed
to satisfy obsolete fakes. Gate executor was interrupted130 AFTER the failed
suite while its CLI stopped producing output; interruption is not a passed gate.
Next full run must use a separate log and naturally finish before any build.

Fixture follow-up: original free Step5 author CLIs interrupted130 after9minutes
of inspection without tests; resumed the same two OpenCode sessions with narrow
implementation instructions. Storage-dependent four files now28/28 pass exit0
(`/tmp/opencode/six-storage-fixtures.log`); proxy/upload two files53/53 pass exit0
(`/tmp/opencode/six-proxy-fixtures.log`). No original behavioral assertions
removed; proxy cleanup now checks the actual revoked URI and upload checks
the exact richer localized key. Storage failures were8 (dashboard6 + policy2),
not7 as one delegate's final text mistakenly summed. Counts are focused sets,
not a new whole-suite success. A fresh whole gate/build executor is waiting for
the last writer to settle; no new APK/install yet.

Storage author's resumed CLI exited0. Proxy author's resumed CLI was stopped130
AFTER its whole two-file test command returned EXIT=0/53passed and scoped
analysis printed No issues found, while it repeatedly inspected reporter label
counts. Flutter's parallel expanded labels do not give per-file pass counts;
the total53 is authoritative. No further source edits were pending. The CLI
interruption is not a test failure or an additional passed command. Writers are
now settled for the independent full gate.

Second full gate: generation/31-fileformat/diffcheck/analyzer all exit0;
whole natural run2494passed18skipped1failed exit1. Unfiltered log
`/tmp/opencode/six-final-gates-rerun.stYzuh/gate5-fulltest.log` retained. Exact
failure is sftp_transfer_records_test managed-download cancel cleanup, NOT the
parallel reporter's NAS label. Fake uploadAutoFinish defaults true and also
finishes downloads, allowing commit-stage refusal before the cancellation check.
Isolated38 and paired41 passing do not fix the race. OpenCode owns a test-only
explicit-pending fixture correction; production committing protection stays.
Final executor interrupted130 after failed gate/diagnostics, before build/install;
will resume only after this writer settles, with a new unfiltered full-run log.

Cancellation fixture explicitly holds its fake download pending and now checks
running/non-aborted/zeroaborts before cancel, canceled/oneabort after, plus all
original cleanup assertions. Author's first attempted negative Future matcher
attached a listener receiving intentional SftpTransferAborted:37passed1failed.
Its tee PIPESTATUS[1] was incorrectly zero and is NOT a passed test exit; log
`/tmp/opencode/six-cancel-fixture-fixed.log` retained. CLI interrupted130 then
resumed same session, removing only that NEW matcher. Actual final scoped run
38passed exit0, analyzer0, CLI0, log`six-cancel-fixture-final.log`. All writers
settled; independent full gate resumed in the same free OpenCode session with a
fresh log directory. No new build/install result yet.

Third complete gate naturally passed: gen-l10n0, format31/0changes0, diffcheck0,
whole analyze0/No issues found, whole tests2495passed18skipped0failed EXIT0.
Final independent logdir `/tmp/opencode/six-final-gates-final.QcWx9V`.
Skips require explicitly configured isolated VM/WebDAV/Mosh/power fixtures,
not optional regression omissions. Earlier failed logs remain. Only now may the
authorized exact-source local Android build and preserving-data ADB proceed;
build/installation still pending.

## Final outcome

All six scoped workstreams implemented. Original AgY Valhalla/high owns UI and
authored17locales; Codex owns business/docs; free OpenCode owns checks/build/ADB.
Whole gates2495passed18environment-skipped0failed EXIT0, analyze0.
First native build with--no-pub failed1 stale ignored integration_test registrant;
normal tool-native release regeneration succeeded0, source+lock unchanged
(`f5ce0efea731f476583d3fc0cf344cd97e89f34dd49b4c270c2194721c6e01cc`).
Fresh x86_64 release-mode original-debug-cert TESTAPK1.0.4/code4005,50,242,416bytes,
SHA256`1508e446162fe22c449520d883081fb6f396ebf8b1008b7473dd339c9de4ca0c`.
Exactadb127.0.0.1:14251 install-r0/Success; pulledinstalledhash/cert/version equal
stage, firstInstallTimeunchanged. Racknerd visible/connected, menu+addserver
dialog cancel succeed, after-cancel IMEfalse withValhalla foreground. No data
clear, productionactions, realAgentprompts, consent, signingchange or publication.
Real ACP/OAuth/NAS/physical-phone/Windows-native paths and cold-cache/frame
performance remain unverified by emulator smoke. No remaining implementation
or authorized local-install step; detailed records in
[final verification](2026-10-11-six-final-verification.md) and
[build/ADB](2026-10-11-six-build-adb.md). Historical partial/fail logs above remain.
