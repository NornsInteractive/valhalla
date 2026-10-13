# Browser core/provider verification — 2026-10-13

## Result

The focused six-file gate passed: **75 tests, zero failures**. Validation ran directly under this round's user authorization after the OpenCode writers stopped. No UI, ARB, full-suite, build, deployment, or remote server operations were performed by this task.

Command:

```sh
flutter test --no-pub --concurrency=2 --reporter=expanded \
  test/core/remote_browser_test.dart \
  test/core/nas_browser_provider_test.dart \
  test/infrastructure/acp_workspace_files_test.dart \
  test/core/nas_saved_probe_test.dart \
  test/core/nas_source_connection_provider_test.dart \
  test/core/nas_source_integration_review_test.dart
```

Observed final output: `00:02 +75: All tests passed!` (exit 0). The preceding 73-test run also passed before adding two late-SFTP-channel regressions.

## Added/completed coverage

| File | Coverage |
| --- | --- |
| `test/core/remote_browser_test.dart` | Completed the partial OpenCode draft; root boundaries, opaque library IDs, immutable selections/batches, late target rejection, request cancellation before first item, blocked backend teardown, late errors, independent concurrent lists, bounded previews, borrowed-service ownership, missing-only fallback, late Host/Agent SFTP channel cleanup without closing SSH. |
| `test/core/nas_browser_provider_test.dart` | New real-provider tests: drafts do not save/select, saved-source credential compatibility, endpoint/type/user/user ID/tunnel isolation, SMB domain prefill/preservation/explicit clear, credential-only save invalidating late reads, secure-write-success/metadata-or-selection-failure generation guards, successful explicit resave recovery, failed secure write preserving leases, legacy SFTP ID fallback and missing-profile rejection, real HTTP probe isolation, HTTP-header-wait cancellation. |
| `test/infrastructure/acp_workspace_files_test.dart` | Kept existing tests; added Docker user binding, `ld`/`lf`/`lN`/`lL` parsing and alias paths, request cancellation independent of another list/preview/SSH, and closing late SSH execute channels. |

The other three existing suites ran unchanged to check saved probes, SSH reconnect/client replacement, source deletion/editing, and DAV-root compatibility.

The completed draft contained invalid `const StateError`, nonexistent `Future.isCompleted`, instance-identity error expectations, and a root-boundary assertion using `/` as its root. Those were corrected in the tests; no product behavior was weakened to make assertions pass. The initial new fake's SSH `close` signature was corrected to the actual `Future<void>` API before its successful run.

Only the three owned test files were formatted; their `git diff --check` passed. No additional production bug was found by this focused run.

## Limits and known risks

- This is automated core/provider coverage, not widget or ADB acceptance. NAS protocol/library scan tests belong to the NAS adapter task; no duplicate protocol suite was written here.
- Cancellation tests verify immediate consumer cancellation and owned-resource closure with controlled SSH fakes plus a real loopback HTTP server. They do not claim a remote server has acknowledged cancellation of an in-flight SSH channel-open handshake.
- The partial-save guard is process-local. The pre-existing secure-storage/metadata split is not an atomic transaction across application restart; playback adapter persistence behavior remains outside this guard.
- Global static analysis, release signing/build and device installation are still the parent task's gates; this result does not claim those have passed.
