# Five-module completion — implementation contract

User approved all five modules and then requested implementation. Preserve all
existing dirty remote-files work. No build, installation, real remote actions,
git commit/push, CI or release in this task.

## Ownership and workflow

Core/storage/services: Codex. UI and authored ARB: ONLY original AgY Valhalla
`ec81a4be-7543-45ee-8658-f68966f57d3b`, `gemini-3.8-flash-high`, effort high.
Tests, analysis, formatting and generated localization: OpenCode with explicitly
free main AND small model (current confirmed fallback `opencode/space-bunny-free`).
After both verification streams stopped producing output for over ten minutes,
resumed SAME verification sessions using user-authorized free fallback
`opencode/step-5-preview-free` for both main and small model. Local model catalogue
confirmed input/output/cache costs all zero. Dedicated config:
`/tmp/valhalla-completion-opencode.json`; do not modify global OpenCode config.
Use apply_patch for authored changes; preserve all unrelated changes. No live
SSH/Agent sessions, credentials or user history access. No new dependencies.
After Step 5 encountered an upstream outage and repeatedly generated invalid
test fixtures, continued the same two sessions with `opencode/mimo-v2-pro-free`
(main and small model). Confirmed local catalogue costs: input/output/cache_read
all zero. This is within the user's existing free-model fallback permission.
MiMo Pro and Qwen 3.6 Plus free returned immediate upstream server errors;
MiMo V2.6 Flash free produced no actions for over five minutes. Resumed both
original verifier sessions on the previously responsive Step 5 free model.
These failed attempts are NOT verification evidence.
During the resumed narrow-dialog follow-up, switched the dialog verifier back
to the requested `opencode/mimo-v2.6-flash-free` (main and small),
using `/tmp/valhalla-dialog-opencode.json`; local catalogue still reports all
input/output/cache prices zero. This does not change the Step 5 task config or
the global OpenCode config.
The long existing verifier session stalled in compaction, so its process was
stopped and a fresh, short-context OpenCode verifier continued the same owned
test file. Only AgY is restricted to its original conversation; that conversation
and its Gemini Flash High settings remain unchanged.
Neither MiMo resumed nor short-context attempt produced tool actions before
being stopped; a short-context Step 5 free verifier completed the narrow
fixture corrections. Those MiMo attempts provide no verification evidence.

## Scope / acceptance

1. Settings: remove inert/default-engine and hardcoded host-count display.
   Reuse per-server ACP/CLI default agent storage/registry; no parallel preference.
   Trusted-host list: address, port, fingerprint, time, copy, revoke confirmation;
   revoke disconnects matching active endpoint and next connect requires trust.
   No missing callback auto-trust. Credential removal selects servers, confirms,
   disconnects affected connections, clears only local SSH/password/private-key/
   sudo credentials; no config/history/remote login deletion. Deletion failure
   remains visible/retryable. Localized, narrow/mobile/desktop accessible UI.
2. ACP: audit/test existing code first, fix reproduced gaps in target isolation,
   authentication/status, model/effort/permission rollback, pre-first-prompt
   commands/skills, streamed tool ordering, approvals, interruption/recovery.
   Preserve same-target content/drafts while reconnecting. No automatic prompt,
   approval replay or new remote session for discovery. Model catalog uses
   independent CLI, shows source/cache timestamp, never proves authorization.
   Diagnostics redact secrets and distinguish error stage/target. Real runtime
   acceptance must be marked unverified without an independent test target.
3. Files: retain current breadcrumbs/hidden/link changes. Multi-select; bulk
   regular-file download, move/delete (no recursive nonempty-directory deletion).
   Same-server file/directory copy/move via target picker; no overwrite by default,
   no self/descendant target, no following symlinks for recursive copies. Per-server
   bookmarks; per-item batch outcomes; explicit failed-transfer retry. Reuse
   pause/resume/cancel. No cross-server copy or cross-process resume guarantee.
4. Docker: existing container page plus Compose project/service grouping from
   labels; image/status/ports/mount details; reuse terminal and bounded logs.
   Project start/stop/restart targets explicit existing IDs only, progress and
   per-item failures, confirmations for stop/restart. No deployment/config edit,
   pulling images, implicit container creation or image/volume/network cleanup.
5. Migration: versioned allowlisted JSON of servers/agents/commands/preferences/
   bookmarks. Exclude credentials, trusted keys, history, runtime state and local
   paths. Export preview warns custom commands can contain embedded secrets.
   Validate completely before import, preview, append with fresh IDs and remap
   references. Applying global prefs opt-in. No automatic connect/execute/trust.
   Snapshot affected keys and rollback partial writes. Do not export whole prefs.

## Phase 1 core API (Codex implements; AgY consumes)

`lib/core/providers/security_settings_provider.dart` exports:
- `trustedHostsProvider`: `NotifierProvider<TrustedHostsNotifier, List<HostKeyEntry>>`;
  notifier `Future<void> revoke(String hostPort)`.
- `securitySettingsProvider`: `Provider<SecuritySettingsActions>`;
  `Future<void> clearServerCredentials(List<String> serverIds)`.
Both commands are called only after UI confirmation, propagate failures and never
modify remote state. Credential deletion clears all selected valid server IDs;
UI should preserve retry selection on failure. Read server list from existing
`serverListProvider`; no servers is an empty state. TrustedHost entry fields are
`hostPort`, `keyType`, `fingerprintSha256`, `trustedAt`.
Default agent: use existing agent registry/default setters, including CLI only
when experimental CLI enabled. No default means automatic existing fallback.
UI review follow-up: default agent picker must handle async save failure in-place
and disable duplicate submissions (not raw unawaited RadioListTile callback).
Use SecuritySettingsActions.setDefaultAgent(id, cli:..., expectedServerId:server.id)
to reject stale target and validate eligible agent. Provider already implements it.
Avoid large fixed height overflows, also for revoke/clear confirmation dialogs.
Core now exports `defaultAgentSettingsProvider: Provider<Map<String,String?>>`
from security_settings_provider.dart with 'acp'/'cli' IDs. SettingsView should
watch this to render labels; all three existing save entrypoints invalidate ONLY
this cheap local provider. No chat/registry initialization or refresh needed.

## Initial UI assignment

AgY starts with phase 1 only. Allowed UI paths: settings_view.dart, new narrowly
scoped settings widgets, lib/l10n/*.arb and own UI status report. No generated
files, business providers/storage/services, tests or build commands. Wait for
follow-up API contracts for remaining modules. Report authored files and real
status to `agent-workflow/2026-10-09-completion-ui-status.md`.

## Docker UI assignment (after phase 1)

Core implemented: `DockerContainer.composeProject` / `.composeService` nullable
strings; `DockerState.composeProjects` map from project name to filtered containers.
`DockerNotifier.performProjectLifecycle(project, action, List<String> ids)` returns
`List<DockerActionResult>` (containerId, containerName, success, error). Only start/
stop/restart. Capture full ID list at confirmation, never broaden it on execution.
`state.pendingActions` contains remaining in-flight target IDs for progress.
Both performProjectLifecycle and SftpNotifier.runBatch now accept named
`expectedServer: ServerProfile`. Capture BEFORE opening confirmation/target picker,
pass it to the core method and compare connectionKey after awaits before any UI
success. Do not capture server only AFTER confirmation: switch/edit while a
dialog is open must never run the old selection on a new endpoint.
No need to add providers. Allowed UI addition: docker_view.dart and own docker
widgets. Reuse container card actions/logs/terminal, group views and display
service/image/ports. Existing inspect provides Mounts for readable read-only
mount summary (don't replace raw JSON details). Confirm stop/restart with exact
container list; async target changes must not show stale success on new server.
Report partial outcomes; do not execute actual Docker commands during development.

## Files UI assignment (after Docker)

Allowed UI file sftp_file_view.dart plus small files/widgets. Preserve current
uncommitted changes. New core APIs: import remote_file_actions.dart for
RemoteFileAction {copy,move,delete,download}, RemoteFileOutcome
{completed,queued,skipped,failed}, RemoteFileResult(path,outcome,error).
`SftpNotifier.runBatch(action, items, {targetDirectory, onProgress(int,int)})`
returns per-item results, rejects overlapping batch. UI must confirm deletes,
list nonempty-dir restriction and no overwrite. Downloads queued != completed.
`retryTransfer(id)` retries failed tasks from beginning, not partial offset.
`fileBookmarksProvider` gives per-server List<String>, notifier.toggle(path).
Offer current path bookmark toggle, bookmark picker/removal and navigation.
Use a directory-only picker over current-server SftpOperations.listFiles(path)
with local path state, ignoring '.' / '..' entries, normalize with p.posix.
DO NOT reuse ACP workspace browser: it targets agent container/user, not SFTP
host. Capture server connectionKey and discard async picker/results after switch.
Multi-select normal list entries (not '.'/'..'), action bar/menus for batch
download/copy/move/delete, progress and per-item outcome dialog. No recursive
nonempty-directory deletion or cross-server operations. Localization in all ARBs.

## Configuration migration UI assignment (after Files)

Settings entry and new small widget(s) only; use installed file_picker to pick /
save UTF-8 JSON, enforce size <= ConfigurationBackupService.maxBytes before read.
Business API `lib/data/services/configuration_backup_service.dart`:
`ConfigurationBackupService(storage).exportConfiguration()` -> ConfigurationBackup;
`.encode()` provides preview/file JSON. static `decode(String)` validates, returns
backup with .servers/.agents/.commands/.bookmarks/.preferences for preview.
`importConfiguration(backup, {applyPreferences: false})` performs append/remap and
rollback. UI preview shows counts, target endpoints, agents, commands (expandable),
with warning custom commands can embed secrets, no credentials/trust/history.
Import global preferences checkbox OFF by default. Require final confirmation,
disable duplicate submissions, retain dialog on error. On success invalidate
serverListProvider, commandsProvider; settingsProvider and terminalSettingsProvider
ONLY when global prefs applied. Don't invalidate agentRegistryProvider or chat
providers (existing server agents unchanged; no automatic remote probes).
No implicit active-server switch or connect. File cancel is not an error. Decode
unsupported/malformed errors localized, detailed diagnostic optionally copyable.

## Verification assignment

IMPORTANT: Do not modify global OpenCode or other tool configuration. Main and
small model are ALREADY set by OPENCODE_CONFIG=/tmp/valhalla-completion-opencode.json.
Phase 1 core APIs now exist, including SecureStorageService.clearCredentialsStrict.
All authored changes must use built-in apply_patch tool; no shell/Python writes.
Core modules now ready for focused tests: security_settings_provider.dart,
file_bookmarks_provider.dart, sftp_provider.dart runBatch/retryTransfer,
remote_file_actions.dart, Docker project grouping/actions, configuration_backup_service.dart
and LocalStorageService appendConfiguration. Test same agent ID on different
servers, malformed/unknown format, no secrets/privateKeyPath/host keys/history,
append/remap, preference opt-in and rollback including false preference writes.
Import must refuse existing damaged JSON rather than treating tolerant [] UI
fallback as empty data and overwriting it. LocalStorageService now guards this.
ACP narrow fixes: draft settings update after successful persistence; no interim
runSettings updates while applying; rollback partially applied remote settings,
restore local defaults/session on persistence failure; report failed rollback
truthfully with actual confirmed settings/stale flag. Tests must cover these.
OpenCode probe reproduced missing quote/access_token/refresh_token/id_token/OAuth
redaction. Codex patched shared sanitizer; add regressions for escaped quoted
secrets, quoted bearer, OAuth pairs/plain code_verifier, split chunks; preserve
ordinary Docker state and JSON RPC numeric code fields (sanitizer also wraps SSH
command output). Do not classify any arbitrary JSON state as a credential.
Run generation after AgY ARB completion before whole-project analyze; core tests
may start now. Only authored new tests and mechanical formatting of this round's
specific core paths are allowed; do not edit production behavior yourself.

OpenCode first audits/reproduces phase 1 security and existing ACP/reconnect gaps.
Allowed edits initially: targeted test files and own verification report only.
Do not change UI/production, weaken assertions, blanket-format or run builds.
Report any baseline failures separately from this change. Cover missing host-key
confirmation, revocation/disconnect, strict credential deletion failures, no
history/config loss. Audit ACP with mocks/fixtures only and report concrete
reproducible issues before suggesting changes. Record commands/exit codes/counts
in `agent-workflow/2026-10-09-completion-verification.md`.

## Current status

All five implementations and AgY's UI handoff are present. After the user switched
accounts, restarted AgY in the SAME original Valhalla conversation, model and
effort; it completed its remaining source and ARB work. Codex/OpenCode did not
take over UI. No build, device or real remote evidence. Changes are uncommitted,
HEAD remains e99e7e14da179cb9d59d01d2880787f1e4abc3a4, and original dirty work and
the protective stash remain intact.

Latest focused checks, each actual exit 0 (overlapping scopes, not additive):
- Files/Docker/configuration/original remote-files contracts: 117 passed.
- Security/sanitizer: 30 passed; strict credentials/trust/default regressions: 14.
- ACP rollback + existing independent models + background recovery: 72 passed,
  including a gated 70-message history read cancelled mid-load and retried.
- Completion dialogs: 13 passed, including 320dp/2x checks. AgY fixed real
  Docker, bookmarks, settings and clear-credentials overflow; OpenCode corrected
  its lazy-list/subclass finders without weakening assertions or changing UI.
- Six affected SFTP widget fixtures: 76 passed; settings auto-connect: 7 passed.
  Mock storage/active-server dependencies and the correct tile finder were fixed.
- Localization generation, whole-project analyze and diff check: exit 0;
  analyze reports No issues found! See 2026-10-10 reports for commands and logs.

Historical failures remain in the reports: first full test run was 2115 passed,
18 skipped, 46 failed (ARB metadata/French clone, settings sizing and SFTP fixtures),
all addressed by the responsible owners. The subsequent default-parallel run
was INTERRUPTED after disk-full temporary-directory failures and one finder
failure now corrected. SIGTERM returned shell exit 0 without a final summary;
that is NOT a passed suite. No old artifacts were deleted. The final full run
used --concurrency=1 to reduce temporary disk peak and COMPLETED successfully:
2165 passed, 18 skipped, zero failed, actual exit 0, terminal summary
04:46 +2165 ~18: All tests passed! Whole analyze --no-pub and diff check both
exited 0. This supersedes the historical red/interrupted snapshots; see
agent-workflow/2026-10-10-final-validation.md. The 18 pre-existing opt-in
integration checks require independent VM/device/mosh fixtures and were not run.
Earlier failed/uncompiled/stalled attempts are not acceptance evidence.

Latest handoff: docs/handoffs/2026-10-09-five-module-completion.md.

## Explicit implementation limits

- Same-server copy/move uses GNU coreutils; unsupported servers fail explicitly,
  without installing software. An abruptly killed copy can leave its temporary
  staging directory; no cross-process continuation is promised.
- Configuration import rolls back reported preference-write failures, but is not
  crash-atomic across a process kill. Export excludes managed credentials; custom
  Agent/quick-command text must still be reviewed for embedded secrets.
- Tests use local fixtures and mocked protocols only. No real SSH/ACP account or
  mobile/desktop runtime acceptance is implied by a passing test suite.
- Import does not replace a saved active target. With an initially empty server
  list, the existing app selector displays the first imported profile, disconnected;
  import does not save an active ID or initiate a connection.

## Original UI review checklist (AgY handed off fixes; preserve for audit)

- Trusted-host revoke: catch errors, busy guard, mounted check after confirmation.
- Settings defaults: watch defaultAgentSettingsProvider so saved labels refresh.
- Capture expectedServer BEFORE Files picker/confirmation and Docker confirmation.
- SftpDirectoryPickerDialog connectionKey is a record, not String; capture a
  ServerProfile and compare hasSameConnectionSettings.
- Files: queued downloads are not completed; show queued wording and runBatch
  onProgress completed/total feedback. Retry needs error handling for disconnect.
  Batch results must not use nasDownloadFailed ("Download failed") for copy/move/
  delete failures; use a generic localized failure label.
- Bookmarks: await toggle, catch failures, disable concurrent toggles; stale
  currentPath must not be saved or navigated after server change while open.
- DockerProjectCard currently has literal '$runningCount/$totalCount running';
  use localization for all authored labels. Long names/paths and 2x text at 320dp
  must scroll/wrap without losing actions.
- Credentials explanatory text includes sudo password; private-key users must
  re-add key in Edit Server after clearing. Do not delete source key files.
- No new blanket lint ignores. Generated code/analyze/widget tests by OpenCode.
- Migration initial draft assumes old file_picker API. Installed 12.3 uses
  pickFile -> PlatformFile?; pickFiles -> List<PlatformFile>, not result.files.
  Use lengthSync() to reject a known large size, then bounded readAsByteStream().
  length() may read contents to determine unknown size; avoid it before the cap.
  Stop accumulating before >8MiB even if metadata is missing/wrong. No deprecated
  withData/withReadStream, readAsBytes or unbounded readAsString.
- Migration export needs preview + secret warning BEFORE save (initial handleExport
  saves immediately). Preview Agent startup/install/login command text as well as
  quick commands; managed credentials excluded does not make embedded text safe.
- Migration import: PopScope must prevent leaving while submitting; check mounted
  before ref access after await. Disable duplicate import/export picker launches.

## Data verifier feedback after first backup test run

Main fixed a REAL decoder issue: malformed JSON/invalid date FormatException now
normalizes to CONFIG_FORMAT_INVALID instead of exposing parser messages/contents.
Other observed failures were fixture expectations, not product behavior:
- Export includes empty bookmark/default-agent entries for configured servers.
- Imported command IDs MUST change; assert preserved existing record and new
  command content with a fresh ID, not original source ID 'b'.
- Rollback fixture seeds theme='light'; it must remain 'light', not null.
- Failure injection on bookmark key srv-new/srv-1 does not fire through import
  because IDs are remapped. Inject on a deterministic global key late in writes,
  or call appendConfiguration with fixed IDs for storage rollback tests.
- Existing data invalidity, rollback failure, and native/cache snapshots need real
  assertions. Required-field type errors may map CONFIG_FORMAT_INVALID and bad
  authType maps CONFIG_AUTH_TYPE_INVALID; do not require every server validation
  to have the same code. Rejection and unchanged storage are the safety boundary.
- After the second run, main added a preference-cache reload on rollback failure
  before reporting CONFIG_IMPORT_ROLLBACK_FAILED. Native data remains the source
  of truth; optimistic failed writes must not masquerade as persisted imports.
  Verifier should also match actual SharedPreferences.remove semantics (cache is
  removed before persistence). The concurrency test's unused Completer is awaited
  but never completed; remove that stray gate or actually gate a storage write.

## Additional ACP recovery fix to verify

Main confirmed the pending-history cancellation bug by tracing all callers:
_handleConnectionLost -> _stopGeneration increments _requestEpoch; pending
_loadSelectedMessages finally skips stale epoch, so isLoadingMessages stayed true
and blocked future history loads/recovery. _stopGeneration now clears ONLY that
loading flag alongside its other busy flags, preserving messages/draft/session.
OpenCode: gate a local loadSession future, disconnect/stop, complete old future;
assert busy clears, stale result is not applied, and retry can load the same
selected session. Reuse existing background_recovery_chat_state_test fixtures.

Fixture review: FakeAcpPair's accepted set_config_option response currently
echoes a changed value without storing it in configOptions. A later response
can reset a previously accepted model in this fake. Persist accepted values in
the fixture before testing multi-option transactions; do not "fix" production
to satisfy a fake that forgets remote state between requests.
