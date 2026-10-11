# Yggdrasil update-source migration

Historical first-stage contract: platform/channel and single-package assumptions
below are superseded by [multi-platform follow-up](2026-10-11-ygg-multiplatform.md).
Its failed/incomplete validation remains historical, not a current passing gate.

User requests all app update checks and downloads use the existing distribution
platform, not direct GitHub discovery. No version bump, build, install, push or
Release publication is included. GitHub remains the open-source repository and
may be the platform's redirect upstream, not a client-selected update source.

## Contract and ownership

- Main owns `lib/core/services/app_update_service.dart`,
  `lib/core/providers/app_update_provider.dart`, `lib/data/models/app_update.dart`,
  `lib/data/storage/local_storage_service.dart` (update-cache/record keys only)
  and this contract/status/architecture/requirements documentation. No UI or tests authored
  by main. No changes to the distribution server, credentials, package or key.
- Public check: `GET https://ygg.norns.cc.cd/api/v1/app/latest`, query `app_id`
  `com.norns.valhalla`, installed integer `version_code`, channel. Distribution
  app ID is an existing catalog identifier, not the native package ID.
- Public download: version-bound `/api/v1/app/download` on the same exact HTTPS
  host with the same app ID, version code and response channel. No secret query,
  unknown/duplicate query fields, HTTP, user-info, nonstandard port or fragments.
- Android ARM64 uses existing `default`; other ABI/platform channels are
  `android-armeabi-v7a`, `android-x86_64`, `windows-x64`, `windows-arm64`,
  `linux-x64`, `linux-arm64`, `macos-x64`, `macos-arm64`. The platform currently
  falls back to default if a channel is missing: enforce filename/ABI matching,
  never install its ARM64 APK on a desktop or incompatible Android ABI.
- Response is `{code:0,data:{...}}`; validate actual catalog ID, semantic version,
  channel, positive integer version/size, filename and bound download URL.
  Android split APK versionCode is ABI prefix times 1000 plus base build, aligned
  with the existing native runtimeInfo. Keep fixed public release certificate
  `73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d` and
  native actual package/version/certificate validation.
- Prefer structured `file_sha256`. Legacy external-URL records have it null:
  accept only an unambiguous explicit `SHA256: <64 hex>` in platform changelog;
  reject malformed or conflicting hashes. No MD5-only or unchecked managed
  downloads. This is a compatibility bridge, not hardcoded per-release hashes.
- Preserve existing 24-hour opt-out check policy, ETag, offline/failed refresh
  state, bounded notes, streaming/resume/cancel, no-overwrite and post-download
  integrity checks. Cache identity must include new source/channel/installed
  code. Ignore old GitHub cache for current actions, leave persisted data/files
  intact for rollback; first new-source check must not wait behind old checkedAt.
- Update release-page/fallback links go to distribution platform, not GitHub.
  Store-managed installs retain official store routes; no untrusted iOS install.
  Catalog currently has only ARM64. Missing compatible packages remain explicit.

## AgY UI handoff — original session only

Only original Valhalla `ec81a4be-7543-45ee-8658-f68966f57d3b`, model
`gemini-3.8-flash-high`, effort `high`, may edit display. Whitelist:
`lib/l10n/app_*.arb`; `lib/features/settings/widgets/app_update_dialog.dart`
only if error mapping needs narrowly related correction. Keep keys and placeholders,
all 17 locales. Change updateOpenReleasePage, updateErrorRateLimited and
updateErrorGeneric wording from GitHub-specific to distribution/update-service
wording. Keep aboutRepository and actual open-source repository tile unchanged.
No layouts, unrelated UI, business/test files, credentials, generation, formatting,
analysis, build, ADB, git operations or release operations. Report actual files.

## OpenCode validation handoff

Main/small model explicit `opencode/mimo-v2.6-flash-free`; only previously
authorized confirmed-free fallback if unavailable. Tests owned by OpenCode:
`test/core/app_update_service_test.dart`, `test/core/app_update_http_test.dart`,
`test/core/app_update_provider_test.dart` and nearest affected updater/localization
widget tests when necessary. Adapt obsolete GitHub discovery fixtures, retain
download/resume/cancel/tamper/no-overwrite and notifier race regression coverage.
Add actual envelope, catalog-ID/version/channel, metadata/hash conflict, URL
binding/redirect validation, ABI-code matching, platform-channel fallback safety,
old-cache migration/immediate-check and new source/check context fixtures.
  Cache/record now use `valhalla_update_check_ygg_v1` and
  `valhalla_update_download_ygg_v1`; the original `_v1` keys remain untouched and
  automatic-check preference stays shared. Prove actual old keys survive both a
  successful check and new download-record save, not just ignored in memory.
Prove missing/incompatible platform metadata cannot trigger wrong downloads.
Run l10n generation if AgY edits ARB, format changed owned files, nearest tests,
then whole-project analyze. No build, ADB, server modification, push or paid model.
Read-only public endpoint/HEAD/range diagnostics allowed; no sending prompts to
live agents. Record commands, own exits and full summaries; failures not erased.

## Rollout and rollback

Only source migration here; existing installed APKs and published artifacts keep
their existing behavior until a later explicitly authorized build/install/release.
Rolling back service/provider/model/l10n changes can reuse retained old cache and
partials; do not mutate user data or disable package/signature checks to roll back.
No platform administration Bearer token may be embedded in client or documentation.

Status: business source and AgY UI handoff implemented; OpenCode verification
pending. AgY used the original session/model/high and changed only the 17 ARB
files and the authorization-error mapping. Its final CLI envelope retained an
earlier quota error; completion is established by the actual narrow file diff,
not that envelope's status. MiMo validation timed out without results; the
previously authorized, confirmed-zero-cost `opencode/step-5-preview-free` is
was tried with both main and small models explicitly configured. Its baseline
run exited 1 (34 passed / 36 failures, including obsolete test signatures and
GitHub URLs); the following reconnaissance-only runs were intentionally
interrupted (130), not accepted as passing tests. Confirmed-free Big Pickle also
returned no output for three minutes and was interrupted without writes. A
single-file Step 5 parser-test handoff also made no writes after its initial
reads and was interrupted (130) after six minutes. No current CLI job remains
running. Main asked for a one-turn test-ownership exception, but has not presumed
approval or authored tests. Verification is blocked pending that user choice or
a usable OpenCode run; the old tests still need fixture/signature migration.
This source change is not release-ready and must not be reported as fully tested.
Logs remain under `/tmp/valhalla-ygg-opencode*.log` and
`/tmp/valhalla-ygg-opencode-logs/`. Live public check confirms
1.0.4 / 2005 / ARM64 / 45,291,528 bytes; structured hash is null but changelog has
the published APK hash. This does not establish new app/device acceptance.
