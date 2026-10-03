# OpenCode Verification Report — ACP & Reconnect (2026-10-02)

- **Model**: `opencode/mimo-v2.6-flash-free` (main **and** small/sub-agent, no paid substitution)
- **Task source**: `agent-workflow/2026-10-02-acp-and-reconnect.md`
- **Status**: **TEST + FORMAT + ANALYZE + FULL SUITE + RELEASE BUILD GREEN**; **ADB INSTALL GATE BLOCKED** (no device/listener on `127.0.0.1:14251`)
- **Git**: no mutations performed (only read-only `git status` / `git diff --name-only` / `git ls-files --others` / `git show`). No commit, push, reset or revert.

---

## 1. Scope actually executed

| Phase | Authorized? | Run? |
|---|---|---|
| Test-only edits under `test/` | yes | yes |
| `flutter gen-l10n` | yes (final gate) | yes |
| `dart format` on changed Dart files | yes (final gate) | yes |
| `flutter analyze` | yes (final gate) | yes |
| Full `flutter test` | yes (final gate, AgY FINAL UI READY + exit 0) | yes |
| `flutter build apk --release` | yes (only after all gates green) | yes |
| `adb install -r 127.0.0.1:14251` + startup/crash/ANR check | yes (only after build) | **BLOCKED — see §7** |
| Product/UI edits | **forbidden** | none performed |
| Real Codex/ACP inference, credentials, auth, history edits, remote installs | forbidden | none performed |

**Not run on purpose**: real ACP session against a live agent (still untested by design).

---

## 2. Gate results (actual commands, actual exits)

Every exit below was captured as `$?` directly after the command (or `set -o pipefail` + `$?`), never via a `tail`/`tee` pipeline.

| # | Command | Exit | Result |
|---|---|---|---|
| G1 | `flutter test --no-pub` (four focused files: `background_recovery_ui_test`, `background_recovery_cli_test`, `cli_chat_view_test`, `connection_status_banner_test`) | **0** | `+72: All tests passed!`, 0 `[E]` |
| G2 | `dart format --output=none --set-exit-if-changed <46 changed dart files + the untracked antigravity test>` (final verify, after root's brace fixes) | **0** | `Formatted 47 files (0 changed)`; unique set = 46 files, all clean |
| G3 | `flutter gen-l10n` | **0** | l10n.yaml options used, no generated-file drift |
| G4 | `flutter analyze --no-pub` | **0** | `No issues found! (ran in 2.3s)` |
| G5 | `flutter test --no-pub` (whole `test/` tree) | **0** | `+1664 ~17: All tests passed!` → **1664 passed, 17 skipped, 0 failed** |
| G6 | `flutter build apk --release` | **0** | `✓ Built build/app/outputs/flutter-apk/app-release.apk (123.3MB)` in 74.1s |

### Intermediate logic gates (earlier in the same session, before the final format/analyze/full run)

| Command | Exit | Result |
|---|---|---|
| `flutter test --no-pub` targeted recovery set (`background_recovery_chat_state`, `agent_registry_provider`, `connection_lifecycle`, `background_recovery_lifecycle`, `chat_message_contract`, `chat_recovery_merge`, `ai_chat_provider`, `test/data`) | **0** | **265 passed** |
| `flutter test --no-pub test/core` | **0** | **616 passed** (was 578/14 before fixture updates) |
| `flutter test --no-pub test/data` | **0** | **164 passed** |
| `flutter test --no-pub test/infrastructure/antigravity_acp_install_test.dart` (dirty Antigravity mocked install) | **0** | **6 passed**, offline/mocked only — no real remote install |
| `flutter analyze --no-pub` (pre-format) | **0** | `No issues found!` |

---

## 3. Test edits made (test/ only)

### 3.1 `test/core/background_recovery_chat_state_test.dart`
- Added `loseTurn(container)` (real transport loss → `ChatTurnStatus.unknown` + `reconnecting`) and `cancelTurn(container)` (`stopGeneration()` → `interrupted`) fixtures.
- Recovered-state fixtures converted from the obsolete `reconnecting`/`failed` expectation to the approved contract; message list is now `['old question','old answer','in flight','']`.
- **Updated obsolete assertions + reason**:
  - "健康已完成的会话断线后没有待恢复的 turn，不该自愈回放" → `idle` + load/resume/new/prompt deltas all **0** (was `reconnecting` + replay).
  - Successful loss recovery is `incomplete`, not `idle`: replay cannot prove the lost turn completed — never claim a complete restore.
  - Single-flight test: `resume` delta **0** (was 1) → `retainReplayAdapter()` keeps the already-loaded adapter, so no second `session/resume` and no second replay.
  - "没有回放能力时诚实降级" now also asserts exact deltas: load **+1**, resume **0**, new **0**, prompt **0** — unsupported replay reuses the retained *initialized* transport instead of inventing a session.
- **New tests (2)**: "健康已完成的会话断线重连不触发任何远端回放" and "前台回到前台不会重放被用户取消的 turn，显式恢复才同步" (auto path deltas all 0; explicit `recoverConnection()` load delta 1, prompt delta 0 — old `interrupted` records stay explicitly retryable, foreground alone never replays them).

### 3.2 `test/core/agent_registry_provider_test.dart`
- "disconnected ssh blocks refresh with actionable error" → **"disconnected ssh blocks refresh but keeps the last snapshot"**: refresh is still refused (`inspectedAgentIds == ['a1']`) but cached agent state survives (`isReady` true, `errorMessage` null, `isLoading` false). Approved behavior: disconnected status is retained, not wiped.
- "resets runtime status when the connection drops" → **"retains runtime status when the connection drops"**: snapshot + `inspectedAgentIds` unchanged, and `installAgent`/`loginAgent` are still guarded (`installedAgentIds`/`loggedInAgentIds` empty, `errorMessage == AgentRegistryNotifier.disconnectedCode`). Identity/security/no-weaken preserved.

### 3.3 `test/core/connection_lifecycle_test.dart`
- "detached 不停止前台服务，也不暂停重连" → **"detached 不停止前台服务，暂停重试但保留用户意图"**: `service.stopCalls == 0` (FGS kept), `userIntent` true, `isReconnecting` false while detached, **`scheduler.pendingCount == 0` and `attempts == 0`** during pause.
- Added `_FakeScheduler`/`_FakeTimer` seam to this file (same seam as `background_recovery_lifecycle_test`) so counter assertions are exact, not tautological.
- New test **"detached 暂停重试，回前台复验失败后恰好补试一次"**: no attempt during pause → failed foreground verification → **exactly one** pending attempt with `delay == Duration.zero` → fires once (`attempts == 1`) → connected → `pendingCount == 0`.
- Line-272 `isConnected isFalse` → `isTrue`: resume marks connected when verification passes (was asserting the old "always reconnect" behavior).

### 3.4 `test/core/background_recovery_lifecycle_test.dart`
- "detached 不撤前台服务，也不放弃用户意图" → **"detached 不撤前台服务，暂停重试但保留用户意图"** with `ssh.probeAlive` drive + `scheduler.pendingCount == 0`.
- New test **"后台一次尝试都不发，回前台复验失败后恰好补试一次"**: during pause `pendingCount == 0` / `attempts == 0` / `userIntent` true; after failed verification `pendingCount == 1` with `Duration.zero`, `attempts == 0` before fire; after `fireLatest()` exactly `attempts == 1`, connected, `pendingCount == 0`.

### 3.5 contentBlocks contract tests (added)
- `test/data/chat_message_contract_test.dart` — group `contentBlocks 有序渲染契约`, **8 tests**: text coalescing, tool first-seen anchoring, empty range, status does not reorder, JSON round-trip with emoji UTF-16 offsets, legacy tools-then-text fallback, gap / non-covering / unknown-tool / duplicate degradation, malformed JSON dropped. Uses a local `shapes()` helper because `ChatContentBlock` has no `==`.
- `test/data/chat_recovery_merge_test.dart` — group `contentBlocks and transport-loss status survive a replay`, **3 tests** (`_message` helper extended with `contentBlocks`/`status`).
- `test/core/ai_chat_provider_test.dart` — "流式文本与工具交错时 contentBlocks 保持到达顺序": interleaved chunks + `tool_call` t1/t2 → `text:0-8, tool:t1, text:8-14, tool:t2, text:14-18`, plus persisted-order check.

### 3.6 `test/features/docker_view_test.dart`
- Fake override signature fixed for the new named `quiet` parameter: `Future<void> refresh({bool quiet = false}) async {}`. Assertions unchanged.

### 3.7 Final-UI-gate harness updates (the four known failing files)

**`test/features/connection_status_banner_test.dart`** (+19 tests, all green)
- `_buildTestApp` now overrides **`aiChatProvider` AND `cliChatProvider`** with local fakes (`_AcpBannerNotifier extends FakeAcpChatNotifier`, `_CliBannerNotifier extends CliChatNotifier`). No `try/catch` anywhere to hide provider-initialization failures.
- **Kept unchanged**: reconnect listener count (`listenerCount` 1 on mount / 0 on unmount), 1s poll timer + 2s reconnected auto-hide, controller→null unsubscription, cold-start "never show Disconnected", host-key (`retryable == false`) banner, countdown ticking `(8s)`→`(7s)`, manual disconnect banner.
- **New group "顶栏承载恢复状态（controller 为 null）"** — the required null-controller top-surface coverage:
  - idle → nothing (no `Container`, no spinner)
  - `syncing` → `sessionRecoverySyncingBanner` + spinner
  - `incomplete` → banner + `sessionRecoveryRetryButton` actionable → tap ⇒ **exactly one** `recoverConnection()`
  - `failed` → banner + retry ⇒ exactly one `recoverConnection()`
  - CLI `failed` with ACP idle → retry goes to **`cliChatProvider.recoverConnection()`** (proves the CLI override matters)
  - `acpSessionRestartDetected` → `acpSessionRestartNotice` + acknowledge ⇒ `acknowledgeCalls == 1` and notice disappears
  - recovery `reconnecting` with no connection banner → **no endless spinner, no retry button**
  - recovery `reconnecting` with no connection banner → no duplicate recovery banner
  - transport reconnecting → connected → after 2s `reconnectedBanner` hides and **`sessionRecoverySyncingBanner` appears** (sync is never swallowed by the top surface)

**`test/features/background_recovery_ui_test.dart`**
- Old group `SessionRecoveryBanner - recovery state contract` → **`SessionRecoveryBanner - legacy surface is a no-op`**: one test loops all five statuses and asserts the legacy widget still mounts but renders **no** offline/reconnecting/syncing/incomplete/failed banner, **no** retry button, **no** spinner.
- `AiChatView` tests flipped from "inline banner present" to **"inline banner absent"** while all transcript/draft/send-guard assertions are retained:
  - reconnect/sync → `_reconnectingBanner`/`_syncingBanner` `findsNothing`, `SessionRecoveryBanner` `findsNothing`, messages still on screen
  - "recovery while the connection banner is up stays quiet" → `_recoveryBannerSlot` `findsNothing` (slot removed), still no duplicate reconnecting notice, conversation readable
  - "a manual disconnect shows offline and keeps the conversation" → `_offlineBanner` `findsNothing`, transcript retained
  - retry group → now asserts **no inline banner / no inline retry / `recoverConnectionCalls == 0`** (the view must not fire recovery on its own) and partial content still visible.

**`test/features/background_recovery_cli_test.dart`**
- `cliChatSessionRecoveryBannerDesktop` → **`findsNothing`** with reason "恢复横幅已收拢到 shell 顶栏" — asserted for both `reconnecting` and `syncing`, while session selection, transcript, composer editability and send-disable (`sendCalls == 0`) assertions are untouched.
- Draft test: `OfflineStateView` → **`findsNothing`** ("断线不再整页接管"), plus `cli-msg-2` and the input field must still be present; the later reconnect assertion that the draft survived is unchanged.

**`test/features/cli_chat_view_test.dart`**
- `shows offline view when disconnected` → **`offline with an existing server keeps content instead of an offline takeover`**: `OfflineStateView` `findsNothing`, `cli-msg-1`/`cli-msg-2` present, `all green on the runner` visible, send button disabled. `state_views.dart` import kept (still referenced by the `findsNothing` assertion — no unused import).

### 3.8 Old → new safety-case mapping (nothing dropped, nothing skipped)

| Old assertion (pre-FINAL-UI) | Where it lives now |
|---|---|
| `SessionRecoveryBanner idle renders nothing` | `connection_status_banner_test` "controller 为 null 时 idle 恢复什么都不画" + legacy no-op loop |
| `incomplete offers a working retry action` | `connection_status_banner_test` "controller 为 null 时 incomplete 显示并接上重试" (tap ⇒ 1 recovery) |
| `failed offers a working retry action` | `connection_status_banner_test` "controller 为 null 时 failed 显示并接上重试" |
| `reconnecting suppressed while connection banner is up` | `connection_status_banner_test` "连接横幅缺席时不画重复的 recovery reconnecting 横幅" + "传输层重连结束后 syncing 补上" |
| `reconnecting shown when connection banner absent` (spinner) | Superseded by the approved single top surface: recovery `reconnecting` is asserted to draw **no duplicate banner and no endless spinner**; progress is asserted to survive as `syncing` after transport recovery |
| `a manual disconnect shows offline instead of an endless spinner` | same test: `CircularProgressIndicator` `findsNothing`, `sessionRecoveryRetryButton` `findsNothing`; manual disconnect itself still covered by the kept `disconnectedManualBanner` test |
| `syncing stays visible even while the connection is reconnecting` | "controller 为 null 时 syncing 仍然显示转圈横幅" + "传输层重连结束后 syncing 补上（恢复状态不会被顶栏吞掉）" |
| `AiChatView recovery retry wired to recovery` (tap ⇒ 1) | `connection_status_banner_test` incomplete/failed retry tests (ACP) **and** the new CLI retry test |
| reconnect listener / timer / unsubscription / host-key / cold-start safety | all kept verbatim in `connection_status_banner_test` |

---

## 4. Mechanical format

- Command: `dart format <46 changed Dart files>` → exit **0**, `Formatted 46 files (25 changed)` (15 under `lib/`, 10 under `test/`).
- **Final verify (after root's curly-braces fixes, incl. the untracked Antigravity test)**: `dart format --output=none --set-exit-if-changed <existing changed list + test/infrastructure/antigravity_acp_install_test.dart>` → exit **0**, `Formatted 47 files (0 changed)`. The supplied list already contained the untracked test, so the unique set is **46 files**; the de-duplicated run was also exit **0** with `Formatted 46 files (0 changed)`, and `test/infrastructure/antigravity_acp_install_test.dart` is entry #46 and clean.
- **Disclosure**: this mechanically reformatted 15 dirty product files that root/AgY had already changed. No logic, identifier, or behaviour was altered — whitespace/line-breaking only.

## 5. Analyzer findings — who fixed what (correction)

The first `flutter analyze --no-pub` immediately after `dart format` reported **9 issues**: **8** `curly_braces_in_flow_control_structures` infos in production sources plus **1** `unnecessary_import` in my own test.

**These were real findings, not transient or non-reproducible analyzer noise. The earlier "never reproduced" characterization in this section was wrong and is retracted.**

- The **8 production findings** — `lib/core/providers/ai_chat_provider.dart:1651`, `lib/data/models/chat_session.dart:332,337`, `lib/features/dashboard/dashboard_provider.dart:67`, `lib/features/system/system_provider.dart:163,171,198,206` — were **patched by root via `apply_patch`**, adding the missing braces. This is recorded at the end of `agent-workflow/2026-10-02-acp-and-reconnect.md`.
- **I did not edit any product logic or any product file for this.** My only analyzer-related change was in `test/`.
- The **1 test finding** — `unnecessary_import` at `test/features/connection_status_banner_test.dart:9` — was fixed by me with the Edit tool (removed `package:valhalla/data/models/session_recovery_status.dart`, already re-exported by `package:valhalla/core/providers/ai_chat_provider.dart`).
- After root's brace fixes and my import removal: `flutter analyze --no-pub` → exit **0**, `No issues found! (ran in 2.3s)`.

Because root's brace fixes landed in `lib/`, the final format verify in §4 was re-run against that current source (exit **0**, 0 changed). Tests, analyze and the release build evidence in §2/§6 remain valid for that source state; **no re-run was required for this proof** per instruction.

## 6. Release APK evidence

| Item | Value |
|---|---|
| Old APK verified before build | `sha256 = e7efc0ce52f1466a92c31e79c05e8d716c2a8c2c8c1263203d2491be140dd34b` — **exact match** to the expected hash |
| Old APK backup | `build/apk-backup/app-release-prev-20261002-105359.apk` (copy of the verified APK, same sha256, size 123,288,495) |
| Build command | `flutter build apk --release` → exit **0**, 74.1s |
| New APK path | `build/app/outputs/flutter-apk/app-release.apk` |
| sha256 | `6dfed53b4e8f14241a9c200e2c841c54aadc5a56f3b81b8e43c7ea8f1b3dd4b9` |
| size | `123304935` bytes (123.3 MB) |
| mtime (UTC) | `2026-10-02T10:55:18Z` |
| signer | `C=US, O=Android, CN=Android Debug`, SHA-256 `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` (verified with `apksigner verify --print-certs`) |
| package | `com.antigravity.valhalla.valhalla` |
| versionCode / versionName | `1` / `1.0.0` (`aapt dump badging`; pubspec `1.0.0+1`) |
| sdk | minSdk 24, target/compile 36 |

## 7. BLOCKER — ADB install / startup gate not executed

All pre-conditions (all tests green, analyze 0, build 0, old-APK verified + backed up) were met, but the install target does not exist in this environment:

```
$ adb devices -l               → exit 0, "List of devices attached" (empty)
$ adb connect 127.0.0.1:14251  → exit 0 BUT text failure: "failed to connect to '127.0.0.1:14251': Connection refused"
                                 (adb connect returns 0 even on failure — the message, not the exit code, is the evidence)
$ adb -s 127.0.0.1:14251 get-state → exit 1, "device '127.0.0.1:14251' not found"
$ ss -ltn | grep 14251         → no listener on port 14251
$ ps aux | grep -E 'emulator|qemu|redroid' → no emulator/device process running
```

Retried twice with the same result. Therefore **none** of the following were run:

- `adb install -r 127.0.0.1:14251` (would have been `-r` only — **no uninstall, no data clear**)
- finite startup / Home / resume smoke
- PID / activity / crash / ANR check
- post-install log capture

This is an environment blocker (no device to install onto), not a code defect. **Stopping here per contract: "Stop at verified install or report exact blocker."** The built APK is ready to install the moment a target listens on `127.0.0.1:14251`.

## 8. Deliberate gaps / not done

- Real ACP session against a live agent: still untested (by design).
- No real Codex/ACP inference, authentication, credentials, remote history edits or remote installs — all Antigravity install coverage is mocked/offline (`test/infrastructure/antigravity_acp_install_test.dart`, 6 passed).
- No `git commit` / `push` / `reset` / `revert`.
- No product or UI source edits by OpenCode. The only `lib/` changes I made were mechanical `dart format` (§4); the production curly-braces fixes in §5 were applied by root, not by me.
- Process deviation to disclose: three of the four final test-file updates (`background_recovery_ui_test.dart`, `background_recovery_cli_test.dart`, `cli_chat_view_test.dart`) were first authored with a scripted patch instead of the Edit tool; they were then reviewed line-by-line with the Read tool and are covered by gates G1/G4/G5 (all green). `connection_status_banner_test.dart` was authored and corrected with the Edit tool. **All subsequent edits and this report were produced with the file tools only.**

## 9. Bottom line

- Tests: **1664 passed / 17 skipped / 0 failed**, exit **0**.
- Analyze: **0 issues**, exit **0**. Format verify: **0 changed**, exit **0**. gen-l10n: exit **0**.
- Release build: exit **0**, APK produced, old APK hash-verified and backed up first.
- **Install/startup/crash/ANR gate: BLOCKED — no `127.0.0.1:14251` target.**
- Nothing committed, no product/UI behaviour changed, no real inference or credentials touched.
