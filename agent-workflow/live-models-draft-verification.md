# Live models + ACP drafts — verification report (2026-10-01)

Operator: OpenCode (inline, no delegation). Model: `opencode/mimo-v2.6-flash-free` (main + small, local metadata cost 0).
Scope authority: `agent-workflow/live-models-draft-tests.md` (23-line version, re-read immediately before final gates).

## 1. Final gate results

| # | Command | Exit | Result |
|---|---|---|---|
| 1 | `dart format --output=none --set-exit-if-changed lib/core/providers/ai_chat_provider.dart lib/infrastructure/acp/acp_client_adapter.dart lib/infrastructure/cli/codex_native_client.dart lib/infrastructure/cli/codex_account_models.dart lib/infrastructure/cli/codex_model_authorization.dart lib/data/models/chat_run_settings.dart` | **0** | `Formatted 6 files (0 changed)` |
| 2 | `flutter analyze --no-pub` | **0** | `No issues found!` (ran in 2.9s) |
| 3 | `flutter test --no-pub` (focused, 14 files) | **0** | `+194` — `All tests passed!` |
| 4 | `flutter test --no-pub` (full suite) | **0** | `+1495 ~17 -0` — `All tests passed!` (01:19, log `/tmp/opencode/lmd-fulltests.log`) |

Baseline measured at session start (same tree, before test edits): `flutter test --no-pub` → exit **1**, `+1442 ~17 -5`. All 5 failures were stale contract assertions in `test/core/independent_model_query_test.dart`.

Delta: **1442 → 1495 passing (+53)**, 17 skipped unchanged, **5 → 0 failing**.

No production source was edited by OpenCode. `dart format` was run only on the 6 approved files; the final pre-report check reported **0 changed**. (An earlier formatter pass in this session reflowed the approved set; root subsequently rewrote those files at 14:27 adding braces — see handoff line 23.)

## 2. Test edits (test/** only)

| File | Status | Tests |
|---|---|---|
| `test/core/independent_model_query_test.dart` | updated | 24 |
| `test/infrastructure/codex_account_models_test.dart` | new | 15 |
| `test/infrastructure/codex_composer_skills_test.dart` | new | 6 |
| `test/infrastructure/codex_model_authorization_security_test.dart` | new | 17 |
| `test/infrastructure/acp_initialize_coalescing_test.dart` | new | 3 |

41 tests in the 4 new files; 7 added to the updated file (17 → 24). The 48 added tests plus 5 previously failing tests now passing account for the +53 passing delta. All new tests use manual fakes, `FakeAcpPair`, an in-memory `SSHSession` fake and the local loopback `HttpServer` — **no real SSH, no real HTTP(S) outbound, no Node execution, no real credentials, no OAuth**.

### 2.1 The 5 stale contract tests — updated, proof preserved

| Old assertion (failed) | New assertion |
|---|---|
| `lastErrorCode == 'AGENT_MODEL_QUERY_UNSUPPORTED'` | `modelCatalogError == 'AGENT_MODEL_QUERY_UNSUPPORTED'`, `lastErrorCode` **null** (catalog failure must not block settings/permissions), `settingsStale` true, plus explicit `session/load`+`session/resume`+`session/prompt` absence |
| catalog model applied via `set_config_option` while ACP did not advertise it | split into two: **(a)** ACP-advertised → `set_config_option` sent and protocol-confirmed; **(b)** not advertised → `setConfigOptionRequests` **empty** + `StateError('ACP_MODEL_NOT_SUPPORTED_BY_ADAPTER')` + no optimistic `runSettings` write |
| agent rejects → fall back | now the model **is** ACP-advertised, so `rejectedConfigValues` path is actually exercised → `runSettings.modelId` stays `legacy-model` |
| `prepareRunSettings(refresh:true) == false` + `lastErrorCode` | returns **true**, `modelCatalogError` carries the message, `settingsFetchedAt` retained, `settingsStale` true, no session ops; then a successful refresh **clears** the error |
| first send sends `set_config_option` for a catalog-only model | **(a)** ACP-advertised saved model → RPC sent + confirmed; **(b)** catalog-only → no RPC + `ACP_MODEL_NOT_SUPPORTED_BY_ADAPTER`; **(c)** *new* independent HTTP failure → still applies the ACP-advertised saved setting (`legacy-model`), `modelCatalogError` set, prompt still sent |

### 2.2 New coverage added this run

- **Contract 1 — `CodexAccountModels`**: `parse` order/dedup/`visibility==list`/empty-slug/missing-`display_name`; API-key `data[]` never mistaken for the account catalog (`AGENT_MODEL_INVALID_RESPONSE`); `ModelCatalogQueryException.toString()` is the fixed code only (no body/token); `accountKey` accepted only as 64-hex. `query` over a fake SSH channel: banner skipping, 2 MiB ceiling, non-zero exit, no-JSON-line, stdout error — every path closes the channel and cancels stderr. `command()`: base64-inlined script, no plaintext endpoint/`Bearer` in the shell command, decoded script contains the fixed `api.openai.com/v1/models` and **no** `session/`, `thread/`, `app-server` strings; host vs docker shell target.
- **Contract 3 — `skills/list`**: nested `data[].skills[]`, `enabled==false` filtered, `interface.displayName` used, cross-bundle dedup, `name→id→skill` fallback, empty id dropped, legacy flat `data[]` tolerated, `forceReload: true` + `cwds: [cwd]`, no `cwds` when cwd absent, `commands` stays empty (no invented TUI commands), wire call list contains no `thread/list`/session method, `AGENT_SKILLS_INVALID_RESPONSE` for non-list/missing `data`.
- **Contract 4**: no-RPC + explicit `ACP_MODEL_NOT_SUPPORTED_BY_ADAPTER` proven on **both** the settings-dialog path and the first-send path; ACP-advertised successful application; independent-HTTP-failure fallback to the ACP-advertised saved setting; no silent model invention.
- **Contract 6 (Dart side)**: `credentialKey` = sha256(`serverId::id`), isolated per server **and** per agent; `remoteCommand` host (`bash -l -c`) vs docker (`docker exec`) target; script base64-inlined so nothing readable reaches the process list; `authorize()` with fake SSH: non-`https`/non-`auth.openai.com` URL ⇒ browser **never** opened; remote fixed codes passed through (`AGENT_MODEL_AUTH_DECLINED`, `AGENT_MODEL_AUTH_BUSY`) and unknown strings folded to `AGENT_MODEL_AUTH_FAILED`; **early cancel** ⇒ channel closed, browser never opened; **late cancel** ⇒ loopback callback accepted exactly once (200), replayed and wrong-state rejected (400), only one `callbackUrl` forwarded, then cancellation closes SSH channel **and** loopback listener; success path ⇒ exactly one browser call and one `redirectUri` line (no tokens); stdout stream failure ⇒ `AGENT_MODEL_AUTH_FAILED`.
- **Handoff line 15 regression**: concurrent `initializeOnly()` coalesces to a **single** `initialize` handshake, sequential calls too, and a disposed adapter rejects late `initializeOnly()`/`prepareSession()` with `ACP_DISCONNECTED` while never creating a session.
- **Handoff line 17**: 4 tests for the `catalogAccountKey` cache-isolation branch — success writes the key; ordinary same-account failure **retains** catalog + `fetchedAt` + stale + error accounting; changed account key clears catalog **and** `fetchedAt`; `AGENT_MODEL_ACCOUNT_MISMATCH` / `AGENT_MODEL_AUTH_UNAVAILABLE` clear even with an unchanged key; fixed code only, no session/prompt triggered.

## 3. UNMET acceptance conditions (explicit)

1. **Embedded OAuth JS is statically asserted only — NOT executed.** Every contract-6 runtime guarantee (JWKS RS256 signature/issuer/audience/azp/expiry/nonce/subject, state+PKCE exchange, declined/missing plan grant, expiry + rotating-refresh serialization under the exclusive lock, mode-0600 atomic writes, non-owner/world-readable/symlink rejection, post-lock subject/account/scope revalidation, **failed exchange after account switch must not relabel old tokens**) is verified by **string assertions on `CodexModelAuthorization.runtime` / the authorize flow captured from `remoteCommand`**, plus Dart-side orchestration tests. **No mocked JWKS verification, no mocked refresh round-trip, no account-rebinding execution proof exists. Security and real authorization are NOT verified.**
2. **Real authorization never exercised** — no OAuth, no live account inference, no token read (handoff prohibition honoured).
3. **Real model catalog unverified** — no live `GET api.openai.com/v1/models` was performed; handoff notes the earlier local Codex GET returned HTTP 403 with cause unknown. Fresh catalog unconfirmed.
4. **Docker execution path unverified** — `docker exec` command construction is asserted, but no container was actually targeted; **-32603 diagnostics under a real Docker agent are unverified.**
5. **Contract 5 has no new coverage.** The `session/new|session/resume|session/load` vs `session/set_config_option <configId>` distinction in `-32603` mapping (`ACP_SESSION_PREPARE_FAILED: …` vs `ACP_SETTING_APPLY_FAILED: …`) still has no test; existing suites only cover the prompt-path `-32603` (`acp_adapter_test.dart`) and "no new-session fallback on load/resume failure" (`acp_session_resume_test.dart`). `FakeAcpPair` also has no `-32603` knob.
6. **Contract 3 is only half-covered.** `prepareComposerCatalog` itself (draft with no session, injectable `agentComposerQueryProvider`, target isolation, `$skills` merged with protocol commands, no replacement by a later `ACPCommandsChangedEvent`, cwd plumbing) has **zero** tests, as do the CLI caller (`CliChatNotifier.refreshComposerCatalog`) and **"skills failure must not block ordinary send"** (handoff line 15).
7. **Contract 4 gaps**: draft `updateRunSettings` saving only (no RPC) and model-then-reasoning ordering / reasoning re-filtering against refreshed options are not directly asserted.
8. **Auth-store permission/symlink rejection and unsafe profile-dir rejection** (handoff line 15) are static-string assertions only, not executed against real filesystem modes.
9. **No executable proof that the phone never receives tokens over a real channel** beyond the fake-SSH string check.

## 4. Explicitly NOT done (per instruction)

- **No UI edits.** UI remains **BLOCKED** — AgY conversation mismatch; AgY original session could not be preserved.
- **No build, no APK deletion, no ADB install** until root provides UI READY + final gate authorization.
- **Existing APK preserved untouched**: `build/app/outputs/flutter-apk/app-debug.apk` (Sep 29), `app-profile.apk` (Sep 19), `app-release.apk` (Oct 1 00:12) — no mtime change, `git status` shows 0 APK/build entries.
- No production semantics changed; no auth files/tokens read or exported; no remote Codex session created/sent/read; history unchanged.

## 5. Production observations for root

- No production **defect** found this run. The 5 failing tests were stale expectations, now realigned (root's semantics match contracts 2 and 4).
- A transient analyzer snapshot mid-run reported 15 `curly_braces_in_flow_control_structures` infos across `ai_chat_provider.dart`, `codex_account_models.dart`, `codex_model_authorization.dart`; root added the braces at 14:27 and the final `flutter analyze --no-pub` is **0 issues**. The two test-file lints from that run were fixed by OpenCode (`prefer_interpolation_to_compose_strings`, `annotate_overrides` in `codex_account_models_test.dart`).
- Cosmetic only, no action required: the generic `catch (_)` in `CodexModelAuthorization.authorize`'s stdout listener (around `lib/infrastructure/cli/codex_model_authorization.dart:281-283`) collapses a deliberately thrown `AGENT_MODEL_ENDPOINT_INVALID` into `AGENT_MODEL_AUTH_FAILED`. Both are fixed codes and the browser is still not opened (asserted), so this is a lost diagnostic, not a security hole.

## 6. Model / environment

- Model: `opencode/mimo-v2.6-flash-free` (main + small), local metadata cost 0.
- Flutter 3.44.2 / Dart 3.10, `/opt/flutter/bin`. `dart_test.yaml` absent; suite run with `flutter test --no-pub`.
- Existing unrelated dirty changes preserved. OpenCode edited `test/**` and this report, and formatted the explicitly approved production files without changing their semantics.
