# GitHub update UI — original Valhalla / Gemini 3.8 Flash High

After terminal phase, implement About GitHub entry and update UI. Whitelist:
lib/features/settings/widgets/about_privacy_card.dart, a new app_update_dialog.dart
in that directory, lib/features/settings/settings_view.dart only if wiring needed,
lib/main.dart (update provider import / lifecycle initial mounting only), authored
lib/l10n/*.arb and this report. No tests, generation, formatting, analyze, builds,
ADB or business edits. Codex owns app_update_provider/service/model and native
bridges. Preserve dirty changes. No extra dependencies.

Read lib/core/providers/app_update_provider.dart and lib/data/models/app_update.dart.
About: link valhallaRepositoryUrl; check/update row shows installed version,
checkedAt, available version/build and progress. Automatic check toggle defaults
true, setAutomaticCheck awaited with visible save errors. App production lifecycle
mounts appUpdateProvider and checkIfDue once after startup; default test hook must
avoid network checks unless explicitly enabled (follow autoConnectEnabled pattern).
Resume already subscribes appVisibilityProvider in update provider. Do not block
startup/connection. Keep manual check accessible without SSH.
Core now also provides automaticUpdateChecksEnabledProvider (default false for
isolated widgets/tests). Production main ProviderScope must override it true;
watch appUpdateProvider to mount it. Its build restores/checks if due itself.

Update dialog displays bounded release notes, exact selected artifact name/size,
version/build and source commit; missing compatible artifact offers release page.
check(), download(), pauseDownload(), openDownloaded(), openRelease() are APIs.
Download explicit user action, progress/throttle, cancel retains resumable partial,
retry resumes, completed Android action opens system installer. Explicit button
for install permission retry. Native UPDATE_SIGNATURE_MISMATCH explains inability
to cover debug-signed installs; never offer uninstall. Never call downloaded/open
automatically. Desktop reveal/open folder with extract/launch instructions, never
overwrite running app. iOS/store go official release/store path.

Map API rate limit/offline/manifest/hash/permission/platform errors to localized
useful text, detailed copy option if needed. No raw key UI. Preserve selected
update during download. Keep old states visible on check failure. Narrow screen,
large font, accessibility and dark/light theme reuse existing components.
All authored locales translated with identical keys/placeholders. Avoid enormous
inline release notes; scroll bounded. OpenCode validates after implementation.

Status: UI implementation authored, not yet accepted. OpenCode owns execution
and verification; the current generated-source analyzer still finds a UI
compile blocker, so no whole-app acceptance or build is claimed.

### Implementation Summary
1. **Lifecycle & Root Mounting (`lib/main.dart`)**:
   - Production `ProviderScope` overrides `automaticUpdateChecksEnabledProvider` to `true` (keeps default `false` for isolated widget/unit tests).
   - `_LifecycleHost.build` nonblockingly watches `appUpdateProvider`, mounting the notifier on app startup so it restores cache, triggers scheduled checks if due, and subscribes to app visibility changes.

2. **About & Privacy Updates Section (`lib/features/settings/widgets/about_privacy_card.dart`)**:
   - Implemented as `ConsumerStatefulWidget`.
   - Added GitHub repository entry pointing to `valhallaRepositoryUrl` with external browser launcher.
   - Added update row showing installed package version (`vX.Y.Z (build)`), last checked timestamp (`checkedAt` formatted, or "Never checked"), update available badge, check progress spinner, and manual "Check now" / "View update" button.
   - Shows check errors in the subtitle while preserving existing cached release info.
   - Added 24-hour automatic update check toggle (`setAutomaticCheck`), catching and reporting persist errors via SnackBar.

3. **Software Update Dialog (`lib/features/settings/widgets/app_update_dialog.dart`)**:
   - Responsive bounded modal dialog (`maxWidth: 540`, `maxHeight: 680`, `Flexible` scrollable body) accessible on 360dp mobile and desktop.
   - Displays current version vs. target version, build number, and source commit badge with copy-to-clipboard action.
   - Selected artifact details: filename, architecture, formatted size, and SHA-256 hash with copy button.
   - Fallback when no matching platform artifact exists: displays explanatory notice with direct button to GitHub releases page.
   - Bounded release notes (truncated at 16Ki characters with scrollbar and external link fallback).
   - Download status and progress indicator (`LinearProgressIndicator` + formatted bytes and percent).
   - User-initiated action flow: Download, Pause, Resume, Retry.
   - Install / reveal flow: Android launches system package installer, Windows reveals in File Explorer, other desktop platforms open download folder; desktop displays guidance to close app before replacing and never overwrite running executable.
   - Native error mapping: handles `UPDATE_SIGNATURE_MISMATCH` explaining certificate differences without offering uninstall, `UPDATE_INSTALL_PERMISSION_REQUIRED` providing an explicit "Retry Install" button, rate limit errors, network failures, manifest/hash integrity mismatches, and platform launch failures.
   - Unknown/generic errors mapped to clean localized copy; technical error details available via dedicated "Copy error details" button.

4. **Localization (17 ARB files in `lib/l10n/`)**:
   - Added 55 updater string keys and required placeholder metadata across all 17 supported locales (`app_*.arb`).
   - All files verified for valid JSON syntax and key consistency.

### Latest diagnostic follow-up — original AgY only

OpenCode regenerated localization successfully (exit 0), then analyzer exited 1.
app_update_dialog.dart:716 reads context.l10n.close, which is not an authored or
generated getter. Reuse an existing appropriate Close getter (for example
cmdClose) or author a dedicated updateClose key in all locales; do not add a
manual extension fallback. This blocks app compilation independently of the
terminal missing-theme/null-safety problems. sftp_file_view.dart also has an
unused AppLocalizations import after its fallback extension was removed; remove
only the unused import during the file-readability follow-up. Main Codex does
not edit these UI files. Original AgY quota restoration is awaited.
