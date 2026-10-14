# Phase C implementation deltas (read with parent + NAS API)

Existing NAS is already capable. Preserve existing behavior, providers, keys
(`nas_tab_*`, `nas_item_*`, `nas_image_grid`) and bounded paging/anchor code.
Do not replace the entire 6000-line view. UI only; root owns all verification.

1. Shell: currently horizontal chips at every width, two-row source toolbar with
   seven actions. Desktop narrow local category rail; mobile source/search/more
   single compact row + five category tabs. Move management into Library/more.
2. Home: BUG fallback `homeSections == null` treats videos.take(4) as continue.
   Only explicit continueWatching/continueListening qualify. Add real listening
   shelf. Keep recent shelves and empty/cached-content states honest.
3. Photos: retain date grouping,600window,two-phase anchors. Add per-source
   density3/4/5 default4 and real folder albums with representative thumbnail;
   groups(kind:image,byFolder)200pagination. Density/layout change must preserve
   item + screen pixel, returning from viewer/folder also keeps position.
4. Videos: currently only big vertical cards. Add actual two-column16:9 grid
   and compact list toggle, preserve real thumbnail/duration/progress/playback.
5. Music: existing tracks/artists/albums, correct albumKey scope and playall.
   Convert albums to real-cover grids, artists grouped rows, tracks music
   metadata. Add same-source audio-only addToQueue from existing new core API.
6. Library: keep existing folders/favorites/playlists/downloads navigation;
   add grouped management links and media-type favorite selection.
7. Player: all controls already work; audio full/mini covers currently notes.
   Use NasThumbnailImage for current item or honest placeholder. No fabricated
   controls, extra players or full-library shuffle claim.
8. Playlist deletion currently immediate; add bounded confirmation explicitly
   explaining only playlist references are removed, never remote files.
9. Downloads already has pause/resume/retry/open/delete-local confirmation.
   Separate active tasks from completed/offline items, preserve all operations.
10. Source/scan/cache/deployment/diagnostics already complete and baseline tested;
    reuse them via new navigation, no needless rewrites. Keep five protocols,
    source/server distinction, protected downloads, Docker->official Jellyfin
    App Center detail, native preview/limits, sanitized diagnostics and DLNA.

Reuse global theme/accent/Inter/Mono and subtle existing Entrance animations;
honor reduced animations. Light/dark/AMOLED,320dp/largefonts/RTL must remain safe.
No new dependencies, cloud services, fake covers, EXIF or unrelated features.
