# 2026-10-11 Transfer Draft Follow-up Validation

## Scope

Narrow test-fixture follow-up on `test/core/ai_chat_draft_failure_test.dart`, `test/core/sftp_transfer_records_test.dart`, and `test/features/sftp_file_view_test.dart`. No production edits, no UI, no ARB/generation, no building/ADB/commits.

## Changes

### `test/core/ai_chat_draft_failure_test.dart`

Fixed synchronous closure with await:

- Moved `SharedPreferences.setMockInitialValues({})` + `await SharedPreferences.getInstance()` into an async `setUp` block.
- Each test now constructs `_FlakyDraftStorage(prefs, n)` directly and passes the instance to `container()`.
- Removed the `() => storage = _FlakyDraftStorage(await SharedPreferences.getInstance(), n)` closure pattern.
- Both checkpoint failure recovery assertions preserved exactly.

### `test/core/sftp_transfer_records_test.dart`

Fixed the completed-download persistence fixture (was invalid):

- **Removed** pre-creation of final `payload.bin` — managed download must refuse collisions.
- **Set** `ops.uploadAutoFinish = false` so the handle does not auto-finish before `.part` is written.
- **Create only** `.part` file after handle starts.
- **Assert final absent** BEFORE `handle.finish()`.
- **Assert final present** with exact bytes `[7, 7, 7]` and correct sha256 hash AFTER finish.
- **Preserved** all hash persistence expectations (`task.localSha256`, `task.transferredBytes`, `storage.getTransferRecords`).

Fixed the tampered-hash reveal test:

- **Added** `DOWNLOAD_OPEN_FAILED` error message assertion (was missing).
- **Added** `revealThrows` field to `_StubDownloads` for native reveal failure injection.

Added native reveal failure test case:

- `a native reveal failure refuses to open` — sets `revealThrows`, calls `revealCompletedTransfer`, asserts `downloads.revealed` is empty and `DOWNLOAD_OPEN_FAILED` is set.

### `test/features/sftp_file_view_test.dart`

Updated `_TestSftpNotifier.closeFileEditor` override to match production signature:

- `void closeFileEditor()` → `void closeFileEditor({int? editorToken})`

## Test Results

Command: `flutter test test/core/ai_chat_draft_failure_test.dart test/core/sftp_transfer_records_test.dart test/core/sftp_provider_test.dart test/features/sftp_file_view_test.dart`

**Final: 102 passed, 0 failed.**

| File | Result |
|------|--------|
| `ai_chat_draft_failure_test.dart` | All pass |
| `sftp_transfer_records_test.dart` | All pass |
| `sftp_provider_test.dart` | All pass |
| `sftp_file_view_test.dart` | All pass |

The reporter establishes the combined count, not a separately parsed per-file
count. OpenCode's outer 240-second wrapper expired after the Flutter command
had exited 0 and this report was written; there was no build or installation.

### Previously failing tests now passing

1. `a completed download persists its hash at completion` — fixed by removing pre-created final file, disabling auto-finish, and asserting correct `.part` → final rename behavior.
2. `a tampered hash of the same length refuses to open` — Codex fixed the uncaught
   verification exception in revealCompletedTransfer; the test additionally
   checks DOWNLOAD_OPEN_FAILED. Adding an assertion alone was not the fix.

### New test added

- `a native reveal failure refuses to open` — verifies that when `revealFile` itself throws, `DOWNLOAD_OPEN_FAILED` is set and no uncaught errors escape.
