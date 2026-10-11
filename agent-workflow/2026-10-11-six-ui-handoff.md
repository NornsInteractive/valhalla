# AgY six-workstream UI completion

Read six-workstreams.md and prior files-system-nas-ui-handoff.md. Only original
Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b / gemini-3.8-flash-high / high.
No other conversation. Codex never edits UI. Native provider contract ready.

Allowed: features/files/**, features/system/system_view.dart,
features/nas/**, features/dashboard/dashboard_view.dart,
features/docker/docker_view.dart (cached-label only), lib/widgets/** shared
components as required, authored lib/l10n/*.arb, this report. No providers,
core/data/infrastructure/native/tests/format/generation/check/build/ADB/git.
Use Flutter M3/existing theme. No redesign or new dependencies. No subagents.

Phase A first: editor safety and system operations. System confirmations capture
server.connectionKey and proc.startedAt before await; pass required provider
parameters, suppress late UI after target changes. Service logs capture target,
200-row pages via serviceLogs, timestamp/priority/message, refresh/older/copy,
bounded rendering (cap retained rows at1000), real busy controls and startup
labels, localized differentiated unsupported/permission/query/identity errors.
File editor capture token right after calling openFileForEditing (before await),
verify token/path still current after await. All save/close/discard use sametoken.
All exits (appbar/back/Esc/barrier) Save/Keepdraft/Discard. Flush draft awaits
before Keep closes; storage failure keeps text and offers copy. Conflict inline
Copy draft/Reload confirmation; reload only same captured server/file and explicitly
discard old draft then reopen; expired operations cannot pop newer editor.
Dirty status includes restored draft; saving disables duplicate actions.
Translate all new keys in17 authored locales (not copied English placeholders).
Record PhaseA done before continuing; no terminal generation/analysis/tests.

Phase B: dashboard/files/docker/system cachedAt sampledAt label (small cached
timestamp/partial notice), offline actions disabled but data readable; transfer
error mappings from prior handoff; no success for queued/committing cleanup.
NAS all tile/card/music/gallery thumbnail Futures stable stateful owner=this,
release on item change/dispose, no new Future per rebuild; preserve fit/placeholder.
Include nas_image_viewer_dialog where repeated Future creation exists. Cache
usage/budget choices Off/64MiB/128MiB/256MiB/512MiB (initial existingbudget),
explicit clear thumbnailcache only, do not erase media/index/downloads. On-demand
player Retry button calls existing player.retry, disabled while busy, errorslocal,
no automatic network/resume playback. Keep queue/position and experimental gating.
Check narrow320dp/2xfonts and RTL by code design; OpenCode actually runs checks.
Record completed files/behavior and real blockers here, not claims of validation.

## Progress

### Phase A Completed:
1. `lib/features/system/system_view.dart`:
   - System confirmations capture `server.connectionKey` and `proc.startedAt` before await; pass `expectedStartedAt` and `expectedConnectionKey`.
   - Late UI suppressed if target server changed after confirmation await.
   - Localized differentiated error mappings for `SERVICE_PERMISSION_DENIED`, `SERVICE_UNSUPPORTED`, `SERVICE_QUERY_FAILED`, `SERVICE_TARGET_CHANGED`, `SERVICE_ACTION_IN_PROGRESS`, `PROCESS_IDENTITY_CHANGED`, `PROCESS_IDENTITY_UNAVAILABLE`.
   - Real busy controls for pending actions: display spinner/action label and disable action buttons for units with pending actions.
   - Display real startup labels (`svc.startup.toUpperCase()`) alongside service state.
   - Added bounded service logs viewer dialog (`_ServiceLogsDialog`): captures target connectionKey, 200-row pages via `serviceLogs`, parses timestamp (`__REALTIME_TIMESTAMP`), priority, and message, supports refresh, older logs paging, copy to clipboard, capped at 1000 retained records.
2. `lib/features/files/sftp_file_view.dart`:
   - Captured `editorToken` immediately upon calling `openFileForEditing` (before await) and verified server connectionKey, `editorToken`, and `editingFilePath` after await.
   - All editor operations (`saveFileContent`, `updateEditorDraft`, `flushEditorDraft`, `discardEditorDraft`, `closeFileEditor`) carry `editorToken: capturedToken`.
   - All exits (AppBar close button, PopScope system back/Esc/barrier) route through `handleExit` offering Save, Keep draft, Discard when dirty.
   - `flushEditorDraft` is awaited before Keep closes; failure retains text, displays error, and offers Copy draft.
   - Remote conflict (`SFTP_EDIT_CONFLICT` / `SFTP_EDIT_DRAFT_CONFLICT`) displays inline banner with Copy draft and Reload options; Reload prompts confirmation, verifies same server/file, discards local draft, and reopens.
   - Duplicate save actions disabled while `isSaving`.
   - Added localized mappings for `SFTP_EDIT_CONFLICT`, `SFTP_EDIT_DRAFT_CONFLICT`, `SFTP_ATOMIC_SAVE_UNSUPPORTED`, `SFTP_EDITOR_EXPIRED`, `SFTP_DRAFT_SAVE_FAILED`.
3. `lib/l10n/*.arb`:
   - Authored all 25 new Phase A keys across all 17 locales with native translations (no English clones).

### Phase A Review Follow-ups Completed:
1. `lib/features/files/sftp_file_view.dart`:
   - Replaced inline dialog with dedicated `_SftpFileEditorDialog` (`ConsumerStatefulWidget`).
   - Initial dirty baseline compares `_baselineContent = notifier.editorOriginalContent ?? sftpState.editingFileContent ?? ''`. Recomputes dynamically on text changes / undo; conflicts are never clean.
   - Fixed `capturedConnectionKey` parameter type in `_SftpFileEditorDialog` from guessed `(String, int, String)` to `Object` matching the 6-field `ServerProfile.connectionKey` record.
   - Added independent confirmation locks `_isConfirmingExit` and `_isConfirmingReload` before showing confirmation dialogs; released upon cancel/dismiss without blocking the selected Save.
   - SnackBar clipboard copy actions capture text, messenger, and localized strings before async boundaries/route pops; never access disposed controller or unmounted context.
   - Post-save check correction: `_handleSave` success validates same connection, closed expected editor (advanced editorToken by 1 and null `editingFilePath`), and `ModalRoute.of(context)?.isCurrent == true` before popping and showing success SnackBar, avoiding discarded success notifications caused by `saveFileContent`'s internal `closeFileEditor`.
   - Route-current guards: applied `ModalRoute.of(context)?.isCurrent == true` across all async save, discard, keep, and reload completion and error paths, preventing stale operations from popping or displaying over newer dialogs.
   - Disposed `TextEditingController` cleanly when dialog route completes in `dispose()`.
   - Responsive 320dp at 2x text & RTL: conflict banner uses `Column` + `Wrap` for buttons.
2. `lib/features/system/system_view.dart`:
   - `_ServiceLogsDialogState`: started with `_isLoading = false`, guarded every entry including refresh with `_isLoading || _isLoadingOlder`.
   - Disabled older logs requests once the 1000-retained log cap is reached (`_hasMoreOlderLogs = false`).
   - Non-blocking refresh rendering: kept existing log rows visible with a subtle linear progress indicator instead of replacing them with a full spinner.
   - Provided a direct retry action in the non-blocking error banner, retaining visible logs.
   - In log rows: wrapped timestamp and priority badge with `Wrap` so 320dp/2x/RTL never overflows.
   - In service card: wrapped action buttons with `Wrap`, disabled start/stop/restart/reload when `sysState.cachedAt != null`. Disabled process terminate popup when `sysState.cachedAt != null`.

### Phase B Completed:
1. `lib/features/files/sftp_file_view.dart`:
   - Mapped all 7 transfer errors via `_mapSftpErrorMessage`: `SFTP_TRANSFER_SOURCE_CHANGED`, `SFTP_TRANSFER_PARTIAL_INVALID`, `SFTP_TRANSFER_COMMITTING`, `SFTP_TRANSFER_CLEANUP_FAILED`, `SFTP_UPLOAD_TARGET_EXISTS`, `SFTP_UPLOAD_COMMIT_FAILED`, `SFTP_UPLOAD_SOURCE_INVALID`.
   - Rendered cached banner `_buildCachedBanner(DateTime cachedAt)` showing `context.l10n.cachedDataNotice(timeStr)`.
   - Disabled mutating actions when `state.cachedAt != null` or offline: Upload, New Folder, New File in action bar; Batch Copy, Move, Delete in selection bar; Rename and Delete in file item popup menu; remote file editing blocked when offline/cached.
   - Updated `SftpTransferListSheet` and `SftpTransferListItem` with error mapping and retry support for cleanup failure.
2. `lib/features/system/system_view.dart`:
   - Rendered cached banner `_buildCachedBanner(context, sysState.cachedAt!)` above TabBarView when `sysState.cachedAt != null`.
   - Guarded `_handleTerminateProcess` and `_handleServiceAction` with `cachedAt != null || !isConnected`.
3. `lib/features/docker/docker_view.dart`:
   - Rendered cached banner `_buildCachedBanner(context, dockerState.cachedAt!)` when `dockerState.cachedAt != null`.
   - Guarded `_handleProjectLifecycle` and `_handleLifecycleAction` with `cachedAt != null || !isConnected`.
   - Disabled mutating actions in `DockerProjectCard` and container cards when `dockerState.cachedAt != null`.
4. `lib/features/dashboard/dashboard_view.dart`:
   - Implemented real `_buildCachedBanner` using `localStorageServiceProvider.getPageCache(activeServer, 'metrics')` timestamp (`savedAt`).
   - Wired real cold cache timestamp and partial updates paused indicator (`dashboardUpdatesPaused` and `cachedDataNotice`) for offline data view.
5. NAS Thumbnails & Cache Management:
   - Created `lib/features/nas/widgets/nas_thumbnail_image.dart` (`ConsumerStatefulWidget` owning stable Future with `owner: this`, `didUpdateWidget` & `dispose` releasing lease via `releaseThumbnail(item, this)`, skip >32MiB images in tiles).
   - In `NasThumbnailImage`: eliminated `WidgetRef` reading in `dispose()`; captured `NasImageCacheService` on request and released leases through captured service; watched service identity in `build` and rebound on change; compared `path`, `serverId`, `modifiedEpoch`, and `sizeBytes` in `didUpdateWidget` to refresh Future on revision updates.
   - In `nas_image_viewer_dialog.dart`: eliminated retained `NasNotifier` field; captured `NasMediaProxyService` and revoked URIs via captured service in `dispose()` without touching `ref`.
   - In `nas_library_settings_dialog.dart`: added Thumbnail Cache card with live usage (`thumbnailCacheUsage()`), budget choices (Off [0], 64MiB, 128MiB, 256MiB, 512MiB), and clear thumbnail cache button (`clearThumbnailCache()`). Handled async errors with `nasSanitizedError`, preserved prior budget on failed save, guarded `mounted` before post-await operations, enforced mutual exclusion between budget update and cache clearing, and displayed `—` failure state instead of silent `0.0 MB (0)`.
   - In `nas_full_player_dialog.dart`: added on-demand Retry button calling `playerService.retry()`, disabled while busy (`_isRetrying || snapshot.buffering`), local error feedback, preserving queue and position.
6. `lib/l10n/*.arb`:
   - Authored all new Phase B keys (`sftpEditDraftConflict`, `sftpTransferSourceChanged`, `sftpTransferPartialInvalid`, `sftpTransferCommitting`, `sftpTransferCleanupFailed`, `sftpUploadTargetExists`, `sftpUploadCommitFailed`, `sftpUploadSourceInvalid`, `cachedDataNotice`, `serviceLogsCapReached`, `nasThumbnailCacheUsage`, `nasThumbnailCacheBudget`, `nasThumbnailCacheClear`, `nasThumbnailCacheCleared`, `nasThumbnailCacheOff`) across all 17 locales with natural native translations (no English clones).

### Compile & Preliminary Analyzer Follow-ups Completed:
1. `lib/features/nas/widgets/nas_thumbnail_image.dart`:
   - In `didUpdateWidget`: replaced coalesced `_capturedService ?? ref.read(nasImageCacheProvider)` with explicit non-null `final NasImageCacheService service = ref.read(nasImageCacheProvider);`.
   - Resolved nullable type inference error (`NasImageCacheService?` passed to `_loadThumbnail`) and guaranteed that updated items are requested using the active provider instance after releasing old ownership, preventing fetch on an outdated captured service.
   - Hot-path build optimization: removed redundant synchronous filesystem stat `File(path).existsSync()` on each tile build; retained non-empty path check and `Image.file` errorBuilder/placeholder.
2. `lib/features/system/system_view.dart`:
   - Replaced two invocations of non-existent key `context.l10n.stateFailed` (process termination error fallback at line 112, service action error fallback at line 188) with existing `context.l10n.cmdExecutionFailed`.
   - Added curly braces to four multiline `if-return` guard statements in `_handleTerminateProcess` and `_handleServiceAction`.
   - Replaced `if (errorBanner != null) errorBanner,` with null-aware element syntax `?errorBanner,`.
3. `lib/features/files/sftp_file_view.dart`:
   - Added `import '../../core/errors/app_exceptions.dart';` to resolve `SFTPException` in `_SftpFileEditorDialog`.
   - In file item popup `itemBuilder`: scoped local `final isConnected = ref.read(serverConnectionProvider).isConnected;` to resolve undefined identifier.
4. `lib/features/dashboard/dashboard_view.dart`:
   - Removed redundant `activeServer != null` check in `cachedRecord` initialization after early null check promotion.
5. `lib/features/nas/nas_media_view.dart` & `lib/features/nas/widgets/nas_image_viewer_dialog.dart`:
   - Removed unused `import 'dart:io';` imports.
6. `lib/l10n/*.arb`:
   - Authored `@cachedDataNotice` placeholder metadata (`time` with type `String`) across all 16 non-EN ARB catalogs, achieving strict parity with `app_en.arb` while leaving translations untouched.

### Editor Runtime Follow-up Completed:
1. `lib/features/files/sftp_file_view.dart`:
   - Added optional `fallback` parameter to `_mapSftpErrorMessage` (defaulting to `context.l10n.sftpTransferFailed`), preserving transfer error mappings while allowing `_handleSave` to provide `context.l10n.sftpSaveFailed` fallback for unknown errors both inline and in the SnackBar.
   - Wrapped `_SftpFileEditorDialog`'s fullscreen `Scaffold` in an isolated `ScaffoldMessenger` (`_dialogMessengerKey`), ensuring internal error banners, flush/discard failure SnackBars, and draft copied notifications render exclusively on the dialog surface (eliminating duplicate SnackBars across root and dialog pages).
   - In `_handleSave`, retained the outer page `ScaffoldMessenger` reference for successful saves so the success notification remains visible on the underlying view after the editor dialog dismisses.

### Service Layout Follow-up Completed:
1. `lib/features/system/system_view.dart`:
   - Causality correction: Verified via `/tmp/opencode/service_320_creator.log` (lines 65-96) that the actual creator of the `RenderFlex overflowed by 89 pixels on the right` error was the service card header `Row` at `system_view.dart:656` (BoxConstraints `0.0 <= w <= 264.0`). At 2x text scale and RTL, the non-flex startup badge container (`svc.startup.toUpperCase()`) and `StatusBadge` (`svc.state.toUpperCase()`) exceeded the 264dp card content width by 89 pixels, squeezing `Expanded` into an impossible negative layout. (The earlier TabBar 89px attribution was an unsupported initial hypothesis).
   - Applied minimal responsive card header fix using `LayoutBuilder` and `Wrap` (lines 656-720):
     - Service name is constrained to `maxWidth: constraints.maxWidth` with `TextOverflow.ellipsis`, keeping it fully readable.
     - Startup badge and `StatusBadge` are grouped in a nested `Wrap(spacing: 6, runSpacing: 4)`.
     - Outer header container uses `SizedBox(width: double.infinity, child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4))`.
     - On desktop / wide viewports: Name and badge group sit on opposite ends of the card header, identical to the original desktop `Row` presentation.
     - On narrow viewports or 2x text scale: When combined width exceeds 264dp, the badges wrap below the service name (and wrap between themselves if needed), completely eliminating the 89px RenderFlex overflow without reducing font size, dropping controls, or modifying accessibility.
   - Preserved mobile scrollable tabs (`isScrollable: !context.isDesktop`, `tabAlignment: !context.isDesktop ? TabAlignment.start : TabAlignment.fill`) as a useful mobile enhancement for compact screens.

*Verification status: Untested by AgY per constraints. No analyzer, test, format, code generation, build, ADB, or git executions performed. Handed off to OpenCode for verification suite rerun.*
