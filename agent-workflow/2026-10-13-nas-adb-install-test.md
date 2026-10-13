# NAS UI: installed-package device acceptance

## Scope and identity

User explicitly requested ADB installation and testing, then confirmed exclusive
device use again after another application was brought to the foreground. This
turn validates the already-built package; no product source, version or signing
configuration was changed, and nothing was pushed or published.

- Device: `127.0.0.1:14251`, Android x86_64 **emulator**, not a physical phone.
- Package: `com.antigravity.valhalla.valhalla`, 1.0.4 / native code4005.
- `adb install -r`: **Success**, keeping existing data.
- Device update time: **2026-10-13 15:37:59**; original first-install time remains
  **2026-09-23 03:26:04**.
- Fresh installed base.apk SHA256 matches the candidate exactly:
  `a92d3f4ee4c84a283f9f367587cd45a7621b4e1e869ad47fedf5e4a0678cbee6`.
- Original compatible test certificate verified before installation:
  `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`.
- Evidence: `/tmp/valhalla-nas-adb-final.SXEVeFcd`; previous APK was preserved.

The prior analyzer/2983-test green gates apply to this same unchanged source;
they were not rerun or confused with the following real device operations.

## Device results

| Area | Actual result and evidence |
| --- | --- |
| Retained configuration | Existing production server, experimental menus and old NAS sources remained. No uninstall or data clear. `01-launch`, `06-menu`, `07-nas-home`. |
| Deployment chooser | New Docker/native choices render and name the selected isolated VM. `09-deployment-chooser`. |
| Docker route | **First attempt fails incorrectly** with catalog-unavailable; a later explicit retry opens the exact official Jellyfin details. No install was submitted. `10-docker-details`, `22-docker-retry`. |
| Native preflight | Actual existing Jellyfin detected on the pinned VM; no reinstallation action executed. No package/service changes. The page also shows an incorrect generic blocker message (see below). `13-native-existing`. |
| New source handoff | Correct Jellyfin type, remote `127.0.0.1:8096`, captured SSH server, blank initial credentials. Cancel/reopen worked; real fixture authentication then Save succeeded. `14-native-source-draft`, `17-source-auth-result`, `20-source-saved`, `23-new-source-home`. |
| Diagnostics | Explicit saved-credential probe succeeded and updated its timestamp. Actual scan completed with three items, one image/video/audio each. `25-diagnostics-probed`, `26-scan-start`, `44-diagnostics-completed`. |
| Source storage | Current-source and unowned legacy thumbnail sections are separate. Both clear confirmations display their correct scope; both were cancelled. Current source stays32.1KB/1 item and original256MiB global budget stays selected. `27` through `31`. |
| Downloads | Source-scoped sheet opens and correctly displays no tasks/0 recorded bytes for the new source. No actual download deletion or cross-source populated-list test on device. `32-source-downloads`. |
| Image | Actual original test image renders colored bars in the viewer. `33-photo-viewer.png`. |
| Video | Actual decoded colored video frame at29.917s, player reaches30/30s. MediaSession earlier reports PLAYING at11s. `35-video-live.png`; no black-frame-only success claim. |
| Music | Real metadata and duration, seek to5.423s, PLAYING continues in background to25.174s. `music-seek-play.txt`, `music-background-progress.txt`. Does not prove audible speaker output. |
| Background return | After closing the player, Home/return preserves source, three-item library, visible scroll position and PID21418. `42-playback-stopped`, `43-library-home-return`. |
| Stop | Mini-player close stops the media session: active=false, NONE, position0. `media-stopped.txt`. |

## Two product findings — not fixed in this verification-only turn

1. **Docker first-entry refresh race.** Real `applicationCenterProvider.build`
   schedules an automatic refresh. The chooser's first read immediately starts
   another refresh. The later epoch can supersede the awaited request, which
   returns before the catalog is ready; the chooser treats this as unavailable.
   Device retry succeeds. Official catalog ID `org.icewhale.jellyfin` is correct.
   Locations: `application_center_provider.dart` build/refreshCatalog and
   `nas_deployment_chooser.dart::_openDocker`. Current chooser fake skips the
   real provider's initial refresh, so unit coverage missed this interaction.
   Next fix should await the actual refresh/ready result with target/route guards,
   backed by a real-provider controlled-Future regression; not title matching.
2. **Already-installed native service mislabeled as failure.** The real plan
   includes `NAS_NATIVE_ALREADY_INSTALLED`; the native dialog error resolver has
   no mapping and renders the generic deployment-failed text below its correct
   existing-install explanation. Keep the core blocker/canInstall protection;
   avoid presenting this expected condition as an additional error. The existing
   fake-plan test returns no blockers and needs the real code represented.

## Safety, interference and remaining limits

Added only a named test SSH profile **NAS acceptance VM** and media source
**NAS acceptance Jellyfin**. They remain selected/available for repeat checks.
ADB reverse22023 was added for this fixture. Original server/source definitions
and256MiB cache budget were not edited; remote media, offline files, accounts on
user servers and production deployments were not changed. Existing native test
service and private fixture account were reused, not reinstalled/reinitialized.
VM machine-id and pinned host key matched the documented disposable VM.

At device15:45:14 another app (`com.aptora.app`) was brought to the foreground.
The package guard stopped before the pending Save tap. User then confirmed other
testing had stopped, so Valhalla resumed with its authenticated draft intact.
No attempt was made to stop the other app or clear its data.

Current app-PID log:1663lines, no FATAL EXCEPTION, ANR, RenderFlex, unhandled
exception or Flutter E markers. PID21418 remained alive. Exit history's newest
entry is the expected PACKAGE UPDATED termination of the old APK. The global
crash buffer is **not empty**: it contains a separate UiAutomation process
PID31328 Bad-file-descriptor exception during the interference interval, not a
Valhalla process crash. Animated-player UI hierarchy collection also timed out;
fresh guarded screenshots and MediaSession evidence were used instead of stale
hierarchy files. `41-home-return.png` caught a system transition snapshot; the
settled `43-library-home-return` is the page-state proof.

Not verified: physical-phone performance/audio, cold restart/long background or
lock-screen recovery, Web setup browser handoff, destructive cache cleanup,
populated offline-source filtering, fresh Docker/native installation through the
device UI, or production agents/servers. These are not marked passing. Earlier
isolated service/transport tests are separate evidence, not device UI proof.

Result: installation and the listed device checks completed; **not a clean
all-features acceptance**, because the two presentation/refresh findings remain.
