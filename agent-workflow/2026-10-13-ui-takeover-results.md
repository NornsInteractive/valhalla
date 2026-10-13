# Shared browser UI takeover — implemented, rebuilt and installed

Subsequent user-requested direct rebuild/ADB validation installed the final clock
display correction at19:08:24+08 and completed real device application installation,
Web access, uninstall-checkbox/name confirmation and exact test-data deletion.
This supersedes the device-uninstall gap at the end of this historical report.
See [latest ADB validation](2026-10-13-adb-rebuild-validation.md) for fresh artifact,
source checks, outcomes and boundaries.

## Authorization and scope

User explicitly authorized the root agent to own this round's UI. This supersedes
AgY-only authorship for the current approved changes; prior direct verification,
build and retain-data ADB permission remains in force. No push, release, version
bump, production mutation, credential rotation or app data clear is authorized.

## Implemented

- Shared controlled breadcrumb/search/hidden/sort/view toolbar, virtualized entries
  and entry tiles are used by the real SFTP page and the remote browser dialog.
  Main-page provider, projection cache, actions and selection remain in place.
- Mobile normal-text grid uses two vertical cards at320–430dp; large text uses
  one. View changes retain visible entry anchors; per-directory scroll positions
  survive refresh and navigation. Hidden content is dimmed, controls are not.
- Unified dialog supports list/card/image views, bounded previews, safe selection
  readiness, independent source/navigation cancellation, partial error display,
  source replacement, accessible mobile footer and keyboard focus dismissal.
- SFTP copy/move, app data/mount, CLI cwd, ACP cwd/attachments are thin callers.
  Capture server, execution profile/session/draft before opening and reject stale
  results. Keep original size/capability and restricted-directory protections.
- NAS source/scan/include/exclude/native and legacy deployment selectors use the
  same component. SMB domain loading gates actions; draft revisions invalidate
  late login/browse results. Media IDs remain opaque, names display separately,
  all-libraries is explicit/include-only.17 locales generated.
- Removed the unused old `remote_directory_picker_dialog.dart` after all callers
  migrated; it remains recoverable from Git. No user data was deleted.

## Verification chronology

- File page44passed; shared component23passed; caller82passed; NAS93passed across
  its final focused runs. These overlap the full suite and must not be added twice.
- Full `flutter analyze --no-pub`: zero issues.
- Read-only pinned acceptance VM identity test1passed this turn; no VM mutations.
- Full suite/build/installed artifact/device acceptance results: pending below.

First full suite:3224passed/28skipped/2failed. Fixed the real same-frame hidden
toggle re-entry regression; migrated one grid-context-menu test from the old
ListTile shape to the shared entry tile, preserving its action assertions.
Focused rerun25passed. Review also added the saved-source object identity guard
between NAS picker completion and config Save (including credential-only saves);
NAS caller15 and old-view57 tests passed. Final full suite exited0:
**3227passed/28skipped/0failed**,2m39s. Skips are environment-gated live tests,
not claimed as actual remote acceptance. Final full analysis zero issues.

First two builds exited1: generated Android registrant contained the dev-only
integration_test plugin while Gradle release excluded it. Initial concurrency
was suspected but the exclusive retry also failed. SDK inspection established
the cause: `--no-pub` also skips `regeneratePlatformSpecificToolingIfApplicable`,
leaving the old debug registrant unchanged. Retry without that flag lets Flutter
regenerate its release-filtered registrant; no manual generated-file patch.

## Artifact baseline and boundaries

Evidence directory `/tmp/valhalla-ui-takeover.pK4xBudK`; earlier focused logs in
`/tmp/valhalla-browser-implementation.NXfb1raa` and internal-agent result docs.
ADB127.0.0.1:14251 is an Androidx86_64 emulator, not a physical phone. Existing
installed APK pulled before any update, SHA256
`a92d3f4ee4c84a283f9f367587cd45a7621b4e1e869ad47fedf5e4a0678cbee6`.
Compatible test certificate SHA256
`2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`.
Prior local build also preserved separately as `previous-test.apk`.
Version stays1.0.4+5/native4005. Current device screen initially uses production
`krm`; no operation was tapped there. Functional reads/actions must first select
the pinned disposable NAS acceptance VM. Do not reuse old screenshots as proof.

## First candidate artifact and retain-data install

- Exclusive build without `--no-pub`: exit0,31.9s. Lockfile SHA256 remained
  `94268ac9b31941cbb9e6552babea632275a9605fb7b4b25856c5b6f09fb948ff`;
  Flutter regenerated the proper release registrant. No dependency upgrade.
- New release-mode, original test-signed x86_64 APK:52,669,128bytes,
  built2026-10-13 18:34:09+08. Same certificate verified before installation.
- `adb install -r`:Success. Last update2026-10-13 18:34:23; original first install
  unchanged2026-09-23 03:26:04. No uninstall or data clear.
- Candidate and freshly pulled installed base.apk SHA256 both
  `e205fb77fbdb4f60745bc676f3467df29cdf42d391da968a6423acbf119dc0bc`.
- Launch PID21597. Actual device checks follow below.

## Device acceptance found two final corrections

The first installed candidate was actually exercised on the pinned NAS acceptance
VM, not merely launched. SFTP list/card switching produced two distinct vertical
columns; hidden `.local`/`.ssh` labels were dimmed without opening those paths.
Copy selection opened the shared read-only browser and was cancelled without
copying. NAS scan selection listed two real Jellyfin libraries and switched to
two-column cards. Application store switched between full-width list rows and
two-column cards. The BentoPDF wizard showed its exact container-name preview;
its not-yet-created data path fell back to the existing parent in the common
picker. Both picker and wizard were cancelled, no installation was executed.

- A short picker breadcrumb was incorrectly right-aligned. The shared component
  now owns a normal-direction controller, reveals the tail only on path changes,
  keeps short paths left-aligned and leaves the root clickable. Five new tests
  plus67 existing browser/file cases passed. The toolbar action row is left-aligned.
- NAS cold start showed `NAS_LIBRARY_LOAD_FAILED` and no cached items. A real
  repository regression proved a failed remote playlists request blocked all
  local-index reads. Device source diagnosis succeeded after SSH was connected,
  and its live libraries were readable; no index was cleared or rescanned.
  Local media loads now finish independently of the optional background playlist
  request, with source/epoch guards and a localized, retryable playlist warning.
  Local database failures retain their original error behavior.

The VM's application-center Installed tab has no app registered in this Android
profile. Therefore this device run cannot claim actual uninstall-checkbox or
deletion verification; widget regressions and the earlier pinned VM lifecycle/
cleanup evidence remain separate. No production application was used as a substitute.

Final full suite after both corrections exited0: **3237passed/28skipped/0failed**
in2m04s (`full-tests-delivery.log`); `analyze-delivery.log` reports no issues and
`git diff --check` is clean. NAS-specific97cases, final locale parity9cases and
localized retry-banner1case also passed independently. These are overlapping
proof, not additional totals. First-candidate process log contained no matches
for Flutter errors, fatal exceptions, RenderFlex overflow or Valhalla ANR; that
does not erase the caught NAS loading failure discovered through the UI.

## Final corrected artifact and second retain-data installation

- `build-delivery.log`: successful exclusive release-mode x86_64 build,64.5s.
- APK: `/tmp/valhalla-ui-takeover.pK4xBudK/valhalla-1.0.4-ui-final-x86_64.apk`;
  project output `build/app/outputs/flutter-apk/app-x86_64-release.apk`.
- Built2026-10-13 18:48:45+08,52,669,128bytes. Version1.0.4/native4005 and original
  test certificate unchanged; no formal release-key changes.
- `install-delivery.log`: `adb install -r` Success. Device lastUpdateTime
  **2026-10-13 18:49:00+08**; firstInstallTime still2026-09-23 03:26:04.
- Fresh build and pulled installed base.apk SHA256 both:
  `9b05acb1bd280011ad25a13609c0ce8ee7a7bb8b6aa44b83a499f8a7837aa0bb`.
- New process PID24144; active test server/source and saved configuration survive.
- Fresh cold NAS view shows the original3items (1photo/1video/1music) even when
  initial remote playlist loading fails. Local photo preview remains visible;
  source-ready retry clears the warning without deleting/rescanning the index.
  Evidence `33-final-nas` and `34-final-nas-retry` XML/screenshots.
- Main SFTP path, double-column cards and copied selection survive cold startup.
  Reopened shared copy picker confirms root/home path gap40physicalpx (=10dp),
  left-aligned controls, readable footer and unchanged selection restrictions.
  Evidence `35-final-files` through `38-final-return`; copy cancelled, no file
  operation confirmed. Keyboard `mInputShown=false` on return.
- `final-device.log` has no matches for Flutter errors, fatal exceptions,
  RenderFlex overflow, unhandled exceptions or Valhalla ANR during these checks.

## Delivery boundaries

Completed approved UI implementation and automated gates plus actual ADB emulator
installation/click checks. No Git push/Release, version increase, credential
rotation, production mutation or app data clear. The removed obsolete picker is
recoverable from Git. The unrelated dirty worktree was preserved.

Not checked on a physical phone, Windows or iOS; no live ACP Docker-agent fixture
was available. Device uninstall-checkbox/real deletion was not exercised because
this Android profile has no registered test deployment. UI tests and earlier
isolated VM lifecycle/cleanup tests cover those layers separately; special mount
filesystems, ACL and million-file stress remain outside this delivery.
