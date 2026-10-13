# NAS classification core → AgY UI contract

Implemented interfaces in the current worktree; not a claim of passed tests.
UI/ARB remains AgY-only. OpenCode owns tests, formatting, analysis and builds.
Preserve the existing player, image viewer, offline actions and source identity.

## Media and album identity

`NasMediaItem` has new nullable `albumId`, `albumArtist`, `discNumber`; these
round-trip through JSON/SQLite and are populated where the actual server/tags
provide them. No EXIF, movie scraping, fabricated covers or inferred episode data.

`item.albumKey` is stable within `item.serverId`: remote album id first, otherwise
album artist (falling back to artist) plus album; missing tags fall back to folder.
Use source + key as identity. `item.album` remains a display label, not identity.
Same album names from different artists/sources must not merge.

`notifier.setScope(albumKey: group.key)` opens an album in disc / track / path
order. Unknown/nonpositive disc or track numbers sort after known values. Do not
offer a generic name/size ordering control that pretends to change this album
track order. Existing `setScope(album: name)` remains available for old callers,
but new album UI must use albumKey to avoid merging same-name albums.

## Bounded group queries

`NasIndexGroup` includes `byFolder`, `byArtist`, `byAlbum`, `byDate`.

```dart
await notifier.groups(group,
  after: previousPage.last.key,
  kind: NasMediaKind.image, // optional; use explicit kind for photo folders
  folder: folder,
  artist: artist,
  albumKey: albumKey,
  modifiedFromEpoch: fromSeconds,
  modifiedBeforeEpoch: beforeSeconds,
);
```

All new arguments are optional. Existing active search, favorite and scope
filters apply; music groups default to audio, date groups to images. Each call
returns at most200 through the provider. Cursor is `last.key`, NEVER `last.name`.
Groups ascend by key except dates, which descend newest first.

`NasIndexGroupCount` keeps `name/count` and adds:

- `key`: stable group cursor/scope key.
- `representative`: a real media item usable by existing thumbnail widgets.
- `totalDurationMillis`: nullable sum of known durations, not proof that every
  item has metadata. Do not label it a complete duration when data is incomplete.
- `modifiedFromEpoch/modifiedBeforeEpoch`: UTC Unix-second date range.

Date grouping is honestly modification-date grouping in UTC. Do not relabel a
UTC bucket as a local-calendar day or claim a capture/EXIF date. A date scope is
`setScope(modifiedFromEpoch: g.modifiedFromEpoch,
modifiedBeforeEpoch: g.modifiedBeforeEpoch)`. Unknown date has empty name/key
and `modifiedBeforeEpoch == 1`; use localized Unknown. Unknown artist also has
empty name/key and is selected with `setScope(artist: '')`.

Folder group names remain real paths. `representative` does not promise artwork:
file sources may lack audio/video thumbnails, so show a truthful neutral fallback.
Do not request originals to manufacture missing video artwork on list rendering.

## Photo window and scroll ownership

After `await selectCategory('photos', filter: NasMediaKind.image)`, call
`await enableGalleryWindow(true)`. Playlist scopes do not support this window.

- `state.galleryWindowEnabled`: active photo-window mode.
- `loadGalleryNext()` / `loadGalleryPrevious()`: append/prepend one keyset page.
- `loadMore()` / `loadPrevious()` automatically route to these in window mode.
- `state.items` retains at most600 items (each request at most200).
- `state.hasMore/hasPrevious`: corresponding edges are available.
- `galleryTrimmedBefore/galleryTrimmedAfter`: item counts evicted by the latest
  successful directional load; ordinary refresh resets these to0.
- `state.isLoading` guards concurrent loads; old contents remain visible.

Before an edge load, UI records the visible source/path item and its viewport
pixel offset. After state changes, find that SAME item and restore its viewport
offset. Eviction counts alone do not give pixel deltas: date headers, column
counts and text scaling alter geometry. Load near the corresponding edge, so
evicting the opposite edge does not remove the visible anchor. Do not jumpTo(0)
or append every page forever. Maintain current source/category generation guards
for deferred post-frame anchor restoration.

Source/category snapshots include the bounded window. Refresh preserves its
leading item and bounded size. Search/sort/scope changes intentionally reset the
query/window to its first page. `enableGalleryWindow(false)` also resets normal
paging. Existing non-gallery and manually ordered playlist paging are unchanged.

## Persisted playback and Home

`NasState.playbackByPath` is one batch lookup for visible non-image items; no
per-tile database calls. Values are `NasPlaybackState` with source, path, position,
nullable duration and updatedAt. Compare BOTH source id and item path before
overlaying the live player snapshot. Saved progress remains useful for all other
cards. Do not show a numeric percentage when duration is unknown/zero.

`refreshPlayback()` refreshes only this bounded progress map. The existing player
save callback invokes it; playback errors do not originate from this optional
library lookup. Playback itself still captures source/query/cursor before opening.

`NasHomeSections` retains existing fields and adds `continueListening`, `favorites`
and `playbackByPath` for the continue-watching/listening entries. They come from
the existing index, not fake sample shelves. New empty shelves should disappear.

## Real scan diagnostics

`NasState.scanStage` uses `NasScanStage`:
`idle, connecting, scanning, finalizing, completed, cancelled, failed`.
`scannedCount` is discovered/indexed count, not a known total. Use indeterminate
progress when total is unknown. `scanUpdatedAt` is the last actual stage/count
update; `lastScan` remains the persisted time of the last successful full scan.
`scanErrorCode` is a sanitized NAS code, preserved separately from transient
library refresh errors; do not invent shell commands or diagnostic log output.

Cancelled/failed scans retain the old index. Same-id source replacement cannot
publish the old scan result into the replacement source.

## Cache forwarding (root owns service implementation)

```dart
await notifier.thumbnailCacheUsage(sourceId: id);
await notifier.thumbnailCacheUsage(legacyOnly: true);
await notifier.thumbnailCacheUsageBySource();
await notifier.clearThumbnailCache(sourceId: id);
await notifier.clearThumbnailCache(legacyOnly: true);
```

The usage-by-source map's empty key is explicitly unowned legacy cache. Omitting
both options retains old global behavior. Cache clearing cannot remove offline
media; offline deletion requires its separate explicit confirmation.

## Required verification ownership

OpenCode should update fake overrides for additive parameters on groups/setScope/
repository queryPage/count/recentPlayback and cache forwarding methods, without
weakening assertions. Verify100k migration, same-name album isolation, unknown
tags/date, scope-aware counts/cursors, all reverse sort orders,600-item eviction
and recovery, saved progress batching, source/category roundtrip, same-id edits,
failed/cancelled scan retention, offline and existing queue/playlist invariants.

### Incremental scan + retained gallery edge regression

OpenCode must cover an initially first-page gallery (`hasPrevious == false`),
then insert newly discovered photos that sort before its first visible item and
call `refresh()` with default position preservation. The original visible anchor
must remain, while `hasPrevious` becomes true and `loadGalleryPrevious()` reaches
the new photos without duplicates or exceeding600 items. Repeat with the
preceding rows removed (flag becomes false) and switch source while the one-row
boundary query is delayed (no stale publish). Core now recalculates that flag
with a reverse keyset `limit:1` query instead of retaining the old flag.
