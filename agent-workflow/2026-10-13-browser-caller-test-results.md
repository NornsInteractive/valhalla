# Browser caller migration verification — 2026-10-13

## Current result

- Migrated `test/features/application_path_flow_test.dart` from a direct `sftpOperationsProvider` override to `remoteBrowserFactoryProvider`. The fake factory bypasses only live SSH lookup and retains the real `sftpRemoteBrowser` adapter and server/connection guard.
- **15 cases prepared; not executed successfully yet.** The first focused Flutter run failed during compilation, before running any cases: `app_operation_wizard_dialog.dart:1586` reads `widget.deployment!.configuration.instanceContainerNames`, but `ApplicationDeployment` has no `configuration` getter.
- Targeted `dart analyze test/features/application_path_flow_test.dart`: **No issues found**.
- No UI, ARB, production server, build or ADB changes were made by this verification task.

## Retained and added assertions

Initial missing paths may walk ancestors; ordinary navigation to a missing directory must not silently select its parent. Permission/connection errors cannot fall back. A missing root and a pending/unlisted directory cannot be confirmed. Restricted exact paths, ancestors and trailing-slash variants cannot be selected. Server switches and disconnects must reject late listing results. Picker cancellation preserves the Nginx configuration. Selected data roots still rebase mounts correctly, trailing slash handling reaches a valid review, and the TZ variable remains set. Mount-picker cancellation preserves every form path; confirming one mount changes only that mount. Completed picker leases must be disposed. Untouched defaults must reach review without browsing or remote writes.

## Source-inspection risks awaiting AgY corrections

- `RemoteBrowserView._loadDirectory` currently applies missing-directory fallback to every navigation, rather than only initial location resolution.
- `RemoteBrowserDialog` confirmation currently does not check listing pending/error state.
- `SftpDirectoryPickerDialog.show` currently checks `restrictedPaths.contains(picked)` only after selection, dropping ancestor/normalized restrictions and disabled-button behavior.

These are inspection findings, **not claimed as executed test failures**; the compilation blocker prevented runtime evidence. Existing safety assertions were not relaxed.

## NAS caller acceptance still pending

At inspection time `NasSourceDialog` and `NasScanConfigDialog` had not yet adopted the new browser calls. Do not count isolated protocol/core tests as caller acceptance. After AgY migration, verify:

1. Browsing a draft source root changes only the root field; cancel does not save, probe or modify it.
2. WebDAV draft root selection browses from endpoint root; scan paths remain relative to the configured root. SMB endpoint share/base is applied once; SFTP selections remain absolute.
3. Jellyfin/Emby selections retain opaque library IDs, including distinct IDs with identical display names, and never treat IDs as filesystem paths.
4. Include/exclude selections write the selected path/ID to the correct list; cancel leaves both lists unchanged.
5. Source, credential or target changes invalidate an open picker and prevent stale selection from updating the draft/configuration.

Re-run the 15 application caller cases after AgY fixes the shared UI and compilation blocker, then add real NAS caller widget coverage after those callers are migrated. No full suite has been run for this task.

## NAS phase-4 tests prepared

`test/features/nas_browser_selection_ui_test.dart` now contains **8 widget cases** using the public `NasSourceDialog.show` / `NasScanConfigDialog.show` callers and a fake `NasSourcesNotifier` returning real `RemoteBrowserSource` leases. No core or model fields were invented. Targeted Dart analysis passes.

Covered assertions: transient WebDAV root selection passes a temporary `/` source root and current draft password without saving/selecting/probing/scanning; cancellation preserves the original root; a late lease after endpoint revision cannot update the form; saved SMB domain loading gates browse and explicit domain clearing remains blank; a media source saves an opaque library ID without navigating that ID; selecting a media include replaces `/` with IDs; include-all is exclusive and exclude cannot offer it; cancelling include/exclude selection preserves both lists.

**Not run yet:** at preparation time phase-4 caller controls were absent. Required stable action keys are `nas_source_browse_root`, `nas_scan_browse_include`, `nas_scan_browse_exclude`, plus requested `nas_scan_include_all_libraries` for the existing all-libraries sentinel action. Existing source field/save keys and config-save key are retained. No cases are marked skipped; run them once the UI migration lands, and report failures accurately rather than weakening behavior assertions.
