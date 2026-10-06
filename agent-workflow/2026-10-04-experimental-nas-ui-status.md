# AgY UI Status: Opt-in Experimental NAS Media

## Identity & Environment
- **Conversation ID**: `ec81a4be-7543-45ee-8658-f68966f57d3b` (Original Valhalla conversation)
- **Model**: `gemini-3.8-flash-high` (effort: high)
- **Status**: UI Implementation Complete & Ready for OpenCode Verification

---

## Whitelist Changes Implemented

### 1. Localization (`lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`)
- Added stable ARB keys for NAS experimental feature in English and Simplified Chinese:
  - `settingsExperimentalNasTitle`: "NAS Media" / "NAS 媒体库"
  - `settingsExperimentalNasDesc`: "Enable media library, scan folders, and audio playback" / "开启媒体库、目录扫描与音频播放功能"
- Preserved existing CLI experimental keys and standard localization formatting.
- Did not manually edit generated Dart files; `flutter gen-l10n` is deferred to OpenCode.

### 2. Settings View (`lib/features/settings/settings_view.dart`)
- **NAS Checkbox in Experimental Dialog**:
  - Added `CheckboxListTile` with key `Key('settings_experimental_nas_tile')` directly inside `_ExperimentalFeaturesDialog`.
  - Checked state bound to `settings.enabledExperimentalFeatures.contains(ExperimentalFeature.nas)`.
  - Persistence handled via `ref.read(settingsProvider.notifier).setExperimentalFeature(ExperimentalFeature.nas, checked)`.
  - Shared saving guard (`_savingFeature`) protects both CLI and NAS checkboxes from double-tap while either is saving.
  - Individual circular progress indicator shown for the actively persisting feature.
  - Local error handling catches persistence failure and displays localized inline error feedback.
  - Both experimental features default to off (`false`).

### 3. Shell Navigation & Offstage Protection (`lib/features/shell/main_shell.dart`)
- **Shared `_buildViews` Helper**:
  - Updated `_buildViews(SettingsState settings)` to check both CLI and NAS:
    - At stable index 8: renders `const CliChatView()` when CLI enabled, or `const SizedBox.shrink(key: Key('cli_chat_disabled_placeholder'))` when disabled.
    - At stable index 9: renders `const NasMediaView()` when NAS enabled, or `const SizedBox.shrink(key: Key('nas_disabled_placeholder'))` when disabled.
  - Applied `_buildViews(settings)` across all three responsive shell variants (`_buildExpandedDesktopShell`, `_buildMediumRailShell`, `_buildCompactMobileShell`).
  - Completely prevents `NasMediaView` offstage mounting and prevents automatic DB/source scans on default startup.
- **Generalized Current-Disabled Fallback**:
  - Updated `ref.listen<SettingsState>(settingsProvider)`:
    ```dart
    final currentSection = viewIndexToAppSection(_currentIndex);
    if (!next.isSectionEnabled(currentSection)) {
      setState(() {
        _currentIndex = appSectionToViewIndex(AppSection.dashboard);
      });
    }
    ```
  - Automatically redirects to dashboard (index 0) if settings disable whichever section is currently active (CLI chat or NAS).
  - Unrelated settings changes or enabling features do not trigger unwanted tab changes.
- **Audited Selectors & Navigation**:
  - Drawer, Desktop/Tablet `NavigationRail`, and Mobile `MainBottomNavigationBar` all consume shared `availableSections` / `visibleBottomNavigationSections`.
  - When NAS is disabled (default), rail has 8 destinations (or 9 if CLI is enabled).
  - Rail selection dynamically maps visible destination index to stable view index via `appSectionToViewIndex(visibleSections[index])`, keeping NAS mapped to stable index 9 when enabled.
  - Preserved hidden NAS slots in bottom bar and dashboard quick actions; re-enabling restores original configuration.

### 4. Lazy NAS Mini-Player Gate (`lib/features/shell/main_shell.dart`)
- Guarded `_buildGlobalMiniPlayer` inside `Consumer`:
  ```dart
  final settings = ref.watch(settingsProvider);
  final isNasEnabled = settings.isSectionEnabled(AppSection.nas);
  if (!isNasEnabled && !ref.exists(nasMediaPlayerProvider)) {
    return const SizedBox.shrink();
  }
  final playbackAsync = ref.watch(nasPlaybackProvider);
  ```
- When NAS is disabled (default) and no media player service has been instantiated, `nasPlaybackProvider` is not watched, preventing premature SQLite database creation and native audio player initialization.
- If a player instance already exists from an active session, player controls remain accessible for ongoing playback without forced stopping or disposal.
- Enabling NAS in settings immediately unlocks the provider watch and restores player behavior.

---

## Preserved Changes & Non-Execution Boundary
- Preserved all dirty CLI feature changes and verified tests from prior task.
- Zero execution of tests (`flutter test`), analysis (`flutter analyze`), format (`dart format`), generation (`flutter gen-l10n`), builds (`flutter build`), ADB, or git commands.
- All edits confined strictly to:
  - `lib/l10n/app_en.arb`
  - `lib/l10n/app_zh.arb`
  - `lib/features/settings/settings_view.dart`
  - `lib/features/shell/main_shell.dart`
  - `agent-workflow/2026-10-04-experimental-nas-ui-status.md`
- Ready for OpenCode verification, testing, and artifact build handoff.
