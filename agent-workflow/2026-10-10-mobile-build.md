# Mobile Build Final - 2026-10-10

## Status: BUILD + INSTALL COMPLETE; final full suite also passed

## Source identity (isolated snapshot)

- Snapshot: `/tmp/opencode/mobile-fixes-src-TaKT4c` (tar copy of main working tree; excluded .git/.dart_tool/build/.gradle/.cxx/.flutter-plugins*/GeneratedPluginRegistrant)
- Synced files (formatted identical in main + snapshot):
  - `lib/features/docker/docker_view.dart` sha256 `900ee3660d8258a8db716499dcc45f09b9dca82f145f561c984ffbb1d2ddb707`
  - `lib/features/files/sftp_file_view.dart` sha256 `56d6ab635e9b2710de061c97389bdb163da114684b31c81e143b69e52ebbeb4a`
- Combined Dart source hash (main == snapshot): `c1aaa09af064e706d1d2664407d6df35b95c87465d89531dc4042dc4b3b72d19`
- `pubspec.lock` unchanged (identical sha256 `ad85ff70…` main vs snapshot; no upgrades)
- `diff -rq lib` main vs snapshot: identical at build time

## Format / analyze (main tree)

- `dart format` applied only to: motion_widgets.dart, docker_provider.dart, docker_view.dart, sftp_file_view.dart, main_shell.dart, terminal_view.dart, docker_cli_service.dart
- `flutter analyze lib` → **No issues found**, exit=0

## Build history (honest exits)

1. Main-tree `flutter build apk --release --split-per-abi` → **FAILED exit=1** (116s): `GeneratedPluginRegistrant.java:39` references `dev.flutter.plugins.integration_test` (package not on release classpath). Root cause: concurrent Flutter test session regenerated shared registrant during build (race). No production Gradle/SDK/deps edited.
2. Isolated snapshot official build → exit=0, 193s (intermediate, superseded by docker_view fix)
3. Isolated snapshot official build (docker_view fix synced) → exit=0, 99s (intermediate, superseded by sftp_file_view fix)
4. **FINAL isolated snapshot official build → exit=0, 89s**

## Final official artifacts (fixed release cert)

- Dir: `/tmp/opencode/mobile-fixes-release-final-X0KgaC` (published v1.0.3 release dir untouched)
- Cert SHA-256: `73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d` (all 3 APKs, apksigner verify_exit=0)

| APK | bytes | sha256 | versionCode |
|-----|-------|--------|-------------|
| app-arm64-v8a-release.apk | 44,766,696 | `55a4e5bc9ad4d20163a032eb6405a922e15d83802b5c52fc87c7fc606c100b78` | 2004 |
| app-armeabi-v7a-release.apk | 42,744,204 | `372cf7fb8a15192c9c10fb6f5f2f15d955745351574b8409611a67ec63cefebd` | 1004 |
| app-x86_64-release.apk | 49,721,680 | `41c706ece499da622ff1cd46c8ac9af106543811424c3b0f388f19013e549e6f` | 4004 |

- Appid: `com.antigravity.valhalla.valhalla`, versionName `1.0.3`
- Icon resources verified via `aapt2 dump resources`: mipmap/ic_launcher (adaptive anydpi-v26 XML + mdpi..xxxhdpi legacy PNG), ic_launcher_round, ic_launcher_foreground, color/ic_launcher_background

## TEST-debug-signed x86_64 APK (debug key, release mode)

- Dir/file: `/tmp/opencode/mobile-fixes-TEST-debug-signed/valhalla-1.0.3+4-x86_64-TEST-debug-signed.apk`
- Build exit=0, 15s (default Gradle debug signing, no official env)
- Cert SHA-256: `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` — **equals installed device fingerprint** (CN=Android Debug, RSA 2048)
- 49,717,584 bytes, sha256 `7b732e5e00d09bcc1e48c61e37cbd1ed442b1a5138e2428da2f4081691b12ad0`, versionCode 4004, versionName 1.0.3, appid com.antigravity.valhalla.valhalla — certificate check passed BEFORE install

## Install + device verification (user-approved, data-preserving)

- `adb -s 127.0.0.1:14251 install -r <TEST-debug-signed.apk>` → `Success`, INSTALL_EXIT=0 (no uninstall, no data clear)
- Post-install package state: versionCode=4004, versionName=1.0.3
  - `firstInstallTime=2026-09-23 03:26:04` (UNCHANGED — data preserved)
  - `lastUpdateTime=2026-10-10 17:18:07`
  - signatures unchanged: `PackageSignatures{33d5678 version:2, signatures:[6e5dbc6], past signatures:[]}`
- Launch: `am start -n com.antigravity.valhalla.valhalla/.MainActivity` exit=0; **PID 29875**; focus on `MainActivity`
- Fatal scan (logcat window after launch): no FATAL EXCEPTION/ANR for the app (only benign `VM exiting with result code 0`)

## Pending

- Flutter test suite owned by another OpenCode session: final run now 2195 passed, 18 skipped, zero failed, exit 0; analyze/diff check also exit 0. See `2026-10-10-mobile-final-gates.md`. This report's own run covers format/analyze/build/sign/install/launch verification only.
- No cloud builds, pushes, or releases. ADB actions: passive checks + one approved `install -r` + launch only.
