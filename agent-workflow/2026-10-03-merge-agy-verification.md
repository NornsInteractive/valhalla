# Verification checkpoint — remote merge + AgY auth/install (2026-10-03)

Task: `agent-workflow/2026-10-03-merge-mosh-agy-auth.md`.
Scope: logic-level checks only, while the AgY UI task is still active.
**Full test suite, `flutter build`, and ADB were deliberately NOT run** (waiting on
UI READY). No git mutation, no product/UI edit, no credential or real remote access.

---

## 1. Merge review (terminal / lifecycle state)

HEAD fast-forwarded `7a4c203` → `de37ed6`; prior dirty work restored from stash
`valhalla-before-origin-update-20261003`.

| Check | Result |
|---|---|
| Conflict markers in `test/` and `lib/` | none |
| `git diff` on `test/core/background_recovery_lifecycle_test.dart` | only the intended 2026-10-02 changes (`_FakeScheduler`/`_FakeTimer` seam, exact `pendingCount`/`attempts`, `detached` pause tests) |
| `git diff` on `test/core/connection_lifecycle_test.dart` | only the intended 2026-10-02 changes (+126 lines) |
| Remote-only coverage retained | mosh locale negotiation, zombie SSH cleanup, terminal font settings, neofetch sheet — all present and passing |
| Local-only coverage retained | pause/probe/credential-race reconnect semantics — all present and passing |

No merge damage found; no lifecycle test was reverted or weakened.

---

## 2. First focused run — 18 failures, all in remote-owned harnesses

Command (28 paths, `set -o pipefail`, real `$?`):

```
flutter test --no-pub <mosh + ssh/zombie + rebind + tmux + font/neofetch/canvas
                      + lifecycle/reconnect + agent env/installer>
FOCUSED_EXIT=1        +364 -18: Some tests failed
```

| Group | Count | Root cause |
|---|---|---|
| `test/infrastructure/mosh/mosh_e2e_manual_test.dart` | 1 | file failed to **load**: `Null check operator used on a null value` at line 66 — `Platform.environment['USERPROFILE']!` is evaluated while registering the test, *before* `skip` is consulted. No `USERPROFILE` on POSIX. |
| `test/features/terminal_mosh_entry_test.dart` | 6 | `ProviderException: UnimplementedError: LocalStorageService must be initialized before runApp` while building `SharedTerminalCanvas` |
| `test/features/terminal_tmux_notice_test.dart` | 11 | same as above |

Chain: `SharedTerminalCanvas` watches `terminalSettingsProvider`
(`lib/features/terminal/widgets/shared_terminal_canvas.dart:140`) →
`TerminalSettingsNotifier.build` watches `localStorageServiceProvider`
(`lib/core/providers/terminal_settings_provider.dart:34`) → un-overridden
`localStorageServiceProvider` throws (`lib/core/providers/storage_providers.dart:17`).

The remote added the font-size feature and updated `shared_terminal_canvas_test`,
but did not give these two sibling view harnesses the required provider override.

---

## 3. Fixes applied (test files only, Edit tool, no shell writers)

1. `test/infrastructure/mosh/mosh_e2e_manual_test.dart:63-71` — replaced the
   platform-fragile `USERPROFILE!` with `USERPROFILE ?? HOME ?? ''` and
   `Platform.pathSeparator`. POSIX behaviour unchanged (file still skips unless
   `VALHALLA_MOSH_E2E=1`); Windows path shape preserved exactly.
2. `test/features/terminal_mosh_entry_test.dart:113,127` — added a
   `_FixedTerminalSettingsNotifier` and `terminalSettingsProvider.overrideWith(...)`.
3. `test/features/terminal_tmux_notice_test.dart:68,95` — same override.

Per the standing harness rule: **required providers are overridden in the test
harness; no UI try/catch was added to swallow init failures.** Nothing under
`lib/` was touched for these fixes.

---

## 4. Auth regression tests added (task lines 58–61)

Four mocked cases added to `test/core/ai_chat_provider_test.dart`, group
`ACP auth challenge`, using the existing `FakeAcpPair` / `authContainer` harness —
no real inference, no remote:

| # | Test | Asserts |
|---|---|---|
| 1 | `revoked auth 失去确认：authRequired 之后的 complete 事件不能收起卡片` | `_emitAuthRequired()` resets `authenticationConfirmed`, so the `ACPCompleteEvent` emitted right after it in the same catch block does **not** clear the card or `ACP_AUTH_REQUIRED`. |
| 2 | `应用外登录后重发同一条消息：卡片与报错都清掉，且不重复写入这一轮` | external login + retry clears `authChallenge` and `lastErrorCode`, and the turn is **not** written twice (still exactly one user `hi`, still 2 bubbles). |
| 3 | `只有 initialize 成功时不能算已认证，卡片必须保留` | `initialize` succeeding while `session/new` fails `-32000` keeps the card; only an actually established session clears it. |
| 4 | `卡片在屏时，与认证无关的远端报错不得把它清掉` | a non-auth remote error (`-32603`) updates the error but leaves `authChallenge` standing. |

All four pass. Existing `authenticationConfirmed` still has **zero** direct
references in `test/` — these tests pin its contract through observable provider
state instead, which is the surface the UI actually consumes.

---

## 5. Pinned installer — reviewed, not bumped

`test/infrastructure/antigravity_acp_install_test.dart` pins **1.2.1**:

- line 79 expected download URL: `.../agy-acp-server-1.2.1-<platform>.zip`
- lines 83 / 139 expected install path: `.../antigravity-acp/1.2.1/...`
- fake `curl` refuses anything that is not an `https:` URL (line 43-47), so a
  stray registry URL cannot be fetched

These match `lib/data/models/builtin_agent_preset.dart:126,131,137,139` (comment
at `:70` records the 2026-10-02 check against ACP Registry distribution metadata).
Registry now also advertises **1.3.0**; **not updated** — no verified distribution
layout and no backwards-safe custom-config preservation proof yet.

---

## 6. Final focused + auth run

```
flutter test --no-pub <28 focused paths> + acp_adapter_test + ai_chat_provider_test
                                          + auth_challenge_ui_test
FINAL_EXIT=0        00:17 +447 ~1: All tests passed!
```

- **447 passed, 1 skipped, 0 failed, exit 0**
- The single skip is `mosh_e2e_manual_test` behind `VALHALLA_MOSH_E2E=1`
  — **no real remote mosh e2e was executed or overridden**.

Focused groups all green: mosh mocked/bootstrap, SSH zombie + transport + host-key
verifier, terminal rebind resilience, terminal tmux, font-size / shared canvas /
tmux notice / neofetch UI tests, background-recovery lifecycle + probe + reconnect +
credential race + keep-alive + reconnect backoff + server connection, agent
environment + execution target + mocked installer + agent management + command
validator + chat eligibility + preset + repository, and the ACP adapter /
auth-challenge UI suites.

---

## 7. Narrow gates

| Gate | Command | Exit | Output |
|---|---|---|---|
| format | `dart format --output=none --set-exit-if-changed` over **all 23** dirty `test/` files | **0** | `Formatted 23 files (0 changed)` |
| l10n | `flutter gen-l10n` | **0** | idempotent, no `lib/l10n/` change |
| analyze | `flutter analyze --no-pub` | **0** | `No issues found! (ran in 7.7s)` |

Note: a mid-run `analyze` briefly reported 2 × `invalid_null_aware_operator` at
`lib/core/providers/ai_chat_provider.dart:1018,1019` (`challenge?.` after
`challenge != null`). Those lines are root-owned product code and were **not**
edited here; the final analyze is clean.

---

## 8. Not run — blocked or deliberately deferred

| Item | Status |
|---|---|
| Full test suite (`flutter test`) | **not run** — task says no full run until UI READY |
| `flutter build apk --release` + APK metadata/cert/hash/time | **not run** — same gate |
| `flutter test` popup 320/360dp + large font + long script overflow/reachability | **not written** — explicitly "when UI is ready" |
| "unknown AgY is not fake unauthenticated" regression test | **not written** — depends on root's business-layer change landing |
| ADB install / startup / crash / ANR | **blocked**: no listener on `127.0.0.1:14251`, `adb devices` empty. **Not retried, no emulator created** (per instruction). |

---

## 9. Stop point

Logic checkpoint complete: merge reviewed, focused + auth suites green (447/0),
format/l10n/analyze green, installer pin held at 1.2.1.
Stopping here and awaiting the AgY UI gate (`agent-workflow/2026-10-03-agy-ui-status.md`)
before the final format/l10n/analyze/full-suite run, release build, and ADB install.

---
---

# FINAL UI GATE — run record (2026-10-03, second pass)

Task section "Final UI gate opened / Compile gate reopened / Installer overflow gate
blocked / Installer gate reopened". All commands run with `set -o pipefail` and a real
`$?`. No product/UI code was edited by OpenCode; no git mutation; no shell file writers.

## 10. Regression tests added for this gate (10 cases, Edit tool only)

| File | Added | Covers task line |
|---|---|---|
| `test/data/chat_message_contract_test.dart` | `status 枚举新旧值 JSON 往返：旧 interrupted 原样保留` — loops **every** `ChatTurnStatus` value, asserts legacy `interrupted` survives verbatim and missing/unknown `status` falls back to `completed` | "Old status round-trip", "new awaitingAuthentication JSON round-trip" |
| `test/core/ai_chat_provider_test.dart` | `-32000 只标 awaitingAuthentication，绝不标成 interrupted` | "-32000→awaitingAuthentication not interrupted" |
| `test/core/ai_chat_provider_test.dart` | `显式重试复用占位并最终 completed：恰好一条用户 + 一条助手` | "Auth retry reuses the prior placeholder… final completed status… exactly one user message and assistant placeholder, no automatic resend" |
| `test/features/auth_challenge_ui_test.dart` | pending-turn card sits **inside** `assistant_msg_m2`'s turn with badge + `Awaiting ACP Authentication`, and `Interrupted` is absent | single challenge near pending assistant |
| `test/features/auth_challenge_ui_test.dart` | completed-turn card falls back to the **bottom** card, in-turn badge absent | auth-card placement |
| `test/features/auth_challenge_ui_test.dart` | draft (`sessions: const []`) renders exactly one card, no badge | auth-card placement |
| `test/features/agent_management_test.dart` | unknown built-in AgY shows `Auth: Unknown`, never `Auth: Logged In` / `Not logged in. Log in now?`, `agent_bottom_login_builtin-agy` still present | "unknown AgY is not fake unauthenticated" |
| `test/features/agent_management_test.dart` | **320dp + `TextScaler.linear(2.0)`** installer dialog: `SelectableText.data == command` (multi-KB, unbroken), clipboard really receives the full command, `Cancel` and `Execute` rects both inside the screen, Cancel→false then Execute→true | "Add popup tests narrow screens/large text/long script" |

`FakeAcpPair` is reused across sends, so the knobs are set on **both**
`configurePair` and the live `pair` (otherwise `host is up` never arrives).

Focused run of the seven task-relevant files:

```
flutter test --no-pub test/core/ai_chat_provider_test.dart
                 + test/data/chat_message_contract_test.dart
                 + test/features/auth_challenge_ui_test.dart
                 + test/features/agent_management_test.dart
                 + test/features/terminal_mosh_entry_test.dart
                 + test/features/terminal_tmux_notice_test.dart
                 + test/infrastructure/antigravity_acp_install_test.dart
FOCUS_EXIT=0     00:05 +120: All tests passed!
```

## 11. Installer overflow — found, reported, fixed by AgY (not by me)

First 320dp/2x run failed. Full framework report (`EXCEPTION CAUGHT BY RENDERING
LIBRARY`):

```
A RenderFlex overflowed by 198 pixels on the right.
The relevant error-causing widget was:
  Row
  Row:file:///…/lib/features/agents/agent_command_confirm_dialog.dart:45:19
constraints: BoxConstraints(0.0<=w<=224.0, 0.0<=h<=Infinity)
```

Cause: the target-server row used an **unconstrained** `Text('${targetServerLabel}: ')`
(`Target Server: `, `app_en.arb:270`) beside an `Expanded` value; at 2× the label alone
measures ~422px against 224px of dialog width. Reported through the task file
("Installer overflow gate blocked"); AgY replaced the `Row` with a wrapping `Column`
and added `maxHeight`. Verified after the fix:

```
flutter test --no-pub test/features/agent_management_test.dart
G9_EXIT=0        00:03 +26: All tests passed!
```

The test keeps the strict assertions — clipboard content, action reachability **and**
zero captured layout exceptions (`expect(layoutErrs, isEmpty)`); no exception was
suppressed to get it green.

## 12. Final gates — real exit codes

| Gate | Command | Exit | Output |
|---|---|---|---|
| format (1st) | `dart format` over all **51** dirty `*.dart` | **0** | `Formatted 51 files (5 changed)` |
| format (2nd, idempotency) | same command re-run | **0** | `Formatted 51 files (0 changed)` |
| l10n | `flutter gen-l10n` | **0** | no `lib/l10n/` change |
| analyze | `flutter analyze --no-pub` | **0** | `No issues found! (ran in 5.0s)` |
| **full suite** | `flutter test --no-pub` | **1** | `00:58 +1689 ~18 -24: Some tests failed.` |

**Full suite: 1689 passed, 18 skipped, 24 failed (1731 total), exit 1.**

## 13. The 24 full-suite failures — exact blocker

> **Superseded by §16–§21.** Root explicitly authorized test-only
> `terminalSettingsProvider` fixture fixes for exactly these four harnesses
> ("Latest handoff section Full-suite harness maintenance authorized"). Kept below
> verbatim as the diagnosis that led to that fix.

| Failing file | Count |
|---|---|
| `test/features/interactive_login_dialog_test.dart` | 16 |
| `test/features/interactive_login_test.dart` | 4 |
| `test/features/cli_chat_view_test.dart` | 3 |
| `test/features/cli_chat_settings_button_test.dart` | 1 |

Primary cause (20 of 24), identical to the checkpoint-phase harness gap:

```
ProviderException: Tried to use a provider that is in error state.
A provider threw: UnimplementedError: LocalStorageService must be initialized
before runApp        (lib/core/providers/storage_providers.dart:15-19)
while building SharedTerminalCanvas
```

Chain: `SharedTerminalCanvas` → `ref.watch(terminalSettingsProvider).fontSize`
(`lib/features/terminal/widgets/shared_terminal_canvas.dart:140`) →
`TerminalSettingsNotifier.build` watches `localStorageServiceProvider`
(`lib/core/providers/terminal_settings_provider.dart:34`) → un-overridden provider
throws. The remaining 4 are downstream `Expected: exactly one matching candidate /
Found 0 widgets with text "TAB"` (`cli_chat_settings_button_test.dart:194`), i.e. the
canvas never rendered.

Reproduced **in isolation** (so this is not a cross-file ordering artifact):

```
flutter test --no-pub <the four files above>
ISOLATED_EXIT=1    00:07 +41 -24: Some tests failed.
```

Attribution:

- None of the four failing files were edited in this session. My edits are test-only
  in `ai_chat_provider_test`, `chat_message_contract_test`, `auth_challenge_ui_test`,
  `agent_management_test`, plus whitespace-only `dart format` (verified idempotent).
- Three of the four failing files are **unmodified in the working tree** (`git status`);
  only `cli_chat_view_test.dart` is dirty, and it still fails 3 cases.
- None of `shared_terminal_canvas.dart`, `terminal_settings_provider.dart`,
  `storage_providers.dart`, `lib/features/agents/interactive_login_dialog.dart` is
  modified either — so the breakage comes from the wider concurrent working-tree merge,
  not from this task's test additions.
- Baseline: the 2026-10-02 report §G5 recorded the whole `test/` tree at
  `+1664 ~17`, **exit 0**. Today's run is `+1689 ~18 -24`, **exit 1**.

Fix direction (not applied here — these are root-owned test harnesses / product
surface, and the standing rule forbids OpenCode editing product or weakening others'
tests): add `terminalSettingsProvider.overrideWith(...)` (or
`localStorageServiceProvider.overrideWithValue(...)`) to the four harnesses, exactly
as was already done for `terminal_mosh_entry_test.dart:113,127` and
`terminal_tmux_notice_test.dart:68,95`.

## 14. Build / ADB — deliberately not run

> **Superseded by §19–§20.** After the authorized harness fix the suite went green
> and the build + install were carried out. Kept for the record of this gate state.

Task line 105: *"All green → build exact metadata/cert/hash/time → adb install -r
only on available existing device"*. The full suite is **not** green (24 failures), so:

| Item | Status |
|---|---|
| APK backup + `flutter build apk --release` + sha256/cert/metadata | **not run** — precondition "all green" not met |
| `adb install -r` / startup / crash / ANR | **not run** — same gate; independently still blocked (no listener on `127.0.0.1:14251`, `adb devices` empty; no reconnect spam, no emulator created) |
| Uninstall / clear / new emulator / real ACP inference / mosh e2e | **not attempted** (forbidden) |
| Pinned installer | still **1.2.1**, not bumped to registry 1.3.0 |

## 15. Stop point

Final gates: format **0**, gen-l10n **0**, analyze **0**, focused 7-file suite **0
(+120)**, full suite **1 (1689 pass / 18 skip / 24 fail)**. The six-plus popup,
auth-status and status-round-trip regressions demanded by this gate are written and
green; the installer overflow was caught by them and fixed by AgY. Blocking on the 24
`SharedTerminalCanvas`/`localStorageServiceProvider` failures in four root-owned test
harnesses before any release build or ADB step.
→ Resumed after root authorized the harness fix; see §16–§21.

---
---

# HARNESS FIX + FINAL BUILD/ADB — run record (2026-10-03, third pass)

Authority: root handoff, *"Yes: apply test-only `terminalSettingsProvider` fixture
fixes to exactly the four failing test harnesses. Latest handoff section Full-suite
harness maintenance authorized explicitly permits it."*

## 16. Test-only harness maintenance — exactly four files

Reused `test/support/fixed_terminal_settings.dart` (`FixedTerminalSettingsNotifier`
+ `fixedTerminalSettingsOverrides()`), which pins `terminalSettingsProvider` and never
touches storage. Edits, **Edit tool only, no shell writers**:

| File | Edit |
|---|---|
| `test/features/cli_chat_settings_button_test.dart` | `+ import '../support/fixed_terminal_settings.dart';` · `+ ...fixedTerminalSettingsOverrides(),` in `_pumpCliChat`'s `ProviderScope.overrides` |
| `test/features/cli_chat_view_test.dart` | same import · `+ ...fixedTerminalSettingsOverrides(),` in the shared pump helper's overrides |
| `test/features/interactive_login_dialog_test.dart` | same import · `+ overrides: fixedTerminalSettingsOverrides(),` on `host()`'s `ProviderScope` |
| `test/features/interactive_login_test.dart` | same import · `+ ...fixedTerminalSettingsOverrides(),` in `createTestApp`'s overrides list |

Constraints held:

- **No assertion added, changed or removed**; **no test skipped**; **no exception
  caught or swallowed**; **zero `lib/` edits**.
- **Real storage injection preserved where persistence is subject**:
  `interactive_login_test.dart:424`
  `localStorageServiceProvider.overrideWithValue(local)` (real
  `LocalStorageService.init()` after `SharedPreferences.setMockInitialValues({})`)
  is untouched. The fixture overrides a *different* provider
  (`terminalSettingsProvider`), so that injected `LocalStorageService` still serves
  every other reader; only the terminal-font/TMUX source is pinned. None of the four
  files asserts `fontSize`, `useTmux` or terminal-settings persistence (grep: 0 hits).
- No other file was edited for this fix.

## 17. Four affected files first

```
flutter test --no-pub test/features/cli_chat_settings_button_test.dart
                 + test/features/cli_chat_view_test.dart
                 + test/features/interactive_login_dialog_test.dart
                 + test/features/interactive_login_test.dart
FOUR_EXIT=0       00:06 +65: All tests passed!
```

All 24 previously failing cases now pass.

## 18. Fresh gates — true exit codes

| Gate | Command | Exit | Output |
|---|---|---|---|
| format | `dart format` over all **57** dirty `*.dart` | **0** | `Formatted 57 files (0 changed)` |
| format (re-run) | same | **0** | `Formatted 57 files (0 changed)` |
| l10n | `flutter gen-l10n` | **0** | no `lib/l10n/` change |
| analyze | `flutter analyze --no-pub` | **0** | `No issues found! (ran in 2.2s)` |
| **full suite** | `flutter test --no-pub` | **0** | `00:55 +1713 ~18: All tests passed!` |

**1713 passed, 18 skipped, 0 failed (1731 total), exit 0.** The 18 skips are the
existing deliberate skips (incl. `mosh_e2e_manual_test` behind `VALHALLA_MOSH_E2E=1`);
**no real remote mosh e2e, inference or credential path was executed.**

## 19. Release APK backup + build + metadata

Backup (`cp` exit 0, before building):

| | |
|---|---|
| backup path | `build/apk-backup/app-release-prev-20261003-20261003T032851Z.apk` |
| bytes | `123304935` |
| sha256 | `6dfed53b4e8f14241a9c200e2c841c54aadc5a56f3b81b8e43c7ea8f1b3dd4b9` |
| matches pre-build `app-release.apk`? | **yes** (identical digest) |
| pre-build APK mtime UTC | `2026-10-02T10:55:18Z` |

Build: `flutter build apk --release` → **exit 0**, `✓ Built build/app/outputs/flutter-apk/app-release.apk (123.4MB)` (Gradle `assembleRelease` 68.9s).

| Property | Value |
|---|---|
| path | `build/app/outputs/flutter-apk/app-release.apk` |
| bytes | `123419671` |
| mtime (UTC) | `2026-10-03T03:30:19Z` |
| sha256 | `23cc6e9175643e5c4b17e6c9fc1e9bb9fec8990566f6556f505d103ceef594a8` |
| package / applicationId | `com.antigravity.valhalla.valhalla` |
| versionCode | `1` |
| versionName | `1.0.0` |
| platformBuild / compileSdk | `16` / `36` (codename `16`) |
| minSdk / targetSdk | `24` / `36` |
| signer DN | `C=US, O=Android, CN=Android Debug` |
| signer cert SHA-256 | `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` |
| signer cert SHA-1 | `f0fb4ad6bd3dd2d9513a0573b40910adb4d288c2` |
| signer cert MD5 | `80633e7c14c1b64a11a6a8b9c874e60a` |

Sources: `aapt2 dump badging` (package/versionCode/versionName/platform/min/target),
`apksigner verify --print-certs` exit 0 (cert), `stat` + `date -u -d @…` (bytes/mtime),
`sha256sum` (digest), `pubspec.yaml:19 version: 1.0.0+1`.

## 20. ADB — existing device only

| Step | Exit | Result |
|---|---|---|
| `adb devices -l` (before) | **0** | empty list |
| `adb connect 127.0.0.1:14251` (exactly one attempt) | **0** | `connected to 127.0.0.1:14251` |
| `adb devices -l` (after) | **0** | `127.0.0.1:14251 device product:sdk_gphone64_x86_64 model:sdk_gphone64_x86_64 device:emu64xa` — **pre-existing device/emulator, not created by this run** |
| on-device version before install | — | `versionCode=1 versionName=1.0.0 lastUpdateTime=2026-10-01 22:58:46` |
| `adb -s 127.0.0.1:14251 install -r <apk>` | **0** | `Performing Streamed Install` → `Success` |
| `logcat -c` (log buffer only — **not** `pm clear`) | **0** | — |
| `monkey -p <pkg> -c android.intent.category.LAUNCHER 1` | **0** | `Events injected: 1` |
| resolved activity | — | `com.antigravity.valhalla.valhalla/.MainActivity` |

Bounded startup / crash / ANR after a 15 s wait:

| Check | Result |
|---|---|
| `topResumedActivity` | `ActivityRecord{… com.antigravity.valhalla.valhalla/.MainActivity t142}` |
| `pidof <pkg>` | `5960` (process alive) |
| `logcat -d -b crash` lines | **0** |
| `am_crash` events | **0** |
| `am_anr` events | **0** |
| `FATAL EXCEPTION` occurrences | **0** |
| on-device after install | `lastUpdateTime=2026-10-03 11:31:34`, `versionCode=1`, `versionName=1.0.0` |

Only benign log lines observed (x86 CPU-variant notice, `jdwp` not-loadable, an
SELinux `avc: denied { read } proc_max_map_count`, a disposed splash input channel) —
no exception, no ANR, no process death after launch.

## 21. Finish — scope compliance

Done: 4 test-only harness fixes · four-file run **0 (+65)** · format **0** ·
gen-l10n **0** · analyze **0** · full suite **0 (+1713 ~18)** · APK backed up ·
release build **0** with full metadata/cert/hash/UTC-mtime · `adb devices -l` ·
one reconnect · `install -r` **0** · bounded startup/crash/ANR clean.

Not done (forbidden / out of scope): uninstall, `pm clear`, new emulator creation,
real ACP inference, remote auth, real mosh e2e, credentials, git mutation, dependency
or installer upgrades, `lib/` product/UI edits. Pinned installer remains **1.2.1**.
Both main and small model remained `opencode/mimo-v2.6-flash-free`.

Report complete.
