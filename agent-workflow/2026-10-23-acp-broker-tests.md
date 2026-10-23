# ACP broker and daily update prompt tests — 2026-10-23

Verification-only run (OpenCode). Production files were not modified by this
work. Core was actively changing under Codex; tests target the checked-in
`assets/runtime/acp_broker.py` and `lib/core/providers/app_update_provider.dart`
as present at run time.

## Deliverables

| File | Role |
| --- | --- |
| `test/infrastructure/acp_broker_test.py` | stdlib `unittest` coverage for the durable stdio ACP broker |
| `test/core/app_update_provider_automatic_prompt_test.dart` | focused Riverpod tests for daily auto checks / prompt claims |

No UI, generate, build, ADB, push or release steps were run.

## Broker test design

- Embedded fake stdio ACP agent (`fake_acp_agent.py` written into the fixture
  temp HOME). No production Agent, no real servers, no listening TCP ports.
- Per-fixture temp `HOME`; runtime paths resolve under
  `$HOME/.local/share/valhalla/acp-runtime-v1`.
- Spawned attach PIDs, serve PIDs (journal `meta.pid`) and agent PIDs (pidfile)
  are tracked. `tearDown` kills **only those exact PIDs** (never pattern
  `pkill`).
- Client commands use the broker envelope `{"frame": {...}, "turnId": "..."}`.

### Cases (6)

1. `test_permissions_paths_are_0700_and_0600` — runtime root + key dir `0700`,
   `config.json` and unix socket `0600`.
2. `test_timed_chunks_survive_attach_death_and_reconnect_cursor` — fake agent
   emits 4 timed `session/update` chunks (250ms apart). Attach is SIGKILLed
   after `chunk-0`; serve PID stays alive; state reaches `completed`. Reconnect
   with `afterSeq` = observed cursor replays only `chunk-1..3` + turn event.
3. `test_prompt_idempotency_with_turn_id` — same `turnId` + same params replays
   the stored result (agent prompt count stays 1). Different params under the
   same `turnId` returns `ACP_RUNTIME_IDEMPOTENCY_CONFLICT` (core added
   input-hash idempotency during this run).
4. `test_permission_pending_across_detach_with_single_explicit_answer` —
   pending `session/request_permission` survives attach death; reconnect sees
   it; one explicit answer is forwarded exactly once; a second answer does not
   reach the agent.
5. `test_dead_process_fails_without_restart` — after SIGKILL of the serve PID,
   a new `attach` exits 1 with `ACP_RUNTIME_PROCESS_EXITED` and does not spawn
   a replacement worker (journal `meta.pid` unchanged).
6. `test_closing_attach_does_not_stop_worker` — killing the attach client leaves
   the worker alive; a new attach can complete a prompt.

### Command and result

```text
$ python3 test/infrastructure/acp_broker_test.py -v
test_closing_attach_does_not_stop_worker ... ok
test_dead_process_fails_attach_without_restart ... ok
test_permission_pending_across_detach_with_single_explicit_answer ... ok
test_permissions_paths_are_0700_and_0600 ... ok
test_prompt_idempotency_with_turn_id ... ok
test_timed_chunks_survive_attach_death_and_reconnect_cursor ... ok
----------------------------------------------------------------------
Ran 6 tests in 3.473s

OK
```

## app_update_provider automatic-prompt tests

Focused on the new core APIs: `appUpdateNowProvider`,
`AppUpdateState.pendingAutomaticPrompt`, `claimAutomaticPrompt()`, and
`LocalStorageService.getUpdatePromptRecord` / `saveUpdatePromptRecord`.

Fakes only: `_FakeUpdateService` (no HTTP), mocked method channels, mock
`SharedPreferences`, overridden `appUpdateNowProvider` clock.

### Cases (6)

1. `daily auto check uses the local calendar day from appUpdateNowProvider` —
   first success arms the prompt and stores `lastSuccessDate`; same local day
   does not re-check; next local day checks again.
2. `a successful check with no update never arms a prompt` —
   `updateAvailable=false` ⇒ `pendingAutomaticPrompt=false`; claim is false.
3. `claimAutomaticPrompt allows one claim per local day` — first claim true and
   writes `lastPromptDate`; same-day re-claim false; next local day can claim
   again.
4. `a failed daily check retries only after at least 15 minutes` — failed check
   stores `lastAttemptAt` without `lastSuccessDate`; `checkIfDue` at +14min
   does not hit HTTP; at +15min the retry runs and can arm the prompt.
5. `background defers both the daily check and the prompt claim` — background
   `checkIfDue` performs no HTTP; background `claimAutomaticPrompt` returns
   false and leaves `pendingAutomaticPrompt` true for foreground.
6. `disabling automatic checks blocks checks and clears a pending prompt` —
   `setAutomaticCheck(false)` clears the pending prompt and blocks further
   daily checks; claim is false.

### Command and result

```text
$ flutter test test/core/app_update_provider_automatic_prompt_test.dart
00:01 +1: daily auto check uses the local calendar day from appUpdateNowProvider
00:01 +2: a successful check with no update never arms a prompt
00:02 +3: claimAutomaticPrompt allows one claim per local day
00:02 +4: a failed daily check retries only after at least 15 minutes
00:02 +5: background defers both the daily check and the prompt claim
00:02 +6: disabling automatic checks blocks checks and clears a pending prompt
00:02 +6: All tests passed!
```

## Notes / core observations (not fixed here)

- During the run, core gained prompt input-hash idempotency
  (`ACP_RUNTIME_IDEMPOTENCY_CONFLICT` when the same `turnId` is reused with
  different params). Tests were aligned to that contract; no core edit was
  made.
- After detach mid-prompt, the RPC waiter can remain bound to the dead attach
  connection. A reconnecting client observes completion via the durable turn
  journal event, not via the original RPC response frame. Tests assert the
  journal path. Flagged for core/UI consumers if a live RPC reply is required
  after resume.
- Broker test suite leaves only unittest `ResourceWarning`s about unclosed
  pipes on killed attaches; no functional failures.

## Gates touched

- Prompt acceptance idempotent — covered (same params replay; different params
  conflict).
- Reconnect cursor + missing frames — covered.
- Permission pending across detach; single explicit answer — covered.
- Process dead fails without restart — covered.
- Daily calendar check / 15min failure backoff / once-per-day claim /
  foreground defer / auto disabled — covered at provider level.

UI consent dialog, recovery notice, and root-route claim coordination remain
UI-ownership (not in this run). No release claims.
