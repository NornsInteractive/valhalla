# Experimental CLI Chat — Device Deployment Evidence (2026-10-04)

## Context / Authorization

- Scope: bounded ADB device install + launch only; this run supersedes the earlier
  no-ADB restriction ONLY for this deployment. No rebuilds, tests, source/ARB/config/
  git/dependency changes, no signing keys/credentials, no pm clear/uninstall/adb root.
- OpenCode context: session `ses_efa045a6bffeBnDODUfPKr6YLw`, legacy
  `ses_f0405efacffePPqWyhHc3GGJY7` preserved; main+small model
  `opencode/fledge-alpha-free`, official+local cost 0.

## Device

- Endpoint serial: `127.0.0.1:14251` (sdk_gphone64_x86_64 emulator, product
  sdk_gphone64_x86_64, transport_id 4). Initially absent from `adb devices -l`;
  one `adb connect 127.0.0.1:14251` succeeded; no server reset. Single device,
  no guessing required. All ops used explicit `adb -s 127.0.0.1:14251`.

## Artifact / Signature Preflight

- Artifact: `build/app/outputs/flutter-apk/app-release.apk`, SHA-256
  `0e9a37d1d99664814ed4635eb904ef14d447c4e2260a010287ec02d0331dfc96` (matches expected).
- Package `com.antigravity.valhalla.valhalla`, versionName 1.0.0, versionCode 1,
  activity `com.antigravity.valhalla.valhalla.MainActivity`, targetSdk 36 (aapt badging).
- Prior installed base pulled into fresh `/tmp/opencode/valhalla-adb-1Qf51e/`:
  older build, SHA-256 prefix `8a0bdd0de0897605` (full
  `8a0bdd0de0897605623aae9f2745ed49c30d2ff56ebc649079a1905a056cd47f`).
- apksigner cert of installed base: Signer #1 SHA-256
  `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` — matches the
  expected development cert → signature compatible. No uninstall/clear needed.

## Install / Installed Hash

- Command: `adb -s 127.0.0.1:14251 install -r build/app/outputs/flutter-apk/app-release.apk`
  → `Performing Streamed Install`, `Success`.
- dumpsys after: versionName 1.0.0, versionCode 1, targetSdk 36,
  lastUpdateTime `2026-10-04 17:08:07` (+0800, = `2026-10-04T09:08:07Z`).
- Pulled installed base from new path
  `/data/app/~~aGRQgyhycT3zUrCpxMlo6Q==/.../base.apk` → SHA-256
  `0e9a37d1d99664814ed4635eb904ef14d447c4e2260a010287ec02d0331dfc96` — EXACT match with the
  artifact; 123,916,922 bytes. Used data-preserving `install -r`; no uninstall or
  data-clear command executed. Existing firstInstallTime before installation was
  `2026-09-23 03:26:04`; individual settings were not inspected after installation.

## Startup (bounded)

- `am start -n com.antigravity.valhalla.valhalla/.MainActivity` → started intent OK.
- At UTC `2026-10-04T09:08:49Z`: `pidof` = 17353 alive (~12s post-launch);
  `topResumedActivity=...valhalla/.MainActivity` (resumed).
- Filtered logcat scan (without a `-T` time boundary; historical buffer included):
  no fatal/ANR lines appeared in the returned five matching entries. The returned
  `Process ... has died` lines are
  historical, timestamped `10-03 15:07–15:08` (previous day, pre-install), matching
  pre-existing records, not evidence of a new crash. No full log output or logcat
  clear; this is bounded startup evidence, not a comprehensive crash audit.
- No manual interaction with chats/settings/preferences/login/consent/remote features;
  expected auto-reconnect startup threads untouched. Preserve-all-data install.

## Limitations / Not executed

- No on-screen UI screenshot verification of the experimental tile or CLI entry
  (out of this bounded scope); launch limited to PID/resumed-activity + fatal/ANR scan.
- No account/server/agent/history inspection; no sign-in state reported.
- Device is an x86_64 emulator endpoint; ARM ABI behavior not covered.
