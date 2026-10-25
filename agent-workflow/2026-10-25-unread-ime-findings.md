> Resolved in final-ready verification: 115 regular tests passed, including unread/prepend, exact latest scroll, RTL/IME and localization parity. Historical diagnostics below describe intermediate work, not outstanding defects. See `2026-10-26-final-ready-findings.md`.

# Unread Badge / RTL IME Findings - 2026-10-25

## Scope

Finalized the two recently appended tests in
`test/features/ssh_acp_interaction_test.dart`:

- `ACP unread badge while scrolled up`
- `ACP permission detail RTL with IME`

No production code was edited. Existing first five tests were left unchanged.

## Commands and Results

Run from `/workspace/projects/valhalla`:

`flutter test --no-pub test/features/ssh_acp_interaction_test.dart`

Real output: `build/ssh-acp-validation/unread-rtl-ime.log`

Observed summary: 6 passed, 1 failed, exit code 1.

Passing tests:

- ACP pending permission presentation
- ACP running session overlay
- ACP session deletion safety (2 tests)
- ACP server busy send rejection
- ACP permission detail RTL with IME

Failing test:

- `ACP unread badge while scrolled up`
- Assertion: `test/features/ssh_acp_interaction_test.dart:631`
- Expected: exactly one widget with type `Badge` descending from
  `chat_scroll_to_latest_button`
- Actual: 0 widgets

## Root Cause

`AiChatView.build` registers `ref.listen<AiChatState>(aiChatProvider, ...)` at
`lib/features/chat/ai_chat_view.dart:1209`. The listener mutates
`_unreadMessageCount` when a new tail message arrives while the user is scrolled
up (`lib/features/chat/ai_chat_view.dart:1288-1298`), but it never calls
`setState`. The `FloatingActionButton` child is selected from
`_unreadMessageCount` at render time (`lib/features/chat/ai_chat_view.dart:1534`),
so the badge does not repaint after the append. This is why the test cannot
observe `Badge` even though the unread counter logic runs.

## Fix Not Applied

Production was intentionally not edited. To make the badge repaint, the listener's
mutation of `_unreadMessageCount` (and `_userNearBottom` where applicable) must
be wrapped in `setState`, or the state change must otherwise mark the widget
dirty. The failing assertion was not weakened.
