# Background Recovery - Release Verification

Worker: protocol/data/widget test owner (space-bunny-free, free tier)
Workspace: /workspace/projects/valhalla
Device: 127.0.0.1:14251 (sdk_gphone64_x86_64)
Scope of this round: unblock the suite hang, re-run every gate, then build and
install the release APK with data preserved. No production behaviour edits (only
`dart format` on changed production files and `flutter gen-l10n`).

## 1. Test-harness deadlock (root-reported) - fixed

Root's diagnosis was correct and the first attempt I made was wrong: I had added
`Future.delayed(Duration.zero)` and `Future.delayed(20ms)` plus
`repository.listSessions(...)` calls to the `addTearDown` in
`test/support/temp_chat_db.dart`. Under `testWidgets` the teardown runs in a
FakeAsync zone with no clock advance, so those waits never completed, and the
repository read queued new isolate work behind FakeAsync-bound writes. That is
what stalled `chat_run_settings_test.dart` for minutes.

Final fix - original cleanup plus a bounded retry for the one error that is
actually a race, no timers and no repository lifecycle invented for tests:

```dart
if (!dir.existsSync()) return;
for (var attempt = 0;; attempt++) {
  try {
    await dir.delete(recursive: true);
    return;
  } on FileSystemException catch (error) {
    if (error.osError?.errorCode != 39 || attempt >= 4) rethrow;
  }
}
```

- errno 39 is ENOTEMPTY: a provider still finishing one unawaited SQLite write
  recreates the file mid-walk. Each attempt is a real async syscall, so the event
  loop turns in between and the writer can retire.
- Any other IO error, and an ENOTEMPTY that survives the last attempt, is
  rethrown - nothing is masked.
- No `Future.delayed`/`Timer`, no `runAsync`, no repository drain: safe under
  both FakeAsync and real async.

Validation:

```
$ timeout 60 flutter test test/features/chat_run_settings_test.dart --reporter expanded
00:01 +6: All tests passed!
EXIT=0                      # log: /tmp/opencode/hang_probe2_chat_run_settings.log
```

## 2. Gates

| Gate | Command | Result | Exit | Log |
|---|---|---|---|---|
| l10n generation | `flutter gen-l10n` | l10n.yaml-driven, no diff churn | **0** | `/tmp/opencode/genl10n_release.log` |
| formatter (changed production files) | `dart format <27 changed lib/*.dart>` | 15 files reformatted | **0** | `/tmp/opencode/format_production.log` |
| analyzer (mid-round) | `flutter analyze --no-pub` | 13 issues, 0 errors | 1 | `/tmp/opencode/analyze_release.log` |
| analyzer (re-run after upstream edits) | `flutter analyze --no-pub` | **No issues found!** | **0** | `/tmp/opencode/analyze_final_confirm.log` |
| full test suite | `flutter test --reporter expanded` | **+1421 ~17, 0 failures** | **0** | `/tmp/opencode/full_suite_release.log` |
| full test suite (re-run on final tree) | `flutter test --reporter expanded` | **+1421 ~17, 0 failures** | **0** | `/tmp/opencode/full_suite_release_final.log` |
| whitespace/diff check | `git diff --check` | clean | **0** | `/tmp/opencode/diffcheck.log` |
| release build | `flutter build apk --release` | `app-release.apk` | **0** | `/tmp/opencode/build_release_apk.log` |

`PIPESTATUS`/`set -o pipefail` was used on every piped command; no `tail`/`grep`
pipeline was allowed to mask an exit code, and no partial run was accepted as a
pass.

### Analyzer

The mid-round run still showed 13 lint findings (recorded for the record, all in
production files this round may not edit):

```
   info x12  curly_braces_in_flow_control_structures:
            lib/core/providers/ai_chat_provider.dart:534,548,553,1501,1570,2066,2081
            lib/core/providers/sftp_provider.dart:428,431
            lib/data/repositories/chat_repository.dart:359
            lib/features/files/sftp_file_view.dart:378
            lib/infrastructure/acp/acp_client_adapter.dart:562
warning      lib/features/dashboard/dashboard_view.dart:1325:44 unused_element_parameter
             ("A value for optional parameter 'key' isn't ever given")
```

Upstream (root / AgY) cleared those while the device checks were running, so the
authoritative re-run reports **`No issues found!` (exit 0)**. The build/install
below therefore ran against a fully green tree, and the full suite was re-run on
that same final tree to keep the reported pass honest.

## 3. Fixes made this round (tests only)

1. `test/support/temp_chat_db.dart` - teardown deadlock/race fixed as above.
2. SFTP fixtures missing the new connection dependency. `ServerConnectionNotifier`
   watches `sshClientManagerProvider` -> `sshHostKeyVerifierProvider` ->
   `localStorageServiceProvider`, which throws outside `runApp`, so every widget
   test that mounted the real notifier died with
   `UnimplementedError: LocalStorageService must be initialized before runApp`
   (51 failures). Added a connected `serverConnectionProvider` fake to:
   - `test/features/sftp_file_view_test.dart`
   - `test/features/sftp_transfer_list_test.dart`
   - `test/features/sftp_two_row_header_test.dart`
   - `test/features/sftp_open_transfers_request_test.dart` (both the shell
     container and the standalone SFTP app)
   - `test/features/multi_column_lists_test.dart` (the 3 SFTP cases)

   Connected in every case because each one drives real file/transfer
   interactions; **no action assertion was changed, removed or relaxed.**
3. `test/core/ai_chat_provider_test.dart` - "keeps an explicitly selected ready
   agent across registry updates" was missing the `activeServerProvider` override
   its sibling cases all have. The registry listener only keeps a selection while
   `profile.serverId == activeServerId` (`ai_chat_provider.dart:1032`), so with a
   null active server the explicit choice was dropped and codex won. Added the
   existing `_StubActiveServer` override; the assertion itself is untouched.

## 4. Reported to others, not touched

- **Core worker - `test/core/connection_lifecycle_test.dart`** (detached healthy
  SSH reconnection expectation): **RESOLVED by the core worker.** The earlier
  note that this was still an open blocker is obsolete - `test/core/connection_lifecycle_test.dart`
  now passes, which the full suite in this document proves (1421 pass / 0 fail,
  exit 0). Nothing was changed by me in that file.
- **Core worker**: 2 heartbeat timer tests via
  `debugRegisterClient(startKeepAlive: true)`; not mine, not touched.
- **AgY**: the `dashboard_view.dart:1325` unused optional `key` and the 12 brace
  infos were already cleared upstream before the analyze run below.

## 5. Release artifact (CURRENT - supersedes the earlier build)

| Field | Value |
|---|---|
| Path | `build/app/outputs/flutter-apk/app-release.apk` |
| Bytes | 123108211 |
| SHA-256 | `1af486e7dec5c32ea1cc6ba487d2a4f1a1e3b60a3208d97fe381ca571610bdb3` |
| mtime (UTC, from `TZ=UTC stat`) | 2026-09-30 16:12:14.182475863 +0000 |
| Build duration | Gradle `assembleRelease` 71.4s |
| Build log | `/tmp/opencode/final_build_release.log` |

Superseded artifact from the previous round (kept only for traceability, **no
longer current**): SHA-256 `9bcfc7f21c283a25bbffc8148c296b243a9287cae2ec9f22899215f1c8594edb`,
same byte size 123108211, mtime 2026-09-30 16:02:04 UTC. The two builds differ
only because the six previously-untracked Dart files were formatted before this
one; both were signed by the same certificate.

## 6. Signature gate (checked before and after installing)

```
$ apksigner verify --print-certs app-release.apk
Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
Signer #1 certificate SHA-256 digest: 2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9

$ adb pull <installed base.apk>   # com.antigravity.valhalla.valhalla
Signer #1 certificate SHA-256 digest: 2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9

SIGNATURE_MATCH=yes
```

Re-verified after this round's install from the freshly installed base.apk:
**`SIGNATURE_MATCH=yes (2faa583f…37e9)`**. Logs:
`/tmp/opencode/final_apk_cert.log`, `/tmp/opencode/final_cert_installed.log`
(earlier round: `/tmp/opencode/apk_cert_new.log`,
`/tmp/opencode/apk_cert_installed.log`).

## 7. Install with data preserved (CURRENT install)

Pre-install observation: app was running as pid 13873. The last 300 logcat lines
showed no ACP/CLI prompt/stream/generation markers; this limited log check does
not prove that no remote task was active. No force-stop or real Agent prompt
was issued; the authorized update used `install -r` without uninstall/clear.

```
INSTALL_START_UTC=2026-09-30T16:12:25Z
$ adb -s 127.0.0.1:14251 install -r build/app/outputs/flutter-apk/app-release.apk
Performing Streamed Install
Success
INSTALL_EXIT=0
INSTALL_DONE_UTC=2026-09-30T16:12:26Z
```

| Field | Value |
|---|---|
| Package | `com.antigravity.valhalla.valhalla` |
| dataDir | `/data/user/0/com.antigravity.valhalla.valhalla` (unchanged) |
| versionName / versionCode | 1.0.0 / 1 (unchanged) |
| firstInstallTime | 2026-09-23 03:26:04 (**unchanged** -> not uninstalled) |
| lastUpdateTime | 2026-10-01 00:11:57 +0800 = 2026-09-30T16:11:57Z (**advanced** by this install) |
| Signature after install | `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` (identical) |

No `uninstall`, no `pm clear`, no data wipe. `run-as` cannot list app data on a
release build (not debuggable), so preservation is evidenced by the unchanged
`firstInstallTime`/`dataDir` plus `install -r` reporting `Success`.

Superseded install from the previous round (traceability only, **not current**):
started 2026-09-30T16:03:47Z, `lastUpdateTime` 2026-09-30T16:03:18Z.

## 8. Read-only runtime checks (CURRENT)

All UTC timestamps from `/tmp/opencode/final_runtime.log`.

| Check | UTC | Observation |
|---|---|---|
| Launch (monkey LAUNCHER) | 2026-09-30T16:12:39Z | `topResumedActivity=…/.MainActivity`, pid **19075** |
| Home | 2026-09-30T16:12:47Z | `NexusLauncherActivity` resumed, app backgrounded |
| Resume | 2026-09-30T16:12:50Z | pid **19075** (unchanged) |
| Lock (KEYCODE_SLEEP) | 2026-09-30T16:12:56Z | `mWakefulness=Asleep` |
| Wake + swipe unlock | 2026-09-30T16:13:00Z | `mWakefulness=Awake`, `MainActivity` resumed, pid **19075** |

`SAME_PID=yes (19075)` across launch / resume / wake.

Crash/ANR scan: **no** `FATAL EXCEPTION`, `E AndroidRuntime`, `Force finishing
activity` or `ANR in com.antigravity.valhalla`. The sleep/wake pair exercises the
app-visibility transition that puts the ACP adapter in background mode, and the
process survived it with no restart.

Device idle was **not** touched: `mState=ACTIVE mLightState=ACTIVE`, no
`deviceidle force-idle`.

Not done, by instruction: no real ACP/CLI prompt, no chat-history modification,
no remote/server operation, no Doze forcing, no force-stop, no git commit/push.

## 9. Bottom line

- Formatting-only round: the 6 untracked Dart files formatted; gate
  `dart format --output=none --set-exit-if-changed` over all 86 changed+untracked
  Dart files reports **0 changed, exit 0**.
- Full suite on the final tree: **+1421 pass / 17 skip / 0 fail, exit 0**.
- `flutter analyze --no-pub`: **No issues found!, exit 0**.
- Current release artifact SHA-256 `1af486e7…bdb3` installed with `install -r`,
  signature identical, no uninstall/data clear, launch/Home/lock-wake all kept pid 19075.
- The detached-SSH reconnection item is **closed** by the core worker and proven
  by the green full suite.

No remaining blocker from this worker's scope. See
`agent-workflow/background-recovery-final-gates.md` for the final gate matrix.
