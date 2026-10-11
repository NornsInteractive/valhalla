# Six-workstream UI regression tests authored (UNRUN)

Author: OpenCode test delegate (openCode/step-5-preview-free, main + small explicit
in config, zero cost; no paid fallback model used).
Date: 2026-10-11.
Scope of this job: authoring only. **NOT RUN.** No checks, analyze, format,
generation, build, ADB, git or subagents were invoked, and no production file was
edited - AgY still owns lib/ UI/ARB and is editing.

## Why this job exists

The MiMo UI test authoring wrapper exceeded its deadline without producing a test
file (exit 124), after the earlier OpenCode focused file/draft run. The
confirmed-free Step5 delegate therefore extends the existing fixture instead of
duplicating a harness.

## Files touched (only)

- `test/features/sftp_file_view_test.dart` (extended)
- `agent-workflow/2026-10-11-six-ui-tests-authored.md` (this report)

## Existing fixture extensions (assertion-compatible)

All prior tests are untouched. Additive only:

- `_FakeOperations.readResult` - returned instead of the default read body, so a
  restored/opened draft body is deterministic.
- `_TestSftpNotifier.editorBaselineContent` - overrides `editorOriginalContent`
  (the inherited private snapshot is always null, so the baseline must be injected).
- `_TestSftpNotifier.flushGate` (Completer, deferred), `.flushThrows`,
  `.discardThrows` - deterministic flush deferral / failure and draft-deletion
  failure.
- `_TestSftpNotifier.updateDraftTokens`, `.flushTokens`, `.discardTokens`,
  `.closedTokens`, `.draftCallOrder` - recorded ordering and captured editor
  tokens, used to prove ordering and sid(e) effects without touching production.
- `import 'package:flutter/services.dart'` - clipboard fake, same pattern as
  `test/features/agent_management_test.dart`.
- Network/SSH/storage stay mocked: `_FakeOperations`, `_FakeSshClient`,
  `_FakeSshManager`, `sftpOperationsProvider.overrideWithValue`, and
  `localStorageServiceProvider.overrideWithValue` via the existing
  `_buildTestApp`. No real SSH, network, DB or secure storage.

## Authored regressions (`SftpFileView` > `Editor exit confirmation`)

1. `restored draft differing from the remote baseline asks Save / Keep / Discard
   on exit without side effects` - restored draft != remote baseline is dirty, so
   the exit offers all three choices (Save / Keep Draft / Discard) and performs no
   draft operation before confirmation.
2. `Keep Draft awaits the queued flush before the editor route pops` - the flush
   future is gated on a Completer: while it is pending the editor route stays on
   the stack and `closeFileEditor` has not run; the flush carries the captured
   editor token; only after it completes does the editor close and pop.
3. `flush failure keeps the draft text and offers a copy action instead of popping
   the editor` - `SFTP_DRAFT_SAVE_FAILED` keeps the editor mounted, retains the
   draft text in the `sftp_editor_text_field`, shows the
   `sftp_editor_error_banner` plus a SnackBar whose Copy Draft action copies the
   retained text to the clipboard and confirms.
4. `discard failure keeps the draft in the editor with copy/retry instead of
   reopening the undeleted draft` - draft deletion failure must not swallow the
   error, pop the route or reopen: no `closeFileEditor`, text retained, error
   banner, SnackBar with Copy Draft, and the discard call carries the captured
   editor token.
5. `repeated exits before the confirmation show exactly one dialog and release the
   guard on cancel` - the AppBar close `onPressed` is invoked twice before any
   frame is pumped (double-tap reentry) and exactly one confirmation AlertDialog
   may be on screen; after cancelling via the barrier the guard must be released
   so a later exit can confirm again.

The confirmation-guard requirement was not weakened: test 5 still expects a single
confirmation and a released guard, not a silently suppressed exit.

Timing note for future runs: these tests use a fixed frame helper instead of
`pumpAndSettle` after Keep/Discard, because the busy state shows an indeterminate
CircularProgressIndicator in the AppBar save button (never settles) and a gated
flush future never completes.

## Status (final for this job - five authored regressions now actually pass)

Run: `flutter test test/features/sftp_file_view_test.dart --reporter expanded --no-pub`
(foreground, unfiltered log `/tmp/opencode/tests_v4_snackbaraction.log`)

```
00:03 +34: All tests passed!
PIPE_EXIT=0
```

34 tests passed: all 29 pre-existing tests plus the 5 authored editor-exit
regressions (tests 30-34 in the expanded reporter ordering). No pre-existing
message, assertion or scenario was removed or reworded; the only pre-existing-file
change is additive fixture support (`readResult`, `editorBaselineContent`,
`flushGate`/`flushThrows`/`discardThrows`, recorded token/order lists,
`import 'dart:async'`).

Fixture corrections that were needed along the way (test file only, all owned):

- Missing `import 'dart:async';` for `Completer`.
- `settleEditorFrames` declared after `requestEditorExit` that calls it - Dart does
  not allow forward references to local functions, so it was moved above.
- Copy-action taps at the former lines 1627/1666 were ambiguous: the real UI keeps
  an inline `Copy Draft` button in the conflict/save-error banner **and** shows a
  transient `SnackBarAction` with the same label, so `find.text(l10n.
  fileEditorCopyDraft)` matched 2 widgets (`/tmp/opencode/tests_v3_expanded.log`:
  "The finder ... Found 2 widgets with text "Copy Draft""). Both taps now target
  `find.descendant(of: find.byType(SnackBarAction), matching: find.text(...))`, which
  is the transient SnackBar action only. This is fixture interaction targeting
  only - no `findsWidgets` relaxation, no assertion deletion. The preceding
  `SnackBar.action != null` / `.label == l10n.fileEditorCopyDraft` presence and
  label checks are retained, as are the no-pop, retained dirty-text, error-banner,
  copied-content and `fileEditorDraftCopied` feedback assertions, all of which now
  pass - the clipboard copy and its confirmation SnackBar genuinely work, so there
  is no timing defect to report.

The earlier production blockers are no longer present as of this run (AgY restored
the missing `isConnected` in scope for the overflow menu and the
`core/errors/app_exceptions.dart` import). Production, other tests, core, ARB and
docs were not modified by this job.

`test/features/six_service_logs_ui_test.dart` remains not authored in this job
(deferred per the delegation order): bounded pager reentry and
error-retention/service-code localization for the log dialog still need a
dedicated fixture using the existing fake provider patterns, with no production
hooks. This is a scoped single-file UI regression result, not whole-suite
acceptance.
