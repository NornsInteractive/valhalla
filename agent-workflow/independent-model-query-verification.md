# Independent model query — verification report

Author: OpenCode (verification only, no production/UI edits).
Model actually used: **opencode/space-bunny-free** (main and small).
Date (UTC): 2026-10-01.
Handoff: `agent-workflow/independent-model-query-tests.md` (rev 12:54, read fully at start).

## 0. Headline status

| Gate | Result |
| --- | --- |
| Focused regression (7 files) | **PASS**, exit 0, 104 tests |
| `flutter analyze --no-pub` | **PASS**, exit 0, no issues |
| Full `flutter test` | **PASS**, exit 0, 1447 passed / 17 skipped |
| New release APK | **NOT BUILT** (UI handoff BLOCKED) |
| ADB install / launch | **NOT ATTEMPTED** (no new artifact) |
| Artifact at `build/.../app-release.apk` | **RESTORED OLD APK**, not a new build |
| Real remote agent / real Codex account | **NOT TESTED** (forbidden by handoff) |

**UI blocked ⇒ no build, no install.** `agent-workflow/independent-model-query-ui-status.md`
is `BLOCKED`: the requested UI delivery was never verified (subscriber-fell-behind on
print-mode CLI; interactive eligibility check failed on a Google avatar TCP timeout).
The tiny dialog + ARB slice therefore does not exist in this tree, so building here
would produce an APK that does not contain the requested UI. Per the handoff I did
not build stale sources.

## 1. Production code I did NOT change

Root owns and had already written both production files. My only production-tree
action was `dart format` on the two allowed files, plus a read-only inspection.

- `lib/core/providers/ai_chat_provider.dart`
- `lib/infrastructure/cli/codex_native_client.dart`

No production semantics, no UI/ARB, no `main.dart` edits. The `'cursor': ?cursor`
lint fix and the `openingExpired` late-channel guard were root's; I only added
regression proof for the latter.

## 2. Late SSH channel regression (the only new production branch)

`CodexNativeClient.queryCapabilities` (`lib/infrastructure/cli/codex_native_client.dart:107`)
races a 15s `execute` timeout against a channel that may still arrive.

New test: `test/infrastructure/codex_model_catalog_test.dart`
→ `queryCapabilities：短生命周期官方 app-server SSH 通道迟到时被关闭，且保留原始 TimeoutException`

Fake-clock proof (`testWidgets` fake clock, no real process, no dependency added —
`fake_async` was *not* imported, since the handoff forbids new dependencies):

1. `execute` returns a `Completer<SSHSession>`; the command is recorded.
2. Pump past the production 15s timeout ⇒ query fails with `TimeoutException`
   (original exception retained, not wrapped), and the not-yet-arrived channel is
   not "closed" out of thin air (`closeCount == 0`).
3. The channel then arrives ⇒ `closeCount == 1` (late process reaped, not leaked).
4. The late channel is **never initialized**: `stdinLines`, `requestMethods` and
   `stdoutLines` are all empty.

Root's earlier review of my first log was correct and is reflected in the fixture:
the fake agent's replies must be routed through the bridge's `onReceive`
(`FakeMemoryTransport.send` delivers via `peer.onReceive`, not `peer.send`), and the
fake session's stream controllers are broadcast so `close()` never awaits an
unlistened controller. No assertion or timeout was relaxed.

## 3. Test coverage added

### `test/infrastructure/codex_model_catalog_test.dart` (new, 9 tests, fake `Connection`/`Transport` + fake `SSHSession`/`SSHClient`)

- Cursor pagination across 3 pages; cross-page dedup; skips `hidden:true`, missing
  id, empty id, non-object rows; label/displayName fallbacks.
- `model/list` request params are exactly `limit:100`, `includeHidden:false`, plus
  `cursor` only on later pages.
- Exact read-only RPC surface: `initialize`, `initialized`, `model/list` only; asserts
  no `thread/*`, `turn/*`, `skills/*`.
- Reasoning levels come from `model/list`, deduped, never aliased to `thought_level`.
- Malformed `data` (not a list) ⇒ `FormatException('MODEL_LIST_INVALID_RESPONSE')`.
- Repeated cursor ⇒ `StateError('MODEL_LIST_CURSOR_REPEATED')`, stops after 2 requests.
- `queryCapabilities` uses the same execution target/user as the ACP channel
  (`bash -l -c … app-server` on host; `docker exec -i --user 'codex' 'val-codex' …`
  with `/bin/bash` preference on docker) and always closes the short-lived process.
- Query failure still closes the process and surfaces the original `RpcError`.

### `test/core/independent_model_query_test.dart` (new, 17 tests, provider with injected catalog)

- Unsupported agent: catalog `null` ⇒ empty model list, `settingsStale == true`,
  `lastErrorCode == 'AGENT_MODEL_QUERY_UNSUPPORTED'`, **no** `session/list` fallback,
  no `session/new`; send still succeeds with defaults.
- Draft prepare: catalog fills models, `settingsStale == false`, no
  `session/new`/`session/load`/`session/prompt`.
- Existing-history refresh: no extra `session/new`, no `session/load`, no prompt,
  established transport preserved (`pairs` stays length 1).
- Obsolete `config_option_update` push cannot overwrite the catalog; it may still
  supply `currentModelId` for the current selection.
- A catalog model absent from older ACP config options can still be applied through
  the advertised model config id; agent rejection falls back to the actual value
  (no optimistic confirmation).
- Query failure keeps the previous list and marks stale.
- Late catalog result after an agent switch is discarded; `cliCommand` change forces
  a re-query with the new command.
- Explicit saved Codex model is independently validated before the first send; a model
  absent from the catalog raises `ACP_SETTING_UNAVAILABLE` instead of silently
  switching.
- Real application stays protocol-confirmed: when the agent ignores the requested
  value, `runSettings.modelId` keeps the agent's actual value (API-listed ≠ adapter
  support ≠ entitlement).
- Default `agentModelQueryProvider` returns `null` for a non-Codex agent without
  touching the network.

### Existing fixtures maintained (no assertion removed, no skip added)

- `test/core/ai_chat_provider_test.dart`: `acpContainer` now takes an optional
  `modelQuery` and defaults to an explicit injected provider, so capability tests
  no longer depend on the agent's CLI-type classification. The two affected tests
  were updated to the new contract, not weakened:
  - `prepareRunSettings 无论是否刷新都复用已建立的连接` (was: "refresh rebuilds the
    connection") — now asserts refresh reuses the connection, adds no `session/new`,
    no `session/load`, no prompt. The old assertion contradicted the contract
    ("NEVER recreates established working ACP transport on refresh").
  - `model_config 不作为 thought_level 推理兜底` — now injects a catalog
    (`gpt-5-codex`) that deliberately differs from the session config options and
    asserts models come from the independent query while `model_config` stays an
    extra setting.
- `test/core/ai_chat_usability_test.dart`: `makeContainer` takes an optional
  `modelQuery` with an explicit default provider. Per root's correction I did **not**
  change the remote-history `launchKey` fixture string (format is unchanged, no
  `cliCommand` suffix); I reverted my initial wrong edit.
- `test/support/fake_acp_transport.dart`: added `session/set_config_option` handling
  (`setConfigOptionRequests`, `failSetConfigOption`, `ignoreSetConfigOption`,
  `rejectedConfigValues`) and a `deliverConfigOptions` helper so obsolete-config-push
  and protocol-confirmed-apply behavior can be asserted.

## 4. Gate commands and true exit codes

All run in `/workspace/projects/valhalla` on the final tree, after the last edit.
`flutter test` exits 0 on success in this setup; failures would exit non-zero.

| # | Command | Exit | Evidence |
| --- | --- | --- | --- |
| 1 | `dart format` on the 2 production files + 5 test files | 0 | `agent-workflow/imq-format.log` |
| 2 | `flutter test test/infrastructure/codex_model_catalog_test.dart` (late-channel test) | 0 | `/tmp/opencode/late2.log` |
| 3 | `flutter analyze --no-pub` | **0** | `agent-workflow/imq-analyze.log` — "No issues found!" |
| 4 | `flutter test <7 focused files>` | **0** | `agent-workflow/imq-focused.log` — "104 tests, All tests passed" |
| 5 | `flutter test` (full suite) | **0** | `agent-workflow/imq-fulltests.log` — "1447 passed, ~17 skipped, All tests passed" |
| 6 | `apksigner verify -v --print-certs` (old artifact) | 0 | `agent-workflow/imq-signature.log` |

Focused file list for gate 4: `codex_model_catalog_test.dart`,
`independent_model_query_test.dart`, `ai_chat_usability_test.dart`,
`ai_chat_provider_test.dart`, `native_cli_protocol_test.dart`,
`chat_run_settings_test.dart`, `acp_run_settings_metadata_test.dart`.

A genuine earlier baseline run (`/tmp/opencode/baseline-focused.log`, 7 failures) is
kept as history and is **not** presented as passing evidence. Those 7 failures were
all fixture drift against the new production behavior and were resolved in the
fixtures/tests above, not by loosening assertions.

## 5. Aborted stale build (recorded, not hidden)

An earlier runner spawned `flutter build apk --release` (timeout wrapper PID 23911,
underlying runner PID 15893) before its CLI was interrupted. That build's shell ran
`rm -f build/app/outputs/flutter-apk/app-release.apk build/.../app-release.apk.sha1`,
which deleted the previous generated artifact. Root stopped the scoped build with
TERM 23911. No APK was produced, no install was authorized.

Check at final-gates time (04:59 UTC): **no build/gradle/adb process running** —
only an idle Gradle daemon (PID 23993) and this OpenCode runner (PID 25049).

## 6. Artifact: RESTORED OLD APK, not a new build

Backup verified against the handoff's recorded value before restoring:

- SHA256 of `/tmp/opencode/final_installed_base.apk`
  = `1af486e7dec5c32ea1cc6ba487d2a4f1a1e3b60a3208d97fe381ca571610bdb3` — **matches**
  the handoff's expected hash.
- Signature: APK Signature Scheme **v2** only (v1/v3/v3.1/v4 = false), 1 signer,
  `CN=Android Debug`, cert SHA-256
  `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`
  (`agent-workflow/imq-signature.log`, `apksigner` exit 0).

Restored copy (mtime preserved from the backup, not the original build-output timestamp):

| Field | Value |
| --- | --- |
| Path | `build/app/outputs/flutter-apk/app-release.apk` |
| mtime | 2026-09-30 16:12:32 UTC (2026-10-01 00:12:32 +0800), inherited from the backup |
| Size | 123108211 bytes |
| SHA256 | `1af486e7dec5c32ea1cc6ba487d2a4f1a1e3b60a3208d97fe381ca571610bdb3` |
| Provenance | **OLD stable APK, restored from backup. NOT built from this slice's sources.** |
| Backup retained | `/tmp/opencode/final_installed_base.apk` (not deleted) |

Root metadata correction: the original prior build output was generated at
2026-09-30 16:12:14 UTC; the installed-artifact backup has a later 16:12:32 UTC
mtime. `cp -p` preserved that backup timestamp. Neither timestamp denotes a new
build of the current code. The identical hash is the provenance proof.

The `.sha1` sidecar was removed by the aborted build and is intentionally **not**
recreated, because regenerating it from a copied artifact could imply a fresh build.

**This APK does not contain the independent-model-query provider changes, and it does
not contain the (blocked, undelivered) UI work. It must not be treated as evidence for
this slice.**

## 7. Explicitly NOT verified

- No release build from current sources; no install on `127.0.0.1:14251`; no cold
  start; no logcat/ANR capture. (All blocked by the UI status.)
- **No real remote agent test.** No real Codex/AgY prompt, no real thread
  create/load/resume, no credential read, no remote CLI upgrade, no user data deleted
  — all forbidden by the handoff. Real `model/list` paging behavior, real cloud
  catalog freshness and real account entitlement are therefore **unproven**.
- `model/list` may be bundled/cached by Codex itself; per the contract these tests do
  not assert cloud freshness or verified entitlement.
- No HTTP credential/export implementation exists in this slice.
- UI behavior for an empty catalog / stale metadata is untested because that UI does
  not exist (BLOCKED).

## 8. Production bug report

**None found.** No production defect surfaced by the focused or full suites; the
analyzer is clean. The 7 pre-existing baseline failures were test-fixture drift
against intended new behavior, resolved in fixtures only. No production semantics
were altered by me, so no root-level fix is required.

## 8b. Final formatting/whitespace gate (direct commands, no pipeline)

| Command | Exit | Output |
| --- | --- | --- |
| `dart format --output=none --set-exit-if-changed lib/core/providers/ai_chat_provider.dart lib/infrastructure/cli/codex_native_client.dart test/core/independent_model_query_test.dart test/infrastructure/codex_model_catalog_test.dart test/core/ai_chat_provider_test.dart test/core/ai_chat_usability_test.dart test/support/fake_acp_transport.dart` | **0** | `Formatted 7 files (0 changed)` — already formatted |
| `git diff --check` | **0** | no whitespace/conflict errors |

No code changes, no test rerun, no build, no ADB, no dependency changes for these
two checks.

## 9. Log index

Gates: `agent-workflow/imq-format.log`, `imq-analyze.log`, `imq-focused.log`,
`imq-fulltests.log`, `imq-signature.log` (`*.log` is gitignored). Interim
non-gate logs: `/tmp/opencode/late2.log`, `/tmp/opencode/baseline-focused.log`.

`agent-workflow/imq-build.log` is **not** a gate: it is the truncated log of the
**aborted stale build** from section 5 (Gradle started, then TERMed; no APK
produced). It is kept only as evidence of the abort. There is no successful build
log and no `adb` log for this slice, by design.
