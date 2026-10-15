# Remote file toolbar preference API — 2026-10-15

## Core implementation

`lib/data/models/remote_file_toolbar_action.dart` defines
`RemoteFileToolbarAction` in stable display order:
`upload`, `create`, `view`, `transfers`, `hidden`, `sort`, `selection`,
`bookmarks`, `refresh`.

- `defaultRemoteFileToolbarActions` pins the first four actions.
- `remoteFileToolbarActionsFromStorage(List<String>? raw)` returns that default
  only for a missing value. An explicit empty list means all actions go in More.
  Unknown names and duplicates are removed; recognized actions use enum order.
  The returned list is immutable.
- `SettingsState.remoteFileToolbarActions` contains the pinned actions.
- `SettingsNotifier.setRemoteFileToolbarActions(Iterable<RemoteFileToolbarAction>)`
  normalizes the selection, persists it, then changes only that state field.
  Failed persistence leaves the provider state unchanged. Settings exports the
  model, so callers can import `settings_provider.dart` alone.
- `LocalStorageService.getRemoteFileToolbarActions()` returns the nullable raw
  string list. `setRemoteFileToolbarActions(List<String>)` normalizes it and
  checks the platform write result. Failed writes reload the optimistic
  SharedPreferences cache and throw `SFTP_TOOLBAR_PREFERENCE_SAVE_FAILED` when
  the platform returns false.
- Storage key: `valhalla_remote_file_toolbar_actions_v1`. It is a global setting,
  included in the existing configuration preference import/export allowlist.
- `resetDefaults()` persists the toolbar default before publishing the reset
  state. If that toolbar write fails, the reset does not change in-memory state.
  Other settings retain their existing reset behavior.

## AgY UI contract

- Watch `settingsProvider.select((state) => state.remoteFileToolbarActions)` in
  the remote file management page, then pass the selection into the controlled
  shared toolbar. Do not apply this preference to read-only pickers.
- Keep a local draft in the configuration dialog; Save calls the notifier and
  closes only on success, Cancel changes nothing, Restore default changes the
  draft to `defaultRemoteFileToolbarActions`.
- Fixed and More entries must share callbacks and disabled state. Keep More and
  its customization entry reachable even with no fixed actions. No ordering UI
  is required: display order is the enum order.
- Storage and provider code does not create a dialog, toolbar widget or strings.
  Production UI/ARB work remains exclusively assigned to AgY.

## OpenCode validation handoff

No tests, formatters, analysis, build or ADB operations were run by this worker.
Required regression coverage:

1. Missing preference gives the four defaults; explicit `[]` stays empty through
   provider recreation and configuration export/import.
2. Unknown and duplicate names are ignored; reverse input order normalizes to
   enum order; results cannot be mutated.
3. Saving updates only toolbar state, preserves unrelated settings, survives
   provider recreation, and stores stable names rather than indexes.
4. Platform false/throw preserves prior provider state and reloads the cached
   preference; subsequent provider creation does not read an uncommitted value.
5. Reset restores the four defaults; a failed toolbar reset write leaves the
   prior state intact. Existing reset and configuration backup tests still pass.
6. UI: each action appears only fixed or in More, all-nine/no-fixed cases remain
   usable on narrow screens, and picker behavior is unchanged. Disabled state,
   action callbacks, transfer badges, RTL, large text and dialog Save/Cancel are
   preserved.
