# Phase B — live contracts and remaining UI work

Same ownership and whitelist as 2026-10-12-nas-refresh-ui.md. Do not run tests,
formatters, builds or modify core/data/infrastructure/generated files.

## NAS

`nasHomeProvider` -> AsyncValue<NasHomeSections>: continueWatching/photos/videos/music.
Queries are independent, bounded (8/12 items) and not filtered by whichever tab was
previously selected. Consume this instead of deriving home from `nasProvider.items`.
Preserve source-change isolation. Refresh can invalidate nasHomeProvider.

`nasDownloadServiceProvider` has `ready`, tasks/changes, download, pause(id),
resume(id), restart(id), remove(id), localFile(id), localPathFor(item), open(id),
reveal(id). New status `paused`. pause/resume/restart/remove are Future<void> and
must be caught in UI. Existing retry(id)/cancel(id) retained. nasDownloadsProvider
waits for restoration; unfinished persisted tasks restore paused, not automatically
networked. Display this list without requiring a currently reachable server/source.
Completed entries expose original `item` and localPath. Removal must confirm that
the local offline file will be deleted, not the remote original. Source changed or
missing validators on resume => NAS_DOWNLOAD_SOURCE_CHANGED, offer restart from
zero, never auto discard partials. Other errors: NAS_OFFLINE_FILE_INVALID,
NAS_DOWNLOAD_STORAGE_FAILED, NAS_OFFLINE_HLS_UNSUPPORTED, NAS_DOWNLOAD_PATH_INVALID.

Audio/video player automatically prefers verified completed offline originals via
localPathFor before obtaining any remote adapter; reuse existing player UI. Images:
await localFile(id), then show Image.file in existing full image preview pattern;
allow zoom/full image and avoid remote thumbnail/auth for offline local preview.
All completed entries need distinct in-app open and existing system open choices.
Add localized labels/errors in ARBs; no raw backend codes as user-facing text.

## Files

`fileRecentDirectoriesProvider` in file_bookmarks_provider.dart gives last20 valid
directories for current server. Record is automatic after successful list. Reuse
current bookmark panel/dialog for a recent section; no extra global destination.

`SftpNotifier.retryFailedBatch(action, originalItems, previousResults,
 expectedServer: originalServer, targetDirectory: originalTarget, onProgress: ...)`
retries ONLY failed paths, revalidates source size/type/mtime and server identity.
Show an explicit retry-failed action on batch result dialog; keep the original
action/target/items/server snapshot. Merge retry results by path, preserve successes.
Do not replay succeeded deletes/copies/moves or clear selected unrelated rows.
Existing transfer recovery controls are retained, not replaced.

## Application center

ApplicationDeployment.services: list of ApplicationServiceHealth(name,state,health).
Structured Docker state; health 'none' means no healthcheck, not healthy. Show per
service status in detail. Existing refresh/reconciliation retrieves it.
ApplicationOperationPlan.availableBytes: free bytes in existing parent filesystem
of dataRoot, null for non-install/config/update operations. Show measured space,
not estimated requirements. Existing environment architecture, port/mount checks
should be visible as preflight/confirmation summary (no fabricated pass state).
ApplicationOperationPlan.changedSections: image/ports/volumes/environment/
healthcheck/restart/services. Show localized update comparison categories, versions
from existing deployment/catalog, never environment secret values.
Manual catalog refresh + explicit update confirmation only, no automatic pull or
deployment. Errors APP_CENTER_DISK_CHECK_FAILED/FULL, APP_CENTER_HEALTH_INVALID.

## Finish

Notification follow-up: NAS downloader uses existing DownloadPlatformService.report
with target='nas', states running/paused/completed/failed/canceled. Existing Android
DownloadChannel currently assumes all non-update taps open remote-file transfers.
Extend your whitelist ONLY for NAS notification tap routing in DownloadChannel.kt,
MainActivity.kt and lib/features/shell/main_shell.dart, preserving other handlers.
Tap must open NAS offline/download list (including cold start), not remote-file
transfers; don't auto-play or bypass local integrity gate. Reuse existing event
channel + pending-action pattern. Experiment disabled should route settings safely
rather than silently enabling NAS. Do not change layout outside scoped NAS routing.

Report touched UI files and known missing APIs. Responsive 320dp/large font/RTL,
themes, offline without active source, no duplicate global nav/title/player.

## Phase B Implementation Status (Authored, Unverified by Tests/Build)

- [x] **NAS Bounded Home & Offline**:
  - `nasHomeProvider` consumed in `NasMediaView` across `continueWatching`, `photos`, `videos`, and `music` sections. Invalidation wired on scan.
  - `NasDownloadsSheet` displays all persisted/restored tasks (including `paused`), supports `pause`, `resume`, `restart`, `remove` actions with mounted guards.
  - Source changed recovery dialog (`NAS_DOWNLOAD_SOURCE_CHANGED`) offers restart from 0 without clearing partial files.
  - Removal confirms local-only file deletion.
  - `NasImageViewerDialog` supports `localFilePath` with `Image.file` in `InteractiveViewer` for offline zoom.
  - Standalone offline access guaranteed without reachable server/source.
- [x] **Files Recent Directories & Batch Retry**:
  - `FileBookmarksDialog` provides segmented selection for Bookmarks and Recent Directories (`fileRecentDirectoriesProvider`).
  - `RemoteFileBatchResultsDialog` integrates `sftpProvider.notifier.retryFailedBatch(...)`, merges results by path, preserves successes, and retains snapshot parameters.
  - `SftpFileView` subtracts only succeeded items from selection, leaving unselected or unrelated items untouched.
- [x] **Application Center Health, Preflight & Update Comparison**:
  - `AppInstalledTab` renders structured Docker health for `ApplicationDeployment.services` (`healthy`, `unhealthy`, `starting`, `none`).
  - `AppOperationWizardDialog` renders measured disk space (`availableBytes`), preflight checks (architecture, ports, mounts) without fabricated pass states, and update comparison (`changedSections`, versions, no environment secrets).
  - Error resolver maps `APP_CENTER_DISK_CHECK_FAILED`, `APP_CENTER_DISK_FULL`, `APP_CENTER_HEALTH_INVALID`.
- [x] **Notification Routing (Android & Shell)**:
  - `DownloadChannel.kt` sets `EXTRA_OPEN_NAS_DOWNLOADS` for `target == 'nas'` and dispatches `openNasDownloads` on warm start.
  - `MainActivity.kt` tracks `pendingOpenNasDownloads` for cold start and delegates warm intents.
  - `MainShell` consumes `getNasLaunchAction` on startup and listens for `openNasDownloads` method calls.
  - Routes to `NasDownloadsSheet.show(context)` if NAS enabled; routes safely to Settings if NAS experiment disabled.
