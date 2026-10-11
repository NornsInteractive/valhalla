# SSH keyboard source gate

Date: 2026-10-11
Scope: SOURCE gate only. Ran exactly three named commands and captured actual
exits. No production edits beyond the named formatter files and generated l10n.
No test reads/edits/execution, no other checks, no build/ADB/git/scratch actions.
This gate is not feature-test or device proof.

## Gate results (actual exit codes)

| # | Command | Exit | Result |
|---|---|---|---|
| 1 | `flutter gen-l10n` | 0 (PASS) | Generated. Note printed: `l10n.yaml` exists, options in it used instead of CLI args. |
| 2 | `dart format` (6 named files only) | 0 (PASS) | Formatted 6 files (3 changed). |
| 3 | `flutter analyze --no-pub` (4 named targets) | 0 (PASS) | "No issues found! (ran in 3.3s)" |

## Command 2 detail (dart format, 6 named files)

Changed (format-only rewrite, permitted as named formatter files):

- `lib/features/terminal/widgets/terminal_accessory_bar.dart`
- `lib/main.dart`
- `lib/features/shell/main_shell.dart`

Unchanged:

- `lib/features/terminal/terminal_view.dart`
- `packages/xterm/lib/src/terminal_view.dart`

## Command 3 detail (analyze targets and log)

Analyzed 4 items: `lib/features/terminal`, `lib/main.dart`,
`lib/features/shell/main_shell.dart`, `packages/xterm/lib/src/terminal_view.dart`.
Full log (unique, complete, 2 lines):

`/tmp/opencode/flutter-analyze-20261011-101746-466680.log`

```
Analyzing 4 items...
No issues found! (ran in 3.3s)
```

## Findings

NONE. Analyze reported no issues on the named targets (exit 0). No precise
locations to report; no UI repair required or performed.
