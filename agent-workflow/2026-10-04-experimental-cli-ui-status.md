# AgY UI Status: Opt-in Experimental CLI Chat

## Identity Verification
- **Conversation ID**: `ec81a4be-7543-45ee-8658-f68966f57d3b` (Original Valhalla session)
- **Model**: `gemini-3.8-flash-high` (effort: high)
- **Status**: UI Implementation Complete & Ready for OpenCode Verification

---

## Changes Implemented

### 1. Localization (`lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`)
- Added stable ARB keys for experimental features in English and Simplified Chinese:
  - `settingsExperimentalFeatures`: "Experimental Features" / "实验性功能"
  - `settingsExperimentalFeaturesDesc`: "Try preview and experimental capabilities" / "体验处于预览或测试阶段的实验性功能"
  - `settingsExperimentalCliChatTitle`: "CLI Smart Chat" / "CLI 智能对话"
  - `settingsExperimentalCliChatDesc`: "Enable dedicated command-line agent chat interface" / "开启独立的命令行 Agent 对话界面"
  - `settingsExperimentalDialogClose`: "Close" / "关闭"
  - `settingsExperimentalSaveFailed`: "Failed to update experimental feature settings" / "更新实验性功能设置失败"
- Adhered strictly to instruction: no manual edits to generated Dart files; `flutter gen-l10n` is left for OpenCode.

### 2. Settings View (`lib/features/settings/settings_view.dart`)
- **Experimental Features Card & Dialog**:
  - Added Experimental Features entrance (`Key('settings_experimental_features_tile')`) under Settings.
  - Implemented M3 `AlertDialog` (`Key('settings_experimental_features_dialog')`):
    - Constrained height and width (`BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7, maxWidth: 400)`) with `SingleChildScrollView` for 320dp/2x accessibility.
    - Checkbox list tile (`Key('settings_experimental_cli_chat_tile')`) bound to `settings.enabledExperimentalFeatures.contains(ExperimentalFeature.cliChat)`.
    - Loading indicator displayed while persisting via `setExperimentalFeature`.
    - Disables interaction while `_isSaving` is active to prevent duplicate requests.
    - Captures storage/persistence exceptions with inline localized error message.
    - Close button with `Key('settings_experimental_dialog_close_button')`.
- **Navigation Configuration Gating & Slot Preservation**:
  - Startup page tile displays `settings.effectiveStartupSection` icon and localized name.
  - Startup page dialog options filtered by `settings.availableSections`.
  - Dashboard Quick Actions reordering and candidates:
    - Reorder operates on `settings.visibleDashboardQuickSections`.
    - Candidates list filtered by `settings.availableSections.where((s) => s != AppSection.dashboard)`.
    - Updates routed through `notifier.setVisibleDashboardQuickSections` to preserve hidden configured slots.
  - Mobile Bottom Navigation reordering and candidates:
    - Reorder operates on `settings.visibleBottomNavigationSections`.
    - Candidates list filtered by `settings.availableSections`.
    - Updates routed through `notifier.setVisibleBottomNavigationSections` to preserve hidden configured slots.

### 3. Shell Navigation (`lib/features/shell/main_shell.dart`)
- **Startup & Fallback**:
  - `initState`: initializes `_currentIndex` using `ref.read(settingsProvider).effectiveStartupSection`.
  - `ref.listen<SettingsState>(settingsProvider)`: detects when CLI chat is disabled while user is on CLI view (index 8) and immediately redirects to dashboard (index 0). Normal settings updates do not trigger unnecessary tab switches.
  - `_navigateToSectionIndex`: guards dashboard onNavigate callbacks against disabled sections.
- **Offstage Mount Prevention**:
  - Replaced static `_views` with `_buildViews(bool isCliChatEnabled)`.
  - At stable index 8, mounts `const SizedBox.shrink(key: Key('cli_chat_disabled_placeholder'))` when CLI chat is disabled, preventing offstage initialization and session creation.
  - Preserves NAS Media View at stable index 9.
- **Drawer**:
  - Iterates over `ref.watch(settingsProvider).availableSections`.
  - Hides `drawer_cli_chat_tile` when CLI is disabled; shows when enabled.
- **Desktop & Tablet NavigationRails**:
  - Filters rail destinations using `ref.watch(settingsProvider).availableSections`.
  - `onDestinationSelected`: maps visible rail position to stable view index via `appSectionToViewIndex(visibleSections[index])`.
  - `selectedIndex`: maps `_currentIndex` to visible rail position via `visibleSections.indexOf(currentSection)`.
  - Prevents the NAS destination index regression when CLI is filtered out.
- **Mobile Bottom Navigation**:
  - Passes `settings.visibleBottomNavigationSections` to `MainBottomNavigationBar`.

### 4. Dashboard View (`lib/features/dashboard/dashboard_view.dart`)
- Updated `quickSections` calculation to consume `ref.watch(settingsProvider).visibleDashboardQuickSections`.

---

## Non-Execution Boundary
- Confined all edits strictly to:
  - `lib/l10n/app_en.arb`
  - `lib/l10n/app_zh.arb`
  - `lib/features/settings/settings_view.dart`
  - `lib/features/shell/main_shell.dart`
  - `lib/features/dashboard/dashboard_view.dart`
  - `agent-workflow/2026-10-04-experimental-cli-ui-status.md`
- No tests, analysis, formatting, generation, builds, ADB, git mutations or remote actions executed. Read-only git status/diff were used during inspection.
- Ready for OpenCode to perform mechanical gen-l10n, test authoring & execution, analyze, and APK build.
