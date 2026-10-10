# v1.0.3 Refresh — Local Package Build & Verification (handoff)

- Date (UTC): 2026-10-10
- Actor: OpenCode only (local build/verify/package). Task-local model
  `opencode/step-5-preview-free` (catalog input/output/cache prices all zero).
- Status: **PASS — 15 staged assets built/reused and verified locally.**
- Boundary: this pass did **NOT** push git, create/update a tag, upload or
  publish a release, call any GitHub API, or run any ADB/device operation.
  Publishing is owned upstream (root) and happens separately. No product/UI/
  source/ARB edits. No Windows/macOS/iOS and no cloud build.

## Staging directory (deliverable location)

- **Release staging dir: `/tmp/opencode/valhalla-v103-refresh-release-9UjF5U`**
  (new `mktemp -d`). Exactly 15 files. The prior release copies in
  `/tmp/opencode/valhalla-v1.0.3-release` were left untouched for recovery.

## Source identity

- Working repo `/workspace/projects/valhalla`, HEAD =
  `a885e97b89840d7126f83756730ca412021f6b84`
  ("fix: repair mobile navigation terminal and Docker regressions [skip ci]").
- New isolated `mktemp` git worktree created at that exact commit:
  `/tmp/opencode/valhalla-v103-refresh-src-6mzPEt` (detached HEAD == the commit).
- Version `1.0.3+4` (`pubspec.yaml`), app id
  `com.antigravity.valhalla.valhalla`, team **Norns Interactive**
  (cert subject `CN=Valhalla, O=NornsInteractive`).
- Fixed release cert SHA-256
  `73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d`.

## Three-APK reuse gate (all must match — passed)

Reused the final official signed APKs from
`/tmp/opencode/mobile-fixes-release-final-X0KgaC` after BOTH gates matched:

1. **Build-source gate** — the APK build snapshot
   `/tmp/opencode/mobile-fixes-src-TaKT4c` was compared against THIS commit's
   tracked compile inputs (`lib/`, `android/` minus regenerated
   `GeneratedPluginRegistrant`, `assets/`, `packages/`, `pubspec.yaml`,
   `pubspec.lock`). Result: **604 / 604 identical, 0 mismatch, 0 missing.**
2. **File + signature gate** — file SHA-256 equals the expected official values,
   `apksigner verify --print-certs` exit 0, single signer, cert SHA-256 matches:
   - arm64-v8a  `55a4e5bc9ad4d20163a032eb6405a922e15d83802b5c52fc87c7fc606c100b78`
   - armeabi-v7a `372cf7fb8a15192c9c10fb6f5f2f15d955745351574b8409611a67ec63cefebd`
   - x86_64     `41c706ece499da622ff1cd46c8ac9af106543811424c3b0f388f19013e549e6f`

   The debug-signed device test APK was **not** used.

## Builds (sequential, local; SDK/deps/lock unchanged; no upgrades)

Signing used the external fixed store
`/home/dev/.local/share/valhalla-signing/android-release.p12`, alias `valhalla`,
password read privately from `android-release.password` into task-local
`VALHALLA_ANDROID_*` env only (never in argv, logs, repo or the report; env
cleared after each build). No global config edit; no SDK licence acceptance.

`flutter pub get` — **exit 0**, `pubspec.lock`/`pubspec.yaml` byte-unchanged
(`git diff --exit-code` exit 0). No upgrades.

| Build (from new a885e97 worktree) | Exit | Notes |
|---|---|---|
| `flutter build appbundle --release` | **0** | `build/app/outputs/bundle/release/app-release.aab` |
| `flutter build linux --release` | **0** | `build/linux/x64/release/bundle/valhalla` + `lib/` + `data/` |

## Artifact times (UTC)

| Item | Time |
|---|---|
| APK build (reused artifacts, mtime) | 2026-10-10T09:17:09Z |
| AAB build | ran 10:09:41Z (mtime 10:10:22Z) |
| Linux executable build | ran 10:10:38Z (mtime 10:12:29Z) |
| Linux tar.gz creation | 2026-10-10T10:24:12Z |

## SDK / toolchain (recorded truthfully, both facts)

- `flutter --version` reports **3.44.2**; framework revision
  `b45fa18946ecc2d9b4009952c636ba7e2ffbb787` is exact-match git tag **3.38.1**.
  Dart 3.10.0. This is the documented discrepancy — artifacts must **not** be
  described as an official Flutter 3.44.2 SDK release. SDK not upgraded/modified.
- Android SDK 36.0.0 / build-tools 36.0.0 (`apksigner`/`aapt`), OpenJDK 17.0.20.
- Host Debian 12 x86_64; cmake 3.25.1, ninja 1.11.1, clang 14.0.6.

## Verification exits (real, unmasked)

Android:
- APKs (staged copies): `apksigner verify --print-certs` exit 0 (x3);
  `aapt dump badging` exit 0 (x3); cert SHA-256 matches; package
  `com.antigravity.valhalla.valhalla`; versionName `1.0.3`; versionCode
  arm64 2004 / armeabi 1004 / x86 4004.
- AAB (staged copy): `jarsigner -verify` **exit 0** (not apksigner; **NOT**
  warning-free — self-signed cert/PKIX, no timestamp, 528 "signed in JarFile
  but is not signed in JarInputStream" consistency lines). `keytool
  -printcert -jarfile` fingerprint matches the APK cert. Protobuf metadata from
  `base/manifest/AndroidManifest.xml`: package + versionName `1.0.3` +
  versionCode `4` (exit 0).

Linux (read-only structural/ELF/ldd only — application never executed, **no
runtime acceptance claimed**):
- `readelf -h`: ELF64, little-endian, `DYN` (PIE), EM_X86_64, entry `0x4750`,
  interpreter `/lib64/ld-linux-x86-64.so.2`, RUNPATH `$ORIGIN/lib`.
- `ldd` exit 0, **0 "not found"**, 243 libraries resolved (gtk-3/gdk-3,
  libsecret-1, libmpv, flutter engine all resolved).
- `gzip -t` exit 0; `tar -tzf` exit 0; **79 members**; exe mode `-rwxr-xr-x`;
  in-tar `BUILD-INFO.txt` byte-identical to the Linux sidecar.

Staged set:
- `sha256sum -c SHA256SUMS.txt` exit 0 (all 7 primaries OK); all 7 `*.sha256`
  sidecars `sha256sum -c` OK.
- Asset count = **15**. Isolated worktree remains clean:
  `git diff --exit-code` exit 0, `git status --porcelain` 0 lines, HEAD == commit.

Secret exclusion (across all 5 packages + plaintext):
- Secret-looking **filenames**: 0. Password value present: **0** (plaintext,
  packages, and tar contents all scanned). Real PEM private-key payloads
  (BEGIN + ≥60-byte base64 body + END): **0**.
- The only `PRIVATE KEY` substring occurrences are the known benign strings
  documented in the prior release: the app sanitizer placeholder
  (`lib/core/logging/sanitizer.dart`, in `libapp.so`) and the engine
  `-----BEGIN…-----END` null-separated token-table strings (in
  `libflutter*.so`); the AAB also embeds those via `*.debugsymbols` `.sym`
  copies. No keystore/password/pem file ships in any package. No secret value is
  printed anywhere.

## Final staged assets — exactly 15 (Staging dir: `/tmp/opencode/valhalla-v103-refresh-release-9UjF5U`)

| # | Name | Bytes | SHA-256 |
|---|---|---|---|
| 1 | valhalla-android-armeabi-v7a-v1.0.3-signed.apk | 42,744,204 | `372cf7fb8a15192c9c10fb6f5f2f15d955745351574b8409611a67ec63cefebd` |
| 2 | valhalla-android-arm64-v8a-v1.0.3-signed.apk | 44,766,696 | `55a4e5bc9ad4d20163a032eb6405a922e15d83802b5c52fc87c7fc606c100b78` |
| 3 | valhalla-android-x86_64-v1.0.3-signed.apk | 49,721,680 | `41c706ece499da622ff1cd46c8ac9af106543811424c3b0f388f19013e549e6f` |
| 4 | valhalla-android-v1.0.3-signed.aab | 78,508,677 | `8204aba40d50456a95a02c8b888da003c187fd48f90e0e497386ca8a33b5d1ba` |
| 5 | valhalla-linux-x64-v1.0.3.tar.gz | 22,942,470 | `d5a41bba23fad6aeb0d18f784f65c9db5a4e8ce229e36739cb9bdc4855bc5372` |
| 6 | valhalla-android-v1.0.3-BUILD-INFO.txt | 7,873 | `43f4550d556a274d0380a43c032410bd6201185481c6d3185e2b32627e3febea` |
| 7 | valhalla-linux-x64-v1.0.3-BUILD-INFO.txt | 7,194 | `c44477caced84ae237af8e79e4201b98f9479f7b0b00a4fe827191da4f76c03c` |
| 8–14 | the 7 `.sha256` sidecars (one per file 1–7) | 99–113 | e.g. arm64 sidecar `651073ef…`, generate/verify `sha256sum -c` all exit 0 |
| 15 | SHA256SUMS.txt (covers the 7 primaries) | 744 | `d7a5f7deada389f2b97fbfed25e3fc991a630f54aaedc734b21ce9fdf8b7caea` |

Names match the existing release asset names exactly. Linux tar contains the
full single-directory bundle under `valhalla/`: executable (`-rwxr-xr-x`),
`lib/`, `data/` (ICU + flutter_assets), `notice/` (LICENSE, NOTICE, xterm,
libsmb2 LGPL/NOTICE set) and `BUILD-INFO.txt`. BUILD-INFO files record org,
exact source commit, UTC build times, the actual SDK discrepancy, the signing
fingerprint and version, and the test-scope boundary.

## Test scope

- Carried from the existing authoritative gate (not re-run in this pass):
  **2195 passed, 18 environment skips, 0 failures**; `flutter analyze lib` —
  "No issues found" (exit 0). This packaging pass introduced no source, test or
  dependency changes.

## Not performed / not claimed

- No git push, tag create/move, release create/upload/edit, GitHub API, or ADB
  operations. No cloud build, no `[skip ci]` Actions dispatch. Root owns
  publishing; clobber upload and remote verification are done separately.
- No real-device install, emulator run, desktop launch, GUI, server, or network
  acceptance test. Linux was inspected read-only (ELF header, RUNPATH, ldd)
  only; the AAB is a Play artifact and is not directly installable. The AAB
  jarsigner warnings are retained as recorded (not warning-free).

## Workspace integrity

- Tracked tree and `pubspec.lock`/`pubspec.yaml` unchanged in the isolated
  worktree (`git diff --exit-code` exit 0; porcelain empty). This report is the
  only file authored outside `/tmp/opencode`.
