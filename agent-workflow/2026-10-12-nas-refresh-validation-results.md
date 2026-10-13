# NAS refresh validation results - SFTP subsystem transport + gates

Executor: OpenCode MiMo session, `opencode/mimo-v2.6-flash-free`.
Logs: `/tmp/valhalla-nas-refresh.OOGiIt`
Date: 2026-10-12. Verification only.

## Scope and ownership honoured

- Only file written under the repo: `test/infrastructure/ssh_sftp_subsystem_transport_test.dart`
  (still untracked, `??`).
- No product edits, no UI/ARB edits, no dependency edits beyond the root-owned
  vendored path already present, no subagents, no build/install, no git.
- `test/core/nas_offline_persistence_test.dart` and
  `test/infrastructure/nas_download_validators_test.dart` untouched (other OpenCode
  was editing them during these runs - file mtimes 13:01/13:02).
- AgY's UI/ARB edits untouched; only `flutter gen-l10n` output regenerated.

## Narrow fix to the last two tests

Both `failWrites` tests were replaced with a synchronous `StateError` injected
through the `SSHClient.printTrace` hook (`_SendFault` in the test file), armed for
exactly one outgoing message (`SSH_Message_Channel_Open(channelType: session` for
the open test, `requestType: subsystem` for the request test).

Why the old approach only hung: this fixture client never completes key exchange,
so `SSHTransport.sendPacket` parks every application packet in
`_kexInProgress`/`_rekeyPendingPackets` (ssh_transport.dart:375) and never calls
`socket.sink.add` - a faulted write path is unreachable, so the operation pended
until the 3s timeout.

Why the new approach is the same branch: `SSHClient._sendMessage` calls
`printTrace` *before* it hands the packet to the transport (ssh_client.dart:1029),
so the throw lands inside the very `try` that guards the send - `_openChannel`
(ssh_client.dart:1826) for CHANNEL_OPEN, `SSHChannelController._sendRequest`
(ssh_channel.dart:305) for `subsystem sftp`. No real handshake, no mirrored
library code, no product hook, assertions unchanged (still require `StateError`,
still require nothing unobserved in the guarded zone).

`_FakeSshSocket.failWrites()` removed with its callers (nothing else in this file
used it). File is `dart format` clean (`--set-exit-if-changed` exit 0).

## Commands and results

| # | command (cwd `/workspace/projects/valhalla` unless noted) | result | log |
|---|---|---|---|
| 1 | hosted baseline, cwd `/tmp/valhalla-nas-refresh.OOGiIt/hosted-baseline`, `/opt/flutter/bin/flutter test --no-pub test/ssh_sftp_subsystem_transport_test.dart` against hosted `dartssh2 4.1.0` (pub-cache) | **exit 1, +3 -4** - RED as expected: tests 2 (pending-then-close), 3 (subsystem refusal), 6 (subsystem send failure), 7 (CHANNEL_OPEN send failure) fail; 1, 4, 5 pass | `sftp-subsystem-hosted-baseline-rev2.log` |
| 2 | `/opt/flutter/bin/flutter pub get` | exit 0, `dartssh2` now resolves to `../packages/dartssh2` (path) | (stdout) |
| 3 | `/opt/flutter/bin/flutter test --no-pub test/infrastructure/ssh_sftp_subsystem_transport_test.dart` | **exit 0, `+7: All tests passed`** | `sftp-subsystem-vendored-baseline.log` |
| 4 | `/opt/flutter/bin/flutter test --no-pub test/infrastructure` (58 files) | exit 1, **+549 ~19 -1**; the single failure is the other OpenCode's then-uncompilable `nas_download_validators_test.dart` (missing `NasCancellation` import, `await` on `void close()`) | `infrastructure-vendored-regression.log` |
| 5 | `/opt/flutter/bin/flutter test --no-pub` (full suite) | exit 1, **+2305 ~19 -32**; attribution below | `fulltests-vendored-regression.log` |
| 6 | `/opt/flutter/bin/flutter gen-l10n` | exit 0 | `gen-l10n.log` |
| 7 | `/opt/flutter/bin/flutter analyze` | exit 1, **120 issues**, then rerun **86 issues (78 errors)** after concurrent edits settled | `analyze.log` |

Baseline integrity: hosted test copy sha256 `0c553935855eeb8f5891397f0bd91828b515be583e72a582f701bcd5a49a62a9`
equals the repo copy, so baseline and vendor runs used the identical file.
Hosted rev2 log sha256 `86e812869724289aee745a6aee2fdb8ad0801538d2b7f9bbbf32973eda4ff4ce`.

## Full-suite failure attribution (32)

- **30 failures**: test files cannot load because
  `lib/data/models/sftp_file_item.dart` does not exist while
  `lib/features/files/widgets/remote_file_batch_results_dialog.dart:9` and
  `lib/features/app_center/widgets/app_operation_wizard_dialog.dart:13` import it.
  `SftpFileItem` actually lives in `lib/infrastructure/sftp/sftp_client_service.dart:13`.
  The import is an uncommitted working-tree change (`git diff` shows
  `+import '../../../data/models/sftp_file_item.dart';`). Blocks 30 unrelated test
  files (widget/dash/main-shell/sftp/nas suites).
- **1 failure**: `test/core/nas_offline_persistence_test.dart` compile errors -
  `package:valhlla/...` typo (should be `valhlla`->`valhalla`) plus duplicate
  `createPlaylist`/`deletePlaylist`/`addToPlaylist` declarations. Other OpenCode's file.
- **1 failure (real assertion)**: `test/core/nas_playback_download_proxy_test.dart:808`,
  test `download failure removes partial; retry atomically completes captured source`,
  `Expected: <0> Actual: <1>` - reproducible on isolated re-run (exit 1,
  `+13 -1`, log `nas_playback_download_proxy_rerun.log`).

**Zero failures attributable to the vendored dartssh2.** The test file is unchanged
and tracked; `lib/core/services/nas_download_service.dart` is modified in the
working tree.

## Product defects to root (no edits made by me)

1. **Missing model file / broken imports (compile-blocking).**
   `lib/data/models/sftp_file_item.dart` is imported by
   `remote_file_batch_results_dialog.dart:9` and `app_operation_wizard_dialog.dart:13`
   but does not exist. Either point both imports at
   `lib/infrastructure/sftp/sftp_client_service.dart` or add the model file.
   Costs 30 test files their load in the full suite and at least 5
   `flutter analyze` errors (8 in the first analyze run).

2. **`NasDownloadService` leaves the `.part` file behind after a failed download.**
   `_run`'s `catch`/`finally` (lib/core/services/nas_download_service.dart:291-307)
   marks the task `failed` but never calls `_deletePartial`, while `cancel` (:123),
   `restart` (:149) and `remove` (:169) do. The unchanged test at
   `test/core/nas_playback_download_proxy_test.dart:808` asserts 0 `.part` files
   after failure and fails reproducibly. Note `resume()` (:133) accepts
   `NasDownloadStatus.failed`, so keeping the partial may be deliberate for
   resume-after-failure - in that case the unchanged contract test is the thing
   that must change, and root decides which side. I weakened nothing and edited
   neither side.

3. **Missing ARB keys.** `context.l10n.resume`
   (`lib/features/nas/widgets/nas_downloads_sheet.dart:335` and `:400`) and
   `ctx.l10n.nasAddToPlaylist` (`lib/features/nas/nas_media_view.dart:2879`) are
   used but absent from `lib/l10n/app_en.arb` after `gen-l10n` -> 3 analyze
   errors. ARBs are AgY's.

4. **App center wizard references model members that do not exist**
   (`lib/features/app_center/widgets/app_operation_wizard_dialog.dart`, 5 errors):
   - `:1141` `env.dockerVersion` - `ApplicationEnvironment`
     (`lib/data/models/application_center.dart:341`) has no `dockerVersion`.
   - `:1160` `_ports.entries` where `_ports` is a `List<ApplicationPort>` -
     `entries` is a `Map` member.
   - `:1234` `_template?.version` - `ApplicationTemplate`
     (`application_center.dart:110`) has no `version`
     (`widget.catalogApp?.version` on the same line is fine).
   Likely `..application.version` was intended.

5. **`nas_downloads_sheet.dart` uses a Riverpod 2 API on Riverpod 3.**
   `:36` `downloadsAsync.valueOrNull` -> undefined getter; `pubspec.lock`
   resolves `riverpod 3.3.2`, which dropped `AsyncValue.valueOrNull`
   (use `.value`). AgY's file, reported as observed.

6. **UI files currently do not compile** (AgY in flight, reported as observed):
   `lib/features/nas/widgets/nas_library_settings_dialog.dart` (36 errors, parse
   errors reported around :580 at first run) and
   `lib/features/nas/widgets/nas_scan_config_dialog.dart` (30 errors, `Undefined
   name 'theme'` at :308/:309/:327/:334...). Snapshot only - both files changed
   between my two analyze runs (120 -> 86 issues).

7. **Vendored package infos (pre-existing, informational).** `flutter analyze`
   reported 2 `deprecated_member_use_from_same_package` infos in
   `packages/dartssh2/lib/src/ssh_transport.dart:120` and `:1605` (`onPacket`).
   No errors in `packages/dartssh2` and none in the transport test file.

## What is proven at this point

- Unpatched hosted dartssh2 4.1.0 is RED on 4 of 7 contract tests (leaked
  subsystem Future, unobserved send error, resolved-after-refusal).
- Vendored `packages/dartssh2` 4.1.0 is GREEN on all 7, with the same assertions.
- No dartssh2 regression anywhere in `test/infrastructure` or the full suite.

## Not done / blocked

- Full-suite green is blocked by defects 1, 2, 4, 5 and 6 above plus the two files
  owned by the other OpenCode; re-run after root/AgY land fixes.
- No build, install, ADB, release, version bump, push or Actions.
