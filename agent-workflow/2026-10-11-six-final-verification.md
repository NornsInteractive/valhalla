# Final verification — 2026-10-11 (six workstreams final gate + local ADB test install)

Scope: fresh complete gate run + authorized local Android release-mode ORIGINAL DEBUG CERT
test build + data-preserving `adb install -r` on transport `127.0.0.1:14251`.
No release publication, no git commit/push, no Actions/cloud, no other platform/AAB,
no shared-cache cleanup, no uninstall/data-clear, no SSH commands, no real agent prompts,
no preference mutations, no OAuth consent. Model: `opencode/step-5-preview-free` (main AND small),
explicitly free; no paid tier, no title, no subagents used for this run.

All gate/build/device evidence logs live in the fresh unique dir
`/tmp/opencode/six-final-gates-final.QcWx9V/` (mktemp, mode 700). The prior 1-fail run
(`+2494 ~18 -1`, exit 1) is preserved unmodified at
`/tmp/opencode/six-final-gates-rerun.stYzuh/gate5-fulltest.log`; the earlier failed
`--no-pub` build log is preserved at
`/tmp/opencode/six-final-gates-final.QcWx9V/build-apk.log` (exit 1) with its start/end
UTC stamps; old build output backup at `/tmp/opencode/six-build-backup.LXYM7O`
(previous `app-release.apk` sha256
`0733639f1784bec7162c4e07bb425a1f05daade5dd5e96f5cee2b51a96d744c9`, 128,717,610 bytes,
mtime Oct 5 — the universal APK was preserved, not overwritten in place before backup).

## 1. Gates — fresh run in `/tmp/opencode/six-final-gates-final.QcWx9V/`

Each command's own `$?` captured immediately after the command, before any `tail`; no
tee/pipeline exit reuse; foreground unfiltered redirection; natural completion.

| # | gate | command | actual exit | evidence |
| --- | --- | --- | --- | --- |
| 1 | gen-l10n | `flutter gen-l10n` | **0** | `gate1-genl10n.log` |
| 2 | format (dry-run, task-changed/new Dart, generated excluded) | `dart format --set-exit-if-changed --output=none` on 31 files from `git status --porcelain` excluding `lib/l10n/app_localizations*` | **0** — "Formatted 31 files (0 changed)" | `gate2-format-dryrun.log`, `gate2-format-targets.txt` |
| 3 | whitespace | `git diff --check` | **0** (no output) | `gate3-gitdiffcheck.log` |
| 4 | analyze whole | `flutter analyze --no-pub` | **0** — "No issues found!" | `gate4-analyze.log` |
| 5 | test whole | `flutter test --no-pub --reporter expanded` | **0** — "All tests passed!" | `gate5-fulltest.log` |

Gate 5 actual measured counts (this run, not reused from any earlier run):
**+2495 passed, ~18 skipped, 0 failed, exit 0** (final line `01:18 +2495 ~18: All tests
passed!`). Total discovered2513; executed/passed2495, skipped18 (not executed).
The first full run2484passed/18skipped/11failed remains at
`/tmp/opencode/six-final-gates/full-suite.log`; fixture fixes28/28 and53/53 preserve
original behavior checks. Previous run `+2494 ~18 -1 exit 1` (stYzuh) is history;
the single failure there (`test/core/sftp_transfer_records_test.dart:745` managed-download
cancel part-file removal, a fixture timing race) had already been fixed in the settled
workspace and is not reintroduced.

## 2. Build preflight (presence-only, secrets never read or printed)

- Signing env presence (names only): `VALHALLA_ANDROID_KEYSTORE`, `VALHALLA_ANDROID_STORE_PASSWORD`,
  `VALHALLA_ANDROID_KEY_ALIAS`, `VALHALLA_ANDROID_KEY_PASSWORD`, `VALHALLA_CI_UNSIGNED` — all **unset**
  (`presence-signing-env.txt`). Therefore the Gradle `release` buildType resolves to the debug
  signing config, i.e. the original local debug keystore `/home/dev/.android/debug.keystore`
  (authorized data-preserving test route per `2026-10-11-six-adb-preflight.md`). No keystore or
  password material was read, printed or written.
- `pubspec.yaml`: `version: 1.0.4+5` unchanged; md5 of `pubspec.yaml`/`pubspec.lock` identical
  before and after build (`ac455a93…` / `4c3e81e6…`).
- Source fingerprint (tracked `lib` + `android` + `assets` + `pubspec.yaml` + `pubspec.lock`
  plus untracked owned `lib/*.dart`; excludes build/cache/`.dart_tool`/`local.properties`/
  signing/test reports), per-file SHA-256 lists captured before and after build:
  **identical, digest `f5ce0efea731f476583d3fc0cf344cd97e89f34dd49b4c270c2194721c6e01cc`**
  (`source-fingerprint-before2.txt` == `source-fingerprint-after2.txt`, byte-identical file lists).
  The build (including its `pub get`) did not mutate tracked source, untracked owned source,
  or the dependency lock.

### First build attempt (preserved failure evidence)

`flutter build apk --release --target-platform android-x64 --split-per-abi --no-pub`
2026-10-11 09:12:19Z → 09:13:17Z → **exit 1**, `build-apk.log`: `:app:compileReleaseJavaWithJavac`
failed on the git-ignored tool-generated `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`
referencing `dev.flutter.plugins.integration_test` (dev-only plugin; the file was stale from the
last writer-session `pub get`; with `--no-pub` the tool does not regenerate platform tooling).
This is a stale generated-artifact/tool issue, not a UI/core/ARB source problem. No manual
registrant edits, no SDK patch, no `flutter clean`, no dependency upgrade, no signing change were
made. Lock/content were left untouched.

## 3. Build — actual result

- Command (exact, no `--no-pub`, letting the tool regenerate platform tooling with the pinned lock):
  `flutter build apk --release --target-platform android-x64 --split-per-abi`
- Window: 2026-10-11 09:17:27Z → 09:17:52Z; **exit 0** (`build-apk-regenerated.log`,
  `build2-start-utc.txt`, `build2-end-utc.txt`).
- Toolchain: Flutter 3.44.2 stable (Dart 3.10.0); Gradle `assembleRelease` 23.2s.
- Artifact: `build/app/outputs/flutter-apk/app-x86_64-release.apk`
  - size 50,242,416 bytes; mtime 2026-10-11 17:17:51 +08:00
  - SHA-256 `1508e446162fe22c449520d883081fb6f396ebf8b1008b7473dd339c9de4ca0c`
  - aapt badging: `versionCode='4005'`, `versionName='1.0.4'`, `native-code: 'x86_64'`,
    `sdkVersion:'24'`, `targetSdkVersion:'36'`, label `valhalla`
  - apksigner: Verifies; Signer #1 DN `C=US, O=Android, CN=Android Debug`,
    certificate SHA-256 `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`
    (== original debug keystore cert == installed package's cert; NOT the public release cert
    `73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d`, which remains untouched
    and unused).
- Staged (owned mktemp): `/tmp/opencode/six-stage-final.eFXlmL/app-x86_64-release.apk`
  (identical sha256 as above).

## 4. Device/adb and install — actual result

Detail and timelines in `agent-workflow/2026-10-11-six-build-adb.md`. Summary:

- Selector used everywhere: exact transport `127.0.0.1:14251` (`adb -s 127.0.0.1:14251`);
  state `device`. No `adb connect`/`disconnect`, no other serial/transport touched.
- Before install (dumpsys + pulled base.apk): `versionCode=4004`, `versionName=1.0.3`,
  `firstInstallTime=2026-09-23 03:26:04`, `lastUpdateTime=2026-10-10 17:18:07`, pulled APK
  sha256 `7b732e5e00d09bcc1e48c61e37cbd1ed442b1a5138e2428da2f4081691b12ad0` (same as preflight),
  cert `2faa583f…37e9`, `native-code: x86_64`.
- Install: `adb install -r` staged x86_64 APK → **exit 0, "Success"** (streamed, 09:19:26Z start).
  No downgrade flags, no uninstall, no clear-data.
- After install (dumpsys + pull): `versionCode=4005`, `versionName=1.0.4`,
  `firstInstallTime=2026-09-23 03:26:04` **unchanged** (data preserved),
  `lastUpdateTime=2026-10-11 17:19:25` (new); pulled installed APK sha256
  `1508e446162fe22c449520d883081fb6f396ebf8b1008b7473dd339c9de4ca0c` == staged hash;
  cert `2faa583f…37e9` == staged cert; `native-code: x86_64`.
- Read-only smoke: launch `.MainActivity` exit 0; no auto-shown IME at any of four checks
  (`mInputShown=false`); drawer/menu navigation responsive (仪表盘/智能会话/SSH终端/远程文件/
  容器管理/系统运维/快捷运维/系统设置/添加服务器 all present); add-server dialog opened
  (取消/保存服务器/关闭 present, no forced keyboard) and cancelled with back → dashboard restored;
  pre-existing `racknerd` server ("已连接") and system info (uptime/hardware/OS)
  still displayed. This verifies visible configuration retention, NOT cold-cache
  restoration; live connection/info cannot prove which cache supplied a frame.
  Final after-cancel probe exit0 shows `mInputShown=false` and
  Valhalla `.MainActivity` as topResumedActivity (`smoke-ime-after-cancel.log`,
  `smoke-activity-after-cancel.log`), distinguishing this from the three earlier
  launch/menu/dialog-open checks. No SSH terminal command executed, no agent
  prompt/history write, no preference change, no production process/service/container/power action.

## 5. Explicitly NOT verified / not exercised

Real end-to-end **ACP** (agent) flows, real **OAuth**/Google consent, real **NAS** streaming
endpoints, physical **phone** hardware, **Windows native** and other platform builds, and the
public release keystore path were not tested by this run (they are outside the local
debug-cert test APK route). Cold-cache restoration and physical keyboard/frame
performance were not established by this emulator smoke. The18 skipped tests
require explicitly configured isolated operations/SSH/NAS/power VM fixtures,
WebDAV fixture port or real Mosh server; they are not counted passed. No
expectation was deleted, skipped into green, or weakened to obtain this result.
