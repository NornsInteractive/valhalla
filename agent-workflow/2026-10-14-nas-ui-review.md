# NAS Phase C review and regression findings

Root forwards this file to the original AgY Valhalla session after its current
turn. UI changes remain AgY-owned. Tests below are owned by the NAS reviewer.

## Final verification: 91/91 passed

Command: `flutter test --no-pub test/features/nas_media_view_test.dart test/features/nas_navigation_test.dart --reporter expanded --concurrency=2`.
Result: **91/91 passed**, 16 seconds, exit 0.
Log: `/tmp/valhalla-nas-baseline-efH5zC/nas-ui-final-91.log`.
No outstanding failure remains in this owned NAS UI acceptance suite. The
root agent runs the final repository-wide gate separately. UI was modified by
AgY; this reviewer changed only tests, review notes and the earlier queue API.

## Targeted final contract checks

- Photo-album return correction: **2/2 passed**, root and `/archive` parent
  scope, including page 2, same-album pixel position and no breadcrumb overflow.
  Log: `/tmp/valhalla-nas-baseline-efH5zC/photo-folder-return-after-fix.log`.
- Typed favorites regression: **1/1 passed** after the query fix. The first
  200 favorites contain only videos; selecting Photos now queries the later-page
  photo with `setFilter(image, favoritesOnly: true)` and resets paging. All uses
  `setFilter(null, favoritesOnly: true)`. The selection derives from provider
  `state.filter`, not local filtering of the currently loaded page.
  Green log: `/tmp/valhalla-nas-baseline-efH5zC/favorites-filter-green.log`.
  Prior red evidence: `/tmp/valhalla-nas-baseline-efH5zC/favorites-filter-red.log`
  (filter called zero times before correction).
- Focused gated `setScope` / same-ID endpoint replacement regression: **1/1
  passed**. The navigation generation guard rejects the late photo-return await,
  keeps the replacement source on Home and does not reload the old album page.
  Log: `/tmp/valhalla-nas-baseline-efH5zC/photo-return-same-id-guard.log`.
  The final view/navigation suite now contains 91 tests.

## Historical photo-album folder return evidence (fixed above)

One focused regression was added after the 87-test green run, subsequently
parameterized for an original root scope (`null`) and parent folder
(`/archive`). Child group keys remain under the respective parent, and return
must restore that original scope, not unconditionally clear to root:
`returning from a photo folder restores the album page and visible album without leaking folder scope`.
At 390dp, load album page 2, scroll 700px, open `Second page album 6`, then use
the visible Albums chip to return. Confirmed result:

- Page 2 and its cached groups survive.
- Album scroll resets **700 → 0**; the selected album's label moves from
  **y=266.11 → not built**, so the approved folder-return anchor is lost.
- `state.folder` remains **`/second/6`**. Albums are painted from the old global
  cache, but the next groups request inherits that folder via
  `NasNotifier.groups` (`nas_provider.dart`, approximately line 831), so global
  album pagination becomes incorrectly scoped to the previously opened folder.
- Entering the folder also produces a **52px right overflow** from
  `_buildScopeBreadcrumbs`' Row at approximately `nas_media_view.dart:2598`.

Root locations in this snapshot: Albums chip `onSelected` at 5259 only flips
`_photoAlbumsMode`; album `GridView.builder` at 5318 has no independent controller
or storage key; album tap at 5341 only sets folder scope then switches to the
timeline. `_loadPhotoFolderGroupsPage`'s jump-to-zero targets the timeline's
shared controller, not this grid. Clearing scope via the separate breadcrumb is
currently an extra manual step and still does not save the album scroll anchor.

Minimal correction: preserve the bounded album page's own scroll/visible item
independently from the timeline, return from the folder with the album query
scope restored, and reset the album grid (not the timeline) on actual page
changes. Retain source identity/navigation guards and the 200-group page limit.
Keep the breadcrumb usable at narrow widths; do not hide text scaling or drop
the existing clear/play controls. No new feature scope is requested.

Log: `/tmp/valhalla-nas-baseline-efH5zC/photo-folder-return.log`.
At discovery, the root-scope case was red; root and `/archive` variants now pass
as recorded above. This evidence is retained to document the acceptance gap
that the earlier 87-test green run did not cover.

## Prior stable verification

- Photo density/source suite: **9/9 passed**, 6 seconds, exit 0.
- Verified actual 4/3/5 columns at 390dp and 320dp/2x Arabic, same-photo screen
  pixel preservation, per-source density, loaded/pending album isolation,
  same-ID endpoint category consistency, and rejection of late album results
  after navigation without resetting another category's scroll position.
- Log: `/tmp/valhalla-nas-baseline-efH5zC/photo-stable-after-guards.log`.
- Full view/navigation suite: **87/87 passed**, 20 seconds, exit 0.
- Final log: `/tmp/valhalla-nas-baseline-efH5zC/nas-ui-final-complete.log`.
- All previously recorded layout, queue, album identity, deletion ownership,
  downloads, management entrypoint and home truthfulness regressions are green.
- The first stable full run passed 86/87; its sole failure was an obsolete
  six-menu-item fixture. The updated test strictly checks all seven action values
  and verifies the new queue action is disabled when no playback queue exists.
  No behavior, source isolation, pixel anchor, layout or laziness assertion was
  weakened. The earlier root-cause tables below are historical review evidence.

## Historical in-progress compilation gate (now repaired)

Photo-only run could not execute assertions after the next layout edits:
`PopupMenuButton` has no `visualDensity` parameter at nas_media_view.dart:2228
and2372; `showSort` is undefined at2222. Restore the prior sort visibility
condition and use supported sizing/layout APIs. These are temporary compile
gates, not additional photo behavior failures. Log:
`/tmp/valhalla-nas-baseline-efH5zC/photo-after-guards.log`.
Root's mini-player follow-up is now **6/6 green**, including320dp/2x Arabic.

## Historical first full Phase C run — blockers at that snapshot

Command: `flutter test --no-pub test/features/nas_media_view_test.dart test/features/nas_navigation_test.dart --reporter expanded --concurrency=2`.
Result: **56 passed /30 failed**,86 total,20 seconds,exit1.
Log: `/tmp/valhalla-nas-baseline-efH5zC/nas-phase-c-first-complete.log`.
Line numbers below refer to that compiled snapshot; find the owning helper if
edits shift them. Most failures share layout roots, not30 separate defects.

| Priority | Confirmed root | Snapshot location / affected test |
| --- | --- | --- |
| P1 | Photo header horizontal SingleChildScrollView -> ConstrainedBox(minWidth only) -> Row retains Spacer, yielding unbounded flex and cascading missing-size errors. Remove unbounded flex or provide genuine bounded constraints. | nas_media_view.dart:5210; all photo/anchor/source checks blocked |
| P1 | Same-ID endpoint change: UI source listener restores remembered Photos by ID while NasNotifier replaces its state with Home. Source object/context must be checked before restoring memory, or resynchronize the provider category. | source listener; `same-ID source replacement keeps UI category and provider query synchronized without another tap` added; not executed while photo layout blocked |
| P2 | Mobile top Row exceeds320dp by2px under2x text, English/Arabic. | nas_media_view.dart:2444; existing selection and music narrow-screen tests |
| P2 | Popup menu's external-open Row has unconstrained long text, exceeds menu width by66px even390dp English. | nas_media_view.dart:7407; queue success/race tests reach all functional assertions but fail overflow |
| P2 | Album card square cover + labels exceeds fixed card height by12px. | nas_media_view.dart:6527; same-name albumKey/real-cover assertions pass then fail overflow |
| P2 | Video card16:9 cover + labels/actions exceeds childAspectRatio1.15 card height (36px at320dp, also390dp). | nas_media_view.dart:5908; video geometry and old pagination test |
| P2 | Queue add action is hidden when incompatible; approved contract says visible but disabled. Keep item for audio tracks with enabled:false when empty/cross-source/video queue, with race handling unchanged. | media-list popup `if (item.kind == audio && canAddToQueue)`;3 new disabled checks |

Already green in this run: all3 home truthfulness cases, all4 deletion guard/
failure cases, both download classification/lazy cases, management5-entrypoint
case. Do not rewrite these working behaviors. Photo async/source isolation and
density/anchor behavior remain **blocked by layout**, not yet behavior-verified.

Reviewer-owned fixture adjustments (not UI bugs): mobile selection moved to
`nas_mobile_more_button` -> selection item; RTL horizontally-scrolled category
chips need ensureVisible before tapping. These corrections retain all original
assertions and do not suppress rendering errors.

## Baseline

- Pre-redraw existing NAS regressions: 168 passed (108 core/widgets +60 view/navigation).
- Two newly added home tests reproduce an existing false Continue Watching
  shelf while home metadata is pending. Both are expected to become green.
- Evidence: `/tmp/valhalla-nas-baseline-efH5zC/nas-ui-before-phase-c.log`.

## Required corrections in the first Phase C diff

0. **P1 destructive action/source ownership:** `_confirmDeletePlaylist` currently
   reads the current NasNotifier only after confirmation. If the source changes
   while the dialog is open, the same playlist ID can delete an unrelated
   playlist in the new source. Capture the selected NasSource object and the
   provider serverId before showing the dialog; confirm only if both still match
   and the playlist belongs to that source. An edited endpoint under the same ID
   is also stale. Await deletePlaylist and catch/sanitize errors; currently its
   Future can escape unhandled and leave no visible feedback. Tests cover source
   selection, same-ID source identity, provider source changes and visible failure.
1. **Download grouping:** `nas_downloads_sheet.dart` currently classifies every
   non-downloading/queued/paused item as completed. This falsely puts failed and
   cancelled transfers in the completed/offline section. Only `completed`
   belongs there; failed/cancelled remain tasks with existing resume/restart/
   remove actions. Completed with an external-open error remains completed.
2. **Download lazy construction:** replacing `ListView.separated` with a full
   children list and `for` eagerly constructs all task rows on each update.
   Keep the two sections but use indexed builders or sliver builders so task
   widgets are only constructed around the visible window. No full-history
   widget materialization on every progress event.
3. **Download section heading layout:** new Row headings contain unconstrained
   Text. Use a flexible text region so 320dp / 2x text / RTL remain safe.
4. **Photo-album source isolation (review final wiring):** the first helper diff
   stores `_photoFolderGroups`, `_photoFolderCursorHistory`, `_photoAlbumsMode`
   across sources without source-listener invalidation/restoration. Switching A
   to B can show A's folder names/covers and call B.setScope(A.path). Isolate or
   clear group pages/mode/cursors on source change; reject pending results for a
   changed source object, including edited endpoint under the same ID. Ensure
   UI category/query matches the provider after same-ID source replacement.
   Source-ID-only guards also accept A->B->A and same-source Photos->Video/Home
   late results: the helper then calls the shared scrollController.jumpTo(0),
   resetting a different page. Capture and recheck full source object,
   navigationGeneration/category and photo request generation. Leaving the
   category/source must invalidate pending photo-group work, including catch
   feedback and loading flags, not only successful result assignment.
   Preserve directory/album return anchors, but never reuse A's context for B.
   Target regression: A loaded then switch B; A pending then B; same-ID endpoint
   change; group pagination and return from directory/viewer retain their own
   visible item rather than unrelated raw scroll offsets.
5. **Photo controls at narrow/large text:** the first photo header uses an
   unscrollable Row of two ChoiceChips, Spacer and density control. The added
   320dp/2x Arabic test checks this real geometry alongside3/4/5 columns. If it
   overflows, fix the header layout (wrap/scroll/flexible appropriate controls),
   not by hiding density choices or reducing readable text scaling.
6. **Video-card height:** the first video grid uses childAspectRatio1.15 while
   each card contains a16:9 cover, title and two action buttons. At320dp the
   available card height is around128dp while the contents need about160dp
   (PopupMenuButton.constraints constrain the menu, not its trigger). Measure
   sufficient mainAxisExtent for actual controls/text. Keep two columns at
   normal320/390dp; compact list must remain usable at2x text. Added tests check
   rendered geometry, thumbnail16:9 and real grid/list layout changes.
7. **Confirmed mini-player large text overflow (root-owned test):**
   `nas_thumbnail_lifecycle_test.dart` reproduces a6px bottom RenderFlex overflow
   with320dp/2x Arabic/AppTheme/real fonts because `nas_mini_player.dart` fixes the
   entire player height at62. Use minimal adaptive height/layout while retaining
   real cover, controls and readable scaled text. Do not suppress text scaling.
   The normal cover-change/release/buttons test passes; preserve it. Evidence:
   `/tmp/valhalla-20261014-player-cover-test.log` (5 passed,1 failed).

Two new cases in `test/features/nas_media_view_test.dart` cover failed/cancelled
classification + retry, and 1000-task lazy name/row construction. Do not weaken
them by relabeling failed transfers as completed or eagerly building all rows.
First targeted execution was blocked by AgY's in-progress `manage` enum addition
without both switch branches yet; no assertions executed. Rerun after Phase C
is compile-ready, rather than treating that temporary gate as a product bug.
Log: `/tmp/valhalla-nas-baseline-efH5zC/download-phase-c-regressions.log`.

## Pending acceptance after the main view lands

- Photos default4 and3/5 geometry; per-source density; preserve visible item and
  screen pixel after density change, bounded600 and existing viewer behavior.
- Add-to-queue dispatch once without opening/restarting playback; disable empty,
  non-audio, cross-source queue; sanitized localized race failure.
- Same displayed album names remain isolated by albumKey; real representative
  cover identity, no fake metadata.
- Home shelves only use real continueWatching/continueListening arrays.
- Preserve category/query/source memory and old baseline behavior through the
  navigation changes; update test navigation to real entrypoints, not bypasses.
- Review final photo-folder async lifecycle: current helper only compares
  source.id (not object identity), swallows load errors, and mode flags are not
  yet per source. Recheck the finished wiring before treating these as final
  failures; delayed groups must not populate a different endpoint/source.
