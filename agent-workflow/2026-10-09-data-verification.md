# Files / Docker / Configuration-migration core test round - data verification

Date: 2026-10-10
Scope: core APIs only (files, Docker, configuration migration), tests and
report. No production, UI, ARB, generated-code, build, install, git,
device/ADB or remote-session commands were used. All edits are new test files
plus the pre-existing `test/core/remote_files_contract_test.dart` (kept passing).

## Files authored (new test files only)

| File | Targets |
| --- | --- |
| `test/infrastructure/remote_file_actions_test.dart` | `RemoteFileActions.command` validation, `execute` outcome mapping, generated shell-script semantics executed inside a freshly created temp dir |
| `test/core/remote_file_batch_contract_test.dart` | `SftpNotifier.runBatch`, `retryTransfer`, `expectedServer` stale-confirmation rejection |
| `test/core/file_bookmarks_provider_test.dart` | `fileBookmarksProvider` (per-server bookmark toggle, persistence, isolation) |
| `test/features/docker_project_lifecycle_test.dart` | `DockerState.composeProjects` grouping, `DockerNotifier.performProjectLifecycle`, `pendingActions`, `expectedServer` |
| `test/data/configuration_backup_service_test.dart` | `ConfigurationBackupService.exportConfiguration/decode/importConfiguration`, `LocalStorageService.appendConfiguration` |

Pre-existing `test/core/remote_files_contract_test.dart` was re-run to confirm no
regression in the earlier files round.

## Commands and results (exact)

```
$ flutter test \
    test/infrastructure/remote_file_actions_test.dart \
    test/core/remote_file_batch_contract_test.dart \
    test/core/file_bookmarks_provider_test.dart \
    test/features/docker_project_lifecycle_test.dart \
    test/data/configuration_backup_service_test.dart \
    test/core/remote_files_contract_test.dart
00:02 +117: All tests passed!
exit code: 0
```

Per-file counts (single-file runs, all exit code 0):

| File | Tests |
| --- | --- |
| `test/infrastructure/remote_file_actions_test.dart` | 18 |
| `test/core/remote_file_batch_contract_test.dart` | 17 |
| `test/core/file_bookmarks_provider_test.dart` | 7 |
| `test/features/docker_project_lifecycle_test.dart` | 14 |
| `test/data/configuration_backup_service_test.dart` | 34 |
| `test/core/remote_files_contract_test.dart` (pre-existing) | 27 |
| **Total** | **117** |

Scoped analyze (production core files under test + all owned test files),
formatted first:

```
$ dart format test/infrastructure/remote_file_actions_test.dart \
    test/core/remote_file_batch_contract_test.dart \
    test/core/file_bookmarks_provider_test.dart \
    test/features/docker_project_lifecycle_test.dart \
    test/data/configuration_backup_service_test.dart
Formatted 5 files (0 changed)

$ dart analyze lib/core/providers/sftp_provider.dart \
    lib/features/docker/docker_provider.dart \
    lib/data/services/configuration_backup_service.dart \
    lib/data/storage/local_storage_service.dart \
    lib/core/providers/file_bookmarks_provider.dart \
    lib/infrastructure/sftp/remote_file_actions.dart \
    test/data/configuration_backup_service_test.dart \
    test/core/remote_file_batch_contract_test.dart \
    test/core/file_bookmarks_provider_test.dart \
    test/features/docker_project_lifecycle_test.dart \
    test/infrastructure/remote_file_actions_test.dart
No issues found!
exit code: 0
```

## What the tests pin down

### Files - `runBatch` outcomes and target change
- Delete batch: files go to `deleteFile`, real directories to `deleteDirectory`,
  **symlinks-to-directory go to `deleteFile`** (the alias, never the rmdir path);
  per-item progress callbacks report `(1,n)...(n,n)`; refresh follows a
  non-download batch.
- Per-item failure isolation: one throwing delete is reported as `failed` with
  the error text and does not abort the remaining items.
- Illegal entries (`.` / `..` / relative / root) are marked `failed` with
  `FILE_PATH_INVALID` and perform no remote write.
- Duplicate paths collapse to one execution.
- Download batch: directories and symlinks are `skipped`/`FILE_REGULAR_ONLY`;
  a regular file is `queued` (not `completed`) and a real task appears in
  `state.transfers`; no directory refresh is issued.
- Queueing failure surfaces as `failed` + `FILE_DOWNLOAD_QUEUE_FAILED` and
  creates no task.
- `copy`/`move` without `targetDirectory` fail with `FILE_TARGET_REQUIRED`;
  with it, the **current server id** plus the exact source/target are handed to
  `RemoteFileActions.execute` per item; `skipped` (target exists) is preserved;
  an executor exception fails only that item.
- Overlapping batch rejected with `FILE_OPERATION_PENDING`; the lock is released
  afterwards. Disconnected / no active server rejected with
  `SSHConnectionException` and no remote call.
- **Target change**: switching servers mid-batch marks the remaining items
  `FILE_OPERATION_INTERRUPTED`, performs no delete on the new target, and the
  stale batch does not refresh/replace the new directory listing.
- **Stale confirmation** (`expectedServer`, core-added guard): after a server
  switch the whole batch is rejected with `StateError('FILE_TARGET_CHANGED')`
  and nothing is deleted; a matching snapshot executes normally.
- `retryTransfer`: only `failed` tasks are retried, the retry starts from offset
  0 (no resuming the failed partial bytes), the error is cleared, an unknown id
  and non-failed tasks are no-ops, and a disconnected server rejects with
  `SSHConnectionException` without silently re-queuing.

### Files - `RemoteFileActions.command`
- Only `copy`/`move` are accepted (`ArgumentError` for `delete`/`download`).
- Rejects relative paths, NUL bytes, `/` as source, target == source, and
  target inside source (descendant) before any shell string is built.
- Generated script keeps `set -eu`, requires `-d "$parent"`, uses `mv -n -T`
  (no overwrite), never `rm -rf` on the source, and single quotes are escaped so
  paths cannot break out of the quoting context.
- Outcome mapping: `VALHALLA_FILE_COMPLETED` -> `completed`; `VALHALLA_FILE_SKIPPED`
  -> `skipped` + `FILE_TARGET_EXISTS`; non-zero exit -> `failed` with
  `FILE_OPERATION_FAILED: exit N: <stderr>`; exit 0 without a marker -> `failed`.
- The generated script is executed against fixtures inside
  `Directory.systemTemp.createTempSync` only: copy preserves content and leaves
  the source; existing target -> skip and original content kept; move removes the
  source; missing source / missing target dir fail with no target created;
  recursive directory copy preserves structure and copies the symlink itself
  (does not expand its content); a descendant target via symlink is refused; the
  staging directory is cleaned up.

### Docker - `performProjectLifecycle`
- `composeProjects` groups only labelled containers, keeps `composeService`, and
  honours the active state filter and search query (a search match outside the
  filter is not grouped). Empty-string labels mean no project.
- Frozen confirmation: only the exact ids captured at confirmation run; other
  containers in the same project are untouched. Duplicates run once. Stale /
  cross-project / empty id lists are rejected wholesale with
  `DOCKER_PROJECT_TARGET_CHANGED`. Only `start`/`stop`/`restart` accepted.
- Not connected -> `SSHConnectionException`, no remote command.
- Partial failures: a failing container yields `success: false` with
  `exit N: <stderr>` while the others succeed; an executor exception fails only
  that item and the loop continues.
- `pendingActions` covers all frozen ids while in flight (and blocks a second
  overlapping batch with `DOCKER_ACTION_PENDING`) and is empty afterwards.
- Target change: after a server switch the remaining targets report
  `DOCKER_OPERATION_INTERRUPTED` and no lifecycle command reaches the new server.
- Stale confirmation (`expectedServer`, core-added guard): rejected with
  `DOCKER_PROJECT_TARGET_CHANGED`; a matching snapshot executes normally.

### Bookmarks - `fileBookmarksProvider`
- Empty state with no active server (`SERVER_NOT_FOUND` on toggle), toggle
  add/remove, normalisation (the same bookmark expressed as
  `/var/www/./my-project` toggles it off instead of appending a duplicate),
  rejection of relative/NUL paths without writing storage, persistence failure
  leaves state unchanged, and per-server isolation across server switches.

### Migration - `ConfigurationBackupService`
- Roundtrip: export JSON carries `format`/`version:1`, servers, agents
  (only agents with a live server), commands, bookmarks and default agents
  per configured server (servers without bookmarks/defaults export empty maps);
  `decode` returns equal data.
- Secret/local omission: no `privateKeyPath`, no `lastConnectedAt`, and chat
  sessions / drafts / active-server id / ACP session maps are absent from the
  exported JSON and from the `preferences` map. A hand-crafted backup still
  cannot plant a `privateKeyPath` (decode drops it -> `null`).
- Validation: `CONFIG_VERSION_UNSUPPORTED` for wrong `format`/`version`;
  malformed/truncated JSON normalises to `CONFIG_FORMAT_INVALID`; missing records
  `CONFIG_FORMAT_INVALID`; `CONFIG_SERVER_INVALID` for blank/NUL fields, port out
  of range, fractional port, string port, duplicate server id;
  `CONFIG_AUTH_TYPE_INVALID` for unsupported authType; missing required id/username
  rejected (reason code may be `CONFIG_SERVER_INVALID` or `CONFIG_FORMAT_INVALID`);
  same agent id on two different servers is allowed, duplicate `(serverId, id)`
  is `CONFIG_AGENT_INVALID`; bad execution target/binding and docker without
  reference `CONFIG_AGENT_INVALID`; duplicate/empty command `CONFIG_COMMAND_INVALID`;
  bookmark refs `CONFIG_REFERENCE_INVALID` / `CONFIG_PATH_INVALID`; default-agent
  refs to missing agents, unknown mode keys, or acp mode for a CLI-only agent
  `CONFIG_REFERENCE_INVALID`; unknown preference key or wrong preference type
  `CONFIG_PREFERENCE_INVALID`; size and item-count caps enforced.
- Append/remap: existing servers/agents/commands survive, imported records get
  fresh UUIDs, bookmarks and default-agent keys are rewritten to the new server
  ids (no legacy `valhalla_file_bookmarks::srv-1` or
  `valhalla_default_agent_acp::srv-1` keys), agents keep correct server
  references, and no active-server switch or host-key write happens.
- Existing-data protection: corrupt existing server/command JSON is refused with
  `CONFIG_EXISTING_DATA_INVALID` and the damaged value is left byte-identical.
- Preference opt-in: `applyPreferences: false` writes no preference key and no
  derived `valhalla_navigation_acp_v2`; `applyPreferences: true` writes the
  allowlisted string/bool/int/set prefs plus the navigation marker. A
  wrong-typed preference is refused before any write.
- Rollback: a failing pref write reverts servers (cache and native), restores the
  previous theme value, removes the failed bottom-nav write and the derived
  marker; an overwritten value is restored from the snapshot; rollback failure
  reports `CONFIG_IMPORT_ROLLBACK_FAILED` and still does not claim the new
  server was written; a partially successful preference write leaves no residue;
  overlapping `appendConfiguration` is refused with `CONFIG_IMPORT_PENDING` and
  the lock is released afterwards.

## Production behaviour worth attention (no production changes made)

1. `RemoteFileActions` builds a single shell command per item and detects
   outcomes via `VALHALLA_FILE_COMPLETED` / `VALHALLA_FILE_SKIPPED` markers.
   Non-GNU coreutils (`cp` without `-a`, `mv` without `-T`) are only detected by
   command failure, so on such hosts every copy/move degrades to
   `FILE_OPERATION_FAILED` rather than a precise diagnostic. The script is
   correct on GNU coreutils (verified locally in a temp dir).
2. `remote_file_actions.dart:64` triggers the `prefer_adjacent_string_concatenation`
   info (string literals joined with `+`); the behaviour is fine.
3. `LocalStorageService.appendConfiguration` imports servers/agents/commands
   sequentially and rolls back all written keys on failure. It does not guard a
   *concurrent* import within the same UI flow other than its local
   `_importingConfiguration` flag; `ConfigurationBackupService` has no idempotency
   token, so a retried network-interrupted export+import would create a second
   copy of the same servers/agents (fresh ids again) rather than being
   recognised as a duplicate. Acceptable per "append with fresh IDs", but worth a
   decision before shipping a "import again" flow.
4. Preference writes are all-or-nothing including the derived
   `valhalla_navigation_acp_v2` flag: if that single write fails after the rest
   succeeded, the whole import reports failure even though server/agent/command
   data would have been restored anyway. No data loss - only a slower rollback.
5. `decode` rejects `CONFIG_TOO_MANY_ITEMS` at 10001 records per list, but the
   size cap is 8 MB; a crafted backup near the cap can still contain ~10 000
   servers/agents each, which the importer will copy into a single JSON
   `SharedPreferences` string (fine on Android, worth watching on very large
   imports).
6. Docker: `performProjectLifecycle` validates that each ID exists in
   `state.containers` with a matching `composeProject`. If the container list is
   stale (e.g. a container was recreated with the same name), the correct
   behaviour (reject with `DOCKER_PROJECT_TARGET_CHANGED`) is observed; no
   staleness bug found.

## Notes

- Stale-confirmation coverage for both `SftpNotifier.runBatch` and
  `DockerNotifier.performProjectLifecycle` uses the core `expectedServer` guard:
  rejection is verified by the `FILE_TARGET_CHANGED` /
  `DOCKER_PROJECT_TARGET_CHANGED` reason codes plus zero remote calls.
- All shell execution in `remote_file_actions_test.dart` is confined to a
  throwaway `Directory.systemTemp` fixture; no user files are read or written.
- No assertions were weakened during this round. Three failures observed during
  an intermediate run were fixture-side (export emits empty per-server
  bookmark/default maps, imported command ids are fresh UUIDs, and the rollback
  fixture seeds `theme='light'`) and were corrected in the test, as reviewed.
