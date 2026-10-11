# v1.0.4 pinned-key fixture verification

OpenCode executed the test-only correction, formatting and checks. The actual
drag started from the leading handle; the original target placed the proxy start
exactly on the last row's bottom. Crossing that strict boundary by 4px restores
the intended drop. Production UI was not edited. Saved-list count, key set and
ESC-last assertions remain, with the full saved order in failure diagnostics.

- MiMo: `/tmp/opencode/v104-pinned-plus4.log`, two tests passed, underlying exit 0.
- Free Step 5: `/tmp/opencode/v104-shared-final.log`, entire shared-canvas suite,
  **28 passed, 0 failed, exit 0**. Only the test was formatted; temporary geometry
  snapshots were removed after proof. Assertions were not suppressed or skipped.
- Both CLI runners reached their 300-second task timeout (124) during later
  bookkeeping. That is not a successful overall runner exit; the independently
  captured underlying test outcomes above are the evidence.

This document records observed OpenCode output; main did not execute tests.
