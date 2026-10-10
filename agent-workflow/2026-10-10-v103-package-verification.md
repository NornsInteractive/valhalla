# Valhalla v1.0.3 Package Verification Report

Date (UTC): 2026-10-10
Status: **PASS - local packaging complete, 15 assets**
This verifier performed no upload. Main's later upload/publication is tracked in
the separate GitHub verification report and release handoff.

## Boundary note (task history, no false passes)

Two attempts preceded this result. Neither is counted as a pass:

1. **First attempt - cancelled by SIGINT (exit 130).** It performed the
   verification work (APK/AAB/Linux checks, secret scan, notice staging) but
   was cancelled before final packaging completed and left a partial Linux tar.
   All its real logs are still in `/tmp/opencode`
   (`v103-apksigner-*.exit`, `v103-aapt-*.exit`, `v103-unzapk-*.exit`,
   `v103-jarsigner-aab.exit`, `v103-unzaab.exit`, `v103-ldd-valhalla.log`).
2. **Second attempt - paused at a real blocker.** It found the first attempt's
   tar had been built before `BUILD-INFO.txt` existed. The partial archive
   lacked the embedded info, so did not satisfy the final packaging condition.
   It was never published. Rather than silently overwrite it,
   the task was stopped and the blocker reported.

**Recovery (this run).** The stale partial tarball was preserved, then a
corrected archive was built from the complete stage:

```
mv -n release/valhalla-linux-x64-v1.0.3.tar.gz \
      /tmp/opencode/v103-partial-linux-before-build-info.tar.gz   exit=0
```

The preserved file (22,794,331 bytes) is recorded here for audit only. It is
**not** part of the release and was never re-uploaded or re-used.

## Source gate (read-only)

| Item | Value |
|---|---|
| HEAD commit | `0dc0a3dbef6c3b7ec26b1cf994863e5c6fa2d2ec` (matches expected, exact) |
| pubspec version | `1.0.3+4` |
| `git diff HEAD --stat` | empty in this phase; command was piped, so its printed exit is not an independent unmasked gate |
| `git diff --cached` | empty |
| untracked files | 0 |

No source, UI or ARB edits were made at any point. Only the release package
BUILD-INFO files and the verification report were authored.
The earlier build/retry phase separately recorded unmasked tracked-source and
lockfile `git diff --exit-code` gates with exit 0; see the build report.

## Android gates (all exit 0, unmasked)

APKs, verified with build-tools **36.0.0** `apksigner` and `aapt`:

| Gate | armeabi-v7a | arm64-v8a | x86_64 |
|---|---|---|---|
| `apksigner verify --verbose --print-certs` | 0 | 0 | 0 |
| `aapt dump badging` | 0 | 0 | 0 |
| `unzip -tq` | 0 | 0 | 0 |

| Assertion | Value | Result |
|---|---|---|
| Certificate SHA-256 (each APK, exactly one signer) | `73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d` | match |
| Certificate DN | `CN=Valhalla, O=NornsInteractive` | match |
| package name | `com.antigravity.valhalla.valhalla` | match |
| versionName | `1.0.3` | match |
| versionCode | armeabi-v7a `1004`, arm64-v8a `2004`, x86_64 `4004` | match |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 | recorded |

ABI code derivation: baseCode `4` (pubspec `1.0.3+4`) with per-ABI multipliers
1/2/4 -> 1004/2004/4004. Consistent with the v1.0.2 scheme (1003/2003/4003).

### AAB gates (jarsigner, not apksigner)

| Gate | Exit |
|---|---|
| `jarsigner -verify -verbose app-release.aab` | 0 |
| `unzip -tq app-release.aab` | 0 |
| `keytool -printcert -jarfile` (fingerprint extraction) | 0 |

Certificate fingerprint from `keytool -printcert -jarfile`:
`73:DC:6D:17:8B:BD:7A:BA:1E:F8:5D:D1:8B:26:6A:D4:91:AE:00:0C:08:91:5B:9E:E6:2C:FC:83:83:A9:2C:7D`
- identical to the APK signing certificate; single signer.
- Self-signed, **no timestamp**, 3072-bit RSA, SHA256withRSA.
- Valid 2026-10-04 to 2054-02-19.

**AAB warning summary (this release is NOT warning-free).** jarsigner reports:
the signer certificate is self-signed and the CA chain is not verifiable
(PKIX path building failure); the signature carries no timestamp so the jar may
become unverifiable after the certificate expires; POSIX file permission /
symlink attributes are present but are ignored by signing and not protected by
the signature; and `JarFile` / `JarInputStream` report internal inconsistencies
("Manifest is missing when reading via JarInputStream"). Entry census: 515
entries signed with a manifest entry, 1 manifest-only, 0 unsigned. jarsigner
still exits 0.

AAB metadata (`base/manifest/AndroidManifest.xml`, protobuf): package
`com.antigravity.valhalla.valhalla`, versionName `1.0.3`, versionCode `4`. These
were read as paired attribute name/value entries, not as loose string matches.
AAB size 78,399,360 bytes. **The AAB is a Play distribution artifact and is not
directly installable on a device**; installs use the architecture-specific APKs.

Secret-material scan (see also the dedicated section below): no private key
payloads and no keystore-like files exist in any Android artifact.

## Linux gates (read-only; application never executed)

| Gate | Result |
|---|---|
| `bundle/valhalla` ELF check | ELF64, little-endian, `DYN` (PIE), EM_X86_64, entry `0x4750` |
| program interpreter | `/lib64/ld-linux-x86-64.so.2` |
| `lib/libflutter_linux_gtk.so` | present, 33,865,776 bytes (Flutter engine) |
| `lib/libvalhalla_smb.so` | present, 277,144 bytes, exports 267 `smb2_*` symbols |
| `lib/libapp.so` | present, 17,875,888 bytes |
| `data/icudtl.dat` | present, 778,864 bytes |
| `data/flutter_assets/` | AssetManifest.bin, FontManifest.json, version.json, LICENSE, NOTICE, NOTICES.Z, assets/, fonts/, packages/, shaders/ |
| notices (see below) | 8 files embedded |
| `ldd valhalla` | exit 0, **no missing libraries** |

System runtime dependencies required on the host (Debian 12): GTK3 stack
(`libgtk-3`, `libgdk-3`, pango/harfbuzz/cairo/gdk-pixbuf/atk/atspi/glib/
gobject/gio/gmodule), X11/libxcb and Wayland (`libwayland-client`,
`libwayland-cursor`), `libxkbcommon`, `libepoxy`, `libfontconfig`,
`libsecret-1.so.0` (secure-storage backend), `libmpv.so.2` plus the ffmpeg
media stack (`libavcodec/avformat/avutil/avfilter/avdevice/swscale/swresample`,
`libplacebo`, libass, libdvdnav/dvdread/bluray/cdio, libx264/x265, libaom,
libdav1d, soxr), audio backends (asound/jack/pulse/pipewire/sdl2), and the base
C++/glibc/runtime set (`libstdc++`, `libgcc_s`, `libc`, `libz`, `libm`,
`libdl`, `libpthread`, GL/EGL/GLX/GLdispatch).

**Limits:** the Linux bundle is **not** distro-signed (no package, no packager
GPG, no code signature) and is **not** a universal or static bundle - the GTK3,
libsecret, libmpv and media/audio libraries are external host dependencies
resolved by the dynamic loader at run time. Bundle libraries load from `lib/`
through the runner's relative RPATH, so no system install and no
`LD_LIBRARY_PATH` are needed.

## Times (UTC) - recorded separately

| Item | Time (UTC) | Local (UTC+8) |
|---|---|---|
| APK build (all three ABIs) | 2026-10-10 03:05:52Z | 11:05:52 |
| AAB build | 2026-10-10 03:09:30Z | 11:09:30 |
| Linux executable / bundle build | 2026-10-10 03:14:12Z | 11:14:12 |
| Linux release archive creation (final) | 2026-10-10 03:38:49Z | 11:38:49 |

The Linux build initially failed with ENOSPC; the operator freed space and
re-ran the same command. The retry exited 0. No cleanup of the successful
output was performed and no shared caches (including
`/home/dev/.gradle/caches/8.10.2/transforms`) were cleared.

## SDK / toolchain (recorded truthfully, both facts)

| Item | Value |
|---|---|
| Flutter reported by `flutter --version` | **3.44.2** (local cache) |
| Flutter framework revision | `b45fa18946ecc2d9b4009952c636ba7e2ffbb787` |
| Framework exact-match git tag | **3.38.1** |
| Dart | 3.10.0 |
| Android SDK / build-tools | 36.0.0 / 36.0.0 (`/opt/android-sdk`) |
| Java | OpenJDK 17.0.20 |
| Build host | Debian 12, x86_64, cmake 3.25.1, ninja 1.11.1, clang 14.0.6 |

**Discrepancy:** the local cache reports `3.44.2` while the checked-out framework
revision is exact-match tag `3.38.1`, which is what this source targets. These
artifacts must not be described as an official Flutter 3.44.2 SDK release.

## Notices shipped inside the Linux archive

All notice and licence **texts** were copied from the source repository at commit
`0dc0a3d` and embedded under `valhalla/notice/`:

`LICENSE` (PolyForm Noncommercial 1.0.0), `NOTICE`, `xterm/LICENSE` (MIT, (c)
2020 xuty), `xterm/NOTICE`, `libsmb2/NOTICE` (Ronnie Sahlberg,
LGPL-2.1-or-later), `libsmb2/LICENCE-LGPL-2.1.txt`, `libsmb2/COPYING`,
`libsmb2/README`.

Only texts are shipped. The libsmb2 upstream **source tree is not** bundled in
the archive; it lives in the repository under
`packages/valhalla_smb/vendor/libsmb2` (tag libsmb2-6.2, commit
d67e213a5c4e7e4969fd81f0b95e4ca5831fbba1). The compiled libsmb2 code is linked
into `valhalla/lib/libvalhalla_smb.so`. `data/flutter_assets/NOTICES.Z` also
contains the xterm MIT text and the libsmb2 notice (it carries the pointer text
only; the full LGPL texts are the ones added under `notice/`).

## Secret scan

Streamed scans over all five final packages (no extraction):

| Scope | Result |
|---|---|
| Secret-looking member **filenames** (APKs/AAB/tar: pem, p12, pfx, jks, keystore, key, der, password, passphrase, secret, credential, privatekey, id_rsa) | 0 matches |
| Full PEM private-key payload (base64 body >= 60 chars between BEGIN/END with a valid END) | **0** in all packages |
| `[REDACTED_PRIVATE_KEY]` marker | found only in `lib/libapp.so` (app's own sanitizer, `lib/core/logging/sanitizer.dart`) - a redaction placeholder, not a key |
| `-----BEGIN \x00-----END \x00` null-separated token | found only in `lib/libflutter_linux_gtk.so` (engine token table) - a library string with no key body |

Per-package real-payload counts: armeabi-v7a 0, arm64-v8a 0, x86_64 0, AAB 0,
final tar 0. Upstream certificate bytes referenced above are public signing
material, not private key payloads. No raw secret value was printed at any step.
The four APK/AAB packages were already scanned in the first attempt and were not
re-scanned in full; the scanned counts above come from those recorded runs.

## Final release assets - exactly 15 files

Directory: `/tmp/opencode/valhalla-v1.0.3-release`

| # | Name | Bytes | SHA-256 |
|---|---|---|---|
| 1 | valhalla-android-armeabi-v7a-v1.0.3-signed.apk | 42,644,688 | `faa8d77661663af4fd590ddeeefc4f53dde1a2a6d6fdf0c95d9e0a522dbc69b2` |
| 2 | valhalla-android-arm64-v8a-v1.0.3-signed.apk | 44,667,180 | `32b62cd0526a5834ca671e9754a88e4295406051ae97a52a2d2f2fda2db9818c` |
| 3 | valhalla-android-x86_64-v1.0.3-signed.apk | 49,622,164 | `73890c1645972c3fa11e3f5a663e767f68defcc5ba204c12236610964ac7c6b9` |
| 4 | valhalla-android-v1.0.3-signed.aab | 78,399,360 | `d02f97e31396511ce1a08f2a57394fd8becce0075b0581c0063c4ecb01a91c59` |
| 5 | valhalla-linux-x64-v1.0.3.tar.gz | 22,799,300 | `c9afd6cd683a453de6166aebf0089461aae44343acbef02220d2011c9a6329b8` |
| 6 | valhalla-android-v1.0.3-BUILD-INFO.txt | 4,618 | `f3b2427d27d292824cc9516303cc071d319bc43579ec70a8fef0dd6fb9ce6ab6` |
| 7 | valhalla-linux-x64-v1.0.3-BUILD-INFO.txt | 5,423 | `e6b450be0db62391c11fa23f6276ad9792506636b7f051cb4ad819654dbcb99a` |

Sidecars (`*.sha256`, one per primary file above) - all generated and verified:

| # | Sidecar | Bytes | SHA-256 |
|---|---|---|---|
| 8 | valhalla-android-armeabi-v7a-v1.0.3-signed.apk.sha256 | 113 | `8501f878e4a5992764e568d892f5482c1b64a7d277e165c79fcb8cb8ed4cddd9` |
| 9 | valhalla-android-arm64-v8a-v1.0.3-signed.apk.sha256 | 111 | `b5051c7e5ca2a2ac6b5e5738743459fd1df2f5455c6be9ec9bfbddb5b2421603` |
| 10 | valhalla-android-x86_64-v1.0.3-signed.apk.sha256 | 108 | `8ab4c855d7493a5ebcd8a385f083e86fc29259d972c362e27ecae5c3f4d25fd5` |
| 11 | valhalla-android-v1.0.3-signed.aab.sha256 | 101 | `2156c6b6ca036e068bc25c1d48d5f5bf5b0429c98c3f9df549636f638e27267a` |
| 12 | valhalla-linux-x64-v1.0.3.tar.gz.sha256 | 99 | `6755fe68ce288860868e1ecea90f3b10735d1c0a5f92281fde93e8a91ef41589` |
| 13 | valhalla-android-v1.0.3-BUILD-INFO.txt.sha256 | 105 | `281fedad78a4220ad7ba9134dc495820fca281cde2faec1f6c16e504144513af` |
| 14 | valhalla-linux-x64-v1.0.3-BUILD-INFO.txt.sha256 | 107 | `15be4eb7d977c836a4c7ae974f44f8708ce357e7bf4910d40c32af9fc898d64e` |

| # | Name | Bytes | SHA-256 |
|---|---|---|---|
| 15 | SHA256SUMS.txt (covers the 7 primary files, not itself) | 744 | `7cefa22871a34abbf78801c2725346a81a30aa7e22e255a1b8338fddc80b8711` |

Total: 15 files (7 primary + 7 sidecars + 1 manifest). No packaging scripts,
tools, certs, keystores, temp or control files are present in the directory.

Final archive structure: 79 members under `valhalla/`
(`valhalla` executable mode `-rwxr-xr-x`, `lib/` 11 members, `data/` 54 members,
`notice/` 11 members, plus `BUILD-INFO.txt`; counts include directory entries).
Required embedded members all present:
`valhalla/valhalla`, `valhalla/BUILD-INFO.txt`, `lib/libvalhalla_smb.so`,
`lib/libflutter_linux_gtk.so`, `lib/libapp.so`, `data/icudtl.dat`,
`data/flutter_assets/AssetManifest.bin`, `notice/LICENSE`, `notice/NOTICE`,
`notice/xterm/LICENSE`, `notice/xterm/NOTICE`, `libsmb2/NOTICE`,
`libsmb2/LICENCE-LGPL-2.1.txt`, `libsmb2/COPYING`, `libsmb2/README`.

## Verification exits (real, not masked)

| Check | Exit |
|---|---|
| `gzip -t valhalla-linux-x64-v1.0.3.tar.gz` | 0 |
| `tar -tzf valhalla-linux-x64-v1.0.3.tar.gz` | 0 |
| `sha256sum -c SHA256SUMS.txt` | 0 |
| per-sidecar `sha256sum -c` (all 7) | 0 |
| final asset count | 15 |
| source commit match | pass |
| secret scan (all 5 packages) | 0 real payloads |

## Not verified (do not claim otherwise)

- No real-device install or emulator run.
- No desktop launch, GUI, server or network test. The Linux binary was only
  inspected read-only (ELF header, RPATH, `ldd`).
- No on-device runtime check of the SMB client, media playback or terminal
  features.
- AAB warnings are retained as recorded above; the AAB's distribution
  suitability for Play is a separate main-level decision.

A separate specialist report covers AAB protobuf schema pairing; that
investigation is not duplicated here.

## Paths

- Release dir: `/tmp/opencode/valhalla-v1.0.3-release` (15 files, exactly)
- Preserved partial tar (audit only, not a release asset):
  `/tmp/opencode/v103-partial-linux-before-build-info.tar.gz`
- Source: `/tmp/opencode/valhalla-v1.0.3-source` at `0dc0a3d`
- Earlier live logs: `/tmp/opencode/v103-*.log`, `v103-*.exit`,
  `v103-ldd-valhalla.log`, `v103-tar-members*.txt`

No upload was performed by this verifier. Publication is coordinated separately.
