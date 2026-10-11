# Actual service UI layout regression

AgY original Valhalla / Gemini3.8Flash-high only. Production UI belongs you;
no tests/core/ARB changes, test execution, formatting, build/ADB/git/subagents.

OpenCode authored test/features/six_service_logs_ui_test.dart and ran it with
unfiltered evidence /tmp/opencode/six_service_logs_ui_test.log. Narrow case:
320 logical dp width, 568 height, 2x text scale, Arabic RTL, one app.service,
two bounded log messages. Initial SystemView -> services tab -> logs dialog.
Actual error: `A RenderFlex overflowed by 89 pixels on the right.` Assert at
test294 expects tester.takeException() null. This is a real layout regression,
not permission to reduce text scale/width or suppress exceptions.

Identify the exact SystemView/service card/log dialog row responsible and make
the smallest responsive correction using existing Wrap/Flexible/scrollable
tabs/layout patterns. Keep all action buttons, busy guards, timestamps/priority,
cursor paging, no-data handling, target confirmation and existing styles. No
manual data loss/automatic mutating actions. Header and dialog title must remain
usable at 320dp/2x/RTL, desktop unchanged. Read the local test fixture if needed;
OpenCode will supply full creator diagnostic if this first log is insufficient.

Two other new-test failures need fixture corrections, NOT UI changes: Icon
cast as IconButton and one huge drag that does not reliably materialize the
lazy list's load-older footer. Production footer is TextButton.icon. OpenCode
should use bounded scrollUntilVisible/drag-until-visible and the actual parent
IconButton finder; don't modify production to satisfy incorrect interactions.

Only lib/features/system/system_view.dart + your six-ui-handoff.md report.
Report actual touched layout, do not claim tested. OpenCode reruns afterward.

07:49 UTC AgY finished: mobile TabBar uses isScrollable and TabAlignment.start,
desktop remains fill. Actual subsequent /tmp/opencode/service_320_creator.log
does NOT report RenderFlex overflow: test attempts to tap the now-scrollable
second RTL tab while its text center is off-screen at x=-143.1. Fixture must
ensureVisible/scroll the Services tab BEFORE tap. Don't turn a missing scroll
interaction into a new product-layout claim. Also scrollUntilVisible uses a
positive vertical delta to reveal later rows; preserve bounded maxScrolls and
do not silence hit-test warnings. OpenCode owns these interaction corrections.

07:51 UTC fuller creator diagnostic AFTER scrolling the second tab now proves
the actual original 89px overflow is service-card header Row at system_view.dart
656, constraints maxWidth264, non-flex startup/status badges exceed that. See
/tmp/opencode/service_320_creator.log lines65-96. Earlier exact TabBar89px
attribution was a GUESS, invalidated by this actual creator, and must be corrected
in your report rather than counted as proof. Keep useful mobile scrollable tabs,
but fix THE CARD header responsively: name readable and badges wrap when width/
text scale requires; retain all badges, actions, semantics, no font reduction,
desktop presentation unchanged. Only system_view.dart + six-ui-handoff report.
No tests/core/ARB/commands/generation/format/build/ADB/git. Original conversation
and modelhigh. OpenCode will rerun all3 unchanged safety/layout assertions.
