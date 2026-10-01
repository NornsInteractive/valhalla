# Independent catalog UI adjustment (AgY only)

Only original Valhalla conversation ec81a4be-7543-45ee-8658-f68966f57d3b; Gemini 3.8 Flash high.
Preserve dirty work. Allowed: lib/features/chat/widgets/chat_run_settings_dialog.dart, lib/l10n/app_en.arb, lib/l10n/app_zh.arb ONLY. No other files, no tests/format/analyze/build commands (OpenCode owns verification).

Business change: ACP model options now come from independent agentModelQueryProvider, not existing sessions. Refresh does not resume/recreate ACP session. Current model id can still come from established session, and may no longer exist in independent catalog. Missing independent endpoint => empty models with stale metadata, not 'available after first send'. Interface query time does not guarantee cloud freshness. Inference still ACP; account/skills/commands unchanged.

Minimal UI tasks:
1. At init and refresh, selected model must be null/default OR an actual caps.models id. If initial/current model is absent from catalog do NOT reuse that invalid id as dropdown value; use null ('agent default') if supported, otherwise actual first catalog entry. Do not apply/send automatically just opening/refreshing.
2. Empty model catalog must not promise sending first message will fetch models. Add dedicated localized independent-model-unavailable text if current shared settings-after-first-message key also governs reasoning/modes. Keep other controls unchanged.
3. Add concise localized note in ACP settings explaining models are provided by agent query interface and it may cache its catalog; no guaranteed current account entitlement. Existing fetched-at label means last query time, not cloud update time. Avoid UI redesign.
4. Model query failure retains old catalog marked stale, empty catalog disables model selection; refresh remains actionable.

Do not change business logic or UI elsewhere. Report exact files changed and stop. OpenCode will generate localization, format and verify after your work.
