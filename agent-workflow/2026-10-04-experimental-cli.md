# CLI chat as an opt-in experimental feature

Scope: user requests hiding CLI chat from normal menus and enabling it only via
Settings > Experimental features > checked CLI chat. No feature removal, no
deletion of chats, agents, credentials or existing navigation preferences.

## Ownership

- Root: non-UI settings/provider/storage and this contract.
- UI/ARB: ONLY original AgY Valhalla conversation
  `ec81a4be-7543-45ee-8658-f68966f57d3b`, `gemini-3.8-flash-high`, effort high.
- ALL test authorship/execution, generation, formatting, analyze and APK build:
  OpenCode original session `ses_f0405efacffePPqWyhHc3GGJY7`, main/small
  `opencode/mimo-v2.6-flash-free`; previously authorized confirmed-free fallback
  only after recording actual rate limit and checking model cost.
  Original verification context now triggers automatic compaction blocked by
  MiMo rate limits; root permits a fresh task-scoped OpenCode verification
  context, preserving the original history, and recording its actual ID/model.
  This is NOT an AgY conversation change: AgY remains original Valhalla only.
- No git commit/push, remote agent/history actions, private key operations or ADB
  uninstall/clear. No device installation required for this request.

## Implemented non-UI contract

`ExperimentalFeature.cliChat`; `SettingsState.enabledExperimentalFeatures`
(immutable Set, default empty); `SettingsNotifier.setExperimentalFeature(feature,
enabled)` persists BEFORE state success and throws on storage failure.
Storage key `valhalla_experimental_features_v1` holds enum names. Missing key,
unknown feature names and empty list do NOT enable CLI chat. Reset disables it.

`SettingsState.isSectionEnabled(section)`, `availableSections`,
`visibleBottomNavigationSections`, `visibleDashboardQuickSections`,
`effectiveStartupSection` centralize availability. Raw startup/nav/quick lists
are preserved; CLI startup falls back to dashboard while disabled. Stable page
indexes and enum names must not shift when hiding an entry; NAS remains index9.
For edits/reorders of visible subsets use notifier
`setVisibleBottomNavigationSections(sections)` and
`setVisibleDashboardQuickSections(sections)`; these merge visible edits with
disabled configured entries, preserving hidden entries' original slots.
CLI provider auto-selects a preferred agent only when enabled; enabling triggers
that existing bootstrap without watching settings as a rebuild dependency.
This prevents a banner/status watcher from auto-opening disabled CLI history.
Disabling does not cancel an already-running remote turn or delete provider state.

## AgY UI task (existing style; no redesign)

1. Settings tile with localized Experimental features label + explanation opens
   a height-bounded scrollable M3 AlertDialog, containing CLI chat CheckboxListTile.
   Add EN/ZH ARB keys (not generated Dart), use stable keys, show saving state,
   disable repeated taps while pending, catch persistence errors with local
   localized feedback; check follows provider state. Close action, 320dp/2x
   text fit. No other experimental feature invented.
2. Drawer, both desktop/tablet NavigationRails and mobile bottom bar filter CLI
   until enabled. Rail selection indexes map visible sections to stable view
   indexes, never use filtered positions as view indexes (NAS regression risk).
3. Shell startup uses effectiveStartupSection; guard dashboard callbacks and all
   navigation selection. When settings disable current CLI view, immediately
   fall back to dashboard; settings changes cannot force arbitrary startup page
   navigation each time. Never cancel/delete/replay any agent conversation.
4. Disabled CLI view must not mount offstage in AnimatedIndexedStack. Keep a
   placeholder at stable index8 and all other pages retained. Do not initialize
   CLI history merely to show a disabled menu. Existing in-memory/history state
   and credentials are not cleared when re-enabled.
5. Dashboard uses visibleDashboardQuickSections. Settings nav/quick/startup
   candidate lists filter disabled sections; reorder visible lists without
   deleting hidden configured CLI entries or changing their saved slots. Stored
   startup label shows effectiveStartupSection while unavailable.
6. Enabling shows CLI in drawer/rail and in navigation configuration candidates;
   does not force-add bottom tab or change startup/other user menu preferences.
   Existing saved CLI bottom/quick entries become visible again in original order.
7. All UI edits confined to shell/main_shell.dart, settings/settings_view.dart,
   dashboard/dashboard_view.dart and ARB + one optional feature dialog widget.
   No test/format/analyze/gen-l10n/build/ADB by AgY. Report edits and exact
   conversation/model in experimental-cli-ui-status.md, then return idle.

## OpenCode proof after UI lands

Provider/storage tests: defaults/unknown feature off; toggle/restart persistence;
reset off; preserve nav order and explicit empty bottom bar; hidden CLI startup
fallback; enable restores old CLI slots; failed write does not report enabled.
CLI automatic preferred-agent bootstrap is disabled while feature off and starts
on enabling; opt-in fixtures for existing automatic-bootstrap tests.
Widget tests: localized settings dialog click/toggle, bounded layout, all menu
gates, correct rail NAS index when CLI hidden, startup fallback, no disabled CLI
offstage mount, current CLI disable fallback. No weakening existing tests.
Existing tests intentionally expecting always-visible CLI need explicit opt-in
fixture setup, not changed product semantics or skipped assertions.
Run scoped mechanical format/gen-l10n, full analyze and focused + full logic
tests. Build fresh local APK with original DEVELOPMENT signing (no release key
environment) preserving previous app-release.apk in a new backup. Record actual
UTC timestamp/size/SHA256/cert; no signing mismatch workaround or device writes.

Status: root contract/provider/storage implemented; original AgY completed UI
and exited 0 with the original conversation ID confirmed. OpenCode completed
analyze exit0, full tests1903 pass/18 existing skips exit0, three new widget
proofs, fresh local development-signed APK and three-ABI AOT marker/hash audit.
Evidence: experimental-cli-verification.md. No ADB or real device/remote actions;
320dp/default-font EN dialog tested, double-font/all-locales are not claimed.
