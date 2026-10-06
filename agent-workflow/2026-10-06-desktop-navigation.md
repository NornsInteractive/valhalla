# Desktop navigation settings fix — no build

User confirmed on 2026-10-06: fix Windows navigation / experimental settings;
do not build packages yet. No release, CI, ADB, signing, git commit/push or remote
server operations in this task. Preserve the existing dirty experimental,
language and remote-file changes; they are not a published Windows package.

## Cause and implementation contract

`MainShell._buildNavigationRail` uses `settings.availableSections`, ignoring
configured navigation choices and order. Mobile already uses
`settings.visibleBottomNavigationSections`. Use that same existing getter for
desktop and medium-width rails; do not add separate settings or storage keys.
Retain the existing stable AppSection <-> view-index mapping; an unpinned active
page has no selected rail item, not a wrong highlight or redirected page.

Both desktop and medium layouts must omit the rail AND its vertical divider
when the effective configured list is empty. Keep the top menu button/drawer
accessible so users can still reach Settings and restore choices. The drawer
continues to show all available (experiment-filtered) sections, independent of
pinned navigation. Single-item lists work; many entries must not overflow in
short desktop windows (reuse native scrollable rail; keep disconnect accessible).
Experimental CLI and NAS remain opt-in, disabled by default. Opening/closing
switches filters visible entries without deleting saved positions/history,
resetting the active non-experimental page or changing startup preferences.
The existing provider/storage already implements this; do not duplicate it.

## Ownership

UI: ONLY original AgY Valhalla conversation
`ec81a4be-7543-45ee-8658-f68966f57d3b`, model
`gemini-3.8-flash-high`, effort high. Start ordinary console and type the task
after ready; no initial-prompt switch that can fork a conversation.
Allowed edits: `lib/features/shell/main_shell.dart` and
`agent-workflow/2026-10-06-desktop-navigation-ui-status.md` only. Preserve every
existing change in those files; use apply_patch, no reset/full rewrite. No ARB,
themes, native runners, provider/storage or other pages changes. No tests/build.

Verification: OpenCode, explicit confirmed-free main and small model
`opencode/space-bunny-free` (user-authorized free fallback). Allowed test edits:
`test/features/main_shell_dynamic_nav_test.dart`,
`test/features/cli_chat_shell_navigation_test.dart` and (only if needed to preserve
explicit destination navigation) `test/features/responsive_breakpoints_test.dart`;
reuse current helpers. Legacy rail navigation tests must explicitly pin their
tested destinations, not assume all enabled pages are pinned. Experimental
enablement alone does not auto-add unconfigured destinations to the rail.
Before UI modification, replace the stale "rail always all10" expectation and
add a focused regression proving current wrong behavior. Record actual failure.
After UI completion cover expanded/medium settings order, stable indices,
empty rail+divider with drawer accessibility, singleton, unpinned active page,
all entries in a short viewport, and experimental hide/enable/disable behavior
without changing saved choices. Include provider persistence tests and existing
settings/navigation/shell regressions; analyze, targeted format, diff check.
Do not skip/weaken unrelated tests, generate or rewrite unrelated resources,
add dependencies, build any platform, install or launch external servers.
Use apply_patch for authored files. Record command exit statuses and exact
test count; distinguish simulated desktop widget proof from actual Windows
runtime verification. Report to
`agent-workflow/2026-10-06-desktop-navigation-verification.md`.

## Acceptance boundary

Source fix and focused regression proof only. Old Windows ZIPs remain old until
a separately requested build/release. No claim of Windows device verification.

## Implementation status

Original AgY console completed the UI change and exited with resume ID
`ec81a4be-7543-45ee-8658-f68966f57d3b`; the read-only conversation metadata also
identified `valhalla`. Model and effort remained Gemini 3.8 Flash High / high.
The existing storage/provider contract required no new production changes.

Both rail layouts now consume the configured, experiment-filtered list in
saved order, hide rail+divider when empty, and preserve the drawer. Native rail
scrolling supports all available menu entries in a short window; its bottom
disconnect control remains outside the scrolling destination list.
See [UI report](2026-10-06-desktop-navigation-ui-status.md) and
[OpenCode verification](2026-10-06-desktop-navigation-verification.md).
The regression reproduced 3 expected versus 8 actual before the fix and passes
after it. OpenCode session `ses_eefb2b8bdffe5D9I3ZthdUV7Ay` passed 103 tests
across four focused groups (16 + 18 + 45 + 24), analysis with no issues, scoped
formatting and diff checks. This is simulated desktop/medium widget and settings
persistence evidence, not actual Windows device verification.
No Windows package was rebuilt or published, and no ADB/remote
operations, source commit or push were performed. Existing installed Windows
binaries will only receive this fix after a later authorized build/update.

## Subsequent GitHub push authorization

After source verification, the user explicitly requested pushing on 2026-10-06.
The push includes this desktop fix plus its previously uncommitted experimental
settings and localization dependencies; SettingsView/SettingsNotifier directly
reference the locale catalogue, so those complete ARB/generated resources and
tests travel together. Unrelated remote-file view/SFTP changes remain local.
Shared localization resources may include unused remote-file strings; that does
not enable the uncommitted remote-file behavior. Shared storage and engineering
rules are staged selectively without rewriting their dirty working-tree files.
Validate the exact selected source before push. Use `[skip ci]`, do not change
version/tags/releases, build packages, or trigger CI/ADB. Earlier "no git write"
statements describe the source-fix phase, not this later authorized push.
