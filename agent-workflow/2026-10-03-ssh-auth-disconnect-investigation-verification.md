# SSH / ACP auth disconnect investigation — result report

## Root review correction (supersedes source diagnoses below)

The tests/results quoted below are diagnostic-stage evidence, not final gates.
Source changed during this stage: root first patched the business helper after
`acp_strict_3.log` (09 pass / 02 fail), then added stderr-drain success gating
after the later `focused_authoritative.log` (29 pass / 01 fail). OpenCode did not
edit product source. The latest red run therefore does NOT prove the listener
still had no onError: it already had one, but Future.any let normal completion
win before the queued stderr error. The no-handler explanation at :106 applies
only to the original prepatch source. Changed-source later runs cannot be called
an unstable reproduction of the original zone leak. Initial guard/zone fixture
timeouts are also not product evidence.

Final patch now waits for BOTH streams to finish before success, alongside stdin
and channel completion. The normal fake must close stderr as native finished
sessions do; this is a fixture correction, not permission to weaken assertions.
See 2026-10-03-ssh-auth-disconnect-final-gates.md for the assigned fresh full gates,
APK and ADB task; until that report exists, no final success is claimed. Historical
racknerd transport-close cause remains UNKNOWN; the passing fake-socket manager
probe does not establish why the real network closed.

The final-gates report now exists: `2026-10-03-ssh-auth-disconnect-investigation-result.md`
(focused 30/30 exit 0, analyze 0, full tests `+1808 ~18` exit 0, release build
exit 0 with a new hash, device gate blocked).

Scope executed exactly as narrowed: tests + diagnosis only. No `lib/`, ARB,
`pubspec`, build, ADB, git, or package-source exploration. Two test files were
touched, both formatted.

## 1. What was added

### `test/infrastructure/acp_oauth_callback_delivery_test.dart` (461 lines)

| Item | Location |
| --- | --- |
| Fixture limitation note | `:49` |
| `_Session` extended with `preloadStdout`, `completeDoneOnCreate`, `stderrErrorOnListen`, `onStdinClose`, `emitStdoutError`, `finishStdout`, `rejectDone` | `:55-142` |
| `_RecordingSink` gains an optional `onClose` hook so `stdin.close` can be delayed or failed | `:23-46` |
| `_Outcome` / `_guarded` — guarded zone + **outer `Completer<_Outcome>` completed from inside the guarded body** + 2 microtask drains + 2 s bounded timeout | `:192-241` |
| `_expectStrictFailure` — one list holding **both** the caller-failure problem and every uncaught zone error | `:243-255` |
| 4 new strict cases under `group('unobserved failure modes')` | `:366-461` |

Each case asserts, in a single `expect(problems, isEmpty)`:

1. the caller received **the identical injected error**, and
2. **zero** uncaught zone errors were reported.

No assertion was weakened, no `lib` code was changed to make anything pass, and
the 7 pre-existing success/routing/secret/limit proofs are untouched.

### `test/infrastructure/ssh_client_manager_transport_test.dart` (594 lines)

| Item | Location |
| --- | --- |
| `import 'package:dartssh2/src/message/msg_userauth.dart'` (implementation import, ignored — the package's own tests import it this way) | `:9-12` |
| **One** real-`SSHClient` reproduction | `:409-…` |

The reproduction: real `SSHClient` on the existing `_FakeSshSocket`,
`client.handlePacket(SSH_Message_Userauth_Success().encode())`, register it via
`_managerWithClient` with a 2 s `verifyAliveTimeout`, start `verifyAlive('s1')`
without awaiting, drop the socket 50 ms later **while the probe is still
pending**, then assert.

## 2. Commands, true exit codes, results

Authoritative run (both files, `timeout 90`, explicit exit):

```
timeout 90 bash -o pipefail -c 'flutter test --no-pub \
  test/infrastructure/acp_oauth_callback_delivery_test.dart \
  test/infrastructure/ssh_client_manager_transport_test.dart'
EXIT=1
```

Result: **29 passed, 1 failed** (`+29 -1`, `Some tests failed`).

Per case:

| Case | Result |
| --- | --- |
| (a) stderr-only error, stdout 200, `done` normal | **FAIL (red)** |
| (b) stdout error during delayed `stdin.close` | PASS |
| (c) `stdin.close` failure | PASS |
| (d) `done` rejects before stdout completes | PASS |
| 7 pre-existing ACP proofs | PASS (unchanged) |
| 18 pre-existing + **1 new** SSH transport tests | PASS |

Format gate:

```
dart format --output=none --set-exit-if-changed <both files>   EXIT=0  (re-check, 0 changed)
```

The deliberate non-zero exit of the focused run is case (a) failing — it is
the red evidence, not a harness problem.

## 3. Red evidence — case (a), exact failing assertion

Log: `/tmp/opencode/focused_authoritative.log`

```
Expected: empty
  Actual: [
            'stderr-only error (stdout=200, done normal): caller error was Null ("null") but expected the identical injected error "Bad state: STDERR_ONLY_FAILURE"'
          ]
  stderr-only error (stdout=200, done normal): caller error was Null ("null") but expected the identical injected error "Bad state: STDERR_ONLY_FAILURE"

package:matcher                                                   expect
package:flutter_test/src/widget_tester.dart 473:18               expect
test/infrastructure/acp_oauth_callback_delivery_test.dart 255:3  _expectStrictFailure
test/infrastructure/acp_oauth_callback_delivery_test.dart 381:7  main.<fn>.<fn>
```

Meaning: with `stdout` already carrying `200` and `done` already complete, an
error on `stderr` is **swallowed** — `deliverAcpOAuthCallback` resolves
normally (`thrown == null`) instead of failing the caller. The product surface
for this is `session.stderr.listen((_) {})` in
`lib/infrastructure/acp/acp_oauth_request.dart:106`, which attaches no
`onError`, so the error never reaches the delivery's control flow.

### Zone-leak observation (one run, not reproduced later)

An earlier run of the same case also reported the identical error into the
guarded zone:

```
log: /tmp/opencode/acp_strict_3.log
'stderr-only error (stdout=200, done normal): uncaught zone error:
  Bad state: STDERR_ONLY_FAILURE
  dart:async/broadcast_stream_controller.dart 262:39  _BroadcastStreamController.addError
  test/infrastructure/acp_oauth_callback_delivery_test.dart 120:40  _Session.stderr.<fn>
  ...
  package:valhalla/infrastructure/acp/acp_oauth_request.dart 106:26  deliverAcpOAuthCallback
```

That is the exact `:106` listener with no `onError`. It did **not** reproduce
in the four later runs (`acp_final.log`, `acp_repeat.log`,
`focused_final.log`, `focused_authoritative.log`), where the `uncaught` list
came back empty — which zone ultimately receives that report is
timing-dependent in this fixture. Reported here as observed, not as a stable
result. The strict assertion checks `uncaught` is empty on **every** run, so a
regression in either direction still fails the test.

## 4. Fixture limitation (flagged, not worked around)

The pre-existing `_Session` shape preloads **and closes** `stdout` at
construction while `stderr` stays open until `close()`. Every existing
success/routing/secret/limit proof depends on that shape. The new failure cases
opt out individually (`preloadStdout: false`, `completeDoneOnCreate: false`,
`onStdinClose`, `stderrErrorOnListen`) instead of changing `lib`. Documented at
`:49-54` of the test file. This is a **fixture limitation**, not a product
defect; no product code was altered to satisfy it.

Case (d) builds its `_Session` **inside** the guarded zone so a rejection that
nobody has observed yet is reported to the assertion rather than escaping to
the test runner. It still attaches its observation to the delivery immediately
(`scheduleMicrotask(rejectDone)` → `scheduleMicrotask(finishStdout)` →
`await deliverAcpOAuthCallback(...)`), so the harness itself can never
manufacture an unobserved caller-side error.

## 5. SSH reproduction — transport-close cause: **UNKNOWN**

New test `已认证真实 SSHClient：verifyAlive 等待期间 socket 掉线 → false 并广播`
**PASSES**, with all four assertions green:

- `pendingAtDrop == true` — the probe was genuinely still waiting when the
  socket dropped;
- `alive == false` — `verifyAlive` reached the caller with `false` instead of
  hanging;
- `manager.isConnected('s1') == false` — the dead transport was cleaned up;
- `died` contains `'s1'` — the death was signalled for reconnect.

Because the reproduction passes, there is no failing behaviour to narrow
further here. The historical cause of the observed auth/disconnect event
therefore remains **UNKNOWN**, and per the stop directive no broader
diagnosis, no further dartssh2 reading, and no `lib` changes were made.

## 6. Not done (out of scope by instruction)

- No `lib/`, ARB or `pubspec` edits.
- No `flutter analyze`, full-suite run, APK build or ADB/device work.
- No `git` operations; no shell/Python file writes (Edit/apply_patch only).
- No further package source reading beyond the import path needed for
  `SSH_Message_Userauth_Success`.
- Root's diagnostic run was stopped by root; specific Flutter/opencode PIDs
  were killed, no real app process was affected.

## 7. Follow-up (requires a new, explicitly approved contract)

1. Decide the intended contract for `deliverAcpOAuthCallback`: should an error
   on `stderr` fail the delivery? If yes, give `session.stderr.listen` an
   `onError` (`lib/infrastructure/acp/acp_oauth_request.dart:106`) and re-run
   case (a), which must then turn green with `problems` empty.
2. If case (a) is instead considered expected behaviour, the contract for the
   test must be revised explicitly — the assertion was not weakened here.
