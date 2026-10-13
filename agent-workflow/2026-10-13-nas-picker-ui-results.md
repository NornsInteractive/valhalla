# NAS picker UI completion — direct-team authorization

The user authorized this round's UI work directly. This report covers NAS source,
scan, and media deployment picker callers only; the common browser and main file
page have separate owners. No production source, remote server, app installation,
Git commit, push, or release was changed by this task.

## Changes

- `nas_source_dialog.dart`: current draft credentials open the common browser
  without saving/selecting/scanning. WebDAV browsing uses endpoint root `/`;
  SMB stays in its share; media libraries use opaque IDs instead of paths.
  Selected library names are display state only. All libraries is the explicit
  `/` option. Credential identity changes clear acquired login token/user ID;
  revision guards reject late authentication or browser results. Cursor/focus
  changes do not falsely revise the draft.
- Saved SMB domain initialization gates save/browse/probe; a failed read blocks
  submission until the existing probe action retries the domain read. Renaming
  the source does not discard its saved domain. Explicit clearing submits empty
  domain and does not silently restore old credentials.
- `nas_scan_config_dialog.dart`: shared include/exclude browsers use saved-source
  adapters, with host-factory fallback only for correctly bound legacy SFTP.
  Media include selection replaces the all sentinel; all is exclusive and is
  not offered/accepted for new exclusions. Existing legacy exclusions are kept.
  Selection names remain separate from opaque IDs. Unavailable saved library
  IDs remain visible and removable, not silently dropped by a refreshed list.
  Cancel does not change lists. Directory sources add one directory per modal.
  Existing manual path/ID entry remains available and does not autofocus.
- `nas_native_install_dialog.dart` and `nas_install_dialog.dart`: media paths
  use the same host picker. Legacy data-root browsing selects an existing parent
  while preserving the entered destination leaf. Missing initial directories
  use the common browser's not-found-only ancestor fallback. Target changes and
  form changes discard stale selections; a non-active selected server is not
  silently browsed through the active server.
- `nas_localizations.dart`: new browse error entrypoints map known codes; unknown
  browse errors show a generic localized failure instead of raw credential-bearing
  exceptions. Existing incomplete-save guidance already requires re-entry/save.
- All 17 ARB catalogs have `nasAllLibraries`; `flutter gen-l10n` succeeded.

## Verification

- Targeted analysis of the five UI/localization files, four test files, and
  `test/support/nas_browser_fixture.dart`: **no issues**.
- `nas_browser_selection_ui_test.dart`: **14 passed, 0 failed, 0 skipped**.
  Log: `/tmp/valhalla-nas-picker-ui-caller-final.log`.
- `nas_install_dialog_test.dart` (12), `nas_native_install_dialog_test.dart` (10),
  and `nas_media_view_test.dart` (57): **79 passed** in the final combined run.
  Log: `/tmp/valhalla-nas-picker-ui-final2.log`. That run also had one caller-test
  finder failure: the error Snackbar existed on both the underlying scaffold and
  the modal. Restricting the assertion to the hit-testable Snackbar fixed the
  fixture; the complete 14-case caller file then passed as recorded above.
- Thus **93 current cases have passed across those runs**, not an assertion that
  the earlier combined run was fully green. Prior earlier all-green run had 92
  cases before the final manual-all exclusion test was added.
- New deployment tests confirm shared picker usage, missing ancestor fallback,
  destination-leaf retention, cancellation, disposal, and no installation or
  preflight mutation. Old NAS regressions include 320dp/2x text, Arabic RTL, and
  desktop dialogs.
- Shared-browser completed subscription cancellation crosses the widget fake
  clock. The fixture explicitly yields real zero-duration futures before waiting
  for frames; directory/path assertions are retained, not bypassed.

## Scope and remaining validation

No build or ADB test was performed by this task; the parent owns the final full
analysis/test/build/install/device gates. Names are intentionally not persisted;
saved unknown library IDs remain readable as IDs until a browser refresh supplies
their names. No cross-store credential transaction, background scan, or automatic
server installation was introduced.

## Read-only review follow-up: scan draft target identity

The parent found that checking only the selected source ID allowed an open scan
configuration to save after that same source ID acquired new endpoint/root/user
or credentials. The dialog now captures the original immutable saved source and
requires selected-object identity plus source ID for both browsing and saving.
Legacy host scans bind the original NAS server ID and active host connection key.
No metadata schema or provider persistence behavior changed.

A regression picks a media library, replaces the selected source with an equal-
metadata fresh object (the credential-only-save shape), and verifies that neither
another browse nor the stale save proceeds. The caller file now has **15 tests**.
Together with the existing NAS view file, **72 passed, 0 failed, 0 skipped**;
`/tmp/valhalla-nas-source-identity-regression.log`. Both changed files analyze
without issues. Prior deployment tests are unaffected (22 cases); the total
current NAS caller/view/deployment set is now 94 cases across the recorded runs.

## ADB-discovered media load follow-up

The parent observed an empty media list and `NAS_LIBRARY_LOAD_FAILED` after
installation, with a previously scanned three-item test source. Read-only
inspection found `NasNotifier.refresh` awaited remote playlists before querying
the local index. A real SQLite-backed regression reproduced exactly an empty
visible list and that error while repository totals/query still returned three
items; only the optional remote playlist lookup threw a network error. This is
proven as a code-level failure path, not a claim that the device's swallowed
original exception was recovered. Existing six index/migration tests passed;
there was no evidence to alter SQL or delete/rebuild the device index.

With parent approval, `nas_provider.dart` now displays the local page without
awaiting remote playlists. A separate, caught refresh preserves known playlists
and checks both epoch and source-object identity before applying results/errors.
It reports `NAS_PLAYLIST_LOAD_FAILED` without overriding an existing error.
An ordinary refresh retries it; local index failures retain the original error.

Only this new code is specially mapped in `nas_media_view.dart`: a friendly
17-language notice says the saved media **list** remains available, and provides
a refresh button. It does not claim remote original files can play offline.

Proof:
- Red reproducer: `/tmp/valhalla-nas-load-diagnostic-red.log`.
- Cold-start remote failure, indefinitely pending playlist response versus local
  refresh completion, preserving known lists with retry recovery, and late
  old-source error isolation: four new provider regressions.
- A new 320dp widget regression checks the localized notice is not mislabelled
  as scan failure, the retry callback runs, and the media list remains intact.
- Provider/organization, index, NAS view and localization parity combined:
  **97 passed, 0 failed, 0 skipped** in
  `/tmp/valhalla-nas-load-final2-tests.log`.
- The changed provider/view and both tests analyze without issues. Final wording
  was clarified from cached media to saved media list after this combined run;
  keys/API are unchanged and generation, parity and the banner test were rerun.

No device, server, source configuration, or index file was changed by this
follow-up. Parent owns final repackaging and ADB acceptance.
