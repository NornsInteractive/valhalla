# Terminal UI recheck — 2026-10-14

Owner: terminal bridge/test reviewer. UI changes remain assigned to AgY.
Latest history UI result: **14/14 passed** after AgY fixed both dismissal races.
The six-file stable terminal cohort passed **56/56**; after NAS compilation was
fixed, the main-shell cohort passed **5/5**, for **61/61 distinct terminal UI
checks** across the final two runs.
This is not device or live SSH acceptance.

## Verification attempted

```sh
flutter test --no-pub \
  test/features/terminal_history_ui_test.dart \
  test/features/terminal_toolbar_actions_test.dart \
  test/features/terminal_tmux_notice_test.dart \
  test/features/terminal_mosh_entry_test.dart \
  test/features/settings_terminal_tmux_test.dart \
  test/features/settings_terminal_font_size_test.dart \
  test/features/main_shell_drawer_focus_test.dart \
  --reporter expanded
```

First attempt: exit 1, all seven files blocked during compilation; no runtime
assertions executed. They were not seven independent product failures.

After AgY corrected the three findings below, the same command completed with
exit 0: **57/57 tests passed**. The new history UI file contributes 10 tests.

The existing tmux notice fixture was corrected to establish connected state
before disconnect/reconnect; its restored-notice and two-second expiry
assertions were preserved. Fresh first connection is tested separately and
must never claim restoration.

## AgY follow-up — resolved

1. **Compilation blocker, resolved and compiled:**
   `lib/features/terminal/widgets/terminal_history_drawer.dart:286`
   passes `_isSubmitting ? null : _selectSession` to `RadioGroup.onChanged`.
   That callback is non-nullable. Always supply the callback and retain the
   existing `_selectSession` busy guard. Disable individual choices while
   saving if appropriate; do not remove duplicate-submit protection.

2. **Resolved and covered by passing widget tests:**
   `lib/features/terminal/terminal_view.dart:87` marks any non-connected to
   connected transition as restored, including a fresh terminal's initial
   connection. Only show restored for explicit restore intent or a reconnect
   after this bridge previously reached connected. Clear transient state when
   switching bridges so another tab does not inherit the banner.

3. **Resolved by static inspection; no screenshot acceptance claimed:**
   `lib/features/terminal/terminal_view.dart:691` has an unbounded custom tab
   title. Add bounded label width, one-line ellipsis and a full-title tooltip so
   a 64-character label cannot consume the entire scroll strip.

The existing follow-up document already explained items 2 and 3; they were not
new scope. AgY added the intent/previous-connection guard, cleared transient
state on bridge switches, and bounded custom labels with ellipsis and tooltip.

## Completed regression coverage

The new `terminal_history_ui_test.dart` covers active-only initialization,
same-ID target edits, fresh-versus-restored notices, offline empty states,
rename disposal and late save failures, default-save failure, stale target
protection, disabled restore for ended history records, explicit first history
attach, and preventing restored banners from leaking between tabs. Tests use
local fakes only and never connect to SSH.

Existing toolbar, tmux notices, Mosh entry, terminal settings, and shell drawer
focus tests also passed, including mobile explicit-keyboard behavior and
Windows input behavior. Scoped analysis of the new history UI test and changed
tmux notice test returned no issues.

Previous focused non-UI run remains valid: planner/tmux/rebind tests passed
63/63; the three owned test files also passed static analysis. No packaging,
ADB testing, push, or publication was performed by this reviewer.

## Additional entry-point checks and remaining dialog race

Two requested real-entry tests were added to the history UI file and passed
along with the existing ten tests (**12/12**):

- Android 390dp: open the inner drawer using `terminal_history_button`, close
  through the scrim/system back, including after explicitly opening the keyboard.
  No automatic keyboard restoration, no remote output bytes, and buffer retained.
- A 64-grapheme combining-character/emoji title has its complete tooltip, a
  bounded one-line label, and horizontal scrolling still reaches another tab.
  The fixed new-tab button remains clickable without sending any SSH commands.

The subsequent read-only lifecycle review found one reproducible outstanding
issue in two save paths. Thirteenth and fourteenth tests were added as proof:

```sh
flutter test --no-pub test/features/terminal_history_ui_test.dart --reporter expanded
```

**Fails on current UI:** Start saving a rename, close its dialog through back,
then finish the save 10ms later while the exit animation is running. The dialog
is still mounted, so `terminal_history_drawer.dart:80-82` pops again and removes
the underlying page. The startup-default dialog has the same confirmed pattern
at `:241-243`. The full latest run exits 1 with **12 passed, 2 failed**:

- `rename completion during dismiss animation does not pop its page`
- `default completion during dismiss animation does not pop its page`

AgY should check that the dialog route is still current before navigating (and
before late error updates), or safely prevent dismissal during submission.
`mounted` alone is insufficient. For example, capture the dialog's own route
while active and, after awaiting, require both `mounted` and `route.isCurrent`
before `Navigator.pop` or showing a late dialog error. A dismissed route must
never pop another route. No UI file was changed by reviewer. Scoped analysis of
the final 14-test file returned no issues.

Target review: startup selection captures the full server target and rejects a
changed endpoint/null selection before dispatch; the passing stale-target test
covers clearing the default. Provider persistence captures the original
workspace, so a server switch during a queued save does not save into a new
server. Rename paths also compare full targets before mutation. They still
capture the opener's `WidgetRef` at `:151`/`:182` without checking that opener's
context remains mounted; if its subtree disappears while the dialog stays open,
the ref read is caught as a save failure rather than crashing, but a dialog-owned
ref or a pre-read opener-mounted guard would avoid that stale-ref path.

## Final bridge/core review and dialog-fix recheck

Read-only final review of planner, bridge, terminal provider and CLI/login/Docker
call sites found no additional blocking regression. New terminals still use a
target-scoped UUID and `new-session` without `-A`; restored terminals use exact
attach-only targeting without `-d`. Previously opened ordinary PTYs keep their
buffer and report interruption rather than claiming the old process recovered.
Host CLI launch commands, Docker remote-exec and explicit login retries retain
their plain startup path and are not added to SSH-terminal history. Unchanged
core tests were not rerun.

AgY captured each dialog route and added `mounted && route.isCurrent` checks to
both successful and failed saves. Both dismissal-race tests now pass.

The first seven-file retry produced 56 passing assertions, but the main-shell
file failed to compile because the in-progress NAS view referenced five missing
localization getters. The shared compiler also emitted a synthetic history-test
load error; this was not counted as a terminal runtime failure. Evidence:
`/tmp/valhalla-20261014-terminal-ui-recheck.log`.

The stable six-file cohort was then run without the NAS-dependent main shell:

```sh
flutter test --no-pub \
  test/features/terminal_history_ui_test.dart \
  test/features/terminal_toolbar_actions_test.dart \
  test/features/terminal_tmux_notice_test.dart \
  test/features/terminal_mosh_entry_test.dart \
  test/features/settings_terminal_tmux_test.dart \
  test/features/settings_terminal_font_size_test.dart \
  --reporter expanded
```

Result: **56/56 passed, exit 0**, including all 14 history UI tests. Log:
`/tmp/valhalla-20261014-terminal-ui-stable-six.log`. No source/UI changes were
made during this final review/recheck.

After AgY replaced the five NAS localization references, the remaining command
completed successfully:

```sh
flutter test --no-pub test/features/main_shell_drawer_focus_test.dart --reporter expanded
```

Result: **5/5 passed, exit 0**. Log:
`/tmp/valhalla-20261014-main-shell-final.log`. Drawer opening/selection/backdrop/
system-back, hidden-page focus, preserved search/page state, and explicit
terminal-keyboard behavior all pass. No terminal UI regression remains failing
in this scoped suite; real device/live SSH acceptance is outside this run.
