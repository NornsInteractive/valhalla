# Next AgY batch after shared component: thin callers only

Root will explicitly start this later. Original Valhalla/model/high; UI only.
Do NOT rescan the project or reread entire chat/wizard pages. Inspect imports and
the named caller functions plus the two wrapper files and tests below.

- SftpDirectoryPickerDialog: replace old independent body with a thin common
  dialog adapter. Keep original target guard and restricted path semantics,
  including normalized exact/ancestor/descendant relations, and disabled confirm.
  Source always disposed; late server change/disconnect cannot return a path.
- RemoteWorkspaceBrowserDialog: remove dead 800-line independent browser body;
  keep public .show and old mode facade if needed. Current partial file references
  serverConnectionProvider without import (compile failure); new thin adapter must
  compile. Real factory uses captured AgentProfile host/container/user. Validate
  original profile execution identity, server connection, activeSessionId and
  draftWorkingDirectory before/after awaited opening and before applying result.
  Status-only redraw remains valid. Check context.mounted after await, close own
  source, never create an ACP session. Preserve old text/image capability filter,
  file-size limit and remaining attachment count. Shared UI already supports3 views.
- ai_chat_view.dart: only _showDraftWorkingDirDialog and _promptRemoteTextFile plus
  required imports. Capture target BEFORE opening and validate BEFORE applying
  cwd/each attachment; current code captures target AFTER the dialog (unsafe).
- cli_chat_view.dart: only _openRemoteDirectoryPicker plus imports. Capture original
  session/draft and execution target, handle async context disappearance, apply only
  to original draft; do not create/switch any session.
- app_operation_wizard_dialog.dart: only _browseDataRoot/_browseMount methods;
  verify original restricted paths reach shared confirmation and cancel preserves
  all controllers, path composition and other mount values. Existing naming fields
  and layout now pass; do not touch them in this batch.

Actual tests: test/features/application_path_flow_test.dart (15 cases),
test/features/acp_remote_workspace_browser_test.dart (17 cases). Read public
contracts as needed, don't run or modify tests. Add localization only if genuinely
missing in all17 catalogs. Root handles generation/analyze/test/build/ADB.
Return after this batch. Main Remote Files + NAS integration is a later batch,
still required; don't begin it here and prolong these stable caller gates.
