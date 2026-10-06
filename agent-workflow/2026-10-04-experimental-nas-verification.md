# Experimental NAS — Phase-1 Verification (2026-10-04)

## Context

- Phase 1 ONLY: root implemented `ExperimentalFeature.nas` + shared `isSectionEnabled`
  gating in `lib/core/providers/settings_provider.dart`; AgY owns UI/ARB (currently
  editing). OpenCode owns all tests. No lib/ARB/generator edits, no format of UI, no
  gen/analyze/full/build until root confirms UI complete.
- Session `ses_efa045a6bffeBnDODUfPKr6YLw`; main+small model
  `opencode/fledge-alpha-free` (confirmed-free fallback); legacy history
  `ses_f0405efacffePPqWyhHc3GGJY7` preserved. No paid model/subagent/git/ADB/remote/key/deps.

## Test changes (test/core/experimental_features_test.dart only)

- Both default off: existing default-off test now also asserts
  `isSectionEnabled(AppSection.nas)==false` + `availableSections` excludes nas.
- New `只开启 CLI 不会顺带开启 NAS` (CLI-only opt-in keeps NAS off).
- Storage parse group: `experimentalFeaturesFromStorage(['telemetry','nas'])` ==
  `{ExperimentalFeature.nas}` added (CLI parse assertions preserved).
- New `NAS 独立开启落盘并跨重启读回，reset 后关闭` (independent NAS persist/restart/reset;
  NAS enable does not pull CLI on; reset persists empty).
- New `写入抛错时 NAS 保持关闭，存储没有被写成开启` (NAS failure: throws, state stays off,
  storage untouched) — mirrors CLI failure coverage.
- New `NAS 启动页在关闭时回退仪表盘，开启后恢复为 NAS` (startup fallback + raw slot
  restoration; visible bottom restores NAS only after opt-in).
- New `CLI 与 NAS 都隐藏时可见列表过滤两者，原始槽位各自保留并分别恢复` — visible
  bottom/quick filter BOTH hidden entries; raw slots preserved; NAS alone restores;
  CLI alone restores; NAS disable leaves CLI slot and raw NAS slot intact.
- Fixture update preserving every existing assertion: `configured()` in the nav group
  now seeds `_experimentalKey: ['nas']` so NAS-dependent expectations stay explicit
  opt-in. Raw `bottomNavigationSections`/`dashboardQuickSections` and
  `settings_persistence_test.dart` / `acp_navigation_and_preferences_test.dart`
  remain valid (raw getters, no experimental gate assumptions); `nas_navigation_test.dart`
  exercises the stable index/icon/name mapping only.

## Results (actual, this session)

- `dart format test/core/experimental_features_test.dart
  lib/core/providers/settings_provider.dart` → 2 files reformatted (mechanical).
- `flutter test test/core/experimental_features_test.dart` → **+24: All tests passed!**
  (19 legacy + 5 new; 0 failures; no weakened/deleted/skipped assertions).
- No product defect surfaced in focused scope → nothing to report to root.
- Focused core experimental tests only, per phase-1 guard rails; analyze/full/build
  deferred to post-UI gates.

> Phase-1 report correction: this section earlier claimed
> `nas_navigation_test.dart` covered "stable index/icon/name mapping only".
> That was incomplete: its drawer positive test
> (`navigating to NAS from drawer ... index 9`) also needed an explicit NAS
> opt-in fixture, which is what was added — see Phase-2 section below.

## Phase-2 verification (2026-10-04, post-AgY UI)

- UI ownership respected: AgY edits only
  (`lib/features/settings/settings_view.dart`, `lib/features/shell/main_shell.dart`,
  ARB + status doc); OpenCode edited four navigation harness fixtures + exactly one
  legacy NAS fixture + two dialog fixtures; no lib/ARB/generator semantic edits.
- Fixture fixes (test code only; assertions preserved):
  - `main_shell_dynamic_nav_test.dart`: both all-10 fixtures now seed
    `{cliChat, nas}` in `enabledExperimentalFeatures`.
  - `cli_chat_shell_navigation_test.dart`: default-off compact drawer test now also
    asserts no `drawer_nas_tile`, no offstage `NasMediaView`, `nas_disabled_placeholder`
    present (skipOffstage:false), and ALL four NAS providers
    (`nasProvider`/`nasPlaybackProvider`/`nasMediaPlayerProvider`/`nasIndexRepositoryProvider`)
    `container.exists(...)==false`; expanded default-off test asserts 8 rail
    destinations, no NAS/CLI rail icons, then NAS opt-in (CLI off) → 9 destinations →
    NAS tap → `AnimatedIndexedStack.index == 9` → NAS disable → index 0 (dashboard
    fallback preserved); existing CLI positive cases kept, CLI disable-current → index 0.
  - `settings_navigation_test.dart`: top "all 10" test seeds BOTH enum names via
    `storage.setExperimentalFeatures(['cliChat','nas'])`; new dialog test asserts both
    checkboxes initial false, NAS on → persists `['nas']` with CLI off, CLI on → both
    persisted, NAS off → CLI-only persisted and CLI checkbox stays true.
  - `nas_navigation_test.dart`: drawer positive test seeds `valhalla_experimental_features_v1=['nas']`
    before pumping (explicit NAS opt-in).
  - `nas_media_view_test.dart` (one out-of-list legacy fixture): the "NAS source
    selector on top bar" test seeds `defaultStorage.setExperimentalFeatures(['nas'])`
    before pumping; preserves all assertions.
- Initial focused run failed two settings tests because the lazily built tile
  existed outside the hit-test viewport. Bounded drag loops gained `ensureVisible`
  before tap; assertions retained, subsequent focused run passed.
- `flutter gen-l10n` executed (NAS ARB keys from AgY); new getters available to tests.
- Focused run: `nas_navigation` + `cli_chat_shell_navigation` + `settings_navigation`
  + `main_shell_dynamic_nav` + `experimental_features` → **+43, All tests passed!**
- `nas_media_view_test` focused → All tests passed, exit 0.
- `flutter analyze` → No issues found (exit 0).
- Full suite → `FULL_EXIT=0`, **+1909 ~18: All tests passed!** (1903 prior + 5 phase-1
  core tests + 1 phase-2 dialog test; 18 known skips).
- Artifact: fresh universal release build. Prior APK preserved verbatim as
  `app-release.apk.bak-20261004-095809` (SHA `0e9a37d1d99664814ed4635eb904ef14d447c4e2260a010287ec02d0331dfc96`,
  123,916,922 bytes, UTC `2026-10-04T08:27:01Z`).
  - `BUILD_EXIT=0`, `Built build/app/outputs/flutter-apk/app-release.apk (123.9MB)`.
  - New APK: 123,916,922 bytes, UTC mtime `2026-10-04T09:59:30Z`,
    SHA-256 `b85ff8ae7e3c6aaf31c5285c84de78750771c71a622db19ad93c8334aa5ef438`.
  - `apksigner verify` → SIG_OK; Signer #1 SHA-256
    `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` (stock Android Debug,
    development signing only; no release key/env; splits/debug/profile/older backups untouched).
- No ADB/remote/git-history ops, no keys/credentials, no dependency changes.
- AgY CLI exited 0 but wrapper reported historical API EOF — noted; relied on actual
  code inspection (`nas nav` keys/`SettingsState` listener check) + full test gates.
