# ACP broker final tests — 2026-10-23

Python broker tests only. Production `assets/runtime/acp_broker.py` untouched.

## Changes to `test/infrastructure/acp_broker_test.py`

- `_start_attach`: added `bufsize=0` to `subprocess.Popen` so `select.select(proc.stdout)` observes raw bytes instead of buffered-prefetched data.
- Restored prompt result waits using `_read_frames` predicates asserting the actual response frame (and turn/response ordering in `test_terminal_turn_journal_precedes_prompt_rpc_response`), instead of `_collect_frames` + sleep.
- `tearDown`: spawned attach `Popen` objects are now `.wait()`ed (via `_stop_attach`) after PID kill and pipes closed, eliminating `ResourceWarning`s.

## Run 1

Command: `timeout 120 python3 test/infrastructure/acp_broker_test.py`

Exit code: 0
Elapsed: 10.075s (wall 10.124s)

```
Ran 12 tests in 10.075s

OK
```

## Run 2

Command: `timeout 120 python3 test/infrastructure/acp_broker_test.py`

Exit code: 0
Elapsed: 9.886s (wall 9.936s)

```
Ran 12 tests in 9.886s

OK
```

No `ResourceWarning`s in either run.
