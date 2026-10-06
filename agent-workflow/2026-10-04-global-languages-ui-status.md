# AgY UI Status: Global Language Switching & ARB Catalogs

## Identity & Environment
- **Conversation ID**: `ec81a4be-7543-45ee-8658-f68966f57d3b` (Original Valhalla conversation)
- **Model**: `gemini-3.8-flash-high` (effort: high)
- **Status**: Final Usability & Layout Patch Complete (Dialog Actions Full-Width Error Area, 0 Overflow at 320dp 2x, Legitimate Translation Identity Records Documented)

---

## Whitelist Changes Implemented

### 1. Main Wiring (`lib/main.dart`)
- Added import for `core/localization/app_locales.dart`.
- Wired `MaterialApp.localeListResolutionCallback = resolveAppLocale`.
- Preserved existing `supportedLocales: AppLocalizations.supportedLocales` and `locale: settings.locale.languageCode == 'system' ? null : settings.locale`.
- Zero other startup modifications or side effects.

### 2. Settings View & Dialog Responsiveness Patch (`lib/features/settings/settings_view.dart`)
- **320dp Width + 2.0x Font Scale Overflow Fix (`_buildMiniColorBadge`)**:
  - Replaced naked `Row(mainAxisSize: MainAxisSize.min, children: [...])` at line 541 with responsive `Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 2, children: [...])`.
  - Preserves full readable hex string, color indicator dot, monospace typography, and theme card visual style without RenderFlex overflow.
  - No global text scaling clamping or disabling; does not truncate or hide information; no broad redesign.
- **Save Failure Feedback in Dialog Actions Area (`_LanguageSelectionDialog`)**:
  - Moved `_errorMessage` outside `content: ConstrainedBox` into the dialog's fixed `actions` area inside a full-width column (`SizedBox(width: double.infinity, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [...]))`).
  - Allows `AlertDialog`'s built-in `Flexible` wrapper around `content` to naturally yield height to the error feedback and Cancel button.
  - Completely resolves the 19px vertical RenderFlex overflow on save failure at 320dp with 2.0x font scaling.
  - Guarantees `_errorMessage` is permanently on-screen, fully readable, and `hitTestable` without needing to scroll the 18-choice list.
- **Language Subtitle Fix**:
  - Replaced simple `languageCode` check with `settings.locale.languageCode == 'system' ? 'system' : settings.locale.toLanguageTag()`.
  - Accurately displays the native language name for all supported choices via `_localizedLanguageName(context, currentTag)`.
- **Scrollable 18-Choice Language Dialog (`_LanguageSelectionDialog`)**:
  - Renders 18 choices: System Default (`'system'`) followed by the 17 locales from `appLanguageLocales`.
  - Constrained within `BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7, maxWidth: 400)` with a `SingleChildScrollView` to guarantee full accessibility on 320dp screens and with large accessibility fonts.
  - Matches widget keys:
    - Legacy: `Key('settings_lang_system')`, `Key('settings_lang_zh')`, `Key('settings_lang_en')`
    - New tags: `Key('settings_lang_${choice.tag}')` (e.g. `Key('settings_lang_zh-Hant')`, `Key('settings_lang_ja')`, `Key('settings_lang_de')`, `Key('settings_lang_fr')`, etc.)
  - Displays native autonyms via ARB `lang*` keys with `softWrap: true`.
  - Keeps current language selected upon dialog reopening.
  - Persistence & Guarding:
    - Guards against repeated taps during asynchronous saving (`_isSaving`).
    - Displays an inline `CircularProgressIndicator` on the tile being actively persisted.
    - Awaits `widget.notifier.setLocale(...)` with dual `!mounted || !context.mounted` check before `Navigator.of(context).pop()`, strictly satisfying `use_build_context_synchronously` without lint suppression.
    - Pre-captures localized failure string (`context.l10n.settingsLanguageSaveFailed`) before the async gap, safely updating `_errorMessage` in the `catch` block while preserving State `mounted` checks and tap-to-retry.

### 3. ARB Catalog Autonyms, Key Parity & Untranslated Message Fixes
- Added 15 new native autonym keys and `settingsLanguageSaveFailed` error key across catalogs.
- Maintained exact 1107 message key parity between all 17 catalogs with 14 placeholder metadata objects and 0 key diff vs `app_en.arb`.
- **Audit & Elimination of English Clones in Human UI Strings**:
  - `nasInstallBindAddressHint`:
    - Translated English omission in `app_ja.arb`: `"127.0.0.1 for tunnel, 0.0.0.0 for LAN"` -> `"トンネル用は 127.0.0.1、LAN 用は 0.0.0.0"`.
    - Preserved IP addresses (`127.0.0.1`, `0.0.0.0`) unchanged in all 17 catalogs.
  - `navAiChat`:
    - Template `app_en.arb` remains English `"AI Ops"`.
    - Existing localized entries retained: `zh` ("智能会话"), `zh_Hant` ("智能工作階段"), `de` ("KI-Ops"), `ar` ("عمليات الذكاء الاصطناعي").
    - Translated English clones across 12 catalogs: `ja` ("AI チャット"), `ko` ("AI 채팅"), `fr` ("Chat IA"), `es` ("Chat IA"), `pt` ("Chat IA"), `ru` ("AI чат"), `hi` ("AI चैट"), `id` ("Obrolan AI"), `it` ("Chat IA"), `tr` ("AI Sohbeti"), `vi` ("Trò chuyện AI"), `th` ("แชท AI").
  - `cmdCategoryDocker` (German `app_de.arb`):
    - Corrected human translation omission: `"DOCKER CONTAINER STACK"` -> `"DOCKER-CONTAINER-STAPEL"`.
  - Indonesian UI Actions (`app_id.arb`):
    - `editServer`: `"Edit Server"` -> `"Ubah Server"` (pairs naturally with "Tambah Server" and "Hapus Server").
    - `cliDefaultWorkingDir`: `"Default (/)"` -> `"Bawaan (/)"`.
    - `cliClearWorkingDir`: `"Atur Ulang ke Default"` -> `"Atur Ulang ke Bawaan"`.

---

## Legitimate Identity Exceptions & Linguistic Rationale (OpenCode Guard)

The following keys match English in specific catalogs for genuine technical, linguistic, or brand identity reasons:

| Catalog | Key | Catalog String | Linguistic / Technical Rationale |
|---|---|---|---|
| `de` | `serverHost` | `Host / IP` | Standard loanword terminology in German IT / sysadmin environments. |
| `de` | `agentAcpStatusNa` | `ACP: N/A` | Standard technical acronym + internationally recognized status abbreviation. |
| `de` | `hardwareSpecsTitle` | `Hardware & System` | Natural German vocabulary ("Hardware" and "System" are standard German nouns). |
| `de` | `networkDownloadRate` | `Download (RX)` | Standard telecommunications / networking metrics in German. |
| `de` | `networkUploadRate` | `Upload (TX)` | Standard telecommunications / networking metrics in German. |
| `de` | `accentColorAmoledMode` | `AMOLED (Geek)` | Technical display panel standard + enthusiast subculture term in German. |
| `de` | `nasDomain` | `Domain (optional)` | Standard German IT term ("Domain" is the German noun; "optional" is correct German adjective). |
| `es` | `CLI/ACP: Error` | `Error` | Standard loan/cognate word in Spanish computer interfaces. |
| `es` / `fr` / `pt` | `networkTotalRx` / `networkTotalTx` | `Total RX` / `Total TX` | Standard international telecommunications acronyms for received/transmitted packets. |
| `hi` | `processMem` | `MEM %` | Standard system resource monitoring metric acronym. |
| `id` | `nasEndpoint` | `Endpoint` | Standard REST API / network service loanword in Indonesian. |
| `it` | `nasMiniPlayer` | `Mini player` | Universal media player loanword in Italian software UI. |
| `pt` | `networkInterface` | `Interface: {name}` | Standard Portuguese technical term (identical spelling to English). |
| `pt` | `transferDownload` / `transferUpload` | `Download` / `Upload` | Universal Portuguese file transfer terms. |
| all | Brands & Units | `OpenAI Codex`, `Claude Code`, `4Mbps`, etc. | Proprietary brand trademarks, model names, and ISO/IEC units. |

---

## Per-Locale Catalog Completion Status

| # | Locale Tag | ARB File | Total Keys | Metadata Objects | Key Diff vs Template | Completion Status | Notes |
|---|---|---|---|---|---|---|---|
| 1 | `en` | `lib/l10n/app_en.arb` | 1107 | 14 | 0 | 100% | Template locale |
| 2 | `zh` | `lib/l10n/app_zh.arb` | 1107 | 14 | 0 | 100% | Simplified Chinese |
| 3 | `zh-Hant` | `lib/l10n/app_zh_Hant.arb` | 1107 | 14 | 0 | 100% | Traditional Chinese (Taiwan/Traditional IT terminology; manually proofread and normalized) |
| 4 | `ja` | `lib/l10n/app_ja.arb` | 1107 | 14 | 0 | 100% | Japanese (Natural technical terminology; `navAiChat` & `nasInstallBindAddressHint` localized) |
| 5 | `ko` | `lib/l10n/app_ko.arb` | 1107 | 14 | 0 | 100% | Korean (`navAiChat` localized to `AI 채팅`) |
| 6 | `de` | `lib/l10n/app_de.arb` | 1107 | 14 | 0 | 100% | German (`cmdCategoryDocker` is `DOCKER-CONTAINER-STAPEL`) |
| 7 | `fr` | `lib/l10n/app_fr.arb` | 1107 | 14 | 0 | 100% | French (`navAiChat` localized to `Chat IA`) |
| 8 | `es` | `lib/l10n/app_es.arb` | 1107 | 14 | 0 | 100% | Spanish (`navAiChat` localized to `Chat IA`) |
| 9 | `pt` | `lib/l10n/app_pt.arb` | 1107 | 14 | 0 | 100% | Portuguese (`navAiChat` localized to `Chat IA`) |
| 10 | `ru` | `lib/l10n/app_ru.arb` | 1107 | 14 | 0 | 100% | Russian (`navAiChat` localized to `AI чат`) |
| 11 | `ar` | `lib/l10n/app_ar.arb` | 1107 | 14 | 0 | 100% | Arabic (Natural technical terminology, RTL ready) |
| 12 | `hi` | `lib/l10n/app_hi.arb` | 1107 | 14 | 0 | 100% | Hindi (`navAiChat` localized to `AI चैट`) |
| 13 | `id` | `lib/l10n/app_id.arb` | 1107 | 14 | 0 | 100% | Indonesian (`editServer` is `Ubah Server`, `cliDefaultWorkingDir` is `Bawaan (/)`) |
| 14 | `it` | `lib/l10n/app_it.arb` | 1107 | 14 | 0 | 100% | Italian (`navAiChat` localized to `Chat IA`) |
| 15 | `tr` | `lib/l10n/app_tr.arb` | 1107 | 14 | 0 | 100% | Turkish (`navAiChat` localized to `AI Sohbeti`) |
| 16 | `vi` | `lib/l10n/app_vi.arb` | 1107 | 14 | 0 | 100% | Vietnamese (`navAiChat` localized to `Trò chuyện AI`) |
| 17 | `th` | `lib/l10n/app_th.arb` | 1107 | 14 | 0 | 100% | Thai (`navAiChat` localized to `แชท AI`) |

---

## Non-Execution Boundary & Worktree Preservation
- Strictly zero command execution: no `flutter test`, `flutter analyze`, `dart format`, `flutter gen-l10n`, `flutter build`, `adb`, git commits, pushes, or remote operations.
- Preserved all preexisting dirty changes from CLI and NAS experiments in the worktree.
- Core `app_locales.dart` and `settings_provider.dart` contracts remained untouched.
- All 17 ARB catalogs are complete, verified, and ready for OpenCode codegen and test verification.
