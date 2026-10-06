# Global language switching — bounded implementation

## Scope

User asks to complete mainstream global language switching. Deliver 17 locale
choices: en, zh (Simplified), zh-Hant (Traditional), ja, ko, de, fr, es, pt, ru,
ar, hi, id, it, tr, vi, th, plus Follow System default. No claim to cover every
world language or native-speaker linguistic certification. Current 1091 messages
per EN/ZH catalog; preserve all CLI/NAS experiments, data and dirty worktree.
No Git writes, remote operations, private keys or device install in this phase.

## Root contract (ready)

lib/core/localization/app_locales.dart exposes appLanguageLocales (17 choices),
appLocaleFromStorage/appLocaleToStorage, resolveAppLocale. Legacy en/zh/system
storage compatible; new script values persist BCP47 zh-Hant. Unknown/malformed
stored tags follow system without destructive migration. Region tags normalize
to supported languages; zh TW/HK/MO or explicit Hant resolve Traditional, Hans
or CN/SG default Simplified; explicit script takes precedence. System preference
order honored; unsupported system languages fall back English, not generated
alphabetical first locale. No separate downloaded language-pack service.
SettingsNotifier.setLocale persists before updating state, rejects unsupported
explicit selections, and storage false returns throw instead of false success.
Do not remove existing system-language default, clear credentials or reconnect
SSH/agents when switching a language.

## AgY UI/translation ownership

ONLY Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b,
gemini-3.8-flash-high / high. Whitelist:
- lib/features/settings/settings_view.dart
- lib/l10n/app_*.arb (existing and 15 new catalogs)
- lib/main.dart: ONLY locale callback/import wiring, no unrelated startup edits
- agent-workflow/2026-10-04-global-languages-ui-status.md
Other files read-only. No tests/format/gen/analyze/build/ADB/remote/git writes.

1. Full 17-locale ARB catalogs with all template message keys and placeholder
   metadata. Translate actual UI messages, not just menu labels. Preserve keys,
   braces/placeholders, technical flags, model names, units/paths, URLs and brand
   identities. Native autonyms can be the same in every locale via ARB lang*
   keys; this deliberate identity is not an untranslated app message.
   zh-Hant file app_zh_Hant.arb / @@locale zh_Hant; genericzh stays Simplified.
   Do not produce English clones/prefix pseudo-translations/dummy resources,
   do not run network machine translation over all app content, do not upload
   repository content to translation services. Use own translation and native
   edit/apply_patch tools. If not finished, clearly report exact missing locales
   rather than presenting placeholder catalogs as translated. Work in batches
   if needed; do not expand languages beyond agreed list.
2. Reuse existing Material3 language tile/dialog styling. Display native names
   via l10n keys (e.g. 日本語 / Français / العربية), no flags. All choices use
   appLanguageLocales and exact toLanguageTag selection including zh-Hant.
   Keep legacy keys settings_lang_system/zh/en; new key settings_lang_<tag>.
   Bounded scrollable list with all18choices accessible at320dp/largefonts and
   current language still selected when reopening. Current subtitle correct
   for every choice, not fallback Follow System for new languages.
3. Await setter, guard repeat taps, close only after successful saving; localized
   in-dialog failure with retry, mounted checks. Allow long autonyms to wrap.
4. Wire MaterialApp.localeListResolutionCallback=resolveAppLocale with core
   import; supportedLocales stays AppLocalizations.supportedLocales. Default
   system locale remains null. Flutter RTL for Arabic via official delegates;
   no forced global LTR, no mirroring shell output or modifying terminal text.
5. Report exact identity/model, actual catalogs and untranslated exceptions.
   Return idle so OpenCode can mechanically generate and verify.

## OpenCode validation ownership

Use documented bounded context ses_efa045a6bffeBnDODUfPKr6YLw main/small
opencode/fledge-alpha-free confirmed-free fallback after MiMo limit. All test
authorship/execution, format/gen/analyze/build belongs to OpenCode. No UI/ARB
semantic edits; issues returned root/AgY. Before UI lands: pure locale parsing,
serialization/script/region/fallback/resolution/provider persistence tests only.
After UI: expand existing l10n_key_parity_test to every catalog, key/placeholder
sets matching, nonempty messages, generated supportedLocales equals17 catalogue,
all delegates load eachlocale, representative screens translated, Arabic RTL,
selection/reopen/restart/defaultsystem and failure UI; bounded narrow dialog
tests, no full-server interactions. Need honestly state machine checks cannot
prove native-speaker wording; spot-check technical/destructive messages.
Nearest focused gate plus analyze/full tests. Build fresh universalrelease APK
existing DEVELOPMENT signature only; explicit unique backup of currentNASAPK
(SHA b85ff8ae7e3c6aaf31c5285c84de78750771c71a622db19ad93c8334aa5ef438).
Record UTC size/hash/cert; no formalkey/splitoverwrite/ADB/git mutation.
Evidence agent-workflow/2026-10-04-global-languages-verification.md.

## Checkpoint / external quota blocker

Core phase: OpenCode reported 33 focused tests passed, exit 0. UI wiring and
four catalogs (en, zh, zh-Hant, ja) exist; each parses with 1107 message keys.
The template was expanded from 1091 keys by 15 autonyms and a save-failure key.
Structural counts do not certify translation quality: Traditional Chinese needs
spot proofreading (e.g. cmdDangerousWarning still contains a Simplified character).

The original AgY session/model/effort was retained. Japanese-only followup ended
with RESOURCE_EXHAUSTED (429), reported quota reset in about 3h7m. Missing 13:
ko, de, fr, es, pt, ru, ar, hi, id, it, tr, vi, th. Asked user whether to refresh
the account or wait. Do not switch UI ownership/model/conversation without
direction. Preserve pending changes, but do not deliver a partial-language APK.

Generated localization Dart remains from the earlier language set; the settings
menu already advertises the intended 17 choices. This is an incomplete source
checkpoint, NOT a runnable release acceptance claim. Phase-2 tests are prepared
only; no generation/full UI tests/analysis/build/ADB for this feature yet.
Latest installed NAS/CLI-experiments APK is unchanged by this work.

Audit correction to AgY's self-report: its first batch executed local structural
and conversion scratch commands, despite native-edit-only handoff instructions.
Its report's phrase 'Strictly zero command execution' is therefore not literal.
No Flutter generation/tests/analysis/build, ADB or Git mutation was delegated to
AgY. The followup explicitly prohibited scripts and used native file editing.

User chose account switch, then confirmed login complete. Restarted original
AgY conversation/model/effort with German+French bounded batch; current CLI
is receiving tool updates again. Quota error above is a historical checkpoint,
not evidence the new account is still blocked. Do not mark uncreated catalogs
complete until files and followup OpenCode validation actually land.

All remaining translation batches subsequently exited 0 and the original AgY
reported 17/17 catalogs written, plus Traditional Chinese manual corrections.
The success batches' cumulative result envelope still carries the historical
quota error string; no new quota failure should be inferred from that stale
field alone. UI/resource editor is now idle. Complete OpenCode generation and
runtime/regression verification are the next gate, NOT already passed.

## Accepted implementation checkpoint

OpenCode generated all locale classes and passed the 17-catalog structural
checks. UI findings were sent back to original AgY: scale-safe color badge,
always-visible save-failure feedback, missing natural-language translations,
and correct async context lifecycle guards. Root did not edit UI or ARB files.
Latest complete suite: 1938 passed / 18 existing skips, exit 0; analyzer zero
issues, exit 0. Universal release APK built with the existing DEVELOPMENT
certificate; no formal signing key changes, Git mutation or device install.
Final mechanical EOF cleanup and artifact metadata were completed by OpenCode;
focused settings tests and analyzer passed again, and APK rebuilt successfully.
See the verification report for final hash/time/certificate and command proof.
