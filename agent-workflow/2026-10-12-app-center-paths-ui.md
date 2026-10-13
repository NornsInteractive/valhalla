# Application Center directory errors — AgY handoff

Only original Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b, Gemini 3.8
Flash High / high. UI belongs to AgY. Preserve all existing dirty work.
No subagents, tests, formatting/generation, builds, ADB, push or release.

Confirmed bug: wizard _pickDataDirectory starts at parent of a not-yet-created
data root (e.g. /root/.local/share/valhalla/apps); _pickMountDirectory starts at
a prospective mount directory. Shared SftpDirectoryPickerDialog blindly lists
that path, returning SftpStatusError.noSuchFile. Its confirm also remains enabled
after a failed listing. Callers: the two wizard methods and SftpFileView batch
destination picker. Do not change general SFTP listFiles semantics.

Whitelist lib/features/files/widgets/sftp_directory_picker_dialog.dart and
lib/features/app_center/widgets/app_operation_wizard_dialog.dart only for now.
Implement minimal shared-picker fix: on INITIAL opening only, walk parents on
typed SftpStatusError code noSuchFile until an existing listable ancestor or /
is reached. Never fall back for permission/connection errors; normal navigation
errors must remain visible (no silently choosing a different destination).
Each async hop checks mounted and captured server connectionKey and connected
state BEFORE further requests and before applying results. No remote writes,
no mkdir, no changing install form on cancellation. After failed listing the
select button must be disabled; disconnected/stale results cannot be selected.
Preserve restricted paths and existing folder/symlink filters. Prefer existing
localized errors for known SFTP cases if available, no new dependencies.

Core now canonicalizes trailing directory slashes in defaults/build/prepare;
strict validation remains. validatePath details identify dataRoot, mountSource,
mountTarget. Nginx Proxy Manager actual template paths are canonical; specific
user-entered paths not yet known. Do not claim exact user cause proved.

Also whitelist app_center_error_resolver.dart and all lib/l10n/*.arb. Add one
localized path-error explanation (absolute non-root path, no . or .. components)
with field parameter, complete placeholder metadata in all17ARB files. Map
APP_CENTER_PATH_INVALID detail identifiers to existing localized
appCenterDataDirectory/appCenterMountSource/appCenterMountTarget; omit raw detail
suffix for that code and do not display internal identifiers. Existing generic
path cases can use a suitable existing generic directory label. No generations.

IMPORTANT previous invocation spent >7min repeatedly reading same code without
edits and was stopped. Resume SAME conversation; stop broad investigation.
Read this handoff and picker once, implement the small change now. Add optional
initial-only bool to _loadDirectory; loop listFiles(candidate), catch ONLY typed
noSuchFile and candidate != '/', candidate=dirname(candidate); rethrow otherwise.
Guard target/connected/mounted between awaits; update displayed actual candidate
on success, disable confirm on loading/error/disconnect. Existing other callers
must preserve normal navigation errors. Do not inspect unrelated files.
