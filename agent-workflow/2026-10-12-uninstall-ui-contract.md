# Selective uninstall: exact UI API and safety verification contract

Implementation in progress; no verification claimed. Product UI/ARB only AgY in
original Valhalla session. Tests, formatting, static analysis, generation and
builds only OpenCode this round. Preserve the dirty workspace. Do not deploy or
delete data on production servers. The pinned disposable VM is the only allowed
real mutation target after its identity/safety constraints are read again.

## Minimal UI flow (AgY)

Existing entry: `AppInstalledTab._handleUninstall`. Keep ordinary uninstall and
all existing unrelated power actions working. Do not send filesystem paths from
UI to the cleanup executor, do not invoke SFTP deletion, and do not synthesize a
cleanup plan. Capture active server connectionKey; guard every async completion.

1. Read `notifier.inspectUninstall(deployment)` while presenting a loading state.
   This is read-only. Failure/unsupported capabilities disables data cleanup,
   never ordinary data-preserving uninstall. Keep a cancel action available.
2. Render `ApplicationUninstallPreview.targets`, each initially UNCHECKED.
   Same paths are deduplicated by core. Show full source path, service/target
   references, read-only property and risk. `target.selectable == false` cannot
   be overridden by a checkbox or risk acknowledgement.
3. For each selected risky target require explicit acknowledgement of exclusive
   use and permanent deletion of its full contents. This is task-scoped consent,
   not a durable ownership claim. Show the exact selected path list on a second
   confirmation, requiring the exact application name. No recycle bin and no
   silent deletion of the unselected application data root.
4. Submit through the existing task path, then show task command/log/result UI.

```dart
final preview = await notifier.inspectUninstall(deployment);
// UI collects selectedKeys (Set<String>), acknowledgedRiskKeys (Set<String>),
// and confirmationName. There is no default preselection.
final plan = await notifier.prepare(
  ApplicationOperation.uninstall,
  deployment: preview.deployment,
  uninstallSelection: selectedKeys.isEmpty
      ? null
      : ApplicationUninstallSelection(
          previewId: preview.id,
          selectedKeys: selectedKeys,
          acknowledgedRiskKeys: acknowledgedRiskKeys,
          confirmationName: confirmationName,
        ),
);
// Guard captured server after prepare and before execute; core guards it too.
final task = await notifier.execute(plan);
```

If preview failed or no target is selected, use the original `prepare(uninstall,
deployment: deployment)` / execute route. It still uses compose down WITHOUT -v,
preserves all data/volumes, and does not require Python or cleanup confirmation.
No text input is needed for ordinary preserve-data uninstall. A preview is
SINGLE-USE: `_prepareCleanup` consumes it before validation, not only on success.
Call prepare only after final confirmation. If prepare fails, the user changes
selection/name after preparing, or the plan expires, discard it and INSPECT AGAIN.
Clear selected keys, risk acknowledgements and typed name for the new preview;
the user must confirm again before a new prepare. Never reuse the consumed ID.
A preview or plan older than five minutes is expired; never auto-execute.

If preview.inspectionError is non-null, disable ALL cleanup selections regardless
of individual target flags. Ordinary preserve-data uninstall remains available.
Do not trim/case-normalize the typed confirmation name. All async boundaries
also require the same current connected server, not just a matching saved ID.

## Exact model fields (already on disk)

- `ApplicationUninstallPreview`: `id`, `deploymentId`, `deployment`
  (ApplicationDeployment), `fingerprint`, `targets`, `createdAt`,
  nullable `inspectionError`.
- `ApplicationCleanupTarget`: `key`, `source`, `serviceTargets` (List<String>),
  `readOnly`, `risks` (List<String>), nullable `blockedReason`, `identity`
  (private safety metadata; do not present it as editable); computed `selectable`
  and `requiresRiskAcknowledgement`.
- Risk codes: `legacy` means NO durable exclusive-ownership proof is recorded
  (including new installs under the present schema), NOT proof that an app is old;
  `external` means outside this app's configured data root; `media` means read-only
  or a media-like source path. Translate to honest warnings, not raw keys.
- `ApplicationUninstallSelection`: immutable `previewId`, `selectedKeys`,
  `acknowledgedRiskKeys`, `confirmationName` (exact name, case/space sensitive).
- `ApplicationTask.uninstallCompleted` defaults false for old records.
  `cleanupResults` defaults empty. Each ApplicationCleanupResult has `key`,
  `source`, `outcome` and nullable `reasonCode`. Outcomes:
  `pending`, `removed`, `alreadyAbsent`, `retained`, `failed`.
- `ApplicationOperationPlan.cleanupPlan` is internal. UI must not construct or
  modify it. `cleanupOnly` is how core skips compose down on a confirmed retry.

Blocked/error codes all use `APP_CENTER_CLEANUP_` prefix:
`PATH_INVALID`, `PROTECTED_PATH`, `SYMLINK_PATH`, `MOUNTPOINT_PROTECTED`,
`SHARED_PATH`, `OVERLAPPING_MOUNT`, `NOT_DIRECTORY`, `VOLUME_PROTECTED`,
`ALREADY_ABSENT`, `CONFIG_CHANGED`, `OWNERSHIP_CHANGED`, `TARGET_CHANGED`,
`CAPABILITY_UNAVAILABLE`, `INSPECTION_INCOMPLETE`, `SELECTION_INVALID`,
`ACKNOWLEDGEMENT_REQUIRED`, `PATH_CHANGED`, `DELETE_FAILED`, `CLEANUP_LIMIT`,
`RETRY_UNAVAILABLE`, `NOT_PREVIOUSLY_SELECTED`, `RESULT_INVALID`.
Use a generic localized safe-retention fallback for future unknown codes.

Important: a parent containing another distinct mount target is disabled in this
first implementation; users can select independently safe leaf directories.
This avoids implicitly deleting a retained/protected descendant. Named/anonymous
volumes and file binds are visible but never selectable in this release.

## Completion and explicit retry

When `uninstallCompleted == true` and task failed or any result failed/retained,
say “Application uninstalled; some data was not cleared”, NOT complete success
and NOT “application still running”. A failed cleanup can already have removed
some files inside its selected directory; `failed` is not a rollback promise.
Show exact remaining paths and copyable sanitized command/output. Pending plus
failed task means cleanup was not confirmed complete, not permission to replay it.

Retry is available only for a FAILED uninstall task with uninstallCompleted true
and at least one result other than removed/alreadyAbsent:

```dart
final preview = await notifier.inspectCleanupRetry(task);
// Same unchecked selection -> per-risk acknowledgement -> app-name confirmation.
// Only previously selected unfinished targets can be selected. No new targets.
final plan = await notifier.prepare(
  ApplicationOperation.uninstall,
  deployment: preview.deployment,
  uninstallSelection: ApplicationUninstallSelection(
    previewId: preview.id,
    selectedKeys: selectedKeys, // MUST NOT be empty for retry.
    acknowledgedRiskKeys: acknowledgedRiskKeys,
    confirmationName: confirmationName,
  ),
);
await notifier.execute(plan);
```

An empty retry selection only closes/cancels; never fall back to ordinary
uninstall from this branch. Reinstalled deployment, changed target, changed path,
active previous worker or unknown inspection blocks retry. Core does NOT repeat
compose down, does not restart the app, and does not automatically retry on
reconnection. The previous task remains an immutable history item.

## OpenCode: focused safety tests and review

Do not just assert generated shell contains a string. Extract the actual raw
Python script from `ApplicationCleanupHelper.script` into an isolated temporary
fixture and exercise it with fixture-controlled Docker responses; never point it
at current real Docker. Test Dart API/provider seams as well. No production
cleanup, no removing user caches, and no global rm. Use apply_patch for tests.

Read-only command fixtures required by helper: machine-id; docker info formats
`{{.ID}}` and `{{.DockerRootDir}}`; local context endpoint; `docker ps -aq --no-trunc`
and batched docker inspect (complete IDs); compose config --format json; private
control owner/configuration/compose files; all other managed deployment records;
passwd home directories; /proc/self/mountinfo and fdinfo mount IDs. Missing,
malformed, oversized or incomplete inventory must fail closed. Python >=3.8 and
Linux O_NOFOLLOW/dir_fd/scandir/fd mount IDs are required only for cleanup.

1. Baseline: null selection emits original down without -v/prune/data deletion;
   existing worker and VM data-sentinel preservation regressions still pass.
   Old model JSON with no new fields loads; new task results persist across reload.
2. Read-only preview: no writes/mkdir/remove; derive only compose/configured bind
   keys, deduplicate refs, compare actual own-container mounts. Unknown/changed
   mount/config or incomplete other-app inspection blocks cleanup, not uninstall.
3. Selection: default none; unknown/blocked keys rejected; legacy/external/media
   require each risk acknowledgement and exact name confirmation. External leaf
   directory can succeed; no silent owner marker creation. Reject parent targets
   containing a retained/protected/other mount target. All volumes stay preserved.
4. Safety: /, every passwd home, system and sensitive/control/runtime trees,
   DockerRootDir (including custom path), native /var/lib/valhalla-native-jellyfin
   and ancestors/descendants blocked. Symlink in any path component, file bind,
   same/ancestor/descendant shared reference (including STOPPED containers), direct
   and nested bind mountpoints blocked. Same-filesystem bind aliases are checked
   via mountinfo filesystem coordinates, not only lexical realpath prefixes.
   Map protected paths too: if controlRoot or DockerRootDir is a bind alias of
   another directory, selecting any backing-path child must remain blocked.
5. Races: change config/compose, target machine/daemon/client, directory inode or
   mount ID between preview/prepare/worker; no deletion. Add sharing before worker
   or after down; retained result. Swap descendant for link/mount during traversal:
   no target outside the authorized directory is followed/deleted. Validate
   snapshot under existing server flock and recheck before EACH cleanup target.
   Rename a child or selected root outside the authorized lexical tree after
   its fd is opened: validate the complete attachment chain BEFORE each unlink
   or rmdir, stop with failed/retained, and preserve the relocated sentinel.
   Covered/stacked bind layers on the same mountpoint must fail closed rather
   than use the first mountinfo row for protected/shared-path calculations.
6. Failure: down failure causes no cleanup; later cleanup permission/error/limit
   causes per-target failed/retained, preserves marker/outcomes and exits nonzero.
   A partially cleared directory is failed, not falsely retained untouched.
   Already-absent target after down is idempotent. Other safe selected targets
   may finish; unselected sentinels/volumes/control metadata survive.
   A missing control/ownership file during inspection or a disappearing child
   during recursion is NOT proof the selected root is absent; it must not mark
   the whole root alreadyAbsent or the task succeeded.
   Shared monotonic budget includes Docker inventory plus every target and
   directory scan (85s inspection/validation; 600s total cleanup). Slow repeated
   commands must not acquire a fresh full timeout for each target indefinitely;
   budget expiry persists failed/retained outcomes and never promises rollback.
   Docker stdout is capped while streaming (32MiB), not after subprocess.run
   has buffered an arbitrary amount. Timeout/overflow kills only the spawned
   readonly-command process group, never a container/daemon or previous worker.
7. Task transport: cleanup.json atomic bounded updates, uninstall-complete marker,
   readTask distinguishes uninstall completion from cleanup failure. Spoofed extra
   result keys/paths and malformed/oversized/symlink results fail safely. Persist
   results even while the task stage itself did not change; preserve on sync error.
8. Retry: only failed/finished original selected keys; new read-only preview and
   confirmation; reject newly installed deployment/current ownership change;
   no repeated down; empty retry selection cannot use ordinary uninstall branch.
   Connection recovery only reads original worker/result, never replays removal.
   An interrupted worker may leave remote state checking/applying even though
   readTask reports failed125. Allow explicit retry only after readonly
   boot-id/PID/starttime proves the old worker inactive; unknown/live is blocked.
   Do not rewrite its state or repeat down, including server-reboot recovery.
9. UI (AgY-owned): 320dp/2x/RTL selection/path visibility, second name confirmation,
   checked state resets on new preview, target switch disables callbacks; source
   changes/close ignore late preview results; partial status and explicit retry.

Root will coordinate analysis/tests/VM/build/ADB after these gates. Record exact
commands, passing counts and unresolved failures; do not claim device acceptance
from installation alone. Do not weaken existing app-center/NAS regressions.
