# CLI model catalog instead of separate authorization — 2026-10-01

Current gate: original AgY UI READY; root reviewed implementation and verified
original conversation forwarding. Business + UI verification still pending.
Root authorizes gen-l10n/targeted formatting/widget tests/full tests/analyze and,
ONLY after all green, new release build + existing ADB install as below.

User explicitly supersedes the previous HTTP/OAuth catalog approach: use CLI.
Business default agentModelQueryProvider now calls existing
CodexNativeClient.queryCapabilities: selected host/container/user -> short-lived
codex app-server -> initialize/initialized -> model/list with pagination -> close.
No thread/start/read/resume or prompt, no browser OAuth or extra account permission.
Uses the CLI's existing login/configuration; no credentials copied or changed.
Manual refresh queries again; failure preserves stale catalog and permissions.
Existing ACP model-support validation and draft skills/commands stay unchanged.
CLI catalog can be bundled/cached; never label it guaranteed cloud latest/access.
Official reference: https://learn.chatgpt.com/docs/app-server (model/list).

## UI handoff — only original Valhalla

AgY original ec81a4be-7543-45ee-8658-f68966f57d3b only,
gemini-3.8-flash-high, effort high. Plain interactive console; never
--prompt-interactive or new conversation. Root cannot edit UI.

Whitelist: lib/features/chat/ai_chat_view.dart,
lib/features/chat/widgets/chat_run_settings_dialog.dart,
lib/l10n/app_en.arb, lib/l10n/app_zh.arb,
agent-workflow/cli-model-catalog-ui-status.md.
Remove ACP run-settings onAuthorize/onCancelAuthorize wiring and now-unused
browser/target-specific locals/imports ONLY when genuinely no longer used.
Keep dialog reusable optional authorization API untouched (tests/other callers
compatible); with no callback it must show no authorize/login/confirm/wait controls.
Keep existing model refresh, loading, error/empty, permissions and target guards.
Update relevant model empty/note/403 strings so they do not claim live/latest
cloud data or instruct a separate model authorization. Explain CLI current catalog,
existing CLI login, possible version/cache limits and manual refresh.
No unrelated layout or cleanup. No business/test/format/build/ADB/auth commands.
Write short UI READY report with exact original conversation/model/files.

User addition: allow manual model name in the shared run-settings dialog (ACP
and CLI callers). ChatRunSettings now has customModel bool default false,
copyWith/toJson/fromJson retain it; legacy JSON remains false, no destructive DB
migration. Add a clear localized choice manual/list, editable model name field
available even with empty catalog. Save trimmed nonempty <=256-char ID with no
whitespace/control chars and customModel:true; list/default saves false. Preserve
manual value across reopen/refresh even when absent from catalog. Do not create
fake catalog entries or auto-change it. Manual IDs are unverified; explain remote
agent may reject them. Root allows manual ONLY model values through declared ACP
model config RPC; other choice validation unchanged, remote must confirm exact
currentValue or ACP_CUSTOM_MODEL_NOT_CONFIRMED. Invalid IDs ->
ACP_CUSTOM_MODEL_INVALID; no model-setting API -> explicit unavailable. Keep
standard absent-list saved values resetting as before when customModel:false.
Reuse shared dialog for CLI, no separate page/input framework. No root UI edits.

## OpenCode verification and release

All test edits/execution/format/gen-l10n/analyze/build/ADB by OpenCode,
main/small opencode/mimo-v2.6-flash-free; free fallback only as previously allowed
if unavailable. No real inference, OAuth, credentials or remote history mutation.
Prove DEFAULT provider invokes CLI initialize/model/list and no HTTP/OAuth;
reuse existing protocol fake rather than override the provider under test.
Check target Docker/user, pagination/close/error/stale, no chat creation;
actual ACP view no authorization button, refresh and model controls preserved.
Prove old JSON/custom flag round-trip, manual empty/list/refresh/reopen, manual
model only RPC override, server rejection/unconfirmed value/no model API, and
list-selected stale models still rejected. No change to reasoning/permissions.
First-send regression uses the initial model config already emitted by
session/new; do not inject a legacy-model notification AFTER the entire send
has completed and label it initialization. A real later remote model change
must remain authoritative; that is not lost draft intent. Never weaken that.
Keep optional reusable dialog authorization tests valid.
UI READY gate required before release. Focused/full tests, zero-issue analyze,
format touched files, gen-l10n. If green back up current APK recoverably, build
fresh release, verify hash/time/size/package/cert, adb install -r existing
127.0.0.1:14251 without uninstall/clear, launch/current log crash/ANR check.
Report agent-workflow/cli-model-catalog-verification.md then stop.
No git commit/push, preserve dirty tree and any previous separate auth data.
