# Six ADB/signing preflight (read-only) — 2026-10-11

Scope: READONLY ADB + signing preflight only. No build, no install, no launch,
no uninstall, no clear-data, no git writes, no Flutter commands (build/test/
gen/format), no Actions/Release changes, no remote agent prompts, no server
mutations, no cleanup, no subagents. Gates for build/install remain closed.

Model/runtime: explicitly MiMo free main + small (step-5 free fallback), as in
`agent-workflow/2026-10-11-six-phase1-verification.md`. Prior phase-1 ADB facts
(transport `127.0.0.1:14251`, serial `EMULATOR37X1X11X0`) were used as the
starting reference and were re-probed live below.

Probe window (host local, `+08:00`): 2026-10-11 15:17:5x → 15:18:57.

## Toolchain

| item | value |
| --- | --- |
| adb | `/opt/android-sdk/platform-tools/adb`, `1.0.41`, `Version 37.0.0-14910828` |
| apksigner | `/opt/android-sdk/build-tools/36.0.0/apksigner` (34.0.0/35.0.0/36.0.0 present) |
| aapt | `/opt/android-sdk/build-tools/36.0.0/aapt` |
| java/keytool | OpenJDK 17.0.20 (`/usr/bin/keytool`), used with `-storepass:env` so no password bytes ever hit argv, stdout or this file |

## Live device state (`adb devices -l`, transport present; no `adb connect` needed)

| item | value |
| --- | --- |
| transport | `127.0.0.1:14251` state `device`, `transport_id:2` |
| device row | `product:sdk_gphone64_x86_64 model:sdk_gphone64_x86_64 device:emu64xa` |
| exact serial | `EMULATOR37X1X11X0` (both `ro.boot.serialno` and `ro.serialno`, re-checked at 15:18:57) |
| OS | Android 14 (SDK 34), build type `userdebug` |
| CPU ABI | `primaryCpuAbi=x86_64`, `secondaryCpuAbi=null`; `ro.product.cpu.abilist=x86_64,arm64-v8a` |

Device was online for the whole probe; final `adb devices -l` at
2026-10-11T15:18:57+08:00 still shows the same single device. No "device
absent" branch was taken.

## Installed package (from `adb shell dumpsys package`, read-only)

| item | value |
| --- | --- |
| package | `com.antigravity.valhalla.valhalla` |
| version | `versionCode=4004`, `versionName=1.0.3` |
| SDK | `minSdk=24`, `targetSdk=36` |
| codePath | `/data/app/~~wGUQ52r1UCDxAWwK1MGotg==/com.antigravity.valhalla.valhalla-yAGF6U61pLWlML3TrFAhIA==/base.apk` |
| firstInstallTime | `2026-09-23 03:26:04` |
| lastUpdateTime | `2026-10-10 17:18:07` |
| flags | `pkgFlags=[ HAS_CODE ALLOW_CLEAR_USER_DATA ALLOW_BACKUP ]` |
| PM signing | `apkSigningVersion=2`, `signatures=PackageSignatures{6c45db4 version:2, signatures:[6e5dbc6], past signatures:[]}`, `Signing KeySets: 60` |

`6e5dbc6` is the packageManager signing-object id only — it is **not** a
certificate digest and was not used for any comparison below.

## APK pull (installed base APK only; no app data)

Owned temp dir, freshly created, mode 700, owned by this agent's uid:

- dir: `/tmp/opencode/six-adb-preflight.JIp8h3/` (from `mktemp -d`, `chmod 700`)
- file: `/tmp/opencode/six-adb-preflight.JIp8h3/base.apk`
- size: `49,717,584` bytes
- SHA-256 of pulled file: `7b732e5e00d09bcc1e48c61e37cbd1ed442b1a5138e2428da2f4081691b12ad0`
- evidence copy of verifier output: `/tmp/opencode/six-adb-preflight.JIp8h3/apksigner-verify.txt`

Only the `base.apk` path from `pm path` was pulled. No `/data/data/...`,
no app databases, no shared prefs, no external app dirs were read or written.
Source path on device was not modified.

`aapt dump badging` cross-check on the pulled file:
`package: name='com.antigravity.valhalla.valhalla' versionCode='4004'
versionName='1.0.3'`, `sdkVersion:'24'`, `targetSdkVersion:'36'`,
`native-code: 'x86_64'` (x86_64 only — matches the device's primary ABI).

## Real certificate probe (`apksigner verify --print-certs -v` on pulled base.apk)

```
Verifies
Verified using v1 scheme (JAR signing): false
Verified using v2 scheme (APK Signature Scheme v2): true
Verified using v3 scheme (APK Signature Scheme v3): false
Verified using v3.1 scheme (APK Signature Scheme v3.1): false
Verified using v4 scheme (APK Signature Scheme v4): false
Number of signers: 1
Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
Signer #1 certificate SHA-256 digest: 2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9
Signer #1 certificate SHA-1 digest: f0fb4ad6bd3dd2d9513a0573b40910adb4d288c2
Signer #1 certificate MD5 digest: 80633e7c14c1b64a11a6a8b9c874e60a
Signer #1 key algorithm: RSA
Signer #1 key size (bits): 2048
Signer #1 public key SHA-256 digest: 728f02dc11c7183735b71dfc584b00c185f83917a0217c8ecd0bf45ceba2d9fb
```

This is the real DER certificate digest of the APK that is actually installed
(device serial `EMULATOR37X1X11X0`, versionCode 4004), not the
packageManager object id `6e5dbc6`.

## Comparison

| source | cert SHA-256 | result |
| --- | --- | --- |
| installed APK (pulled `base.apk`, real cert via apksigner) | `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` | — |
| original local debug keystore `/home/dev/.android/debug.keystore`, alias `androiddebugkey` | `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` (keytool: `2F:AA:58:3F:…:37:E9`) | **MATCH** (byte-identical digest) |
| public release cert (fixed, from prior reports `2026-10-10-v103-build.md` / `2026-10-11-v104-release.md`) | `73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d` | **MISMATCH** |

Debug keystore facts (public certificate metadata only, via
`keytool -exportcert -rfc | openssl x509`):

- path: `/home/dev/.android/debug.keystore` (2,618 bytes, mtime 2026-09-13)
- alias: `androiddebugkey`, entry type `PrivateKeyEntry`, created 2026-09-13
- subject: `CN = Android Debug, O = Android, C = US`
- validity: `notBefore=Sep 13 11:48:08 2026 GMT`, `notAfter=Sep 5 11:48:08 2056 GMT`
- certificate SHA-256: `2F:AA:58:3F:B6:46:2E:EC:F5:07:C8:F6:D0:E1:4D:46:EE:8B:51:2F:AB:79:40:B3:0C:7A:93:7B:5C:7F:37:E9`

Password handling: the keystore password was supplied only through
`-storepass:env KS_PASS` inside the shell (env var set, never echoed, never
written to any file, never placed on argv). No private key bytes, no PKCS#8/#
PKCS#12 material, no password material was exported, printed or stored. The
release keystore under `/home/dev/.local/share/valhalla-signing/` was **not
opened** at all this run; the release comparison uses the already-public fixed
certificate hash `73dc6d17…83a92c7d` from prior reports, which is the same hash
those reports verified against the published v1.0.3/v1.0.4 artifacts.

## Existing Android signing config (read-only)

`android/app/build.gradle.kts`:

- Release signing is driven purely by env vars:
  `VALHALLA_ANDROID_KEYSTORE`, `VALHALLA_ANDROID_STORE_PASSWORD`,
  `VALHALLA_ANDROID_KEY_ALIAS`, `VALHALLA_ANDROID_KEY_PASSWORD` (all four
  required together; presence-checked, values never read here).
- Current shell state: **all four UNSET**, and `VALHALLA_CI_UNSIGNED` UNSET.
- Therefore the `release` buildType currently resolves to
  `signingConfigs.getByName("debug")` (the explicit local debug-key workflow
  kept for adb development, `android/app/build.gradle.kts:66-71`).
- `android/key.properties` does **not** exist (this project does not use it;
  nothing created it).
- Repo-wide glob for `*.jks` / `*.keystore` / `key.properties*` / `*.pepk`:
  none in the repository (release material is deliberately external, per
  `agent-workflow/2026-10-10-mobile-preflight.md`).

## Determined data-preserving test route

The device's installed package (versionCode 4004, first installed
2026-09-23, last updated 2026-10-10 17:18:07) is signed with the **original
local debug certificate** (`2faa583f…37e9`), not the release certificate
(`73dc6d17…92c7d`). Consequences for the eventual (not-yet-authorized) test
install:

1. Data-preserving route = build a test package signed with the **same original
   debug keystore** (`/home/dev/.android/debug.keystore`, alias
   `androiddebugkey`) and install with `adb install -r` (INSTALL_REPLACE_
   EXISTING). Same-signer replacement keeps `/data/data/
   com.antigravity.valhalla.valhalla` intact — no clear, no uninstall.
2. That is exactly what the existing Gradle config already does when the
   `VALHALLA_ANDROID_*` release env vars are unset: the `release` buildType
   falls back to the `debug` signing config. So a release-mode test package
   produced by the current config is debug-cert signed — authorized by the
   user because the installed app is debug-signed.
3. No release keystore involvement is needed for the data-preserving test
   route. The public release keystore and any `key.properties` (nonexistent)
   must never be replaced or modified — neither was touched, read or written
   in this run.
4. If a future install were signed with `73dc6d17…92c7d` over this debug-signed
   install, Android would reject it as a signature mismatch and would require
   uninstall (data loss). That path is **not** chosen and not authorized here.

Nothing in this section was executed — it is the determined route only. Build
and install remain gated.

## Explicitly not done

- No `flutter build` / `flutter test` / `flutter gen` / `dart format`.
- No install, reinstall, launch, force-stop, clear, uninstall, or any
  `pm`/`am` mutating command; no app data directory touched.
- No git add/commit/stage/checkout; working tree left as found (pre-existing
  `git status --porcelain` shows 78 entries, none created or modified by this
  run).
- No Actions/Release changes, no remote agent prompts, no server mutations, no
  cleanup of pre-existing artifacts, no subagents.
- No password, private key, keystore secret, or env secret content was read
  into or emitted from this report; only public certificate digests, paths and
  metadata appear above.

Status: device online, installed build is debug-cert signed
(`2faa583f…37e9` == `/home/dev/.android/debug.keystore`), release cert
(`73dc6d17…92c7d`) not present on device; data-preserving test route confirmed
as debug-signed `adb install -r`. Awaiting final gates before any
build/install.
