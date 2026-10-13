# NAS remaining UI: direct completion and device delivery

## Latest device result (supersedes the pending-device notes below)

User authorized ADB operation and reconfirmed exclusive use after interference.
The exact new APK was retained-data installed successfully at device time
2026-10-13 15:37:59; installed hash matches. Actual source authentication, scan,
diagnostics, cache confirmation/cancel, photo/video display, music progression and
Home-return were exercised. Two findings remain: first-entry Docker refresh race
and native-existing-install generic error wording. No product fix in this
verification-only turn. See [device results](2026-10-13-nas-adb-install-test.md).
Do not interpret source gate success as all device workflows passing.

## Authority and boundary

User explicitly asked root to take over the remaining five UI areas, then build,
retain-data install through ADB and operate the app. This round overrides AgY-only
UI ownership for those areas. Preserve the existing dirty tree, app version,
production credentials and formal signing key. No push, release, data clear or
uninstall. Real server mutations only on the pinned disposable VM. ADB currently
identifies an Android emulator; do not label it physical-phone acceptance.

## Completion scope

1. Both NAS deployment entries open the same Docker/native chooser. Docker uses
   the exact official Jellyfin application and explicit experiment enablement;
   native uses the existing durable installer. Capture the selected connected
   server; no fallback to the first saved server.
2. Fix native confirmation layout at 320dp/2x and its three analyzer warnings.
3. Healthy deployment offers web setup and a new source draft. Reuse SSH access,
   keep remote endpoint/server identity, never save transient local tunnel ports
   or generate an account automatically.
4. Source diagnostics display only actual connection/scan state and sanitized
   copyable details. Probe is explicit, with saved secrets retained internally.
5. Library storage distinguishes per-source thumbnails, unowned legacy cache and
   recorded offline download bytes. Clear/remove actions remain confirmed and
   separate; thumbnail clearing cannot delete offline media.

Preserve Flutter Material and project tokens (taste native exception), light/dark
theme, narrow/large-text/RTL usability and reduced-motion behavior. Reuse existing
components and services; no new package or unrelated category redraw.

## Ownership

- Root: page entries, integration/regressions, final gates and APK/ADB evidence.
- Deployment collaborator: chooser, native UI, successful-deployment handoff.
- Storage collaborator: diagnostics/library-settings/download filtering and tests.
- Locale collaborator: all new messages in 17 catalogs; generation is serialized.

## Verification state

Pre-change baseline: 2950 passed, 25 environment skips, 2 failed (native review
overflow and 16 missing native locale keys). Real isolated native/Docker media
authentication, scanning and range reads, and selective uninstall already passed;
these are not device playback proof. Final checks and a new APK are pending.

ADB is online at `127.0.0.1:14251`, but another app is foreground. Root requested
fresh exclusive-use confirmation and will not tap/install before confirmation.
Existing installed APK and timestamps are historical, not new delivery evidence.

## Current source gates (2026-10-13)

All five scoped UI areas are implemented. Taste guidance was applied within the
existing native Flutter design: large touch targets, responsive/wrapping actions,
semantic sections, retained dark/light/RTL behavior; no new design framework.
Native confirmation overflow and all 16 previously untranslated native messages
are fixed. All 17 catalogs have 1587 message keys with matching placeholders.

Saved-source diagnosis now reads full stored credentials internally (including
SMB domain). Changing an SSH profile's connection key invalidates only affected
diagnostics and pending probe reports, without clearing sources or selection.
The delayed old-success regression was reproduced before the fix. Legacy new
deployment also no longer falls back to the first saved server without selection.

- `flutter gen-l10n`: successful.
- `flutter analyze --no-pub`: **No issues found**, exit 0.
- Nine-file focused regression gate: **125 passed**, exit 0 (15 seconds).
  Includes 320dp/2x, RTL, desktop, actual source/target changes, separate cache
  confirmation, source-filtered downloads, guarded deployment handoff, and locales.
- `git diff --check`: exit 0.
- Whole suite: **2983 passed, 25 environment-gated skips, zero failures**, actual
  exit 0 in 3m11s. Destructive/live opt-in variables were explicitly unset;
  isolated VM evidence remains a separate gate rather than hidden skip coverage.
- Fresh compatible x86_64 APK: built successfully after green full suite, actual
  exit 0, Gradle 80.5 seconds. It has not been installed or device-accepted.

Evidence directory: `/tmp/valhalla-nas-direct.wCL6Gmvn`. Earlier red logs are
retained. One targeted invocation named the locale test in the wrong directory;
it was rerun using `test/core/l10n_key_parity_test.dart`. Six older widget harnesses
were updated for the new source-scoped cache API; assertions were not weakened.

## New artifact and remaining device gate

Artifact: `/tmp/valhalla-nas-direct.wCL6Gmvn/valhalla-1.0.4-nas-ui-x86_64.apk`
(also `build/app/outputs/flutter-apk/app-x86_64-release.apk`), 52,472,544 bytes.
SHA256: `a92d3f4ee4c84a283f9f367587cd45a7621b4e1e869ad47fedf5e4a0678cbee6`.
Package `com.antigravity.valhalla.valhalla`, version1.0.4/nativecode4005, x86_64.
`apksigner verify` passed with compatible original test certificate SHA256
`2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`.
This is a release-mode, test-signed device candidate, not a published/formally
signed release. Formal certificate and pubspec1.0.4+5 remain unchanged.

Build used normal pub resolution, existing isolated Gradle home and subprocess
unset signing variables: `flutter build apk --release --split-per-abi
--target-platform android-x64`. No clean/shared cache deletion was performed.
Historical artifacts were preserved as `previous-*.apk`; their hashes differ.

ADB device `127.0.0.1:14251` is still online (Android x86_64 emulator). Last
read-only check shows another app foreground and installed Valhalla update time
still2026-10-12 22:28:37. The exclusive-use question remains unanswered. **No
install, launch, tap or device playback is claimed for this round.** Pending:
retained-data `install -r`, fresh installed APK hash/time verification, safe
navigation of all five UI areas, fixture media playback and scoped error logs.
Do not repeat already-green source gates unless product files change. Never
uninstall/clear data to work around installation. No push or release was made.
