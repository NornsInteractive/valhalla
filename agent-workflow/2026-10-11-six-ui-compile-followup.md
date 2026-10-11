# AgY compile follow-up after actual OpenCode checks

Same original Valhalla/model/effort only. Codex does not edit UI. No new keys or
layout changes needed for these concrete fixes.

- `NasThumbnailImage.didUpdateWidget`: actual test failed compilation at
  `_loadThumbnail(widget.item, service)` because coalesced generic read inferred
  nullable service. Also captured old service must not fetch a changed item
  before build watches the new service. After releasing old captured ownership,
  read current nasImageCacheProvider into an explicitly NONNULL
  NasImageCacheService local, capture it and request new item through that
  service. One existing-line correction resolves both type and ownership.
  Do not append `!` to the old-service choice or weaken service-swap behavior.
- SystemView references `context.l10n.stateFailed` twice; that key does not
  exist in any generated localization. Reuse existing `cmdExecutionFailed`
  fallback (or stateError), no new 17-ARB set just for these two sites.

OpenCode will rerun unchanged assertions. Nas lifecycle suite has not executed
any case yet (compile exit1), so do not claim cases passed. Preserve all earlier
draft/route/confirmation/cache fixes and current formatting; tests/core/ARB and
generation/analyze/build/ADB/git are outside this AgY follow-up scope.

Full preliminary report `/tmp/opencode/analyze_prelim.log` adds UI items:
- sftp_file_view.dart missing core/errors/app_exceptions.dart import for
  SFTPException in extracted editor; undefined `isConnected` at file-actions
  popup: read connection state in that method's actual lexical scope.
- dashboard_view.dart redundant lastSnapshot!=null check after hasSnapshot
  type promotion; remove redundant check without changing cached detection.
- nas_media_view.dart and nas_image_viewer_dialog.dart unused dart:io imports.
- system_view.dart four multiline if/return statements need braces and log
  record map null-aware element syntax per current analyzer. Fix UI sites only.
- `test/core/l10n_key_parity_test.dart` failed metadata parity for
  cachedDataNotice: all16 non-en catalogs need @cachedDataNotice placeholders
  with time type String, matching EN. Do not weaken parity test. No translation
  content change needed. OpenCode regenerates afterward, AgY authors ARB only.

Main fixed the nine business-only curly-brace findings in updater/SFTP/system
provider; AgY must not modify those providers. No pass claimed until rerun.

Small NAS hot-path cleanup: do not call File(path).existsSync() on every tile
build. The cache loader already verifies local files asynchronously; Image.file
has errorBuilder for deletion/races. Keep path nonempty check and existing
placeholder/errorBuilder, remove redundant synchronous filesystem stat only.

Ownership correction: preliminary report incorrectly labeled SFTP view missing
import/lexical-variable issues Codex/business. They are UI file changes and MUST
remain with AgY, even when only imports or callbacks are involved.
