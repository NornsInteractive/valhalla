# OpenCode six-service logs UI tests — fixture correctness (2026-10-11)

Owned files: `test/features/six_service_logs_ui_test.dart` only (fixture corrections) + this report.
Model: opencode/step-5-preview-free, main + small config, inline (no subagents, no paid).
No production UI/core/ARB/pubspec/other tests/build/ADB/git changes. No UI bug found, so no UI change
or assertion weakening was needed.

## Baseline (actual run, not inherited)

Interrupted prior log (130 lines) was distinct and NOT reused; baseline re-run here:

    set -o pipefail; flutter test --no-pub test/features/six_service_logs_ui_test.dart --reporter expanded > /tmp/opencode/baseline.log 2>&1; echo EXIT=$?
    EXIT=1

- `initial 200 logs stay gated and duplicate callbacks cannot overlap` — FAIL
- `older failure keeps the initial rows and offers a localized retry` — FAIL
- `320dp 2x text scale and RTL lay the logs dialog out cleanly` — PASS

Both failures: `Bad state: No element` from `scrollUntilVisible` at `_revealLoadOlder`
(`WidgetController.element` on the never-revealed load-older label).

## Root causes and fixture-only fixes (all in the owned test file)

1. `_revealLoadOlder` passed delta `-120`. `scrollUntilVisible` maps positive delta to later
   rows for `AxisDirection.down` (`moveStep = Offset(0, -delta)`), and the load-older footer is
   the last list item, so the footer was never reached and the 120 bounded drags were exhausted
   in the wrong direction. Delta set to `300` (positive, later rows).
2. `_dialogListScrollable` previously did not explicitly scope its matches to the
   log `ListView`. The identity of its old first match was not independently
   established; wrong-direction scrolling alone explains the baseline failure. Now the
   finder scopes to the log `ListView` and keeps the vertical predicate
   (`w is Scrollable && w.axisDirection == AxisDirection.down`), taking `.first`: each
   `SelectableText` row embeds its own vertical `EditableText` `Scrollable`, and the ListView's
   own Scrollable is their ancestor, so it is first in DFS order.
3. `message-0` (earliest row) scroll in the retry test reversed to `-300` (earlier rows);
   `maxScrolls: 120` kept.
4. 320dp test: dropped the TabController mutation workaround; `_openLogs` now does real
   interaction — `tester.ensureVisible(servicesTab)` (jump) + `pump` + tap on the Services tab
   (the TabBar is horizontally scrollable at mobile width, so the tab needs revealing first),
   then the logs-icon tap. No `warnIfMissed: false`, no keyboard commands.
5. DIAG print probes removed: the `DIAG dialogs=…` debugPrint in `_revealLoadOlder` and the
   `SERVICE_320_CREATOR` dump loop. The error hook still forwards to the previous handler
   (`previousOnError?.call(details)`) plus `dumpErrorToConsole(forceReport: true)` — nothing is
   suppressed; `expect(tester.takeException(), isNull)` retained.

## Preserved (no assertion or product behavior weakened)

All existing assertions untouched: gated first page, disabled refresh while gated, non-overlapping
duplicate callbacks, `c199` older cursor, queued three-record older page starting
at message number1000 (not a1000-record page; cap stress is not proved here),
localized query error without raw `SERVICE_QUERY_FAILED`, retry `TextButton` via
`widgetWithText`, retained `message-0`, Arabic 320dp @2x RTL title/direction/message checks.
`_olderButton` keeps the widget predicate `widget is TextButton` because `TextButton.icon` builds
the runtime subclass; captured callbacks asserted non-null after capture.

## Final verification (exact commands and exits)

    dart format test/features/six_service_logs_ui_test.dart
    → Formatted 1 file (1 changed)

    flutter analyze --no-pub test/features/six_service_logs_ui_test.dart
    → No issues found! (ran in 1.1s)

    set -o pipefail; flutter test --no-pub test/features/six_service_logs_ui_test.dart --reporter expanded > agent-workflow/2026-10-11-six-service-ui-tests.log 2>&1; echo EXIT=$?
    EXIT=0
    00:02 +3: All tests passed!

Full unfiltered run log: `agent-workflow/2026-10-11-six-service-ui-tests.log` (5 lines, no
warnings). The production header fix by the AgY creator (service card header `Wrap` at
`lib/features/system/system_view.dart:656`) is complete and stable; no production/UI change was
required to turn these tests green.
