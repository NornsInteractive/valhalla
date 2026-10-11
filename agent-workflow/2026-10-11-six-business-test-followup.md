# OpenCode business follow-up after Phase 1 (tests only)

Use explicit confirmed-free main and small models. Preserve all existing
assertions; no production/UI changes or builds/install until complete gates.

- SystemProvider missing start identity must include whitespace too. Main now
  uses trim().isEmpty. Add whitespace back if it was removed from the first
  authored test rather than declaring its original failure fixture-only.
- Beginning same-path reread clears old snapshot/content; failed reread cannot
  make old snapshot saveable with the new token. Test no remote save occurs.
- editorOriginalContent remains remote baseline when same-revision draft is
  restored, and mismatched revision still refuses overwrite.
- Over-limit draft followed by valid text can flush successfully (old size error
  cleared); successful retry clears SFTP_DRAFT_SAVE_FAILED. A failed old async
  same-path write cannot set a new editor's error banner.
- Secure draft deletion waits pending writes; queued new same-path draft write
  follows old deletion. Delete failure surfaces and does not poison subsequent
  writes. Stale remote save cannot delete a new same-path draft.
  Also switch target while secure-delete awaits: completion must not close the
  new editor or refresh a new server from the old save.
- Actual systemd missing-init/bus and interactive-auth messages map specifically,
  but existing generic shortened-message fixture remains QUERY_FAILED.
- Journal pages: first --lines=200, older --lines=201 inclusive cursor yields
  exactly 200 unique rows; oversized fake response cannot return >200 records.

These are requested proofs, not reported passes. Focused actual command/exits
must be recorded before full suite. AgY owns remaining consumers; no test weaker
expectation just to match unfinished UI.

06:52 follow-up: ServiceManager.action now applies the same _requireSuccess
classifier to nonzero action results as list/logs, before returning success.
Keep synchronous argument validation. Add a mocked restart result with actual
interactive-auth stderr -> SERVICE_PERMISSION_DENIED, and successful action
still returns its original SSHExecutionResult. No real service changes.
