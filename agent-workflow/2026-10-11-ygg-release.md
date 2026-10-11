# Ygg update-source same-version release

Completed **2026-10-11 14:15:51 UTC**. User explicitly asked the main agent to
build/upload after OpenCode quota prevented completion. This one-operation
exception includes necessary test migration, generation, checks and packaging;
future OpenCode validation/build ownership and original AgY UI ownership remain.
No hand-authored UI change by main: AgY's prior 17 locale text/auth-error changes
were included and generated with Flutter's official l10n generator.

## Published source and compatibility

Source `f1cf8c9a19334e034bb196b9d9d7b59c03d9aabc` was normally pushed with
`[skip ci]`. App is still `1.0.4+5`, package ID and fixed release certificate
unchanged. Android native split codes remain ARM64=2005, ARMv7=1005, x86_64=4005.
Catalog remains `com.norns.valhalla` / `ver_mv3qr13agvpd` / code2005 / default.
Checks and downloads include platform/arch, derived from the application's Dart
runtime ABI rather than hardware-supported ABI lists. Download remains bound
to package_id/version and each package's independent size/SHA256.

Existing public [v1.0.4 Release](https://github.com/NornsInteractive/valhalla/releases/tag/v1.0.4)
(ID409398862) now contains the same 17 names, all freshly verified local files.
Original tag object `359689749927f6bc2e54a824dd77397cca89d8ac` and original source
`b397ec62255fa9cc0575941450a4b2cdadfa4608` stay unchanged. GitHub's automatic
source archive is still original; refreshed binaries point to the source above
in Release notes, BUILD-INFO and update.json. No Actions were triggered.

Same-version clients may need manual download and same-signature installation.
A public release APK cannot overwrite a debug-signed installation. No uninstall,
data clear or ADB operation occurred. Windows/macOS/iOS were not built and are
not substituted with unrelated older binaries.

## Gates and real build evidence

- Fresh focused updater/localization/privacy/storage suite: **140 passed**.
- Fresh entire suite: **2484 passed, 18 explicit environment skips, 0 failed**.
- Existing update-manifest generator: **27 passed**.
- Whole-project analyze: **no issues**; diff-check passed.
- APK `flutter build apk --release --split-per-abi`: 14:05:54–14:07:29 UTC, exit0.
- AAB `flutter build appbundle --release`: 14:07:29–14:07:49 UTC, exit0.
- Linux `flutter build linux --release`: 14:07:49–14:08:34 UTC, exit0.
- All runtime/platform/asset/lock inputs byte-equal before and after building.

APKs passed original-certificate apksigner verification, actual package/native
code/version/ABI/minSdk24/targetSdk36 checks and CRC/unique ZIP-member checks.
AAB jarsigner verification exited0; signer certificate matches. Self-signed,
no-timestamp and JarInputStream warnings are retained, not dismissed as APK v2.
Linux archive contains all 48 actual release runtime files, eight license
notices and embedded BUILD-INFO, with safe single-root paths, x64 ELF and
executable mode verified. The obsolete debug kernel was moved only from the
owned staging copy, retained separately; no original output/cache was deleted.
No missing runner dependencies in this container; not a Linux GUI acceptance.

Tool reports Flutter3.44.2 from cache, but actual framework git is3.38.1.
Both recorded in BUILD-INFO, without SDK patching or an official3.44.2 claim.
No physical-phone / real ACP, OAuth, NAS end-to-end acceptance is claimed.

## Final binary digests

| File | Bytes | SHA256 |
| --- | ---: | --- |
| valhalla-v1.0.4-android-arm64-v8a-signed-5.apk | 45291464 | 3b4c784f901d7219ac341e14d1e2f9ea4dbb72c70869ad496ee7ece8592fcba1 |
| valhalla-v1.0.4-android-armeabi-v7a-signed-5.apk | 43268972 | 9e2a2eccc253d46ed54ca06d3613a92d1b95eff3d1e1c22d249b800cd2a5158a |
| valhalla-v1.0.4-android-x86_64-signed-5.apk | 50246448 | 80e5e7548f8933d24a5fcc65583593879ff6c864b8c5da9f9aa6cd3ba4670d24 |
| valhalla-v1.0.4-android-signed.aab | 79136821 | 8558e3fe9dbc8fb591553f9be9ae6bd9bcb404d81349428190e03a17b053665f |
| valhalla-v1.0.4-linux-x64.tar.gz | 22974176 | 1242db878c8e3136ba120c3e2d1a9936c23e0763a855a04585621247e83da4be |

All eight primaries and eight sidecars match; manifest describes actual frozen
packages. Reused credential/archive audit scanned **2089 surfaces** (17 raw,
2015 ZIP members, 57 tar files) with **0 failures**: no signing password, entire
PKCS12/JKS or genuine DER-backed PEM private-key payload leakage.

## Distribution registration and public proof

MCP currently exposes package add/delete but no in-place metadata update.
Exact prior four external-only records and all 17 GitHub assets were resolved
and backed up before replacement. Only those four metadata records were
removed/re-added; each had null file_key. No R2 binary or historical version was
removed. Prior snapshots/artifacts permit restoration; IDs naturally changed.

| Target | New package ID |
| --- | --- |
| android/arm64-v8a | pkg_mv3wljyqt0rb |
| android/armeabi-v7a | pkg_mv3wlmhpunoq |
| android/x86_64 | pkg_mv3wlpgz0h92 |
| linux/x86_64 | pkg_mv3wls0l62yq |

All four retain the corresponding GitHub v1.0.4 download URLs and new exact
size/structured SHA256. MCP readback preserved the same app/version/history.
Actual GitHub digest/size/uploaded states match all 17 frozen files, original
release identity/publication timestamp retained, source Actions count zero.
Each public platform/arch check returns the correct new file; actual streaming
download from all four package-ID-bound distribution URLs returned200 and
matched new size/SHA256. In addition, **production AppUpdateService** checked all
four platforms/architectures, parsed the new hashes/explicit query parameters,
then downloaded Linux through normal redirect/streaming/integrity logic and
completed successfully. Download-only diagnostic; no executable launch/install.

One redundant later read-only GitHub metadata request timed out after successful
publication/verification; it made no write and does not replace the completed
remote proof. No retry of a mutation was required.

Evidence/rollback directory: `/tmp/valhalla-ygg-release.5yW0qv`.
It contains build logs and original timestamps, source immutability manifest,
backup binaries and remote/distribution-before JSON, frozen inventory, package
proof, preupload audit, publication log, distribution-after/remote-after JSON
and actual production-client check/download. Temporary container evidence
needs external retention if long-term rollback is required.
