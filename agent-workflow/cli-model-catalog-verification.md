# CLI model catalog — business test verification — 2026-10-01

Scope: **business tests only**, per `agent-workflow/cli-model-catalog-ui.md`.
Model roles: **main + small = `opencode/mimo-v2.6-flash-free`**.

Stage gate: AgY original is concurrently implementing the UI. While AgY is active I did
**not** run gen-l10n, `flutter build`, ADB, or the whole-tree `flutter test`, and I did
**not** format or edit any product/UI file. All test editing/execution was mine.

## 1. Files touched

| file | role | change |
|---|---|---|
| `test/infrastructure/codex_model_catalog_test.dart` | CLI app-server fake (`serveModelList`, `_FakeSshSession`, `_RecordingSshClient`) | **extended**: `requestParams` capture on the fake + new group `默认 agentModelQueryProvider：只走 CLI app-server` (6 tests) |
| `test/core/independent_model_query_test.dart` | provider-level contract harness (`makeContainer`, `settle`, `FakeAcpPair`) | **extended**: optional `reuseStorage` on `makeContainer` (re-open without re-seeding) + new group `手动模型：只走声明的 model config RPC，不放宽其他校验` (10 tests) |
| `test/data/chat_run_settings_json_test.dart` | old/new `ChatRunSettings` JSON + draft persistence | **created** (11 tests) |

**No product, UI, l10n, business-logic or storage file was written.** The three test
files are untracked (`??`) — nothing tracked in the tree was modified by me.

## 2. What is covered

### 2.1 Default provider is the CLI path, never HTTP/OAuth (6 new)

Read the shipped default out of a bare `ProviderContainer()` — **no
`agentModelQueryProvider.overrideWithValue`** — so a regression to HTTP/OAuth discovery
cannot hide behind an override.

| test | proves |
|---|---|
| `Codex 目标真的发起 CLI initialize/initialized/model/list` | one `bash -l -c … '/usr/local/bin/codex' app-server` exec; RPC order exactly `['initialize','initialized','model/list']`; `closeCount == 1`; catalog returned |
| `绝不走 HTTP/OAuth/历史/指令` | executed command contains **no** `curl` / `wget` / `http(s)://` / `api.openai.com` / `oauth` / `authorize` / `authorization` / `token` / `model_authorization` / `open_browser`; RPC has no `session/prompt` and no `thread/*`, `turn/*`, `session/*`, `composer*`, `skills/*`, `response/*` |
| `容器目标沿用同一容器与执行用户` | `docker exec -i --user 'codex' 'val-codex' /bin/sh -lc … app-server` |
| `非 Codex CLI 在触碰 SSH 前直接返回 null` | `client.commands` **empty**, `requestMethods` empty, `closeCount == 0` — returns before touching SSH |
| `翻完游标页后关闭进程` | two `model/list` pages, `cursor` absent then `'page-2'`, cross-page dedup, `closeCount == 1` |
| `查询失败仍关闭进程且不吞掉错误` | `RpcError` propagates, `closeCount == 1` |

Cleanup / pagination / error shapes are asserted against **the existing fakes**
(`serveModelList`, `_FakeSshSession`, `_RecordingSshClient`), reusing the direct-client
contract already pinned in this file's `queryCapabilities` group (host `bash -l -c`,
docker `--user`, 15 s late-channel `TimeoutException`, failure-closes).

### 2.2 `ChatRunSettings` old/new JSON (11 new)

- legacy JSON **without** `customModel` → `false`, all other fields preserved; empty
  object → all defaults
- non-boolean `customModel` (`'true'`, `'TRUE'`, `1`, `1.0`, `[]`) → `false` (only the
  literal `true` counts)
- new format round-trips byte-identically (`toJson → fromJson → toJson` equality);
  normal list selections also emit an explicit `false`
- `copyWith` keeps `customModel` when changing `modelId`/`reasoningId`;
  `customModel: false` keeps the id; `clearModel: true` clears **both**
- `LocalStorageService`: `saveChatRunDefault`/`getChatRunDefault` round-trip; a legacy
  stored entry with no `customModel` key reads as `false`; a new write does **not**
  clobber other agents' entries; `saveCliRunSettings` mirrors into the default draft

### 2.3 Manual model (10 new)

Harness: real `AiChatNotifier` over `FakeAcpPair`, with the model `config_options`
advertised by the fake agent.

| test | result |
|---|---|
| `非法手动 ID显式拒绝，且不改写已保存的草稿` | `''`, `' '`, `'has space'`, `'tab\there'`, `'ctrl\x01model'`, `'nbsp model'`, `'del\x7fmodel'`, 257 chars → `ACP_CUSTOM_MODEL_INVALID`; draft and storage unchanged; **ordinary list selection still accepted** |
| `草稿手动模型只保存不发 RPC，重开容器后仍生效且不伪造目录` | draft writes no `session/new` / `set_config_option`; `customModel` persisted; a fresh container over the same storage restores id + flag; first send pushes the unlisted id; the catalog is **not** polluted with a fake entry |
| `未列出的显式模型只发这一条 model config RPC 并要求精确回执` | exactly `[(configId: 'model', value: 'my-manual-model-2026')]` — no other config id; confirmed only from the agent echo; persisted |
| `agent 不回显精确值时报未确认，绝不乐观写入` | `ignoreSetConfigOption` → `ACP_CUSTOM_MODEL_NOT_CONFIRMED`, `runSettings.modelId` never becomes the manual id |
| `agent 拒绝该手动值时同样报未确认` | `rejectedConfigValues` → same code, one RPC attempted |
| `RPC 本身失败时按配置失败上报，不吞掉错误` | `-32603` → `ACP_SETTING_APPLY_FAILED: model`, rethrown, not optimistic |
| `没有 model 设置 API 时显式报不可用` | no `config_options` → `ACP_SETTING_UNAVAILABLE: model`, **zero** RPC |
| `手动模型不放宽推理选择校验` | on model change the bad `reasoningId` is never sent (`configIds == ['model']`) and the confirmed value falls back to `'low'`; with no model change the same bad value is rejected `ACP_SETTING_UNAVAILABLE: thought_level` |
| `手动模型不改变权限策略` | `askEveryTime` requested under a manual model stays `askEveryTime` in confirmed settings and in storage — never escalated to `autoAllowAll` |
| `普通列表选择的过时模型仍然被拒，且不发 RPC` | `customModel: false` + unlisted id → `ACP_MODEL_NOT_SUPPORTED_BY_ADAPTER`, `setConfigOptionRequests` **empty** |

Rejection / no-API / unconfirmed are three distinct tests (RPC error, missing option,
non-echoing agent), not one path re-labelled.

## 3. Exact commands and exit codes

Direct redirection, `$?` captured immediately (no pipelines).

| # | command | exit | result | log |
|---|---|---|---|---|
| 1 | `dart format --output=none --set-exit-if-changed <3 test files>` | 1 | 3 needed formatting (test files only) | `/tmp/opencode/clmc1-format.log` |
| 2 | `dart format <3 test files>` (write) | 0 | `Formatted 3 files (3 changed)` | `/tmp/opencode/clmc1-format-write.log` |
| 3 | `dart format <3 test files>` (re-check) | 0 | `Formatted 1 file (0 changed)` | `/tmp/opencode/clmc2-format.log` |
| 4 | `flutter test --no-pub test/infrastructure/codex_model_catalog_test.dart` | 0 | `+15` | `/tmp/opencode/clmc2-catalog.log` (first attempt `/tmp/opencode/clmc1-catalog.log` exit 1: my new pagination assertion read the wrong fake channel — fixed in the test, product untouched) |
| 5 | `flutter test --no-pub test/data/chat_run_settings_json_test.dart` | 0 | `+11` | `/tmp/opencode/clmc2-json.log` |
| 6 | `flutter test --no-pub test/core/independent_model_query_test.dart` | 0 | `+42` | `/tmp/opencode/clmc2-provider.log` |
| 7 | `dart analyze <the 3 test files>` | 0 | `No issues found!` | `/tmp/opencode/clmc2-analyze.log` |
| 8 | focused set (all three together) | 0 | **`+68 ~0 -0`**, All tests passed | `/tmp/opencode/clmc2-focused.log` (32 805 B) |

Per-file: `codex_model_catalog_test.dart` **15** (9 pre-existing + 6 new),
`independent_model_query_test.dart` **42** (32 pre-existing + 10 new),
`chat_run_settings_json_test.dart` **11** — total **68**.

## 4. Not done here (explicitly)

- **no** product/UI/l10n/storage edit; **no** test weakened — the one failure was fixed in
  my own new assertion, never by loosening a production contract
- **no** gen-l10n, **no** `flutter build`, **no** ADB, **no** whole-tree `flutter test`
  while AgY is active
- **no** real OAuth, credentials, browser authorization, inference or remote history
- **no** git commit/push; dirty tree preserved
- UI-level checks (no authorization button in the ACP view, refresh/model controls kept)
  are **AgY's UI READY gate**, not covered here.

**Status: business tests GREEN (+68, analyze clean on the touched files).** Awaiting the
UI READY instruction before format/gen-l10n/analyze/full-suite/release gates.

---

## 5. Final gates after the UI READY unlock (2026-10-01, all direct-redirection)

| # | command | exit | result | log |
|---|---|---|---|---|
| 1 | `dart format` write on root2+UI2+3 test files | 0 | `Formatted 7 files (5 changed)` | `/tmp/opencode/clm3-format.log` |
| 2 | `dart format --output=none --set-exit-if-changed` same 7 | 0 | `Formatted 7 files (0 changed)` | `/tmp/opencode/clm3-format-check.log` |
| 3 | `flutter gen-l10n` | 0 | only the l10n.yaml notice | `/tmp/opencode/clm3-genl10n.log` |
| 4 | `flutter analyze --no-pub` | 1 | 4 errors, **all in my new stage2 widget tests** (3x nullable `controller`, 1x undefined `input.key`) — fixed in the test only | `/tmp/opencode/clm3-analyze.log` |
| 5 | `flutter analyze --no-pub` (re-run) | 0 | `No issues found!` | `/tmp/opencode/clm3-analyze2.log` |
| 6 | `flutter test --no-pub test/features/live_models_stage2_widget_test.dart` | 0 | **`+28`** (22 pre-existing + 6 new) | `/tmp/opencode/clm3-stage2.log` |
| 7 | `flutter test --no-pub` catalog+json+provider+chat_run_settings | 0 | **`+75`** | `/tmp/opencode/clm3-focused-a.log` |
| 8 | focused set (9 files incl. stage2) | 0 | **`+145 ~0 -0`**, All tests passed | `/tmp/opencode/clm3-focused.log` (38 143 B) |
| 9 | `flutter test --no-pub` whole tree | 0 | **`+1598 ~17 -0`**, All tests passed | `/tmp/opencode/clm3-fulltests.log` (396 836 B) |

Per-file final counts: `codex_model_catalog_test.dart` **15** (9 pre-existing + 6);
`independent_model_query_test.dart` **43** (32 pre-existing + 10 manual-model + 1 first-send);
`chat_run_settings_json_test.dart` **11**; `live_models_stage2_widget_test.dart` **28**
(22 pre-existing + 4 manual-model + 1 AiChatView authorization-gate + 1 narrow-screen).

### 5.1 What was added in this stage (test files only, Edit tool only)

- `codex_model_catalog_test.dart` — `defaultQuery()` now calls `container.dispose()` in a
  `finally`, so every bare `ProviderContainer` the default-provider group builds is disposed.
- `independent_model_query_test.dart` — ONE first-send regression: the `session/new` initial
  config notification must not erase an already-confirmed manual model. Draft
  `{modelId, customModel:true}`; config options delivered mid-flight; asserts exactly
  `[(configId:'model', value: manualId)]`; post-acceptance state keeps `customModel:true`;
  no fabricated catalog entry; storage flag persisted; `session/prompt` sent; no `session/list`.
- `live_models_stage2_widget_test.dart` — manual-model empty-catalog entry + save + localized
  hint, invalid-input table (empty / spaces / >256 / control char), refresh+reopen preserving
  text, switch-back clearing `customModel`; a real `AiChatView` settings dialog with
  `onAuthorize == null` (no authorize button / authorizing card / confirm button /
  "Authorize Model Catalog", while refresh + model dropdown + segmented remain and survive a
  refresh); narrow-screen 360x640 DPR 1.0 with `takeException()` null. One pre-existing copy
  expectation updated from `Latest model catalog unavailable` to
  `chatSettingsIndependentModelUnavailable` (AgY l10n copy change, reason noted in-test).

All 4 intermediate analyze errors were in my own new test code; product/UI untouched.

## 6. Release APK + ADB install proof

### 6.1 Recoverable backup (previous stage-4 APK)

```
STAMP=20261001T114030Z
build/apk-backup/app-release.apk.20261001T114030Z.stage4
build/apk-backup/app-release.flutter-apk.apk.20261001T114030Z.stage4
SHA256 (both copies): 1dfe9ab4e59b93e3234300ece10ec2cffcb2390ae584cda0732cbb728d4b0f35
size: 123 304 927 B     BACKUP_EXIT=0
```

### 6.2 Fresh release build

```
flutter build apk --release  ->  BUILD_EXIT=0
  ✓ Built build/app/outputs/flutter-apk/app-release.apk (123.2MB)
file   : build/app/outputs/apk/release/app-release.apk
size   : 123 190 191 bytes
mtime  : 2026-10-01 19:41:48 +0800
sha256 : 32c3478d689fefe7173586e1f9a4ce1bed16b3b105a56c338383d068d91514a3
         (identical to build/app/outputs/flutter-apk/app-release.apk)
```

```
aapt dump badging (AAPT_EXIT=0)
  package: name=com.antigravity.valhalla.valhalla versionCode=1 versionName=1.0.0
  sdkVersion=24  targetSdkVersion=36  compileSdkVersion=36
  application: label=valhalla

apksigner verify --print-certs (APKSIGNER_EXIT=0)
  Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
  Signer #1 certificate SHA-256: 2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9
```

### 6.3 `adb install -r` (no uninstall, no `pm clear`)

```
device: 127.0.0.1:14251  model:sdk_gphone64_x86_64  device:emu64xa  transport_id:1

PRE-INSTALL
  versionCode=1 minSdk=24 targetSdk=36   versionName=1.0.0
  lastUpdateTime=2026-10-01 18:52:10
  firstInstallTime=2026-09-23 03:26:04
  signatures=PackageSignatures{74bbc1f version:2, signatures:[6e5dbc6], past signatures:[]}
  pid pre: 26523

adb install -r  ->  INSTALL_EXIT=0  ->  Performing Streamed Install / Success

POST-INSTALL
  versionCode=1 minSdk=24 targetSdk=36   versionName=1.0.0
  lastUpdateTime=2026-10-01 19:42:13      (refreshed)
  firstInstallTime=2026-09-23 03:26:04    (UNCHANGED -> in-place update)
  signatures=PackageSignatures{74bbc1f version:2, signatures:[6e5dbc6], past signatures:[]}  (UNCHANGED)
  dataDir=/data/user/0/com.antigravity.valhalla.valhalla  (app data preserved)
```

### 6.4 Launch + crash/ANR log window

```
marker    : 10-01 19:42:21.000
am start  : AMSTART_EXIT=0  Intent { cmp=com.antigravity.valhalla.valhalla/.MainActivity }
Start proc: 10-01 19:42:21.472 I/ActivityManager: Start proc 24879:com.antigravity.valhalla.valhalla
resumed   : topResumedActivity=ActivityRecord{... com.antigravity.valhalla.valhalla/.MainActivity t139}
pid       : 24879 at +10s, still 24879 at +25s (stable, never restarted)

logcat -d -v time -T "10-01 19:42:21.000" -> LOGCAT_EXIT=0, 194 lines / 29 192 B
  crash/ANR keyword grep (FATAL EXCEPTION|ANR in|am_anr|am_crash|beginning of crash|
  Force finishing|not responding)                              = 0
  dumpsys activity processes | grep -iE "anr|not responding"   = empty (no ANR records)
  E-level lines total 17:
    1  app pid 24879  "Not starting debugger since process cannot load the jdwp agent." (benign)
   16  pid 18940 / 9200  Google tiktok tracing + TaskPersister recents-dir warnings (not our app)
  W-level lines from app pid 24879 = 5, all benign:
    x86 CPU variant notice, SELinux proc_max_map_count read denial,
    OpenGLRenderer "Unknown dataspace 0" / "Failed to initialize 101010-2 format"
```

**Final status: ALL GREEN** — format 0, gen-l10n 0, analyze 0 (`No issues found!`),
stage2 `+28`, focused `+145 ~0 -0`, full suite `+1598 ~17 -0`; release APK rebuilt
(SHA `32c3478d…1514a3`), `install -r` success with `firstInstallTime`/signature/data
unchanged, app launched and stayed up (pid 24879) with a zero-crash, zero-ANR log window.
