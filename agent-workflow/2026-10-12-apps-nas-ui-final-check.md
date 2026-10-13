# Current UI closure checklist (supersedes resolved historic findings)

Same original AgY Valhalla conversation/model/high, UI/ARB only. No core/data/test
edits, test runs, generation/build/ADB/publish. Root has current-round validation
authority. Preserve the workspace. Core and isolated VM have passed; UI still
must pass real regressions. Do not weaken tests or add dependencies.

## Application center still to prove

1. Store deep-scroll list/grid anchor at 320/812dp fails after 4800px scrolling.
   Natural ListView.separated card heights are NOT `104 * scale`. Smallest option:
   switch to ListView.builder with a REAL `itemExtent = cardExtent + 8` and an
   8px bottom Padding inside each item; use that same extent in offset math.
   Give the grid the same adaptive cardExtent as its mainAxisExtent. Compute the
   extent once per layout from the actual text scaling/styles and max line counts
   (title 1, summary 2, source/version 1, badge, icon 48, vertical padding 24 and
   gaps 8); do not measure every catalog item or hard-cap large text at 180px.
   TextScaler may be nonlinear: `scale(1) * fontSize` is not a safe replacement
   for scaling/measuring each actual font size. Card text must fit vertically.
   With fixed extents, list index uses max(0, offset - 12) / (cardExtent + 8);
   grid row uses max(0, offset - 16) / (cardExtent + 12), both floored. Restore
   the target item's start using the matching leading padding/stride, clamped
   to the new maxScrollExtent after layout. Preserve a visible application key,
   resolving its index in the same filtered catalog; do not reset search/source.
   In this Flutter SDK (`rendering/sliver_grid.dart:504`), columns are
   `max(1, ceil(crossAxisExtent / (380 + 12)))`; crossAxisExtent is the actual
   viewport width MINUS 32px horizontal padding. No arbitrary upper column cap.
   At viewport 812px, available 780px gives TWO columns, not three. Keep layout
   and restoration on the same calculation; do not replace one guess with another.
   Tests: `apps-ui-anchor.log`; assertions require the same app visible after
   list -> grid -> list at 320/812/1100dp, including the deep-scroll cases.
2. Every failed source needs its own retry invoking
   `refreshCatalog(sourceId: entry.key)`. Core API is on disk and29tests passed.
   Global refresh still invokes refreshCatalog(). Disable each source retry
   while state.loadingCatalog is true; retain cached cards from both the failed
   and healthy sources, search, view and scroll. Do not replace populated results
   with a spinner. Current test records [null], expected ['fixture']; see
   apps-ui-source-retry.log.
3. Access diagnostics after server switch: old buttons are correctly disabled,
   but show the existing localized `l10n.appCenterErrorTargetChanged` explanation
   immediately too. Compute the captured/current connectionKey mismatch with
   ref.watch at build scope, not only in endpoint branches; show one banner even
   if diagnostics are loading/empty. Do not send a new probe against the new
   server from the old dialog; keep old endpoint actions/recheck disabled and
   retain the existing handler-side target/connection guards. Cached read-only
   information may remain visible. Do not weaken the server-switch assertion.

Already passed: SSH button calls existing openApplication, no external candidate
for private-only management binding, HTTPS/path/query/IPv6 URI correctness,
320dp2xRTL access dialog, initial tasklog tail, manual log scrolling/follow-latest,
numeric port edit plus bind override preserving both. Keep these behaviors.

## NAS still to prove

- Initial category/search must reflect NasState.browseCategory/search, not Home.
- Category/source switch cancels pending search debounce. Source round-trip must
  sync controller+category+scroll; identity changes clear old selections/context.
- Batch pending must disable buttons, not merely ignore duplicate calls. Captured
  source/identity must still match before displaying completion/retry dialogs or
  snackbars; old source completion currently leaks into new source UI.
- Sort popup,500dp top controls,320dp2x selection bar and homepage section header
  overflow. Wrap/flex without hiding required actions; selected-item count stays
  readable. Manual playlist keeps sort hidden.
- Individual selection and metadata MUST be reachable from actual tiles. Current
  analyze still reports `_toggleSelection` and `_showItemMetadataDialog` unused.
  Clicking tile while selecting must toggle selection, not play media. Preserve
  ordinary tap behavior outside selection; playlist duplicates use entry identity.
- Keep keys nas-sort/nas-selection/nas-select-loaded/nas-batch-favorite/
  nas-batch-playlist/nas-batch-retry; expose a metadata action/dialog key.

Already passed: loaded-items-only batch, failed-only retry, selected playlist,
category search isolation after debounce completes, refresh and category scroll
restoration. Do not regress these. Source+late result assertions are independent.

Logs /tmp/valhalla-apps-nas.wCun9l/nas-ui-organization.log and
nas-ui-source-batch.log. Latest analyzer only5NAS warnings/infos in
analyze-ui-current.log: nonnull comparison,2unused methods,2null-aware elements.
Tests in test/features/application_center_ui_test.dart, application_path_flow_test.dart,
nas_media_view_test.dart, nas_navigation_test.dart. Read only relevant portions.

## NAS follow-up verification after the saved closure pass

Two NAS UI files ran: 50 passed / 2 failed initially. One failure was the old
test expecting five overflow-menu actions; metadata correctly adds a sixth, so
the test now explicitly checks six plus the reachable metadata action.

The single remaining product failure is `_buildBatchBottomBar` around line450:
the nested Row containing the selected-count label plus Select Loaded text
button is still an unbreakable child inside the outer Wrap. At320dp and2x text,
it receives288px and overflows262px. Let count and button wrap/stack independently
instead of retaining an unbreakable nested Row. Preserve readable labels,
text scaling and all action keys. No need to revisit already-passing controls.

Evidence: `/tmp/valhalla-apps-nas.wCun9l/nas-ui-narrow.log` (exact Row diagnosis)
and `nas-ui-final.log` (full run). Targeted analyzer is clean in
`nas-ui-final-analysis.log`.

Confirmed passing: individual photo A/B/A taps select onlyB without playback,
URL fetch or download; metadata action opens the correct name/path; sort popup
and manual-playlist hiding; loaded-only/failed-only batches; pending-button
disable; old-source completion suppression; category/source initial/search/
scroll restoration; existing500dp shell navigation.

### Final intermediate evidence while AgY quota is blocked

After correcting the legitimate six-action menu expectation and adding the
authorized Home regression, the final53-test NAS two-file run completed
51 passed /2 failed in `/tmp/valhalla-apps-nas.wCun9l/nas-ui-final-interim.log`.
The failures are exactly the batch-bar nested Row at450 (320dp/2x,
overflow262px) and Home selection described below. Targeted analyze clean.

One separately authorized minimal regression confirms a second root cause:
Home also exposes the global selection toolbar, but `_buildHomePhotoTile`
(around3048) still routes every tap directly to `_openInApp(item)`. Enter
selection mode on Home then tap one photo: an actual `NasImageViewerDialog`
opens instead of selecting the item. Photos-tab tile behavior already passes.
Reuse the same selection guard for Home; preserve ordinary non-selection tap.
Evidence `nas-ui-home-selection.log` (0 passed /1 failed); all media operations
use existing fake providers and Flutter's test HTTP override, no actual image
download or production mutation. This new test is included in the final run.
