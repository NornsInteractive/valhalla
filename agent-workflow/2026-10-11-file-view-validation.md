# 2026-10-11 SFTP file view — UI validation (tests only)

Scope: validate the latest remote `SftpFileView` / `SftpState.viewMode` work. Tests only,
no production edits. Production owned by AgY/Codex.

## Command

`flutter test test/features/sftp_file_view_test.dart`

Result: **29 passed / 0 failed** (pre-existing 20 + 9 new).

`dart analyze test/features/sftp_file_view_test.dart` — no issues. `dart format` applied.

## New coverage

### View mode (list / grid) — widget level, 400x800 surface
- `mobile defaults to list and toggles to grid and back`
  - `viewMode == null` + width < `LayoutBreakpoints.compactMax` (600) renders `ListView`, no `GridView`.
  - Tapping `Key('sftpToggleViewModeButton')` yields `GridView` and `getFileViewMode() == 'grid'`;
    tapping again returns to `ListView` and `'list'`.
- `toggle button tooltip reflects the next action`
  - list state → tooltip `sftpViewModeGrid` + `Icons.grid_view`; after tap → `sftpViewModeList` + `Icons.view_list`.

### Hidden file de-emphasis
- `hidden title and icon are subdued, menu icon stays normal`
  - `.env` title color == `onSurface @ 0.62`; icon == `onSurface @ 0.55` (alpha < 1).
  - Visible `notes.txt` title alpha greater than hidden; its icon color is null (theme default, no dimming).
  - `Icons.more_vert` color identical between hidden and visible rows (null in both).
- `hidden directory icon uses subdued primary and checkbox styling matches visible rows`
  - `.git` folder icon == `primary @ 0.6`; `html` == full `primary`.
  - Long-press to enter selection: both rows' `Checkbox` share identical `activeColor` / `checkColor` /
    `fillColor` / `side` — selection control is not de-emphasized for hidden entries.

### View mode persistence — isolated per-test SharedPreferences mock
Group `setUp` resets `SharedPreferences.setMockInitialValues({})` per test so the global
`valhalla_file_view_mode_v1` pref cannot leak between cases. Uses a private `ProviderContainer`
with `_FakeSshManager` (in-memory `SSHClient`), `_ActiveServerWithProfile`, connected notifier,
and `_FakeOperations`.
- `setViewMode writes the pref and updates state` — state starts null; `setViewMode(grid)` writes
  `'grid'` and state becomes `SftpViewMode.grid`.
- `build restores the persisted mode when the notifier rebuilds` — pref `'grid'` pre-seeded;
  initial build and post-`container.invalidate(sftpProvider)` rebuild both restore `grid`.
- `unknown persisted value falls back to null (layout decides)` — pref `'table'` → `getFileViewMode()`
  null → `viewMode` null, i.e. width decides.
- `failed write keeps the current mode and surfaces an error code` — `_FailingViewModeStorage`
  (overrides `setFileViewMode` to throw `StorageException`): `viewMode` stays null and
  `errorMessage == 'SFTP_VIEW_PREFERENCE_SAVE_FAILED'`.
- `failed write shows the localized snackbar and keeps the list` — widget level: tapping the toggle
  surfaces `sftpViewPreferenceSaveFailed` and the layout stays a `ListView` (no optimistic grid).

## Notes
- `_buildTestApp` gained an optional `storage` parameter (defaults to the file-wide `_storage`) so
  persistence cases can pin their own `LocalStorageService` through `localStorageServiceProvider`.
- Test doubles added: `_FakeSshClient`, `_FakeSshManager`, `_FailingViewModeStorage`.
- `flutter gen-l10n` was NOT run (concurrent unrelated string work by AgY).
- Not run by instruction: full suite, builds, ADB.