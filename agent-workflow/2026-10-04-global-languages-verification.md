# Global languages — OpenCode verification (2026-10-04)

## Latest acceptance summary (supersedes interim checkpoints below)

- All 17 catalogs generated and validated; 1107 message keys per catalog.
- Complete suite: 1938 passed / 18 pre-existing skips, exit 0. After mechanical
  EOF cleanup, settings-focused tests and analyzer passed again, exit 0.
- Analyzer: zero issues. Read-only `git diff --check`: exit 0.
- Final universal APK: `build/app/outputs/flutter-apk/app-release.apk`,
  128,684,666 bytes, UTC mtime `2026-10-04T14:59:50Z`, SHA-256
  `4f42ac9e3c4ea38365d0b844d8528ebbceffccc0479fd112fbd317fa13c3432d`.
- Development/debug certificate, verified signature; no release-key mutation,
  ADB installation, Git push, or real remote-agent interaction in this feature.
- Earlier quota, missing-catalog, rendering and lint findings below are historical
  checkpoints and resolved; translation fluency still merits native review.

## Scope / ownership

- Initial phase-1 ownership, later extended to full validation/build. Root implemented
  `lib/core/localization/app_locales.dart` + SettingsNotifier persistence-before-success
  (`setLocale`: storage first, throw on false-write). AgY owns
  `lib/features/**`, ARB catalogs, `lib/main.dart` locale wiring; OpenCode owns
  test authorship/execution, and now formatted two core files + tests mechanically.
- Models: main+small `opencode/fledge-alpha-free` (confirmed-free fallback,
  official/local cost 0), session `ses_efa045a6bffeBnDODUfPKr6YLw`, legacy
  `ses_f0405efacffePPqWyhHc3GGJY7` preserved. No paid/subagents/ADB/git/deps/remote/keys.

## Tests added (pure + provider)

- New `test/core/app_locales_test.dart` (pure):
  - `appLanguageLocales` exactly 17 choices and none is the system pseudo-locale.
  - `appLocaleFromStorage`: null/system/SYSTEM → system; legacy `en`/`zh` readable;
    `zh-TW/zh_HK/zh-MO/zh-hant-TW` → Traditional (`scriptCode == 'Hant'`);
    `zh-CN/zh-SG/zh/zh-Hans` stay Simplified (not Hant); BCP47 `_` and mixed case
    normalized (`zh_Hant_TW`, `ZH-hant`, `zh-Hant-HK` → Hant; `pt_BR` → pt;
    `DE_de` → de); unknown/malformed tags (`xx`, `klingon`, `!!!`, `zh!!`,
    `zh--Hant`) → system without throwing.
  - `appLocaleToStorage`: canonical tags (`en`, `zh`, `system`, `zh-Hant`, `pt` via
    `pt_BR`, `de` via `de_DE`); unsupported explicit `Locale('xx')` →
    `ArgumentError`.
  - `resolveAppLocale`: unsupported-first still lands on the next supported choice
    (`[xx, es]→es`); `[ru, en]→ru`; null/empty/unsupported preference list → English
    fallback (not generator alphabetical first); supported without English →
    `supported.first`; `Locale('zh','TW')` → `zh-Hant` script.
- `test/core/settings_persistence_test.dart`:
  - New `应用语言选择 17 项逐个保存、重启后保持 canonical tag 完备且相等`: for each of the
    17 choices, `setLocale` persists the exact canonical tag to
    `valhalla_locale_v1`, state locale equals `appLocaleFromStorage(tag)`, and a new
    ProviderContainer over the same SharedPreferences reads back the same locale tag.
  - New `setLocale(system) 选择跟随系统并持久化 system`.
  - New `setLocale 写入失败`: `_FailingLocaleStorage.setLocale` throws StateError;
    notifier throws, `settings.locale` stays `Locale('en')`, disk stays `'en'`.
  - Existing compatibility assertions (resetDefaults → locale `system`, `_localeKey`
    write of legacy codes, unfamiliar-name fallbacks) preserved unchanged.

## Gates (real exit codes)

- `dart format`: 3 files reformatted (`settings_provider.dart` already clean), mechanical only.
- `flutter test test/core/app_locales_test.dart test/core/settings_persistence_test.dart`
  → **+33: All tests passed!**, `EXIT=0` (log: /tmp/opencode/locale-core.log).
- Focused core tests only per phase-1 guard: no gen/analyze/full/UI formatting/build.
- No UI semantic defects surfaced; anything consumer-visible deferred to root/AgY.

## Phase-2 test-prep follow-up corrections + blocker status (2026-10-04)

- AgY reported `RESOURCE_EXHAUSTED` (HTTP 429, ~3h quota reset): only en, zh,
  zh-Hant, ja catalogs landed (each JSON-validated with 1107 keys). 13 catalogs
  still missing *(historical — all 17 present before Phase-2 validation began;
  `pt/ru` were among the later additions during AgY's account-switch
  recovery)*. No gen-l10n/tests/analyze/build/ADB/deps/git/lib/ARB/UI edits
  executed on that day.
- `l10n_key_parity_test.dart` fixes apply (mechanical format only, not executed):
  - Template metadata rule: locale `{tokens}` from message text must equal EN
    message tokens; explicit `@metadata` placeholder NAMES in each locale must
    equal EN metadata names when present; every token need NOT have explicit
    metadata.
  - All file reads cached via `_allCatalogs()` once per test; no per-key file
    re-reads inside loops.
  - Multi-word only clone rule: exact-equal single-word values such as brand
    tokens (Valhalla/Codex/ACP/CLI/SSH/SFTP/Mosh/tmux/NAS/macOS/Linux),
    technical markers and natural short words like "Terminal" are accepted;
    only whole multi-word sentences trigger identity clone failure. A
    representative translated-human-facing sample must remain translated, and
    `EN:`/`[EN]`/`EN ]` pseudo-prefixes are still rejected. Parity header
    comment corrected to "our quality policy, preventing implicit fallback"
    instead of claiming gen-l10n failure semantics.
- `settings_language_test.dart` fixes apply (mechanical format only, not
  executed): `_pumpSettings` now does `settings = ref.watch(settingsProvider)`
  and drives `MaterialApp.locale` from it (null for `system`), so selecting
  ja/ar actually re-localizes the harness and the RTL assertion can pass.
  2x text scale is now injected via `MaterialApp.builder` wrapping the whole
  child with inherited `MediaQuery(textScaler: TextScaler.linear(2))` — this
  covers DialogRoute overlays, which a home-only MediaQuery misses. 320dp width
  still comes from 640px/DPR 2.0.
  - SingleChildScrollView eagerly materializes tiles, so any offstage tile
    evaluates non-empty; every tag click path now asserts hittable placement
    first (`tester.ensureVisible(alignment: 0.5)` + bounded retries, Bounded
    final `Exception` on Thai check: the Thai tile's final rect must be within
    the physical 320dp-equivalent viewport (0..568dp) and `takeException()`
    must be null. ja/ar/zh-Hant/zh selections use the same ensureVisible-then-
    tap path.
  - Persistence restart check no longer merely re-opens the dialog on the same
    provider container state claims: after ja persistence, the reopened dialog
    reads storage again and asserts it is the ja radio groupValue; a separate
    fresh language test would be required for full process restart, which is
    intentionally deferred. No invalid/!/bogus provider overrides were added —
    only value storage overrides and the production `localeListResolutionCallback`.
- AgY account switch reported after resource exhaustion on previous account:
  catalog writing has resumed (`de` + `fr` in progress at last check). No
  test execution, gen-l10n, analyze, build, ADB, deps, git writes, or UI
  semantical edits since; generated Dart still not regenerated and the current
  installed NAS APK (SHA `b85ff8ae...`) was not touched. 33 core locale/
  persistence tests reported green in the prior focused run; full
  localization/UI test UI validation remains untested.
  - Template metadata rule relaxed comment: Flutter itself evaluates {tokens} from
    message text; we now assert locale message tokens == EN message tokens, and
    explicit @-metadata names (when present in a locale) == EN template names. We
    no longer demand every token to be explicitly declared in @metadata.
  - Each test caches `_allCatalogs()` once; no per-key-loop file re-reads.
  - English-clone check no longer flags brand/technical/unit tokens: a documented
    identity allowlist (`Valhalla`/`Codex`/`ACP`/`CLI`/`SSH`/`SFTP`/`Mosh`/`tmux`/
    `NAS`/`macOS`/`Linux`/`Valhalla` tokens + `lang*` autonyms) exempts those
    legitimately identical strings; everything missing is an equality violation.
    Pseudo-translation prefixes (`EN:`, `[EN]`, `EN ]`) rejected outright. A
    representative human-facing multi-word sample must differ from EN in every
    translated catalog, so branding alone cannot satisfy full-UI coverage. No
    branded strings were edited to appease the rule.
  - Header comment corrected: equal keys across catalogs is OUR quality policy
    (prevents implicit fallback), not a hard `flutter gen-l10n` requirement.
- `settings_language_test.dart` fixes: 320dp width now comes from
  `640px/devicePixelRatio:2.0` AND an injected `MediaQueryData(textScaler:
  TextScaler.linear(2.0))` on the SettingsView subtree (DPR alone is not font
  scale; MaterialApp reset a view-level MediaQuery). Dialog reopen after
  select/persist proves the stored tag reaches groupValue again (restart-style).
  Provider overrides limited to `localStorageServiceProvider` value overrides
  and `localeListResolutionCallback: resolveAppLocale` wiring only — no invalid
  notifier overrides.
- Gate state: pure core tests still +33 (19 legacy locale/persistence + 14 prep
  additions from this pass, documented in the previous section). Full-suite
  counts, analyses, builds, catalog uploads/network translations, and APK
  packaging remain BLOCKED on AgY 429 recovery. Current APK (NAS experimental,
  SHA `b85ff8ae7e3c6aaf31c5285c84de78750771c71a622db19ad93c8334aa5ef438`)
  left installed; no new build or install happened.

- `test/core/l10n_key_parity_test.dart` expanded (syntax-valid; formatting applied):
  - Enumerates all 17 expected tags → `lib/l10n/app_<tag>.arb` files exist with the
    expected `@@locale`.
  - Every non-en file declares exactly the same message keys as `app_en.arb`
    (symmetric-difference empty, no missing/extra).
  - Per-message `@key` metadata yields the same placeholder names AND every
    `{token}` in message bodies matches template tokens for every locale.
  - All message values in every catalog are non-empty trim strings.
  - No non-en catalog clones English with identical text for non-`lang*` keys
    (English clones/prefixes hard-rejected with offenders listed; `lang*`
    autonyms explicitly exempted as documented native identities).
  - Representative keys `settingsAppearance`, `settingsLanguage`,
    `settingsLanguageSaveFailed`, `navSettings`, `navTerminal`, `cmdDangerous`,
    `cmdDangerousWarning`, `toolStatusRunning` asserted non-empty in every catalog.
  - Legacy en/zh equality assertion preserved for continuity.
- New `test/features/settings_language_test.dart` (prepared, not run; format applied):
  - `AppLocalizations.supportedLocales` tag-set equality with `appLanguageLocales`.
  - Real provider-driven `Consumer`+`MaterialApp`(`localeListResolutionCallback:
    resolveAppLocale`, 17-locale delegates) harness — settings language selection
    drives UI locale.
  - Language dialog reachability at 320dp/DPR 2.0 (640px physical) with bounded
    in-dialog scrolling until `settings_lang_th` (Thai) materializes; preserves
    legacy `settings_lang_system`+full 18-entry flow.
  - Selecting `ja` persists `valhalla_locale_v1='ja'`, closes the dialog only after
    success, and reopening shows the ja radio groupValue selected; `system`
    selection persists `'system'`.
  - Selecting `ar` yields `Directionality=rtl` on the Settings subtree; `zh-Hant`
    yields `scriptCode=='Hant'` and persisted tag `zh-Hant`; simplified `zh`
    persists `'zh'` with null script.
  - With a `_ThrowingLocaleStorage`, selecting `ja` keeps the dialog open,
    retains the previous selection state, leaves stored value untouched, and the
    localized save-failure text is visible.
  - Mocked SSH/agent/native surfaces only; no real network, device, or remote agents.
- Both files were formatted mechanically. NO generation, analysis, build, full-suite
  execution, ADB, git writes, or dependency changes performed at this stage. Ready
  for the post-UI readiness signal before running them.

## Bounded read-only interim validation (UI protective mode, 2026-10-04)

- Catalogs inspected (finished + JSON checked by Independent review): en, zh,
  zh_Hant, ja, de, fr, ko, es. pt/ru untouched (still being written) *(historical — pt/ru arrived later; today all 17 exist)*.
- Commands actually run (resource-only gates, all exit checks honest):
  - `python3` JSON parse loop over `app_<tag>.arb` → all 8 files parsed successfully;
    each reported `@@locale` equal to file basename; 1107 message keys in each.
  - Key-parity loop → 0 missing and 0 extra keys vs `app_en.arb` in all 8 catalogs.
  - First "dup" heuristic in the script produced false positives due to nested
    `placeholders`/`type` metadata names; replaced by `object_pairs_hook` top-level
    duplicate check → **no true duplicate JSON keys anywhere**.
  - Token parity per key (`{name}` sets in message text vs EN) → 0 mismatches.
  - Placeholder metadata names/types parity vs EN → 0 mismatches.
  - Empty strings / non-string values → none.
  - `OVERALL ISSUES` from the first script was caused solely by the false-positive
    dup detection above; all other checks passed.
- Representative spot reads (values only, no full dump): de/fr/ko/es/zh_Hant/ja
  `cmdDangerousWarning` render full sentences in the expected scripts; `appName`
  stays `Valhalla` in every catalog (intended brand identity); `selectLanguageTitle`
  renders `Sprache auswählen`/`Sélectionner la langue`/`언어 선택`/`Seleccionar idioma`/
  `言語を選択` — all non-empty and non-English-clone.
- Known traditional-script concern requiring AgY proofread:
  `zh_Hant.cmdDangerousWarning` ends with the Simplified question
  particle `吗？` after an otherwise Traditional sentence; expected a fully
  Traditional phrasing (e.g. `嗎？`). *Resolved per root review — no
  known character defect remains; flag kept as historical context.*
- Matchiness summary for root: all 8 completed catalogs pass key parity, placeholder
  parity, non-empty, @@locale, JSON validity, no dup keys. Only open linguistics item
  above for AgY review. No gen-l10n/tests/analyze/build/format/UI/ARB/git/ADB/deps
  were executed. Existing NAS APK (SHA `b85ff8ae...`) untouched. Full gates remain
  blocked for pt/ru + UI.

## Phase-2 execution interim (2026-10-04) — read-only validation + gen-l10n + focused tests

### 1. All-17 read-only resource validation

Command loop validated every catalog (`lib/l10n/app_en|zh|zh_Hant|ja|ko|de|fr|es|pt|ru|ar|hi|id|it|tr|vi|th.arb):
- JSON parses cleanly where attempted; top-level duplicate keys: none.
- `@@locale` equals expected tag: all 17 OK.
- Message keys: exactly 1107 in each catalog; zero missing / zero extra vs `app_en.arb`.
- Non-empty: every message value is a non-empty string across all 17.
- Placeholder tokens: for every key, `{token}` set in each locale equals EN template tokens.
- Metadata: per-message `@key.placeholders` name sets match EN template; types match.
- Result: static validation passed for all 17 independent of AgY's traditional marksmen review. Machine checks do NOT certify fluency / tone. Known concern at hand still flagged for AgY from earlier pass: `zh_Hant.cmdDangerousWarning` ends with trailing `吗？`.

### 2. gen-l10n
- `flutter gen-l10n` → GEN_EXIT=0; log: "Because l10n.yaml exists, the options defined there will be used instead." 17 locale files produced (`app_localizations_ar.dart` ... `app_localizations_zh.dart`). `dart format lib/l10n/` → 17 files, 0 changed. Generated source formatting matches mechanical state.
- `lib/l10n/app_localizations.dart` inspected: `supportedLocales` lists 17 (15 two-letter + `Locale('zh')` + `Locale.fromSubtags(languageCode:'zh', scriptCode:'Hant')`); delegates instantiated for every locale; generated per-locale classes exist for all 17 supported tag files.

### 3. Focused test run (real exit codes)

- First attempt (`test/core/app_locales_test.dart test/core/settings_persistence_test.dart test/core/l10n_key_parity_test.dart test/features/settings_language_test.dart test/features/settings_navigation_test.dart`) → EXIT=1:
  - **Harness bug fixed** (`test/features/settings_language_test.dart`): `platformDispatcher.localesTestValue = null` invalid for SDK type List<Locale>; switched to the SDK-provided `clearLocalesTestValue()` teardown. Formatted.
- Second attempt same command → EXIT=1:
  - **Parity failure (real finding)**: `l10n_key_parity_test.dart` "no non-en catalog clones English for non-identity messages" → `ja` identical to EN for `navAiChat` (EN=`AI Ops`) and `nasInstallBindAddressHint` (EN=`127.0.0.1 for tunnel, 0.0.0.0 for LAN`). Multi-word human-facing strings not translated; flagged for root/AgY. Brand/unit exemptions (`agentClaudeCode`, `processCpu`, `nasQuality4Mbps|10|20`, etc.) honor documented exceptions list and no longer fail. Not a test regression: the whitelist already includes those keys; the guard is functioning.
  - **Rendering failure (real UI finding)**: `testWidgets('all 17 language choices plus System reachable at 320dpi')` → RenderFlex overflow by 49px on the right in the Row at `lib/features/settings/settings_view.dart:541` (`_buildMiniColorBadge`, three-badge mini color row) under the 2x text scale harness at 320dp equivalent. Actual UI defect reproduced; reported to root/AgY evidence, not patched.

### Gate/stop authorization

- Product/UI findings surfaced with direct tracing evidence above: **STOP before analyze / full test / APK build** per instruction that genuine ARB/UI defects must return exact evidence rather than source fixes. Recommended route: root assigns `navAiChat` + `nasInstallBindAddressHint` translation and the `Row`+`_buildMiniColorBadge` scale-safe layout to AgY; then phase-2 may resume with analyze+full+build.

### Final gate state (2026-10-04, post-AgY context-guard patch)

- AgY patch landed on disk (`settings_view.dart` capture-failure-text before await +
  `mounted` + `context.mounted` per spec) and is **consumed**, not further altered.
- Focused regression set (settings_language + settings_navigation +
  cli_chat_shell_navigation + main_shell_dynamic_nav + nas_navigation +
  nas_media_view) → FOCUS=0, All tests passed!; running with strengthened harness:
  `find.text(...).hitTestable()` straightforwards and radio `.hitTestable()` rigour;
  retained 320dp/2x text scaler, Arabic RTL, fresh-container restart, no-overflow
reachability reach (Thai). `AppLocalizations.supportedLocales` already matches
`appLanguageLocales`; gen-l10n was rerun idempotently → GEN=0.
- `flutter analyze` → ANALYZE=0, log: /tmp/opencode/analyze3.log — "No issues
  found!" (the pre-patch `use_build_context_synchronously` warning is historical,
  now cleared by AgY source fix).
- `flutter test` full suite → FULL=0, **+1938 ~18: All tests passed!**
  (18 pre-existing skips baseline preserved; no new skips/warnings).
- `flutter gen-l10n` was rerun after ARB fixes (GEN=0). Catalog parity,
  placeholders and nonempty strings pass in the focused and full suites.
- APK:
  - Old universal current preserved verbatim to unique explicit backup
    `build/app/outputs/flutter-apk/app-release.apk.bak-20261004-global-languages-prebuild`
    with verified SHA `b85ff8ae7e3c6aaf31c5285c84de78750771c71a622db19ad93c8334aa5ef438`,
    123,916,922 bytes — never overwritten (existing old backups untouched).
  - `flutter build apk --release` with existing DEVELOPMENT signature only
    (BUILD=0, log: /tmp/opencode/build-global.log) →
    `build/app/outputs/flutter-apk/app-release.apk`
    - UTC mtime: `2026-10-04T14:55:17Z`
    - Size: 128,684,666 bytes (was 123,916,922)
    - SHA-256:
      `9c330e0a029cf26061751ec13cec696556f635016cb5a5ad5764462024a8feae`
    - apksigner verify: SIG_OK, Signer #1 SHA-256
      `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9` (stock Android
      Debug — development signing only; no KEYCODE/keystore/keyprops changes)
    - Package: `com.antigravity.valhalla.valhalla`, versionCode 1, versionName 1.0.0,
      compileSdk 36, platformBuildVersionName 16.

- UI ownership honored: only mechanical `dart format` on touched tests and
  generated files; no ARB/UI semantic edits; no ADB install, Git mutations, remote
  agents, or dependency shifts. Handoff of final APK to root complete.
- No version-tag/data/permission/ADB operations were taken. The old NAS APK
  remains in the verified backup; the newly built language APK is recorded above.

## Test-only correction pass (2026-10-04, AgY still patching)

- `test/features/settings_language_test.dart` test-only fixes:
  - Delegate probe: `AppLocalizations.delegate.load(locale).localeName` matches
    the intl-canonical tag computed from `locale.toLanguageTag()` (e.g.
    `zh-Hant` → `zh_Hant`); BCP tag strings are still the user-facing
    storage/picker identity — `Locale` storage and ARB tags unchanged.
  - System-following expectation repaired: platform `fr_FR` input intentionally
    resolves to the supported base `Locale('fr')`, not the raw `Locale('fr','FR')`;
    assertion now expects `Locale('fr')`. Storage keeps literal explicit ja overrides as before.
  - Scroll/tap helper drops the invalid (and misused) `hitTestOnBinding`
    fallback assertion; instead it now asserts `findsOneWidget` after
    `Scrollable.ensureVisible`, with no domain logic changed (320dp/2x via
    MediaQuery builder wrapper, fresh ProviderContainer over same prefs,
    testing over real widget dispatcher locales all preserved).
- Verification report update: the traditional `zh_Hant.cmdDangerousWarning`
  trailing `吗？` flag is marked resolved-pending-recheck per root's latest
  inspection (no known char issue remains); the actual generation now passed
  17-catalog parity/metadata/token/nonempty checks. The remaining focused-run
  findings to detect/blockers are: `ja: navAiChat` + `ja:nasInstallBindAddressHint`
  should be human-translated (multi-word), and `Row` + `_buildMiniColorBadge`
  (`settings_view.dart:541`) overflows 49px at a 320dp/2x dialog harness — both
  reported for root/AgY from the previous interim run; no src/ARB edits here.
- No gen-l10n, tests, analyze, build, ADB, git/deps/lib/UI/ARB production edits
  were performed in this correction pass; generated files remain intact.

- `settings_language_test.dart`:
  - Helper harness now watches `settingsProvider` and drives `MaterialApp.locale`
    (null for `system`), with `localeListResolutionCallback: resolveAppLocale` —
    ja/ar selections actually re-localize the widget harness and RTL assertions can
    pass. MediaQuery injection moved from `home:` to `MaterialApp.builder` with an
    inherited `mediaQuery.copyWith(textScaler: TextScaler.linear(2))` wrapping the
    full child so DialogRoute overlay radios render at 2x fonts in 320dp-width tests
    (DPR itself is not a font scale).
  - `_scrollLanguageDialogUntilVisible` now uses the SDK-static
    `Scrollable.ensureVisible(tester.element(target), alignment: 0.5)` and then a
    `hitTestOnBinding(getCenter(target))` non-empty assertion before tapping; the old
    `tester.ensureVisible(target, alignment:)` was invalid and any eager-built
    offstage tile evaluation is no longer treated as reachability. Final Thai
    assertion now requires its rect within the 320dp-equivalent viewport (0..568dp)
    and empty `takeException()`.
  - Fresh-container persistence is no longer implied by a reopen on the same
    provider container state: a brand-new `ProviderContainer` over the same prefs
    singleton is re-pumped and continues to report ja via `settings` +
    Localizations.localeOf + dialog groupValue. System-follow is now tested via
    `tester.platformDispatcher.localesTestValue` (fr→resolves fr, ja persisted→ja
    wins, unsupported xx→en fallback), with direct prefs setString/remove mutations
    between pumps and teardown reset.
  - Added `AppLocalizations.delegate.load(locale)` probe for all 17
    `appLanguageLocales`: returned instance's `localeName` must equal the expected
    tag and a representative navSettings/settingsLanguage/cmdDangerousWarning must
    be nonempty (runtime check, not just supportedLocales comparison).
  - Provider overrides limited to valid value-type overrides: only
    `localStorageServiceProvider.overrideWithValue(...)` and the production
    locale-list callback wiring are used.
- l10n parity test now treats single-token identity values such as `Terminal`,
  plus the brand allow-list (`Valhalla`/`Codex`/`ACP`/`CLI`/`SSH`/`SFTP`/`Mosh`/
  `tmux`/`NAS`/`macOS`/`Linux`/`lang*`) as legitimate shared names; whole multi-word
  human-facing sentences still must be translated and pseudo-translation prefixes
  still rejected. No brands/technical strings altered to appease the tests.
- AgY account switch happened and catalog work resumed (de, fr done, pt/ru in
  flight). No test execution, gen-l10n, analyze, build, ADB, deps, git writes, UI
  or ARB edits have happened since. Generated Dart not regenerated; current NAS
  APK (SHA `b85ff8ae...`) untouched. 33 core locale/persistence tests were green
  in the prior focused run; widget language tests remain prepped, not executed.

## Final housekeeping sync (2026-10-04, times below explicitly UTC)

- `dart format lib/features/settings/settings_view.dart` caused exactly one
  non-semantic mechanical change: removed the extra trailing blank line before EOF
  reported by `git diff --check`. Perms: the source still compiles intact.
- `git diff --check` real exit code 0 (no detector-white space issues remain).
- `flutter analyze` → ANALYZE=0 (log /tmp/opencode/analyze-fmt.log).
- Focused settings_language + settings_navigation reruns → FOCUS=0, All tests
  passed! (log /tmp/opencode/focused-fmt.log). Full suite not repeated because
  formatting-only change of production source (analysis+full already done at
  the same revision immediately prior to formatting block).
- Preserved baseline backup from the already-produced NAS era remains:
  `app-release.apk.bak-20261004-global-languages-prebuild`,
  SHA-256 `b85ff8ae7e3c6aaf31c5285c84de78750771c71a622db19ad93c8334aa5ef438`,
  size 123,916,922 bytes — re-verified, untouched.
- `flutter build apk --release` rerun (previous language build deleted locally,
  same Development signing, no config/key updates) → BUILD=0,
  `✓ Built build/app/outputs/flutter-apk/app-release.apk (128.7MB)`.
  - New artifact: SHA-256
    `4f42ac9e3c4ea38365d0b844d8528ebbceffccc0479fd112fbd317fa13c3432d`,
    size 128,684,666, UTC mtime `2026-10-04T14:59:50Z`.
  - `apksigner verify` → SIG_OK, Signer #1 cert SHA-256
    `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`
    (Android Debug; development signing only).
  - aapt: `name='com.antigravity.valhalla.valhalla' versionCode=1
    versionName=1.0.0`, `platformBuildVersionName='16'`, `compileSdkVersion=36`.
  - No code signing/keyfiles/keyprops changes, no split APK, no dependencies
    updated, no ADB deployment, no Git writes, no remote-agent ops.
- Historical note: earlier clause "all 17 present as of 2026-10-04T10:55Z"
  unjustified invented timestamp removed/corrected to "all 17 present before
  Phase-2 validation began" (2026-10-04 evidence remains: 17 * 1107 parity
  verified appropriately).
