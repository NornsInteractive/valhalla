# Recovery / terminal history focused widget verification

Initial widget work changed only the two assigned test files, preserving existing
terminal-history test additions. A later device-discovered CLI core fix and its
focused regression proof are recorded below; no UI implementation was changed.

## Earlier software verification — before the device-discovered CLI fix

The recovery layout and target-routing regressions are included in the
**73/73 passing** Batch 5 focused run:
`/tmp/valhalla-core-experience.ACZJNb/direct-batch5-focused.log`.
This is the total for the mixed focused suite, not 73 recovery-only tests.
The Arabic overflow recorded below is resolved; the failed run is retained
as the audit trail rather than the current result.

Terminal history separately completed **18/18 passing**, including the new
320dp / 2× / Arabic RTL grouped-search and keyboard-dismissal regression:
`/tmp/valhalla-core-experience.ACZJNb/codex-terminal-history-rtl.log`.
That case also verifies actual plain/SSH mode despite a requested tmux
preference, and no terminal input or session restore while searching.

Pre-CLI-fix integration status: **3685 passed, 30 skipped**, with zero analysis
issues. That formal 1.0.6+7 APK was built locally and installed through a
data-preserving ADB replacement. These are historical results, not final proof
for the subsequent CLI fix; widget results do not constitute device acceptance.
See the [implementation record](2026-10-15-core-experience.md) for final evidence.

## Initial executed result (pre-fix audit)

```sh
flutter test --no-pub test/features/connection_status_banner_test.dart test/features/terminal_history_ui_test.dart --reporter expanded
```

Initial result: **43 passed, 1 failed**, exit 1; superseded by the passing run above.
Log: `/tmp/valhalla-core-experience.ACZJNb/codex-recovery-history-focused.log`.
The earlier full-tooltip assertion was updated to allow the new `(SSH)` suffix
while still requiring the entire original 64-grapheme title. Old reconnecting
fixtures now distinguish an explicit user disconnect from a missing controller.
Retry fixtures carry matching server, Agent, and session identities.

## Resolved UI defect — original repro and requested fix

The line numbers and behavior below describe the pre-fix source snapshot.

`lib/features/shell/widgets/connection_status_banner.dart:618` lays out the
inline retry button as an unconstrained child of the banner Row (`:633`).
At **320×640 logical pixels, text scale 2, Arabic / RTL**, the failure banner
overflows horizontally by **121 pixels**. The details-opening leading icon is
pushed to x≈408, outside the screen, so this is also an inaccessible action.
The retry TextButton at `:263–275` uses the full translated label without a
width constraint and has a zero minimum size / shrink-wrapped tap target.

Reproducer is checked in at
`test/features/connection_status_banner_test.dart:772`:
`320dp 2x ar long recovery details fit`.
It failed at `:799` on `tester.takeException()` before attempting to open the
dialog. The identical English case passed, including long server / session
names, both non-idle entries, scrolling to CLI retry, and its ≥44dp target.

Requested fix: constrain or wrap the inline retry action inside the banner's
available width (or put it on a second row at constrained widths / large text),
while preserving a ≥44dp action target and the details entry. Do not suppress
overflow exceptions, disable text scaling, or remove the action to pass the test.

## Passing added coverage

- Both non-idle ACP and CLI rows are present; preferred mode controls the top
  banner; each row invokes only its own recovery notifier, without send calls
  or changing the ACP draft.
- A stale row cannot act after its ACP/CLI session changes before the next
  frame; same-ID server endpoint changes also reject the stale retry.
- Preferred ACP reconnecting stays visible while the separate CLI failure can
  be retried; the dialog updates when ACP session text / status changes and
  does not offer an unrelated generic retry for already-connected SSH.
- Terminal history keeps a disconnected-but-open tab in the open group, sorts
  recoverable rows by last use, preserves unknown/offline labels, filters
  names case-insensitively, shows empty search results, and does not start or
  restore a session or send terminal input while searching.

No build, ADB, live SSH, or real ACP operation was performed by this test owner.

## Device-discovered CLI recovery defect — fixed in source, final checks pending

The primary agent's installed-package ADB check found an aggregate
`Reconnecting...` banner persisting for over 60 seconds after explicit SSH
reconnect on the isolated fixture. Details confirmed SSH `Connected` but
`CLI: CLI (Reconnecting...)`, with no selected/configured Agent. Device evidence:
`/tmp/valhalla-core-experience.ACZJNb/adb-transfer-tail.png` and
`/tmp/valhalla-core-experience.ACZJNb/adb-recovery-details.jsonl`.

Cause: `CliChatNotifier` unconditionally set recovery to `reconnecting` on a
connected-to-nonconnected SSH transition. With no selected Agent, subsequent
recovery only attempted preferred-Agent selection and returned, leaving the
orphan state indefinitely visible. The aggregate UI was exposing real provider
state; SSH itself had recovered.

The narrow fix at `lib/core/providers/cli_chat_provider.dart:184` keeps recovery
`idle` only when `activeAgent == null`. Selected-Agent recovery remains unchanged,
including blank drafts with no selected session; no feature-wide hiding or
prompt/approval replay was added. The surgical-patch skill kept the change at
the invalid state's producer, without changing UI or unrelated recovery paths.

Two real-notifier regressions at
`test/features/background_recovery_cli_test.dart:205` cover CLI disabled with an
available but unselected Agent, and CLI enabled with an empty registry. Both
exercise connected → connecting → connected plus explicit recovery; assert idle
recovery, preserved draft directory, and no session/message/approval or remote
command creation. Both failed before the fix (**0 passed, 2 failed**):
`/tmp/valhalla-core-experience.ACZJNb/direct-cli-empty-recovery-red.log`.

After the fix, the six-file CLI/banner/operations focused run passed **93/93**,
including existing selected-Agent recovery cases:
`/tmp/valhalla-core-experience.ACZJNb/direct-cli-empty-recovery-green.log`.
Targeted analysis of the changed core and test files reported zero issues:
`/tmp/valhalla-core-experience.ACZJNb/direct-cli-empty-recovery-analyze.log`.

Source is frozen again. The primary agent is rerunning full tests, analysis,
formal build and installed-device verification; no post-fix build or device
acceptance result is claimed here yet. Do not add overlapping historical counts.
