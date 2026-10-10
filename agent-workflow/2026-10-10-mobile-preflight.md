# Mobile Preflight - 2026-10-10

## Disk

| Path | Filesystem | Size | Used | Avail | Use% |
|------|-----------|------|------|-------|------|
| /workspace/projects/valhalla | /dev/nvme0n1p8 | 458G | 383G | 52G | 89% |
| /tmp | overlay | 458G | 383G | 52G | 89% |

- Available disk: **52G** on both paths (same underlying volume).

## Devices

- `adb devices -l`: **no devices connected** (empty list).
- Device serial: N/A — no device to report.
- Device ABI / current app versionCode / signing checks: **not run** (condition requires exactly one connected device; zero present).

## Release Certificate Availability (filenames only)

- **Fixed signing is deliberately OUTSIDE the repository** — not-found-in-repo does NOT mean not-on-disk.
- Repo glob for `*.jks`/`*.keystore`/`*.p12`/`*.pkcs12`/`*.pfx`/`*.cer`/`*.pem`: none in repo (expected; location is external).
- External signing path stat (metadata only; **contents/password never read**):

| Path | Type | Size | Perms |
|------|------|------|-------|
| /home/dev/.local/share/valhalla-signing/android-release.p12 | regular file | 3452 bytes | 600 |
| /home/dev/.local/share/valhalla-signing/android-release.password | regular file | 65 bytes | 600 |

## Verdict

- Preflight FAIL for on-device work: no device connected, so ABI/versionCode/signing verification cannot proceed.
- Fixed release certificate: **present on disk** at `/home/dev/.local/share/valhalla-signing/` (`android-release.p12`, 3452 B; `android-release.password`, 65 B; perms 600) — deliberately outside repo; verified by filename/stat only.
- Disk space sufficient (52G free) for builds.

## Retry — Emulator Connected (2026-10-10)

- `adb devices -l` initially empty → `adb connect 127.0.0.1:14251` → connected; single device `127.0.0.1:14251` (product: sdk_gphone64_x86_64, transport_id: 1). All checks used explicit `-s 127.0.0.1:14251`.

### Read-only device checks (all exit=0)

| Check | Command | Result |
|-------|---------|--------|
| Boot | `getprop sys.boot_completed` | `1` (booted) |
| ABI list | `getprop ro.product.cpu.abilist` | `x86_64,arm64-v8a` |
| Primary ABI | `getprop ro.product.cpu.abi` | `x86_64` |
| APK path | `pm path com.antigravity.valhalla.valhalla` | `/data/app/~~X74z4h8MUrY_O2l1ezh2Gg==/com.antigravity.valhalla.valhalla-U4mw7056YTHsq3doe48YCw==/base.apk` |

### Installed app: com.antigravity.valhalla.valhalla

- versionCode=`1`, versionName=`1.0.0`, minSdk=24, targetSdk=36
- firstInstallTime=2026-09-23 03:26:04, lastUpdateTime=2026-10-04 18:13:34
- apkSigningVersion=2, single signer, dataDir=/data/user/0/com.antigravity.valhalla.valhalla (not touched)

### APK pull (installed base APK only; no private data)

- Pulled `base.apk` (123,916,922 bytes) to `/tmp/opencode/valhalla-preflight/base.apk`; exit=0. No app private data accessed.

### Signing certificate (apksigner verify --print-certs)

- Verifies: true; APK Signature Scheme v2 only (v1/v3 false); 1 signer.
- Signer DN: `C=US, O=Android, CN=Android Debug` → **installed APK is debug-signed (standard Android debug key)**, not the fixed release keystore.
- Cert SHA-256: `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`; SHA-1 `f0fb4ad6bd3dd2d9513a0573b40910adb4d288c2`; RSA 2048.

### Preflight verdict (revised)

- 1 emulator connected at `127.0.0.1:14251`, booted, ABI x86_64.
- Installed app v1.0.0 (versionCode 1) is **debug-signed**; fixed release keystore on disk not used so far.
- Nothing installed, started, stopped, or built; main source untouched.
