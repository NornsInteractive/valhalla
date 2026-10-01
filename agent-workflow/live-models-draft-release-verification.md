# Live catalog / draft UI — release verification — 2026-10-01

Working file for the release flow in `agent-workflow/live-models-draft-release.md`.
This document is written **incrementally, per stage**. Sections marked *pending* have
not been executed yet and no result is claimed for them.

- Session model: main + small = **`opencode/mimo-v2.6-flash-free`** (unchanged).
- Dirty worktree preserved: no commit, no push, no product-semantics edit.
- No real login / credentials / inference / remote history at any stage.

---

## STAGE 1 — browser bridge (COMPLETE)

Scope authorised for this stage: browser-only regression. AgY UI work is still in
progress, so **no whole-tree analyze, no full test suite, no gen-l10n, no build, no
ADB** were run.

### 1.1 Files

| file | role | touched by OpenCode |
|---|---|---|
| `lib/core/services/model_authorization_browser.dart` | root's new bridge: `MethodChannel('valhalla/model_authorization')` → `invokeMethod<bool>('openBrowser', {'url': …})`, validating `https` + host `auth.openai.com` + empty `userInfo` + port `443` **before** dispatch, and folding `false` / `null` / `PlatformException` / `MissingPluginException` into `AGENT_MODEL_BROWSER_FAILED` | **format only** — `dart format` reported **0 changed**, mtime still root's `17:42:56`, no semantic edit |
| `android/.../MainActivity.kt` | root's Android bridge | not read, not edited (Kotlin compile is covered later by the release build) |
| `test/core/model_authorization_browser_test.dart` | the new mock-channel test | **created** |
| `agent-workflow/live-models-draft-release-verification.md` | this report | **created** |

Nothing else was created or modified in this stage. No transient probe file exists.

### 1.2 What the test proves

Pure method-channel mock (`TestDefaultBinaryMessengerBinding`), one narrow file,
**10 tests**. No real browser, no OAuth flow, no platform implementation, no credentials.

**A. Official HTTPS endpoint is allowed and dispatched verbatim (2)**

| test | assertion |
|---|---|
| `https + auth.openai.com + 无 userinfo + 默认 443` | resolves normally; **exactly one** dispatch; `method == 'openBrowser'`; `arguments == {'url': url.toString()}` and equals the input string unchanged; bridge reply `true` |
| `显式 :443 端口同样放行` | `Uri.port == 443` passes the guard; one dispatch; payload is `Uri.toString()` |

**B. Rejected *before* dispatch — the channel is never called (4)**

Each case asserts `AGENT_MODEL_ENDPOINT_INVALID` **and** `dispatched` is empty:

| case | input |
|---|---|
| 明文 http | `http://auth.openai.com/authorize` |
| 非官方主机 | `https://evil.example/authorize`, `https://auth.openai.com.evil.example/x` |
| 带 userinfo | `https://user:secret@auth.openai.com/authorize` |
| 非 443 端口 | `https://auth.openai.com:8443/authorize`, `https://auth.openai.com:4443/authorize` |

**C. Bridge failures all sanitize to the fixed browser-failure code (4)**

Every case asserts `StateError` with message exactly `AGENT_MODEL_BROWSER_FAILED`:

| case | bridge behaviour | dispatch recorded |
|---|---|---|
| `false` | handler returns `false` | 1 |
| `null` | handler returns `null` | 1 |
| `PlatformException` | handler throws `PlatformException(code: ACTIVITY_NOT_FOUND)` | 1 |
| `MissingPluginException` | mock handler removed → no platform implementation | 0 (no handler to record) |

The original `PlatformException` code/message never escapes the service — only the
fixed code is observable from the test.

### 1.3 Gates for this stage

| gate | command | result |
|---|---|---|
| format (only the new browser service + its test) | `dart format --output=none --set-exit-if-changed lib/core/services/model_authorization_browser.dart test/core/model_authorization_browser_test.dart` | `Formatted 2 files (0 changed)`, **exit 0** |
| the one relevant test | `flutter test --no-pub test/core/model_authorization_browser_test.dart` | **`+10 ~0 -0`, All tests passed, exit 0** — log `/tmp/opencode/lmd3-browser-final.log` (5 281 bytes) |

### 1.4 Observation (not a defect)

Dart's `Uri.toString()` normalises an explicit default port away, so
`https://auth.openai.com:443/...` is dispatched as `https://auth.openai.com/...`.
The guard still evaluates `url.port == 443` correctly (asserted), and the payload is
exactly `url.toString()` with no rewriting by the service. The test pins both facts.

### 1.5 Explicitly NOT done at this stage

- **no** whole-tree `flutter analyze --no-pub`
- **no** whole-tree `flutter test --no-pub`
- **no** `gen-l10n`, **no** broad format pass
- **no** `flutter build apk`, **no** `adb` of any kind
- **no** widget/UI tests (AgY UI still in progress)
- **no** product, UI, auth or history edit

---

## STAGE 2 — AgY UI READY widget regression (COMPLETE, GREEN)

Scope authorised for this stage: **`test/**` only + this report + gen-l10n outputs**.
No product/UI semantic edit, no whole-tree full test run, no build, no ADB.

### 2.1 Files

| file | role | touched by OpenCode |
|---|---|---|
| `test/features/live_models_stage2_widget_test.dart` | the Stage 2 widget regression — **20 tests / 6 groups** as delivered in Stage 2; Stage 3 appended two more narrow AiChatView integration regressions (→ **22 tests / 7 groups**, see §3.1) | **created** (Stage 2), **extended** (Stage 3) |
| `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_zh.dart` | generated localizations | **regenerated** by `flutter gen-l10n` (whitelisted) |
| `lib/l10n/app_en.arb`, `app_zh.arb` | template ARBs | **not edited by OpenCode** — AgY owns them; only read |
| `agent-workflow/live-models-draft-release-verification.md` | this report | **edited (Stage 2 section appended)** |

Nothing else was created or modified. No transient probe file exists.

### 2.2 gen-l10n (was a hard prerequisite)

Before `flutter gen-l10n` the tree **did not compile**: `lib/l10n/app_localizations*.dart`
were stale relative to AgY's ARB additions, so every consumer of
`chatModelAuthorizeConfirmTitle`, `chatModelAuthorizeConfirmMessage`,
`chatModelCatalogError403`, `chatModelCatalogErrorGeneric`,
`chatSettingsIndependentModelUnavailable`, `chatSettingsModelCatalogNote`,
`chatModelAuthorizing`, `chatModelAuthorizeCancel`, `chatModelAuthorizeButton`,
`chatCommandsClientActionRunSettings`, `chatCommandsClientActionWorkingDirectory`
and `chatCommandsFirstTurnNote` failed to resolve. `flutter gen-l10n` regenerated the
three generated files: **1 198 inserted lines, 0 deleted lines** (only additions; the
single `"copy": "Copy"` line diff in the ARBs is AgY appending a trailing comma plus
new keys — no key was removed).

Attribution: **AgY (UI/process)** — ARB + lib usage updated without regenerating.
Fixed here because gen-l10n output is explicitly whitelisted for this stage.

### 2.3 What the 20 tests prove

All mocked: `ChatRunSettingsDialog` / `ChatCommandsSkillsDialog` / `AiChatView` driven
by in-memory doubles on `test/support/acp_chat_widget_harness.dart`. No SSH, no Agent,
no browser, no credentials, no network.

**A. Model catalog — empty / missing current / refresh (6)**

| test | assertion |
|---|---|
| `目录为空时下拉不可用且不触发断言，也绝不回退到缺失的 currentModelId` | `takeException()` is null; inner `DropdownButton.items == null` and `onChanged == null` (non-interactive); `Latest model catalog unavailable` shown; `gpt-5` (the remote-claimed `currentModelId`) **not** rendered as a selection |
| `目录里没有当前模型时回落到 Default，绝不显示不存在的 id` | dropdown mounts, shows `Default`, `ghost-model` never rendered, no exception; saved settings carry `modelId == null` |
| `刷新后目录仍包含已选项时保留原选择` | refresh → saved `modelId` still `gpt-5-mini` |
| `刷新把已选项删掉时回落到 Default，且不自动套用第一项` | refresh removing `gpt-5-mini` → no exception, dropdown still mounts, shows `Default`, `GPT-5 mini` gone, saved `modelId == null` (first item **not** auto-applied) |
| `刷新未返回时关闭弹窗，迟到结果不会重建已销毁的界面` | refresh gated by a `Completer`; dialog popped externally; late result arrives → dialog stays gone, `takeException()` null (mounted guard in `_handleRefresh`) |
| *(covered by the same group)* | `chat_run_settings_model_dropdown` / `chat_run_settings_refresh_button` keys used throughout — no `DropdownButtonFormField.value` reads (deprecated API avoided) |

**B. Catalog warning vs. permission controls (3)**

| test | assertion |
|---|---|
| `目录告警出现时权限控件仍可选择并保存` | `modelCatalogError: '403 forbidden…'` → `chat_run_settings_model_catalog_warning` present with the dedicated localized `403` text **and** `chat_permission_auto_allow_safe` still tappable; save records `autoAllowSafe` |
| `自动允许全部被取消时保持原策略` | tapping `chat_permission_auto_allow_all` opens the confirmation; declining it leaves the policy at `askEveryTime` |
| `自动允许全部经显式确认后才生效` | confirming sets `autoAllowAll`; the dialog is dismissed only after the explicit confirm |

**C. Codex independent authorization — confirm / decline / dispose / callback error (4)**

| test | assertion |
|---|---|
| `确认框展示目标服务器、容器与用户，确认后才调用授权` | confirm dialog shows `Target Server: Prod Host`, `Target Container: valhalla-agent`, `Username: coder`; `onAuthorize` calls **0** before confirm, **1** after; authorizing card + `chat_run_settings_cancel_auth_button` appear; after completion the card is gone and the authorize button returns |
| `确认框未打开前不调用授权；拒绝则完全不调用` | opening the confirm dialog alone → 0 calls; declining → still 0 calls, no authorizing card, no exception |
| `授权等待中关闭弹窗会触发取消回调` | while gated pending: closing the settings dialog calls `onCancelAuthorize` exactly once; the late completion of `onAuthorize` is swallowed by the mounted guard, no exception |
| `授权回调失败时展示稳定错误码，且不回显回调参数` | `StateError('AGENT_MODEL_CALLBACK_INVALID')` → `chat_run_settings_error_banner` shows exactly that code; authorizing card cleared, authorize button restored; banner contains **no** `access_token`, `code=`, `http://`, `https://` |

**D. Save guards — await-save / mounted (2)**

| test | assertion |
|---|---|
| `保存未返回时禁用保存与取消，弹窗保持打开` | while `onSave` is gated: dialog still mounted, save + cancel `onPressed == null`, spinner inside the save button; completing the gate closes the dialog cleanly |
| `保存期间弹窗被外部关闭时迟到结果不会再 pop` | dialog popped externally during a pending save; the late result hits the `if (mounted)` guard → no exception, dialog stays closed |

**E. Draft commands + `$skills` insertion, no invented RPC (4)**

| test | assertion |
|---|---|
| `草稿态打开命令面板展示命令与客户端动作，且无发送副作用` | draft (no active session) → panel lists `status` / `compact`, tab `Commands (2)`, client action `Run Settings`; notifier counters: `prepareComposerCatalogCalls == 1`, `sendMessageCalls == 0`, `prepareRunSettingsCalls == 0`, `queryAccountStatusCalls == 0` |
| `命令为空时重试会用回调返回的真实命令刷新面板` | empty catalog → `chat_commands_retry_button`; one retry → the callback's real commands render (`Commands (2)`, `status`, `compact`) and the retry button disappears; `retryCalls == 1` |
| `草稿态按光标位置插入命令且不发送` | cursor at offset 7 of `please run this` → panel pick inserts `/status ` **at the cursor** → `please /status run this`, selection collapsed at 15, `draftTexts.last` matches, `sendMessageCalls == 0` |
| `草稿态插入 $skills 前缀且不发送` | picking `$review` from the Skills tab appends `fix the bug$review `, draft updated, `sendMessageCalls == 0` |

Insertion uses `AcpSlashCommand.insertion` only (`/cmd ` for protocol commands,
`$skill ` for skills) — asserted at the widget boundary, no client-side command
synthesis and no RPC issued by the panel.

**F. Target-switch guards (2)**

| test | assertion |
|---|---|
| `打开设置途中切换 Agent 时不再弹出设置弹窗` | `prepareRunSettings` gated; the active agent is switched while the await is in flight; the re-check after the await refuses → `chat_run_settings_dialog` never appears, `takeException()` null |
| `目标未变时打开设置弹窗` | same path with no target change → the dialog **does** appear (the guard is not a blanket early-return) |

### 2.4 Gates for this stage

Run at `2026-10-01T10:21Z`:

| gate | command | result |
|---|---|---|
| gen-l10n | `flutter gen-l10n` | regenerated the 3 generated localization files, **exit 0** |
| format (only the new test) | `dart format --output=none --set-exit-if-changed test/features/live_models_stage2_widget_test.dart` | `Formatted 1 file (0 changed)`, **exit 0** |
| analyzer (whole tree, as instructed) | `flutter analyze --no-pub` | `No issues found! (ran in 2.8s)`, **exit 0** |
| the new Stage 2 test alone | `flutter test --no-pub test/features/live_models_stage2_widget_test.dart` | **`+20 ~0 -0`, All tests passed, exit 0** — log `/tmp/opencode/lmd4-stage2-widget.log` (12 551 bytes) |
| focused set (6 files) | `flutter test --no-pub test/features/live_models_stage2_widget_test.dart test/features/acp_run_settings_metadata_test.dart test/features/acp_usability_widget_controls_test.dart test/features/chat_run_settings_test.dart test/features/ui_enhancements_round_test.dart test/features/ai_chat_session_isolation_test.dart` | **`+68 ~0 -0`, All tests passed, exit 0** — log `/tmp/opencode/lmd4-stage2-focused.log` (21 371 bytes) |

Per-file counts of the focused set (each run alone, `flutter test --no-pub`):

| file | count |
|---|---|
| `test/features/live_models_stage2_widget_test.dart` | **20** |
| `test/features/acp_run_settings_metadata_test.dart` | **18** |
| `test/features/acp_usability_widget_controls_test.dart` | **9** |
| `test/features/chat_run_settings_test.dart` | **6** |
| `test/features/ui_enhancements_round_test.dart` | **9** |
| `test/features/ai_chat_session_isolation_test.dart` | **6** |
| **total** | **68**, all exit 0 |

### 2.5 Observations (not defects, attributed for the record)

1. **Empty catalog still mounts the Dropdown widget.** `chat_run_settings_dialog.dart`
   always builds `DropdownButtonFormField<String?>` under `isStructuredSend`, and only
   passes `items: null` / `onChanged: null` when `caps.models.isEmpty`. No Flutter
   assertion fires (verified by `takeException()`), the localized unavailable hint is
   shown, and the control is non-interactive. The test pins all four facts rather than
   asserting widget absence, so the "never asserts" requirement is covered
   behaviourally. → **AgY (UI)**, no action required.
2. **The settings dialog renders `_errorMessage` verbatim** (`error.toString()`) with
   no `LogSanitizer` pass (`chat_run_settings_dialog.dart:620`). The tested path only
   ever receives folded `StateError` codes (`AGENT_MODEL_ENDPOINT_INVALID`,
   `AGENT_MODEL_CALLBACK_INVALID`, `AGENT_MODEL_AUTH_FAILED`, `AGENT_MODEL_AUTH_BUSY`,
   `AGENT_MODEL_QUERY_UNSUPPORTED`, `SSH_DISCONNECTED`), because root's bridge folds
   everything else — so nothing sensitive can reach the banner today, and the test pins
   that the banner contains no `access_token` / `code=` / `http(s)://`. If a future
   `onAuthorize` implementation is allowed to throw a raw exception, it would be
   displayed as-is. → flag to **root (business/provider layer)** as a hardening
   candidate; not a defect in the current flow.
3. **Two analyzer issues were observed mid-stage and disappeared before the final
   gate**: `use_build_context_synchronously` at `lib/features/chat/ai_chat_view.dart:2353`
   and `unused_local_variable` (`hasRemoteModel`) at
   `lib/features/chat/widgets/chat_run_settings_dialog.dart:416`. Both were gone from
   `flutter analyze --no-pub` at `10:21Z`, i.e. **AgY fixed them while this stage ran**.
   The recorded analyzer result is a point-in-time snapshot of a live worktree.

### 2.6 Explicitly NOT done at this stage

- **no** whole-tree `flutter test --no-pub` (Stage 3)
- **no** `flutter build apk`, **no** `adb` of any kind (Stage 3)
- **no** product / UI / business-logic edit — the only non-test files written are the
  three gen-l10n outputs
- **no** test weakened to make a gate pass; both initial failures were corrected in the
  *test's own* expectations after reading the shipped widget behaviour (see §2.5.1), and
  the `AcpSlashCommand` / `$skills` compile errors were fixed in the test file, never in
  `lib/`

---

## STAGE 3 — final gates + release build + install (COMPLETE, GREEN)

Scope authorised: two narrow AiChatView integration regressions added to the existing
Stage 2 test file, then format / gen-l10n / analyze / focused + full tests, and — only
after every gate was green — a recoverable backup, a fresh release APK, and an
`adb install -r` on the existing authorised target.

- Session model: **main + small = `opencode/mimo-v2.6-flash-free`** (unchanged).
- Original Valhalla reconciliation complete (exit resume `ec81a4be-7543-45ee-8658-f68966f57d3b`).
- **No product / UI / business-semantic edit.** The only non-test files written are the
  three gen-l10n outputs. All dirty worktree changes preserved; no commit, no push.
- `--prompt-interactive` was **never** used.
- No real OAuth, no browser authorization, no inference, no remote history, no
  credentials anywhere in this stage.

### 3.1 The two added integration regressions

Added to `test/features/live_models_stage2_widget_test.dart`, group
`命令面板生命周期 - 迟到重试与打开期间的命令更新`, reusing the existing
`_ComposerChatNotifier` (an extension of the shared `FakeAcpChatNotifier` from
`test/support/acp_chat_widget_harness.dart`) and the production widgets — **no new
test framework, no new harness**. Two small additions to that fake:
`composerCatalogGate` (a `Completer<bool>` that suspends `prepareComposerCatalog`)
and `publishCommands(...)` (pushes a new `commands` list into provider state).

| # | test | what it proves |
|---|---|---|
| 1 | `重试挂起时关闭面板，迟到结果不会读取已销毁的 WidgetRef` | menu opened (1st `prepareComposerCatalog` completes normally), then retry is started and **gated**; the dialog is closed while that retry is still awaiting; the late result then arrives. Asserts: `chat_commands_skills_dialog` gone **but** `chatPromptInput` still present — i.e. the parent `AiChatView` is alive while only the `Consumer`'s route is dead — then `takeException()` is null, no dialog reappears, `prepareComposerCatalogCalls == 2`, `sendMessageCalls == 0`, `draftTexts` empty. |
| 2 | `面板打开期间收到命令更新会立即刷新显示` | panel opens against an empty catalog (`Commands (0)`, retry button present, `status` absent); a background command update is then pushed into provider state. Asserts the **already-open** dialog refreshes in place: `Commands (2)` / `Skills (1)`, `status` + `compact` listed, retry button gone; switching to the Skills tab shows `$review` from the same notification. Dialog stays open, no exception, nothing sent, no draft mutation. |

**Why test 1 is load-bearing (teeth).** `onRetry` runs inside
`Consumer(builder: (ctx, ref, _) { … })` in `_openCommandsAndSkills`. The guard root
asked for is the post-await `if (!mounted \|\| !ctx.mounted) return null;`. Without it,
the closure falls through to `ref.read(activeServerProvider)`, and
`flutter_riverpod` 3.3.2 `ConsumerStatefulElement.read` (`lib/src/core/consumer.dart:556`)
calls `_assertNotDisposed()` (`:466`), which throws `StateError('Using "ref" when a
widget is about to or has been unmounted is unsafe…')` as soon as `context.mounted` is
false. Because `mounted` there is the **`AiChatViewState`** (still true) and only
`ctx` belongs to the closed dialog, checking only the parent mounted state is
insufficient — exactly root's review note. The test asserts `chatPromptInput` is still
mounted to pin that distinction.

Test 2 proves the live-catalog contract in §4 of AgY's UI report: the dialog is mounted
inside a `Consumer` that watches `aiChatProvider`, so `didUpdateWidget` must propagate
a new `commands` list into the already-open `ChatCommandsSkillsDialog`.

### 3.2 Final gates — exact commands, exit codes, logs

Every command was run with **direct log redirection and `$?` captured immediately**
(`cmd > log 2>&1; echo $?`) — no pipelines masking the exit status.

| # | command | exit | result | log |
|---|---|---|---|---|
| 1 | `dart format test/features/live_models_stage2_widget_test.dart` | **0** | `Formatted 1 file (1 changed)` | `/tmp/opencode/lmd5-format.log` |
| 2 | `dart format --output=none --set-exit-if-changed test/features/live_models_stage2_widget_test.dart` | **0** | `Formatted 1 file (0 changed)` (re-verified after all edits) | `/tmp/opencode/lmd6-format-check.log` |
| 3 | `flutter gen-l10n` | **0** | regenerated the three generated localization files | `/tmp/opencode/lmd5-genl10n.log` |
| 4 | `flutter analyze --no-pub` | **0** | `No issues found! (ran in 2.9s)` — whole tree, zero issues | `/tmp/opencode/lmd6-analyze.log` |
| 5 | `flutter test --no-pub test/features/live_models_stage2_widget_test.dart` | **0** | **`+22 ~0 -0`**, All tests passed | `/tmp/opencode/lmd6-stage3-widget.log` (13 741 B) |
| 6 | `flutter test --no-pub <6 focused files>` (command below) | **0** | **`+70 ~0 -0`**, All tests passed | `/tmp/opencode/lmd5-focused.log` (22 885 B) |
| 7 | `flutter test --no-pub` (whole tree) | **0** | **`+1564 ~17 -0`**, All tests passed | `/tmp/opencode/lmd5-fulltests.log` (397 728 B) |
| 8 | `flutter build apk --release` | **0** | `✓ Built build/app/outputs/flutter-apk/app-release.apk (123.3MB)` — `assembleRelease` 125.9 s | `/tmp/opencode/lmd5-build.log` |

Focused command (gate 6):

```
flutter test --no-pub \
  test/features/live_models_stage2_widget_test.dart \
  test/features/acp_run_settings_metadata_test.dart \
  test/features/acp_usability_widget_controls_test.dart \
  test/features/chat_run_settings_test.dart \
  test/features/ui_enhancements_round_test.dart \
  test/features/ai_chat_session_isolation_test.dart
```

Per-file counts of the focused set (each run alone, `flutter test --no-pub`):

| file | count |
|---|---|
| `test/features/live_models_stage2_widget_test.dart` | **22** (20 Stage 2 + 2 Stage 3) |
| `test/features/acp_run_settings_metadata_test.dart` | **18** |
| `test/features/acp_usability_widget_controls_test.dart` | **9** |
| `test/features/chat_run_settings_test.dart` | **6** |
| `test/features/ui_enhancements_round_test.dart` | **9** |
| `test/features/ai_chat_session_isolation_test.dart` | **6** |
| **total** | **70**, all exit 0 |

Whole-tree gate 7 ran **after** gate 1–6 and **before** the build (18:36 build at
18:39), so the shipped APK comes from exactly the tree the full suite passed on.
Previous whole-suite snapshot was `+1532 ~17`; this run is `+1564 ~17` (net +32 from
intervening stages, still `-0`).

### 3.3 Release APK — recoverable backup, build, verification

**Previous APK preserved before overwrite (recoverable):**

| | |
|---|---|
| original path | `build/app/outputs/apk/release/app-release.apk` |
| original mtime | `2026-10-01 00:12:13.902466273 +0800` |
| original size | `123 108 211` bytes |
| original SHA256 | `1af486e7dec5c32ea1cc6ba487d2a4f1a1e3b60a3208d97fe381ca571610bdb3` |
| backup 1 | `build/apk-backup/app-release.apk.20261001T103722Z.pre-release` |
| backup 2 | `build/apk-backup/app-release.flutter-apk.apk.20261001T103722Z.pre-release` |
| backup SHA256 | **both identical to the original** (`sha256sum` verified, `BACKUP_EXIT=0`) → the old build is recoverable byte-for-byte |

**Fresh build** (`flutter build apk --release`, exit 0):

| field | value |
|---|---|
| mtime | `2026-10-01 18:39:34.245614764 +0800` (`apk/release`), `18:39:34.529623739` (`flutter-apk`) |
| size | `123 304 927` bytes — **both output paths identical** |
| SHA256 | `da07819c35432224d76c59f1c79541a61ad194c26b11cf35b757ca3e12f1768d` (both paths) |
| package | `com.antigravity.valhalla.valhalla` |
| version | `versionCode=1`, `versionName=1.0.0` |
| SDK | `minSdkVersion 24`, `targetSdkVersion 36`, `compileSdkVersion 36` |
| app label / icon | `valhalla` / `res/9w.png` |
| aapt exit | **0** — `/tmp/opencode/lmd5-apk-badging.log` |
| sha256 log | `/tmp/opencode/lmd5-apk-sha256.log` |

**Signing certificate** (`apksigner verify --print-certs`, exit **0**, build-tools 36.0.0):

```
Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
Signer #1 certificate SHA-256 digest: 2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9
Signer #1 certificate SHA-1 digest:   f0fb4ad6bd3dd2d9513a0573b40910adb4d288c2
Signer #1 certificate MD5 digest:     80633e7c14c1b64a11a6a8b9c874e60a
```

Log: `/tmp/opencode/lmd5-apk-certs.log`. **`CN=Android Debug` — this is the existing
debug signing, NOT store signing.** The APK must not be treated as a store artifact.

### 3.4 ADB — install -r, launch, log inspection

Target: the existing authorised `127.0.0.1:14251` (reconnected with `adb connect`,
`CONNECT_EXIT=0`). No uninstall, no `pm clear`, no data wipe, no unrelated device action.

**Device** (`adb devices -l`, exit 0):

```
127.0.0.1:14251   device product:sdk_gphone64_x86_64 model:sdk_gphone64_x86_64 device:emu64xa transport_id:1
```

**Pre-install state** — `/tmp/opencode/lmd5-adb-pre.log`:

```
versionCode=1 minSdk=24 targetSdk=36
versionName=1.0.0
lastUpdateTime=2026-10-01 00:11:57
signatures=PackageSignatures{74bbc1f version:2, signatures:[6e5dbc6], past signatures:[]}
firstInstallTime=2026-09-23 03:26:04
pid (pre): 19075
```

**Install** — `adb -s 127.0.0.1:14251 install -r build/app/outputs/apk/release/app-release.apk`
→ `Performing Streamed Install` / `Success` / **`install exit=0`**
(`/tmp/opencode/lmd5-adb-install.log`).

**Post-install state:**

| field | before | after | reading |
|---|---|---|---|
| `lastUpdateTime` | `2026-10-01 00:11:57` | `2026-10-01 18:40:19` | update applied |
| `firstInstallTime` | `2026-09-23 03:26:04` | `2026-09-23 03:26:04` | **unchanged → update-in-place, not a reinstall** |
| `signatures=` | `signatures:[6e5dbc6]` | `signatures:[6e5dbc6]` | **unchanged → user data preserved** |
| `dataDir` | — | `/data/user/0/com.antigravity.valhalla.valhalla` | present, not cleared |
| pid after install | 19075 | not running | old process reaped by the update (expected) |

**Launch** — `adb -s 127.0.0.1:14251 shell am start -n com.antigravity.valhalla.valhalla/.MainActivity`
→ `Starting: Intent { cmp=…/.MainActivity }`, **exit 0**
(`/tmp/opencode/lmd5-adb-launch.log`).

Observed afterwards:

| check | result |
|---|---|
| `resolve-activity --brief` | `com.antigravity.valhalla.valhalla/.MainActivity` |
| pid after launch | `26083` (`ActivityManager: Start proc 26083:com.antigravity.valhalla.valhalla/u0a196 for next-top-activity`) |
| `topResumedActivity` | `com.antigravity.valhalla.valhalla/.MainActivity` (task `t137`) |
| pid stability | still `26083` after a further 15 s (no crash/restart loop) |
| activity after wait | still `topResumedActivity = …/.MainActivity` |

**Log inspection** — `adb -s 127.0.0.1:14251 logcat -d -v time -T "10-01 18:40:27.000"`
(marker taken immediately before launch) → exit 0, 179 lines / 27 309 bytes,
`/tmp/opencode/lmd5-logcat.log`.

| scan | matches |
|---|---|
| `FATAL EXCEPTION` / `ANR in` / `am_anr` / `am_crash` / `beginning of crash` / `Force finishing` / `not responding` | **0** |
| `dumpsys activity processes \| grep -i 'anr\|not responding'` | **0** |
| E-level lines in the window | **2**, neither a crash: `E/lhalla.valhalla(26083): Not starting debugger since process cannot load the jdwp agent.` (benign ART notice in a release build) and `E/TaskPersister(9200): File error accessing recents directory` (system process, unrelated) |
| W-level lines for pid 26083 | **5**, all benign emulator notices (`Unexpected CPU variant for x86`, SELinux `max_map_count` avc denial, `OpenGLRenderer Unknown dataspace 0`, `Failed to initialize 101010-2 format … EGL_SUCCESS`) |

**Conclusion: observed crash/ANR = none.** Stated strictly as an *observation of this
launch window* — **no claim of real Agent acceptance, no claim of functional correctness
beyond what the automated gates prove.**

### 3.5 Explicitly NOT done / not claimed

- **no** product, UI, auth, business-logic or history edit — Stage 3 wrote only
  `test/features/live_models_stage2_widget_test.dart` and the gen-l10n outputs
- **no** commit, **no** push, all unrelated dirty changes preserved
- **no** real OAuth / browser authorization / inference / remote history / credentials
- **no** `--prompt-interactive` invocation
- **no** uninstall, **no** `pm clear`, no store signing, no second device touched
- **no** claim that the debug-signed APK is a store artifact
- **no** claim of real Agent acceptance on the device

### 3.6 Format-gate gap recheck (production/UI files)

Stage 3 §3.2 gate 2 covered only the test file. Re-run on the 10 task-touched
production/UI files, read-only (`--output=none --set-exit-if-changed`), both model roles
`opencode/mimo-v2.6-flash-free`, no writes / no tests / no build / no ADB:

```
dart format --output=none --set-exit-if-changed lib/core/providers/ai_chat_provider.dart \
  lib/infrastructure/acp/acp_client_adapter.dart lib/infrastructure/cli/codex_native_client.dart \
  lib/infrastructure/cli/codex_account_models.dart lib/infrastructure/cli/codex_model_authorization.dart \
  lib/data/models/chat_run_settings.dart lib/core/services/model_authorization_browser.dart \
  lib/features/chat/ai_chat_view.dart lib/features/chat/widgets/chat_run_settings_dialog.dart \
  lib/features/chat/widgets/chat_commands_skills_dialog.dart
```

**EXIT = 1**, `Formatted 10 files (3 changed) in 0.41 seconds.` — log
`/tmp/opencode/lmd7-production-format.log` (223 B).

**Exact affected files (not formatted yet):**

1. `lib/features/chat/ai_chat_view.dart`
2. `lib/features/chat/widgets/chat_run_settings_dialog.dart`
3. `lib/features/chat/widgets/chat_commands_skills_dialog.dart`

The other 7 files are already format-clean. No file was written by this recheck.

---

## STAGE 4 — close format gate (mechanical only) + re-verify + rebuild/reinstall

Root authorised `dart format` on exactly the three §3.6 files (formatting was delegated;
no UI/layout/semantic editing). Both model roles stayed `opencode/mimo-v2.6-flash-free`.
No new tests/features, no manual product edits, no uninstall/`pm clear`, no remote
OAuth/inference/history. All commands used direct redirection with `$?` captured
immediately.

### 4.1 Mechanical formatting

| step | exit | log |
|---|---|---|
| `dart format` (write) on the 3 files → `Formatted 3 files (3 changed) in 0.27s` | **0** | `/tmp/opencode/lmd8-format-write.log` |
| `dart format --output=none --set-exit-if-changed` on **all 10 production files + the 2 new test files** → `Formatted 12 files (0 changed) in 0.40s` | **0** | `/tmp/opencode/lmd8-format-check.log` |

Mechanically reformatted (formatting only — no semantic/UI/layout edit):

1. `lib/features/chat/ai_chat_view.dart`
2. `lib/features/chat/widgets/chat_run_settings_dialog.dart`
3. `lib/features/chat/widgets/chat_commands_skills_dialog.dart`

### 4.2 Re-verification gates

| # | command | exit | result | log |
|---|---|---|---|---|
| 1 | `flutter gen-l10n` | **0** | regenerated | `/tmp/opencode/lmd8-genl10n.log` |
| 2 | `flutter analyze --no-pub` | **0** | `No issues found! (ran in 4.2s)` | `/tmp/opencode/lmd8-analyze.log` |
| 3 | `flutter test --no-pub <6 focused files>` (same set as §3.2) | **0** | **`+70 ~0 -0`**, All tests passed | `/tmp/opencode/lmd8-focused.log` (22 811 B) |
| 4 | `flutter test --no-pub` (whole tree) | **0** | **`+1564 ~17 -0`**, All tests passed | `/tmp/opencode/lmd8-fulltests.log` (389 354 B) |

Full suite ran **after** the formatting and **before** the build.

### 4.3 APK — recoverable backup, rebuild, verification

Previous (Stage 3) APK preserved before overwrite — all four SHA256
`da07819c35432224d76c59f1c79541a61ad194c26b11cf35b757ca3e12f1768d`:

- `build/apk-backup/app-release.apk.20261001T105023Z.stage3`
- `build/apk-backup/app-release.flutter-apk.apk.20261001T105023Z.stage3`
- (plus the original pre-release backups from §3.3)
- log `/tmp/opencode/lmd8-backup.log`, `BACKUP_EXIT=0`

`flutter build apk --release` → **`BUILD_EXIT=0`**, `✓ Built …/flutter-apk/app-release.apk (123.3MB)`
(`/tmp/opencode/lmd8-build.log`).

| field | value |
|---|---|
| mtime | `2026-10-01 18:51:48.289057865 +0800` (`apk/release`), `18:51:48.561066609` (`flutter-apk`) |
| size | `123 304 927` bytes (both paths identical) |
| **SHA256** | **`1dfe9ab4e59b93e3234300ece10ec2cffcb2390ae584cda0732cbb728d4b0f35`** (both paths) |
| package / version | `com.antigravity.valhalla.valhalla`, `versionCode=1`, `versionName=1.0.0` |
| SDK / ABI | `minSdk 24`, `targetSdk 36`, `compileSdkVersion 36`; `arm64-v8a armeabi-v7a x86_64` |
| aapt | exit **0** — `/tmp/opencode/lmd8-apk.log` |
| cert | `apksigner` exit **0**, `C=US, O=Android, CN=Android Debug`, SHA-256 `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` — **debug signing, not store signing** (`/tmp/opencode/lmd8-certs.log`) |

### 4.4 Reinstall `install -r` + launch + latest-window log

Device `127.0.0.1:14251` (`device`, `sdk_gphone64_x86_64` / `emu64xa`).

| | pre-install | post-install |
|---|---|---|
| `lastUpdateTime` | `2026-10-01 18:40:19` | `2026-10-01 18:52:10` |
| `firstInstallTime` | `2026-09-23 03:26:04` | `2026-09-23 03:26:04` (**unchanged → update-in-place**) |
| `signatures=` | `signatures:[6e5dbc6]` | `signatures:[6e5dbc6]` (**unchanged → data preserved**) |
| `dataDir` | — | `/data/user/0/com.antigravity.valhalla.valhalla` |

`adb -s 127.0.0.1:14251 install -r build/app/outputs/apk/release/app-release.apk` →
`Performing Streamed Install` / `Success` / **`INSTALL_EXIT=0`**
(`/tmp/opencode/lmd8-adb-pre.log`, `/tmp/opencode/lmd8-adb-install.log`).

`am start -n com.antigravity.valhalla.valhalla/.MainActivity` → **`AMSTART_EXIT=0`**;
`Start proc 26523 … for next-top-activity`; `topResumedActivity = …/.MainActivity t138`;
pid still `26523` after a further 15 s (`/tmp/opencode/lmd8-adb-launch.log`).

Log window `adb logcat -d -v time -T "10-01 18:52:25.000"` → exit 0, 186 lines / 28 127 B
(`/tmp/opencode/lmd8-logcat.log`):

| scan | matches |
|---|---|
| `FATAL EXCEPTION` / `ANR in` / `am_anr` / `am_crash` / `beginning of crash` / `Force finishing` / `not responding` | **0** |
| `dumpsys activity processes \| grep -i 'anr\|not responding'` | **0** |
| E-level | **2**, both benign (`Not starting debugger … jdwp` for pid 26523; system `TaskPersister`) |
| W-level for pid 26523 | **5**, all benign emulator/OpenGL/SELinux notices |

**No observed crash/ANR in the latest window** — an observation only; no claim of real
Agent acceptance, no store signing, no real OAuth/inference/remote history.

---

**Stage 1 status: GREEN. Stage 2 status: GREEN. Stage 3 status: GREEN. Stage 4 status:
GREEN** — format gate closed (12/12 files clean), analyze 0 issues, `+70` focused,
`+1564 ~17` full, rebuilt APK `1dfe9ab4…0f35` at `18:51:48`, reinstalled `install -r`
(18:52:10, data preserved), launched without observed crash/ANR.


