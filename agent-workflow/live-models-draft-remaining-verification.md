# Remaining business proof — verification report — 2026-10-01

Handoff: `agent-workflow/live-models-draft-remaining-tests.md` (3 missing proof items).
Prior report: `agent-workflow/live-models-draft-verification.md` (1495 pass / 17 skip,
explicit missing acceptance = the 3 items below).

**Result: all three items proven by runnable tests. Full suite green, no production edit by this task.**

> **Addendum — final narrow regression (same day, second gate run).** Root fixed the
> §4 defect in `lib/infrastructure/cli/codex_model_authorization.dart` (production edit
> is root's; this pass touched only the security test and this report). This pass
> strengthened `test/infrastructure/codex_model_authorization_security_test.dart`
> (17 → **19** tests) and re-ran every gate. A `+1530 ~17` figure is the
> **previous snapshot**; the authoritative full-suite count is **`+1532 ~17 -0`** in §5.
> Corrected per-file counts for item 1/2: provider **32**, diagnostics **6**,
> resume **9** (total **47**), measured by running each file on its own.

---

## 0. Scope actually executed

| | |
|---|---|
| Production/UI/auth/history edits | **none by this task** (`lib/` untouched by this task). Root separately fixed `lib/infrastructure/cli/codex_model_authorization.dart` (§4); that file was only **formatted**, never semantically edited here. |
| Build / APK / ADB | **none**; `git status` has **0** `apk`/`build/` entries; the 3 APKs keep their original mtimes (`app-debug.apk` 9/29 11:43, `app-profile.apk` 9/19 09:31, `app-release.apk` 10/1 00:12) |
| Real credentials / real files / real network / real SSH / inference | **none** |
| New dependency | **none** (only `dart:*`, `package:*` already in the project, plus the system `node`) |
| Files added by this task | `test/infrastructure/codex_model_authorization_node_exec_test.dart` |
| Files edited by this task | `test/infrastructure/codex_model_authorization_security_test.dart` (final regression) + this report; earlier transient probes were deleted, see §6 |

---

## 1. Item 1 — composer draft discovery / coalescing / late-result guard

Covered inside the existing `test/core/independent_model_query_test.dart` harness
(the handoff forbade a second harness). The file now runs **32 tests, all pass**
(`flutter test --no-pub test/core/independent_model_query_test.dart` → `+32`, exit 0).
What this task added to it:

- `prepareComposerCatalog` on an empty draft passes the selected Docker profile/user
  + cwd `/workspace/app`, sends **only** `initialize` (`sentMethods == ['initialize']`),
  creates **no** session and sends **no** prompt.
- `$skills` is merged with a later `available_commands_update` notification, stays
  ordered before protocol commands, and is not overwritten by that notification.
- A failed skills query does **not** block ordinary `sendMessage`.
- Overlapping `prepareComposerCatalog` + `prepareRunSettings` → transport `pairs`
  length **1** (provider-level `_adapterFor` coalescing, not `initializeOnly`).
- Late result arriving after `switchAgent` is discarded (no state write).
- `setDraftWorkingDirectory` / draft update path makes no session and no RPC.

Also proven (item 1/2 overlap):

- `updateRunSettings` on a draft issues **no** session/RPC; protocol-confirmed
  model → reasoning order is preserved and filtered (`modelAfter()` helper only
  rebuilds the model when `configId == 'model'`, so `thought_level` keeps the live model).

## 2. Item 2 — ACP `-32603` diagnostics

New file `test/infrastructure/acp_error_diagnostics_test.dart` (**6 pass**, `+6`,
exit 0) plus one added assertion in
`test/infrastructure/acp_session_resume_test.dart` (**9 pass**, `+9`, exit 0).

Corrected per-file counts for items 1+2, each file run on its own:
provider **32** + diagnostics **6** + resume **9** = **47**.

- `session/new` failure → `ACP_SESSION_PREPARE_FAILED: session/new: ...-32603`
- `session/load` failure → `...: session/load: ...-32603`
- `session/resume` failure → `...: session/resume: ...-32603`
- load/resume failure keeps the **no-new-session** fallback.
- `session/set_config_option` `-32603` → `ACP_SETTING_APPLY_FAILED: model:` carrying the
  real `configId`.
- non-`-32603` → raw `RpcError` code preserved (type/flow unchanged).
- auth `-32000` → `ACPAuthRequiredEvent`, **not** a prepare diagnostic.
- Existing resume/load-failure test now also asserts the exact
  `ACPErrorEvent.error == 'ACP_TRANSPORT_FAILURE: Bad state: ACP_SESSION_RESTART_REQUIRED'`.

Fixture knobs added to `test/support/fake_acp_transport.dart` (test-only):
`sessionNewErrorCode` / `sessionLoadErrorCode` / `sessionResumeErrorCode`
(null keeps old behaviour), `setConfigOptionErrorCode`, and
`configOptionsAfterChange` so a `session/set_config_option` can mutate the stored
options *before* the response is built.

---

## 3. Item 3 — real execution of the embedded Node OAuth runtime

**This is the headline of this report. The scripts were executed, not substring-matched.**

### 3.1 Where the scripts came from

Captured from the *actual commands production sends*, exactly like the existing
static-review test:

- authorize target = `decodeScript(CodexModelAuthorization.authorize(...).commands.single)`
  driven by the fake SSH + loopback callback (`$runtime` + `_authorize`),
- models target = `decodeScript(CodexAccountModels.command(profile()))`.

Both are asserted to start with `CodexModelAuthorization.runtime`, then written to
`/tmp/opencode/lmd-node/{authorize,models}.js` by the test itself.

### 3.2 How the runner isolates everything

The runner (`/tmp/opencode/lmd-node/runner.js`, 20 062 bytes) is embedded verbatim in
the test as `_runnerSource` (raw Dart string; byte-identical, verified) and is written
to disk on every run. Per scenario it starts a fresh Node process.

| Surface | What the script sees |
|---|---|
| `require('fs')` | in-memory store (`/vh/**`), `open/mkdir/read/write/rename/unlink/lstat/close` recorded to an ops log; `EEXIST`/`ENOENT`/`EISDIR` emulated; mode + uid carried per node |
| `require('path'/'os'/'crypto'/'readline')` | real Node modules; `os.homedir()` → `/vh` |
| any other `require` | throws `require blocked by runner: <name>` |
| `process` | fake: `argv = ['node','credkey-test']`, `env.CODEX_HOME = '/vh/.codex'`, `getuid() = 1000`, stdout captured line-by-line, `once/on/exit` no-ops |
| `fetch` | recorded then answered by a scenario handler; unknown host → throws (no network ever leaves the process) |
| `AbortSignal` / `Buffer` / `URL` | real |
| `crypto` (RSA, SHA-256, sign/verify) | **real** — a fresh 2048-bit RSA keypair is generated per process and published as the mock JWKS |

Seed fixtures: ephemeral `auth.json` (`auth_mode: chatgpt`, an RS256 `id_token`
signed with the *same* ephemeral key), and `credentials.json` records. Nothing in
`$HOME`, nothing on the real disk, nothing on the real wire.

Mock endpoints (5, all recorded into `report.fetchedUrls`):
`/.well-known/openid-configuration`, `/.well-known/jwks`, `/api/accounts/oauth/token`,
`/v1/models`.

### 3.3 Sandbox assertions applied to **every** scenario

`_expectSandboxed(report)` asserts: no runner crash; `stdoutLeaksToken == false`;
no `.tmp` leftover; lock released; **every** `fetchedUrls` entry is one of the 5
allow-listed `https://auth.openai.com` / `api.openai.com` URLs; **every** fs op path
starts with `/vh/` (the fake root) — so nothing outside the fake filesystem was touched.

### 3.4 The 21 scenarios and their actual results

Authorize target (14):

| # | scenario | asserted actual outcome |
|---|---|---|
| 1 | `authorize_ok` | `authorized:true`; URL `https://auth.openai.com/authorize?...`, `redirect_uri=http://127.0.0.1:5555/auth/callback`, `resource=https://api.openai.com/v1`, `code_challenge_method=S256`; exactly **1** token POST `grant_type=authorization_code`; **`pkceMatches=true`** (SHA-256(verifier) == challenge) and **`pkceVerifierDiffers=true`**; credential `mode 600`/`uid 1000` with `AT-NEW`/`RT-NEW`; ops = `open(lock,wx,0600)` → `write(*.tmp,wx,0600)` → `rename(tmp→credentials.json)` → `unlink(tmp)` → `unlink(lock)`; **no** direct `write` to `credentials.json` |
| 2 | `authorize_state_mismatch` | `AGENT_MODEL_CALLBACK_INVALID`, **0** token POSTs, no credential, no lock, no credential write |
| 3 | `authorize_declined` | `AGENT_MODEL_AUTH_DECLINED`, **0** token POSTs, no credential |
| 4 | `authorize_client_mismatch` | `AGENT_MODEL_CLIENT_MISMATCH`, **0** token POSTs, no lock, previous `OLD-AT`/`OLD-RT` untouched |
| 5 | `authorize_bad_signature` (signed with a *different* RSA key) | `AGENT_MODEL_IDENTITY_INVALID`, 1 token POST, stored record has **no** `access_token`/`refresh_token` |
| 6 | `authorize_bad_audience` (`aud` = `someone-else`) | `AGENT_MODEL_IDENTITY_INVALID`, 1 token POST, no tokens stored |
| 7 | `authorize_expired` (`exp` now−1h) | `AGENT_MODEL_IDENTITY_INVALID`, 1 token POST, no tokens stored |
| 8 | `authorize_bad_nonce` | `AGENT_MODEL_IDENTITY_INVALID`, 1 token POST, no tokens stored |
| 9 | `authorize_bad_subject` | `AGENT_MODEL_ACCOUNT_MISMATCH`, 1 token POST, no tokens stored |
| 10 | `authorize_missing_grant` (scope without `chatgpt.tokens.use.direct`) | `AGENT_MODEL_PLAN_PERMISSION_REQUIRED`, 1 token POST, no tokens stored |
| 11 | `authorize_rebind_failed_exchange` (record rebound to account B, token endpoint 401) | `AGENT_MODEL_AUTH_EXPIRED`; **the stored record contains no `access_token` and no `refresh_token`** — the rebind dropped the old tokens *before* the exchange, so a failed exchange leaves **no** usable credential |
| 12 | `authorize_same_account_failed_exchange` | `AGENT_MODEL_AUTH_EXPIRED`; `OLD-AT`/`OLD-RT` retained and **no** new token written — binding unchanged, so retention is correct |
| 13 | `authorize_endpoint_blocked` (discovery `jwks_uri` → `https://evil.example/jwks`) | `AGENT_MODEL_ENDPOINT_INVALID`; **`evil.example` never appears in `fetchedUrls`** — rejected before `fetch` |
| 14 | `authorize_endpoint_insecure` (`authorization_endpoint` → `http://...`) | `AGENT_MODEL_ENDPOINT_INVALID`; **no** authorization URL emitted, **0** token POSTs, no credential, only the discovery URL fetched |

Account-models target (7):

| # | scenario | asserted actual outcome |
|---|---|---|
| 15 | `refresh_ok_atomic_write` | `accountKey` = sha256(`sub:account_id`) for account A; `models` = exactly `[{slug: gpt-5-codex, display_name: Codex, visibility: list}]` (the `visibility:'none'` row is filtered); 1 token POST + 1 models GET; credential `mode 600` with `AT-NEW`/`RT-NEW`; `open(lock,wx,0600)`, one `write(*.tmp,wx,0600)`, `rename(tmp→credentials.json)`, `unlink(tmp)`, `unlink(lock)`; **no** direct `write` to `credentials.json` |
| 16 | `refresh_post_lock_account_rebind` (mutated to account B **inside** the lock, at `openSync` time) | `AGENT_MODEL_ACCOUNT_MISMATCH`; **0** token POSTs, **0** models GETs — the binding is re-read under the lock *before* any network call |
| 17 | `refresh_post_lock_scope_rebind` (scopes shrunk to `['openid','profile']` under the lock) | `AGENT_MODEL_PLAN_PERMISSION_REQUIRED`; **0** token POSTs, **0** models GETs |
| 18 | `storage_unsafe_mode` (file `0644`) | `AGENT_MODEL_AUTH_STORAGE_UNSAFE`; **0** network, **0** fs ops |
| 19 | `storage_unsafe_owner` (file `uid 999` vs `getuid()=1000`) | `AGENT_MODEL_AUTH_STORAGE_UNSAFE`; **0** network, **0** fs ops |
| 20 | `storage_symlink` (`credentials.json` is a symlink) | `AGENT_MODEL_AUTH_STORAGE_UNSAFE`; **0** network, **0** fs ops, credential never loaded |
| 21 | `storage_dir_unsafe_write` (directory `0777`) | `AGENT_MODEL_AUTH_STORAGE_UNSAFE`; **0** `write`, **0** `rename`, no temp file; credential on disk unchanged (`OLD-AT`); lock still released |

`_run()` fails the test (does **not** skip) if `node` cannot be started, with the
message *"Node 安全证明不可用 … 绝不允许把静态断言当成安全通过"*. There is no
environment / branch / cwd gate anywhere in the file.

### 3.5 Observation (not a security bypass)

In scenario 21 the refresh token POST happens **before** `writeRecord`'s directory
mode check, so one refresh round-trip is spent and then refused
(`tokenFetchCount == 1`, `modelsFetchCount == 0`, credential unchanged).
If the token endpoint rotated the refresh token server-side, the on-disk record could
become unusable and force a re-login. This is reachable only when the credential
directory is already world-writable — i.e. only in a state where the credential is
already untrustworthy — so it is reported as an observation, not patched.

---

## 4. Production defect — reported, then fixed by root, now pinned by a test

**`CodexModelAuthorization.authorize` used to swallow two of its own fixed error codes.**

### 4.1 What the defect was

- Location: `lib/infrastructure/cli/codex_model_authorization.dart`
  - `:302` — `throw StateError('AGENT_MODEL_ENDPOINT_INVALID')` when the remote
    authorization URL is not `https` / not `auth.openai.com` / wrong `redirect_uri` / wrong `resource`.
  - `:306` — `throw StateError('AGENT_MODEL_CALLBACK_INVALID')` when `state` is missing/empty.
  - `:331` — the surrounding `catch (error)` completed with
    `StateError('AGENT_MODEL_AUTH_FAILED')` unconditionally, so both codes above were
    replaced by `AGENT_MODEL_AUTH_FAILED`.
- Exact evidence produced in the previous pass (transient probe, deliberately failing,
  then deleted): feed `authorizationUrl = http://evil.example/auth?...`
  → `Expected: 'AGENT_MODEL_ENDPOINT_INVALID'` / `Actual: 'AGENT_MODEL_AUTH_FAILED'`.
  Log: `/tmp/opencode/lmd-defect-probe.log`.
- Why it was invisible: the old assertion only checked
  `matches(RegExp(r'^AGENT_MODEL_[A-Z_]+$'))`, which `AGENT_MODEL_AUTH_FAILED` also satisfies.
- Not affected: a *remote-emitted* `{"error":"..."}` line maps correctly at `:321–330`,
  and the Node-level proof (§3.4 scenarios 13/14) shows the script itself emits the
  right code. The loss happened only on the Dart side.

### 4.2 The fix (root's production edit — read, not written by this task)

`catch (error)` at `:331` now completes with `error.message` **only** when the caught
object is a `StateError` whose message is exactly `AGENT_MODEL_ENDPOINT_INVALID`
or `AGENT_MODEL_CALLBACK_INVALID`; every other parse/`Uri` error still collapses to
`AGENT_MODEL_AUTH_FAILED` (`:331–343`). Verified by reading the diff and by the tests
in §4.3. The file was run through `dart format` only (allowed), semantics untouched.

### 4.3 Test strengthening (this task, `test/infrastructure/codex_model_authorization_security_test.dart`, 17 → 19)

| line | test | asserts |
|---|---|---|
| `:261` | 非法 authorizationUrl 一律精确报 ENDPOINT_INVALID，且不启动浏览器 | **replaces** the old regex-only assertion. Table of 4 cases, each violating exactly one constraint — 明文 http 端点 / 非 auth.openai.com 主机 / `redirect_uri` 不是本机回环回调 / `resource` 不是 v1 — each must throw **exactly** `AGENT_MODEL_ENDPOINT_INVALID`; **`browserCalls` empty** and `closeCount >= 1` retained for every case |
| `:309` | 授权 URL 缺 state：精确报 CALLBACK_INVALID，且不启动浏览器 | **new.** A fully valid endpoint URL with no `state` query param must throw **exactly** `AGENT_MODEL_CALLBACK_INVALID`; browser never opened |
| `:342` | authorizationUrl 连 Uri.parse 都过不去：仍折叠成 AUTH_FAILED | **new.** `https://[::1` makes `Uri.parse` throw `FormatException` → still **exactly** `AGENT_MODEL_AUTH_FAILED`, proving the fix preserves *only* the two local codes; browser never opened |

No production, UI, auth or history file was edited. No transient probe was created
(this run) — the evidence above comes from tests that stay in the tree.

---

## 5. Final gates (authoritative — rerun after the §4 fix and the §4.3 test edits)

| gate | command | result |
|---|---|---|
| format | `dart format --output=none --set-exit-if-changed` on `lib/infrastructure/cli/codex_model_authorization.dart` (root's file, allowed) + `test/infrastructure/codex_model_authorization_security_test.dart` | `Formatted 2 files (0 changed)`, **exit 0**; the catch-condition fix survived formatting unchanged |
| analyzer | `flutter analyze --no-pub` | `No issues found! (ran in 3.6s)`, **exit 0** |
| auth-focused suites | `flutter test --no-pub` on `codex_model_authorization_security_test.dart` + `codex_model_authorization_node_exec_test.dart` | **`+40 ~0 -0`, exit 0** — log `/tmp/opencode/lmd2-authfocused.log` |
| per-file counts (run alone) | `flutter test --no-pub <file>` | security **`+19`** exit 0 (`/tmp/opencode/lmd2-security.log`); provider **`+32`** exit 0 (`/tmp/opencode/lmd2-independent_model_query_test.log`); diagnostics **`+6`** exit 0 (`/tmp/opencode/lmd2-acp_error_diagnostics_test.log`); resume **`+9`** exit 0 (`/tmp/opencode/lmd2-acp_session_resume_test.log`) |
| full suite | `flutter test --no-pub` | **`+1532 ~17 -0`, exit 0** — log `/tmp/opencode/lmd2-fulltests.log` (388 KB) |

Number cross-check (all exit 0):

- previous handoff baseline: `+1495 ~17` (`/tmp/opencode/lmd-fulltests.log`),
- full suite with the Node-exec file removed: `+1509 ~17`
  (`/tmp/opencode/lmd-remaining-baseline.log`) → that file contributes exactly **+21**,
- `1509 + 21 = +1530` = the **previous snapshot** (`/tmp/opencode/lmd-remaining-final.log`),
- `1530 + 2 = +1532` = this run, the **+2** being the two new §4.3 tests
  (`:309` CALLBACK_INVALID, `:342` AUTH_FAILED sanitization), the third one at `:261`
  being a strengthening of an existing test, not a new one,
- `1509 − 1495 = +14` came from other test files that changed in the shared tree
  between those two runs; **none** of them were authored or edited by this task.

Sanity: `git status` still has **0** `apk`/`build/` entries; no `zz_*` file exists.

## 6. Transient files created and removed

From the earlier pass only; **the final §4 regression created no transient file.**

| file | why | status |
|---|---|---|
| `test/infrastructure/zz_dump_scripts_test.dart` | one-off capture of the two production scripts | **deleted** |
| `test/infrastructure/zz_defect_probe_test.dart` | produced the §4 failure evidence | **deleted** |

`git status --short test/` contains no `zz_*` entry.

---

## 7. What is still NOT proven (explicit gaps)

1. **Mock, not live.** The proof exercises the script's control flow and validation
   logic against a simulated OpenAI authorization server. It does **not** prove
   behaviour against the real service, and no real JWKS/nonce/redirect was ever used.
2. **Emulated POSIX semantics.** The fake `fs` reproduces Node's documented outcomes
   (`ENOENT`/`EEXIST`/`EISDIR`, `lstat` mode + uid) rather than running libuv. Kernel
   DAC checks (e.g. `EACCES` from the OS because a parent dir is `0777`) are not
   simulated — production does not rely on them, it performs its own explicit
   `directory.mode & 0o077` check, which **is** exercised (scenario 21).
3. **Single process only.** `withCredentialLock` exclusivity is shown inside one
   process via `openSync(..., 'wx')`; cross-process lock contention and
   `AGENT_MODEL_AUTH_BUSY` are not exercised here (they remain static-review only).
4. **Signals not exercised.** `SIGTERM`/`SIGINT` → `releaseLock()` is not driven
   dynamically (the fake `process.once` is a no-op).
5. **Readline re-entrancy not exercised.** The `processing` guard is not tested with
   two lines delivered concurrently.
6. ~~**The §4 Dart-side defect still stands**~~ — **resolved.** Root's fix preserves
   exactly `AGENT_MODEL_ENDPOINT_INVALID` and `AGENT_MODEL_CALLBACK_INVALID`; the three
   §4.3 tests pin both directions (both codes exact, and every other parse/`Uri` error
   still folding to `AGENT_MODEL_AUTH_FAILED`).
7. **No build / install / ADB / UI READY** — explicitly out of scope for this handoff.

## 8. STOP

- All three handoff items remain proven by runnable tests (§1–§3), unchanged by this pass.
- The §4 defect is now **fixed by root** and **pinned** by 3 tests in §4.3 (17 → 19).
- Corrected counts: provider **32** + diagnostics **6** + resume **9** = **47**;
  security **19**; Node-exec **21**.
- Authoritative gates (§5): format **exit 0**, `flutter analyze --no-pub` **exit 0**,
  auth-focused **`+40` exit 0**, full **`+1532 ~17 -0` exit 0**.
- Model: main and small both **`opencode/mimo-v2.6-flash-free`** for this whole session.
- Edits this pass: only `test/infrastructure/codex_model_authorization_security_test.dart`
  and this report. No production/UI/auth/history edit, no transient probe, no real
  credential/network, no build or ADB.

No further work performed.
