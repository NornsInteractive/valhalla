> Resolved in final-ready verification: 115 regular tests passed, including unread/prepend, exact latest scroll, RTL/IME and localization parity. Historical diagnostics below describe intermediate work, not outstanding defects. See `2026-10-26-final-ready-findings.md`.

# 2026-10-25 Terminal Gate Findings

## Gate

Command:
`flutter test --no-pub --machine` on the 34 files selected by `tool/release.py`
(`*terminal*test.dart`, `*tmux*test.dart`, plus
`test/features/shared_terminal_canvas_test.dart` and
`test/core/l10n_key_parity_test.dart`).

Machine log: `build/ssh-acp-validation/terminal-release-gate-machine.log`
Exit code: `build/ssh-acp-validation/terminal-release-gate.exit` = `1`

Counts: 579 total, 578 passed, 1 failed, 0 skipped, 0 errors.

## Terminal close-tab fixture update (test only)

`test/features/terminal_toolbar_actions_test.dart` `_closeTab` helper updated to tap
`terminal_confirm_close_tab_button` after selecting `terminalCloseTab`, matching the
new accepted close-tab confirmation dialog in `lib/features/terminal/terminal_view.dart`
(`_confirmAndCloseTab`). No production behavior assertions were weakened; close still
requires the explicit confirmation and typed target guard.

After this test-only update, all terminal/tmux tests pass.

## Genuine production/l10n failure (not fixed)

Failed test:
- File: `test/core/l10n_key_parity_test.dart`
- Test: `@metadata placeholder names follow the EN template, explicit or not`
- First reported locale: `zh`
- Key: `acpRunningSessionIndicator`
- Expected declared metadata names: `{agentName}`
- Actual declared metadata names: `{}` (no `@acpRunningSessionIndicator` block)

Exact source/cause:
- `lib/l10n/app_en.arb` defines `acpRunningSessionIndicator` with an explicit
  `@acpRunningSessionIndicator` metadata block containing
  `placeholders.agentName` of type `String`.
- All 16 non-English catalogs (`app_ar.arb`, `app_de.arb`, `app_es.arb`,
  `app_fr.arb`, `app_hi.arb`, `app_id.arb`, `app_it.arb`, `app_ja.arb`,
  `app_ko.arb`, `app_pt.arb`, `app_ru.arb`, `app_th.arb`, `app_tr.arb`,
  `app_vi.arb`, `app_zh.arb`, `app_zh_Hant.arb`) contain the message string
  `"…{agentName}"` but omit the matching `@acpRunningSessionIndicator`
  metadata block entirely.
- The parity test requires each catalog's declared placeholder-name set to equal
  EN's when explicit metadata is present. Flutter can infer the placeholder from
  the message text, so runtime behavior is unaffected, but the metadata omission
  violates the parity contract.

Production/UI/ARB/tool changes were not made for this finding, and the test was
not skipped or weakened. Terminal production remains frozen. The missing
`@acpRunningSessionIndicator` metadata blocks need to be added to the 16
non-English ARB files by the l10n owner before the release gate can pass.
