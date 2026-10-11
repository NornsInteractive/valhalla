# Terminal Scroll Retention — Test Validation (2026-10-11)

## Command

```
cd /workspace/projects/valhalla
flutter test --no-pub test/features/terminal_scroll_retention_test.dart --reporter expanded
```

## Result

```
00:00 +0: loading /workspace/projects/valhalla/test/features/terminal_scroll_retention_test.dart
00:00 +0: SSH terminal scroll retention — baseline reproduction bottom follow survives AnimatedIndexedStack page changes, including output while hidden
00:00 +1: SSH terminal scroll retention — baseline reproduction intentional history position survives AnimatedIndexedStack page changes
00:00 +2: SSH terminal scroll retention — baseline reproduction swapping populated Terminal A -> short Terminal B -> A on the same canvas element loses A position
00:00 +3: SSH terminal scroll retention — baseline reproduction swapping A -> B -> A at the bottom restores bottom follow, not top
00:00 +4: SSH terminal scroll retention — baseline reproduction viewport height change (keyboard) keeps history position and bottom follow
00:00 +5: SSH terminal scroll retention — baseline reproduction render layout dimensions report the viewport the terminal resized to
00:00 +6: All tests passed!
```

6 passed / 0 failed. Exactly one rerun was performed after the harness fix (within the "at most once" budget).

## Failures in the baseline run (before any edit)

Two failures, with different causes:

1. `test/features/terminal_scroll_retention_test.dart:155` — harness finder defect.
   - Error: `Expected: exactly one matching candidate / Actual: Found 0 widgets with type "TerminalView": []`.
   - Root cause: `AnimatedIndexedStack` keeps every page alive by wrapping the hidden page in `Offstage` (`lib/core/design/motion_widgets.dart:246`), so the default `skipOffstage: true` finder cannot see the retained `TerminalView` while page 1 is selected.
2. `test/features/terminal_scroll_retention_test.dart:249` — genuine production regression (not a harness bug).
   - Error: `Expected: <1961.0> Actual: <18.0>` — swapping populated Terminal A → short Terminal B → A on the same `SharedTerminalCanvas` element lost A's scroll position (`historyA=1961.0, maxA=3922.0`; on B `pixels=18.0 max=18.0`, and back on A `pixels=18.0`).

## Harness fix applied (test file only)

`test/features/terminal_scroll_retention_test.dart` is the only file modified:

- line 155: `find.byType(TerminalView, skipOffstage: false)`
- `_scrollable()` helper (lines 118-125): `find.byType(TerminalView, skipOffstage: false)` and
  `find.byType(Scrollable, skipOffstage: false)`

Both finders are pure lookups (they locate the retained offstage element); no assertion was weakened and no timing/pump behavior was altered. No production file under `lib/` or `packages/` was touched.

## Production regression

- The A → B → A scroll-position loss (baseline run, line 249) was a real production defect. Between the baseline run and the rerun, the concurrently applied production changes in
  `lib/features/terminal/widgets/shared_terminal_canvas.dart`, `packages/xterm/lib/src/terminal_view.dart`, and
  `packages/xterm/lib/src/ui/render.dart` landed, and the same test then passes with no further harness change.
- The offstage page-switch retention assertions (lines 169-173, 209-213) also pass as-is; no production behavior needed to change for them once the finder could see the offstage widget.

## Verification status

- `flutter test --no-pub test/features/terminal_scroll_retention_test.dart --reporter expanded` → **all 6 tests pass**.
- No other test, build, ADB, or analysis command was run, per scope.
- Open risk: the passing swap test currently depends on the concurrent production edits noted above; if those edits are reverted, line 249 will fail again with the 18.0-vs-1961.0 mismatch.
