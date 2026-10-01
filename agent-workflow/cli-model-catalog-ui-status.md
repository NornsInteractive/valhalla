# AgY UI Implementation Report — 2026-10-01 (CLI Model Catalog & Manual Model Selection)

- **Status**: **UI READY** (UI integration complete; release remains blocked until OpenCode completes verification of pending backend acceptance)
- **Conversation**: Original Valhalla `ec81a4be-7543-45ee-8658-f68966f57d3b`
- **Model**: Gemini 3.8 Flash (High) (`gemini-3.8-flash-high`), high reasoning effort
- **Directory**: `/workspace/projects/valhalla`

## Whitelisted Files Modified
1. `lib/features/chat/ai_chat_view.dart`
2. `lib/features/chat/widgets/chat_run_settings_dialog.dart`
3. `lib/l10n/app_en.arb`
4. `lib/l10n/app_zh.arb`
5. `agent-workflow/cli-model-catalog-ui-status.md` (this report)

## Exact UI Implementation Details

1. **Removed ACP Authorization Wiring (`ai_chat_view.dart`)**:
   - Removed `onAuthorize` and `onCancelAuthorize` callbacks from `ChatRunSettingsDialog.show(...)`.
   - Removed unused `isCodex` logic and removed unused imports:
     - `lib/core/services/model_authorization_browser.dart`
     - `lib/data/models/native_cli_session.dart`
   - Retained all existing model refresh, metadata fetching, target guards (`dialogServerId` / `dialogAgentId`), and async `onSave` logic.

2. **Dialog Backward Compatibility (`chat_run_settings_dialog.dart`)**:
   - Retained optional `onAuthorize` and `onCancelAuthorize` parameters in `ChatRunSettingsDialog` constructor and `show()` method.
   - When no authorization callbacks are provided (`widget.onAuthorize == null`), no authorization buttons, confirmation dialogs, or in-flight progress cards are rendered.

3. **Manual Model Name & Source Choice (`chat_run_settings_dialog.dart`)**:
   - Integrated `SegmentedButton<bool>` to allow choosing between "Model List" (`customModel: false`) and "Manual Input" (`customModel: true`).
   - If `customModel: true`, displays an editable `TextField` (`Key('chat_run_settings_custom_model_input')`) with localized hint and warning explaining manual models are unverified and may be rejected by the remote agent runtime.
   - Manual input is fully available even when `caps.models` is empty.
   - On save: validates that manual model name is non-empty, <=256 characters, and contains no whitespace or control characters. Saves `modelId: customText, customModel: true`.
   - On catalog selection: saves selected catalog model with `customModel: false`.
   - Preserves manual model values across reopen and manual refresh without creating synthetic catalog entries or resetting to catalog defaults.

4. **Updated Catalog & Error Localization (`app_en.arb` & `app_zh.arb`)**:
   - Updated `chatSettingsIndependentModelUnavailable`, `chatSettingsModelCatalogNote`, and `chatModelCatalogError403` to reflect CLI app-server queries, existing CLI authentication, possible version/cache limits, and the option to input a model manually.
   - Added localized strings for manual model selection:
     - `chatRunSettingsModelSourceCatalog`
     - `chatRunSettingsModelSourceCustom`
     - `chatRunSettingsCustomModelHint`
     - `chatRunSettingsCustomModelNotice`
     - `chatRunSettingsCustomModelEmptyError`
     - `chatRunSettingsCustomModelInvalidError`

5. **Neutral Localization Copy Revisions (`app_en.arb` & `app_zh.arb`)**:
   - `chatRunSettingsCustomModelHint`: Removed concrete model examples (e.g. `gpt-4o`) in favor of neutral copy: `"Enter model ID"` / `"输入模型ID"`.
   - `chatModelCatalogError403`: Avoided asserting that login lacks permissions (as 403 root causes include service, network, or authentication), updated to neutral: `"CLI model query access denied (403). Check CLI login and service connectivity, or enter a model name manually."` / `"CLI模型查询被拒绝(403)。请检查CLI登录和服务连通性，或手动输入模型名。"`.

## Remaining Blockers / Verification
- Release remains blocked pending OpenCode verification of backend acceptance.
- OpenCode owns and will execute `flutter gen-l10n`, `flutter format`, `flutter analyze`, and unit/widget test suites.
- AgY did not run tests, formatting, localization generation, builds, or ADB commands.
