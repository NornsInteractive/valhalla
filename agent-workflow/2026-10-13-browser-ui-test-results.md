# Shared browser widget verification — 2026-10-13

Scope: new `test/features/remote_browser_dialog_test.dart`, with two narrow
completed-subscription regressions added to `test/core/remote_browser_test.dart`.
No UI/ARB/product edits, full suite, generation, build, ADB, or real remote
mutation were performed by this verifier. AgY is concurrently improving UI;
these results describe the snapshot whose locations are listed below.

## Executed gates

```sh
flutter test --no-pub --concurrency=2 --reporter=expanded test/features/remote_browser_dialog_test.dart
flutter test --no-pub --concurrency=2 --reporter=expanded test/core/remote_browser_test.dart
```

- Widget gate: **1 passed / 9 failed**, exit 1 (`00:03 +1 -9`). Failures are
  intentionally retained as acceptance regressions; none are skipped or weakened.
- Browser core gate: **23 passed**, exit 0 (`00:00 +23`).
- Owned test files formatted; `git diff --check` on both files passed.

## Widget evidence for AgY

Tests interact through public buttons, dialog results, source implementations,
selection callbacks and the public `reload()` API wired to a host button. They do
not read private widget state. Delayed-cancel cases supply a public source whose
subscription cleanup is held by a completer.

| Test name | Actual result | Responsible snapshot location |
| --- | --- | --- |
| `a loaded empty directory can be confirmed` | PASS: root directory selection and correct target key | Dialog happy-path control |
| `directory confirmation never returns a regular file` | Returns `/notes.txt` with `isDirectory == false` | `remote_browser_view.dart:212`; dialog `_confirm` at `:149` |
| `directory confirmation is disabled until listing completes` | Confirm callback enabled before any response | `remote_browser_dialog.dart:206` |
| `permission failure cannot confirm the unverified directory` | Confirm callback enabled after SFTP permission-denied error | `remote_browser_dialog.dart:206` |
| `library preselection spans batches and reaches dialog payload` | Confirm remains disabled after both selected libraries arrive | `remote_browser_view.dart:140`; no initial-selection callback |
| `user deselected libraries stay deselected after public reload` | Both unchecked libraries reappear checked after reload | `remote_browser_view.dart:140` restores whenever selected map is empty |
| `source replacement clears the dialog selection snapshot` | Source B keeps an enabled file confirm from source A | `remote_browser_view.dart:96`; dialog does not reset parent selection |
| `late thumbnail from an old source cannot enter the new source` | A's late `/photo.png` bytes create an Image while displaying B, which has returned no bytes | `remote_browser_view.dart:249` lacks captured-source/generation guard |
| `closing during directory cancellation does not setState later` | Actual Flutter `setState() called after dispose()` stack | `remote_browser_view.dart:122`, after awaited cancel |
| `source swap during navigation does not reuse the old path` | B receives `['/documents', '/']` instead of only `['/']` | `remote_browser_view.dart:117` reads mutable source after await |

The library payload assertion remains in the test after its currently failing
enabled-button assertion, so fixing only the button cannot conceal a missing
second-batch selection. The preview test additionally requires B to make its own
preview request for the same entry ID. Both become observable once the first
failure is fixed.

## Investigation note: reload timing was a test harness artifact

An intermediate widget run appeared to block while awaiting a completed stream's
`cancel()`. A real-async unit regression proved completed cancel and subsequent
listing finish normally. The equivalent widget test also passes once
`tester.runAsync` advances Dart's real event loop: Dart stream subscriptions may
return their shared already-completed null future, whose continuations are not
necessarily advanced by Flutter fake-async `pump` alone.

The widget `_frames` helper now advances that real event loop before pumping.
Reload correctly reaches its second listing and exposes the actual UI defect:
initial IDs are restored despite explicit user deselection. **No product cancel
fix is needed or was made.** Core tests now cover completed cancel/relist both in
normal async and a widget event loop, alongside existing per-read cancel tests.

## Remaining verification

Re-run the widget gate after AgY changes. This file is not a pass sign-off. It does
not prove preview concurrency/byte limits, mobile grid geometry, anchor retention,
all caller migrations, or device behavior. Root owns the later unified gate and
device delivery.
