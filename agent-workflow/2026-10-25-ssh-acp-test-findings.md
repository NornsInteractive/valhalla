# SSH + ACP Test Findings - 2026-10-25

## Scope

This pass replaced the previously appended `ACP Session Isolation Regressions`
tests with behavior tests that exercise the real provider seams and existing
fixtures:

- `test/core/acp_durable_recovery_test.dart`
- `test/core/terminal_history_provider_test.dart`
- `test/features/ai_chat_session_isolation_test.dart`
- this findings file

No production code was edited in this pass. The working tree already contains
unrelated production changes from other owners.

## Commands and Results

All commands were run from `/workspace/projects/valhalla` and reported their real
unpiped exit status.

| Command | Observed result | Exit |
|---|---|---|
| `dart format test/core/acp_durable_recovery_test.dart test/core/terminal_history_provider_test.dart test/features/ai_chat_session_isolation_test.dart` | 3 files formatted | 0 |
| `flutter test test/core/acp_durable_recovery_test.dart` | `+13`, all tests passed | 0 |
| `flutter test test/core/terminal_history_provider_test.dart` | `+48`, all tests passed | 0 |
| `flutter test test/features/ai_chat_session_isolation_test.dart` | `+5 -1`, one failure at line 179 | 1 |

No full-suite, infrastructure-suite, data-suite, or core-suite run is claimed.

## Behavior Coverage Added

### `test/core/acp_durable_recovery_test.dart`

The new `ACP session isolation behavior` group covers:

1. Hidden run output is persisted after switching Agent.
   - Holds the prompt open, switches Agent, delivers an assistant chunk, and
     verifies the repository contains `hidden answer`.
2. Same-server send is blocked before a draft or session is created.
   - Verifies `ACP_RUNTIME_SERVER_BUSY`, unchanged active session/draft/session
     list, unchanged exported repository rows, no second prompt, and no
     `must-not-be-sent` payload on any fake transport.
3. Failed remote purge retains local history.
   - Forces the manager purge to throw and verifies the local session remains in
     state and the repository.
4. Local delete cancels nothing and cannot resurrect late output.
   - Verifies the record is deleted locally, no `session/cancel` is written, and
     late held output does not restore the deleted session.
5. Expired runtime rotates generation and resumes the same remote session.
   - First open throws `AcpRuntimeUnavailableException`; retry opens one
     persistent transport, performs exactly one `session/load` or
     `session/resume` for the same remote id, never sends `session/new`, sends
     exactly one prompt ending with `after expiry`, advances
     `runtimeGeneration` to `1`, clears `runtimeRestartPending`, and persists
     the new runtime key/cursor.
6. Stale permission completer or server target cannot respond.
   - Verifies a matching completer/target responds once; stale target, stale
     completer, and already-completed completer are rejected without completing
     or clearing the current permission.

Supporting fixture changes:

- `makeContainer` now supports `autoOpen`, `initialState`, `readyAgents`,
  `pairSink`, `configurePair`, `inspectorOverride`, `serverRunsOverride`, and
  `managerOverride`.
- `_MutableRegistry` accepts explicit `readyIds`.
- Existing managed-recovery tests now register `stopGeneration` teardown before
  `container.dispose`, so disposal no longer runs first and closes the transport
  while recovery is still stopping.

### `test/core/terminal_history_provider_test.dart`

Added `stable tab ids, target checks and last-tab retention govern close and
reconnect`:

- Stale target rejects `closeTabById`/`reconnectTab` with
  `TERMINAL_TARGET_CHANGED`.
- Unknown ids and stale reconnects leave tab order and buffers intact.
- Closing the middle tab keeps the remaining stable ids and selects the first.
- Closing the final tab is refused, preserving the last tab and terminal buffer.

## Remaining Failure

`flutter test test/features/ai_chat_session_isolation_test.dart` currently
fails only this pre-existing test body:

- Test: `AiChatView - Stop Generation Button shows stop button and clicking
  invokes stopGeneration when isGenerating`
- Assertion: `test/features/ai_chat_session_isolation_test.dart:179`
- Actual: `generatingChatNotifier.stopGenerationCalled` is `false` after tapping
  `stopGenerationButton`.

The failing assertion body was not changed by this pass; only the invalid
appended regression group and its now-unused imports were removed from that
file. No root cause is claimed without further investigation, and the UI test
was not modified to hide the failure.
