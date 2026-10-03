# SSH / ACP auth-disconnect — final gates result report

Contract executed: `agent-workflow/2026-10-03-ssh-auth-disconnect-final-gates.md`
(supersedes diagnosis-only). Session/roles unchanged: main + small
`opencode/mimo-v2.6-flash-free`, continue session
`ses_f0405efacffePPqWyhHc3GGJY7`.

**Status: gates 1–4 executed and GREEN. Gate 5 (device install / startup) is
BLOCKED — the contracted device is unreachable and a new emulator is forbidden
by the contract. Details in §5.**

This report **supersedes** `agent-workflow/2026-10-03-ssh-auth-disconnect-investigation-verification.md`
for diagnosis and chronology; that file includes both pre-patch and first-patch
diagnostic runs, not final acceptance.

---

## 1. Corrected chronology of the defect and the patches

All times local +0800 on 2026-10-03. "Source state" is what `lib/` actually
contained at that moment — the differences between runs are **explained by
root's source changes**, not by flaky test timing.

| # | Time | Source state | What the run showed |
|---|---|---|---|
| 1 | 15:55:31 | original (pre-patch) | `acp_strict_1.log` — **test-harness compile error**: `runZonedGuarded<void>` made `await started` a type error (`This expression has type 'void' and can't be used`). Harness bug only; no product information. |
| 2 | 15:57:19 | original (pre-patch) | `acp_strict_2.log` — (a) red; (b)(c)(d) each hit the 30 s test timeout. Cause was the harness: `_guarded` awaited a future that had been *created inside* the error zone from *outside* it, so the outer `await` never finished. Test-only repair (outer `Completer` completed from inside the guarded body). |
| 3 | **16:01:17** | **original (pre-patch)** | `acp_strict_3.log` — **pre-patch true red proof.** Case (a) reported **both** contract halves: caller error was `Null` *and* an uncaught `Bad state: STDERR_ONLY_FAILURE` whose stack pins the site to `lib/infrastructure/acp/acp_oauth_request.dart:106` (`session.stderr.listen((_) {})`, **no `onError`**) via the `:105` `await client.execute(...)` gap. (b) and (c) passed. (d) failed with an escaping `DONE_REJECTED_EARLY` because the fixture completer was built outside the guarded zone (harness placement, fixed test-only). |
| 4 | 16:05:50 → 16:09:39 | **root FIRST patch** (observers attached, `onError` present) | `focused_final.log`, `acp_final.log`, `focused_final2.log`, `acp_repeat.log`, `focused_authoritative.log` — case (a) still red, but now reporting **only** `caller error was Null ("null") …`, with the uncaught list **empty**. The error is observed by the listener, yet the delivery still resolves normally because **normal completion won the race before stderr was delivered**. This is the **first-patch stderr race**, *not* the original missing-handler behaviour, and *not* an uncorroborated transient — the source changed between step 3 and this step. (d) turned green once the fixture session was constructed inside the guarded zone. |
| 5 | **16:10:45** | **root SECOND patch (current source)** | `lib/infrastructure/acp/acp_oauth_request.dart` now attaches `onDone`/`onError` to `session.stderr` completing a `stderrDone` completer, then runs `Future.wait([stdout fold, stderrDone, session.done, stdin add+close], eagerError: true)` and awaits it under a **20 s** deadline measured after channel opening; `finally` closes the session and **always** `await stderr.cancel()`. No credential, command, routing or UI change. |
| 6 | 16:13:37 | both | Fixture fix (test-only, contract item 1): a native completed exec closes **both** streams, so the fake now closes `stderr` (emitting `onDone`) once the listener has attached; when `stderrErrorOnListen` is set it emits that error first and then closes. |
| 7 | **16:13:51** | both | **Final strict run green — 30/30 (11 callback + 19 SSH), exit 0.** |

### Statements that are now obsolete

- *"`session.stderr.listen` has no `onError` at `:106`"* — true **only** for
  the pre-patch source (step 3). It does **not** describe the latest red and
  must not be used as the current diagnosis; the latest failing behaviour was
  the **normal-completion race** in step 4.
- The earlier note that the differing zone-report between runs was
  "timing-dependent" — **withdrawn**; the difference is a source change by root
  between 16:01:17 and 16:05:50.
- The `guarded fixture` timeouts (step 2) and the compile error (step 1) are
  **test-harness** defects, never product defects, and their repair is
  test-only — they are not a product fix.

---

## 2. Gates executed — commands, true exits, counts

| Gate | Command | Exit | Result |
|---|---|---|---|
| 1 Fixture fix | Edit only `test/infrastructure/acp_oauth_callback_delivery_test.dart` | — | normal fake stderr now closes; error case emits then closes |
| 2 Focused | `timeout 90 bash -o pipefail -c 'flutter test --no-pub test/infrastructure/acp_oauth_callback_delivery_test.dart test/infrastructure/ssh_client_manager_transport_test.dart'` | **0** | `+30: All tests passed!` (log `/tmp/opencode/gates_focused.log`) |
| 3 Format | `dart format` then `dart format --output=none --set-exit-if-changed` on the **3 authorized paths only** | **0** / **0** | `Formatted 3 files (0 changed)` |
| 3 Analyze | `timeout 600 bash -o pipefail -c 'flutter analyze --no-pub'` | **0** | `No issues found! (ran in 2.0s)` |
| 3 Full tests | `timeout 1500 bash -o pipefail -c 'flutter test --no-pub'` | **0** | `+1808 ~18: All tests passed` |
| 4 Backup | `cp -p app-release.apk app-release.apk.bak-20261003-161602` | **0** | see §4 |
| 4 Build | `timeout 1800 bash -o pipefail -c 'flutter build apk --release'` | **0** | `✓ Built … app-release.apk (123.7MB)` |
| 5 Cert | `apksigner verify --print-certs` (build-tools 36.0.0) | **0** | see §4 |
| 5 Install / startup | see §5 | **blocked** | device unreachable; emulator forbidden |

### Verified test counts (counted, not guessed)

```
grep -cE '^\s+test\(' test/infrastructure/acp_oauth_callback_delivery_test.dart  → 11
grep -cE '^\s+test\(' test/infrastructure/ssh_client_manager_transport_test.dart  → 19
```

- **11/11 callback cases pass**, including the 7 pre-existing
  success/routing/secret/limit proofs (host routing, Docker routing, secret off
  the command line, invalid-callback rejection before any channel, non-zero
  exit, non-2xx output, 4096-byte cap) and the 4 strict unobserved-failure
  cases (a)–(d).
- **19/19 SSH transport tests pass**, including the older
  *user-deliberate-disconnect* test (`用户主动 disconnect 不广播 transportDied`)
  and the new real authenticated `SSHClient` fake-socket pending-heartbeat test
  (`已认证真实 SSHClient：verifyAlive 等待期间 socket 掉线 → false 并广播`).
- Skips: `~18` — the same 18 as the previous full baseline, **no new skips**,
  no added `skip`, no relaxed expectation, no assertion weakened.

### Format gate detail

The 3 authorized paths only:

- `lib/infrastructure/acp/acp_oauth_request.dart` (whitespace only — 0 changed,
  no semantic edit)
- `test/infrastructure/acp_oauth_callback_delivery_test.dart`
- `test/infrastructure/ssh_client_manager_transport_test.dart`

---

## 3. What the strict cases now prove (final, passing)

| Case | Assertion that must hold | Result |
|---|---|---|
| (a) stderr-only error, stdout `200`, `done` normal | caller receives **the identical** injected error **and** zero uncaught zone errors | **PASS** |
| (b) stdout error while `stdin.close` is still pending | identical caller error + zero uncaught | **PASS** |
| (c) `stdin.close` itself fails | identical caller error + zero uncaught | **PASS** |
| (d) `done` rejects before stdout completes | identical caller error + zero uncaught | **PASS** |

Both requirements are asserted together in one
`expect(problems, isEmpty, reason: …)` (`_expectStrictFailure`), so a red run
prints the caller failure and the uncaught error side by side.

**Fixture note (documented, not worked around):** the pre-existing `_Session`
still preloads **and closes** stdout at construction — the shape every
success/routing/secret/limit proof depends on. The failure cases opt out
individually via `preloadStdout` / `completeDoneOnCreate` / `onStdinClose` /
`stderrErrorOnListen`. `lib` was never edited to satisfy a mock.

---

## 4. APK evidence

### Backup (older backups preserved, none overwritten)

| File | sha256 | mtime (local +0800) |
|---|---|---|
| `app-release.apk.bak-20261003-133900` | `23cc6e9175643e5c4b17e6c9fc1e9bb9fec8990566f6556f505d103ceef594a8` | 2026-10-03 13:39:00 |
| `app-release.apk.bak-20261003-144316` | `3e748162ab1dc2a29649073d581d73b91d529f6e614251dc078bb64f304b424a` | 2026-10-03 14:43:16 |
| `app-release.apk.bak-20261003-161602` **(NEW)** | `6ff2244ea5cf00db417c3b956b5aa7f2d5332610f1da5bc7315c40e8aa13035e` | 2026-10-03 14:44:39 (mtime preserved by `cp -p`) |

The new backup is a byte-identical copy of the contracted **14:44 APK**
(`6ff2244e…`), taken at 16:16:02 before the rebuild.

### New release build

| Field | Value |
|---|---|
| Command | `flutter build apk --release` |
| Exit | **0** |
| Path | `build/app/outputs/flutter-apk/app-release.apk` |
| sha256 | `5f0f3bae6d07ed83be1c3e2b6c234ce2e9008c1be43dd462d32eb6095aa7c4db` |
| Size | 123736478 bytes |
| mtime | 2026-10-03 16:17:03 +0800 = **2026-10-03T08:17:03Z** |
| Differ from `6ff2244ea5cf00db417c3b956b5aa7f2d5332610f1da5bc7315c40e8aa13035e`? | **YES** (`HASH_DIFFERS=OK`) |

### Signing certificate

```
Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
Signer #1 certificate SHA-256 digest: 2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9
Signer #1 certificate SHA-1 digest:  f0fb4ad6bd3dd2d9513a0573b40910adb4d288c2
Signer #1 certificate MD5 digest:    80633e7c14c1b64a11a6a8b9c874e60a
```

`apksigner` exit **0**. The **same** signer digests are printed for
`app-release.apk.bak-20261003-161602` — i.e. the APK built at 14:44 and installed
at 14:45 — and `~/.android/debug.keystore` is unchanged since
2026-09-13 19:48:08. The new build is therefore **cert-compatible** with the
previously verified installed APK. The live installed package cannot be inspected
while the device is offline; its certificate must be checked again when reachable
before data-preserving `install -r`. This is a release build using the Android
Debug certificate, not a store-signed release.

---

## 5. Device gate — BLOCKED (contract-compliant stop)

Contract item 5 allows **only** the existing device `127.0.0.1:14251`, and
forbids uninstall / `pm clear` / root / **new emulator**.

Evidence collected:

```
$ adb connect 127.0.0.1:14251
failed to connect to '127.0.0.1:14251': Connection refused     (retried twice, same result)

$ adb devices -l
List of devices attached
<empty>

$ adb -s 127.0.0.1:14251 shell …
adb: device '127.0.0.1:14251' not found

$ pgrep -a qemu-system        → none
$ command -v emulator         → absent (no emulator binary installed)
$ find … *.avd / avd.ini      → none (no AVD exists)
$ TCP probe 127.0.0.1:14251   → Connection refused
```

The local adb server is running (`adb -L tcp:5037 fork-server`), but no device is
listed and the endpoint has no reachable listener. This does not establish that
the device itself was removed: the original device or its port forwarding may
need restoration. No broader client/network cause was established.

**Therefore `install -r`, MainActivity start and the finite
process/fatal/ANR logcat check were NOT executed.** Cert compatibility was
established statically from the signer digests (§4) instead. **No new emulator
was created.** The user must restore the original connection or provide its
current address; no need to recreate a device has been established or authorized.

### Separation from earlier device proofs

| Proof | APK sha256 | Status |
|---|---|---|
| 13:40 old browser/session proof (earlier auth-phase report) | `3e748162ab1dc2a29649073d581d73b91d529f6e614251dc078bb64f304b424a` | belongs to the **old** APK; **not** re-executed |
| 14:44 install/startup/logcat proof (earlier final-gates round) | `6ff2244ea5cf00db417c3b956b5aa7f2d5332610f1da5bc7315c40e8aa13035e` | belongs to the **14:44** APK; **not** re-executed |
| **this round's build** | `5f0f3bae6d07ed83be1c3e2b6c234ce2e9008c1be43dd462d32eb6095aa7c4db` | **built and hashed; NOT installed, NOT started** |

No claim is made that any older device action happened on this APK, and no
earlier auth-phase report was modified.

---

## 6. SSH underlying cause

The single real-`SSHClient` reproduction (protocol-injected
`SSH_MSG_USERauth_SUCCESS` on the fake socket, probe started, socket dropped
while the probe is still pending) **passes**: probe was pending at drop, returns
`false`, `isConnected` false, `transportDied` contains the server id.

Because it passes, nothing in the manager/reconnect code was changed and **the
historical racknerd transport-close cause remains UNKNOWN**. No deeper dartssh2
reading, no broader diagnosis.

---

## 7. Explicitly not done

- No UI edit, no semantic `lib` edit (only authorized whitespace formatting,
  which changed 0 bytes), no ARB/`pubspec` change.
- No credential, account, browser/OAuth, database/history read or change; no
  real inference; no new session; no remote probe; no Docker e2e.
- No private host/IP, no authorization code, no callback/challenge URL, no
  screenshot in this report.
- No `git` add/commit/push; no command/routing change.
- Google / live callback / Docker e2e remain **pending user**.

## 8. Pending / next

1. **Gate 5** — needs a reachable `127.0.0.1:14251` (or root's explicit
   approval for an alternative target). Once available:
   `install -r` (data-preserving), start `MainActivity`, finite
   process/fatal/ANR logcat window, and record the result against sha
   `5f0f3bae…` only.
2. Root updates main docs; this report plus the gates above are the evidence.
