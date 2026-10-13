# AgY gallery completion, narrow next batch

UI only, original Valhalla/Gemini3.8FlashHigh/high. Existing core contract remains
authoritative. Preserve viewer/player/selection/offline actions and tests' public
keys. No new dependencies or core changes, no generated files or validation runs.

## Observable outcome

Photo gallery scrolls through the bounded600-item window in both directions.
Loading at an edge keeps the same visible source/path tile at the same viewport
pixel offset, including prepend/eviction and 2x text. It never estimates a tile
from a fraction of maxScrollExtent, never resets to top and never builds/downloads
all images to find a tile. Normal non-gallery page changes still start at top.

## Small native layout option, verified available locally

Flutter has `SliverVariedExtentList.builder` in
`/opt/flutter/packages/flutter/lib/src/widgets/sliver.dart:599`. A single lazy
list of date-header rows and square-photo rows can make layout geometry exact:
derive columns and square size from available width; measure date label height
with the same TextPainter style/textScaler/direction/width as the actual header.
The resulting per-row extents/prefix offsets are authoritative, not scroll-ratio
estimates. Keep at most current bounded-window row metadata. Native Material
theme and existing thumbnail widgets remain; no full-resolution list fetches.

Capture the first ACTUALLY visible mounted tile with source/path and measured
viewport-relative RenderBox offset. Use exact row geometry to bring that item
back into the built viewport after prepend/eviction, then use measured pixel
correction if needed. GlobalKey entries, if used, must be pruned with the window.
An ensureVisible-only solution fails when lazy eviction makes the anchor unbuilt.
An equivalent smaller exact solution is fine; no generic scrolling framework.

Use directional near-edge loading so the opposite-edge eviction cannot remove
the user's visible item. Do not leave always-enabled fixed footer actions that
can evict the visible anchor from the wrong edge. Keep accessible explicit edge
retry controls and stop auto-retry when an edge request fails. Avoid auto-loading
loop at initial position or while a viewer/dialog covers the gallery.

## State preservation

- Remove `enableGalleryWindow(false)` BEFORE switching category. It destroys the
  photo snapshot. Enable(true) after guarded selectCategory(photos); preserve the
  core snapshots' own window mode. Init deferred callbacks need same guards.
- Invalidate restoration generation on source/config, category, search, sort and
  scope changes, including A->B->A. Compare exact selected source object/config,
  not ID alone. Recheck every await and post-frame continuation.
- Capture latest visible position if the user scrolled while data was loading;
  a stale request-start anchor must not yank the user backward.
- Preserve source/category positions and viewer return; any source switch while
  a load/viewer is pending must not restore into the replacement source.
- Respect reduce-motion and bounded state transitions150-250ms; no per-tile
  infinite controllers. Date means UTC modification date, not EXIF capture time.

Read only affected methods, implement then report. Root/reviewer will inspect;
OpenCode will author/run widget regressions and analyze. Do not claim acceptance
from the patch alone.
