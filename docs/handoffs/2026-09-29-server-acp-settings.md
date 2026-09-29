# Server switching and ACP settings / streaming

UI executor: ONLY historical Valhalla agy conversation ec81a4be-7543-45ee-8658-f68966f57d3b, gemini-3.8-flash-high, effort high. Main agent owns core/data/infrastructure. OpenCode opencode/mimo-v2.6-flash-free owns ALL tests, analysis, formatting, builds and ADB. Do not run these yourself.

## UI whitelist

- lib/features/shell/main_shell.dart
- lib/features/servers/server_form_dialog.dart
- lib/features/chat/ai_chat_view.dart
- lib/features/chat/widgets/chat_run_settings_dialog.dart
- lib/features/chat/widgets/chat_run_settings_strip.dart
- lib/l10n/app_en.arb and lib/l10n/app_zh.arb

Preserve unrelated work. No business/provider modifications. No dependency changes. No tests (OpenCode owns them).

## Required behavior

Server picker: remove duplicate selectServer call (handler already selects), guard async connect flow after credentials/dialogs against target switch/deletion, catch selection/delete errors and show localized actionable feedback, prevent repeated delete clicks, preserve deletion confirmation. Server editor delete must show progress/error and stay open on failure. Do not auto-connect after deletion. Provider APIs unchanged.

ACP composer: keep horizontal model / reasoning / permissions strip above input. Before opening settings call await ref.read(aiChatProvider.notifier).prepareRunSettings(); then read fresh state, mounted/identity guard. prepareRunSettings returns Future<bool>, false on error/auth challenge. It may create remote draft session but no local history until first send. AiChatState gains isLoadingSettings and isApplyingSettings; disable duplicate requests/send during either and remote setting changes during generation. updateRunSettings remains Future<void>, errors throw and lastErrorCode contains reason; catch and keep settings dialog open on failure. Make settings dialog optional async onSave callback so CLI remains backward compatible; only pop after successful save. AgentRuntimeCapabilities gains modes, currentModelId/currentReasoningId/currentModeId, extraSettings. ChatRunSettings gains modeId (copyWith clearMode), configValues Map<String,Object>. Extra setting has id,label,currentValue,Object,options List<ChatSettingOption>,isBoolean. Support dropdowns/toggles for extras. For ACP use remote current values; do not offer an ambiguous null/default reset after session exists. Model changes can invalidate reasoning: saving applies model first, refresh options; invalid reasoning gives error and fresh capabilities; allow reopen/refresh without losing current remote settings.

Permissions section: distinguish remote Agent mode from local approval policy. Display advertised modes and current mode; no hardcoded unsupported options. Existing local askEveryTime/autoAllowSafe/autoAllowAll retained with explicit all-actions confirmation. Explain safe mode asks whenever operation safety cannot be determined. No privilege labels inferred from mode names.

Streaming: preserve selection/copy behavior. Follow bottom only while user already near bottom; user scrolling up must not be dragged down; resume when user returns to bottom. Rendering must remain lazy for long history; don't rebuild entire history per token. Handle thinking/tool/permission/auth/loading/error states and allow cancellation; copy includes final streamed text.

Report changed files and actual work only; main agent reviews, OpenCode verifies. Keep both locales complete.
