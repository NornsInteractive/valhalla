# OpenCode focused files/application regressions

Verified free model opencode/big-pickle (input/output/cache all zero), no subagents.
Write scope: test/core/remote_file_batch_contract_test.dart (extend existing fakes),
NEW test/core/file_recent_directories_test.dart, NEW
test/core/application_preflight_health_test.dart, and append report here.
Root owns product, AgY owns UI. Main OpenCode verifier owns all Flutter test,
pub-get/generation/build commands. Only standalone dart analyze on owned files is
allowed here; do not run Flutter or change dependencies/product/other tests.

Keep cases small and deterministic; do not fabricate model APIs. Reuse existing
test/support/application_center_fakes.dart constants and existing batch provider
fixtures. New behavior needs regression proof before packaging:

- Recent directory storage/provider: normalized absolute valid paths, last20
  deduplicated, per-server isolation, invalid path rejected, late old-server record
  cannot replace current server's visible recent list.
- retryFailedBatch: only failed entries retried, successes/skips not replayed;
  re-list size/mtime/type change rejects source, expectedServer mismatch rejects.
  Extend current test/core/remote_file_batch_contract_test.dart helpers rather than
  inventing a replacement service/provider. Preserve existing tests.
- ApplicationDeploymentService.reconcile: fake SshCommandExecutor, owned deployment
  marker and metadata; docker ps -aq IDs then docker inspect JSON fields. Assert
  running+healthy => running, unhealthy/starting => partial, no healthcheck='none',
  stopped/missing, malformed/bounded IDs reject; roundtrip services in deployment JSON.
- prepare: use real service with a fake connected SSHClient/executor following
  existing fixture patterns. Read-only preflight df -Pk data row supplies bytes,
  zero and invalid df reject; no install/deploy called. Update comparison categories
  exclude secret values. If setup would require enormous fake, report remaining
  gaps explicitly rather than mock away the method under test.

No remote network/user server writes or Agent prompts. Finish authoring and report
exact files + static-check results. Do not claim tests have passed without execution.

## Report

Authored (unverified — printed during verification planning, then re-derived from the
source; not executed):

1. `test/core/remote_file_batch_contract_test.dart` (extended):
   - `_item` gained `int modifiedEpoch = 0`.
   - `_RecordingRemoteActions` gained per-path `outcomes`/`failures` maps with
     fallback to the existing `outcome`/`error` (existing tests untouched).
   - New `group('retryFailedBatch', ...)`: only-failed retried (delete), successes and
     skips not replayed (copy), size+mtime change reject, file->directory type change
     reject, item missing from listing reject, unchanged-source retry succeeds,
     expectedServer mismatch -> FILE_TARGET_CHANGED (nothing lands on new server),
     failed path not in original items -> empty no-op batch.
2. `test/core/file_recent_directories_test.dart` (NEW): switchable active-server fake,
   5 tests (normalization, dedupe + last-20, per-server isolation, invalid paths throw
   `FILE_PATH_INVALID` synchronously with nothing written, late old-server record).
3. `test/core/application_preflight_health_test.dart` (NEW): scripted
   `SshCommandExecutor` + fake SSHClient/Session.
   - `reconcile`: running+healthy and health='none' -> running (services roundtrip via
     toJson), starting/unhealthy -> partial, exited/created -> stopped, no containers ->
     missing (no inspect), malformed/>100 ids and row count/field mismatches ->
     APP_CENTER_HEALTH_INVALID, empty deployment.json -> null (no docker ps),
     ownership marker / tampered deployment id -> APP_CENTER_OWNERSHIP_CHANGED,
     server key mismatch -> APP_CENTER_TARGET_CHANGED with zero commands.
   - `prepare`: df data row -> availableBytes (786432*1024) and no compose up/mkdir/cat
     >/docker run commands and no client sessions; zero df -> APP_CENTER_DISK_FULL;
     header-only and negative df -> APP_CENTER_DISK_CHECK_FAILED; install preview is
     redacted; update runs a full read-only reconcile prerequisite (marker, ps, inspect)
     and compares sections.

Static check: `dart analyze` of the three files above -> 0 issues. Tests were NOT run
(every Flutter test execution is owned by the flagship verifier).

Extra findings (not executed):
- DEFECT candidate (whitelist violation): `changedSections` in `prepare` json-compares
  full environment maps including secret values, so an update changing only a secret's
  value flags `'environment'`. Requirement says secret values must be excluded. Authored
  regression asserts `isNot(contains('environment'))` (expected to FAIL when run).
- Defect candidate: `FileRecentDirectoriesNotifier.record` throws synchronously
  (non-async) while `toggle` is async; the marked-up section III lists methods with
  different async shapes. Tests assert the sync-throw and mark it deliberately.
- Preview redaction is exact-substring replacement of `jsonEncode(value)`; evaluate
  before claiming secrets <4 chars or values containing quotes/backslashes stay hidden
  in the compose preview (string literals may not round-trip identically).
