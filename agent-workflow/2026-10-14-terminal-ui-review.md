# Phase B follow-up — AgY only

Root generated localization and ran analysis. Fix UI only; root owns tests and
verification. No build/install/push or core changes. Full analyzer evidence:
`/tmp/valhalla-20261014-analyze-phase-b.log`.

- settings_view: terminalState declared in build but used in a different helper
  scope (line842). Watch/read it in the helper that renders its row.
- drawer: remove redundant/wrong relative model import; provider exports model.
  Import design/tokens.dart for vSuccess/vWarning; remove unused l10n import.
  Use RadioGroup instead of deprecated groupValue/onChanged. Use (_, _) callback.
- Rename dialogs need state-owned controllers (dispose only when dialog widget
  unmounts), mounted checks after awaits, busy guards, and distinct validation
  versus persistence errors. Current showDialog().then(controller.dispose)
  is too early for exiting route animation. Reuse one bounded dialog for tab
  and history rename rather than copy/paste forms.
- Startup dialog and drawer menu setDefaultHistory can throw. Catch errors,
  show localized persistence failure, preserve selection, prevent duplicate
  submits. Snapshot targetFor(activeServer) on opening every async selector;
  refuse actions after target changes, including clear default(null) which
  otherwise clears the NEW server's default. Don't call stale WidgetRef.
- Restore row/menu disabled for ended sessions. isLegacy means unimported remote
  record (also new UUID orphan); badge should say remote/not-imported, not old.
- terminal_view activeServer listener compares only id; compare targetFor so
  same-server host/port/user edits initialize the new target workspace.
- New inner Scaffold history drawer must retain explicit-keyboard behavior:
  unfocus on open/close and dialog return, don't automatically show IME.
- Empty terminal must not spin forever when offline/start failed. Spinner only
  while initialization is active; localized disconnected/failed state and retry
  should preserve cached terminals. Never create fresh session in error UI.
- First fresh tmux connection currently triggers the restored banner too.
  Show restored only for restore intent or reconnect after previously connected.
- Custom tab titles can be64 characters: bound chip label width, ellipsis and
  full tooltip/semantics, so one title cannot hide the whole tab strip.

All code that touches providers after a dialog await checks mounted AND target.
Keep precise restore/new semantics in core; no duplicating remote checks in UI.
