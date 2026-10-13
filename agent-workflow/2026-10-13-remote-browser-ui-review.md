# Shared browser UI contract review — 2026-10-13

Read-only review of AgY's current `lib/widgets/remote_browser_view.dart` and its dialog confirmation boundary. UI work is still in progress; line references describe the snapshot inspected, not a claim that later changes remain broken. No UI/test code was changed and no tests/builds were run.

## Blocking findings

### P1 — Directory navigation resumes after disposal, and increments its generation too late

`remote_browser_view.dart:117–122` awaits `_streamSub?.cancel()` before capturing/incrementing `_epoch`, then calls `setState` without checking `mounted`. Closing the dialog during that await produces `setState after dispose`. Two overlapping loads can both await the same old subscription, then one clears/replaces `_streamSub` created by the other without canceling that new subscription. The callback generation rejects its results but does not release its resources.

The request also reads mutable `widget.source` after suspension (`129–135`). `didUpdateWidget` (`96–102`) can replace the source while an earlier load is pending; that older request can then browse its old path through the new source.

Required fix: increment/capture generation and source before awaiting anything; detach the old subscription; cancel it; then check `mounted`, captured generation, source identity and source validity before mutating state or starting a stream. All callbacks and parent fallback must use the captured source. Increment generation on dispose/source replacement. Do not notify parent selection/path callbacks from stale requests.

Regression: block subscription cancellation, start A then B/source replacement, complete A's cancellation last; only B starts/updates. Dispose during cancellation must produce no framework exception.

### P1 — Directory selection currently accepts regular files

`remote_browser_view.dart:202–219` enters directories but otherwise selects any selectable entry in `RemoteBrowserMode.directory`, including an ordinary file. `remote_browser_dialog.dart:154–174` only synthesizes the current directory when nothing is selected; an already-selected regular file passes straight to `source.selection`, which validates target/path availability, not UI selection mode. `pickDirectory` returns that file path (`dialog:91–92`). This can reproduce invalid application data-directory configuration.

Directory confirmation is also always enabled (`dialog:206`) while its initial path is still loading or the listing failed, allowing a nonexistent/unverified current path to be returned before fallback completes.

Required fix: directory mode disables/omits regular-file selection; confirmation independently validates entry kinds, counts, restrictions and current source. Current-directory confirmation requires a successfully loaded current location. Single-file mode must also reject directory selections when supplied through initial state or a mismatched source/mode.

Regression: tapping/double-tapping a regular file cannot return it from `pickDirectory`; confirmation during delayed or failed initial listing cannot bypass validation.

### P1 — Previews can cross source boundaries and exceed the agreed limits

`remote_browser_view.dart:249–274` keys cache and in-flight work only by `entry.id`; result handling checks only `mounted`. `didUpdateWidget` does not clear preview state. Switching between two valid sources that both contain `/photo.jpg` can show the old source's cached image or apply its late bytes to the new source.

There is no concurrency queue/cap. Every built image card starts a request (`736–742`). The cache only limits count to 24 while each image permits 2 MiB (`261`), so retained compressed bytes can reach 48 MiB, not the agreed 8 MiB. `Image.memory` (`772`) omits decode dimensions, so a tiny visual thumbnail can decode a full-resolution photo. Failed/null previews are not remembered and can be retried on every unrelated rebuild.

Required fix: capture source identity plus preview generation; clear source-specific cache/queue on source replacement and reject stale completion, including stale `_loadingPreviews.remove` operations. Keep at most two requests active, at most 24 cached entries **and** 8 MiB total compressed bytes, evicting until both limits hold. Limit decoded thumbnail dimensions to display size × device pixel ratio. Avoid retry loops for a failed preview until an explicit refresh/new request epoch. Directory navigation/refresh must invalidate obsolete work; it must not stall the new list.

Regression: same ID from sources A/B with A completing last; rapidly scroll many images and assert concurrency ≤ 2, cache bytes ≤ 8 MiB, count ≤ 24; oversized/failed image does not repeatedly fetch on rebuild.

### P1 — Selection snapshots are not synchronized with the dialog

`remote_browser_view.dart:140–147` restores initial IDs only while `_selectedEntries.isEmpty`. Once an early batch contains one selected library, all selected IDs arriving in later batches are ignored. Restoration never calls `onSelectionChanged`, so the dialog's `_selected` stays empty and its confirm button/count are wrong despite visible checkmarks. Clearing all selections and reloading can unexpectedly reselect initial IDs again.

On source replacement (`98–101`) the internal selection is cleared without notifying the parent. The dialog can retain entries belonging to the previous source; `source.selection` then binds those stale paths to the new target key if the parent calls confirm.

Required fix: initialize a per-source pending-initial-ID set once; resolve matches across all incoming batches independently of whether other entries are already selected; notify the parent consistently. User deselection must not be undone by later batches/reloads. Source replacement clears both child and parent snapshots before confirmation can proceed. Selection mode restrictions apply to restored entries as well as taps.

Regression: initial selected libraries in batches 1 and 2 both survive and count/confirm match; deselect-all stays cleared; replacing source clears the dialog's confirmation payload.

## Required usability/contract corrections

### P2 — View switching does not preserve a visible-item anchor

List and grid share a pixel-offset controller but use different geometry and different constant PageStorageKeys (`415–417`, `443–450`); the view toggle (`655–660`) only flips an enum. Equal pixel offsets do not represent the same file after changing column count/row height, and saved offsets can bleed across directories/sources.

Capture the first visible entry ID and its relative position before switching, then restore that entry after the new layout. Key stored positions by source identity and directory, not globally. In a 360dp widget test, scroll to a known entry, switch list/grid and verify it remains visible. Sorting/search/directory changes need an explicit reset/anchor rule, not an inherited unrelated pixel offset.

### P2 — Shared styling currently drops requested file-page behavior

- Search and toolbar actions remain in one Row (`575–665`), contrary to the approved standalone search row; this squeezes mobile input space.
- Hidden entries are filtered by `isHidden` (`279`) but neither row nor grid dims them; retain the existing subdued-hidden-entry treatment when shown.
- Grid filenames use `maxLines: 1` (`786–789`) instead of the approved two-line treatment.
- `Hidden files`, `Name`, `Size`, `Date`, `Library`, `Directory` are hard-coded (`617`, `636–644`, `843–844`) instead of localized.

These should be corrected in the shared component so management pages and all pickers do not diverge again.

### P2 — Partial-list errors become invisible

The error body only appears when `_entries.isEmpty` (`354`). If a paged backend returns entries and then fails or loses its target, the error is recorded but hidden, leaving a partial list looking complete. Show a compact localized retry/status message while preserving already displayed rows, and disable confirmation when target validity is lost.

## Flat-library and multi-directory notes

- Root scope clarification: the approved requirement mandates multi-select for media
  libraries, not a new filesystem multi-directory mode. NAS filesystem include/exclude
  editors may accumulate one selected directory per dialog using the shared directory
  picker. Preserve that smallest existing flow; do not add a mode only for this review.
- Opaque library IDs are correctly not used for navigation: `entry.canEnter && !source.flat` guards entry navigation (`203`), and the flat header does not render path breadcrumbs (`468`). Keep that behavior.
- Existing multiple-library tap toggling is structurally valid, but the initial-selection bug above breaks its preselection/confirmation contract.
- There is no multiple-directory mode in `RemoteBrowserMode` (`15–21`), and navigable directories always enter before any toggle. NAS filesystem include/exclude multi-selection therefore needs a separate selection affordance/mode; reusing `multipleLibraries` will still navigate directory rows without selecting them. If the approved caller deliberately supports accumulating one directory per dialog instead, document that deviation rather than claiming this component supports directory multi-selection.
- The special `/` branch in `multipleLibraries` (`231–242`) does not itself create an “all libraries” option; adapters only return opaque library IDs. Any caller offering “all” must handle the root sentinel explicitly without treating `/` as a real library ID.

## Limits

## Caller follow-up inspected during phase2

Root also added `test/features/remote_browser_preview_test.dart`; both regressions
currently fail: 10,000-image list starts more than2 concurrent preview reads on
first grid render, and thumbnail uses raw MemoryImage without decode dimensions.
Bound parallel requests/encoded cache AND decoded dimensions as described above.
These are actual widget failures, not inferred from a screenshot.

Phase3 partial implementation follow-up: source replacement resets
`_activePreviewCount=0`, but old `.then/.catchError` decrements it before checking
captured source/epoch. An old failure even drains the NEW queue. Added public widget
regression `old-source preview failures cannot release new-source permits`: second
source grows to3 concurrent reads when an old-source failure arrives (limit2).
Scope counters/queue operations to the correct lease; stale completion must neither
clear new in-flight keys nor alter its permits. When navigating within a source,
ensure discarded old completion still releases its own permit and new queue can
make progress. Also update grid cache lookup to the same new target-key key used by
cache writes; partial snapshot still reads `_previewCache[entry.id]`, losing images.

After AgY's latest guard patch and service429, root stable checkpoint tests are
11passed/5failed (`root-component-checkpoint.log`). The old-source error-counter
test now passes, but `navigation releases old preview permits and starts the new
directory` proves a new stall: navigation doesn't reset active count, old completions
return early on epoch mismatch and never release its permit, so new directory
images never start. Retain both tests; fix permit ownership without reversing one
regression to resolve the other. Other remaining failures: selected files remain
confirmable during loading or after partial-list error; missing thumbnails from
cache-key mismatch/unbounded decode; same-ID new source starts duplicate previews.

- `SftpDirectoryPickerDialog.show` now routes to shared dialog but leaves its entire
  legacy widget body; `RemoteWorkspaceBrowserDialog.show` likewise leaves >700 lines
  of the old independent browser. Convert old types to thin adapters or shared-body
  wrappers after migrating callers; do not retain parallel live browse UI.
- Restricted paths in SFTP wrapper are only checked by `restrictedPaths.contains`
  after closing, losing the original ancestor/descendant restriction and visibly
  disabled confirm. Preserve original protection at shared dialog confirmation.
  Initial missing-path fallback is allowed, but an explicitly navigated missing
  directory must show its error rather than silently selecting an ancestor.
- ACP wrapper captures only profile.id and activeSessionId; same ID can change
  execution user/container/host. Capture execution identity, original server
  connection key and session/draft identity; validate after async factory opening,
  after dialog selection and before attachment/cwd mutation. Currently AI chat
  attachment caller captures its target AFTER the dialog, which is too late.
- CLI picker currently compares activeAgent object only, not session/draft identity.
  Add original target/session guard and context.mounted after factory await; neither
  opening nor cancelling a picker may create or switch a conversation.
- Preserve ACP supported file kinds/count/size validation in the shared picker
  adapter. Current pickFiles replacement discards the old UI's supported-file filter.
- Preserve existing ACP list/card/image-preview choices when sharing the display.
  `test/features/acp_remote_workspace_browser_test.dart` already covers three views;
  the new component currently offers only two. A compact common view menu can
  retain all three without three wide toolbar buttons. Gallery uses bounded image
  previews; cards remain vertical and mobile2columns. Don't delete the old feature
  or weaken this regression to claim complete migration.

Root runs actual regressions now; original paragraph below only describes the first
source-level review. Tests and results are recorded separately.

This is source-level contract review only. No widget, protocol, device, or performance proof was executed. Confirm the fixes against the existing browser core/API handoff before build or ADB acceptance.
