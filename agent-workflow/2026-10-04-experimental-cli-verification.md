# Experimental CLI Chat — Task-Scoped Verification (2026-10-04)

## Session / Model / Ownership

- Verification context: fresh bounded OpenCode session, legacy history
  `ses_f0405efacffePPqWyhHc3GGJY7` preserved separately (MiMo rate-limited
  auto-compaction). OpenCode session id (this bounded context):
  `ses_efa045a6bffeBnDODUfPKr6YLw`; `CODEX_SESSION_ID` observed in the shell
  environment is NOT the OpenCode session id and must not be cited as such.
- Main/small model: `opencode/fledge-alpha-free`, explicit and identical for both;
  official + local cost verified 0 after root authorization. No paid models, no
  subagents, no remote/device/git/dependency operations used.
- UI ownership unchanged: only original AgY Valhalla session
  `ec81a4be-7543-45ee-8658-f68966f57d3b` / `gemini-3.8-flash-high` (high) may
  edit UI/ARB. Root owns non-UI. This pass edited test fixtures only.

## Fixture fixes executed (this pass)

1. `test/features/settings_navigation_test.dart` — first "renders all 10 sections"
   test now calls `storage.setExperimentalFeatures([ExperimentalFeature.cliChat.name])`
   before `pumpWidget` (explicit opt-in fixture; assertions/skips untouched).
2. `test/features/cli_chat_shell_navigation_test.dart` — `_pumpShell` helper gained
   `bool enableCli = false`; mock prefs seeded with
   `valhalla_experimental_features_v1: ['cliChat']` only when true; both existing
   positive CLI tests (compact drawer index 8, expanded rail CLI destination)
   explicitly pass `enableCli: true`.
3. Two `main_shell_dynamic_nav_test.dart` all-10 fixtures were already fixed to
   explicit `enabledExperimentalFeatures: {ExperimentalFeature.cliChat}` prior to
   this pass.

## Interim failures observed (before fixture fixes)

- `settings_navigation_test.dart` first test: `settings_startup_page_radio_cliChat`
  not found — expected, CLI hidden by default.
- `cli_chat_shell_navigation_test.dart` both tests: no `drawer_cli_chat_tile` / no
  rail `forum_outlined` destination — expected with CLI off by default.
- No lib/UI semantic defect found in this pass; nothing reported to root.

## Gates (actual results)

- Focused: `settings_navigation` + `cli_chat_shell_navigation` +
  `main_shell_dynamic_nav` + `experimental_features` → 32 passed, 0 failed.
- `dart format` (mechanical, changed tests only): 2 files reformatted.
- `flutter analyze` → No issues found (0).
- `flutter test` full → **+1900 ~18: All tests passed!** (0 failures; 18 known
  skips).

## APK (local default development signing; no release env / private keys)

- `flutter build apk --release` → exit 0, `Built build/app/outputs/flutter-apk/app-release.apk (123.9MB)`.
- New universal APK: 123,916,922 bytes, UTC mtime `2026-10-04T08:27:01Z`.
- SHA-256: `0e9a37d1d99664814ed4635eb904ef14d447c4e2260a010287ec02d0331dfc96`
- apksigner (build-tools 36.0.0): `VERIFY_OK`; Signer #1 DN `C=US, O=Android, CN=Android Debug`;
  cert SHA-256 `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`
  — stock Android Debug certificate, i.e. default development signing.
- Preserved previous universal APK without overwrite:
  `app-release.apk.bak-20261004-082557` (123,916,842 bytes, SHA-256 prefix
  `8a0bdd0de0897605`). All 4 older backups, `app-debug.apk`, `app-profile.apk`,
  split release APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`) and `.sha1` files
  retained. No ADB/install/device writes.

## Not done this pass (root decides follow-up) — HISTORICAL, SUPERSEDED

- New default-off widget extras NOT authored (superseded 2026-10-04: all three
  such proofs WERE authored in the last-gate update below — two CLI-harness
  default-off tests and one settings default-off dialog test): two small CLI-harness default-off
  tests (no offstage `CliChatView` / no drawer CLI tile; desktop rail 9
  destinations + NAS tap ⇒ `AnimatedIndexedStack.index == 9`) and one settings
  dialog default-off test (CLI checkbox on ⇒ persisted `cliChat` key ⇒ off).
- No screenshots/live device behavior claimed; APK not installed/verified on hardware.

## AOT provenance audit 2026-10-04 (read-only)

- Extracted `lib/*/libapp.so` via native `unzip` from the new APK and
  `app-release.apk.bak-20261004-082557` into fresh `/tmp/opencode/aot-check-*`.
- `strings` markers `valhalla_experimental_features_v1` + `Experimental Features`
  present in NEW `libapp.so` for all ABIs (arm64-v8a, armeabi-v7a, x86_64;
  2/2 unique marker hits each), absent (0) in ALL OLD ABIs → new APK genuinely
  carries the experimental-feature AOT, not a timestamp/signature-only diff.
- AOT SHA-256 per ABI changed in all three: arm64-v8a `ac419ad50562` vs old
  `c5c87e86bd54`; armeabi-v7a `46f4180c4c02` vs old `82dc35930829`;
  x86_64 `6b3e745f0ae7` vs old `d583a3e31b71` (sizes identical per ABI).
- APK-level size increased by only 80 bytes, but AOT hashes and new markers
  independently prove the compiled feature changed; size alone is not proof of
  freshness. `flutter analyze --no-pub` →
  `ANALYZE_EXIT=0`, No issues found (log: /tmp/opencode/analyze-nopub.log).
- No rebuild, no backup, no private keys/credentials, no ADB/remote/git/deps.

## Last-gate update 2026-10-04T08:40Z: UI proof tests added (3) — production source untouched

- OpenCode session id (this bounded context): `ses_efa045a6bffeBnDODUfPKr6YLw` — original legacy history
  `ses_f0405efacffePPqWyhHc3GGJY7` preserved, no history ops. Main+small model
  `opencode/fledge-alpha-free`, official+local cost verified 0 after root authorization.
- New default-off widget proofs authored in the two affected harness files (no new real
  remote calls, no fake assertions, no skips, every assertion preserved):
  1. `cli_chat_shell_navigation_test.dart`: compact drawer → no `drawer_cli_chat_tile`,
     `find.byType(CliChatView, skipOffstage: false)` empty, `cli_chat_disabled_placeholder`
     present (skipOffstage false).
  2. `cli_chat_shell_navigation_test.dart`: expanded rail → 9 destinations
     (`NavigationRail.destinations.length == 9`), NAS `perm_media_outlined` tap →
     `AnimatedIndexedStack.index == 9`; then explicit opt-in
     `setExperimentalFeature(cliChat, true)` → forum tap → index 8 →
     `setExperimentalFeature(cliChat, false)` → index 0 (dashboard fallback).
  3. `settings_navigation_test.dart`: EN viewport 640px/DPR 2.0 (320dp width at
     default text scale — NOT a 2x TextScaler claim); bounded manual drag loop
     scrolls `settings_experimental_features_tile` into view; dialog opens with
     `settings_experimental_cli_chat_tile` CheckboxListTile.value==false; tap → true and
     persisted `valhalla_experimental_features_v1` contains `cliChat`; tap again → false
     and persisted list empty; close button dismisses dialog.
- Interim hits fixed during authoring (test code only):
  `NavigationRailDestination` is a config class (not a widget) → counted via
  `NavigationRail.destinations`; lazy ListView children → bounded drag loop;
  invalid `Finder.tryEvaluate().isEmpty` query → `evaluate().isEmpty`; an unused
  `container` local removed, startup-section test's container capture restored.
- Gates (real exit codes, logfile/pipefail captured):
  - focused 3 files → 30 passed, 0 failed
  - `dart format` mechanical on the two test files
  - `flutter analyze` → No issues found (0)
  - full `flutter test` → `FULLTEST_EXIT=0`, `+1903 ~18: All tests passed!`
    (1900 prior + 3 new widget proofs; 18 known skips unchanged)
- APK byte identity re-verified, unchanged from previous gate:
  `app-release.apk` 123,916,922 bytes, UTC mtime `2026-10-04T08:27:01Z`,
  SHA-256 `0e9a37d1d99664814ed4635eb904ef14d447c4e2260a010287ec02d0331dfc96`.
  No APK rebuild, backup, ADB/install, signing/key, git, dependency or remote ops.
- No lib/ARB/generator edits this pass (production source unchanged); no real UI bug
  surfaced to report to root/AgY.
