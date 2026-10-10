# Focused mobile UI regression tests — 2026-10-10

Owner: OpenCode (tests only). No production, ARB or native files were edited.
Docker tests/services and builds are owned elsewhere and were not touched.

## Scope run (current working tree, AgY UI fixes applied)

Command (exit code captured verbatim):

    flutter test \
      test/features/terminal_toolbar_actions_test.dart \
      test/features/remote_files_ui_contract_test.dart \
      test/features/main_shell_drawer_focus_test.dart

- `flutter test` exit code: **0**
- Result line: `00:05 +28: All tests passed!` (28 passed / 0 failed)
- `flutter analyze` on the same three files: `No issues found!` (exit 0)

Full raw log kept at `/tmp/opencode/focused4.log`.

## Red baseline (same tests against unmodified `HEAD` = cca7096)

The three files were copied into a throwaway `git worktree` of `HEAD`
(pre-fix code: Android `ChoiceChip` tabs, `eraseDisplay` clear, `minWidth: 44`
breadcrumb segments, no `ExcludeFocus` in `AnimatedIndexedStack`).

- `flutter test` (same three files) exit code: **1**
- Result line: `00:30 +16 -12: Some tests failed.` (16 passed / 12 failed)

Raw log: `/tmp/opencode/baseline_tests.log`. Worktree removed afterwards.

### Baseline failures (all pre-fix UI defects, 12)

| Test (baseline failure) | Observed |
| --- | --- |
| terminal_toolbar_actions_test: clicking close on the selected tab (android) | no `InputChip` close affordance on Android |
| terminal: closing a tab before the active tab (android) | close target not reachable |
| terminal: closing the active middle tab … (android) | close target not reachable |
| terminal: closing a later inactive tab … (android) | close target not reachable |
| terminal: the last tab stays open … (android) | close target not reachable |
| terminal: clear repaints immediately … (android) | `repaints` expected `<1>`, actual `<0>` — `eraseDisplay`/`setCursor` never notified xterm listeners, so the screen never repainted |
| terminal: Android tabs expose independent, accessible close callbacks | `InputChip` count expected `<2>`, actual `<0>` — the nested 14px `InkWell` had no chip semantics/tooltip |
| remote_files_ui_contract_test: compact breadcrumbs stay tight yet touchable and exact | mobile horizontal gap expected `<= 30`, actual `122.19999980926514` — old `minWidth: 44` inflated every short segment into a 120px slot |
| main_shell_drawer_focus_test: drawer selection, backdrop tap and system back never restore the keyboard | hidden-page focus expected `false`, actual `true` — keyboard/focus returned after dismissing the drawer |
| main_shell: a hidden page cannot take focus | hidden page still took focus (no `ExcludeFocus`) |
| main_shell: switching pages keeps the search draft and page state | focus/`EditableText` assertion failed pre-fix |
| main_shell: tapping the terminal reopens the keyboard … | pre-fix focus/terminal keyboard chain failed |

After the current UI fixes every one of these 12 passes; nothing was weakened
to make them pass.

## What the tests assert (no snapshots, no mocks of production code)

1. `terminal_toolbar_actions_test.dart`
   - All six Windows tab/close/clear cases now run for **both** platforms via
     `TargetPlatformVariant({windows, android})` (titles de-platformed).
   - New Android case asserts the mobile layout reuses the same chip with a
     **per-index, tooltip-labelled** delete callback and that closing one tab
     never disposes the other; the last remaining tab has no delete callback.
   - The clear case keeps the strict contract: local ANSI write repaints exactly
     once, buffer + scrollback cleared, other tabs untouched, nothing sent to
     the shell (`sent == isEmpty`).
2. `remote_files_ui_contract_test.dart`
   - New case `compact breadcrumbs stay tight yet touchable and exact`:
     every segment still has `height >= 44` (touch target), the maximum
     horizontal gap between two consecutive short-segment labels is `<= 30`
     (chevron 14 + 6 + 6 padding), and exact navigation is preserved — segments
     tapped deepest-first record `/a/b/c`, `/a/b`, `/a`, the up button at `/a`
     records exactly `['/a']` and is then disabled at root, and the root
     segment records `/`.
3. `main_shell_drawer_focus_test.dart` (new file, reuses the
   `main_shell_dynamic_nav_test.dart` shell fixture and `test/support` helpers)
   - Opening the drawer clears the files page focus and hides the keyboard.
   - Drawer selection, backdrop tap, backdrop fling and Android system back
     (`flutter/navigation` + `JSONMethodCodec` `popRoute`) all dismiss the drawer
     **without** restoring the keyboard.
   - A hidden page cannot take focus (`requestFocus` is refused while offstage).
   - Page switches keep the search draft and the page `State` object (page is
     never unmounted).
   - Tapping the terminal after dismissal re-attaches a text input client
     (keyboard reopens); the xterm 300ms double-tap timer is flushed and the
     terminal bridge disposed in teardown.

## Status

- Focused UI regressions: **all green on the current working tree**.
- Baseline proof of the four mobile regressions is recorded above; the same
  tests are the acceptance gate for AgY's UI fixes.
- Not run / not owned here: `docker_*` suites and `docker_cli_service_test.dart`
  (Codex + separate verifier), Android builds and ADB device smoke tests
  (still paused), launcher icon resource validation (deferred until AgY icons
  are ready), dialog-focus coverage (the shell exposes no text dialog through
  these fixtures).
