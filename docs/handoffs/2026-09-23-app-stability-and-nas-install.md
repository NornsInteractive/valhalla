# App stability and NAS deployment UI

## Acceptance status — 2026-09-23

The UI handoff below is implemented and the scoped stability acceptance is complete. The final release was installed with `adb install -r`, preserving app data. Final checks: 1111 Flutter tests passed, 17 opt-in VM tests skipped in the default run (separate real VM results are recorded); analysis and formatting passed. On Android 14 emulator `192.168.1.145:14251`, the final APK completed 25 navigation/Home-resume cycles over 1817 seconds with the same PID and no new crash, ANR, or exit record. Saved WebDAV source cold-start, SSH reconnect, and a scan after the soak passed without resaving the source. App and isolated WebDAV fixture remain running.

Final package, version-specific evidence, real VM outcomes, remaining feature gaps, and unverified external-device/account paths are in the [acceptance report](../04-testing-and-deployment/04-app-stability-acceptance-2026-09-23.md). This closes the listed stability work, not every app feature or physical-device scenario. The following sections preserve the original implementation contract; they are not a new pending work list.

User authorized implementation and testing. Work only in the historical agy conversation `ec81a4be-7543-45ee-8658-f68966f57d3b`, model `gemini-3.8-flash-high`, high. Preserve all existing dirty changes. UI/ARB/widget tests belong to this session. Backend agents work concurrently; do not edit their service/provider files.

## Required UI scope

1. Fix `nas_install_dialog.dart` lifecycle and narrow-screen layout. All new/remaining installer strings localized Chinese+English. 360 logical width + large text must not overflow. Errors near task status, not below off-screen form. Strict port parse/range; immutable captured form before async work; no selected-server fallback to a different active server. Show explicit target name, product, paths, image in review.
2. Dialog close only hides task; reopening observes retained task. One global active task. Busy disables all form/target/product mutation and duplicate submits. Show stage, real elapsed time, bounded log tail, error and cleanup outcome. Separate explicit cancel button. Do not fabricate percentage. Read-only reconcile action for interrupted/unknown tasks; no automatic retry/deletion.
3. Settings diagnostics entry: view a refreshable bounded local log tail and explicit export via native file picker; load/error/empty feedback. No uploads. Add app-level recoverable error snackbar from diagnostics incident stream and safe startup failure screen with retry and diagnostics export. Diagnostics screen must stay usable after storage initialization fails (no main ProviderScope dependencies). Test layout and failure paths.
4. Docker logs view currently renders only latest chunk. Maintain bounded 256 KiB log history, consume shared service stream, show error and release subscription on close. Backend root will fix stdout/stderr + finally session cleanup. Avoid UI hot rebuilding entire log per character.

## Backend API contracts (being implemented concurrently)

`nas_install_provider.dart`: existing `nasInstallServiceProvider` FutureProvider retained. New `nasInstallTaskProvider` StreamProvider<NasInstallTask?> emits initial/current task. `NasInstallService.state`, `.states`; existing prepare/install signatures unchanged. `cancel()` async requests cancellation; `discard(plan)` clears review only; `reconcile()` read-only after interruption/process death. Task fields: `id`, immutable `request`, `stage`, `startedAt`, `updatedAt`, `logTail`, `errorCode?`, `cleanupComplete?`, `plan?`, `result?`, `requiresReconciliation`; getters `isBusy`, `canCancel`, `elapsed`. Stage enum `preflight, review, writing, pulling, starting, health, cleanup, succeeded, failed, cancelled, needsInspection, reconciling`. Confirm exact compilation against actual backend before final tests. UI-local timer only updates elapsed display; cancelling timer must never cancel installation. Handle stream initial/loading states and preflight errors.

`core/providers/diagnostics_provider.dart` already added: `diagnosticsServiceProvider` -> AppDiagnostics, `diagnosticsTextProvider` FutureProvider.autoDispose<String>, `diagnosticsIncidentProvider` StreamProvider<String> (category, not raw exception). Service `.read()` defaults256KiB tail; `.export()` returns path/null via FilePicker; `.storageError`; singleton `AppDiagnostics.instance` for bootstrap screen. No UI needs to read raw files. Error records kept3files×1MiB, sanitized, queue bounded.

Root owns `main.dart` startup and error-handler plumbing. Coordinate: add UI in separate diagnostics/startup widgets and send root import + function/class signature to wire startup failure; you may edit `ValhallaApp` / `_LifecycleHost` UI listener only after notifying root. Do not rewrite startup function concurrently. Root has wired exact file `lib/features/settings/widgets/startup_failure_app.dart` and startup widget: `StartupFailureApp({required Future<void> Function() retry})`, independent MaterialApp/l10n, diagnostics readable from singleton. No raw secret-bearing exception displayed.

## Verification

Backend additions while UI work runs: map `SFTP_PREVIEW_TOO_LARGE` in SFTP UI with localized instruction to download/open externally (1MiB preview cap). New NAS codes: `NAS_INSTALL_BUSY`, `NAS_INSTALL_RECONCILIATION_REQUIRED`, `NAS_INSTALL_CANCELLED`, `NAS_INSTALL_PREFLIGHT_FAILED`, `NAS_INSTALL_COMMAND_TIMEOUT`, `NAS_INSTALL_COMMAND_RESULT_UNKNOWN`, `NAS_INSTALL_DEADLINE_EXCEEDED`, `NAS_INSTALL_INTERRUPTED`, `NAS_INSTALL_INSPECT_FAILED`, `NAS_INSTALL_REMOTE_INSPECTION_REQUIRED`, `NAS_INSTALL_RECONCILIATION_FAILED`, `NAS_INSTALL_STATE_SAVE_FAILED`. Startup retry errors must be localized/sanitized and reset busy on failed retry; root's `main` catches failure and rebuilds same StartupFailureApp, so retry must remain available even if callback completes normally after rebuilding failure UI. Prefer finally mounted reset. Do not show raw e.toString() on fallback screen.

Meaningful widget tests for dismiss/reopen active installer, no fallback/mutable target, invalid port, cancel/reconcile status and360px layouts; settings diagnostics load/export-error; Docker bounded history. Run `flutter gen-l10n`, format changed UI files, targeted tests/analyze only after backend contracts settle. Report exact files/test results. Do not run integration_test on device; Flutter runner deletes installed app data. No git reset/commit/push. Existing remote configurations read-only; root handles ADB and isolated VM testing.


## Independent review fixes required before finish

- `_confirmInstall` / `_preparePlan` keep `_isSubmitting=true` for entire task; cancel button must NOT require !_isSubmitting, otherwise user cannot cancel in the same window. Use `task.canCancel` and separate cancel-in-flight guard if needed. Add widget test that starts task then cancels without closing/reopening.
- MainShell diagnostics listener must replace/coalesce existing error snackbar, never enqueue an unbounded snackbar per incident. Test repeated incidents.
- DockerLogsDialogContent pending list must be bounded at ingestion, not only on50ms flush; history cap is256KiB UTF-8 bytes, not UTF-16 String.length (Chinese currently exceeds statedcap). Reuse bounded history helper if needed in backend; do not retain hugechunk queue. Testmultibyte+burst.
- Additional backend code NAS_INSTALL_CONNECTION_CHANGED should say connection/target changed and remote state needs checking.

- NAS new-deployment `_forceNewDeployment` must be cleared before awaiting new prepare, so new preflight task progress/cancel immediately visible. Disable New Deployment while requiresReconciliation; do not hide only recovery action.
- SFTP editor save callback must catch write failure locally, show actionable error in editor and prevent duplicate save; preserve unsaved content after failure. Agent added SFTP_PREVIEW_TOO_LARGE for bounded reads and is adding real SFTP deadlines.
