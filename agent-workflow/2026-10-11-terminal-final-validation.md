# 2026-10-11 Terminal final validation

Scope: bounded terminal verification only. One `flutter gen-l10n`, `dart format` on the
changed terminal UI / xterm / settings / test files, new bounded tests, and the seven
listed test files. No full suite, no build, no ADB, no commits, no production edits
beyond formatter output and generated localization.

## Result summary

| File | Result |
| --- | --- |
| `test/features/terminal_ime_intent_test.dart` | 16/16 pass (8 pre-existing + 8 new desktop tests) |
| `test/core/terminal_keys_test.dart` | 19/19 pass |
| `test/features/terminal_scroll_retention_test.dart` | blocked in-repo (P1); passes once P1 is fixed |
| `test/features/settings_terminal_tmux_test.dart` | blocked in-repo (P1); passes once P1 is fixed |
| `test/features/settings_terminal_font_size_test.dart` | blocked in-repo (P1); passes once P1 is fixed |
| `test/features/shared_terminal_canvas_test.dart` | blocked in-repo (P1); 25/28 pass in the scratch tree, 3 fail on P3/P4 |
| `test/features/terminal_toolbar_actions_test.dart` | blocked in-repo (P1 + P2) |

---

## P1 — terminal UI does not compile: missing `lib/core/theme/valhalla_theme.dart`

`git log -- lib/core/theme/` is empty: the file never existed in this repository.

```
lib/features/terminal/widgets/shared_terminal_canvas.dart:8:8: Error: Error when reading
  'lib/core/theme/valhalla_theme.dart': No such file or directory
lib/features/terminal/widgets/customize_pinned_keys_dialog.dart:5:8: Error: Error when reading
  'lib/core/theme/valhalla_theme.dart': No such file or directory
```

Knock-on errors (the symbol the missing file was expected to provide):

```
lib/features/terminal/widgets/shared_terminal_canvas.dart:290:28: Error: The method 'monoTextStyle'
  isn't defined for the type '_SharedTerminalCanvasState'.
lib/features/terminal/widgets/customize_pinned_keys_dialog.dart:155:38: Error: The method 'monoTextStyle'
  isn't defined for the type '_CustomizePinnedKeysDialogState'.
lib/features/terminal/widgets/customize_pinned_keys_dialog.dart:194:32: Error: The method 'monoTextStyle'
  isn't defined for the type '_CustomizePinnedKeysDialogState'.
```

`monoTextStyle` actually lives at `lib/core/design/tokens.dart:87`; `lib/core/theme/` does
not exist. Both terminal widget files are the only two in `lib/` importing it:

```
$ grep -rln "core/theme/valhalla_theme" lib
lib/features/terminal/widgets/shared_terminal_canvas.dart
lib/features/terminal/widgets/customize_pinned_keys_dialog.dart
```

Fix: point both imports at `../../../core/design/tokens.dart`. Not applied here — this
is a production edit and outside the validation mandate.

Blast radius in the bounded run: 5 of the 7 listed test files fail to load
(`terminal_scroll_retention`, `shared_terminal_canvas`, `terminal_toolbar_actions`,
`settings_terminal_tmux`, `settings_terminal_font_size`). This is also an app-build
blocker, not only a test blocker.

## P2 — `terminal_view.dart:421` null-safety compile error

```
lib/features/terminal/terminal_view.dart:421:43: Error: Property 'bridge' cannot be accessed
  on 'TerminalTab?' because it is potentially null.
```

Context: `originatingTab` is null-checked and used for the canvas, but the tmux overlay
in the same expression uses `activeTab.bridge` (nullable `activeTab`). `activeTab` is
`terminalState.activeTab`; the null promotion does not reach it because it is a property
read, not a local. Independently of P1 this alone blocks `terminal_toolbar_actions_test`.

## P3 — `CustomizePinnedKeysDialog` `const Spacer()` inside `AlertDialog.actions`

`lib/features/terminal/widgets/customize_pinned_keys_dialog.dart:215`:

```
The following assertion was thrown while applying parent data.:
Incorrect use of ParentDataWidget.
The ParentDataWidget Expanded(flex: 1) wants to apply ParentData of type FlexParentData to
a RenderObject, which has been set up to accept ParentData of incompatible type
_OverflowBarParentData.
  SizedBox.shrink ← Expanded ← Spacer ← OverflowBar ← Padding ← Column ← IntrinsicWidth ← ...
```

`AlertDialog` lays `actions` out with an `OverflowBar`; an `Expanded`/`Spacer` child can
never be placed there. This fires on every screen size, not only the 360px case — the
dialog throws while mounting. Fix: drop the `Spacer` (the button order is
reset / cancel / save) or move the reset button out of `actions`.

## P4 — `ReorderableListView` inside `AlertDialog` content cannot compute intrinsics

`lib/features/terminal/widgets/customize_pinned_keys_dialog.dart:138` (the pinned list,
inside the dialog `content`):

```
RenderViewport does not support returning intrinsic dimensions.
...
The relevant error-causing widget was:
  AlertDialog:.../lib/features/terminal/widgets/customize_pinned_keys_dialog.dart:96:12
```

`AlertDialog` wraps its content in `IntrinsicWidth`, which asks the `ReorderableListView`
viewport for intrinsic dimensions; followed by `RenderBox was not laid out: RenderIntrinsicWidth ...`.
Consequence: reordering pinned keys is unreachable in the UI, which is exactly the
"pinned customization saves/reorders" behaviour the new tests assert.

## P5 — observation: `SharedTerminalCanvas` no longer calls the legacy `onPaste`

The pre-existing test `accessory bar paste button triggers onPaste` asserted that the
accessory PASTE button invokes `widget.onPaste`. It fails against current production,
which reads the clipboard itself (`_handlePasteText`) and never calls `onPaste`:

```
Expected: true
  Actual: <false>
  test/features/shared_terminal_canvas_test.dart:192  accessory bar paste button triggers onPaste
```

This matches the widget's documented intent ("统一接管物理 Ctrl+V 与按键栏 PASTE 的多行
粘贴确认"), so the test — not the production — was stale. The test was updated to assert
the new contract (single-line clipboard text is delivered through `onPasteText` without a
confirmation dialog). Two follow-ups for the production owner:

- `onPaste` is now dead from the canvas side: `terminal_view.dart:410` and
  `cli_chat_view.dart:1101` still wire `pasteClipboard()` / `pasteTerminalClipboard()`
  to a callback the canvas never invokes. Harmless, but misleading.
- When the clipboard is unavailable (denied permission, non-web platform without a
  handler), PASTE is a silent no-op — there is no fallback to `onPaste` and no feedback.

---

## Tests added

`test/features/terminal_ime_intent_test.dart` (desktop paths, 8 tests, all passing):

- Windows / Linux: passive focus still opens the input connection (desktop semantics
  differ from the mobile explicit-intent rule).
- Windows / Linux: hardware `Ctrl+C` reaches `onKeyEvent` as `handled` and never leaks
  into `onInsert`.
- Windows / Linux: CJK composition reports `composing` first, inserts only on commit.
- Windows input connection carries `viewId == tester.view.viewId`; Linux carries `null`
  (matches `custom_text_edit.dart:204`).

`test/features/shared_terminal_canvas_test.dart` (paste TOCTOU, modifier locks, hold
repeat, pinned keys, narrow screen, long-press selection):

- Confirmed multi-line paste reads the clipboard exactly once and never re-enters the
  legacy `onPaste`.
- Cancelling the confirmation dialog sends nothing.
- Switching terminals while the confirmation dialog is open sends nothing to either the
  originating or the new terminal.
- The CLI-style originating-terminal guard closure refuses to send after the session
  switch and stays safe when invoked directly.
- Mobile IME: one-shot Ctrl turns the first `c` into Ctrl-C and the next `c` into plain
  text; locked Ctrl keeps combining on every input; Alt behaves the same way one-shot;
  switching terminals resets the modifier state; with no modifier active a composing
  `zhong` produces no output and only the committed `中文` reaches the terminal.
- `HoldRepeatKey`: `pointer cancel` stops the repeat, and removing the widget mid-repeat
  stops all further callbacks.
- `CustomizePinnedKeysDialog`: save persists the reordered list; a failing save keeps the
  dialog open and shows the visible error snackbar; 360px + textScaler 2 must not overflow.
- Long-press word selection still surfaces the copy affordance and copies `hello`.

## Validation method for the blocked files

P1–P2 prevent the terminal UI from compiling at all, so the affected tests cannot run in
the workspace. To obtain real evidence rather than skipping the checks, the repository was
copied to `/tmp/opencode/vscratch` (outside the workspace), and **only there** the two
P1 import lines were repointed at `lib/core/design/tokens.dart`. Results in that scratch
tree: `terminal_scroll_retention`, `settings_terminal_tmux`, `settings_terminal_font_size`
all pass; `shared_terminal_canvas_test` is 25/28 with the 3 failures being exactly P3 and
P4; `terminal_toolbar_actions_test` still cannot compile because of P2. The scratch tree
has been deleted; no production file in the workspace was modified.