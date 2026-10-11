# SSH Keyboard Validation Evidence — 2026-10-11

Validation-only run after AgY finished all 10 catalog fixes. No source edits; only generated localization may change via `flutter gen-l10n`.

## Commands and actual exits

| Command | Exit | Result |
|---|---|---|
| `flutter gen-l10n` | **0** | OK (l10n.yaml options used) |
| `flutter test test/core/l10n_key_parity_test.dart --reporter expanded` | **0** | **9/9 passed** |
| `flutter analyze --no-pub lib/features/terminal lib/main.dart lib/features/shell/main_shell.dart packages/xterm/lib/src/terminal_view.dart test/features/terminal_toolbar_actions_test.dart` | **0** | **No issues found** (5 items, 1.7s) |

## Full logs (unique)

- gen-l10n: `/tmp/opencode/gen_l10n_20261011.log`
- l10n_key_parity test: `/tmp/opencode/l10n_key_parity_20261011.log` (ends `00:00 +9: All tests passed!`)
- analyze five-file gate: `/tmp/opencode/flutter_analyze_gate_20261011.log`
- toolbar 17-pass full log (prior OpenCode run): `/tmp/opencode/toolbar_actions_20261011_103741_470023.log`

## Status

- l10n key parity: **pass** (9 tests)
- joint nine-file gate: **131 passed, 1 failed** (recorded before the style-only local function repair; persisted pinned-key reorder remains unresolved)
- latest six-target analyze: **exit 0, no issues**; repaired identity-guard test: **1 passed**
- device acceptance: **pending**

The initial three-command run excluded the shared canvas fixture while its author
was running. Subsequent bounded runs below include it. All delegated writers have
now stopped. These checks are not full-app, build or device acceptance.

## Final bounded evidence run — 2026-10-11 10:45 (no repairs, writers stopped)

Constraints honored: no source/ARB/test-assertion edits; `dart format` limited to the two named test files; no skips, no weakened assertions, no subagents/scratch/build/ADB/git.

### 1. `dart format` (two files only)

```
dart format test/features/shared_terminal_canvas_test.dart test/features/terminal_toolbar_actions_test.dart
```

- Exit: **0**
- Output: `Formatted test/features/shared_terminal_canvas_test.dart` / `Formatted 2 files (1 changed) in 0.03 seconds.`
- Re-check (`--set-exit-if-changed`, both files): exit **0** for each → both now clean.

### 2. Nine-file joint test gate

```
flutter test --no-pub test/features/terminal_ime_intent_test.dart test/features/terminal_scroll_retention_test.dart test/core/terminal_keys_test.dart test/features/shared_terminal_canvas_test.dart test/features/terminal_toolbar_actions_test.dart test/features/settings_terminal_tmux_test.dart test/features/settings_terminal_font_size_test.dart test/features/sftp_file_view_test.dart test/core/l10n_key_parity_test.dart --reporter expanded
```

- **Actual exit: 1**
- Complete log (unique): `/tmp/opencode/final-test-20261011-104529.log` (165 lines / 27,882 bytes)
- Final line: `00:07 +131 -1: Some tests failed.`
- **Counts: 131 passed, 1 failed, 132 total**, duration 00:07

#### The 1 failure (reported honestly, not skipped)

| | |
|---|---|
| File | `test/features/shared_terminal_canvas_test.dart` |
| Group/test | `CustomizePinnedKeysDialog` → `保存后按新顺序落库` |
| Assertion line | `test/features/shared_terminal_canvas_test.dart:804` |
| Matcher message | `ESC 应被拖到末尾` |
| Expected | `'ESC'` |
| Actual | `'↑'` |
| Progress stamp | `00:03 +81 -1: ... shared_terminal_canvas_test.dart: CustomizePinnedKeysDialog 保存后按新顺序落库 [E]` |

This is the persisted-reorder test. It **still fails after two fixture iterations**; it was not skipped, not weakened, and not repaired in this run. Reported as-is per instruction.

All other eight files contributed passing tests; no other `[E]` markers appear in the log (exactly 1 `[E]` line total).

### 3. `flutter analyze` gate

```
flutter analyze --no-pub lib/features/terminal lib/main.dart lib/features/shell/main_shell.dart packages/xterm/lib/src/terminal_view.dart test/features/terminal_toolbar_actions_test.dart test/features/shared_terminal_canvas_test.dart
```

- **Actual exit: 1**
- Complete log (unique): `/tmp/opencode/final-analyze-20261011-104557.log` (5 lines / 304 bytes)
- Full content:

```
Analyzing 6 items...

   info • Use a function declaration rather than a variable assignment to bind a function to a name • test/features/shared_terminal_canvas_test.dart:507:13 • prefer_function_declarations_over_variables

1 issue found. (ran in 1.6s)
```

- **1 issue, severity `info`** (`prefer_function_declarations_over_variables` at `shared_terminal_canvas_test.dart:507:13`). No warnings or errors. Exit 1 is the true exit; `flutter analyze` returns non-zero on any issue.

Note vs. the earlier 5-item gate above (exit 0, no issues): the 6th item added here, `test/features/shared_terminal_canvas_test.dart`, is the sole source of the single info issue.

## CLI-guarded lint repair + final evidence — 2026-10-11 10:47

Single style repair only: in `test/features/shared_terminal_canvas_test.dart:507` the local
`final cliGuarded = (String text) { ... };` became a local function declaration
`void cliGuarded(String text) { ... }`. Body, captured `currentTerminal`/`terminal` identity guard,
and every assertion (including `final before = cliGuarded;` / `before('probe')` / all `expect`s) are
byte-for-byte unchanged. Reorder gesture/assertions and all other source untouched. `dart format`
run on this one test file only.

### 1. `dart format` (one file)

```
dart format test/features/shared_terminal_canvas_test.dart
```

- Exit: **0**
- Output: `Formatted 1 file (0 changed) in 0.02 seconds.`

### 2. `flutter analyze` — same 6-target gate

```
flutter analyze --no-pub lib/features/terminal lib/main.dart lib/features/shell/main_shell.dart packages/xterm/lib/src/terminal_view.dart test/features/terminal_toolbar_actions_test.dart test/features/shared_terminal_canvas_test.dart
```

- **Actual exit: 0**
- Complete log (unique): `/tmp/opencode/analyze6-cli-guarded-20261011-104752.log` (2 lines)
- Full content:

```
Analyzing 6 items...
No issues found! (ran in 1.7s)
```

- The previous `prefer_function_declarations_over_variables` info at
  `shared_terminal_canvas_test.dart:507:13` is gone; zero issues, true exit 0.

### 3. Targeted test

```
flutter test --no-pub test/features/shared_terminal_canvas_test.dart --plain-name 'CLI 发起终端守卫' --reporter expanded
```

- **Actual exit: 0**
- Complete log (unique): `/tmp/opencode/cli-guarded-test-20261011-104758.log` (3 lines / 245 bytes)
- Full content:

```
00:00 +0: loading /workspace/projects/valhalla/test/features/shared_terminal_canvas_test.dart
00:00 +0: SharedTerminalCanvas 粘贴确认的 TOCTOU 保护 CLI 发起终端守卫：切换后回调自身也拒绝发送
00:00 +1: All tests passed!
```

### Status (unchanged from prior run)

- Joint nine-file gate: **131 passed, 1 failed** (`CustomizePinnedKeysDialog` → `保存后按新顺序落库`,
  `shared_terminal_canvas_test.dart:804`, `ESC 应被拖到末尾`, log
  `/tmp/opencode/final-test-20261011-104529.log`) — **preserved as recorded, still unresolved**;
  the old reorder failure was not touched, skipped, or weakened in this run.
- l10n key parity: **pass** (9 tests)
- device acceptance: **pending**
