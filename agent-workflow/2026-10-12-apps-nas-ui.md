# AgY original Valhalla UI task: apps observability, access, NAS

Only conversation ec81a4be-7543-45ee-8658-f68966f57d3b; model
gemini-3.8-flash-high / high. Preserve dirty work. No subagents, test edits/runs,
format/generation/build/ADB/publish/version changes. Do not edit core/data files.
Whitelist lib/features/app_center/**, lib/features/nas/** and lib/l10n/*.arb.
Read this and relevant files only; implement now, don't spend the turn on broad
investigation. Reuse current tokens/components and all17 locales, no dependencies.

Phase A now: application center UI; Phase B NAS APIs will follow from root.

1. Root adding ApplicationTask optional currentCommand:String, commandStartedAt,
lastOutputAt,lastSyncedAt:DateTime?, syncError:String?; all fields old-compatible.
Display stage, selectable/copyable sanitized command/log, elapsed/no-output age.
Never show fabricated percent. Preserve scrolling unless already following tail;
allow follow-latest. Show sync unavailable separately while preserving last stage.
Notifier public setObservedTask(String? taskId): call when install/details shows
task, clear on dispose only if matches (API clearObservedTask(String taskId)).
Runtime visible task refresh1s independent full refresh. Existing task operations
remain. No automatic retry installation or claiming failure due quiet output.

2. ApplicationPort now adds nullable bindAddress and effectiveBindAddress(config)
will be finalized by port helper; root will notify exact helper. New installs
must explicitly choose app default127.0.0.1 or0.0.0.0 (a separate form bool can
track user choice). Existing deployment configured state is already chosen.
Per-port dropdown inherit/SSH only/external. Preserve bindAddress in every port
copy (validation/onChanged). Default scope currently offered but unclear: rename
user-facing scope so0.0.0.0 is NOT falsely called LAN-only. Explain public risk
before executing preview with any external port. Existing deployments unchanged
until explicit configure confirmation. External binding does not open firewalls.
Show target/published ports and management entry. Root adds access information /
readonly diagnostics; do not invent provider methods before contract arrives.

3. Store list/grid toggle, persisted via storage.getApplicationStoreViewMode():
String? and setApplicationStoreViewMode(String) (list/grid); absent means current
responsive default. Keep search/filter/scroll anchor while changing view, adaptive
grid height at large font. Keep cached apps visible when source refresh fails.
Show source-specific concise classified errors, last success and retry; diagnostics
copyable. New codes APP_CENTER_SOURCE_DNS/TIMEOUT/NETWORK/TLS/UNAVAILABLE.
Catalog.image(url,{sourceId:app.sourceId}) enables trusted official URL fallback;
add argument to all3 image/screenshot calls. No raw SocketException banner.

Confirmed port helper: effectiveBindAddress(String applicationBindAddress).
ApplicationComposeService.webPort(template,config) returns ApplicationPort?.
Wizard port copies at validation and field onChanged MUST preserve bindAddress.

Phase B core contracts now available (implementation concurrent):
NasSortKey {modified,name,size}; state.sortKey/sortAscending(default modified,false);
notifier.setSort(NasSortKey,{required bool ascending}).
runBatch(List<NasMediaItem>,{required NasBatchOperation operation,String? playlistId})
returns NasBatchResult: sourceId,operation,playlistId,results,failedItems,successCount.
retryBatch(result) retries failures only. Operations favorite/unfavorite/
addToPlaylist/removeFromPlaylist. Favorites max3 concurrent, playlist changes
sequential. Read final model for item-result field names before integrating.

Phase B direction: media browser same existing home/categories; compact sort and
multi-select actions, name/modified/size asc/desc; current default order unchanged.
Source+category view position/search/filter preserved. Batch favorite/unfavorite/
add-to-playlist and remove-from-playlist only; select-all means currently loaded.
Partial result summary and failed-only retry. Metadata dialog reads existing item
fields (no whole download). Fix _openExternal missing await. Scan/offline/cache
status distinct, cancellation/failure keeps index; clearing cache never offline.
No remote deletion, new services or unsupported buttons. Source/category memory
core helper details will follow; keep scroll/search in UI keyed by source/section.

FINAL ADDENDUM (read before completing):
NAS selectCategory(String category,{NasMediaKind? filter,bool favoritesOnly=false})
restores per-source/category search/sort/scope/page; call on category changes instead
of resetting all filters/search. NasState.browseCategory. UI restores search controller
from state.search and owns scroll offsets keyed source+category. refresh now preserves
current page unless explicit preservePosition:false. Batch result per-item names are
on disk in nas_media.dart.
Access API root provider.accessInfo(deployment) returns ApplicationAccessInfo:
ports(actual bindings),services,managementPort,sshEndpoint,checkedAt,probeStatus
(notApplicable/unavailable/reachable/failed),httpStatus?,probeExitCode?.
Add access info/readonly diagnose sheet to installed app actions with SSH open and
external candidate (editable server hostname, not0.0.0.0; no HTTP localhost claim
for external). Diagnostics only execute when user opens/retries; no firewall changes.
Use current server host as editable default candidate. Existing openApplication
directUrl remains user-explicit; explain external availability unknown until tested.

Integration correction: all core APIs above are now ON DISK, use statically typed
calls, no `(storage as dynamic)` fallbacks or empty catches to mask missing APIs.
Store preference writes return Future<void>; on error retain previous preference
and show retryable existing error, not silent failure. NasNotifier.openExternal
returns a synchronous download taskId String (it queues asynchronously), so do NOT
add await to that String; expose scheduled download progress/errors through existing
download state instead. This supersedes earlier suspicion of missing await.
Use direct provider APIs from current code, not invented methods.
ApplicationCenterState.sourceRefreshedAt[source.id] now provides each source's
last success time (loaded from cache too). Prefer that over global timestamp.
Hide NAS sort controls inside a manually ordered playlist; repository playlist
order is deliberately independent of media sort. Ensure selectCategory() wired
for actual tab transitions before claiming memory support complete.
Observe only task fields needed by the progress panel so1s logs do not rebuild
entire store/installed lists. Stop elapsed timers onterminal; log textbounded64KiB,
don't auto-scroll if user reading old lines. currentCommand/log are already sanitized.

INTERIM REVIEW REQUIRED FIXES (UI root cannot edit):
- app_task_details_dialog Column.children currently contains local declarations
  `final now=...; final elapsed=...;` (around352): invalid Dart; move before list.
- Storage view-mode dynamic unawaited setter + emptycatch is still on disk; typed
  awaited write, mounted error feedback, restore previous choice onfailure.
- Cache notifier in initState for dispose; do not ref.read from disposing widget.
- Stop terminal tasktimer and freeze elapsed at lastSyncedAt (or terminal capture),
  don't keep completed task duration increasing. Same review for wizard cleanup.
- Details followlatest flag must actually scroll onnew log, except userreadingold.
- Wizard progress log controller must attach to scrollview; call setObservedTask
  when launchedtask known. Clear only sameobserved ID when closing.
- Wizard numeric port onChanged constructor still needs bindAddress preserved.
- Separate PageStorageKeys do not preserve samevisibleapp on first switchlist/grid;
  remember visible app index/anchor and restore in newlayout.

Use existing design style: current command is the progress panel's focus, not a
decorative timeline. Buttons explicit; fit320dp, large font, RTL and desktop.
Return edited paths and any blocked integration, don't claim tests passed.

VALIDATION FEEDBACK (root authorized to test this round):
Flutter analyze interim found app_access_info_dialog.dart uses health.status but
actual model is health.state; wizard needs flutter/services.dart for Clipboard /
ClipboardData. DropdownButtonFormField value is deprecated; use initialValue with
stable reset key as needed. Please fix these UI files yourself.
For NAS validation add stable ValueKeys to new controls (nas-sort, nas-selection,
nas-select-loaded, nas-batch-favorite, nas-batch-playlist, nas-batch-retry) so tests
can verify loaded-items-only actions without depending on translated captions.
Interim widget compiler also found app_store_tab.dart line297 local declaration
`final sourceLastRefresh` inside Column.children. Move declaration to map callback
before returning the widget. Full compiler log: /tmp/valhalla-apps-nas.wCun9l/apps-ui-interim.log.

FINAL READ-ONLY WIRING REVIEW — AgY must resolve before device validation:

- Access dialog SSH button currently launchUrl(sshEndpoint), but this endpoint is
  REMOTE loopback, not a local tunnel. Call notifier.openApplication(deployment)
  instead. Preserve the existing HTTPS-direct-required error; never silently open
  the phone's 127.0.0.1. Watch active-server/connection changes and disable stale
  diagnostics/open controls; current _openUrl bypasses the captured-target guard.
- External candidate currently chooses even loopback management bindings and
  concatenates `http://host:port`, losing HTTPS/path/query and breaking IPv6.
  Base the URI on deployment/template endpoint semantics; use Uri.replace with
  validated editable host, only offer direct access for an actual externally
  bound management port, and explain SSH-only bindings. Never choose some other
  TCP service as a guessed management UI. Do not imply firewall/NAT reachability.
- Store anchor math hardcodes 104px/130px/two columns, while cards vary by text
  scale and grid uses responsive columns. Preserve a visible application key/index
  using the actual layout geometry, including one-column mobile and 3+ columns.
- Details and wizard stop timers on needsInspection (not terminal) and never
  restart after recovery. Only freeze on succeeded/failed/cancelled; latch the
  terminal elapsed endpoint once, because subsequent lastSyncedAt reads and
  unrelated task updates must not grow completed duration. Resume busy timing.
- Both log panels initially render existing nonempty logs at the top if readTask
  returns identical content. Scroll to the bottom after the first layout when
  follow-latest is enabled. Recheck the follow flag INSIDE queued post-frame
  callbacks so a user scrolling away before the callback is not pulled back.
- Wizard per-port bind dropdown captures `port.published` from build, while the
  numeric onChanged updates _ports without rebuilding. Changing bind after typing
  a port can restore the old value in _ports, later propagated by _syncControllers.
  Read the latest _ports[idx] when changing only bindAddress; preserve other fields.
- 320dp/2x text blocking rows: access probe status+HTTP+exit, actual bindings and
  service health rows, and wizard progress stage+elapsed have unfitted Text/Spacer
  combinations. Wrap/stack or flex them; retain readable endpoint LTR inside RTL.
- Localize new access dialog English literals (Probe/Checked/Access Endpoints/
  SSH Port Forwarding/External Access Candidate/host label/warning), wizard Target
  and External labels. Source error strings include `APP_CENTER_SOURCE_UNAVAILABLE:
  503`; split typed code/detail before resolving, otherwise the raw code still
  appears in the banner. Label source timestamp as last successful refresh, not
  the reused file-modified label. Cover all supported locales, not English only.

Review was read-only; no UI/ARB changed and no widget tests executed by reviewer.

SINGLE-SOURCE RETRY API NOW AVAILABLE (core regression passed):
`ApplicationCenterNotifier.refreshCatalog({String? sourceId})`.
Each failed source row needs its own retry button calling
`notifier.refreshCatalog(sourceId: entry.key)`; do not make that action refresh all
sources. Keep the page-wide refresh action as `notifier.refreshCatalog()`.
Scoped retry retains other sources' catalog/error/last-success values; disabled
or unknown IDs are no-ops, late replaced requests cannot overwrite newer results.
Reuse existing loadingCatalog to disable conflicting refresh buttons while pending.

NAS UI MUST FIX — authorized regression pass (2026-10-12)

- Current `flutter test test/features/nas_media_view_test.dart
  test/features/nas_navigation_test.dart` cannot compile: `PopupMenuButton`
  does not accept `visualDensity` (nas_media_view.dart around line1582).
  App-center compiler blockers above are also still present in this snapshot.
  Evidence: `/tmp/valhalla-apps-nas.wCun9l/nas-ui-interim.log` (0 tests executed,
  not a runtime failure and not a passing result).
- The source-change listener currently restores tabs only. It must also save and
  restore source/category scroll, synchronize `_currentCategory` and the search
  controller, and clear selection. Otherwise selection from source A can remain
  actionable while source B is displayed. Same-ID source edits/re-authentication
  must invalidate UI context too; observe source identity, not just its id.
- On the first frame or widget recreation, reflect `state.browseCategory` and
  `state.search` instead of showing Home/an empty field for restored Photos.
  Added widget regression: `restored provider category and query are reflected
  on the first frame` in `test/features/nas_media_view_test.dart`.
- Cancel pending search debounce before switching category/source and when the
  widget disposes. A query typed in Photos then switched to Videos within300ms
  must not overwrite the Videos query. Guard async category completion and queued
  scroll callbacks with captured source/category and mounted before touching the
  controller; rapid switches must not restore an obsolete offset.
- Capture source object identity around batch execution AND retry. A result from
  an old source must not open a dialog, clear new selection, or show a success
  snackbar over the replacement source. Core already safely binds mutations and
  failed-only retries; UI still needs its own presentation guard.
- Batch progress needs a busy guard so repeated taps cannot schedule duplicates.
  At this snapshot `_toggleSelection` and `_buildBatchBottomBar` only have their
  declarations: wire both into the actual tiles/bottom layout; metadata action
  likewise must be reachable. Multi-select cannot consist only of a toolbar icon.
- Select-all means currently loaded items, not all matching rows. Clear or prune
  selection on pagination, sort/search refresh and source changes; use source +
  path + playlistEntryId for playlist membership (the same media may occur twice).
- Keep manual playlist ordering: hide sort when `state.playlistId != null`.
  Currently `nas_sort_button`/`nas_multi_select_button` exist; either retain these
  stable keys consistently or use the agreed `nas-sort`/`nas-selection` names.
  Add `nas-select-loaded`, `nas-batch-favorite`, `nas-batch-playlist`,
  `nas-batch-retry`, and a metadata action/dialog key before final test pass.
- New behavioral regressions already prepared: independent category search and
  controller restoration; retaining visible data/offset while refreshing;
  Photos→Videos→Photos scroll restoration. Do not remove/weaken these assertions.

This handoff is from tests/read-only inspection. Only AgY may edit product UI;
NAS test author is waiting for wiring before running final UI verification.

Newest compiler feedback: ApplicationPort.containerPort does NOT exist; use
ApplicationPort.target (wizard dropdown key around1022). Latest complete analyzer
log /tmp/valhalla-apps-nas.wCun9l/analyze-ui-progress.log. Core analyses clean.

APPLICATION-CENTER WIDGET GATE — now compiles; 27 pass, 6 fail (2026-10-12)

Command: `/opt/flutter/bin/flutter test test/features/application_center_ui_test.dart test/features/application_path_flow_test.dart --reporter expanded`
Evidence: `/tmp/valhalla-apps-nas.wCun9l/apps-ui-focused.log`. These are real
behavior/layout failures, not missing fixture mocks. Keep the test assertions.

1. `live applying stage removes cancellation from wizard` (test line 476):
   320dp progress view overflows by 1.6px at ordinary text scale. Responsible
   stage/elapsed Row is `app_operation_wizard_dialog.dart:1651`; its stage Text
   and elapsed Text are both unconstrained with a Spacer between them.
2. `store list/grid keeps visible application anchor at 320dp` (test line 577):
   after scrolling list, visible `Catalog item 009` is not built in the new grid.
3. `store list/grid keeps visible application anchor at 1100dp` (same test loop):
   anchor is built but outside visible grid viewport. Both anchor failures are
   caused by `_toggleViewMode` hardcoded 104/130/two-column conversion around
   `app_store_tab.dart:59`. Use actual layout/card geometry and stable app id.
4. `access info is read-only and private management opens through existing SSH path`
   (test line 769): despite actual management bind 127.0.0.1:18081, dialog offers
   http://fixture.invalid:18081. Only expose a direct candidate for an actual
   externally bound MANAGEMENT port; a different public service does not qualify.
   This same test continues to assert opening via notifier.openApplication with
   null directUrl. Current SSH button directly launchUrl(remote 127.0.0.1) is
   independently wrong and must also be fixed, not just the first assertion.
5. `public management candidate preserves scheme path and IPv6 host` (test line 806):
   typed IPv6 host must produce https://[2001:db8::7]:18081/admin?view=1 from
   provided sshEndpoint, preserving path/query and HTTPS. Current string
   concatenation loses all these semantics. Editing must not probe typed hosts.
6. `access mixed ports fit 320dp 2x RTL without exceptions` (test line 836):
   seven RenderFlex overflows in `app_access_info_dialog.dart` Rows at lines
   236, 331, 388, 424, 494 (two services), 537. Keep endpoints LTR/readable,
   but make surrounding diagnostic/endpoint/service labels wrap or stack.

Already passing: async preference persistence failure is handled; view preference
survives remount and filters; selectable/copyable command; sync failure preserves
command/log; task dispose clears observation; editing host port preserves bind
override; directory wizard integration. Do not regress these while repairing.

ADDITIONAL FOCUSED PROOF — 29 pass / 7 fail, tests themselves analyze clean:

- `existing task output initially shows the latest log lines` reproduces the
  initial-follow bug: log controller offset is 0.0, maxScrollExtent is 1280.0.
  AppTaskDetailsDialog ref.listen does not fire for an already-present logTail;
  schedule initial bottom positioning after layout, respecting a user scroll.
- `new logs preserve user scroll until follow latest is selected` PASSES.
- `changing binding after numeric edit and variable rebase keeps both edits`
  PASSES at this snapshot (including TZ rebase and preview checks).
- Private management access test now checks the SSH button FIRST, before the
  direct-candidate assertion. It fails with notifier.opens=0 (expected1), proving
  this button bypasses the existing SSH openApplication route. Both access bugs
  still need repair; moving the assertion did not change the required behavior.

Full latest results remain `/tmp/valhalla-apps-nas.wCun9l/apps-ui-focused.log`.

ACCESS SERVER-SWITCH SAFETY REGRESSION — confirmed failure:

`access diagnostics cannot open stale endpoints after server switch` now changes
activeServer while access info is visible. Open buttons still have non-null
callbacks and no target-changed explanation. Watch connection/active-server in
build and disable/remove stale endpoint actions; enforce the captured target
again within both SSH/direct open handlers, not just during diagnostics load.
Test evidence: `/tmp/valhalla-apps-nas.wCun9l/apps-ui-access-target.log`.

ANCHOR FIX REVIEW — proposed scaled estimate is still not the actual layout:

- `listItemHeight = 104 * textScale` is not the height of the current natural
  `_CatalogItemCard` in ListView.separated (summaries vary from 1 to 2 lines).
  Changing the estimate or loosening tests does not preserve the visible app.
- Minimal robust implementation: use ListView.builder with an actual, shared
  `itemExtent = cardExtent + 8`, and an 8px bottom Padding around each card.
  Compute `cardExtent` once from text scaling and use that same value for layout
  and restoration. Allow enough height at large text scales; do not cap a row at
  a size that clips its content. This avoids a key pool/render-child measurement
  and preserves a deterministic index-to-offset mapping with fewer moving parts.
- Account for list leading padding 12 and grid leading padding 16 when deriving
  anchor indices/restoring offsets. Grid row stride is mainAxisExtent + 12.
- Local Flutter source `rendering/sliver_grid.dart:504` computes grid columns as
  max(1, ceil(crossAxisExtent / (maxCrossAxisExtent + crossAxisSpacing))), meaning
  the denominator here is 380 + 12, NOT 380. Cross-axis extent is the actual
  viewport width after horizontal padding. Use that same geometry consistently.
- Keep the current regression asserting that the same visible application is
  actually in view after list -> grid -> list at 320dp and 1100dp. We will also
  exercise a spacing-boundary width; tests must not be weakened to only check
  that some offscreen lazy child was built.

LATEST FOCUSED RESULTS — fixes converged, but two proven anchor gaps remain:

- Main UI gate now 37 pass / 1 fail. SSH open routing, private binding exclusion,
  HTTPS/path/query/IPv6 candidate, 320dp 2x RTL access layout, and initial log
  following now pass. The remaining gate failure is target-changed explanation:
  access buttons disable on server switch, but the dialog has no visible reason.
- Extended the same anchor assertion to a 160-app catalog after scrolling 4800px:
  `store list/grid keeps visible application anchor at 320dp after 4800px` fails
  actual viewport overlap; at 812dp the previously visible `Catalog item 052`
  is not even built after switching. 1100dp deep-scroll and shallow cases pass.
  This confirms cumulative geometry drift, not a need to loosen the assertion.
  Evidence: `/tmp/valhalla-apps-nas.wCun9l/apps-ui-anchor.log` (4 pass / 2 fail).
  Use the actual itemExtent/grid spacing implementation described above.

SOURCE RETRY WIRING — new regression confirms missing sourceId:

`source failure retry targets only that source and preserves other apps` fails:
expected refreshCatalog(sourceId: 'fixture'), actual refreshCatalog(sourceId: null).
The error banner still has one global retry after all error entries. Render a
retry control for EACH failing source and pass entry.key to the already-existing
provider API `refreshCatalog({String? sourceId})`; leave the general refresh as
global. Disable retry while catalog is refreshing; keep cached cards from both
the failed source and healthy sources visible throughout that request. Do not
replace the catalog with a spinner or clear search/view/anchor state.
Evidence: `/tmp/valhalla-apps-nas.wCun9l/apps-ui-source-retry.log`.

NAS UI repeat verification (latest snapshot, no product edits by tester):

- Retried both NAS widget files after batch action keys appeared. Compilation
  still blocked by NAS PopupMenuButton.visualDensity and wizard
  ApplicationPort.containerPort; see nas-ui-interim.log above. All other earlier
  compiler errors disappeared in this newer run.
- Ten new NAS widget scenarios are now ready in nas_media_view_test.dart,
  group `NAS organization browsing state`. In addition to the eight previously
  described, they verify loaded-only playlist selection and per-source
  query-controller/scroll restoration. The pending-batch test also requires the
  Favorite submit button be disabled to prevent duplicate taps.
- Test selectors retain the actual `nas_sort_button` and
  `nas_multi_select_button` names plus newly added hyphenated batch keys.
  AgY subsequently renamed the first two to `nas-sort` / `nas-selection`;
  regression selectors have now been updated to these agreed names. No revert
  is needed; keep the current hyphenated names stable for the final pass.

NAS UI ACTUAL RUNTIME FAILURES — compile blockers fixed, assertions not weakened:

- New ten-scenario group: 4 passed / 6 failed. Full NAS two-file first run:
  43 passed / 8 failed; two of those were tester GridView casts subsequently fixed
  to the actual ScrollView base. They are not product failures. Latest targeted
  evidence: `/tmp/valhalla-apps-nas.wCun9l/nas-ui-organization.log`.
- English sort popup rows overflow135/121px (and7.7px) at normal text scale:
  nas_media_view.dart around1596/1609/1635/1648. Make labels flex/wrap within the
  popup constraints; do not drop sort options or suppress overflow assertions.
- Existing navigation test at500px now overflows the top toolbar52px (around1729).
  The narrow/desktop split must account for all newly added action buttons.
- Batch action remains enabled while its Future is pending (expected disabled,
  actual onPressed closure). Captured old-source result presentation guard remains
  required; source-batch test will continue past the busy assertion on next run.
- Typing then switching category before debounce fires leaves Videos search
  `old-category-query`, expected empty. Cancel debounce and capture source/category.
- SourceA→B leaves the TextField controller `source-a` while provider search is
  `source-b`. Restore controller and scroll from the actual new provider state.
- Initial provider category=photos/search=photo still renders Home: no
  nas_image_grid exists. Restore category/query before first rendered content.
- At320px/2x font, the batch Row overflows454px (around365); existing home section
  header overflows331px (around2941). Wrap/stack/flex these layouts with readable
  labels; do not reduce text scaling or increase test width.
- Passing new scenarios: loaded-only batch selection and failed-only retry;
  selecting a playlist passes only loaded items and intended playlist; independent
  category query restoration; visible data and scroll retention on background
  refresh plus Photos→Videos→Photos offset restoration.

Confirmed independently: moving the batch busy assertion to the end exposed an
actual old-source success SnackBar after switching A→B. Expected no SnackBar,
actual1. Evidence `/tmp/valhalla-apps-nas.wCun9l/nas-ui-source-batch.log`.
Capture source identity before awaiting batch/retry, and suppress presentation
when selected source changed; do not merely clear selection after completion.
