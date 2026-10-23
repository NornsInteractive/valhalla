# ACP Closeout Check — 2026-10-23

Scope: narrow commands only. No formatting, no build/ADB/push, no product (lib/) edits.

## 1. Broker test (source changed: pending permissions clear)

Command:

```
python3 test/infrastructure/acp_broker_test.py
```

Result: **PASS — 12/12 tests, OK (9.795s)**

```
test_closing_attach_does_not_stop_worker ... ok
test_completed_agent_exit_does_not_become_failed_or_exited ... ok
test_dead_process_fails_attach_without_restart ... ok
test_expired_retention_clears_events_and_turn_result_after_7d ... ok
test_expired_retention_does_not_expire_running_task ... ok
test_expired_retention_does_not_expire_waiting_task ... ok
test_permission_pending_across_detach_with_single_explicit_answer ... ok
test_permissions_paths_are_0700_and_0600 ... ok
test_prompt_idempotency_with_turn_id ... ok
test_session_cancel_while_pending_permission_ends_cancelled ... ok
test_terminal_turn_journal_precedes_prompt_rpc_response ... ok
test_timed_chunks_survive_attach_death_and_reconnect_cursor ... ok

----------------------------------------------------------------------
Ran 12 tests in 9.795s

OK
```

## 2. Import cleanup (only if analysis reported)

First `flutter analyze --no-pub` reported 2 issues:

```
info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check • lib/features/chat/widgets/persistent_runtime_consent_dialog.dart:250:36 • use_build_context_synchronously
info • The import of 'dart:async' is unnecessary because all of the used elements are also provided by the import of 'package:flutter_test/flutter_test.dart' • test/core/app_update_provider_automatic_prompt_test.dart:6:8 • unnecessary_import
2 issues found. (ran in 12.0s)
```

Action taken:

- **Removed** `import 'dart:async';` from `test/core/app_update_provider_automatic_prompt_test.dart` (line 6). This was the only file edited by this run.
- **NOT removed**: `session_recovery_status.dart` import in `test/core/acp_durable_recovery_test.dart` — analysis did **not** report it as unnecessary, so per the "if analysis reports" condition it was left untouched.

## 3. Flutter tests

Command:

```
flutter test test/core/acp_durable_recovery_test.dart test/features/connection_status_banner_test.dart --timeout=120s
```

Result: **PASS — All tests passed! (38/38, 00:04)**

Breakdown:

- `test/core/acp_durable_recovery_test.dart`: 6 tests — all passed
  - production flag consent send holds draft and inserts no messages
  - approval installer override called once preserving draft
  - dismissRecoveryNotice retains status/diagnostics
  - AgentChatContext runtimeKey/cursor roundtrip
  - ChatMessage runtimeTurnId roundtrip
  - managed recovery regression
- `test/features/connection_status_banner_test.dart`: 32 tests — all passed
  - includes `update notice priority 320dp 2x ar update notice remains dismissible` and all banner/recovery-row routing cases

No banner test failures — nothing to record for AgY banner/ARB handoff.

## 4. Final analyze

Command:

```
flutter analyze --no-pub
```

Result (after import removal): **1 issue found (9.6s)**

```
info • Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check • lib/features/chat/widgets/persistent_runtime_consent_dialog.dart:250:36 • use_build_context_synchronously
```

**Reported, not touched:** `use_build_context_synchronously` at
`lib/features/chat/widgets/persistent_runtime_consent_dialog.dart:250:36`
(UI file — left as-is per instructions while AgY finishes banner+ARB work.)

## Summary

| Check | Result |
| --- | --- |
| `python3 test/infrastructure/acp_broker_test.py` | PASS (12/12) |
| Import `dart:async` removal (test/core/app_update_provider_automatic_prompt_test.dart) | Done (reported by analyze) |
| Import `session_recovery_status.dart` removal (test/core/acp_durable_recovery_test.dart) | Skipped — not reported by analyze |
| `flutter test ... --timeout=120s` | PASS (38/38, incl. banner tests) |
| `flutter analyze --no-pub` | 1 remaining info: `use_build_context_synchronously` @ persistent_runtime_consent_dialog.dart:250 (reported, untouched) |

Files edited by this run: `test/core/app_update_provider_automatic_prompt_test.dart` only (plus this report).
No build, no ADB, no push, no other product edits.
