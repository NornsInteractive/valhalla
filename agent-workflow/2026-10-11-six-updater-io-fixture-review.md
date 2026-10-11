# Exact async fixture review after additional updater cases

Actual /tmp/opencode/six-phase1/provider-phase1c.log: old pause/resume test at
test410 expects service.downloadCalls1 but sees0. It uses `await pump()` with
12 zero-duration turns after notifier.download. reservePath still does genuine
async filesystem mkdir/exists before entering the fake download; a fixed count
of event-loop turns is not an IO acknowledgment.

Do not claim later case6 pollutes earlier case3: tests are sequential and setUp
already creates fresh service/storage/temp/path-platform per case. Extra resets
would not establish the desired await boundary. Confirm actual causal evidence,
not a guessed cross-test ordering. No production changes are warranted here.

OpenCode owns the fixture fix: add a small Completer acknowledgment INSIDE the
fake download method, complete on entry; await that explicit event (bounded
timeout) before asserting writer counts/pausing. Reset/rotate for next writer as
needed. Use the same event in tampered-download test rather than unbounded polls
or fixed 12 turns for OS file allocation. Preserve counts, path/artifact identity,
pause-resume/cancel/no-install assertions. Remove redundant per-case resets if
added solely for the guessed cause. Keep all failed logs. No repeated loops to
claim a flaky check fixed; run once after deterministic adapter boundary, then
whole-suite foreground gate. Report exact failure and fix without attributing
the separately lost old NAS assertion to this cause.

Only owned updater tests/report; no core/UI/ARB/dependencies/build/ADB/git writes.
