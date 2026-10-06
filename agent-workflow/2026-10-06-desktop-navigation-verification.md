# Desktop navigation verification — OpenCode, no build

Date: 2026-10-06. OpenCode sessionID `ses_eefb2b8bdffe5D9I3ZthdUV7Ay`; main and
small model are both explicitly `opencode/space-bunny-free` (the model ID is not
the session ID). No build, no gen_l10n, no CI,
no ADB, no git write, no server, no dependency changes. All pre-existing dirty
work (experimental / language / remote-file) preserved untouched.

## Source state observed

`lib/features/shell/main_shell.dart` (AgY) now uses
`settings.visibleBottomNavigationSections` in `_buildNavigationRail`,
`scrollable: true` on the `NavigationRail`, and a `hasRail` guard around both the
rail and its `VerticalDivider` in `_buildExpandedDesktopShell` and
`_buildMediumRailShell`. `MainBottomNavigationBar` was already on the same
getter. No new settings/storage keys were introduced.

## Baseline proof

Regression `desktop rail respects configured selection and order`
(1200x900, `bottomNavigationSections: [files, terminal, dashboard]`, experiments
default off):

- Before the source fix: `Expected: <3>  Actual: <8>` — log
  `/tmp/opencode/valhalla-desktop-nav-baseline.log`, exit code 1.
- After the source fix: passes — log
  `/tmp/opencode/valhalla-desktop-nav-baseline2.log`, exit code 0.

## Test changes (only the two allowed files)

`test/features/main_shell_dynamic_nav_test.dart` (existing dirty changes kept;
the shared helper gained an optional `prefs` map so the real settings notifier
can be driven from storage):

- `desktop rail respects configured selection and order` replaces the stale
  "rail always all 10" expectation: exactly 3 destinations, label order
  Files/Terminal/Dashboard, icon order folder/terminal/dashboard outlined, tap
  Files -> stable view index 3.
- `medium rail respects configured order with stable index` (800x900): order
  Terminal/Files/Dashboard, tap Terminal -> index 2.
- `desktop empty selection hides rail and divider, drawer reaches Settings` plus
  the medium equivalent: no `NavigationRail`, no `VerticalDivider` inside the
  shell, the top menu button still opens the drawer, Settings tile -> index 7.
- `single pinned section renders one selected destination`: 1 destination,
  `selectedIndex == 0`, tap keeps index 2.
- `active unpinned page leaves rail selection empty`: startup Settings with only
  Files pinned -> `selectedIndex == null`, view stays on index 7.
- `all sections pinned in short desktop window scroll without overflow`
  (1200x400, all 10 pinned, CLI+NAS on): 10 destinations, `scrollable == true`,
  no overflow exception, disconnect button still present, last pinned entry
  reachable by scrolling. No live SSH: the suite's existing fake
  server/SFTP/CLI providers plus empty server list are used.
- `runtime experiment toggles filter rail without losing saved order`: seeded
  stored order `[dashboard, nas, files, cliChat]`; rail shows 2 entries while
  NAS/CLI are off, NAS appears in its slot when enabled, closing the switch
  while NAS is active returns the shell to index 0 and hides the entry, CLI
  appears at its saved slot when enabled, and the stored list is unchanged
  (`['dashboard','nas','files','cliChat']`).

`test/features/cli_chat_shell_navigation_test.dart` — the fixture only gained an
optional `pinnedSections` (writes `valhalla_bottom_navigation_v1` +
`valhalla_navigation_acp_v2`), because the rail now honours the pinned list:

- `expanded mode navigation rail navigates to CliChatView` explicitly pins CLI
  before enabling it; the index 8 and `CliChatView` assertions are unchanged.
- `default off: expanded rail shows pinned sections only; NAS/CLI opt-in flow`
  now asserts 4 default destinations, pins NAS and CLI positions before each
  opt-in, checks that enabling adds only the pinned entry (4 -> 5), stable
  indices 9 (NAS) and 8 (CLI), and that disabling hides the entry, returns the
  shell to index 0 and keeps both sections in the saved list. All placeholder,
  drawer and provider-existence assertions are preserved verbatim.

`test/features/responsive_breakpoints_test.dart` was **not** modified.

## Commands, exit codes, test counts

| Command | Tests | Exit |
|---|---|---|
| `flutter --no-version-check test --no-pub test/features/main_shell_dynamic_nav_test.dart test/features/cli_chat_shell_navigation_test.dart` | 16 passed | 0 |
| `flutter --no-version-check test --no-pub test/features/responsive_breakpoints_test.dart test/features/settings_navigation_test.dart test/features/nas_navigation_test.dart` | 18 passed | 0 |
| `flutter --no-version-check test --no-pub test/core/settings_persistence_test.dart test/widget_test.dart test/features/main_shell_top_layout_test.dart test/features/main_shell_back_button_test.dart test/features/main_shell_open_transfers_test.dart test/features/main_shell_fingerprint_test.dart` | 45 passed | 0 |
| `flutter --no-version-check test --no-pub test/core/experimental_features_test.dart` | 24 passed | 0 |
| `flutter analyze --no-pub` | No issues found | 0 |
| `git diff --check` | clean | 0 |
| `dart format` on `lib/features/shell/main_shell.dart` + the two edited test files | already formatted | 0 |

Logs: `/tmp/opencode/valhalla-nav-group1.log`, `-group2.log`, `-group3.log`,
`-experimental-core.log`, `-analyze.log`, `-diffcheck.log`, `-baseline.log`,
`-baseline2.log`.
103 tests total across the four test gates, all passing.

Experimental coverage also comes from the requested gate
`test/core/experimental_features_test.dart` (24 tests, log
`/tmp/opencode/valhalla-nav-experimental-core.log`), which asserts default-off
parsing, restart persistence, write-failure safety, and that hiding an
experimental entry keeps its saved slot and stable view index. Provider
persistence
(`settings_persistence_test.dart`) already covers empty-list saving, duplicate
filtering, order retention and restart re-read, so no extra persistence test
was needed.

One test-only fix during the run: the singleton case tapped
`Icons.terminal_outlined`, but a selected destination renders the selected
icon; it now taps `Icons.terminal`. No production change was needed and no UI
error was observed in AgY's source.

## Scope statement

All desktop/medium evidence above is simulated-desktop widget proof: real
`NavigationRail` widgets at simulated 800x900 / 1200x900 / 1200x400 viewports
with the fake server/SFTP/CLI providers already present in these suites. No live
SSH connection was made and no Windows runtime verification was performed.

## Acceptance boundary

Source fix plus focused regression proof only. Existing Windows ZIPs stay old
until a separately requested build/release. No claim of Windows device
verification.
