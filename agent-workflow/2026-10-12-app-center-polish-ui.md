# AgY UI handoff

Read sibling app-center-polish.md completely for design/acceptance/ownership.
Use ONLY original Valhalla/modelhigh/efforthigh. No tests, format, generation,
Flutter/build/ADB, business/native changes, unrelated UI or dependencies.
Whitelist: lib/features/app_center/** and lib/l10n/*.arb. Root handles providers;
OpenCode will generate ARBs and test. Preserve unrelated edits and stable APIs.

Implement the observed gaps with current contracts. In particular:
- Keep Store/Installed/Tasks searchable/browsable and visible during refresh;
  useful real environment strip, sourceErrors localized with retry, no-source /
  no-results distinction. Keep tab/scroll/search state. Mobile details fullscreen.
- Wire simple optional callbacks/results between existing view/tabs/details/
  wizard to reach Tasks or Installed after submission/completion. Do not create
  a new global workflow framework. Closing a running wizard never cancels it.
  After success allow opening actual reconciled deployment (not provisional).
- Use current live task.canCancel, not original _runningTask, and catch/translate
  every cancel Future; disable repeated/offline requests. Explain needsInspection
  as unknown outcome, expose read-only recheck; never restart the operation.
- Task detail dialog/sheet: all already-bounded logTail selectable/copyable,
  localized stage/operation/exit code, safe cancellation, recheck when unknown.
  No claim of percent progress; stages reflect actual worker state.
- Installed card: localized deployment/service health, actual version/source,
  compact primary Open/action row, safe overflow menu disabled offline/busy/unknown
  task. Confirm stop/restart with app+server identity; uninstall/restore retain
  existing confirmations. No data deletion. Show ongoing state; avoid fixed
  height clipping with many services/long names/2x fonts/RTL on desktop or mobile.
- Empty installed offers Store navigation; empty Tasks offers useful next action.
- All new labels in17ARB files; no new hardcoded English statuses/enum names.
  Existing semantic colors/fonts/tokens; no new icon art/dependencies/hero.

Audit async mounted AND captured connectionKey after awaited actions/dialogs;
dispose text controllers; do not leave spinners permanently busy after switching
server. Existing provider methods remain callable; root may add no new UI API.
Return authored files, callback/key contracts for OpenCode, and any core gaps.
