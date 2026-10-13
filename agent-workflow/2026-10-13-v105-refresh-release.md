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

Status: preflight complete; publication pending. Evidence and final hashes will
be appended only after successful builds and remote verification.
