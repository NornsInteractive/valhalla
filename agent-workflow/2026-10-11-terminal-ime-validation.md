# 2026-10-11 — Terminal IME intent validation

Scope: regression tests only, no production edits. New file:
`test/features/terminal_ime_intent_test.dart`. Read only
`packages/xterm/lib/src/ui/custom_text_edit.dart` and
`test/features/terminal_scroll_retention_test.dart`.

## Model / cost

Model ran as `space-bunny-free` (session default, local routing). Input, output
and cache tokens for this session report zero spend on the local provider path;
no paid-model fallback was needed, so the opencode.ai Zen free-table fallback
was not exercised. Nothing to reconcile.

## What is pinned

`CustomTextEditState` opens a `TextInputConnection` (i.e. shows the IME) only
when an explicit intent flag `_keyboardRequested` is set on mobile, and clears
that intent on: blur, `inactive` lifecycle, and keyboard dismissal via
`didChangeMetrics`. The tests lock that contract on `TargetPlatform.android`.

Fixture: `MaterialApp` + `Scaffold` + `CustomTextEdit` with a `FocusNode` and
`GlobalKey<CustomTextEditState>`. No new dependencies; `TestTextInput` is the
binding's built-in fake, so no explicit registration is needed.
`debugDefaultTargetPlatformOverride` is set and restored *inside* each test body
because `flutter_test` asserts it is unset at the end of every `testWidgets`.

| # | Test | Asserts |
|---|------|---------|
| 1 | 被动获得焦点不得弹出 IME | `focusNode.requestFocus()` → `hasInputConnection == false` |
| 2 | autofocus 也不得弹出 IME | `autofocus: true` → no connection |
| 3 | 显式 requestKeyboard 会打开输入连接 | `requestKeyboard()` → focus + `hasInputConnection == true`, no spurious insert/delete |
| 4 | 焦点被模态框抢走再恢复 | `showDialog` steals focus (connection closes), pop restores focus but connection stays closed |
| 5 | 生命周期 inactive/resumed | `inactive` closes connection; `resumed` does not reopen it; focus is retained |
| 6 | 软键盘收起 | `viewInsets.bottom 0→320→0` via `tester.view`; connection survives the raise, closes on dismissal, focus kept |
| 7 | IME 关闭时物理键盘事件仍被处理 | `sendKeyEvent` reaches `onKeyEvent`, all 4 (down+up) results `handled`, no connection opened |
| 8 | IME 打开期间的输入仍回传给回调 | `tester.testTextInput.updateEditingValue` → `onInsert(['x'])`, `currentTextEditingValue` starts empty |

Each assertion reads real state (`hasInputConnection`, `FocusNode.hasFocus`,
recorded callbacks) — no `print`/probe/scratch tests.

## Run results

```
flutter test test/features/terminal_ime_intent_test.dart \
            test/features/terminal_scroll_retention_test.dart
→ 00:04 +14: All tests passed!   (8 new + 6 existing, 0 failures)

dart analyze test/features/terminal_ime_intent_test.dart  → No issues found!
dart format --set-exit-if-changed                        → clean
```

## Notes / limits

- Desktop (non-mobile) branch of `_openOrCloseInputConnectionIfNeeded` consumes
  `FocusNode.consumeKeyboardToken()`; that path is not covered here since the
  request was scoped to the Android IME intent.
- `FocusNode`s are intentionally not disposed in `tearDown`: disposing after
  the binding is torn down emits a "FocusManager used after being disposed"
  noise line. Test-scoped nodes are collected by GC.