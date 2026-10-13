# Remaining actual caller integration after component gate

Original Valhalla/model/high, same UI-only ownership and no test/build commands.
Do not start until root explicitly gives this batch. Read phase2 + browser API +
protocol handoff completely. Phase3 corrections remain requirements, not waived.

## Main Remote Files page must actually share browse presentation

Use extracted breadcrumb/search/hidden/sort/view/list-grid display rather than
leaving a new independent picker beside the untouched file page. Keep existing
SftpProvider, cache, navigation, management actions, keyboard and selection
semantics. The page may supply extra menu/action builders to the common display;
the dialog must not receive download/upload/rename/delete/transfer controls.
Retain original SftpFileItem metadata and actions by path/ID. Do not replace cached
page state with a new source on every build/status update or every selection.
Search keeps own row, clears on directory change; '.' hidden and root '..' hidden;
symbolic directory links keep existing behavior; hidden entries dimmed; mobile
grid2 real vertical cards and accessible large-text1; view switch keeps item anchor.
Local upload/export remains OS FilePicker. Every remote picker shares common UI.

## NAS real callers, not only reusable component existence

Use stable action keys `nas_source_browse_root`, `nas_scan_browse_include`, and
`nas_scan_browse_exclude` for these new entrypoints. Root tests exercise real
dialogs through these public controls with provider fakes, not private state.
Use `nas_scan_include_all_libraries` for the include-only all-libraries choice;
preserve current source root/domain/save and scan save field/button keys.

- Source form root browse uses transient current form credentials/identity and
  `openBrowser`, never save/select/scan. WebDAV root browse from a temporary copy
  with rootPath='/' so form's current root can be changed within endpoint boundary.
  SMB browser remains in specified share. SFTP target correctly bound server.
- Saved SMB domain prefill via `savedDomain`: await before browse/probe/save;
  don't overwrite user changes, don't reuse old-domain secret after explicit clear.
- Form changes increment draft revision; late auth/browse only apply to same
  identity/revision. Endpoint/type/user changes clear old auth token/userId.
- Jellyfin/Emby default root is explicit all-libraries sentinel or a returned
  opaque library ID. Do not navigate IDs as paths. Store names separately for
  display; unknown previous IDs remain visible/removable, not silently replaced.
  Current models persist IDs/rootPath, not a library-name map; retain names in
  form/display state and refresh read-only labels as needed. Do not invent missing
  model fields, replace stored IDs with names, or add a new persistence scheme.
- Scan include/exclude use saved-source browser, selected IDs restored. Media
  multiselect allows exclusive all only on include. File sources accumulate one
  directory per dialog; no unnecessary new multi-directory mode. Cancel leaves
  original list unchanged. Legacy NAS SFTP without saved source uses proper host
  factory rather than inventing a saved source.
- Native/legacy media deployment directory inputs use same host picker. Current
  missing typed install destination may resolve existing ancestor on initial open;
  preserve destination-field composition as the existing tests assert.

Map all new errors without raw exception strings exposing credentials. No auth
or credentials in logs. NAS_SOURCE_SAVE_INCOMPLETE recovery asks re-enter/save,
not restart. All17 catalogs. Modal footer visible with keyboard/2x/RTL, no auto
keyboard on opening/dismissing.

Run no validators yourself; root will regenerate/test. Update UI status with real
files changed and any unmet item before returning. No test/ADB success claims.
