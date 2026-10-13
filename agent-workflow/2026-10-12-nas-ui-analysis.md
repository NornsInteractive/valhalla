# UI compile errors from OpenCode — AgY ownership

OpenCode ran gen-l10n successfully and analyzed current tree. Full log:
`/tmp/valhalla-nas-refresh.OOGiIt/analyze.log`. Root won't edit UI.

Fix all lib/features errors/warnings in that log, same original conversation/model
and whitelist. Do not change core contracts to match invented UI fields.

- SftpFileItem is defined in infrastructure/sftp/sftp_client_service.dart,
  not data/models/sftp_file_item.dart. Fix imports in app_operation_wizard_dialog
  and remote_file_batch_results_dialog with correct relative depth.
- ApplicationEnvironment has dockerAvailable/composeAvailable/architecture, NO
  dockerVersion. Show actual availability/architecture, no fabricated version.
- _ports is List<ApplicationPort>, NO entries. Use published/target/protocol fields.
- ApplicationTemplate has application.version, NO direct version. Read actual model.
- nasAddToPlaylist/resume l10n getters are absent; use existing correct translated
  getter or add valid ARBs if needed, don't edit generated files.
- nas_library_settings_dialog.dart end of _buildForm has unmatched stale bracket
  closings around 580-586; nas_scan_config_dialog similarly 603-604, and the
  extracted form needs a local Theme.of(context) for its theme usages.
- Remove only unused _buildQuickStatDot / activeSource / import identified by log.
- Review syntax without running tools that analyze/build/test/format; OpenCode owns
  these. Current test draft errors belong to OpenCode; vendor info belongs to root.

Report fixes so OpenCode can regenerate/analyze and run responsive UI tests.
