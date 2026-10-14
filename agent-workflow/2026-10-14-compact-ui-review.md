# Phase A review — AgY follow-up required

These are source-review findings after phase A, NOT verified runtime fixes.
Only AgY may change the UI. Root now has per-round test/analysis permission.

1. `app_store_tab.dart` grid titlePainter measures `Title Sample` at unbounded
   width, therefore ONE line despite maxLines2; actual title permits TWO lines.
   Use explicit two-line sample/real constrained measurement so 1.5x/2x title
   fits, instead of fixed-height overflow. Approx current2x143 vs needed185.
2. Ordinary file grid108dp cannot contain 8+24+6+48+4+16+8 ~=114dp. The SFTP
   PopupMenuButton's `constraints` restrict POPUP contents, not its48dp button.
   Shrink gaps and calculate correctly, retaining minimum44dp touch area. Do
   not hide overflow or weaken tests. If accessibility genuinely requires more
   height, correctness wins over target; normal <=112 can use gap0/2 carefully.
3. `RemoteBrowserEntryTile` date still maxLines1+ellipsis: at320dp/1.3x2cols loses
   minutes. Allow date/time wrap and include possible lines in grid height.
4. Store footer statusbadge is a non-flex child; long localized labels (e.g.vi)
   +1.5x overflow. Constrain badge with flexible allocation or stackfooter; keep
   status discernible, no unbounded Row child. Header/source allsafeRTL.
5. Ordinary compact grid no longer displays previewBytes but RemoteBrowserView
   still _fetchPreview for every non-list entry. Fetch only gallery (unless a
   real small preview is rendered); preserve gallery limits/owner cancellation.
6. Main file LIST date wraps but 320dp/2x minute glyphs paint outside the tile.
   Root confirmed with production AppTheme + actual Inter/JetBrains Mono fonts.
   Use measured metadata height/appropriate layout (not just TextOverflow.visible)
   and update virtual row geometry. Existing new test asserts minute glyph bounds
   within the file tile and fails at2x; don't weaken it.

Geometry tests should compare shared row bounds, not identical top pixels for
different text/icon heights. Date tests must check RenderParagraph layout/
selection bounds within tile, not only Text.maxLines. Anchor tests must derive
current detailed-row extent rather than old hardcoded72.

AgY must correct these before Phase A can be called complete. Preserve pending
terminal UI work and all other agents' edits; no tests/format/build by AgY.

Runtime confirmation (root-run widget tests): ordinary file grids overflow 5px
at normal text. Store long title+Vietnamese incompatible status at1.5x overflows
25px horizontally /31px vertically; at2x 42px vertical. Logs:
`/tmp/valhalla-20261014-compact-tests.log` and
`/tmp/valhalla-20261014-compact-review-tests.log`. Some first-run test assertions
also required fixture fixes (file mode vs directory-only and vertical-overlap
rather than exactcenter), maintained by root separately from production fixes.
