# Transfer core API and verification handoff

Scope: `lib/core/providers/sftp_provider.dart` only. Existing dirty worker,
progress, SHA-256, managed-download, and NAS integration changes are retained.
No UI, localization, dependency, or storage-schema migration changes are needed.
Implementation follows Ponytail's existing-provider scope; regression writing,
formatting, analysis, tests, builds, and device checks belong to OpenCode and
have **not** been executed by the transfer core agent.

## Public API

```dart
enum SftpTransferPauseReason { user, network, appRestart }

// Optional constructor argument and immutable field on SftpTransfer:
final SftpTransferPauseReason? pauseReason;

// Additional named arguments on SftpTransfer.copyWith:
SftpTransferPauseReason? pauseReason,
bool clearPauseReason = false,

// New SftpNotifier methods:
Future<void> pauseAllTransfers();
Future<void> resumePausedTransfers();
```

`pauseReason` is persisted as the optional JSON key `pauseReason`, using the enum
name or null. Copying preserves the reason unless a replacement is supplied;
`clearPauseReason: true` wins and clears it. Existing constructor callers remain
compatible. UI should treat a directly constructed paused task with null reason
as `user`; it should no longer infer pause reason from an error string.

Restoring stored `running` or `queued` tasks produces `paused/appRestart` even
when a stale stored reason exists. Restoring `paused` preserves recognized
reasons; missing, null, unknown, or wrong-type values fall back to `user`.
Terminal records restore with null pause reason. An app restart or server-target
restore never repopulates the in-memory reconnect retry set.

`pauseTransfer(id)` and `pauseAllTransfers()` mark eligible tasks `paused/user`,
clear a prior connection error, and remove reconnect eligibility. This includes
an already network-paused task. Completed, canceled, failed, and missing tasks
are untouched. Publishing/commit protection remains: those tasks are left alone
and expose the existing `SFTP_TRANSFER_COMMITTING` error.

`pauseAllTransfers()` captures current nonterminal IDs, blocks the scheduler
before invoking pause, and initiates all captured pauses before awaiting handle
acknowledgments. It awaits the pause operations, not file completion. A new task
added after that snapshot can run after the operation finishes. A pause command
failure is propagated and keeps that handle occupying the running slot because
its stopped state is uncertain. Switching source invalidates the old operation;
its completion cannot unlock or mutate the new target's queue.

`resumePausedTransfers()` captures paused IDs and the current target, validates
that source/target and connectivity, and synchronously queues only those still
paused. Its Future means queueing is complete, not file transfer completion. It
does not retry failed/canceled tasks or pick up pauses created after invocation.
Offline/no-target calls are no-ops. Original queue order is retained. Paused
handles are reused when their turn arrives; unopened/restored tasks use the
existing source identity and partial-file validation when starting. Single-task
resume retains its existing busy error for a live paused handle while another
task runs; an explicit resume during a pending pause acknowledgment queues the
task until the pause gate releases.

Network pauses remain limited to the existing one automatic download retry.
Only an in-memory network-paused task eligible for that retry automatically
queues on reconnect. Manual, legacy, and app-restart pauses wait for an explicit
resume. Resume, completion, cancellation, and failure clear pause reasons.

## OpenCode regression scenarios

Extend the existing fake-handle/provider fixtures in
`test/core/sftp_transfer_records_test.dart` and `test/core/sftp_provider_test.dart`.
Use controlled Futures for startup, pause, resume, and abort acknowledgments;
do not infer race coverage from timing sleeps.

1. JSON round trip for all three reasons; missing/null/unknown/non-string reason
   on paused records becomes user. Running/queued becomes appRestart regardless
   of stored reason. Terminal reason is null. `copyWith` retains, replaces, and
   explicitly clears the reason while preserving source identity and hashes.
2. Restore active and paused records while already connected. No transfer starts
   automatically. Explicit bulk resume starts one, then the next only after the
   first completes; completed/failed/canceled records remain unchanged.
3. One running plus two queued tasks: hold the running handle's pause Future.
   Call pause-all without awaiting it, then trigger queue-relevant callbacks or
   add a new task. All captured eligible tasks are user-paused immediately, and
   no additional start occurs before acknowledgment. The later-added task was
   not captured and may start after acknowledgment.
4. Call pause-all while a transfer's start Future has not produced its handle.
   Explicitly resume before startup resolves. No second start overtakes the
   first; the obsolete initial handle is aborted before queue startup resumes.
   Paused tasks must not turn canceled because an obsolete start was aborted.
   Repeat with an automatic retry: fail the first download handle with
   `SFTP_DOWNLOAD_TIMEOUT` while SSH stays connected, hold the retry's start
   Future, then pause-all and bulk-resume. There must be no third start before
   that retry startup settles/aborts. Failure scheduling happens after the old
   attempt's `finally` cleanup so it cannot erase the new attempt's startup gate.
5. Accumulate multiple retained paused handles by individually pausing running
   tasks, then call bulk resume. Verify one running task at every transition,
   one resume per retained handle, no duplicate start, preserved byte counts,
   and original queue order. An unrelated active task must finish first.
6. During a gated pause, cancel/remove a captured task and cancel another queued
   task. Resolve the gate and invoke bulk resume: canceled/deleted tasks do not
   reappear, fail, or complete. Failed records are never included in bulk resume.
   A task paused after the bulk-resume call stays paused.
7. Switch from alpha to beta while a pause/resume control Future is pending;
   include equal server IDs with changed host/credentials and colliding fixture
   transfer IDs. Late success/error cannot change beta's records, notifications,
   running slot, or scheduler gate. Switch back and check persisted reasons.
8. Download disconnection creates network pause with zero speed; reconnect uses
   the existing single retry. Another disconnect after that retry fails. Manual
   pause (including pause-all on a network-paused task) blocks automatic recovery.
   A late transport failure after manual pause does not overwrite that pause.
9. A failed pause acknowledgment must not let another task run concurrently.
   A failed queued-handle resume acknowledgment exposes the existing mapped error
   and keeps the running slot occupied until the handle resolves or the user
   cancels, since acknowledgment failure cannot establish worker completion.
10. Publishing handles/finalizing managed downloads remain protected from pause
    and cancellation. Retest managed `.part` rename, source-change rejection,
    local SHA-256 verification, notification/open completion paths, and NAS
    managed downloads. Switching away during finalization must not leave stale
    publishing protection when returning to the same transfer record.

Existing tests for download retry bounds, paused progress, per-task busy resume,
record isolation, upload cleanup, and serial completion should remain in scope.
Device/background/network behavior remains an explicit unverified requirement
until OpenCode runs the designated isolated-server/ADB workflow.
