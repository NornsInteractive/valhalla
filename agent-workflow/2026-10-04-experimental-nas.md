# NAS as an opt-in experimental feature

## Scope and existing state

User requests NAS also in Settings > Experimental features; ALL experimental
features default off. Reuse existing CLI feature gates and persistence. Do not
reset explicit opt-ins on upgrade or delete NAS sources, credentials, index,
playlists, downloads, agent histories, or saved navigation preferences.
Current worktree contains the completed CLI experiment and its verification;
preserve these changes. AppSection.cliChat=8, AppSection.nas=9 remain stable.

Root implemented `ExperimentalFeature.nas` and shared `isSectionEnabled` gating
in settings_provider.dart. Existing empty-set default and exact enum-name
storage parser make NAS default off, even with only `cliChat` opted in. Existing
visible/effective selectors, persistence-before-success, reset, and hidden-slot
merge apply unchanged. No new dependency, schema, or independent toggle.

## AgY ownership and UI acceptance

ONLY original Valhalla conversation `ec81a4be-7543-45ee-8658-f68966f57d3b`,
model `gemini-3.8-flash-high`, effort high. Verify these before editing.
Allowed edits: lib/features/settings/settings_view.dart,
lib/features/shell/main_shell.dart, lib/l10n/app_en.arb, lib/l10n/app_zh.arb,
and agent-workflow/2026-10-04-experimental-nas-ui-status.md. Other files read-only.
No tests, format, analyze, generation, builds, ADB, git writes, remote operations.

1. Add localized NAS checkbox in existing experimental dialog, stable key
   settings_experimental_nas_tile. Uses setExperimentalFeature(nas, checked),
   shared saving guard and local error handling; both values default false.
   Reuse existing UI style, bounded scrollable M3 dialog, accessible EN/ZH.
2. Shell `_buildViews` must consult shared settings for BOTH CLI and NAS.
   Disabled NAS uses SizedBox placeholder key nas_disabled_placeholder at
   stable index9; do not mount NasMediaView offstage or initiate index/source
   scans merely from startup. All three shell modes must use updated helper.
3. Settings listener checks current section via viewIndexToAppSection and
   next.isSectionEnabled; disabling current NAS/CLI falls back dashboard.
   Do not rebuild state, delete configs, or force navigation when enabling.
4. Existing shared available/visible/effective selectors already hide NAS from
   drawer, rails, bottom, startup settings and dashboard quick selections.
   Audit paths for bypasses. Preserve old NAS slots; rail filtered position
   still maps to stable index9. Do not force-add it to bottom bar.
5. Global mini player currently watches nasPlaybackProvider unconditionally;
   this creates a native player and DB even when NAS is disabled. Guard BEFORE
   watching playback: if NAS disabled AND no existing nasMediaPlayerProvider
   (`ref.exists`) return SizedBox without initializing NAS providers. If player
   already exists keep controls available for a running user-started playback
   (no forced stop/disposal). Existing full-player control is allowed for this
   ongoing playback; normal NAS navigation stays gated. Guard should be inside
   Consumer and watch settings so enabling can restore normal behavior.
6. Do not edit NAS media page internals or redesign unrelated UI. Report actual
   conversation/model, modified files, unresolved issues, and return idle.

## OpenCode verification and artifact handoff

All test maintenance/execution, mechanical format/gen-l10n, analyze/build are
OpenCode-owned. Existing session ses_efa045a6bffeBnDODUfPKr6YLw with confirmed-free
main/small opencode/fledge-alpha-free is the documented fallback after MiMo
rate limits; no paid model or parallel subagents. No device install requested
by this feature update (previous ADB permission belonged to prior deployment).

After UI completes: regress both defaults off/missing/empty/unknown storage;
CLI-only stored opt-in does not enable NAS; independent NAS toggles, restart,
reset, failed writes; hidden NAS startup/dashboard/bottom slots preserved and
restored when opt-in. Existing tests assuming NAS always enabled must explicitly
opt in without weakening assertions. Default rail has 8 sections; NAS opt-in
with CLI off maps to9. No NasMediaView, playback/index/source adapter initialization
at default startup. Settings two checkboxes toggle independently and persist.
Current NAS disable returns dashboard. Nearest focused tests plus full analyze
and full tests; report actual failures without skips or swallowed exceptions.

Build a fresh universal release APK with existing DEVELOPMENT signing only,
preserve current APK in explicit unique backup first; record UTC build time,
size, SHA256, apksigner verify/cert. Do not access formal signing private keys,
replace split packages, uninstall/clear device, push git, or execute remote agents.
Write evidence to agent-workflow/2026-10-04-experimental-nas-verification.md using
native edit/write tools or apply_patch, not shell write tricks. Stop at gates.

## Handoff progress

Root settings contract implemented; original AgY resumed and selected the required
model (confirmed local CLI log). UI whitelist edits and status report are present.
AgY process exited0; its result envelope carried a historical upstream EOF error
alongside the completed response, so this is not recorded as a clean upstream
status. Product verification relies on source inspection and OpenCode gates.
Phase1 OpenCode: 24 focused core tests passed (19 previous +5 NAS regressions).
Phase2 complete: focused43 pass; full1909 pass /18 existing skips, exit0;
analyze reports no issues. Fresh development-signed APK build exit0, UTC mtime
2026-10-04T09:59:30Z, SHA256
b85ff8ae7e3c6aaf31c5285c84de78750771c71a622db19ad93c8334aa5ef438.
Previous APK backed up app-release.apk.bak-20261004-095809. No ADB in the initial
feature phase; subsequent explicit deployment request was completed by OpenCode
on 127.0.0.1:14251 at2026-10-04T10:13:34Z, install-r Success, installed APK hash
matches the new artifact, PID and resumed MainActivity verified. No clear or
uninstall; evidence in experimental-nas-device.md. Exact build proof is in
experimental-nas-verification.md.

Full-suite evidence exposed one additional affected fixture in
test/features/nas_media_view_test.dart: the existing Shell NAS-source-selector
positive test assumes an always-visible NAS drawer. Root authorizes OpenCode
to seed NAS opt-in ONLY in that positive case, retain all assertions, and rerun
its nearest tests plus full gates. No product behavior change or new skips.
