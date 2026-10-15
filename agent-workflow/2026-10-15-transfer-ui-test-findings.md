# Transfer widget test findings — 2026-10-15

Codex adapted the transfer/file widget tests listed below. All production UI
fixes remained AgY-owned. This final status update is documentation-only;
source and tests are frozen while the root's build/device validation proceeds.

## Resolution and latest evidence

**All known transfer UI findings below are resolved.** Original failures and
reproduction details are retained as an audit trail, not outstanding work.

- Batch 5 focused suite: **73 passed / 0 failed**, including all transfer-list
  cases and notification routing. This covers 320dp/2× English and Arabic,
  same-frame bulk pause/resume duplicate taps, filter counts, pause reasons,
  actions/details, and notification-panel dismissal/deduplication/rebinding.
  Evidence: [direct-batch5-focused.log](/tmp/valhalla-core-experience.ACZJNb/direct-batch5-focused.log).
- Files plus rebuild suite after restoration of the active-transfer-presence
  upload guard: **68 passed / 0 failed**. This covers the retained upload guard
  behavior and transfer start/end updates, file Open/download, and the rebuild
  contracts.
  Evidence: [direct-files-postfix.log](/tmp/valhalla-core-experience.ACZJNb/direct-files-postfix.log).

These results supersede the initial failures below. No tests were started for
this documentation update. Root's final ADB validation is still pending; widget
results are not device, real-network, or background-worker evidence.

## Resolved: 320dp / 2× text overflow

Resolution verified by the passing Batch 5 focused suite, with the original
320dp/2× English and Arabic fixture retained.

Command:

```sh
flutter test --no-pub test/features/sftp_transfer_list_test.dart --plain-name 'compact sheet fits 320dp at 2x text in English and Arabic' --reporter expanded
```

The new retained regression uses a 320 × 1000 logical-pixel viewport,
`TextScaler.linear(2)`, and one network-paused download with 50 of 100 bytes.
It checks English followed by Arabic; the original English failure prevented
Arabic from being reached.

Observed Flutter rendering exceptions in the full transfer-list run:

- Sheet header `Row`, `lib/features/files/sftp_file_view.dart:2674`: **573 px**
  overflow to the right; available width 288 px after horizontal padding.
- Transfer status/size `Row`, same file at line 3209: **112 px** overflow to the
  right; available width 288 px.

Line numbers were captured before subsequent AgY edits and may move. At that
failure snapshot, the header put the title, bulk controls, clear-finished text
button, and close action in a single row. The card put a flexible status label
beside a non-flexible bytes label. The retained test requires usability at the
accepted narrow/large-text settings without suppressing overflow exceptions or
reducing the requested scaling.

## Resolved: bulk-action duplicate tap before rebuild

Resolution verified by the passing Batch 5 focused suite, including both pause
and resume repeated before the busy-state rebuild.

Command:

```sh
flutter test --no-pub test/features/sftp_transfer_list_test.dart --plain-name 'bulk actions suppress repeat clicks until their Future finishes' --reporter expanded
```

The recording notifier holds `pauseAllTransfers()` on a `Completer<void>`. Two
`tester.tap(pauseButton)` calls occur before the next `pump`, reproducing two
input events before the busy-state rebuild. Expected one core call; observed
**two calls** (`sftp_transfer_list_test.dart:432` at this run).

At that failure snapshot, the UI set `_isBulkActing = true` and hid controls on
the next build, but the callback did not check the flag before starting another
operation. Both bulk callbacks needed an immediate guard. The same regression
also double-taps resume after pause completes; the original pause failure
prevented that assertion from being reached. The test releases pending gates
in teardown.

## Initial verification (audit trail)

- Formatted only the two owned widget test files with `dart format`.
- Full transfer-list target initially completed **27 passed / 1 failed**: only
  the 320dp/2× overflow failed. Filter counts, active-first stable ordering,
  canceled exclusion from completed, ordinary bulk busy state, offline resume,
  pause-reason fallback, expanded details, retry, and existing actions passed.
- Strengthened the bulk test to send two taps before a frame, then ran that
  single target: failed with the duplicate-call finding above. The passing
  focused rerun now includes the strengthened regression.
- Rebuild target initially could not compile during concurrent chat UI edits
  (missing `_ChatErrorBanner` and `AppLocalizations.copySuccess`). After those
  definitions were corrected by the UI owner, reran
  `flutter test --no-pub test/features/sftp_transfer_rebuild_test.dart --reporter expanded`:
  **3 passed**. This includes terminal/browser widget identity and expanded
  transfer details surviving sibling progress updates.

The previously pending AgY fixes and transfer-list rerun are complete, as shown
in the latest evidence above.

## Additional file-view/routing verification

The root assigned these existing tests for fixture adaptation after the full
features sweep: `sftp_open_transfers_request_test.dart`,
`remote_files_ui_contract_test.dart`, `multi_column_lists_test.dart`,
`sftp_two_row_header_test.dart`, and `sftp_file_view_test.dart`. Existing dirty
changes were retained; only test selectors/accepted layout expectations changed.

### Resolved: header overflow blocked notification-panel dismissal at 500dp

Resolution verified by the passing Batch 5 focused suite with the 500dp fixture
and strengthened dismissal/routing assertions retained.

```sh
flutter test --no-pub test/features/sftp_open_transfers_request_test.dart --reporter expanded
```

Observed **4 passed / 1 failed**. At 500 × 900 logical pixels and default text
scale, the same header Row overflows **77 px**. The full-sweep log shows the
close-button center at x = 536.8, outside the 500 px viewport, so the tap misses
and `transferEmptyView` correctly remains on screen. This is not a stale
empty-state assertion. The strengthened test requires the close button to be
hit-testable and the entire sheet to disappear after tapping it, while retaining
the notification-request/deduplication/rebind behavior checks. Initial empty UI
also checks the selected All filter and its zero count. Keep the 500dp fixture.

### Resolved: upload guard regression — existing behavior restored

The active-transfer-presence guard was restored. The subsequent files/rebuild
suite passed all 68 cases, including active-transfer removal/reintroduction.

```sh
flutter test --no-pub test/features/sftp_file_view_test.dart --plain-name 'disables upload while keeping download action enabled for continuous queueing when transfer != null' --reporter expanded
```

Confirmed actual failure: expected upload `onPressed == null`, observed an active
`_handleUpload` callback. `_buildActionBar` previously also checked
`state.activeTransfer != null`; at the failure snapshot, `onUpload` checked only connected/cached
state. Root explicitly confirmed continuous upload queueing was **not** approved
and requested that AgY restore the guard. The test preserves download queueing,
Open/download behavior, and no-premature-success assertions. It additionally
checks that removing/reintroducing an active transfer updates the upload guard.
Use an active-presence subscription rather than full progress subscription:
the parent file-view projection deliberately omits transfers to avoid byte-level
rebuilds.

### Fixture corrections and executed result

- Scoped file More selectors to the matching `RemoteBrowserEntryTile`; the new
  toolbar More icon must not intercept file Open/download/menu animation tests.
- New Folder/File now open through New; hidden/sort/refresh through More.
- Kept offline pending hidden-toggle and captured-callback double-submit checks;
  both pass with the menu callback path.
- Kept search/actions vertical separation and 320dp overflow checks. The
  breadcrumb refresh-scroll case now uses three long segments (still scrollable)
  and asserts exact user-offset retention; longer paths intentionally collapse
  their middle segments under the accepted design.
- Ran all four assigned file-view targets together: **93 passed / 1 failed**.
  The only failure was the upload guard above. Row structure, date/permission
  layout, 320dp/2× text, file Open/download, animations, hidden-toggle races,
  and sort selections passed. The original initial-disabled failure prevented
  the later upload start/end assertions from running; those assertions are now
  covered by the passing post-fix files/rebuild result above.
