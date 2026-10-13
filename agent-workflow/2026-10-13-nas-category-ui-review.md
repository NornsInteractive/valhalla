# AgY NAS category first-pass review (in progress)

Original Valhalla conversation/model/high only. All fixes below belong to AgY.
Read the actual APIs before editing; no model or repository changes are needed
to accommodate invented UI fields. OpenCode owns generated code and validation.

## Confirmed blockers while first pass is being written

1. `NasPlaybackState` in `lib/data/models/nas_media.dart` has `serverId`, `path`,
   `Duration position`, nullable `Duration duration`. It does NOT have `sourceId`,
   `positionMillis` or `durationMillis`. Both new progress consumers need the real
   fields and must check source AND path before using saved/live data. Home
   sections have their own batch `playbackByPath`, not necessarily the visible
   library state's map; pass the correct bounded map to their cards.
2. `_captureScrollAnchor` estimates the item from scroll/maxExtent ratio;
   `_restoreScrollAnchor` estimates the offset from itemIndex/itemCount. Neither
   measures the first visible tile or its pixel displacement. Date headers,
   grid columns, text scaling and a600-item eviction make these estimates jump.
   Use a real visible source/path tile and its viewport-relative pixel offset;
   preserve it after prepend/eviction and guard by generation plus exact source
   object/config identity, not just source ID. Do not claim ratio math meets the
   approved anchor contract. Keep tile-key bookkeeping bounded to the window.
3. Calling `enableGalleryWindow(false)` BEFORE `selectCategory` erases the current
   photo-window snapshot before the provider can remember it. Let category
   snapshots preserve their own gallery state; enter photos with enable(true)
   after the guarded category load. Guard all async continuations against both
   a newer category selection and source replacement. Deferred init callbacks
   need the same check.
4. For album scopes use `g.key` directly. Its getter already falls back for old
   constructors; adding `isNotEmpty ? key : name` risks substituting a display
   name for an intentionally empty key. Unknown artist is `artist: ''`, not a
   displayed localized label. All group cursors use keys, never names.
5. Album navigation now sets `albumKey`, but music detail routing and breadcrumb
   visibility still check only `artist`/`album`. Include `albumKey != null` in
   the existing scope checks and preserve album labels without exposing IDs.
6. Increment paging/query generation on source, category, search, sort and scope
   changes, not just next/previous actions. A→B→A must not revive an old async
   restoration. Avoid touching ordinary non-gallery paging: its replacement
   pages should still start at the first item, rather than the old raw offset.

Read-only reviewer confirmed all six against the first-pass snapshot. Review
all callers of changed helpers, including Home shelf cards and photo tiles.

This list is a live review, not evidence of fixed behavior. Preserve existing
selection, viewer, queue and offline controls. Do not edit core or tests.
