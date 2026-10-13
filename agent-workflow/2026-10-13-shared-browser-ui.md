# AgY Valhalla — UI-only implementation

Use only original ec81a4be-7543-45ee-8658-f68966f57d3b / Valhalla,
gemini-3.8-flash-high and high. Read the approved implementation document
2026-10-13-shared-browser-and-app-data.md and frontend rules. Use frontend-design
guidance within the USER's existing Flutter Material design: functional two-column
tiles, compact paths, accessible selection, not a marketing-site redesign.

## Whitelist

lib/widgets/remote* (new reusable browser UI allowed),
lib/features/files/sftp_file_view.dart,
lib/features/files/widgets/sftp_directory_picker_dialog.dart,
lib/features/chat/widgets/remote_workspace_browser_dialog.dart,
lib/features/chat/ai_chat_view.dart, lib/features/chat/cli_chat_view.dart,
lib/features/app_center/widgets/app_store_tab.dart,
lib/features/app_center/widgets/app_uninstall_dialog.dart,
lib/features/app_center/widgets/app_operation_wizard_dialog.dart,
lib/features/app_center/widgets/app_center_error_resolver.dart,
lib/features/nas/widgets/nas_source_dialog.dart, nas_scan_config_dialog.dart,
nas_native_install_dialog.dart, nas_install_dialog.dart, nas_deployment_chooser.dart,
lib/features/nas/widgets/nas_localizations.dart,
lib/l10n/*.arb (all17 languages; generated Dart is OpenCode-owned),
agent-workflow/2026-10-13-shared-browser-ui-status.md.

No core/data/infrastructure/platform/pubspec/test/format/generate/analyze/build/ADB
or remote operations. Read core contracts freely. Preserve unrelated dirty edits.

## First slice (do now without waiting for new browser APIs)

1. App store grid must be actual2 columns at normal320–599dp, distinct vertical
   icon/name/status cards vs horizontal list. One shared layout computation for
   render and existing anchor conversion; 2x typography may become1 vertical card.
   Preserve preferences/filters/source+app anchor, no unrelated reskin.
2. Native install existingInstall=true: presentation filters only
   NAS_NATIVE_ALREADY_INSTALLED, existing explanation already covers it; map code
   to existing localized explanation as fallback. Other blockers still render,
   canInstall remains core-owned and false. Add compatible OS_UNSUPPORTED/PORT_BUSY
   error aliases if applicable; no new misleading health claim.
3. Then implement uninstall/dataRoot and naming UI using new model/helper fields
   once they exist; if not yet landed, stop after1–2 and report, do not invent APIs.

## Subsequent slice (root will signal stable browser contracts)

Core is now ready. Read 2026-10-13-browser-core-api.md for exact provider APIs and
2026-10-13-nas-browser-protocol-handoff.md for protocol semantics. Root still sends
a separate continuation after first slice; do not run concurrent AgY turns.

Extract real shared browse UI from remote file page, and reuse both on page and
all pickers; don't add a fourth independent picker. Full functionality in approved
doc. Narrow/fullscreen modal+desktop bounded; picker has no downloads/manage
buttons; native local FilePicker unchanged. Never accept late target/agent/draft
results, invalidate only own requests. Migrate CLI cwd using captured Agent source
instead of host SFTP. Preserve link/hidden/selection behaviors and2MiB per preview,
24items/8MiB cache limits. Search resets entering another directory.

NAS source+scan+deployment fields use same component with real source semantics.
Source drafts use temporary provider opener; library names map to IDs, not paths.
No direct protocol calls in UI. Keep17 catalogs complete and parameter-parity.

Report changed files/remaining work truthfully; do not claim screenshots or tests.
