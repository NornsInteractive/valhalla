# Terminal UI API and validation handoff

Read parent `2026-10-14-nas-terminal-compact.md` for approved behavior/ownership.
Core code is being completed; inspect final signatures, do not edit core to fit UI.

## Provider

`terminal_provider.dart` exports terminal history models.
`SshTerminalState` adds `history`, `historyStatuses`, `defaultHistoryId`,
`isInitialized`, `isInitializing`, `isHistoryLoading`, `errorCode`, `noticeCode`.
`TerminalHistoryRecord`: `id`, `serverId`, `targetKey`, `remoteSessionName`,
`title`, `createdAt`, `lastUsedAt`, `isLegacy`.
`TerminalHistoryStatus`: `unknown`, `available`, `open`, `ended`.

Notifier methods (Future<void> unless noted):
- `ensureInitialized()` — only ACTIVE SSH-page entry, never hidden page build.
- `refreshHistory()`, `restoreHistory(String id)`.
- `setDefaultHistory(String? id)` — null means new terminal.
- `renameTab(String tabId, String title)`, `renameHistory(String id, String title)`.
- `clearNotice()` clears operation feedback; `addNewTab([String? customTitle])`
  always fresh, retains current useTmux preference.

MainShell currently builds `const SshTerminalView()` in an IndexedStack. Add an
explicit active property passed from `_currentIndex` (SSH is index2; prefer enum
mapping). SSH view schedules ensureInitialized only when active/target changes,
not every render. No terminal start from dashboard count/settings/history listing.
Keep page identities stable, dispose no workspace on route exit.

UI terminal/settings whitelist: `lib/features/terminal/terminal_view.dart`,
local new widgets under `lib/features/terminal/widgets/`,
`lib/features/settings/settings_view.dart`, `lib/features/shell/main_shell.dart`,
`lib/l10n/*.arb`. No generated files/tests/core edits by AgY.

Stable operation codes: `TERMINAL_HISTORY_LOAD_FAILED`,
`TERMINAL_HISTORY_SAVE_FAILED`, `TERMINAL_HISTORY_REFRESH_FAILED`,
`TERMINAL_START_FAILED`, `TERMINAL_RESTORE_FAILED`,
`TERMINAL_DEFAULT_SAVE_FAILED`, `TERMINAL_COMMAND_FAILED`,
`TERMINAL_TITLE_INVALID`, `SSH_DISCONNECTED`.
Notices: `TERMINAL_DEFAULT_MISSING`, `TERMINAL_SESSION_MISSING`,
`TERMINAL_PLAIN_INTERRUPTED`. Use localized labels, not raw code/English from
infrastructure. Existing `bridge.plainSessionInterrupted` is also available.

Drawer max360dp/85%, history only currenttarget, mostwidth title +moremenu.
Startup picker accessible both in history and Settings' terminal group; choice
is local pertarget. Unknown offline records are not labeled ended. Legacy rows
can explicitly restore/rename/setdefault (which importsmetadata). Plain/Mosh
records not offered as persistent defaults. Emptyhistory explains tmux opt-in.
Rename title1–64graphemes, validate with model helper, no focusresurrection.
17 ARB locales must remain structurally complete.

## Bridge / tests (OpenCode)

`TerminalSessionIntent { createFresh, restoreExisting }` defaults createFresh;
optional `tmuxSessionName` only on restore. Getter `activeTmuxSessionName` only
for successfully active tmux, `lastError`, `remoteSessionMissing`,
`plainSessionInterrupted`. Static `discoverTmuxSessions(client, serverId: ...)`
and `tmuxSessionExists(client, name)` issue bounded isolated non-PTY SSH queries.
Missing is distinguished from query failure; no failure-as-empty list.

Planner `createCommand`, `attachCommand`, `hasSessionCommand` replace old
`attachOrCreateCommand`. Create has NO `-A`; attach uses exact `=name` and no `-d`.
Existing unit fake servers need exitstatus and non-PTY detect/has/list responses,
not only PTY open mocks. Background exec uses LC_ALL=C for diagnostic matching.
Fake return setup must match actual command, not call a real production server.

Author focused tests for planner/bridge/new model/storage/provider and adjust
terminal UI fakes for lazy startup. Include unavailable vs gone, newcountreuse,
double restore while awaits, defaultpending+plus, readprovideropensnothing,
persistfailure/titlevalidation, targetswitchlatecallbacks, old legacy explicit
only, disabled tmux/plain/Mosh, nameswithcommonprefix, failedcreatecannotattachold.
Preserve existing app operations/login/Docker/CLI callers and regression tests.
