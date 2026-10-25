> Resolved in final-ready verification: 115 regular tests passed, including unread/prepend, exact latest scroll, RTL/IME and localization parity. Historical diagnostics below describe intermediate work, not outstanding defects. See `2026-10-26-final-ready-findings.md`.

# SSH + ACP UI Test Findings - 2026-10-25

## Scope

Test/verification ownership only. Added `test/features/ssh_acp_interaction_test.dart` and did not edit `lib/features/chat/ai_chat_view.dart`, ARB files, or other production code. No SSH, ADB, git, build, or publication commands were run.

`ai_chat_view.dart` now compiles after the AgY fix; the new test and both existing widget harnesses load and run.

## New Test File

`test/features/ssh_acp_interaction_test.dart` reuses `test/support/acp_chat_widget_harness.dart` and only overrides the `AiChatNotifier` boundary for widget behavior.

| Test | Result |
|------|--------|
| Long permission at 320px + textScale 2: compact summary, bounded details, copy and fixed actions | FAIL (production UI bug) |
| Running-session indicator overlays without moving transcript viewport | FAIL (production UI bug) |
| Delete defaults local-only; runtime inspection error remains locally deletable | PASS |
| Selected remote purge failure keeps delete dialog open | PASS |
| `ACP_RUNTIME_SERVER_BUSY` rejection restores typed draft | PASS |

Summary: `+3 -2: Some tests failed`.

## Finding 1 - Permission details overflow at 320px / textScale 2

Evidence: `build/ssh-acp-validation/new-test-final2.log`

- The compact permission summary itself is correct: the summary `Text` is `maxLines: 2` with `TextOverflow.ellipsis`, and the full command is not rendered in the compact card.
- The details sheet is correctly bounded: `ConstrainedBox(maxWidth: 640, maxHeight: 512)` for a 640px-high screen, and the fixed action button stays inside the viewport.
- The details content row overflows horizontally:
  - `A RenderFlex overflowed by 225 pixels on the right.`
  - Widget: `lib/features/chat/ai_chat_view.dart:3376` (`Row` containing "Command to Execute" and the "Copy Command" `TextButton.icon`).
  - The copy action's right edge is `529.42`, beyond the 320px viewport, so it is unreachable at this width/text scale.
- The test stops at the copy-action reachability assertion; the clipboard/snackbar assertion is not reached.

Suggested production fix (owner): let the command label flex/shrink or switch that header row to a `Wrap`/vertical layout so the copy action stays within the sheet width.

## Finding 2 - Running-session banner resizes the transcript viewport

Evidence: `build/ssh-acp-validation/new-test-final2.log`

- Before the banner: transcript `ListView` rect `Rect.fromLTRB(195.0, 49.0, 195.0, 654.0)` (zero width).
- After emitting a busy `serverRun` for another session: `Rect.fromLTRB(0.0, 49.0, 390.0, 654.0)` (full width).
- Cause: the `Stack` at `lib/features/chat/ai_chat_view.dart:1461` has only positioned children plus the banner `Consumer`, which returns a non-positioned `SizedBox.shrink()` when no banner is shown. The parent `Column` uses its default `crossAxisAlignment: center`, so the `Stack` shrink-wraps to the zero-width placeholder. When the banner becomes a `Positioned` child, the `Stack` falls back to the maximum width.
- The test asserts the entire transcript rect, so it fails on the width change. The scroll offset comparison is not reached.
- This also means the transcript viewport is zero-width whenever the fallback placeholder is the only non-positioned child.

Suggested production fix (owner): make the transcript `Stack` fill its width (for example `SizedBox.expand`, a stretched parent, or `width: double.infinity`), and/or render the banner placeholder as `Positioned.fill`/keep a full-size non-positioned child.

## Existing Harness Reruns

### `test/features/ai_chat_initial_scroll_test.dart`

`+7: All tests passed` (`build/ssh-acp-validation/ai_chat_initial_scroll_test.log`).

### `test/features/ai_chat_session_isolation_test.dart`

`+5 -1: Some tests failed` (`build/ssh-acp-validation/ai_chat_session_isolation_test.log`).

Failing test: `shows stop button and clicking invokes stopGeneration when isGenerating` at `test/features/ai_chat_session_isolation_test.dart:179`.

- Expected `stopGenerationCalled == true`, actual `false`.
- The UI stop handler now prefers `stopViewingRun(expectedServerKey, expectedSessionId)` when a server key and session id exist (`ai_chat_view.dart` stop-button branch), while the test's mock only overrides `stopGeneration`.
- This is test/UI contract drift in the existing test, not a failure of the new test file. Reported for the owner of that test; no production or test edits were made outside the new file.

## Static Checks

- `dart format test/features/ssh_acp_interaction_test.dart` - exit 0.
- `flutter analyze --no-pub test/features/ssh_acp_interaction_test.dart` - exit 0, no issues.

## Command Evidence

All commands run from `/workspace/projects/valhalla` with explicit exit capture, no `head`/`tail`/`tee` masking:

| Command | Exit |
|---------|------|
| `flutter test test/features/ssh_acp_interaction_test.dart` | 1 (`+3 -2`) |
| `flutter test test/features/ai_chat_initial_scroll_test.dart` | 0 (`+7` all passed) |
| `flutter test test/features/ai_chat_session_isolation_test.dart` | 1 (`+5 -1`) |
| `flutter analyze --no-pub test/features/ssh_acp_interaction_test.dart` | 0 |

Artifacts:

- `build/ssh-acp-validation/new-test-final2.log`
- `build/ssh-acp-validation/ai_chat_initial_scroll_test.log`
- `build/ssh-acp-validation/ai_chat_session_isolation_test.log`
- `build/ssh-acp-validation/analyze-new-test.log`
- `build/ssh-acp-validation/debug-overlay2.log` (render-tree evidence for Finding 2)

## Next Steps

1. UI owner fixes the permission-details header overflow and the transcript `Stack` width behavior.
2. Re-run `test/features/ssh_acp_interaction_test.dart`; the three passing regression cases must remain green.
3. Session-isolation owner decides whether the stop-button test should observe `stopViewingRun` or whether the UI contract should change.
