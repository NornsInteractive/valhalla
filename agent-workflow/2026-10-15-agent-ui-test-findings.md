# Agent compact UI verification findings

Only the new `test/features/agent_compact_ui_test.dart` was added for these
reproducers; no product edits. The test uses in-memory server/registry state
and does not launch login, Agent, SSH, or install operations.

Command: `flutter test --no-pub test/features/agent_compact_ui_test.dart --reporter expanded`

## Current status — both defects resolved; final software checks passed

The combined original Agent suite plus compact regressions completed
**30/30 passing** after the UI fixes:
`/tmp/valhalla-core-experience.ACZJNb/direct-agent-postfix.log`.
This clears both the narrow English/Arabic app-bar overflow and reduced-motion
details-expansion assertion documented below. The original failures and source
line numbers remain as a pre-fix audit trail.

Final integration status: **3685 passed, 30 skipped**, with zero analysis
issues. The formal 1.0.6+7 APK was built locally and installed through a
data-preserving ADB replacement. Detailed device checks remain in progress;
the focused widget results above do not constitute device acceptance.
See the [implementation record](2026-10-15-core-experience.md) for final evidence.
This documentation update neither reran tests nor changed code.

## Initial failing run (pre-fix audit)

Initial result: 0 passed, 3 failed (two independent product defects).
Detailed diagnostic log:
`/tmp/valhalla-core-experience.ACZJNb/codex-agent-compact-diagnostics.log`.

1. **Resolved: App bar overflow at 320dp / 2× text in English and Arabic.**
   Renderer identifies `lib/features/agents/agent_management_view.dart:335`
   (`AppBar`); its action Row at `:354–369` overflows 33px in English and 61px
   in Arabic. This happens before expanding a card. The unconstrained full
   Add Agent label plus refresh action exceed the available width.
   Use a responsive constrained action or icon with localized tooltip at
   narrow widths, preserving both actions and ≥44dp touch targets; ensure
   the title / server summary remains constrained too.

2. **Resolved: Expanding details with reduced motion threw during layout.**
   `agent_management_view.dart:660–663,795–801` selects Duration.zero for
   AnimatedCrossFade. Tapping the expand button at 400×800 / scale 1 with
   `MediaQuery.disableAnimations = true` raises:
   `A RenderAnimatedSize was mutated in its own performLayout implementation`.
   The stack points to RenderAnimatedSize restarting its zero-duration
   animation while laying out the newly expanded child. Render the chosen
   details child directly when reduced motion is enabled; retain the normal
   crossfade only for animated mode. Do not force motion on to avoid the error.

The fixture confirms existing CLI login, ACP login, edit, expand, and diagnostic
callbacks remain present; it opens the exact diagnostic text without running
Agent actions. Both refresh and delete callbacks are retained by source review.
Terminal source review confirms real `bridge.mode` (not preferTmux), explicit
Mosh labeling, open-tab identity grouping, most-recent-first ordering, unknown
offline status, and retained rename/default/delete menu actions. Existing
history search/group tests passed during that review. A subsequent terminal
history run completed **18/18 passing**, including 320dp / 2× / Arabic RTL
grouped search, actual plain mode despite a tmux preference, and dismissal
without reopening the terminal keyboard:
`/tmp/valhalla-core-experience.ACZJNb/codex-terminal-history-rtl.log`.

## Existing Agent suite adaptation

`test/features/agent_management_test.dart` now checks the visible default Docker
target and expands details before opening diagnostic buttons. Disabled-state,
exact raw text, monospace font, clipboard payload, copy feedback, and close
assertions are retained. Its focused run completed **27/27 passed**, exit 0:
`/tmp/valhalla-core-experience.ACZJNb/codex-agent-management-focused.log`.
That interim 27-test run did not clear the separate compact failures; the
later combined **30/30** post-fix result above does. Counts are successive run
totals and must not be added as unique tests.
