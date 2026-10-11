# Six Phase-1 verification — AppUpdate provider focus

Scope: continuation of the timed-out MiMo Phase-1 handoff
(`agent-workflow/2026-10-11-update-provider-validation-handoff.md`). Read-only
sources for this run were `lib/core/providers/app_update_provider.dart`,
`lib/core/services/app_update_service.dart`, the handoff document, and the
existing `test/core/app_update_service_test.dart` /
`test/core/app_update_http_test.dart` fixtures for reuse.

Model/runtime fallback confirmed as explicitly provided by the caller:
`step-5-preview-free` main + small. No subagents, no paid models.

## ADB preflight (read-only, no install/build)

The step-5 free-fallback configuration was used. No build, no install, no
uninstall, no clear-data, no git operations, no scratch repository.

| item | value |
| --- | --- |
| transport | `127.0.0.1:14251` (connected via `adb connect`; initial `adb devices -l` was empty) |
| device | `sdk_gphone64_x86_64`, product `sdk_gphone64_x86_64`, device `emu64xa`, transport_id 2 |
| exact serial | `EMULATOR37X1X11X0` |
| CPU ABI | `x86_64` (abilist `x86_64,arm64-v8a`; 32-bit abilist empty; `primaryCpuAbi=x86_64`, `secondaryCpuAbi=null`) |
| installed package | `com.antigravity.valhalla.valhalla` (uid 10196) |
| installed version | `versionName=1.0.3`, `versionCode=4004`, minSdk 24, targetSdk 36 |
| codePath | `/data/app/~~wGUQ52r1UCDxAWwK1MGotg==/com.antigravity.valhalla.valhalla-yAGF6U61pLWlML3TrFAhIA==/base.apk` |
| signing | `apkSigningVersion=2`, `signatures=[6e5dbc6]`, `past signatures:[]`, `Signing KeySets: 60`, signer object id `6e5dbc6` |
| install time | `firstInstallTime=2026-09-23 03:26:04`, `lastUpdateTime=2026-10-10 17:18:07`, `timeStamp=2026-10-10 17:18:07` |
| device build | Android 14 (SDK 34), build `userdebug` |
| installer | `installerPackageName=null`, `initiatingPackageName=com.android.shell`, `packageSource=1` |
| dexopt | `x86_64 [status=verify][reason=install][primary-abi]` |

Device facts stay a compatibility reference only: they are not used as proof of
the provider behaviour below, because no app was installed or run on the device
in this task.

## What was written

Only these files were authored (exact file counts):

- `test/core/app_update_provider_test.dart` — new, 2 test cases.
- `test/features/system_provider_target_test.dart` — existing file, one
  additive block only (whitespace `expectedStartedAt` rejection). No assertion
  was removed or weakened.
- `agent-workflow/2026-10-11-six-phase1-verification.md` — this report.

`dart format` was run only on the two test files I own; no production, UI or
workplace-wide formatting was performed. `dart format
--output=none --set-exit-if-changed` on both files reports 0 changes.

No change was made to `lib/`, no dependency was added or changed, no product
hook or abstraction was introduced, and no UI was generated or formatted.

## Harness shape

Smallest deterministic harness, no new dependencies:

- `_FakeUpdateService implements AppUpdateService` with
  `List<Completer<AppUpdateCheck>> checkGates` and
  `List<Completer<void>> downloadGates` so each notifier await point is
  driven directly by the test; it counts `check`/`download`/`cancel` calls and
  records artifacts and destinations.
- Method channels stubbed through `TestDefaultBinaryMessengerBinding`:
  `valhalla/updates`, `valhalla/downloads`,
  `dev.fluttercommunity.plus/package_info`. Every recorded call is asserted on
  so "no native call" claims are real, not inferred.
- Path allocation goes through a `_FakePathProvider extends
  PathProviderPlatform` returning owned temp paths. This is required, not
  cosmetic: the default `MethodChannelPathProvider.getDownloadsPath` throws
  `UnsupportedError: Functionality only available on macOS` on a Linux host
  *before* invoking any channel, so a `plugins.flutter.io/path_provider` stub
  alone can never reach `reservePath`. The fake is saved in `setUp` and
  restored in `tearDown`; the earlier ADB preflight section is unchanged.
- `PackageInfo.setMockInitialValues` and `SharedPreferences.setMockInitialValues`
  (both pre-existing testers already in the repo), `LocalStorageService` over
  the real `SharedPreferences`, and the real `appUpdateServiceProvider` /
  `appUpdateProvider` / `storage_providers` / `app_visibility_provider` wiring via
  `ProviderContainer` overrides.
- `automaticUpdateChecksEnabledProvider` is overridden to `false` so the
  isolated provider performs no HTTP on its own, exactly as production does for
  isolated widgets.
- Temp directories from `Directory.systemTemp.createTempSync` are deleted in
  `tearDown`; all test paths stay inside owned temp files.
- No real sockets, no real device, no real OS installer.
- `methodCalls` is declared once in `main()` and therefore accumulates across
  the file; the path-allocation test clears it before its own assertions so its
  report-progress expectations are self-contained.

## Cases run and their result

Exact, unfiltered command output is retained in
`/tmp/opencode/six-phase1/`:

- `owned-two-tests-final.log`, `owned-two-tests-final2.log` — the two owned
  files in one foreground run (last green run of this round).
- `provider-phase1c.log`, `provider-phase1d.log`, `provider-phase1e.log` —
  intermediate failing runs retained, including the ones with the wrong and then
  the correct causal diagnosis below.
- `provider-and-system-target.log` — earlier round where the system-provider
  target suite was also green.

Run: `flutter test test/core/app_update_provider_test.dart
test/core/app_update_service_test.dart` with `set -o pipefail` and `tee`, plus a
second unfiltered capture (`RAW_EXIT`) to confirm the exit code independently of
the pipeline.

Result: **56 tests, all passed, real exit code 0** — 8 provider cases in
`app_update_provider_test.dart` and 48 cases in `app_update_service_test.dart`
(45 pre-existing + the 3 new `bounded notes` cases).
`dart analyze` on exactly those two files: **No issues found**.

Provider cases 1–5 are unchanged in substance from the earlier round and are
repeated here for completeness; cases 6–8 and the service `bounded notes` group
are new this round.

1. `concurrent checks deduplicate to a single deferred HTTP call`
   - Two `check()` calls issued back to back coalesce into one `_check` future
     (`identical(first, second)`), exactly one fake `check` call and one gate,
     while the fake HTTP gate is still blocked.
   - After releasing the gate, `release.version == '9.9.9'` and
     `updateAvailable == true` are published once; the service still reports a
     single `check` call.

2. `disposal while a check waits publishes nothing and never calls natives`
   - One `check()` is in flight with the fake HTTP gate still open; the
     container is then disposed (provider invalidated mid-flight).
   - After the gate completes, `getUpdateCheckCache()` and
     `getUpdateDownloadRecord()` remain `null` (no storage overwrite), no
     `runtimeInfo` / `install` / `revealFile` method channel call happened, and
     no `AppUpdateState` publication occurred after disposal
     (`published` is unchanged from the snapshot taken before disposal).
   - A positive control is included: the in-flight `checking: true` state *was*
     observed before disposal, so "nothing published" means nothing published
     *after* disposal, not that the listener was inert.

3. `pause then immediate resume waits for the gated writer and reuses the path`
   - The first `download()` is triggered with `nextWriterOpened()` pre-registered;
     the entry acknowledgment fires only after `reservePath`'s mkdir/exists have
     completed and the writer is genuinely open.
   - Two further taps while `downloadStatus == downloading` add no writer
     (`downloadCalls` stays 1). `pauseDownload()` bumps the epoch and calls
     `cancelDownload()` exactly once.
   - Resuming immediately parks on `_downloadTask` (the old writer): still one
     `download` call while the gate is blocked, so the resume provably waits for
     the old writer before opening a second one.
   - Releasing the old gate lets the resume open the second writer on the
     *same* destination string and the same `AppUpdateArtifact` instance;
     `state.localPath` equals the first destination.
   - No `failed` status is ever published for the canceled epoch and no
     non-null error is published at all; the resume then completes with
     `downloadedBytes == artifact.size`.

4. `cancel while path allocation is pending leaves no writer and no record`
   - `getDownloadsPath` is gated, so `download()` parks inside `reservePath`;
     `downloadCalls == 0`, `localPath == null`, and no durable record exists.
   - `pauseDownload()` before allocation returns; allocation resolves afterwards
     against the stale epoch.
   - Still `downloadCalls == 0`, `downloadGates` empty,
     `getUpdateDownloadRecord()` still `null`, status `paused`, error `null`.
   - The only progress the native bridge received is `paused` — no `running`
     or `completed` progress for a canceled epoch.

5. `a failed check keeps the previous release; an empty result clears it`
   - The fake service fails the next `check`; the notifier does not rethrow, it
     publishes `checking == false` plus an error containing
     `UPDATE_CHECK_FAILED`, while `release`, `artifact` and
     `updateAvailable` are retained and the previous cache is not discarded.
   - A clean `AppUpdateCheck(release: null)` (the 404 path) then clears
     `release` and `artifact` and resets `updateAvailable` and `error`.

6. `the production default performs no HTTP check on its own` (new)
   - A container created *without* `automaticUpdateChecksEnabledProvider`
     overriding (i.e. the production default `false`) is read, then
     `checkIfDue()` runs and foreground/background/foreground visibility
     transitions fire.
   - `checkCalls == 0` and `checkGates` is empty throughout; no cache is
     written. This is the exact production posture for isolated widgets.

7. `an enabled automatic check fires once and not again within 24h` (new)
   - A container with the provider explicitly enabled performs exactly one
     fake HTTP check from `build() → _restore() → checkIfDue()`.
   - A second `check()` call reuses the same in-flight future (no second call),
     and after the release lands, `checkIfDue()` and both visibility
     transitions inside the 24h window add no further HTTP call.

8. `a completed download with a wrong hash never reaches the OS` (new)
   - The fake writer opens against the real reserved path (acknowledged, not
     polled), and the artifact-sized file it "lands" is tampered content.
   - `openDownloaded()` throws `UPDATE_DOWNLOAD_INTEGRITY_FAILED`; no `install`,
     no `revealFile`, and the recorded launcher list is empty.
   - State remains `completed` with a null error, so the tampered file is not
     silently re-rollouted into a new state.

Service parser cases (new, in `app_update_service_test.dart`):

9. `oversized notes stay unicode-safe and point at the release page`
   - A body mixing ascii and astral characters above 16k runes is bounded to
     `16 * 1024 + 2` runes, has no lone surrogate, round-trips as valid UTF-16,
     still contains astral code points, and keeps its Release URL so the full
     text remains reachable.
10. `a body at the limit is not rewritten` — a body exactly at the UTF-16 bound
    passes through unchanged (no truncation, no ellipsis marker).
11. `astral characters survive truncation as whole code points` — an all-astral
    body above the bound truncates by rune, keeping every code point whole.
    Note the real production semantics recorded here: `_boundedNotes` compares
    `notes.length` (UTF-16 units) against the bound but truncates by runes, so
    an all-astral body yields 16386 runes rather than 16384 — my initial
    expectation of 16384 was wrong and was corrected to match the code, not the
    reverse.

Additive change in the existing system-provider target test (previous round,
unchanged):

12. `a missing start identity is refused before any ssh work` now also rejects
    `' '`, `'   '`, `'\t'`, `'\n'` and `' \t\n '` with
    `_identityUnavailable()`, matching the
    `expectedStartedAt.trim().isEmpty` guard at
    `lib/features/system/system_provider.dart:270` and
    `lib/infrastructure/system/process_service.dart:80`. The original `null` and
    `''` cases are untouched and still asserted, and
    `expect(h.processes.terminateCalls, isEmpty)` still runs after all of them.
    That file's own suite is 11 tests, all passing.

## Handoff items covered vs still pending

Covered now (8 provider cases + 3 service parser cases, all green):

| handoff requirement | where it is proven |
| --- | --- |
| concurrent check deduplicates to one deferred fake HTTP call | `concurrent checks deduplicate…` |
| dispose while a fake HTTP check waits: no storage overwrite, no native call, no state publication | `disposal while a check waits…` |
| pause → resume waits for the old writer to settle; single writer on the same `.part`; no false failed state; identical artifact/path preserved | `pause then immediate resume…` |
| two taps while downloading do not duplicate | same case, after the first writer opens |
| cancel while path allocation is pending: no download and no durable record write after the epoch goes stale | `cancel while path allocation…` |
| manual refresh failing keeps the previous release and exposes the error; a null-release result (404 path) clears it | `a failed check keeps…` |
| default isolated providers make no HTTP automatically | `the production default performs no HTTP check on its own` |
| explicit opt-in checks no more than once per 24h | `an enabled automatic check fires once and not again within 24h` |
| release notes above the limit, including Unicode astral characters, remain bounded without broken UTF-16; full text at the Release URL | service `bounded notes` group (3 cases) |
| tampered completed download reaches no native installer / reveal / launch | `a completed download with a wrong hash never reaches the OS` |

Not yet authored (still pending; not claimed as verified):

- an old restore/check must not overwrite a newer release after the
  `PackageInfo`/runtime-metadata awaits.
- `openDownloaded` must use the exact captured file/artifact/version it
  validated, never a later `state.localPath` (partially covered: the tampered
  case proves no OS handoff; the "captures a later `state.localPath`" race is
  still untested).
- an Android-specific install invocation path: the Linux host never enters the
  `Platform.isAndroid` branch, so `install` method-call arguments
  (`path`, `versionCode`, `certificateSha256`, `versionName`) are **not** verified
  here and no runtime Android claim is made.
- metadata-epoch behaviour that would need a mockable hook that production does
  not expose; not added.

These are written as pending, not claimed: a green subset here is not the full
handoff gate.

## Failed fixtures recorded (not quietly overwritten)

The previous round's three new fixtures failed before being fixed; the causes
are recorded because they are fixture facts, not production bugs:

- `pause then immediate resume` and `cancel while path allocation is pending`
  both relied on a `plugins.flutter.io/path_provider` method-channel stub. On
  Linux the default `MethodChannelPathProvider.getDownloadsPath` throws
  `UnsupportedError: Functionality only available on macOS` before any channel
  call, so `reservePath` failed with
  `Unsupported operation: Functionality only available on macOS` and the
  download never started. Fixed by the `_FakePathProvider` fake (with an
  `allocationGate` completer for the blocking case). No production injection
  was added.
- The check-failure fixture assumed `notifier.check()` rethrows.
  `_performCheck` catches internally and publishes the error as state, so the
  future completes normally; the assertion was corrected to check state rather
  than to expect a throw. The requirement itself (previous release retained,
  error exposed) is unchanged.
- A first attempt at "no progress reported for a canceled epoch" assumed
  `pauseDownload` reports nothing. It legitimately reports `paused` to the
  native bridge; the assertion was tightened to `['paused']` instead of being
  dropped.

Logs for the failing intermediate state are retained in
`/tmp/opencode/six-phase1/` (including the earlier run whose output shows the
three failures above) rather than being overwritten with the green result.

## Corrected causal evidence (this round)

An intermediate diagnosis of a later fixture failure was wrong and is corrected
here rather than quietly dropped. In
`/tmp/opencode/six-phase1/provider-phase1c.log`, `pause then immediate resume`
failed at `downloadCalls` expected 1 / actual 0 after a fixed `await pump()`
with 12 zero-duration turns.

**Wrong cause I first recorded:** that a later test polluted the earlier one via
shared fake state. That is incorrect and is retracted. `setUp` already builds a
fresh `_FakeUpdateService`, fresh `SharedPreferences`, fresh temp directory and a
fresh path platform before every test, and tests run sequentially — a later
test cannot reach an earlier one's assertions.

**Actual cause:** `reservePath` performs genuine filesystem I/O
(`directory.create`, `File.exists`) before the fake download is entered. A fixed
count of event-loop turns is not an I/O acknowledgment, so the `download()` call
had not yet reached `service.download` when the assertion ran. No production
change is warranted or implied.

**Fixture fix:** `_FakeUpdateService.download` now completes a
`Completer<void>` on entry, which the test pre-registers *before* triggering
the download via `nextWriterOpened()`. This is a deterministic handshake rather
than a retry or poll loop, and the pump count was not increased and no assertion
was weakened. The tampered-download fixture uses the same acknowledgment in
place of the fixed turn count.

The separately lost old NAS assertion noted in earlier review is **not**
attributed to this cause; its origin remains unverified.

## Dependency change

Sanctioned by main and applied exactly, with no version change:
`pubspec.yaml` declares `path_provider_platform_interface: 2.1.3` under
`dev_dependencies` (already installed, previously transitive), following the
existing `url_launcher_platform_interface` pattern in this file.
`flutter pub get --offline` reported
`path_provider_platform_interface 2.1.3 (from transitive dependency to dev
dependency)` and `pubspec.lock` changed only
`dependency: transitive` → `dependency: "direct dev"`. No runtime dependency,
no version bump, no other pubspec or lock line changed.

## Blockers and records

- No production, UI, or other-test file was modified by this run. The `lib/`
  entries visible in `git status` are pre-existing in-progress work from another
  task and were not touched.
- `flutter pub get --offline` and `flutter test` were the only build-tool
  invocations; no build, install, git commit/staging, ADB, subagent or server
  interaction was performed. The ADB preflight facts in this report come from
  the earlier read-only pass and were not re-measured.
- `test/core/app_update_provider_test.dart` and
  `test/features/system_provider_target_test.dart` are untracked in git, so no
  commit or staging was performed.
- Interim results in `/tmp/opencode/six-phase1` from earlier phases (the
  31 draft 45 provider 9 system 20 infra numbers) remain interim only; they are
  not a full gate and not proof of the current source.

Status: 8 provider cases and 3 service parser cases authored and passing; the
remaining handoff items listed above are still pending and unverified.

