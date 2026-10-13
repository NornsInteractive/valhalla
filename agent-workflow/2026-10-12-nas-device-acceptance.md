# Current-tree Android build and ADB acceptance

User explicitly requests packaging, retained-data ADB installation, and actual
device operation after the incomplete NAS upgrade checkpoint. This supersedes
the previous decision to defer an acceptance build, NOT the completion status.
Known two widget failures and one UI warning remain; new NAS redraw/selective
uninstall/native-deployment UI is incomplete. Build is a test candidate, not a
fully accepted release. No version bump, push, publication or UI/product edits.

OpenCode owns build, signature inspection, ADB and tests. First try MiMo free;
only verified-zero-cost fallbacks, including auxiliary model. Save raw evidence
under `/tmp/valhalla-adb-acceptance.FRk3b1CC` and append actual results here.

## Executor instructions

1. Inspect ADB inventory, target ABI, installed app version/certificate and free
   space. Expected previous serial `127.0.0.1:14251`, package
   `com.antigravity.valhalla.valhalla`; verify, never guess a different device.
   If absent, one connect attempt to the known serial is allowed. Never uninstall,
   clear app data, bypass a device lock, change global config or delete caches.
2. Build current tree locally, unchanged `1.0.4+5`, targeting connected ABI.
   Prefer release-mode APK with existing compatible test signing configuration.
   Old installed debug cert SHA256:
   `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`.
   Official cert SHA256:
   `73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d`.
   Preserve formal signing configuration/artifacts and never print secrets. The
   project already selects debug signing for release builds without the four
   VALHALLA_ANDROID signing variables. Use a subprocess-local env choice only.
   Reuse `/tmp/valhalla-app-center-gradle.mgpUTM` if valid; global Gradle init can
   conflict with Flutter. Do not flutter clean or delete shared caches.
   Build normally with pub (stale plugin registration was an earlier no-pub
   issue). Do not modify product, tests, dependencies, pubspec version or UI.
3. Verify APK certificate against actual installed certificate, version, ABI,
   creation time/size/SHA256. Copy fresh artifact to this scratch directory.
   Install with explicit `adb -s SERIAL install -r APK`, retain all data, then
   verify installed APK hash/version/update time and launch the app.
4. Actually operate device using ADB: launch and navigate main drawer/settings,
   app-center store list/grid, NAS existing category/source/download dialogs;
   open/close safe dialogs, Home/background/return. Capture named screenshots,
   UI hierarchy where possible, before/after PID and timestamp-scoped logs.
   Do not claim a tap passed without observing outcome. Detect physical vs
   emulator and say which was tested. Existing enabled experimental features
   may be visited; do not silently enable disabled preferences.
5. Do not deploy/uninstall applications, delete/modify media, send agent prompts,
   approve OAuth, change server settings, clear logs, or exercise destructive
   controls on user targets. Newly incomplete UI must be marked unavailable.
   Device startup/navigation is not proof of Jellyfin playback or deletion safety.
6. Report actual command outcomes, evidence, tested screens and any crashes,
   ANRs, overflow/connection errors. Preserve private logs locally; summarize
   without credentials or user server/file details. Stop on incompatible signing
   or missing/locked device, and report precisely what remains.

Tools: `/opt/flutter/bin/flutter`, `/opt/android-sdk/platform-tools/adb`.
Existing reference: `agent-workflow/2026-10-12-nas-refresh-install.md`.

Read-only review confirms new uninstall/native-deploy/diagnostic/cache APIs have
no UI callers yet. Existing NAS deploy dialog still uses the old installer with
a first-server fallback; do not execute it. Existing store and NAS browsing are
appropriate smoke-test targets. `tool/adb_stability_soak.py` can inform fresh UI
dump/PID/log techniques, but its routes are not this acceptance checklist and
must not be run wholesale on a production target.

## Actual execution (current)

OpenCode MiMo returned rate-limit; Nemotron3 Ultra free performed commands with
intermittent upstream503. Both primary and auxiliary models were explicitly free.

- Verified original target `127.0.0.1:14251`, Android **emulator**, x86_64;
  not physical-handset hardware acceptance. Existing data partition had3.7GBfree.
- Pulled original APK and verified original debug certificate above. Original
  APK SHA256 `28c1d991257770fb32f01fdb76e0ba22789d67d07727ee5b738e2c2929295927`.
- First default-Gradle build failed at repository policy. Reusing the existing
  isolated Gradle home built successfully. First non-split APK nativecode5 was
  correctly refused as a downgrade from installed4005; no uninstall/downgrade
  bypass was used. OpenCode rebuilt the **test candidate only** with
  `--build-number=4005`, matching installed nativecode; pubspec remains1.0.4+5.
- Command: `GRADLE_USER_HOME=/tmp/valhalla-app-center-gradle.mgpUTM
  /opt/flutter/bin/flutter build apk --release --target-platform android-x64
  --build-number=4005` (OpenCode shell pipelines did not enable pipefail;
  distinguish actual Flutter error/success and artifact checks from shellstatus).
- Fresh candidate: `/tmp/valhalla-adb-acceptance.FRk3b1CC/app-release-v4005.apk`,
  SHA256 `bf1a84ca4f45dabd48a4fca50d0f670f42d20f3ba4053dad1c6114d594997f48`.
  Release execution mode with original **debug test certificate**, not a new
  official release artifact. Certificate and aapt metadata verified by OpenCode.
- `adb -s 127.0.0.1:14251 install -r .../app-release-v4005.apk`: **Success**.
  Installed version1.0.4/nativecode4005, device local lastUpdateTime
  **2026-10-12 22:28:37**. No data reset. Startup retains original server and
  enabled experimental menus; app-center still shows prior installed application.
- Actual validated screens so far: dashboard/settings/container list,
  app-center store list scrolling and app-detail open/close, installed tab,
  NAS existing fixture Home/video tab/video actions menu/scan config/library
  settings. Named early `screen_appcenter.png` / `screen_remotefiles.png` were
  launcher misnavigation and are **NOT passing evidence**; later
  `screen_appcenter_real.png` + matching hierarchy are genuine app-center.
- Home→return kept PID15823, but happened while NAS settings modal was still
  open; not sufficient proof of full page/connection recovery. Final specific
  view-toggle, APK-on-device hash and fresh log checks are recorded separately.

### Test side effect, disclosed and corrected

OpenCode confused cache budget chip “关闭” with modal dismissal and tapped it.
Original `ui_nas_lib_settings.xml` proves256MiB selected and1.5MB/11thumbnails.
`restore_before_dump.xml` proves disabled/0MB/0thumbnails after the mistake.
Root interrupted the tester and delegated a narrow restore. Fresh
`restore_after_256tap.xml` proves **256MiB selected=true**; the actual “确认”
button closed the modal (`restore_after_close.xml`). Thumbnail cache was removed
and can regenerate from media later; no remote media or offline file deletion,
no scan/recovery command was executed. Do not claim this run had zero preferences
side effects. This is a testing mistake, not proof of an application crash.

New selective uninstall/native-deployment/redraw UI remains unavailable; no
security/destructive lifecycle or real Jellyfin playback acceptance was performed.
Two known widget failures and one UI warning remain. No push/publication.

### Installed identity and interaction pause

Final OpenCode check queried fresh `pm path` after replacement, then SHA256 of
that installed base.apk: **bf1a84ca4f45dabd48a4fca50d0f670f42d20f3ba4053dad1c6114d594997f48**,
exactly the new candidate. First install time remains2026-09-23 03:26:04.
The earlier stale preinstall-path hash produced empty-input SHA256 and was
rejected as invalid evidence; do not reuse it.

Before final store-toggle verification, a fresh hierarchy showed another
application in the foreground. Root stopped the UI executor and asked whether
device interaction can be exclusive. Do not attribute the foreground switch to
a Valhalla crash without logs. Store view toggle, NAS photo/download, fresh
page-state recovery remain unverified. Only scoped log inspection continues;
no further automatic taps while device ownership is uncertain.

User then confirmed exclusive device availability, authorizing the remaining
safe view tests. A new narrowly scoped OpenCode run requires package/title/label
checks before taps, excludes settings, and resumes store grid/list, NAS photo/
downloads and background-return only.

Read-only log collection before that resume: `fresh-app.log`1076lines since the
install, `fresh-crash.log` empty. No FATAL EXCEPTION/ANR markers found in this
app-PID log (not a complete system ANR audit). Root reviewed actual Flutter lines:
one FlutterJNI detached-response warning at22:30:45 during the earlier root-Back
activity exit; next engine warmed at22:32:23. Do not call warnings absent or infer
an app crash from this. No new Flutter E line was visible in collected evidence.

## Final checkpoint after competing-device test confirmed

User confirmed another AI is simultaneously testing another app. Both current
OpenCode executors were stopped; no further ADB taps or lifecycle commands are
running from this turn. No other project's process/app was stopped or modified.

- Store mode toggles actually observed: `actual_grid.xml` has “列表视图”,
  `actual_list.xml` has “网格视图”, both Valhalla package. At360dp the grid is
  **one column by existing responsive design**, not two. SnapOtter remained the
  first visible item. `actual_list.png` confirms restored original list mode.
- Remote-files root listing was also actually displayed in the final hierarchy;
  no file operations were run. NAS photo/download-modal and final page-state
  lifecycle checks remain **not completed**, not passed.
- `foreground-events.log`: other package was force-stopped/reinstalled at
  device22:56:10 (`installPackageLI`) and launched22:56:25 from shell UID2000;
  also launched22:49:46 from shell UID2000. This demonstrates another ADB actor,
  not a launch originating from Valhalla UID10196. Some later foreground returns
  were additionally caused by this tester wrongly pressing root BACK, not crash.
- Recent crash-buffer query was empty; no app crash/ANR shown in collected
  scoped logs. Shared-device interference prevents reliable full acceptance.

Ready to resume only after other AI releases the device, or on another explicitly
selected ADB device. APK/install proof remains valid. No release, version/source
change or product/UI fix was performed in this packaging/verification turn.
