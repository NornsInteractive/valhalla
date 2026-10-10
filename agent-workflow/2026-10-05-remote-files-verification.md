# Remote files hidden visibility + symlink contract — Phase-1 verification (2026-10-05)

## Authorization / model

- Stage 1 ONLY: read `agent-workflow/2026-10-05-remote-files.md`; no UI/ARB
  formatting, codegen, builds, or trespass into AgY scope.
- Session: bounded OpenCode context `ses_efa045a6bffeBnDODUfPKr6YLw`, legacy
  `ses_f0405efacffePPqWyhHc3GGJY7` preserved. Main+small model
  `opencode/fledge-alpha-free` (confirmed-free fallback metadata, no paid model/
  subagent/ADB/git/keys/credentials ops taken).

## Core diff inspected (root work, root owns logic)

- `lib/core/providers/sftp_provider.dart`:
  - `SftpState.showHiddenFiles` default `false`; `copyWith` preserves it, search
    query, sort key/direction, transfers, and current path.
  - `SftpNotifier.setShowHiddenFiles(bool)` persists first
    (`valhalla_file_show_hidden_v1` prefs key, throws on false write), then
    updates state; injects reason code `SFTP_HIDDEN_PREFERENCE_SAVE_FAILED` on
    storage failure without flipping selection; filtering of cached list is
    local-only (no second `listFiles`).
  - `filteredFiles` rules: `.` removed everywhere, `..` removed at root, hidden
    dot entries excluded unless enabled; `..` always surfaced outside root.
  - Provider loops `canPreview`/`downloadTo`/`_downloadFile`/`openFileForEditing`
    guard unresolved-link reason codes before queueing work.
- `lib/infrastructure/sftp/sftp_client_service.dart`:
  - `SftpFileItem.isSymbolicLink=false`, `linkTargetErrorCode`; unresolved
    targets reported via `SFTP_LINK_TARGET_UNAVAILABLE` /
    `SFTP_LINK_TARGET_PERMISSION_DENIED`.
  - Only symlink entries are followed with native SFTP `stat`, at most**4**
    concurrent stat workers per directory listing; per-entry errors; alias path
    preserved on every produced item; symlink entries keep their entry type +
    `l` permission prefix; `isDirectory` follows the target's resolved type.
  - Existing browse timeout structure (`_bounded`, `_sessionEpoch`) preserved;
    stale listings are gated by `_currentSource(sourceEpoch)`/`_loadEpoch`.

## Tests added (stage 1, focused)

New file `test/core/remote_files_contract_test.dart` (no new production logic
added; mocks/fixtures reused in style):

- `SftpState.showHiddenFiles` defaults false; `copyWith` flipping only the flag
  keeps search/sort/transfers/source path; `SftpFileItem` defaults
  `isSymbolicLink=false` and `linkTargetErrorCode=null`.
- `filteredFiles`: at root it hides dot entries and `..`; enabling shows
  hidden entries but never clones `.`/`..` duplicates. Outside root `..`
  stays visible regardless of the hidden flag.
- `setShowHiddenFiles` success path: prefs boolean set, state updated, second
  `setShowHiddenFiles` immediately reflects filtered list from cached
  `files` (no extra `listFiles` call), search query preserved.
- `setShowHiddenFiles` failure path (`_ThrowingHiddenPrefs.setFileShowHidden`
  throws): state unchanged, errorMessage equals `SFTP_HIDDEN_PREFERENCE_SAVE_FAILED`,
  prefs key remains null.
- Unresolved-link provider guards: `canPreview` returns false for directory and
  for items carrying `linkTargetErrorCode`; `downloadTo` + `openFileForEditing`
  set error code without queueing downloads (no transfer created).
- Service classification: ordinary `file.txt` unstat'd; at most 4 in-flight
  native `stat` calls among symlink entries; symlink `link` accumulates
  `SFTP_LINK_TARGET_UNAVAILABLE` vs `SFTP_LINK_TARGET_PERMISSION_DENIED` paths;
  cyclic link keeps alias path and is treated unavailable rather than navigable;
  resolved `linkdir` becomes directory; raw alias path everywhere (`/var/www/
  my-project/<alias>`); regular entries keep `-` permissions, symlink entries
  keep `l` prefix.
- Source epoch guard: concurrent `loadDirectory('/tmp/a')` + `/tmp/b` then
  stale completion does not clobber `/tmp/b` state or `currentPath`.

## Commands / real exit codes

- `dart format test/core/remote_files_contract_test.dart` → one file changed (mechanical).
- `flutter test test/core/remote_files_contract_test.dart` → `EXIT=0`,
  `All tests passed!` (log: /tmp/opencode/rfiles2.log).
- Model: `opencode/fledge-alpha-free` main+small; no user-server contact, no
  real SSH/SFTP connections, no ADB/dependencies/keys/git writes.

## Defects / inspection findings

- None blocking. `_formatPermissions` derives the `l` prefix from the *entry*
  attr's type (correct and verified); the target's attrs are still honored for
  `isDirectory`/size (modification comes from the link entry), so directory symlinks enter as folders and
  broken/denied links surface the right error code rather than navigating.

## Next (stage 2, blocked)

- AgY UI + ARB additions for hidden toggle + symlink badge/compact breadcrumb.
  My remaining work then: gen-l10n, mechanical format, locale parity
  verification (all 17 catalogs), full locale/settings/navigation focused
  tests, analyze, full `flutter test`, then `flutter build apk --release` with
  development signing and a freshness-checked universal APK backup.
