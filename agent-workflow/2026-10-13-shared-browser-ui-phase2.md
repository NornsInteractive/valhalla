# AgY continuation: shared browser extraction and every remote caller

Same original Valhalla/model/high and whitelist in shared-browser-ui.md. Read
2026-10-13-browser-core-api.md completely before code, plus protocol handoff.
Root/core API is landed. No core/test edits, no analyzer/generation/build/ADB.

Build the actual reusable browse display (breadcrumbs, search, hidden/sort/view,
virtualized list/grid/entry, selection footer). Both main file page and picker
must use the extracted display, not a fourth independent dialog. Keep page provider
and manage actions outside. Host adapter converts SftpFileItem to browser entries;
retain original items by ID for page management/context actions. Adapt list/grid
presentation without dropping permissions/link flags/hidden style/selections.

RemoteBrowserSource.list emits batches. Own navigation epoch and subscription,
reject delayed results, dispose only own source. Fixed bottom selection footer,
phone large/fullscreen vs desktop constrained. Picker actions: up/breadcrumb,
search on its own row, hidden/sort/view, refresh/cancel/confirm; NO downloads,
transfer list, delete/rename/copy/upload. Local OS FilePicker unchanged.
Normal320–599dp grid has2 real columns of vertical cards; large text can1 vertical.
Preserve item anchor when changing modes, not only pixel offsets.

Migrate all6 existing callsites/wrappers: file copy/move, app dataRoot and mount,
CLI cwd, ACP cwd and remote attachments. CLI needs Agent-bound factory, not host.
ACP callers capture original selected agent execution identity AND session/draft
before opening, check before applying; status-only redraw shouldn't change target.
Do not create chat session. Agent factory resolves default real pwd, no translated
default label becomes a path. Preserve attachment filters/count/2MiB thumbnail max,
24preview items/8MiB memory budget, preview only visible with bounded concurrency.

NAS source form: root browse uses ephemeral draft; WebDAV root selector passes a
temporary copy with rootPath='/' to browse endpoint base, then saves returned path
only to form. Media source default library single /all or a real ID, store names
separately from IDs. Scan include/exclude browse saved source; multiselect libraries,
all only in include and exclusive; keep unknown old values viewable/removable.
NAS SFTP legacy fallback has no saved NasSource: use explicit correct host factory,
not invented saved-source lookup. NAS native/legacy deploy media path uses host.

Source form identity/credential edits increment revision; auth results only apply
to unchanged revision and target changes clear old token/userId. SMB savedDomain
prefill must complete before actions; don't overwrite a user edit/clear. Changing
domain with blank password does not reuse old-domain credentials. Browse must not
save/select/scan. On cancel return to unchanged form. Disable invalid/loading
confirmation; not-found ancestor fallback only through core helper (never permission).

Map core errors meaningfully using all17 locale catalogs, including
NAS_BROWSE_UNAVAILABLE/NAS_INVALID_DIRECTORY_ENTRY/NAS_INVALID_LIBRARY_RESPONSE/
NAS_SCAN_FILTER_UNRESOLVED/NAS_SOURCE_SAVE_INCOMPLETE and REMOTE_BROWSER_* codes.
NAS_SOURCE_SAVE_INCOMPLETE means a previous source save only partially persisted;
ask the user to re-enter credentials and save successfully before browsing.
Do not advise restarting as a recovery because that does not repair persistence.
No raw exception-toString
display that leaks secrets. NAS source root vs scan path labels distinguish source
paths from host paths. Preserve localizations and accessibility2x/RTL/keyboard.

Finish pending phase1 uninstall/naming UI before returning if not already done.
The core fields and helpers are now available: implement the UI and introduce
the needed ARB keys yourself in all17 catalogs (that is your assigned ownership,
not a dependency on root supplying keys). In uninstall, show dataRoot first with
an explicit whole-instance label and a warning that unmounted files are included;
all checkboxes start unchecked. Selecting a parent covers/disables its children
without duplicate deletion. Protected entries remain disabled with their exact
localized reason. Preserve existing confirmation and risk/name confirmation.
In the install configuration step, validate the instance name using the core
helper, show a main-service dropdown only when multiple services need a choice,
and show a compact service-to-container-name preview using containerNames.
Single-service or valid template main is preselected. Do not switch existing
legacy configurations into the new naming strategy. Existing new-strategy name
changes must be visible in operation review as container recreation.
Update shared-browser-ui-status.md with precise changed files and unimplemented
requirements. Do not claim tests/screenshots. Ask root for missing API, do not
expand protocol/business behavior in widgets.
