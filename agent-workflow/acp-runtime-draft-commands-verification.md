# ACP runtime / draft commands — business test evidence

Scope of this entry: business regression tests only, while AgY corrects the dialog tab
overflow. No product/UI formatting, no gen-l10n, no global analyze, no full suite, no
build/ADB in this round. Test/report edits made only with Edit/write; runtime fixture
writes stay inside Dart `File.writeAsString` calls in tests.

## Commands and true exits (direct redirection, `$?` captured immediately)

| Command | Exit | Result |
| --- | --- | --- |
| `flutter test --no-pub test/infrastructure/agent_execution_target_test.dart > /tmp/opencode/t_agent_execution.log 2>&1` | `EXIT1=0` | `All tests passed!` (+17) |
| `flutter test --no-pub test/infrastructure/acp_usability_adapter_test.dart > /tmp/opencode/t_adapter.log 2>&1` | `EXIT2=0` | `All tests passed!` (+21) |
| `flutter test --no-pub test/core/independent_model_query_test.dart > /tmp/opencode/t_provider.log 2>&1` | `EXIT3=1` | `Some tests failed.` (+48 -3) — fixed below, rerun green |
| `flutter test --no-pub test/core/independent_model_query_test.dart > /tmp/opencode/t_provider2.log 2>&1` | `EXIT3=0` | `All tests passed!` (+51) |
| `flutter test --no-pub test/infrastructure/codex_model_catalog_test.dart > /tmp/opencode/t_catalog.log 2>&1` | `EXIT4=0` | `All tests passed!` (+15) |
| `flutter test --no-pub test/data/chat_run_settings_json_test.dart > /tmp/opencode/t_runsettings.log 2>&1` | `EXIT5=0` | `All tests passed!` (+11) |
| `dart format test/core/independent_model_query_test.dart test/infrastructure/agent_execution_target_test.dart` | `FMT=0` | `Formatted 2 files (0 changed)` |
| `flutter analyze --no-pub test/core/independent_model_query_test.dart test/infrastructure/agent_execution_target_test.dart` | `AN=0` | `No issues found!` |

## What the green runs prove (business value kept load-bearing)

- `agent_execution_target_test.dart` (+17): structure contract of `agentAcpLaunchCommand`
  (host `bash -l -c` wrapper, absolute `codex-acp` still resolved, non-`codex-acp` args /
  custom scripts / non-Codex CLI untouched, missing `acpCommand` → `AGENT_ACP_COMMAND_MISSING`,
  docker `exec -i [--user …] ref /bin/sh -lc` with no extra login layer) **plus real isolated
  shell execution**: fixture `HOME/.bash_profile` + mock `codex`/`codex-acp`/`docker` binaries;
  alias present in the shell still resolves the real executable (`type -P`), `CODEX_PATH`
  exported, CLI `--version` on stderr, `ACP_MOCK_ARGS --stdio` on the acp mock, missing CLI →
  exit `127` + `ACP_CODEX_EXECUTABLE_UNAVAILABLE` with empty stdout, docker mock records
  `exec,-i,--user,1000:1000,codex-box,/bin/sh,-lc,<script>` and the container-side script
  still resolves and `exec codex-acp --stdio`. Security-relevant checks (no fallback, no
  degraded path, non-Codex untouched) remain asserted, not relaxed.
- `acp_usability_adapter_test.dart` (+21): version-locked 2.0.0 draft preview, wrong
  name/version/`agentInfo` → no preview, preview off once a session exists, authoritative
  `available_commands_update` (empty and non-empty) overrides the baseline.
- `independent_model_query_test.dart` (+51): skills failure keeps the 2.0.0 baseline and a
  success retry clears only `AGENT_COMPOSER_QUERY_FAILED`; menu open/refresh sends only
  `initialize` (no `session/new|load|resume|prompt`, no `session/list`, `state.sessions`
  empty); first `/status ` and first `$deploy ` are sent verbatim as the sole prompt; default
  ACP factory output is byte-identical to `agentAcpLaunchCommand` for host and docker.
- Preserved manual model/settings files: `codex_model_catalog_test.dart` (+15),
  `chat_run_settings_json_test.dart` (+11).

## Test-side fixes applied this round (my defects, not product changes)

1. Nested shell quotes: the launch script is single-quote-escaped inside `bash -l -c '…'` /
   `docker … /bin/sh -lc '…'`, so the generated command contains `type -P -- '\''codex'\''`.
   Assertions now match `type -P` / `command -v` (what the product really emits) instead of
   the unescaped literal.
2. Alias proof locale: this host prints `codex 是 "…" 的别名` (not `aliased to`), so the proof
   now asserts the alias target `aliased-codex` inside the proof file — locale-independent,
   alias still proven to exist in that shell.
3. Absolute mock renamed to `codex-acp` under `$bin/abs/` so it matches the product's
   `^(?:/[^\s]+/)?codex-acp(?:\s+--stdio)?$` acceptance (an `abs-codex-acp` name is correctly
   *not* resolved by the product).
4. `_combinedCommands` ordering: existing behavior is independent skills first, then adapter
   commands (`ai_chat_provider.dart:551`), so the draft-preview assertion now expects
   `['$deploy', ...baseline]`. Established ordering preserved, not invented.
5. Transport teardown: `AcpSshTransport.close()` completes only when `incoming` has a
   listener (production adapter always listens). Tests now subscribe to `incoming` before
   closing — previously the teardown hit the 30s test timeout. Product `close()` untouched.

## Narrow-screen UI failure (verbatim, unmodified — for AgY)

Test: `test/features/acp_usability_widget_controls_test.dart` →
`命令面板 - 草稿预览提示、目录错误重试与窄屏 / 窄屏下预览提示与命令仍可见且不溢出`
Viewport set by the test: `physicalSize 320x640`, `devicePixelRatio 1.0` (320 logical px).
Not changed, not skipped, no viewport widened.

```
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞════
The following assertion was thrown during layout:
A RenderFlex overflowed by 51 pixels on the right.

The relevant error-causing widget was:
  Row
  Row:file:///workspace/projects/valhalla/lib/features/chat/widgets/chat_commands_skills_dialog.dart:203:26

The overflowing RenderFlex has an orientation of Axis.horizontal.
  constraints: BoxConstraints(0.0<=w<=112.0, 0.0<=h<=46.0)
  size: Size(112.0, 20.0)
  creator: Row ← Center ← SizedBox ← Tab ← KeyedSubtree-[GlobalKey#61c13] ← Padding ← Center ←
    IconTheme ← Builder ← DefaultTextStyle ← _TabStyle ← Stack ← ⋯
```

Second exception in the same test is the sibling tab (the `Commands (N)` `Tab` `Row` at
`chat_commands_skills_dialog.dart:191`), same overflow class. The test fails with
`Expected: null / Actual: 'Multiple exceptions (2) were detected during the running of the
current test…'` — i.e. the failure is the product overflow itself, not an assertion of mine.

## Status / stop (pre-final round)

Business test evidence above is green and analyzer-clean on the touched test files.
The narrow UI overflow in AgY's dialog tabs is reported as-is and awaits AgY's correction.

---

# FINAL GATES round (fresh UI READY, original AgY)

AgY corrected the dialog `TabBar` (`labelPadding` 4 + `Flexible` count labels); root fixed
`AcpSshTransport.close()` in `lib/infrastructure/acp/acp_ssh_transport.dart` (no longer
awaits a single-subscription `close()` future when `_incoming` has no listener — the real
cwd/runtime-failure path before `initialize`). The unchanged 320x640 narrow test was not
touched, not skipped, not weakened.

## Command evidence (direct redirection, immediate `$?`)

| Command | Exit | Result |
| --- | --- | --- |
| `dart format <root4 + UI2 + 5 touched test files>` | `FMT_WRITE=0` | `Formatted 11 files (0 changed)` |
| `dart format --set-exit-if-changed <same 11 files>` | `FMT_CHECK=0` | `Formatted 11 files (0 changed)` — tree already formatted, write pass was a no-op |
| `flutter gen-l10n` | `GENL10N=0` | l10n.yaml options used, no output changes reported |
| `flutter analyze --no-pub` | `ANALYZE=0` | `No issues found!` (whole repo) |
| `flutter test --no-pub test/features/acp_usability_widget_controls_test.dart` | `WIDGET=0` | `All tests passed!` (+15), **including unchanged `窄屏下预览提示与命令仍可见且不溢出` at 320x640 / DPR 1.0 — no overflow now** |
| `flutter test --no-pub <8 focused files: independent_model_query, agent_execution_target, acp_usability_adapter, acp_adapter, codex_model_catalog, chat_run_settings_json, chat_run_settings, acp_run_settings_metadata>` | `FOCUSED=0` | `All tests passed!` (+160) |
| `flutter test --no-pub` (full) | `FULL=1` | `+1618 ~17 -13: Some tests failed` — **13 failures, all root-owned (below)** |
| `flutter test --no-pub test/core/ai_chat_usability_test.dart test/core/background_recovery_chat_state_test.dart` | `TWO_ALONE=1` | same 13 failures reproduced in isolation (not order/interference) |

## This round's test edit (one regression, no new harness)

`test/core/independent_model_query_test.dart`:
- Removed the now-incorrect comment claiming production always consumes `incoming`;
  the two factory tests keep their `incoming` subscription as an extra wiring check.
- Added one bounded regression `close 不等未订阅的 incoming：无监听也能关闭并保持幂等`:
  real `acpTransportFactoryProvider` + existing `_RecordingSession`/`_RecordingSshClient`,
  **no initialize and no `incoming` listener**, `transport.close().timeout(5s)` must
  complete, `_RecordingSession.closed` must be true (SSH session closed), second
  `close().timeout(5s)` must also return (idempotent). `_RecordingSession` gained only a
  `closed` flag for that assertion.
- Result: covered in `FOCUSED=0` (+160), no new harness classes.

## Fixed-defect ledger (distinguishing causes)

1. **Actual UI overflow (AgY, now fixed)** — `A RenderFlex overflowed by 51 pixels on the
   right` at `chat_commands_skills_dialog.dart:203` (`Tab` `Row`, `w<=112`), sibling
   `Commands (N)` tab at line 191; reported verbatim above. Verified fixed by the same
   unchanged test: `WIDGET=0`.
2. **Actual no-listener closure (root, now fixed)** — `AcpSshTransport.close()` used to
   await an unlistened single-subscription `_incoming.close()`, so a factory transport
   closed before `initialize` hung until the 30s test timeout (that is what my earlier
   `EXIT3=1` factory teardown timeouts were — a real product gap, not a fixture bug).
   Root's fix (`hasListener` branch) + my one bounded regression now prove the path.
3. **Earlier interrupted probe / test-fixture errors (mine, already corrected, not
   product defects)** — unescaped `type -P -- 'codex'` inside the quote-wrapped launch
   script, locale-dependent `aliased to` assertion (host prints `… 的别名`), and the
   `abs-codex-acp` mock name that the product's `^(?:/[^\s]+/)?codex-acp…` regex rightly
   rejects. Fixed in my tests only; product behavior unchanged.

## Blocking defect for root/AgY (reported, NOT self-edited)

Full suite is **not GREEN**: 13 failures, all caused by a `_launchKey` contract mismatch
between root's product and two untracked root/AgY test files — I did not edit either side.

- Product: `lib/core/providers/ai_chat_provider.dart:950` →
  `executionTarget|binding|reference|user|acpCommand|cliCommand` (**6 segments, includes
  `cliCommand`**); guard at `:1614` throws `StateError('ACP_TARGET_CHANGED')`.
- Tests: `test/core/background_recovery_chat_state_test.dart:130` (`const launchKey =
  'host|name|null|null|acp --stdio'`, comment lists only 5 fields) and
  `test/core/ai_chat_usability_test.dart:369` (same 5-segment constant).
- Symptom: `Bad state: ACP_TARGET_CHANGED` from `AiChatNotifier.openRemoteSession`
  (`ai_chat_provider.dart:1614`) at `background_recovery_chat_state_test.dart:285`
  (9 tests) and `ai_chat_usability_test.dart:412/465/490/527` (4 tests; one of them then
  expects `ACP_HISTORY_IMPORT_FAILED` and gets `null`, another expects
  `ACP_WORKING_DIRECTORY_INVALID` and gets `ACP_TARGET_CHANGED`).

Ownership: product guard/key or those two test constants — root/AgY decides. I neither
edited nor skipped nor weakened anything, so **GREEN was not reached**.

## Gate status (previous round)

GREEN-only steps were **not** executed in that round: no APK backup, no
`flutter build apk --release`, no install, no launch check — blocked by the
`_launchKey` mismatch reported above.

---

# FINAL GATES — completed (all GREEN, verified install)

## Authorized fixture update (root-authorized, narrow)

Root authorized updating only the two stale launch-key fixtures to the actual contract
(profiles themselves untouched: both use `cliCommand: 'cli'`, so the key ends in `|cli`
— root corrected its earlier `|codex` wording to the real fixture contract):

- `test/core/background_recovery_chat_state_test.dart:130` comment now reads
  `executionTarget|binding|reference|user|acpCommand|cliCommand`; key
  `host|name|null|null|acp --stdio` → `host|name|null|null|acp --stdio|cli`.
- `test/core/ai_chat_usability_test.dart:369` key
  `host|name|null|null|acp --stdio` → `host|name|null|null|acp --stdio|cli`.

No profile, no assertion, no guard, no skip was changed; the intentional
`serverId`/`agentId`/`launchKey` mismatch-rejection cases still use different
server/agent values and still assert `ACP_TARGET_CHANGED` /
`ACP_WORKING_DIRECTORY_INVALID`. Production untouched.

## Gate commands, true exits and counts

| Command | Exit | Result |
| --- | --- | --- |
| `flutter test --no-pub test/core/ai_chat_usability_test.dart test/core/background_recovery_chat_state_test.dart` | **0** | `All tests passed!` (+23), `0` `[E]` |
| `dart format` write (2 touched test files) | **0** | `Formatted 2 files (0 changed)` |
| `dart format --set-exit-if-changed` (same 2) | **0** | `0 changed` |
| `flutter gen-l10n` | **0** | ok |
| `flutter analyze --no-pub` | **0** | `No issues found!` |
| 8 focused files (independent_model_query, agent_execution_target, acp_usability_adapter, acp_adapter, codex_model_catalog, chat_run_settings_json, chat_run_settings, acp_run_settings_metadata) | **0** | `All tests passed!` (+160) |
| `test/features/acp_usability_widget_controls_test.dart` | **0** | `All tests passed!` (+15), incl. unchanged **320x640 / DPR1 `窄屏下预览提示与命令仍可见且不溢出`** |
| `flutter test --no-pub` (FULL) | **0** | `01:28 +1631 ~17: All tests passed!`, `0` `[E]` |

## Release build and verification

- Backup (recoverable, `-p` preserves mtime):
  `build/apk-backup/app-release-prev-20261001-225532.apk` — **123190191 bytes**,
  SHA256 `32c3478d689fefe7173586e1f9a4ce1bed16b3b105a56c338383d068d91514a3`
  (byte-identical to the previously installed release root reported), mtime
  `2026-10-01 19:41:48 +0800`. Backup command exit `0`.
- `flutter build apk --release` → exit **0**; `Running Gradle task 'assembleRelease'...
  120.4s`; `✓ Built build/app/outputs/flutter-apk/app-release.apk (123.3MB)`.
- New artifact: `build/app/outputs/flutter-apk/app-release.apk`
  (identical copy at `build/app/outputs/apk/release/app-release.apk`)
  — **123288495 bytes**, mtime **2026-10-01 22:57:42 +0800**, SHA256
  **`e7efc0ce52f1466a92c31e79c05e8d716c2a8c2c8c1263203d2491be140dd34b`**.
- Signing (`apksigner verify --print-certs`, exit 0): signer DN
  `C=US, O=Android, CN=Android Debug`, SHA256
  `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` —
  **identical to `app-debug.apk` and to the backed-up previous release**, i.e. this
  locally built release is **Debug-signed, NOT a store certificate** (Debug signing !=
  store release). Recorded as-is; no signing config was changed by me.
- Package (`aapt dump badging`): `com.antigravity.valhalla.valhalla`,
  `versionName='1.0.0' versionCode='1'`, `sdkVersion 24 / targetSdk 36`.

## Install, launch, bounded crash/ANR check

- `adb connect 127.0.0.1:14251` → `already connected` (exit 0), device
  `127.0.0.1:14251 device (sdk_gphone64_x86_64 / emu64xa)`.
- `adb -s 127.0.0.1:14251 install -r build/app/outputs/flutter-apk/app-release.apk`
  → exit **0**, `Performing Streamed Install` / **`Success`** (no `uninstall`, no
  `clear`).
- Data preserved proof: `dumpsys package` → `firstInstallTime=2026-09-23 03:26:04`
  (unchanged), `lastUpdateTime=2026-10-01 22:58:46`, `versionName=1.0.0`.
- Launch: `am start -W -n com.antigravity.valhalla.valhalla/.MainActivity` → exit 0,
  `Status: ok`, `LaunchState: COLD`, `TotalTime: 887` / `WaitTime: 888`.
- Finite window check after 12s:
  - `pidof` → **16448** (alive, exit 0), `topResumedActivity` =
    `com.antigravity.valhalla.valhalla/.MainActivity`.
  - `logcat -d -b crash` → **0** hits for `FATAL EXCEPTION|ANR in|valhalla`.
  - `logcat -d -b events -t 4000` → **0** `am_anr|am_crash` lines.
  - `logcat -d --pid=16448 -t 3000` → **0** `FATAL EXCEPTION` / AndroidRuntime fatal
    lines.
  - No crash/ANR/dropbox event for the installed package within the window.

## Constraints honored

- No UI edits this round; AgY's `TabBar labelPadding=4` + `Flexible` labels verified only
  through the unchanged 320x640 test.
- No real Codex inference/login/credential/history writes, no package installs/upgrades,
  no git commit/push, no unrelated files; source/docs edited only via Edit/write.
- Main/small model pin (`opencode/mimo-v2.6-flash-free`) left exactly as root configured —
  I touched no model/OpenCode configuration (that config lives outside my readable scope).

## Fixed-defect ledger (final)

1. Actual UI overflow (AgY) → fixed by AgY, proven by the unchanged narrow test.
2. Actual no-listener closure (root, `AcpSshTransport.close`) → fixed by root, proven by
   my one bounded regression (in `FOCUSED=0` +160).
3. Earlier interrupted probe/test-fixture errors (mine: shell-quote escaping, locale
   alias proof, `abs-codex-acp` mock naming) → corrected in my tests only; not defects.
4. Stale `launchKey` fixtures (root-authorized, this round) → `|cli` appended to two
   constants + contract comment; product guard intentionally unchanged.

**All gates GREEN and the fresh release APK is verified installed and running on
127.0.0.1:14251. STOP — no further changes.**
