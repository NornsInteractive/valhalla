# Build + local ADB evidence — 2026-10-11 (x86_64 release-mode debug-cert TEST build)

Companion to `2026-10-11-six-final-verification.md`. Everything below was executed in this
session with exact `$?` capture; logs in `/tmp/opencode/six-final-gates-final.QcWx9V/`.
Selector: **exact transport `127.0.0.1:14251` only** (`adb -s 127.0.0.1:14251`).
Times are UTC unless marked +08:00 device local.

## Preflight

- 2026-10-11T09:17:17Z signing-env presence: all of `VALHALLA_ANDROID_KEYSTORE`,
  `VALHALLA_ANDROID_STORE_PASSWORD`, `VALHALLA_ANDROID_KEY_ALIAS`, `VALHALLA_ANDROID_KEY_PASSWORD`,
  `VALHALLA_CI_UNSIGNED` **unset** (presence only; no values read/printed).
- `pubspec.yaml` `version: 1.0.4+5`; `pubspec.lock`/`pubspec.yaml` md5
  `4c3e81e69fbc089af0e1967c21d4c9e6` / `ac455a934e4faecbd40a055e012f85dc` unchanged by the build.
- Source fingerprint (tracked lib/android/assets/pubspec+lock + untracked owned lib source;
  excludes build/cache/`.dart_tool`/local.properties/signing/test reports), digest
  `f5ce0efea731f476583d3fc0cf344cd97e89f34dd49b4c270c2194721c6e01cc`
  **before == after** (per-file lists byte-identical; `source-fingerprint-before2.txt`,
  `source-fingerprint-after2.txt`).

## First build attempt — preserved failure (evidence kept)

- `flutter build apk --release --target-platform android-x64 --split-per-abi --no-pub`
  09:12:19Z → 09:13:17Z, exit 1.
- `:app:compileReleaseJavaWithJavac` error on git-ignored generated
  `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java:39`
  (`dev.flutter.plugins.integration_test` missing — dev-only plugin, stale generated file;
  `--no-pub` skips platform-tooling regeneration). No source/registrant manual edit, no SDK
  patch, no `flutter clean`, no dependency change. Log: `build-apk.log`.

## Build — actual

- `flutter build apk --release --target-platform android-x64 --split-per-abi` (no `--no-pub`),
  09:17:27Z → 09:17:52Z, **exit 0** ("✓ Built ... app-x86_64-release.apk (50.2MB)").
  Tool-native regeneration ran with the pinned lock; `pubspec.lock` md5 identical afterwards.
- APK `build/app/outputs/flutter-apk/app-x86_64-release.apk`:
  size 50,242,416; mtime 2026-10-11 17:17:51.764 +08:00;
  sha256 `1508e446162fe22c449520d883081fb6f396ebf8b1008b7473dd339c9de4ca0c`.
  aapt: `com.antigravity.valhalla.valhalla` `versionCode='4005'` `versionName='1.0.4'`,
  `native-code: 'x86_64'`, min 24 / target 36.
  apksigner verify: pass, single signer `CN=Android Debug, O=Android, C=US`, cert SHA-256
  `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` (original debug cert).
- Old output preserved BEFORE build by copy to owned temp
  `/tmp/opencode/six-build-backup.LXYM7O/outputs/` (old universal `app-release.apk`
  sha256 `0733639f1784bec7162c4e07bb425a1f05daade5dd5e96f5cee2b51a96d744c9`, 128,717,610 bytes).
- New APK staged in owned mktemp `/tmp/opencode/six-stage-final.eFXlmL/app-x86_64-release.apk`
  (sha256 identical to built artifact).

## Device — fresh reprobe before install (`adb -s 127.0.0.1:14251`)

- `get-state` → `device`. No `adb connect`/`disconnect` performed or needed.
- dumpsys package: `versionCode=4004`, `versionName=1.0.3`, min 24/target 36,
  `firstInstallTime=2026-09-23 03:26:04`, `lastUpdateTime=2026-10-10 17:18:07`.
- Pulled installed base.apk (`/tmp/opencode/six-pull-before.3RkPBe/base.apk`, 49,717,584 B):
  sha256 `7b732e5e00d09bcc1e48c61e37cbd1ed442b1a5138e2428da2f4081691b12ad0` (equals the
  2026-10-11 preflight hash), cert `2faa583f…37e9` (original debug cert), badging 4004/1.0.3,
  `native-code: 'x86_64'` — same-signer replacement therefore allowed, no downgrade.

## Install — actual

- Command: `adb install -r /tmp/opencode/six-stage-final.eFXlmL/app-x86_64-release.apk`,
  started 09:19:26Z, **exit 0**, output "Performing Streamed Install / Success".
  No `-d`, no uninstall, no `pm clear`, no data wipe.
- After (dumpsys + fresh pull `/tmp/opencode/six-pull-after.q509QJ/base.apk`):
  `versionCode=4005`, `versionName=1.0.4`, `firstInstallTime=2026-09-23 03:26:04` **unchanged**,
  `lastUpdateTime=2026-10-11 17:19:25` (new). Pulled APK sha256
  `1508e446162fe22c449520d883081fb6f396ebf8b1008b7473dd339c9de4ca0c` == staged; cert
  `2faa583f…37e9` == staged; `native-code: 'x86_64'`. Version went **up** (4004→4005, 1.0.3→1.0.4);
  universal code-5 APK was never used or installed.

## Read-only smoke

- Launch `am start -n com.antigravity.valhalla.valhalla/.MainActivity` → exit 0, dashboard visible.
- IME: `dumpsys input_method` `mInputShown=false` on launch, with menu open, and with
  add-server dialog open — no unsolicited keyboard.
  Additional after-cancel probe exit0: `mInputShown=false`, activity probe exit0
  shows Valhalla `.MainActivity` top resumed. Evidence: `smoke-ime-after-cancel.log`
  and `smoke-activity-after-cancel.log` (not inferred from earlier checks).
- Navigation: more-functions drawer opens and shows all entries (仪表盘, 智能会话, SSH终端, 远程文件,
  容器管理, 系统运维, 快捷运维, 系统设置, 添加服务器); selecting 添加服务器 opens its dialog.
- Dialog: 添加服务器 dialog opened (登录密码/私钥内容/Mosh 开关/测试连通性/取消/保存服务器/关闭),
  cancelled with KEYCODE_BACK → back on dashboard, no server saved, no pref written.
- Preserved visible configuration: server `racknerd` ("已连接") and system info
  still rendered after replace-install. Same-signature `install -r`, unchanged
  `firstInstallTime` and retained server support data-preserving replacement,
  but do not independently verify every stored datum or cold-cache restoration.
  `run-as` is unavailable because a release-mode build is not debuggable;
  no app data was read via run-as, and none was needed.
- Not performed: SSH terminal commands, agent prompts/history, preference edits, production
  process/service/container/power operations, OAuth consent.

## Not verified by this evidence

Real ACP agent flows, real OAuth/Google consent, real NAS streaming endpoints, physical phone
hardware, Windows native and other platforms, public release keystore signing.
