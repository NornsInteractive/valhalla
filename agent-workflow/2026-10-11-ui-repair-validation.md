# 2026-10-11 UI Repair Validation Gate

Status: PARTIAL PASS (format + gen-l10n green, 3 test failures)

Scope of this run (per request): formatting of 5 named files, one `flutter gen-l10n`,
one `flutter test` run over 9 named test files. No test edits, no production edits
beyond the formatter/generated files, no scratch runs, no subagents, no full suite,
no build, no ADB. AgY phase-2 (global input in main.dart / shell) intentionally not
touched by this run.

## Step 1 - `dart format` (5 named files only)

Command:

    dart format lib/features/terminal/widgets/shared_terminal_canvas.dart \
      lib/features/terminal/widgets/customize_pinned_keys_dialog.dart \
      lib/features/terminal/terminal_view.dart \
      lib/features/settings/widgets/app_update_dialog.dart \
      lib/features/files/sftp_file_view.dart

- Result: `Formatted 5 files (2 changed)`, exit 0.
- Changed: `lib/features/terminal/widgets/customize_pinned_keys_dialog.dart`,
  `lib/features/settings/widgets/app_update_dialog.dart`.
- Idempotency check after the run: `dart format --output=none --set-exit-if-changed`
  on the same 5 files -> `Formatted 5 files (0 changed)`, exit 0.
- Note: these two new UI files are untracked; an empty ordinary `git diff` does
  not establish equality with HEAD or prove whether formatting changed behavior.
  The formatter reported changes and the deterministic failure is recorded below.

## Step 2 - `flutter gen-l10n`

- Command: `flutter gen-l10n`
- Log: `/tmp/opencode/gate-genl10n-20261011-095508-463908.log`
- Exit: 0 (stdout: "Because l10n.yaml exists, the options defined there will be used
  instead."; no errors).

## Step 3 - `flutter test` (9 named files, `--reporter expanded`)

- Command:

    flutter test test/features/terminal_ime_intent_test.dart \
      test/features/terminal_scroll_retention_test.dart \
      test/core/terminal_keys_test.dart \
      test/features/shared_terminal_canvas_test.dart \
      test/features/terminal_toolbar_actions_test.dart \
      test/features/settings_terminal_tmux_test.dart \
      test/features/settings_terminal_font_size_test.dart \
      test/features/sftp_file_view_test.dart \
      test/core/l10n_key_parity_test.dart --reporter expanded

- Log: `/tmp/opencode/gate-tests-20261011-095518-463980.log`
- Exit: 1
- Tally: `00:08 +125 -3: Some tests failed.` (125 passed, 3 failed)
- No pipes used; exit code captured directly from the command.

### Failure 1 - pinned key reorder (drag ESC to end)

- Test: `test/features/shared_terminal_canvas_test.dart`
  group `CustomizePinnedKeysDialog`, case `保存后按新顺序落库` (line 779)
- Symptom: `Expected: 'ESC'`, `Actual: '↑'`, `Differ at offset 0`,
  assertion message `ESC 应被拖到末尾`.
- Stack top: `test/features/shared_terminal_canvas_test.dart:779:7`
- Reading: the dragged-to-last slot resolves to `↑`, not `ESC`.

### Failure 2 - l10n placeholder metadata parity (zh)

- Test: `test/core/l10n_key_parity_test.dart`
  case `@metadata placeholder names follow the EN template, explicit or not` (line 159)
- Symptom: `Expected: Set:['count']` / `Actual: Set:[]`,
  `zh: terminalConfirmPasteMessage @-metadata names must equal en`.

### Failure 3 - zh catalog clones EN text

- Test: `test/core/l10n_key_parity_test.dart`
  case `no non-en catalog clones English for non-identity messages` (line 231)
- Symptom: `Expected: <0>` / `Actual: <1>`,
  `zh identical to EN (non-identity): [updateArtifactHash]`.

## Reproducibility check (read-only, no edits)

- Re-run of only the two failing files, expanded reporter:
  `/tmp/opencode/gate-tests-failonly-20261011-095618-464290.log`, exit 1.
- Result: `00:02 +34 -3: Some tests failed.` - identical 3 failures, so the failures
  are deterministic and not caused by the formatter pass or test ordering.

## Tree hygiene

- The gate reported no production edits other than the formatter/generated
  l10n outputs listed above. Untracked files include new UI/test/core sources as
  well as reports; status counts alone do not prove source equality, especially
  while the independent AgY main.dart / shell phase is active.
- No test sources were edited in this run.

## Next actions (not performed here, out of scope)

- AgY global-input phase is main.dart / shell only; it does not modify these test
  sources or the ARBs.
- Failure 1 needs a pinned-key default/reorder inspection in
  `lib/features/terminal/widgets/customize_pinned_keys_dialog.dart` and its ordering
  source.
- Failures 2 and 3 need `lib/l10n/app_zh.arb` (missing `@-metadata` placeholder `count`
  for `terminalConfirmPasteMessage`, and `updateArtifactHash` identical to EN).
