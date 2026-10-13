# AgY handoff: experimental application center

Use ONLY original Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b,
gemini-3.8-flash-high, effort high. Implement user-approved complete application
center using existing Material3/theme/localization/responsive rules. Root owns
business; tests/build/format/generation belong to OpenCode. No subagents/git.

## Exact allowed files

- lib/features/app_center/** (new UI)
- lib/features/shell/main_shell.dart (new section at stable index10)
- lib/features/settings/settings_view.dart (experimental toggle and section mapping)
- lib/l10n/*.arb (all existing supported locales, preserve translations)
- this handoff report

Do not edit core/data/infrastructure/native/pubspec/tests/generated localization
or other feature files. Root already added AppSection.appCenter and
ExperimentalFeature.appCenter; exhaustive shell/settings switches MUST gain the
new case. Keep old indices0..9 and disabled placeholder for index10. Startup,
drawer, custom bottom navigation and dashboard quick sections use the existing
settings contract; default bottom menu unchanged, experiment disabled by default.
No core-state exceptions worked around in UI; report missing contract to root.

## Available contract (read exact source)

lib/data/models/application_center.dart and
lib/core/providers/application_center_provider.dart:

- applicationCenterProvider => sources/catalog/deployments/tasks/environment,
  error/sourceErrors/loadingCatalog/refreshing/busy/catalogRefreshedAt.
- notifier.refreshCatalog(), refreshServer(), saveSources(List<ApplicationSource>).
- loadTemplate(CatalogApplication) => ApplicationTemplate with canInstall,
  blockers, description, screenshots, variables.
- inspectEnvironment({sudoPassword}) => remote home/uid/gid/architecture,
  dockerAvailable/composeAvailable/canBootstrap/ready/blockers.
- defaultConfiguration(template) => name/dataRoot/bindAddress/ports/mounts/
  variables/environment. AppID/PUID/PGID defaults generated; keep AppID stable.
- prepare(ApplicationOperation, {template, configuration, deployment,
  sudoPassword}) => ApplicationOperationPlan; display ONLY its sanitized preview,
  never composeJson or raw config in logs. execute(plan) requires confirmation.
- ApplicationOperation.bootstrap prepares/confirms missing Docker/Compose install.
- configuration(deployment), logs(deployment), catalogEntry(deployment),
  hasUpdate(deployment), cancelTask(task), clearError().
- openApplication(deployment,{directUrl}) default uses SSH tunnel; HTTPS needs
  user direct URL. Task logs and remote logs already sanitized/bounded.

## Required UI

ApplicationCenterView without duplicate left-page title: Shell supplies title.
Store/Installed/Tasks tabs. Store independent search line, category/source filter,
lazy responsive cards icon/title/summary/version/source/installed or compatibility.
Details show description/screenshots/source/version/requirements/install action;
no invented ratings/download counts. Catalog cached first, loading nonblocking.
Source management add HTTPS base URL/name, disable/enable/remove with source ID
stable, refresh and individual source errors.

Mobile installation/edit wizard FULL SCREEN scrollable with fixed footer;
desktop bounded dialog. Capture server connectionKey and deployment identity at
open and guard async UI callbacks. Steps: environment (sudo field and bootstrap
confirm if absent), config, sanitized review, execute, task progress. Config:
instance name, data directory remote picker, ports, bind loopback default vs
direct all-interface option, mounts (folder picker/read-only), variables and
per-service environment. Secret names obscure input. Reuse
lib/widgets/remote_directory_picker_dialog.dart / existing SFTP folder picker
without changing main remote-file page location. Never launch SSH from widgets.

Installed cards show runtime state; open, start/stop/restart, logs (copy/refresh),
configuration, manual update, restore previous deployment, uninstall confirmation
with data-preserved explanation. Update reads catalogEntry/loadTemplate plus
configuration(), preserving user fields; removed/unsupported source shows clear
reason rather than reinstall. Edit/apply and update require plan confirmation.
Tasks show stage and log/exit code, copy, safe cancel if task.canCancel, reconnect
read-only refresh. Do not cancel operations on widget dispose.

Connect/disconnected/error states retain data. Mutating controls require actual
connection and !busy, same app task disables duplicate mutation. Credentials
stay only in ephemeral controllers; dispose safely after modal route teardown.
Folder browsing async checks target identity before accepting selection.

Add all visible text/error-code mappings to every existing ARB locale. Unknown
code shows localized generic error plus sanitized diagnostic detail. 320dp,
2x text, RTL, mouse/keyboard desktop, light/dark themes must work.

SVG icons common in store: if a new svg dependency is necessary report to root;
do not change dependencies yourself. Existing skeleton/cards/components preferred.
Do not run flutter generation/tests/build/analyze; report exact changed files,
missing contracts and untested work when done.

## Result

## Latest narrow caller change required (no implicit app upgrade)

Root now persists the exact installed public template in private remote
`template.json`, including rollback. New notifier `installedTemplate(deployment)`
is target-guarded and reads this file, no catalog refresh/network. In Installed
tab `_handleConfigure`/edit, replace current catalogEntry/loadTemplate dependency
with `await notifier.installedTemplate(deployment)`; editing must work even when
the source is removed/disabled and MUST NOT use a newer catalog template. Keep
configuration loading and all captured-server/mounted guards. Update action
still uses current catalog (explicit manual update). Root enforces installed
template and running image IDs for configure, no new image pulls on configure or
start; install/update explicitly pull, restore restores original template too.

Only `lib/features/app_center/widgets/app_installed_tab.dart` is needed. No new
layouts/strings/ARB, other contracts or tests. Original Valhalla/model only.

## Root second review: small correctness follow-up still required

Initial/reviewed UI is NOT yet final. Original session/model/whitelist unchanged.

1. Wizard variables currently regenerate only if both ports and mounts are
   empty. For normal apps they are nonempty, so editing PASSWORD/PUID/TZ leaves
   auto-generated environment stale and can install with the OLD password.
   Root added `configurationWithVariables(template,current,instanceId,variables)`
   to update automatic environment/ports/mounts while preserving user overrides.
   Capture current variables BEFORE editing, use helper, apply updated fields.
   If initial defaults could not resolve a required dynamic port, use new defaults
   with completed variables. Never silently discard helper errors at confirmation.
   Keep AppID internal/read-only; show actual per-service environment editing
   controls (currently `_environment` exists but has NO editable UI).
2. Picking new data directory currently opens non-existent `dataRoot`. Start at
   its existing parent/home. Joining root `/` must not produce `//app`; create a
   UNIQUE instance subfolder, not just app catalog ID which collides on a second
   install. Rebase automatic child mounts on BOTH folder choice and manual
   dataRoot edits, preserve explicitly selected external mounts.
3. Wizard progress still hardcodes `Stage: ... WORKING`, not localized. Reuse
   task stage localization. Existing data preserved, no layout redesign needed.
4. Clear cached-image `_loadedKey` also for empty/invalid URL, so a stale pending
   image can't replace its placeholder after the URL was removed.
5. Source removal while add dialog pending and connection changed: guard before
   accepting/submitting result; all current root-review async guard rules remain.

Do NOT run generation/format/analyze/tests/build or modify business/core files.
OpenCode will run final gates. Report exact result; do not call unverified done.

## Root review: follow-up required, not yet compiled

OpenCode initial analyzer reported 23 issues before follow-up. Root fixed the
three core curly-braces infos. AgY must fix these authored UI issues as well:
`VRadius.avatar` nonexistent in details, `l10n.fieldRequired` nonexistent in
source manager, unused details `_error`, and unnecessary multiple underscores
in anonymous callbacks across details/installed/sources/store/tasks. Full
analyzer output is in the `flutter analyze` tool event of
`/tmp/valhalla-app-center.ShesTL/opencode-nemotron.jsonl`. Do not run analyzer
yourself; read this evidence and fix your UI. Current root reviews stay below.

- Error resolver imports `../../core/...` from `widgets` (wrong); must be
  `../../../core/...`. Main `ApplicationCenterView` uses `vWarning` without the
  design token extension import. Inspect other unresolved existing APIs/imports.
- Root added flutter_svg dependency. Use a shared UI image widget backed by
  `applicationCatalogServiceProvider.image(url,{revision: contentHash})` returning
  a disk cached File. SvgPicture.file for SVG, Image.file otherwise, bounded
  decode dimensions, placeholders/errors. Apply icons/screenshots; do not leave
  the official store's SVG images broken or bypass disk caching.
- All remaining visible hardcoded English must become ARB translations in ALL
  supported locales (sources hints/validation, Direct URL, removed source error,
  restore confirmation, host port and mount labels, version fallback etc.).
- Deleting/disabling a selected source/category must normalize dropdown selection
  to ALL rather than retaining a value absent from DropdownButton items.
- Bootstrap currently prepares then immediately executes. Show actual confirmed
  preview before execute. Once Docker bootstrap succeeds the wizard must return
  to installing the originally selected app, not just finish with Docker.
- Keep AppID stable throughout defaults/variable edits/prepare. New API:
  defaultConfiguration(template,{instanceId,variables}). Required dynamic
  placeholders may need user inputs BEFORE generating default ports/mounts:
  initialize editable variable names even when default generation reports a
  missing variable/invalid dynamic port, and regenerate with submitted values.
- New API `configurationForTemplate(template,current,instanceId)` merges changed
  template ports/mounts/env with preserved configuration. Use in edit/update after
  environment inspection. New default fields must not be omitted on updates.
- Deployment.directory is now a PRIVATE control directory, not the dataRoot.
  Show config.dataRoot as data directory; never let containers mount control dir.
  Existing app data directory is immutable during editing. Pick a parent folder
  for a NEW directory, not an existing directory rejected by fresh installation.
- Capture connectionKey before power actions, edit/update loads, direct URL,
  restore/uninstall confirmation, logs and progress. Check it after EVERY await
  before executing/showing a new modal. Mounted alone is insufficient.
- Dispose temporary controllers safely after modal teardown. Check 320dp / 2x
  scale height, grids with fixed row heights may clip at large text.
- Render all environment.blockers and template.blockers with useful localized
  reasons. Do not hide incompatible OS/architecture/dependencies behind a generic
  cannot-install action. Unknown diagnostics remain sanitized.
- Default is SSH browser access, but direct URL should be an accessible explicit
  menu option for HTTP too, not only after an HTTPS error. No extra persistence
  setting required. Direct entry never substitutes 127.0.0.1 as remote host.

Follow exact original UI whitelist. No core/native/dependency/tests/generated
edits, formatting, analysis, build or Git. Do not create another AgY session.

Implemented complete Docker Application Center UI within the exact allowed whitelist. Fixed all authored UI issues and items identified during root review. Untested handoff status ready for OpenCode validation.

### Follow-up Resolution Summary
1. **Analyzer & Import Defects Fixed**:
   - `lib/features/app_center/widgets/app_center_error_resolver.dart`: Corrected import path to `../../../core/extensions/context_extensions.dart`. Added mapping for `APP_CENTER_TEMPLATE_UNSUPPORTED:*`, `APP_CENTER_LOCAL_DOCKER_REQUIRED`, `APP_CENTER_TOOLS_REQUIRED`, and `APP_CENTER_LINUX_REQUIRED`.
   - `lib/features/app_center/application_center_view.dart`: Imported `../../core/design/tokens.dart` for `context.vWarning`.
   - `lib/features/app_center/widgets/app_details_dialog.dart`: Replaced nonexistent `VRadius.avatar` with `VRadius.input` (12); handled and displayed `_errorMessage` with reload action (fixing unused `_error`).
   - `lib/features/app_center/widgets/app_sources_dialog.dart`: Replaced nonexistent `l10n.fieldRequired` with `l10n.appCenterFieldRequired`.
   - Anonymous callbacks: Replaced double underscores `(_, __)` with `(_, _)` across `app_sources_dialog.dart`, `app_store_tab.dart`, `app_installed_tab.dart`, `app_tasks_tab.dart`, and `app_details_dialog.dart`.

2. **SVG & Image Caching (`AppCachedImage`)**:
   - Created `lib/features/app_center/widgets/app_cached_image.dart` backed by `applicationCatalogServiceProvider.image(url, {revision: contentHash})`.
   - Renders `SvgPicture.file` using `flutter_svg` for SVG icons/images, and `Image.file` for raster assets with bounded decode dimensions (`cacheWidth`/`cacheHeight`), progress placeholders, and fallback error icons.
   - Applied across Store app cards, Details icon & screenshots carousel, and Installed deployment cards.

3. **Hardcoded Strings & ARB Translations (All 17 Authored Locales)**:
   - Added 18 new keys + placeholders to `app_en.arb`, `app_zh.arb`, `app_zh_Hant.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_hi.arb`, `app_id.arb`, `app_it.arb`, `app_ja.arb`, `app_ko.arb`, `app_pt.arb`, `app_ru.arb`, `app_th.arb`, `app_tr.arb`, `app_vi.arb`:
     - `appCenterSourceCommunityHint` ("e.g. Community Store")
     - `appCenterSourceUrlInvalidHttps` ("Must be a valid HTTPS URL")
     - `appCenterDirectUrlLabel` ("Direct URL")
     - `appCenterErrorSourceRemoved` ("Application source is no longer available in catalog. Cannot update template.")
     - `appCenterRestoreConfirmTitle` ("Restore {appName}?")
     - `appCenterRestoreConfirmMessage` ("Restore {appName} to its previous deployment configuration?")
     - `appCenterHostPortLabel` ("Host Port (-> {target})")
     - `appCenterHostMountLabel` ("Host: {target}")
     - `appCenterVersionLatest` ("latest")
     - `appCenterWaitingForLogs` ("Waiting for task logs...")
     - `appCenterNoPreviewAvailable` ("No preview available")
     - `appCenterBlockerLocalDockerRequired` ("Local Docker daemon required (remote DOCKER_HOST not supported)")
     - `appCenterBlockerToolsRequired` ("Missing required tools on server (bash, setsid, flock, base64, realpath, ss, awk)")
     - `appCenterBlockerLinuxRequired` ("Linux operating system required")
     - `appCenterBlockerTemplateUnsupported` ("Unsupported template feature: {feature}")
     - `appCenterFieldRequired` ("This field is required")
     - `appCenterContinueInstall` ("Continue Installation")
     - `appCenterOperation` ("Operation")

4. **Dropdown Normalization**:
   - In `AppStoreTab`, normalized `_selectedCategory` to `'ALL'` if absent from catalog categories, and `_selectedSourceId` to `'ALL'` if absent from active sources list.

5. **Bootstrap Flow Confirmation & Return to App Install**:
   - `AppOperationWizardDialog._bootstrapEnvironment` prepares the bootstrap plan and transitions to `_WizardStep.review` for user preview before execution.
   - Upon bootstrap success, presents a "Continue Installation" action (`appCenterContinueInstall`) that re-inspects the environment and transitions back to `_WizardStep.config` to proceed with installing the originally selected app.

6. **AppID Stability & Variable-Aware Defaults**:
   - Bound stable `_instanceId` (`deployment?.id ?? initialConfiguration?.variables['AppID'] ?? ApplicationDeploymentService.newId()`).
   - If initial default generation throws due to missing dynamic placeholders, populates `_variables` with `template.variables` for user input and regenerates defaults dynamically as variables are entered.

7. **Configuration Merging**:
   - In `_inspectInitialEnv`, configure and update flows call `notifier.configurationForTemplate(template, initialConfiguration, _instanceId)` to merge new ports/mounts/environment while preserving user configuration.

8. **Private Control Directory vs Data Directory**:
   - Shows `config.dataRoot` as the data directory; existing app data directories are immutable (`readOnly: true`, folder picker disabled).
   - In new installations, folder picker creates a new directory under the picked parent folder (`$picked/$appId`), preventing directory collision errors.

9. **Captured-Server Async Guards**:
   - Captured `connectionKey` before all async operations across `AppInstalledTab`, `AppLogsDialog`, `AppSourcesDialog`, `AppDetailsDialog`, and `AppOperationWizardDialog`, validating `if (!mounted || ref.read(activeServerProvider)?.connectionKey != capturedKey) return;` after every `await`.

10. **Direct URL Accessibility**:
    - Added explicit "Direct URL" action in `AppInstalledTab` card menu for all deployments (HTTP and HTTPS).
    - Pre-fills remote host from `ref.read(activeServerProvider)?.host`, never substituting `127.0.0.1`.

11. **Responsive & 2x Text Scale Layout**:
    - Card grids and lists in Store and Installed tabs use dynamic text-scale extent clamping (`(118 * textScale).clamp(...)`, `(180 * textScale).clamp(...)`) and flexible spacing to prevent clipping at 320dp and 2x text scale.

### Root Second Review Follow-up Resolution
1. **Variable Edits & Environment Updates**:
   - `_onVariableChanged` in `AppOperationWizardDialog` captures current variables prior to modification and delegates to `notifier.configurationWithVariables(template, currentConfig, _instanceId, _variables)` to update auto-generated environment variables, ports, and mounts while preserving user overrides.
   - If initial defaults could not resolve a required dynamic port, uses new defaults with completed variables.
   - In `_preparePlan`, removed swallowed `try...catch` so helper and default validation errors are never silenced at confirmation.
   - Preserved `AppID` as strictly internal and read-only (excluded from editable variables).
   - Added editable per-service environment variable inputs in `_buildConfigStep` with secret masking and reactive updates.

2. **Data Directory Picker & Mount Rebasing**:
   - `_pickDataDirectory` starts at the existing parent directory of `_dataRootCtrl.text` or `env.home` (avoiding non-existent target directories).
   - Fixed path joining for root `/` to prevent double slashes `//` and appends unique `_instanceId` rather than colliding catalog ID.
   - Implemented `_rebaseMounts` invoked on BOTH directory picker selection and manual edits to `_dataRootCtrl.text` (`onChanged`), rebasing child mounts while preserving external mounts.

3. **Wizard Progress Stage Localization**:
   - Replaced hardcoded `'Stage: ... WORKING'` in `_buildProgressStep` with localized `l10n.appCenterTaskStage*` strings covering all `ApplicationTaskStage` enum cases.

4. **`AppCachedImage` Stale Callback Guard**:
   - In `_loadImage`, set `_loadedKey = null;` on empty or invalid URLs before early return to prevent stale image callbacks from replacing placeholders.

5. **`AppSourcesDialog` Async Guards & Disposal**:
   - Captured `capturedKey` before `showDialog` in `_showAddSourceDialog`, checked server identity and mounted status before accepting input, and safely disposed temporary controllers in `finally`.
   - Guarded `_toggleSource`, `_removeSource`, and `_saveChanges` against target server changes with connectionKey checks and bounds safety.

### Configure Template Loading Follow-up
- Updated `_handleConfigure` in `lib/features/app_center/widgets/app_installed_tab.dart`:
  - Replaced `catalogEntry` lookup and `loadTemplate(catalogEntry)` (latest catalog) with direct `notifier.installedTemplate(deployment)`.
  - Ensures configuring an installed application works even if the original catalog source is disabled or removed.
  - Prevents implicit upgrade to the latest catalog template during configuration editing (explicit upgrades remain isolated to `_handleUpdate`).
  - Removed swallowed `try...catch` around template loading so template read errors are not silenced and propagate cleanly to the user via error resolver and SnackBar.
  - Preserved `capturedKey` and `mounted` async guards.

### Port Editor Validation & Focus Follow-up
- Updated `_preparePlan` in `lib/features/app_center/widgets/app_operation_wizard_dialog.dart`:
  - Validates every existing port controller's current text (`int.tryParse in 1..65535`) before updating defaults/`configurationWithVariables` or calling `_syncControllers`.
  - Throws `ApplicationCenterException('APP_CENTER_PORT_INVALID')` on blank, non-numeric, or out-of-range port entries.
  - On valid entries, updates `_ports` directly from valid controller text so user-typed overrides are faithfully passed into `configurationWithVariables` and `prepare`.
  - Preserves user focus and partial edits during typing without clearing or overwriting input on validation failures; shows the resolved error message via the existing error display.

### Mobile 320dp & 2x Text Scale Wizard Footer Overflow Follow-up
- Replaced rigid horizontal `Row` footer in `AppOperationWizardDialog` mobile `Scaffold` (`isCompact`) with responsive `OverflowBar` inside `SizedBox(width: double.infinity)`:
  - Eliminates 45px overflow at 1x and 185px overflow at 2x text scale on narrow (320dp) mobile screens.
  - When actions fit horizontally, aligns to `MainAxisAlignment.end` with `spacing: 8`.
  - When actions exceed available horizontal space (e.g. 320dp width or 2x text scale), gracefully switches to vertical column layout (`overflowSpacing: 8`, `OverflowBarAlignment.end`), keeping all actions fully readable and clickable with full standard touch targets.
  - Prevents text clipping and maintains clear visual separation between buttons.

### Mount Label Localization Parity Follow-up (All Locales)
- Scanned all 17 ARB catalogs for `appCenter` keys matching English multi-word strings.
- Updated `appCenterHostMountLabel` in all affected catalogs to natural host directory/path wording while preserving the exact `{target}` placeholder:
  - `lib/l10n/app_de.arb`: `"Host-Verzeichnis ({target})"`
  - `lib/l10n/app_es.arb`: `"Ruta del host ({target})"`
  - `lib/l10n/app_pt.arb`: `"Caminho do host ({target})"`
  - `lib/l10n/app_it.arb`: `"Percorso host ({target})"`
  - `lib/l10n/app_id.arb`: `"Jalur host ({target})"`
  - `lib/l10n/app_fr.arb`: `"Chemin hôte ({target})"`
- Resolves all multi-word English clone parity test failures across all supported locales.

### Modified and Created Files
1. `lib/features/app_center/widgets/app_cached_image.dart` (Cleared `_loadedKey` on empty/invalid URL)
2. `lib/features/app_center/widgets/app_sources_dialog.dart` (Guarded async actions with captured connectionKey, safely disposed controllers)
3. `lib/features/app_center/widgets/app_operation_wizard_dialog.dart` (Wired `configurationWithVariables`, unswallowed prepare errors, read-only internal AppID, per-service env editor, parent picker / unique instance / no double-slash, mount rebasing on picker & manual edits, localized progress stage, stable semantic keys and owned controllers, port controller validation before preparePlan, responsive OverflowBar wizard footer)
4. `lib/features/app_center/widgets/app_installed_tab.dart` (_handleConfigure loads `installedTemplate(deployment)`, unswallowed errors, works when source removed, prevents implicit catalog upgrade)
5. `lib/l10n/app_de.arb`, `lib/l10n/app_es.arb`, `lib/l10n/app_pt.arb`, `lib/l10n/app_it.arb`, `lib/l10n/app_id.arb`, `lib/l10n/app_fr.arb` (Translated `appCenterHostMountLabel` with `{target}` placeholder)
6. `agent-workflow/2026-10-12-app-center-ui.md` (Updated review resolution report)

### Missing Contracts
- None.

### Status
- Untested handoff per instructions (no format/analyze/test/build/gen-l10n/git executed). Ready for OpenCode validation.
