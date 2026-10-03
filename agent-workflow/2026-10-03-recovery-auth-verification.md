# Recovery / Auth / Download — Final Verification

OpenCode (main + small model: confirmed-free local endpoint, 0 cost) — same original session.

## Model exception

MiMo hit upstream 429 (2026-10-03 ~13:26 UTC); `big-pickle` also 429 (~13:32:16 UTC). Root verified
`space-bunny-free` active with input/output/cache read/write all 0 and the official pricing page lists it
Free. Work before the switch is recorded as MiMo-era, after the switch as space-bunny-free-era. No paid
model was used. All work below was produced under space-bunny-free.

## Exact commands and results

| Step | Command | Exit | Result |
|---|---|---|---|
| l10n | `flutter gen-l10n` | 0 | generated (l10n.yaml used) |
| format | `dart format <92 changed lib/ + test/ dart files>` | 0 | 0 changed on re-check |
| analyze | `flutter analyze --no-pub` | 0 | `No issues found! (ran in 3.4s)` |
| focused | `flutter test --no-pub <24 files>` | 0 | `+404: All tests passed!` |
| full suite | `flutter test --no-pub` | 0 | `+1881 ~18: All tests passed!` (0 failures) |
| APK backup | `cp -p app-release.apk app-release.apk.bak-20261003-224443` | 0 | 123736478 B, sha256 `5f0f3bae…` (identical to pre-build) |
| release build | `flutter build apk --release` | 0 | `✓ Built … (123.9MB)` |
| signature | `apksigner verify --print-certs` | 0 | `C=US, O=Android, CN=Android Debug`, SHA-256 `2faa583f…` |
| install | `adb -s 127.0.0.1:14251 install -r …` | 0 | `Success` |

Logs: `/tmp/opencode/{gen_l10n3,analyze_final5,focused_final2,fullsuite_final2,build_final,install_final}.log`.

### Artifact

- New APK `build/app/outputs/flutter-apk/app-release.apk`
- size `123916842` bytes, mtime `2026-10-03 22:47:01 +08:00` / `14:47:01 UTC`
- SHA-256 `8a0bdd0de0897605623aae9f2745ed49c30d2ff56ebc649079a1905a056cd47f`
- Signer SHA-256 `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`
- **Debug-signed release build — NOT a store release.** Release/store signing is not configured here.

### Install evidence (data preserved)

- Historical prior installation record: `lastUpdateTime=2026-10-03 14:45:52`, `firstInstallTime=2026-09-23 03:26:04`, `signatures:[6e5dbc6]`. This is not a newly captured pre-install update-time check.
- After: `lastUpdateTime=2026-10-03 22:46:59`, `firstInstallTime=2026-09-23 03:26:04` (**unchanged**), `signatures:[6e5dbc6]` (**unchanged**)
- Pre-install signer was verified by pulling the installed `base.apk` and running `apksigner`: digests matched exactly, so `-r` was safe. No uninstall, no clear, no `adb root`.
- Package `com.antigravity.valhalla.valhalla`, device `sdk_gphone64_x86_64` @ `127.0.0.1:14251`.

## Device follow-up (second pass) — what is now proven, and what is not

Same installed APK throughout; **no rebuild, no new APK** (installed artifact is still `8a0bdd0d…`), no UI/credential mutations, no git writes.

### Post-install artifact re-verification (contract step 1)

Pulled the **post-install** base.apk to a distinct filename:

- `adb -s 127.0.0.1:14251 pull /data/app/~~JOoI9S2vKef8zZB2nzRiNQ==/…/base.apk /tmp/opencode/postinstall_base.apk` → `PULL_EXIT=0`
- `sha256sum postinstall_base.apk` → `8a0bdd0de0897605623aae9f2745ed49c30d2ff56ebc649079a1905a056cd47f` — **MATCH=YES** against the built APK
- `apksigner verify --print-certs postinstall_base.apk` → **`VERIFY_EXIT=0`** (recorded standalone, not a piped tail)
- Signer SHA-256 `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`; built APK verify exit `0`

The installed APK is byte-identical to the built artifact and the signature is unchanged. APK is **valid**.

### Correction to the previous report's navigation claim

My earlier taps used incorrectly scaled coordinates, so `s5_agents.png` was still the dashboard and **agent management was not proven** in the first pass. Repeated now with real bounds from `uiautomator dump` (`/tmp/opencode/ui*.xml`):

- drawer `智能会话` `[48,536][1168,760]` → routes to chat, **not** management
- chat header `Antigravity AGY` `[256,362][992,470]` → selector sheet → `管理 Agent` `[472,2768][968,2960]`

`c2_mgmt.png` therefore genuinely shows **agent management**, with real remote probe data and **no manual refresh tap**:

- `已就绪`; `CLI: 已安装`; `ACP: 已就绪`; **`Auth: 已登录`**
- `CLI: agy`, `ACP: agy_acp_server.par`, **`Probe: /root/.local/bin/agy`** (CLI executable detection path, not the credential directory)
- `最近检测: 2026-10-03 23:03:37`

This is stronger than the earlier statement: the management status/auth UI **is** now observed. The page displays `authenticated`; this check did not open its detection log to independently identify which particular login probe/RPC produced that state.

### Bounded background interval (contract step 2)

- 25 s HOME interval, then relaunch; PID **12893 identical before, during and after**.
- Immediate frame (`b1_immediate.png`) and settled frame 12 s later (`b2_settled.png`): same route (智能会话), same agent (`Antigravity AGY`), same retained session content, header and auth card intact — no reset, no spinner, no reload.

### Model candidates — now actually proven (read-only)

The model chip was disabled while the catalog refresh was in flight; after settling, `b5_dropdown.png` + `ui3.xml` show the **live independent CLI catalog candidates** (opened, read, then dismissed with BACK + 取消, nothing selected or saved):

`默认`, `Gemini 3.8 Flash (High|Medium|Low)`, `Gemini 3.7 Flash (High|Medium|Low)`, `Gemini 3.6 Flash (High|Medium|Low)`, `Gemini 3.1 Pro (High)`, `Gemini 3.1 Pro (Low)`

`模型: 默认` remained unchanged afterwards, so no setting was persisted. This corrects the earlier report: the version string `antigravity-acp 1.2.1` came from ACP **initialize** and was *not* catalog proof — the catalog proof is this candidate list.

### 14:49:27 UTC SSH unhandled exception — still UNKNOWN owner

`dart.unhandled SSHStateError(SSH connection closed)` (`TerminalState.terminate` ← `AsyncQueue.closeWithError` ← `SSHClient._terminatePendingOperations` ← `_handleTransportClosed`) remains **unattributed**.

I previously suggested the ping/global-request path owned it; **that attribution is withdrawn and is not proved.** In dartssh2 4.1.0 (`ssh_client.dart:372-385`) `_globalRequestReplyQueue` and `_pendingChannelOpens` are constructed with the **same `_terminalState`**, so whichever queue terminates first captures the error and stack, and the other reuses it. The observed stack therefore cannot distinguish a pending global request (ping) from a pending channel open (exec).

Bounded checks performed:
- `flutter test --no-pub test/infrastructure/ssh_client_manager_transport_test.dart` → **exit 0, `+19: All tests passed`** on current code, including the authenticated real-client pending-ping + socket-drop test. So the known pending-ping path does not fail in isolation.
- **No new isolated test was authored** — without a failing assertion any new test would be speculative.
- I did **not** find a reproducible agent-management trigger this pass: navigating to management with correct bounds did not raise the banner again.

**Cause remains unknown. No product, dependency or vendor change was made, and nothing is claimed as fixed.**

### Explicit limits of this follow-up

- I did **not** open the in-app 应用诊断 dialog after the background interval, so I **cannot state that no new diagnostic events were recorded**. The absence of an on-screen banner is not equivalent to reading the log.
- A bounded relaunch attempt to re-check the banner was interrupted and produced no result; it is not counted as evidence.
- `Auth: 已登录` in management vs `等待 ACP 认证` on the chat card are both observed as-is; I make no claim about which is correct for a new turn, and no consent was performed to reconcile them.
- 320 dp / 2x long-agent-header layout is **still not** proven on device or by a dedicated header regression. The cited 320 dp widget tests cover login navigation/entry layout, not the same long-header/2x-font acceptance case. Current device shows the complete `Antigravity AGY` header label.
- No real conversation, prompt, new chat, history write, SFTP download, remote modification, reboot/shutdown, Google consent, uninstall or data clear was performed.
- The prior full-suite result (`+1881 ~18`) is unchanged; the only test re-run this pass was the 19-test transport file, so no new gate numbers are claimed.

## Regression coverage added this round (all green)

- **`test/infrastructure/agy_model_catalog_test.dart`** (15) — parser (gemini-only, ANSI, dedup/order, empty→`AGENT_MODEL_CATALOG_EMPTY`) and query. Shell quoting is asserted **exactly**, per contract: `cliShellQuote("'agy' models") == r"''\''agy'\'' models"` is pinned, the command equals `bash -l -c ${cliShellQuote("'agy' models")}` **and** the fully literal `r"bash -l -c ''\''agy'\'' models'"`; a metacharacter case pins `r"bash -l -c ''\''agy; rm -rf /'\'' models'"`. Injection protection is not weakened to `contains`.
- **`test/infrastructure/agy_saved_auth_probe_test.dart`** (5) — official AgY: RPC success → `authenticated`; `-32000` → `unauthenticated`; dropped channel → `unknown`; new authorization challenge → `unauthenticated` with **no** `authenticate`/`session/new`/`session/prompt` and the channel released; transport opening after the 20 s timeout is **closed, not leaked** (the late-open cleanup path).
- **`test/infrastructure/agent_environment_agy_auth_test.dart`** (+8) — `validateSavedAuth` gating: called only for `saved` + `oauth-personal`/`oauth-business` + official AgY ACP ready + `requireAcp`; result maps to detail (`authenticated`→null, `unauthenticated`→`AGY_ACP_SIGN_IN_REQUIRED`, `unknown`→`AGY_ACP_CREDENTIALS_NOT_VALIDATED`); not called for `missing`/`unknown`, wrong authType, ACP-missing, `requireAcp:false`, non-AgY.
- **`test/core/agent_registry_provider_test.dart`** (+8) — late construction while already connected inspects without any connection event; concurrent `refresh()` share one in-flight future; concurrent `refreshAgent()` share one probe; editing agent A's execution target never rewrites or re-probes B; `confirmAuthentication` clears the three auth-only details (`AGY_ACP_SIGN_IN_REQUIRED`, `AGY_ACP_CREDENTIALS_NOT_VALIDATED`, `AGY_AUTH_CHECK_UNAVAILABLE`) and preserves unrelated ones (`AGY_AUTH_CHECK_INVALID`).
- **`test/core/reconnect_provider_test.dart`** (+4) — `markConnected` idempotence (no duplicate emission while connected), state machine still schedules exactly one retry after repeated health checks, recovery path stays single-transition, post-`armConnectionSession` health check is side-effect free.
- **`test/core/independent_model_query_test.dart`** (+3) — `settingsFetchedAt` does **not** advance when the independent query fails (timestamp identity, not just non-null) or is unsupported (`AGENT_MODEL_QUERY_UNSUPPORTED`, never a timestamp), and **does** advance on success. No ACP category fallback was revived.
- **`test/core/sftp_download_error_code_test.dart`** (8) + **`test/infrastructure/sftp_download_incomplete_test.dart`** (5) + **`test/core/sftp_provider_test.dart`** (+7) — classification for timeout/link/permission/not-found/local-space/local-IO/incomplete/fallback; early EOF → `SFTP_DOWNLOAD_INCOMPLETE` with partial bytes retained and both handles released; retry gate retries exactly once for TIMEOUT/DISCONNECTED and never for permission/EOF/disk-full, per-transfer retry budget.
- **`test/features/agy_login_survives_route_pop_test.dart`** (1) — official AgY, real button tap once, real ACP `initialize` on the wire, `initialize` deliberately held while the **management route is replaced** (container stays alive), then the gate releases and `authChallenge.methods == ['oauth-personal']` lands in the surviving provider, with **no** `authenticate`, **no** `session/new`, **no** `session/prompt`. Distinct from the container-disposal test in `ai_chat_provider_test.dart`.
- **`test/features/agent_acp_login_navigation_test.dart`** (4) — login navigates immediately while discovery stays pending; navigation does not depend on `pop`; 360 px and **320 dp** layouts keep the ACP entry visible, tappable, and overflow-free.
- **`test/infrastructure/acp_oauth_loopback_test.dart`** (+1) — occupied redirect port makes `bind` throw `SocketException` (surfacing `ACP_AUTH_CALLBACK_LISTENER_FAILED` before any browser) and the port is rebindable after release.

## Test-side fixes (fixtures, not product)

- `_FakeEnvService.validateSavedAuth` getter; connected/switchable connection notifiers now publish `activeServerId` (matches production `connect()`), which is what the new `_isConnected` requires.
- `FakeAcpPair`: added `holdAuthenticate` and a wire-side method observer.
- `antigravity_login_check_command_test`: probe now also reports `credentialDirectory` and `home`; the exact key set was updated and `credentialDirectory` is asserted to live under the fixture `GEMINI_HOME`.
- `server_connection_provider_test`: injects `LocalStorageService`; fake manager implements real `isConnected`/`getClient`. **Real registry, no registry stub** — the `CircularDependencyError` was a production bug (root fixed the imperative bootstrap `ref.read` → `ref.container.read`), not something to mask.
- `agent_execution_target_test`: the fake `docker` keeps the original executable **and** `-lc` flag, prepends a fixture-only PATH **inside the payload**, and answers the selected-user `id -u` / `awk /etc/passwd` lookup with in-fixture doubles. The selected-user case starts from a **different** temp image HOME so the assertion `HOME=homeDocker` proves the production passwd mapping rather than a hardcoded fake answer. No host passwd, no real user rc, no real Codex/ACP.

## Production defect found on device (reported, not fixed by me)

The current device build recorded an unhandled Dart error (diagnostics log, `2026-10-03T14:49:27Z`):

```
[dart.unhandled] SSHStateError(SSH connection closed)
#0 TerminalState.terminate (package:dartssh2/src/utils/terminal_state.dart:30)
#1 AsyncQueue.closeWithError
#2 SSHClient._terminatePendingOperations (package:dartssh2/src/ssh_client.dart:980)
#3 SSHClient._handleTransportClosed (package:dartssh2/src/ssh_client.dart:970)
#4 new SSHClient.<anonymous closure> (package:dartssh2/src/ssh_client.dart:321)
```

The error escapes as unhandled. **Owner unknown** — see the device follow-up section: in dartssh2 4.1.0 the global-request queue and pending-channel-open queue share a single `_terminalState`, so the captured stack does not identify which future escaped. No product change was made by me and nothing is claimed as fixed. The exact trigger is unknown and is **not** proven to be entering agent management nor repeatedly reproducible.

## Read-only racknerd UI / device evidence

Screenshots in `/tmp/opencode/s1_start.png`, `s2_return.png`, `s3_unlock.png`, `s5_agents.png`, `s6_diag.png`, `s8_chat.png`, `s9_selector.png`, `sb_afterauth.png`, `sd_final.png`.

- **Retained data after install**: racknerd profile + credentials survived; app auto-connected on first launch and the dashboard showed live remote metrics (Xeon E5-2690, Debian 13 trixie, kernel 6.7.9, uptime 7d 8h 5m).
- **Home → return**: process stayed alive (pid 12893); on return the dashboard was still connected and metrics refreshed (uptime 5m → 6m). No cold-start snapshot reset.
- **Lock → unlock**: `mWakefulness=Asleep` then wake + dismiss keyguard; state fully retained, still connected, uptime advanced 6m → 7m continuously.
- **Registry auto-selection**: opening 智能会话 auto-selected **Antigravity AGY**; the header agent selector sheet listed `Antigravity AGY — Google Antigravity · Official, ACP server & CLI`. This proves readiness-driven auto-selection only — **not** the management status/auth probe UI (that is now separately observed in the follow-up via `c2_mgmt.png`) and **not** exact credential persistence.
- **Runtime settings**: the 运行设置 sheet displayed real agent version **`antigravity-acp 1.2.1`** from ACP initialize with 模型列表 / 手动输入 available. This alone does NOT prove the independent CLI catalog returned candidate names — that proof is the candidate list captured in the follow-up (`b5_dropdown.png`). The auth card `等待 ACP 认证` and `请求认证` button are present and the composer stays disabled until ACP auth, so no prompt was sent.
- **Management automatic inspection** was **not** proven in this first pass (`s5_agents.png` was the dashboard due to mis-scaled taps); it is proven in the device follow-up with correct bounds.
- `FATAL EXCEPTION` count in logcat was 0. **This does not mean there were no unhandled Dart exceptions** — the app routes those to its own diagnostics log, where the 14:49:27Z entry exists.

## Limits — not claimed

- **No Google consent was performed.** `请求认证` was triggered once accidentally while navigating (first pass); it stayed in-app (no browser/chooser launched, foreground remained `MainActivity`), no OAuth URL was consumed, and no consent was completed. The management card reports `Auth: 已登录`; its exact probe/RPC source was not independently checked in detection logs. No end-to-end credential/callback claim is made.
- **No successful real conversation** — the composer is disabled pending ACP auth; no prompt, new chat, or history edit was made. The visible `回复我ok` bubble is pre-existing user data, untouched.
- 运行设置 was closed with 取消; no run settings were saved and no permission policy was changed.
- No remote modification, restart/shutdown, SFTP download (no harmless fixture file was designated by the user), history deletion, commit or push.
- Debug-signed release APK: not a store release build.
- **Installed APK valid; device acceptance incomplete.** The `dart.unhandled` SSH exception remains with **unknown owner** after the bounded follow-up (shared `_terminalState` in dartssh2 4.1.0 makes the stack non-attributable; the existing 19 transport tests pass on current code). It is not claimed fixed, and no diagnostic log was read after the follow-up interval, so no claim is made about whether new events were recorded.
- 320 dp / 2x long-agent-header layout remains **unproven by this acceptance**: the cited widget tests cover navigation/entry layout, not a dedicated long-header/2x-font case. Model candidates are now proven read-only (`Gemini 3.8/3.7/3.6 Flash`, `Gemini 3.1 Pro`) but nothing was selected or saved.
- Previous `+1808 ~18` figures are historical and are not this round's proof; this round is `+1881 ~18`. The device follow-up re-ran only the 19-test transport file (exit 0), so no new gate totals are claimed.
