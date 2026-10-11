# Ygg multi-platform distribution

## Authorized release follow-up

User subsequently requested application ABI detection and explicitly asked the
main agent to build/upload. This one-operation exception includes prerequisite
test maintenance, generation, formatting and validation after OpenCode quota
failure; future OpenCode/UI ownership stays unchanged. Keep 1.0.4+5, fixed
certificate, original tag and Android/Linux local release scope. No Actions/ADB.
Both check and download explicitly carry platform/arch. Android now uses the
running application's Dart ABI, not Build.SUPPORTED_ABIS; APK ARM32 remains
ARM32 even on an ARM64 device. Desktop keeps process ABI; universal fallback is
macOS only. Preserve package_id/version/hash binding and old cache/user data.
The current MCP exposes add/delete, not package metadata updates. Before any
same-version package replacement, back up exact existing external-only records
and GitHub assets; do not delete versions, R2 objects or signing material.

Current prerequisite result: 140 focused updater/localization/privacy/storage
tests passed, whole suite 2484 passed / 18 explicit environment skips / 0 failed,
manifest generator 27 passed and whole-project analysis has no issues. Fresh
build/publication are in progress; earlier blocked results below are historical.

Scope: finish the previous unverified update-source migration against the newly
deployed public API. Reuse catalog `com.norns.valhalla`, existing published
version `ver_mv3qr13agvpd`, and verified GitHub v1.0.4 assets. No new app version,
build, ADB, Git push, GitHub Release mutation or distribution-server code changes.
Preserve old versions, signing and user data. Register download URLs, not duplicate
binary uploads, as the user previously requested GitHub upstream delivery.

## Implementation contract

- Check `/api/v1/app/latest` with app_id, installed version_code, channel=default,
  explicit platform and arch. x64 -> x86_64; desktop arm64 -> arm64-v8a,
  macOS arm64 -> apple-silicon. Use runtime ABI, not Platform.version guessing.
- Parse packages[] with each package's structured SHA256, size, filename and
  package_id-bound HTTPS URL. Reject ambiguous identity, duplicate IDs or
  platform/architecture mismatch. Never use one parent changelog hash for all
  packages. Legacy no-package/synthetic entries retain strict prior hash fallback.
- Shared catalog version_code=2005 is not every APK's native code. Set the
  existing catalog display version to 1.0.4+5 (same app semantic version/build).
  Parse build 5, display/install version 1.0.4; derive APK native codes
  armeabi-v7a=1005 / arm64-v8a=2005 / x86_64=4005. Desktop build is 5 too.
- Do not rely on server has_update ordering across split ABI codes; compare
  actual semantic version/base build as before. Preserve native cert verification.
- Cache source/context includes platform/arch; independent ygg_v2 preferences
  retain legacy GitHub and first Ygg caches/records for rollback. Keep auto pref.
- Only actual APKs and Linux tar from current Release are distributable. No
  Windows/macOS/iOS package exists in v1.0.4; do not attach old-version binaries
  or AAB as an installable APK. Missing compatible package remains explicit.
- Publication read-before-write: reuse exact version; skip byte-identical
  existing packages, stop on conflicting identity. Do not delete/recreate.

## Ownership / gates

Main owns updater service/provider/model/storage keys and rules/PRD/architecture/
status/docs; no UI or tests. Reuse AgY's already completed 17 locale changes and
auth-error mapping from the previous handoff; no further UI layout is needed.
OpenCode owns the three test/core/app_update_*_test.dart and directly affected
updater widget/localization tests. Attempt explicit MiMo free main/small first;
previously user-authorized confirmed-free fallback only. No secrets/paid models.

Tests must migrate old GitHub fixtures/signatures, retain download/resume/cancel/
tamper/no-overwrite and provider lifecycle races, add multi-package URL binding,
SHA independence, alias mapping, shared-code native identity, same-version build
comparison, wrong-ABI fallback and v2 cache/ETag context. Deterministically await
fake check entry now that PackageInfo/runtime awaits precede service calls.
OpenCode runs l10n generation, narrow formatting, focused updater/localization/
privacy tests, whole-project analyze and diff-check. Do not format the whole
large storage file. Report production defects, never patch production to mask
failures. Keep logs/actual exits; no old test gate reused as current proof.

Status: business implementation and package registration complete; OpenCode
validation pending. Previous migration is not yet gated. MiMo2.6 console exited
124 without output/writes; confirmed-free MiMo2.5 console exited 1 with upstream
`UnknownError` (`err_3ecbf798`), also without writes. Confirmed-free Step5 with
explicit main/small models returned 429 `FreeUsageLimitError` with retry-after
37670 seconds; no further retry or quota-bypass is attempted. No test changes,
generation, formatting or analysis were executed by those three invocations.
Verification is blocked by the delegated provider. Main requested a one-turn
test-ownership exception, without assuming approval; original GitHub test
fixtures and fake signatures still require migration. Source is not release-ready.
Each failed invocation is retained under `/tmp/valhalla-ygg-multi-*.log`.

## Registered 2026-10-11 13:25 UTC

MCP registration exited 0; reused version `ver_mv3qr13agvpd`/code2005/default,
display name now `1.0.4+5`. Three APKs and Linux tar retain their existing GitHub
binary URLs, byte sizes and actual GitHub digest fields. No R2 duplication,
new version, old-version deletion, Actions or GitHub Release edit. Parent notes
no longer advertise one ARM64 checksum for every package.

| Platform / arch | Package ID | Actual APK code |
| --- | --- | --- |
| android / arm64-v8a | pkg_mv3uvxoeqk7o | 2005 |
| android / armeabi-v7a | pkg_mv3uvzdwzlob | 1005 |
| android / x86_64 | pkg_mv3uw0jc4kes | 4005 |
| linux / x86_64 | pkg_mv3uw1tg9syu | not an APK |

All use `https://ygg.norns.cc.cd/api/v1/app/download?app_id=com.norns.valhalla&version_code=2005&channel=default&package_id=<ID>`.
Public checks with explicit platform/arch return each correct file/hash and all
four packages; following download HEAD returns 200 and each expected byte size.
Windows request currently falls back to Android x86_64 on the server: the client
must select only Windows artifacts from packages, never that top-level fallback.
No current Windows/macOS/iOS archive exists; no incorrect replacement registered.
Registration proves distribution metadata/link availability, not new app tests.
