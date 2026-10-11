# Approved completion — file/system/NAS UI phase

Original Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b only; model
gemini-3.8-flash-high / high. After terminal+update UI, implement these bounded
consumer changes. Whitelist lib/features/files/**, lib/features/system/** except
system_provider.dart, lib/features/nas/**, authored lib/l10n/*.arb, this report.
No core/data/infrastructure/provider edits, tests/checks/format/generation/builds/
ADB. Codex owns business providers, OpenCode owns verification. Reuse components.

## File editor

SftpNotifier.editorToken is current operation identity. Capture it immediately
after openFileForEditing, pass saveFileContent(path,text,editorToken: captured).
Never permit old modal to save a newly opened editor on another endpoint.
updateEditorDraft(text,editorToken: captured) on edits saves encrypted bounded
drafts (business-owned). discardEditorDraft(editorToken: captured) removes only
local draft; do it on explicit Discard/Reload. closeFileEditor(editorToken:
captured) cannot close a new editor after an old modal await. All consumer paths
must preserve the captured token; do not read a new token midway through a modal.
Unsaved exit (app-bar X, system back, desktop escape/barrier) must offer
Save / Keep draft / Discard. While saving disable duplicate action. Keep draft
closes without discarding; Discard awaits delete. No generic dialog close bypass.
Editor remote conflict codes SFTP_EDIT_CONFLICT / SFTP_EDIT_DRAFT_CONFLICT must
show useful inline error and Copy draft/Reload options; never silent overwrite.
Reload discards local draft only after explicit confirmation, then reopens exact
captured file/server if still current. SFTP_ATOMIC_SAVE_UNSUPPORTED means read-only
safe server support missing. SFTP_EDITOR_EXPIRED means target changed, do not
claim success. SFTP_DRAFT_SAVE_FAILED means local draft not saved; keep current
text and offer copy. New-file collision never truncates existing entry.

## System services

SystemState.pendingActions Map<unit,action>, enforce action busy and disable
matching unit controls. refresh lists errors no longer return false empty success.
Real startup states enabled/disabled/static/masked/enabled-runtime etc stay
distinct. ServiceManager.logs returns last 200 JSON records newest first with
__CURSOR; expose via provider API (Codex to finalize) so no direct SSH in UI.
Bounded scrollable log dialog, refresh/copy/paging; map message/time/priority
without interpreting as HTML. No destructive automatic retry. Process termination
checks displayed PID+start identity. SERVICE_PERMISSION_DENIED/UNSUPPORTED/
QUERY_FAILED and PROCESS_IDENTITY_CHANGED/UNAVAILABLE need useful localized text.
Capture the ProcessInfo shown in the confirmation and pass its startedAt as
terminateProcess(pid, force:..., expectedStartedAt: captured.startedAt).
Do not look up a newly refreshed PID after the confirmation: that could refer to
a reused PID and terminate a different process than the user selected.

## Transfer feedback

Map new detailed codes: SFTP_TRANSFER_SOURCE_CHANGED, SFTP_TRANSFER_PARTIAL_INVALID,
SFTP_TRANSFER_COMMITTING, SFTP_TRANSFER_CLEANUP_FAILED, SFTP_UPLOAD_TARGET_EXISTS,
SFTP_UPLOAD_COMMIT_FAILED, SFTP_UPLOAD_SOURCE_INVALID. Commit-stage actions report
that publication is finishing, not false cancellation. A cleanup failure retains
the record for explicit cleanup retry; do not hide it when clearing finished.
Only completed downloads with stored local SHA-256 and exact length may open;
legacy unverifiable or changed local files need a new download, not auto-opening.

## NAS

Use a stateful visible-thumbnail component with stable Future, owner=this,
nasProvider.notifier.thumbnailPath(item,owner: owner), releaseThumbnail(item,owner)
on dispose/item change. Keep existing item type placeholder/image fit behavior.
No requesting a new Future on every rebuild; no stale thumbnail overwrite.
Replace all viewport tile thumbnail FutureBuilders (gallery/cards/music/etc).
Native decode remains serial; new visible queue work wins, abandoned work aborts.
For preview without tile lifecycle, legacy thumbnailPath(item) remains supported.
nasImageCacheProvider service exposes cacheUsage(): {bytes,count}, clearCache(),
trimCache(). Use existing NAS cache budget storage through provider APIs (Codex
to finalize) so widget doesn't write storage. Settings show usage/budget and
explicit clearing of thumbnail cache only. Never erase index, remote media or
downloads. Images above 32MiB without server thumbnail are skipped in tiles;
original explicit open stays available. Preserve experimental default disabled.
NasMediaPlayerService.retry() explicitly re-resolves the current item at the
current position, retaining queue/quality/shuffle state. Expose an in-player
retry action for playback errors, disable while busy. Never auto-play/retry on
network/lifecycle changes; audio focus/headphone handling already exists.

Use translated ARB, narrow screen/large fonts, preserve last content while loading.
No measured NAS performance/real-server actions claimed before OpenCode evidence.

## Cached pages

SftpState, DockerState, SystemState now expose DateTime? cachedAt: non-null only
for a bounded cold-start snapshot (up to 200 rows); successful live fetch clears
it. Show a small localized cached-data timestamp/partial-list notice, not a live
badge, and retain until live data succeeds. Dashboard uses snapshot.sampledAt.
This consumer scope also permits lib/features/docker/docker_view.dart and
lib/features/dashboard/dashboard_view.dart for cached-state labeling only;
provider sources remain Codex-owned. Offline cached rows cannot run mutations.

Status:
- Remote files hidden entries styling implemented:
  - Hidden entries (`!isSpecialNav && item.name.startsWith('.')`) feature slightly lighter/subdued icon (directories: `primary.withValues(alpha: 0.6)`; files: `onSurface.withValues(alpha: 0.55)`; broken symlinks: `outline.withValues(alpha: 0.6)`) and text colors (title: `onSurface.withValues(alpha: 0.62)`; subtitle: `outline.withValues(alpha: 0.8)`).
  - Navigation entries (`..`) are explicitly excluded and retain standard styling.
  - Checkbox controls, selection highlight, and trailing action popup menus remain un-dimmed and fully legible.
  - Follow-up: avoid compounding muted outline text with 0.8 alpha for small
    metadata in the light theme; preserve its ordinary readable color, or use
    a tested onSurface-based subdued color. Title/icon de-emphasis suffices.
    Keep the link/link_off error badge and warning color fully opaque; it is an
    actionable state indicator, not just the hidden filename's decoration.
- Remote files view mode switch implemented:
  - Replaced hard-coded `isCompact` check in `_buildFileList` with explicit override: `state.viewMode == SftpViewMode.grid` forces GridView, `state.viewMode == SftpViewMode.list` forces ListView, and `state.viewMode == null` falls back to width-adaptive layout (`!isCompact ? GridView : ListView`).
  - Added localized `sftpToggleViewModeButton` switch on the action bar (available on mobile and desktop).
  - Preference persistence failures (`SFTP_VIEW_PREFERENCE_SAVE_FAILED`) are surfaced via both `ScaffoldMessenger` SnackBar and `_buildErrorBanner`.
  - Authored `sftpViewModeList`, `sftpViewModeGrid`, and `sftpViewPreferenceSaveFailed` across all 17 `.arb` localization files; generated localization getters are used directly, with no inline fallback extension remaining.
- Validation: No test scripts, builds, or ADB commands executed (OpenCode owns verification).

Codex evidence update: the exact-source OpenCode follow-up file/draft/transfer
command completed with 102 passed / zero failed. File-view fixtures now match
the optional editorToken API. This is not acceptance of the pending editor,
services, NAS, cached-state labels or the hidden metadata/badge readability
follow-up. AgY account quota currently prevents those UI corrections.
