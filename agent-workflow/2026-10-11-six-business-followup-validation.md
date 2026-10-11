# Six-business follow-up — test evidence

Model: opencode/step-5-preview-free (main/small), no paid fallback.
NO production/UI/generation/build/ADB/git edits. Test-only proofs, run one
focused file in the foreground, real `flutter` exit captured under pipefail
into owned `/tmp/opencode` logs. Only listed files were edited:
`test/infrastructure/system_service_safety_followup_test.dart`,
`test/core/sftp_transfer_records_test.dart`, and this doc.

Proven rows (each with a recorded exit 0):

| # | Proof | File |
|---|---|---|
| 6 | real systemd missing-init vs interactive-auth classify; generic shortened msg keeps QUERY_FAILED | system_service_safety_followup_test.dart |
| 7 | 201 inclusive cursor older page ⇒ exactly 200 unique rows; oversized response capped 200 | system_service_safety_followup_test.dart |
| — | ServiceManager.action maps interactive-auth failure ⇒ SERVICE_PERMISSION_DENIED; clean result returned unchanged | system_service_safety_followup_test.dart |
| 2 | failed same-path reread clears old snapshot/content, refuses save with the new token, no remote save | sftp_transfer_records_test.dart |
| 3 | same-revision restored draft ⇒ `editorOriginalContent` stays the remote baseline, editor shows the draft; mismatched revision retains draft, `editorOriginalContent` is the new remote, save refuses `SFTP_EDIT_DRAFT_CONFLICT`, `ops.saves` empty | sftp_transfer_records_test.dart |
| 4a | over-limit draft then valid text flushes and clears the size error | sftp_transfer_records_test.dart |
| 4b | async failed OLD same-path secure write cannot banner a newly opened editor | sftp_transfer_records_test.dart |
| 5a | gated same-path deletion serialized before a reopened same-path write (`events == ['delete','save:…']`), current draft survives | sftp_transfer_records_test.dart |
| 5b | failing secure-delete surfaces (`SFTP_DRAFT_SAVE_FAILED`-path throws to caller), serialized chain recovers on later write | sftp_transfer_records_test.dart |
| 5c | old save whose secure-delete is pending throws `SFTP_EDITOR_EXPIRED`; new editor path/content preserved; no directory refresh | sftp_transfer_records_test.dart |

Scope caveat (target-specific variant NOT tested):
- 5c was proven only via the EDITOR variant — the stale save is invalidated by
  reopening a different file (`editorEpoch != _editorEpoch` guard). The
  separate "switch active server target while the delete is pending" variant
  (which trips `!_currentSource(sourceEpoch)` on a source change) was NOT
  exercised; it remains unproven here.
- #1 SystemProvider missing-start-identity whitespace stays in Phase1's
  `system_provider_target_test.dart` (already passed there); not touched or
  claimed by this slice.

## Recorded runs (exact exit)

- `flutter test test/infrastructure/system_service_safety_followup_test.dart`
  → `FLUTTER_TEST_EXIT=0`, `+5`. log `/tmp/opencode/system_service_safety_followup2.log`
- `flutter test test/core/sftp_transfer_records_test.dart`
  → `FLUTTER_TEST_EXIT=0`, `+38: All tests passed!` (31 original + 7 races).
  logs `/tmp/opencode/sftp_draft_races2.log`, `/tmp/opencode/sftp_draft_races3.log`
- combined cross-check → `FLUTTER_TEST_EXIT=0`, `+41` (turn 3).

## Fixtures / mechanism (no SSH/secure server, no real host, no production hooks)

- `_MemorySecureStorage` gained only: `deleteGate`, `deleteEntered`,
  `deleteFailure` Completers and an ordered `events` trace; save/delete append
  `events` after a committed mutation. `_FakeService`, `_container`, transfer
  fixtures reused untouched; `ops.listedPaths` used as the refresh probe (no new
  counter needed).
- Races are driven by Completers (deterministic), not timers.
- Draft-key/revision proof seeds a draft by open→type→flush→close then reopens,
  and toggles the remote by `ops.contents[path]`, so `readTextSnapshot`'s digest
  flips without any injected key arithmetic.

No source/UI bug surfaced — the provider's `saveFileContent` epoch guard +
`_editorDraftWrites` serialization, `discardEditorDraft`, `flushEditorDraft`,
and `ServiceManager.action`/`_requireSuccess`/`logs` all behave as specified for
every proven row.
