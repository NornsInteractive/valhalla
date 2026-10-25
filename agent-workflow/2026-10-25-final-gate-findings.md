> Superseded by final-ready proof: 115 regular tests passed, zero failures; generation, formatting and analysis exit 0. See `2026-10-26-final-ready-findings.md`. Historical failed attempts below are retained for traceability.

# 2026-10-25 Final Gate Findings

## Flutter Tests

### Test Suite: `flutter test --no-pub --machine test/core/acp_durable_recovery_test.dart test/core/terminal_history_provider_test.dart test/core/agent_update_provider_test.dart test/features/ai_chat_session_isolation_test.dart test/features/ai_chat_initial_scroll_test.dart test/features/ssh_acp_interaction_test.dart test/data/acp_runtime_generation_test.dart`

**Exit code:** 1 (failed)
**Raw testDone count:** 113
**Hidden suite-loading pseudo-tests:** 7
**Regular tests:** 106
**Passed:** 105
**Failed:** 1
**Skipped:** 0

Failed test:
- `test/features/ssh_acp_interaction_test.dart`: `ACP unread badge while scrolled up` -> `prepend older messages does not show badge; append new tail message shows badge count 1; jump-to-latest clears badge and reaches bottom`
- Assertion at line 652: expected controller.offset within 1.0 of maxScrollExtent (2664.0), actual 2641.6 (22.4 short).

Fixture now valid (initial messageOffset 20/total 50; prepend to offset 10 keeps absolute end 50). Badge count 1 assertion passes. Remaining failure is the jump-to-bottom assertion: `_scrollToBottom` animates to the maxScrollExtent captured at tap time (2641.6), but the newly appended tail message is lazily laid out during the scroll, increasing maxScrollExtent to 2664.0 after the animation target was fixed. The button is hidden correctly; exact-bottom assertion cannot pass without changing scroll implementation or test expectations. No production edit made.

## Flutter Analyze

### `flutter analyze --no-pub`

**Exit code:** 0
**Issues found:** 0 (No issues found!)

## L10n Generation

### `flutter gen-l10n`

**Exit code:** 0 (from prior run in this sequence)

## Formatting

### `dart format` (specified production files plus changed test files)

**Exit code:** 0

## Python Unit Tests

Not rerun (Broker34 already passes unchanged).

## Summary

Analyze passes with 0 issues. Full 7-file suite not rerun after fixture change; focused ssh_acp_interaction_test.dart fails 1/6 (jump-to-bottom exact assertion). Badge count 1 passes. Previous UI/unread reports are NOT superseded because the jump-to-bottom assertion has not passed.
