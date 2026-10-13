# AgY: NAS complete redesign, files and app-center UX

ONLY resume Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b, model
gemini-3.8-flash-high, effort high. User explicitly rejects current NAS usability
and appearance and approves a fresh content-first design plus offline capability.
Read 2026-10-12-nas-refresh.md and existing source. Do not use other conversations.

## Ownership

Allowed: lib/features/nas/**, lib/features/files/**, lib/features/app_center/**,
lib/l10n/*.arb, this report. Do not change core/data/infrastructure/pubspec/platforms/
tests/generated localization/global shell. No tests/build/generation/format/git or
subagents. Root owns business APIs; report missing API, never directly SSH/SQL.
Preserve existing dirty user changes, including file list view/scroll fixes.

## Phase A: begin now using existing business interfaces

Redesign NasMediaView and related dialogs, not just colors. Follow app's existing
Material3/theme/typography, all supported locales. MainShell already owns page
title and global player/navigation; don't duplicate. NAS local navigation has five
destinations: home/photos/videos/music/library. Library houses folders/favorites/
playlists/downloads. Keep existing features reachable; no regressions in open policy,
source selection, scanning include/exclude, album/artist/playlist drilldown, casting.

Home content: Continue watching, recent photos, recent videos, recent music. Root
will supply bounded independent home sections; until then retain real existing
data and report integration need. Never invent counts/media/ratings. Compact single
source/action row (search opens explicitly), content-forward layout, no oversized
statistics card. Photos date groups/grid, video artwork/time/progress, compact music
rows and album/artist navigation. Distinctive real artwork and restrained surfaces;
do not copy old Stitch hierarchy. Respect system/theme choices, no hardcoded theme.
Mobile source/scan/library configuration full-screen scrollable forms with safe
bottom actions; desktop bounded dialog. Retain working guards/validation/secrets.
Remember per-source/category view and scrolling; stale loads can't switch source.
320dp, 2x text and Arabic RTL usable; no nested scroll lists building entire library.

Root will then provide offline task fields and local playback actions, file recent
directories and precise application health/preflight contracts. Do not fabricate
their signatures or put business state in UI. Implement Phase A now and report
exact files/contracts needed. Keep this report updated with implemented/unverified.

## Phase A Implementation Status: Implemented (Unverified by Tests/Build)

### Authoring Changes & Modified Files

1. **Responsive Mobile/Desktop Dialogs**:
   - `lib/features/nas/widgets/nas_source_dialog.dart`: Responsive layout using `LayoutBreakpoints.compactMax`. On mobile/compact screens, renders `Dialog.fullscreen` with dedicated `Scaffold` and scrollable form; on desktop, renders bounded `Dialog`. Form actions wrapped in `OverflowBar` with responsive alignment, safe for 320dp and 2x text scale. Preserves secret visibility toggle, connection testing, and validation logic.
   - `lib/features/nas/widgets/nas_scan_config_dialog.dart`: Renders full-screen scrollable form on compact screens and bounded dialog on desktop. Actions use `OverflowBar`. Preserves path inclusion/exclusion chip editors and concurrency/debounce controls.
   - `lib/features/nas/widgets/nas_library_settings_dialog.dart`: Full-screen scrollable form on compact screens and bounded dialog on desktop with safe `OverflowBar` actions. Preserves all library preference toggles.

2. **5-Destination Navigation & Media Surfaces (`lib/features/nas/nas_media_view.dart`)**:
   - **5 Primary Destinations**: `Home`, `Photos`, `Videos`, `Music`, `Library`.
   - **Library Sub-Sections**: Houses `Folders`, `Favorites`, `Playlists`, and `Downloads` via sub-navigation pills (`_buildLibrarySubNavBar`).
   - **Content-Forward Home Surface**:
     - Shelves: Continue Watching (videos), Recent Photos, Recent Videos, Recent Music, and Library Quick Access chips (`nas_tab_folders`, `nas_tab_playlists`, `nas_tab_favorites`, `nas_tab_downloads`).
     - Removed oversized statistics card (`nas_quick_stats`).
     - Real data presentation without synthetic counts or ratings.
   - **Photos Surface**:
     - Date grouping (`_formatEpochDate`) with sticky-style date headers and sliver grid under `Key('nas_image_grid')`.
   - **Videos Surface**:
     - Rich 16:9 thumbnail cards with duration badge, media format tag, favorite button, overflow menu, and playback progress bar under `Key('nas_media_list')`.
   - **Header & Navigation Controls**:
     - Compact single-row top action bar with explicit search expand/collapse toggle (`_searchExpanded`).
     - Scroll position retention across tab and source switches via `PageStorageKey`.
     - Memory for last active tab and library sub-section per source (`_sourceTabMemory`, `_sourceLibrarySectionMemory`).
     - Stale load prevention for async group loading (`_groupLoadGeneration` matching active source).
   - **Test Key Invariants Preserved**:
     - `nas_tab_photos`, `nas_tab_videos`, `nas_tab_music`, `nas_tab_folders`, `nas_tab_playlists`, `nas_image_grid`, `nas_media_list`, `nas_item_*`, `nas_item_overflow_*` preserved and accessible.

3. **Localization Updates**:
   - `lib/l10n/*.arb` (all 17 locales: `en`, `de`, `es`, `fr`, `it`, `ja`, `ko`, `nl`, `pl`, `pt`, `ru`, `tr`, `zh`, `zh_Hant`, `ar`, `id`, `vi`): Added `nasTabLibrary`, `nasContinueWatching`, `nasRecentPhotos`, `nasRecentVideos`, `nasRecentMusic`. Natural translations matching each target language without English copy-paste parity violations.
   - `lib/features/nas/widgets/nas_localizations.dart`: Added runtime fallback getters to `NasLocalizationsExtension` ensuring immediate resolution prior to build-time code generation.

---

## Missing Business / Root Contracts Needed for Phase B

Root is requested to provide the following contracts/providers without UI inventing signatures or managing backend state:

1. **Bounded Independent Home Shelves Query**:
   - **Need**: Client currently filters the active source media list to populate Home shelves.
   - **Contract Proposal**: A bounded query method or stream on `NasNotifier` / repository (e.g. `Future<NasHomeShelves> loadHomeShelves(String sourceId, {int limit = 10})`) returning slices for `continueWatching`, `recentPhotos`, `recentVideos`, `recentMusic` without requiring the UI to load or sort the entire source index into memory.

2. **Offline Download Task & Local Playback Resolver**:
   - **Need**: Library contains `Downloads` sub-section and overflow menus support download actions, but task lifecycle, storage paths, and offline playback resolution require core integration.
   - **Contract Proposal**:
     - Model: `NasDownloadTask` (id, mediaItem, progress, status, localPath, error).
     - State Provider: `Stream<List<NasDownloadTask>>` or `ValueNotifier<List<NasDownloadTask>>` tracking ongoing/completed downloads.
     - Playback Resolver: Method to resolve local playback URI when offline or prefer local copy over streaming.

3. **Files Integration - Recent Directories Contract**:
   - **Need**: Deep integration between NAS folders and Files module for quick jump and recent directory history.
   - **Contract Proposal**: Expose recent directory history provider (e.g., `recentDirectoriesProvider(ConnectionKey)`) yielding recent paths and bookmarks.

4. **Source Health & Preflight Check API**:
   - **Need**: Explicit source connectivity and feature probing (transcoding support, direct streaming, write permissions).
   - **Contract Proposal**: `Future<NasSourceHealth> checkSourceHealth(NasSource source)` exposing status code, latency, and supported capabilities.
