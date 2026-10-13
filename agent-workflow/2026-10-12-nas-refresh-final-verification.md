# NAS / SSH stability: final local verification

Version remains 1.0.4+5. No push, Release, Actions, uninstall or data clearing.
AgY original Valhalla / gemini-3.8-flash-high / high authored all UI/ARB changes.
OpenCode supplied core regression coverage; root completed final tests/build/ADB
under the user's explicit one-round exception after provider limits/stalled runs.

## Gates

- Hosted dartssh2 4.1.0: 3 pass / 4 fail on seven actual-protocol tests; identical
  tests against local patch: 7 pass. Does not suppress SSH errors globally.
- Final targeted offline provider, image, navigation, responsive UI and terminal
  callback suite: 46 pass (including 320dp/2x, Arabic RTL and desktop forms).
- `flutter gen-l10n`: exit0. `flutter analyze`: exit0, no issues.
- `flutter test --no-pub --reporter expanded`: exit0, **2647 pass / 19 skip**,
  81s. Skips require dedicated VM / Mosh / platform fixtures, not passed tests.
- Root corrected reused test Notifier and RTL close-button targeting. Actual
  overflow repairs went to AgY. No test exclusions or assertion weakening in
  final full suite. Mechanical formatting/braces only after UI authoring.

## Local builds

Existing isolated `GRADLE_USER_HOME=/tmp/valhalla-app-center-gradle.mgpUTM`;
no global SDK/Gradle edits. Official build command: `flutter build apk --release
--split-per-abi --target-platform android-arm,android-arm64,android-x64`, exit0,
87.8s. Original release signing injected privately, never printed/stored in repo.

Artifacts in `build/nas-refresh-validation/official/`:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| valhalla-1.0.4-android-arm64.apk | 46537868 | 689de8ef2a0ddca94fba3bba4d0df692fa146787aaaae953d845a3b6e633194b |
| valhalla-1.0.4-android-armv7.apk | 44679220 | 375c60186199516df6473c847ed107a42870933311362568226d3a68d3f2f39a |
| valhalla-1.0.4-android-x86_64.apk | 51492852 | 54ff05aff249ccd827fa692dd9db124ac1295d9f39d56644c4e1036044f5d2b3 |

Built 2026-10-12 06:02:57 UTC. `apksigner verify` passed, certificate SHA-256
`73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d`.
`aapt dump badging`: correct single ABI and codes 2005 / 1005 / 4005 respectively,
versionName 1.0.4, original package `com.antigravity.valhalla.valhalla`.

Compatible emulator build: same command with only `android-x64` and original
debug certificate; exit0,60.2s. Separate artifact
`build/nas-refresh-validation/valhalla-1.0.4-x86_64-compatible-test.apk`:
51488756 bytes, built06:05:14 UTC, SHA-256
`71943ac3740a2b03532b0ed1e6075453d85a8d7807e0c9fd49154d3da7c26a0d`.
Certificate `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`
matches the pre-install emulator APK. It is NOT a public release-signed package.

## ADB

Device `127.0.0.1:14251` / sdk_gphone64_x86_64, `adb install -r` returned Success.
Installed APK SHA-256 read from device matches compatible artifact exactly.
Installed1.0.4/4005; lastUpdateTime2026-10-12 14:05:37 (device local time);
firstInstallTime unchanged2026-09-23 03:26:04. Cold `am start -W` Status ok,
890ms; original server configuration is visible and connects. Remote-file root
listing loads with original configuration. No server writes or Agent prompts.
After returning to the launcher and reopening the App, the remote-file root
listing remained present; UI dump contains no incident banner. Final logcat check
since installation: corrected `adb logcat -d -T '10-12 14:05:30.000'` exited0,
2731 lines spanning14:05:30.846–14:10:23.231, zero `Unhandled Exception`,
`FATAL EXCEPTION` or `[ERROR:flutter` matches. Initial date-marker capture had
lost its time component and logcat exited1; that empty capture is NOT evidence.
Only `device-final-logcat.log` is used for this conclusion. Keyboard dump reports
`mInputShown=false` and `mIsInputViewShown=false`. Returned the App to Dashboard.
Existing NAS experiment
was not enabled/changed on the device: NAS UI/offline controls were verified by
widget/provider tests, not real media playback on this emulator. No settings or
server records were intentionally changed; normal directory-history recording
is part of opening the file page.

## Evidence and limits

Logs/screenshots under `/tmp/valhalla-nas-refresh.OOGiIt/`: final-gen.log,
final-analyze.log, final-full-test.log, root-targeted-green.log, build-official.log,
build-compatible.log, official-artifacts.jsonl, compatible-artifact.log,
adb-install.log, adb-start.log, device-final-logcat.log, device-start.png.
Temporary evidence may be removed outside this task; above hashes/results are
durable documentation, actual binaries remain in build/nas-refresh-validation.

No physical-phone performance, real ACP/OAuth, all media-source protocols, TV,
desktop-native, HLS offline packaging or adversarial user-server faults tested.
SMB without reliable resource version cannot safely resume partial downloads.
Interrupted downloads restore paused; this is not an OS-surviving background
download daemon. Emulator smoke is not complete real-world acceptance.
