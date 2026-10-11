# v1.0.4 SFTP Test Fixture Compatibility Fix

Date: 2026-10-11
Scope: test/infrastructure/sftp_download_incomplete_test.dart (test fixture only)
Production code: unchanged. Security posture: unchanged.

## Problem

The full suite compiled and ran this file and reported 5 failures of the same
kind: `NoSuchMethodError _Sftp.absolute`. Cause: the canonical binding
`SftpClientService._startDownload` (lib/infrastructure/sftp/sftp_client_service.dart:610)
calls `await sftp.absolute(remotePath).timeout(operationTimeout)` to build the
identity record used for source-change detection. The `_Sftp` test double
implemented `SftpClient` but did not override `absolute`, so the inherited
`noSuchMethod` stub threw. This was purely a fixture compatibility gap, not a
production defect.

## API Verification

Read the exact installed dartssh2 signature from the pub cache:

- Package: dartssh2-4.1.0 (~/.pub-cache/hosted/pub.dev/dartssh2-4.1.0)
- File: lib/src/sftp/sftp_client.dart:182
- Declaration: `Future<String> absolute(String path) async`

The implementation performs an SFTP `realPath` round trip. For inputs that are
already absolute (all fixtures in this file: `/big.bin`, `/small.bin`,
`/proc/uptime`), a conforming server resolves them to the identical string, so
an identity implementation is faithful for these tests.

## Change

Added one override to the `_Sftp` fake, matching the installed signature
exactly:

```dart
@override
Future<String> absolute(String path) async => path;
```

No other edits. No assertions, test counts, expected values, or error-handling
expectations were touched. No production file was modified and no security
control (source-identity check, timeout, handle release) was relaxed.

## Verification

Targeted run (full unique log: /tmp/opencode/v104-targeted-fluttertest.log):

```
flutter test --no-pub test/infrastructure/sftp_download_incomplete_test.dart --reporter expanded
```

Result: exit code 0.

```
00:00 +0: loading /workspace/projects/valhalla/test/infrastructure/sftp_download_incomplete_test.dart
00:00 +0: server ends the stream before the advertised size fails as incomplete
00:00 +1: a truncated payload keeps the partial bytes it already wrote
00:00 +2: a complete reply finishes without a trailing read
00:00 +3: a zero/unknown size reads until the server reports EOF
00:00 +4: a failed transfer releases both handles instead of leaking them
00:00 +5: All tests passed!
```

Preserved behavior proofs per test:

- Truncated stream still throws `SFTPException` with message
  `SFTP_DOWNLOAD_INCOMPLETE` (lines 39-48 assertions intact).
- `remote.readCalls == 2` after first empty reply (stop after empty read).
- `remote.closes == 1` per transfer; `== 2` after the re-open test
  (both remote and local handles released, no leak).
- Partial bytes preserved: written file length 40, `transferredBytes == 40`.
- Complete reply: `transferredBytes == 100`, `readCalls == 1`, `closes == 1`,
  file length 100.
- Zero/unknown size: reads until EOF, `transferredBytes == 10`, `closes == 1`.
- `SftpNotifier.downloadErrorCode` mapping assertion re-verified.

Static analysis:

```
flutter analyze --no-pub test/infrastructure/sftp_download_incomplete_test.dart
No issues found! (ran in 1.0s)
```

Formatting: `dart format test/infrastructure/sftp_download_incomplete_test.dart`
reported 0 files changed (already conformant). Only this file was touched.

## Notes

- The original full-suite gate recorded these 5 failures; the whole suite will
  be rerun after this fixture fix to confirm they are resolved end to end.
- No other errors were encountered in the targeted run.
