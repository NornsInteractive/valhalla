# v1.0.5 terminal / Gboard release refresh

User requested republishing the existing 1.0.5 after terminal modifier delivery.
This supersedes the prior no-publication boundary for this release only.

## Contract

- Keep 1.0.5+6, application identity, original formal signing certificate and the
  existing public release. Local three-ABI Android APK, AAB and Linux x64 only;
  no Actions, Windows/macOS/iOS, ADB operation or production server tests.
- Preserve v1.0.5 tag / target `ce3ebe1323903030ae83ebfb648c28c04d969922`.
  Commit and push source normally with `[skip ci]`. BUILD-INFO, manifest and
  release notes must identify the actual new source; tag source archives remain
  the original source. Never force push or move the tag.
- Snapshot live metadata and match the 17 original assets to the retained backup
  before replacing exactly those filenames. Upload binaries/checksums before the
  update manifest. Retain old artifacts and verify new remote sizes and hashes.
- Refresh the existing Yggdrasil com.norns.valhalla 1.0.5+6 version and four
  platform/architecture packages, including SHA256 and size. The MCP API cannot
  modify existing package hashes. User explicitly authorized backing up and
  re-registering these four external records only; IDs change and package
  download counters may reset. Preserve all other versions and records.
- MiMo and Big Pickle returned rate limits; Step 5 returned endpoint unavailable,
  before executing any build. User explicitly authorized the main agent to
  complete validation/build/packaging and this release only. No UI changes.
- Verify original certificate, version/ABI, fresh release payloads, complete
  Linux archive, unchanged sources/lock, checksums and credential exclusion.
  Test-signed device APK must never be uploaded as a formal release.

## Existing proof and limits

Terminal/Gboard source has 163 passing focused regressions and zero analyzer
issues; actual Gboard local-probe bytes were verified before restoring the normal
app on ADB. See [delivery](2026-10-13-terminal-gboard-modifiers.md). New publication
does not imply a new physical-phone or Linux GUI acceptance test.

Same-version clients may need a manual download. Formal APKs cannot cover an
installation signed with the device-test key; do not uninstall or clear data.

## Local verification completed

Actual source `b3d5c28f2efae0d5090858a7cba73eac8ae32d5f` was pushed normally;
the terminal change is `45539b1237d582d146a8ce3e7d937a9fe47c49b0`.
Fresh focused regression: **163 passed / 0 failed**; analyzer: **no issues**.
No source/lock changes occurred during the builds. Evidence is retained in
`/tmp/valhalla-v105-refresh.xqbC8y`.

| Local release command, explicit `--target lib/main.dart` | Start → end UTC, 2026-10-13 |
| --- | --- |
| `flutter build apk --release --split-per-abi` | 14:47:40 → 14:48:41 |
| `flutter build appbundle --release` | 14:48:41 → 14:48:56 |
| `flutter build linux --release` | 14:48:56 → 14:49:42 |

All command exits were zero. The initial attempt with the normal Gradle home
failed because its global init.gradle injects Maven repositories into Flutter's
included build. The established isolated Gradle home was restored; its cache
and wrapper are symlinks to the existing shared cache. No global file, cache,
SDK, product source or dependency version was changed or deleted.

All three APKs passed original formal certificate verification:
`73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d`.
Native codes remain 2006/1006/4006 for arm64/armv7/x86_64, minSdk24/target36.
AAB jarsigner exited zero and its public certificate matches; self-signed,
missing-timestamp and JarInputStream warnings are retained in the build log.

Linux contains all 48 release runtime files, license notices and BUILD-INFO,
with byte-equal runtime payloads, executable mode, safe archive paths, x64 ELF
and no missing `ldd` dependencies. Native runner caching is distinguished from
fresh Dart AOT compilation at 14:49:41 UTC. An obsolete debug kernel was moved
only out of the staging copy and retained separately, not deleted from caches.
Flutter's cached version reports 3.44.2, but actual framework git is 3.38.1;
neither was changed. This is not a Linux desktop interaction acceptance test.

All 17 frozen artifacts passed ZIP/size/hash/manifest checks. Privacy inspection
covered **2091 byte surfaces**, with no signing secrets, access tokens or real
private-key payloads found. Normal lib/main.dart entrypoint is used; the checked
ARM64 AOT payload contains no local IME probe markers. Public formal packages
are separate from the previously installed debug-compatible device package.

```text
15d09bc5ddfaba69e1e616f20355de7d716a88b39e15a75bc18c6da34cdaeb06  valhalla-v1.0.5-android-arm64-v8a-signed-6.apk
fb1bae43f02e648ff76bd106fe3d3476b059b7aefedbaf3b65d4c8251c47ee43  valhalla-v1.0.5-android-armeabi-v7a-signed-6.apk
691cb970c266d0791c7096f2fb6344285ccc5caf4ad26951afdc869be14736d5  valhalla-v1.0.5-android-x86_64-signed-6.apk
ad20299855485b79bd66737d53bc338d88917c0a5122ee5012614fd3c518de38  valhalla-v1.0.5-android-signed.aab
54374d29a8ac9f39d24921acecfc04495aa9aa21aed924766a1a55d12d807cc0  valhalla-v1.0.5-linux-x64.tar.gz
```

## Remote publication completed: 2026-10-13 14:58 UTC

Status: **complete**. Existing [GitHub v1.0.5](https://github.com/NornsInteractive/valhalla/releases/tag/v1.0.5)
now serves the 17 verified new assets. Release ID411682951, original tag/target
ce3ebe1, original published timestamp and public status are unchanged. Notes,
BUILD-INFO and update.json identify actual source b3d5c28. All 17 API digests and
sizes match staging; public update.json and SHA256SUMS are byte-identical.
One intermittent GitHub connection timeout interrupted status reads after the
binary upload; bounded read-only retries and digest-aware resume completed the
remaining files. No blind repeat of package-registration writes was performed.

[Ygg distribution](https://ygg.norns.cc.cd/d/com.norns.valhalla) retains original
version ver_mv6p1zi3nm7o / 1.0.5+6 / code2006 / default channel. With explicit
user approval, four external records were backed up and replaced, each newly
registered and verified before deleting only its original record:

| Target | Original record | Replacement record |
| --- | --- | --- |
| Android arm64-v8a | pkg_mv6p3hq6oydg | pkg_mv6sxk3h2yqz |
| Android armeabi-v7a | pkg_mv6p3jrfpqul | pkg_mv6sxqivyq3w |
| Android x86_64 | pkg_mv6p3lxj43yh | pkg_mv6t0r9850yt |
| Linux x86_64 | pkg_mv6p3obzzvx3 | pkg_mv6t0wsmmtdh |

All other versions and their metadata were preserved (naturally increasing
download counters excluded from equality checks). Only this version's changelog
was updated. The service MCP exposes no package-update tool; this controlled
registration is not an upsert and does not require new server code or credentials.
Old records/counters are recorded in snapshots; their original IDs/counts cannot
be restored by the supported add/delete API. No R2 objects were removed.

The production platform/architecture checks and **four actual full downloads**
all matched frozen sizes/SHA256, including package-ID-bound URLs. Final proof
exited zero with `PASS: 17 public assets, four actual downloads, unchanged old
tag/history, no Actions.` Source commit Actions run count is zero.

Old 17 binaries remain in `/tmp/valhalla-v105.stiS17/artifacts`; this operation's
new binaries, snapshots, add/delete receipts and logs remain under
`/tmp/valhalla-v105-refresh.xqbC8y`. Original published files can be reuploaded;
replaced GitHub asset IDs/counters cannot be restored.

No ADB operation, new physical-phone/Linux GUI test, other-platform build or
version increment was performed. Same-version and signing compatibility limits
above remain applicable. Later documentation-only commits do not change the
recorded binary source commit.
