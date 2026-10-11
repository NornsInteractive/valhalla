# Valhalla UI Repair Status (2026-10-11)

## Overview
A bounded UI repair phase has been applied across the 5 target UI files to resolve compilation, widget layout, and styling issues identified in terminal, update dialog, and SFTP file views. All changes are UI-scoped without touching core, data, infrastructure, provider, or test files. OpenCode owns verification.

---

## Completed Repairs

### 1. Design Token Imports and Clean Localization (`P1`)
- **Files**:
  - `lib/features/terminal/widgets/shared_terminal_canvas.dart`
  - `lib/features/terminal/widgets/customize_pinned_keys_dialog.dart`
- **Fix**: Replaced references to nonexistent `core/theme/valhalla_theme.dart` with `core/design/tokens.dart` (providing `monoTextStyle`). Removed unused direct imports of `app_localizations.dart`, relying on `context.l10n` from `context_extensions.dart`.

### 2. Tmux Install Offer Non-Null Bridge Access (`P2`)
- **File**: `lib/features/terminal/terminal_view.dart`
- **Fix**: In the tmux install overlay callback, replaced nullable `activeTab.bridge` with the already captured non-null `originatingTab.bridge`, ensuring type safety within the non-null `originatingTab` branch.

### 3. Dialog Width Bounding & Touch Target Fixes (`P3`, `P4`)
- **File**: `lib/features/terminal/widgets/customize_pinned_keys_dialog.dart`
- **Fix**:
  - Bounded dialog content width explicitly with `SizedBox(width: (MediaQuery.sizeOf(context).width - 48).clamp(280.0, 480.0))` to prevent `AlertDialog`'s `IntrinsicWidth` from calculating unsupported intrinsic dimensions on `ReorderableListView`.
  - Removed `const Spacer()` from `AlertDialog.actions` (resolves `Incorrect use of ParentDataWidget` caused by `OverflowBar` actions layout).
  - Ensured $\ge 44$dp hit targets for both the `ReorderableDragStartListener` drag handle (`SizedBox(width: 44, height: 44, ...)`) and the remove action button (`SizedBox(width: 44, height: 44, ...)`), while retaining narrow/large-font scrolling support.

### 4. Localized Close Action in App Update Dialog
- **File**: `lib/features/settings/widgets/app_update_dialog.dart`
- **Fix**: Replaced nonexistent `context.l10n.close` getter with `context.l10n.cmdClose`, which is uniformly authored across all 17 supported locales.

### 5. SFTP Hidden File Readability & Fully Opaque Badges
- **File**: `lib/features/files/sftp_file_view.dart`
- **Fix**:
  - Removed unused `app_localizations.dart` import.
  - Removed compounding `0.8`/`0.7` alpha dimming on subtitle metadata (`permissions`, `formattedSize`, and `modified`), ensuring clear legibility across dark and light themes.
  - Made symlink badges (`Icons.shortcut`) and broken symlink badges (`Icons.link_off`) 100% opaque (`context.colorScheme.primary` and `context.colorScheme.error`).
  - Preserved subtle dimming on hidden file title (`0.62` alpha) and base icon (`0.6`/`0.55` alpha), while keeping list/grid toggle, user preferences, batch actions, selection mode, and navigation intact.

---

## Modified Source Files
1. `lib/features/terminal/widgets/shared_terminal_canvas.dart`
2. `lib/features/terminal/widgets/customize_pinned_keys_dialog.dart`
3. `lib/features/terminal/terminal_view.dart`
4. `lib/features/settings/widgets/app_update_dialog.dart`
5. `lib/features/files/sftp_file_view.dart`
6. `agent-workflow/2026-10-11-ui-repair-status.md`
