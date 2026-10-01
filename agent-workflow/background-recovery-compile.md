# Background Recovery - Compile / Analyze Gate

Date: 2026-09-30
Workspace: /workspace/projects/valhalla
Model: space-bunny-free
Scope: round 1 ran `flutter gen-l10n` + `flutter analyze --no-pub`. Round 2 added the
focused protocol/data regression suite. Round 3 added focused widget coverage in
`test/features/background_recovery_ui_test.dart`. No production/UI or other-test edits,
no build, no network/SSH, no Agent prompts.

> Round 1 output is preserved verbatim below. For the current state see
> "Round 3 - focused widget coverage" at the end of this file.

## Command 1

```
$ flutter gen-l10n
```

Output (verbatim):

```
Because l10n.yaml exists, the options defined there will be used instead.
To use the command line arguments, delete the l10n.yaml file in the Flutter project.

```

Actual exit code: **0**

Generated/updated l10n files (per `git status --short -- lib/l10n`):

```
 M lib/l10n/app_en.arb
 M lib/l10n/app_localizations.dart
 M lib/l10n/app_localizations_en.dart
 M lib/l10n/app_localizations_zh.dart
 M lib/l10n/app_zh.arb
```

## Command 2

```
$ flutter analyze --no-pub
```

Output (verbatim):

```
Analyzing valhalla...

   info - Statements in an if should be enclosed in a block - lib/core/providers/ai_chat_provider.dart:1654:31 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block - lib/core/providers/ai_chat_provider.dart:1972:51 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block - lib/core/providers/ai_chat_provider.dart:2004:61 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block - lib/core/providers/ai_chat_provider.dart:2017:79 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block - lib/core/providers/ai_chat_provider.dart:2035:39 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block - lib/core/providers/ai_chat_provider.dart:2073:22 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block - lib/core/providers/ai_chat_provider.dart:2219:64 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block - lib/core/providers/cli_chat_provider.dart:282:77 - curly_braces_in_flow_control_structures
   info - Statements in an if should be enclosed in a block - lib/core/providers/sftp_provider.dart:431:29 - curly_braces_in_flow_control_structures
   info - The import of '../../data/models/session_recovery_status.dart' is unnecessary because all of the used elements are also provided by the import of '../../core/providers/ai_chat_provider.dart' - lib/features/chat/ai_chat_view.dart:29:8 - unnecessary_import
   info - The import of '../../data/models/session_recovery_status.dart' is unnecessary because all of the used elements are also provided by the import of '../../core/providers/cli_chat_provider.dart' - lib/features/chat/cli_chat_view.dart:23:8 - unnecessary_import
warning - Unused import: '../../../l10n/app_localizations.dart' - lib/features/chat/widgets/session_recovery_banner.dart:10:8 - unused_import
   info - Unnecessary use of multiple underscores - test/core/background_recovery_lifecycle_test.dart:480:13 - unnecessary_underscores
  error - '_MockAiChatNotifier.stopGeneration' ('Future<void> Function()') isn't a valid override of 'AiChatNotifier.stopGeneration' ('Future<void> Function({bool cancelRemote})') - test/features/ai_chat_session_isolation_test.dart:556:16 - invalid_override

14 issues found. (ran in 1.8s)
```

Note: bullet separator above is transcribed as ` - `; the real output uses a wider separator and `•` bullets. Line order, severities, counts, and locations are exact.

Actual exit code: **1**

## Gate result

- `flutter gen-l10n`: PASS (exit 0)
- `flutter analyze --no-pub`: FAIL (exit 1)

## Blocking issue (1 error)

| Severity | File | Line | Rule | Message |
|---|---|---|---|---|
| error | test/features/ai_chat_session_isolation_test.dart | 556:16 | invalid_override | `_MockAiChatNotifier.stopGeneration` (`Future<void> Function()`) isn't a valid override of `AiChatNotifier.stopGeneration` (`Future<void> Function({bool cancelRemote})`) |

Production signature now takes a named optional `cancelRemote`; the test mock still declares the old zero-arg form. Test file is owned by another worker and was not edited here.

## Non-blocking issues (13)

- 1 warning: unused import `../../../l10n/app_localizations.dart` at `lib/features/chat/widgets/session_recovery_banner.dart:10:8`
- 12 info:
  - `curly_braces_in_flow_control_structures` x8: `lib/core/providers/ai_chat_provider.dart` (1654:31, 1972:51, 2004:61, 2017:79, 2035:39, 2073:22, 2219:64), `lib/core/providers/cli_chat_provider.dart:282:77`, `lib/core/providers/sftp_provider.dart:431:29`
  - `unnecessary_import` x2: `lib/features/chat/ai_chat_view.dart:29:8`, `lib/features/chat/cli_chat_view.dart:23:8` (both for `data/models/session_recovery_status.dart`, re-exported via the provider imports)
  - `unnecessary_underscores` x1: `test/core/background_recovery_lifecycle_test.dart:480:13`

## Not run in round 1 (out of scope for this gate)

- `flutter build` / assemble
- Network or SSH operations
- Real Agent prompts
- Any edit to production code or tests

---

# Round 2 - focused protocol/data regression

Owner: this worker (protocol + data only). Root had already fixed the core
`curly_braces` findings and restored the public zero-arg `stopGeneration()`;
AgY owns the chat UI warnings.

## Files added (tests only, no production/UI touched)

- `test/data/chat_recovery_merge_test.dart` (20 cases) - `ChatRepository.mergeReplayBatch`
- `test/infrastructure/acp_background_idle_test.dart` (5 cases) - `ACPClientAdapter.setInBackground`

Both reuse existing helpers: the temp-SQLite pattern from `test/data/chat_repository_test.dart`
(`ChatRepository(storage, databasePath: <temp dir>)`, unique dir per test) and
`FakeAcpPair` / `testAgentProfile` from `test/support/fake_acp_transport.dart`. No real
SSH, no real process, no network.

## Focused runs (reporter expanded, pipefail, full logs in /tmp)

```
$ set -o pipefail; flutter test test/data/chat_recovery_merge_test.dart --reporter expanded
00:20 +20: All tests passed!
EXIT=0
# log: /tmp/opencode/merge_test_run2.log

$ set -o pipefail; flutter test test/infrastructure/acp_background_idle_test.dart --reporter expanded
00:05 +5: All tests passed!
EXIT=0
# log: /tmp/opencode/bg_idle_test_run1.log  (3 extra consecutive runs also exit 0, timing stable)

$ set -o pipefail; flutter test test/data/chat_recovery_merge_test.dart test/infrastructure/acp_background_idle_test.dart --reporter expanded
00:25 +25: All tests passed!
EXIT=0
# log: /tmp/opencode/recovery_focused_final.log
```

### mergeReplayBatch cases (all pass)

| Group | Case |
|---|---|
| idempotence | identical batch twice -> zero byte-level row change |
| idempotence | batch replayed after an extension still keeps one row |
| local id stability | partial assistant text extends without moving id/createdAt |
| local id stability | ordinal fallback merges into the existing row, never a new one |
| tools/attachments | replay without tools/attachments keeps local ones |
| tools/attachments | replay unions its tools/attachments, replay wins per id |
| no erasure | shorter replay rejected, rows byte-identical |
| no erasure | divergent ordinal replay rejected, text survives |
| no erasure | replay may not straddle a local attachment with empty text |
| no erasure | longer replay under the same remote id corrects the text |
| no erasure | role flip rejected |
| no erasure | self-contradicting batch rolls back its earlier write (atomic) |
| no collapse | same text under two remote ids stays two messages |
| no collapse | two new same-text messages with distinct ids are both appended |
| identity | replay for another server refused (`CHAT_SESSION_IDENTITY_MISMATCH`) |
| identity | replay for an agent outside the session refused |
| identity | replay for an unknown session refused (`CHAT_SESSION_NOT_FOUND`) |
| shared agent | identical text from another agent never merges into this one |
| shared agent | a remote id owned by another agent never rewrites that row |
| shared agent | a shared session still merges each agent into its own message |

Rejections assert `StateError` message **and** that the persisted rows are
byte-identical before/after, so no assertion is weakened to make a run pass.

### adapter background/idle cases (all pass)

| Case | Asserts |
|---|---|
| turn started in background is never cancelled as idle | 4x timeout elapsed -> no `ACPErrorEvent`, no `ACPCompleteEvent`, 0 `session/cancel` on the wire, 1 `session/prompt` |
| already armed idle timer is suspended by going to background | foreground timer cancelled by `setInBackground(true)`, 3x timeout with no cancel |
| returning to foreground grants a fresh timeout | resume re-arms the watchdog (times out afterwards) and sends no extra `session/prompt` |
| foreground turn is cancelled as idle when the app stays awake | control case: same harness/timeouts still produce `ACP_IDLE_TIMEOUT` + exactly 1 `session/cancel`, proving the three cases above are not vacuous |
| background turn completes normally without any cancel | answered prompt finishes with `ACPCompleteEvent`, 0 `session/cancel`, adapter not disposed |

## `flutter analyze --no-pub` after the new tests

```
Analyzing valhalla...

   info - The import of '../../data/models/session_recovery_status.dart' is unnecessary ... - lib/features/chat/ai_chat_view.dart:29:8 - unnecessary_import
   info - The import of '../../data/models/session_recovery_status.dart' is unnecessary ... - lib/features/chat/cli_chat_view.dart:23:8 - unnecessary_import
   info - The import of '../../../data/models/session_recovery_status.dart' is unnecessary ... - lib/features/chat/widgets/remote_workspace_browser_dialog.dart:9:8 - unnecessary_import
warning - Unused import: '../../../l10n/app_localizations.dart' - lib/features/chat/widgets/session_recovery_banner.dart:9:8 - unused_import
  error - The getter 'items' isn't defined for the type 'SftpState' - lib/features/files/sftp_file_view.dart:758:52 - undefined_getter
   info - Unnecessary use of multiple underscores - test/core/background_recovery_lifecycle_test.dart:481:13 - unnecessary_underscores

6 issues found. (ran in 1.9s)
```

Actual exit code: **1** (log: `/tmp/opencode/analyze_final.log`)

**Both new test files are analyzer-clean** (the two findings the analyzer raised
on them - an unused `dart:convert` import and an `await` on a non-Future - were
fixed in the new tests before this run).

Delta vs round 1 (14 issues -> 6):

- Cleared by root: 8x `curly_braces_in_flow_control_structures`, and the
  `invalid_override` in `test/features/ai_chat_session_isolation_test.dart`
  (the zero-arg `stopGeneration()` API is restored).
- Cleared by this worker: 2 findings on the two new test files.
- Newly reported by other workers mid-flight (not mine, not edited here):
  `remote_workspace_browser_dialog.dart:9:8` unnecessary_import (AgY, UI);
  `background_recovery_lifecycle_test.dart:481:13` unnecessary_underscores
  (core-lifecycle test owner; was 480:13 in round 1).
- `session_recovery_banner.dart` unused import moved 10:8 -> 9:8 (AgY, UI).

## Gate result (current)

- `flutter gen-l10n`: PASS (exit 0, round 1)
- focused regression tests (25 cases, 2 files): PASS (exit 0)
- `flutter analyze --no-pub`: FAIL (exit 1) - 1 production error + 1 warning + 4 infos, none in the files this worker owns

## Defects reported to root (not fixed here - outside this worker's ownership)

1. **Production compile error - `lib/features/files/sftp_file_view.dart:758:52`**
   `undefined_getter`: the view reads `sftpState.items`, but `SftpState`
   (`lib/core/providers/sftp_provider.dart:163`) exposes `files`. This is app
   code, not a test, so the SFTP feature cannot compile. SFTP is not this
   worker's area (core/SSH/reconnect tests and sftp belong to the other
   OpenCode worker) - reported, untouched. Either `items` -> `files` at the call
   site or restore a compatible getter on `SftpState`.

2. **UI analyzer debt (AgY)** - `unused_import` warning at
   `lib/features/chat/widgets/session_recovery_banner.dart:9:8` and
   `unnecessary_import` infos at `lib/features/chat/ai_chat_view.dart:29:8`,
   `lib/features/chat/cli_chat_view.dart:23:8`,
   `lib/features/chat/widgets/remote_workspace_browser_dialog.dart:9:8`.

3. **Test lint (core-lifecycle test owner)** -
   `unnecessary_underscores` at
   `test/core/background_recovery_lifecycle_test.dart:481:13`.

## Documented merge semantics worth root's attention (not counted as a defect)

`mergeReplayBatch` treats a **matching remoteMessageId as identity**: for that
message the remote text is authoritative, so a longer but non-prefix replay
replaces local text (`chat_repository.dart:298-317`). The no-erasure guards apply
to (a) any *shorter* snapshot under the same id, and (b) the ordinal fallback
path, where the replay must extend the local content as a prefix. The
"divergent text is rejected" test therefore exercises the ordinal path, and
"a longer replay under the same remote id corrects the text" pins the intended
authority rule. Also note that a shared session refuses to append any message
without a matching per-agent remote id (`chat_repository.dart:319`), which is the
fail-closed behaviour the cross-merge tests require.

## Not run in round 2 (out of scope)

- `flutter build` / assemble
- adb / device runs
- Network or SSH operations
- Real Agent prompts
- Any edit to production/UI code or to another worker's tests

---

# Round 3 - focused widget coverage

Owner: this worker (widget tests only). Root had fixed the core braces and
restored the zero-arg `stopGeneration()`; AgY was finishing the chat UI
compile/import/cache fixes. No production file was touched.

## File added

`test/features/background_recovery_ui_test.dart` (14 cases). Reuses the existing
in-memory doubles from `test/support/acp_chat_widget_harness.dart`
(`FakeAcpChatNotifier`, `HarnessActiveServerNotifier`,
`HarnessAgentRegistryNotifier`, `harnessAgent`, `loadRealTextFonts`) and
`tempChatRepositoryOverride()`; the production theme and l10n are the real ones.
Assertions are on the rendered widget tree - keys, `enabled`/`onPressed` state,
ticked callbacks, presence of spinners - not on source text.

One local pump helper replaces `pumpAcpHarness` for the cases that need a
driven connection state: Riverpod asserts *"Tried to override a provider twice
within the same container"*, so a second `serverConnectionProvider` override
cannot be layered on the shared harness. `pumpChatView` mounts the same set of
doubles and only swaps the connection notifier; nothing in `test/support/` was
modified.

## Cases

`SessionRecoveryBanner` (minimal real widget, no full app):

| Case | Asserts |
|---|---|
| idle renders nothing at all | no banner keys, no spinner anywhere |
| incomplete offers a working retry action | `sessionRecoveryRetryButton.onPressed != null`, one tap -> exactly 1 recovery |
| failed offers a working retry action | same, on the failed banner |
| reconnecting is suppressed while the connection banner is up | connection `connecting` -> no `sessionRecoveryReconnectingBanner`, no spinner |
| reconnecting is shown when the connection banner is absent | control: connection `connected` -> banner + exactly 1 spinner (suppression is conditioned, not blanket) |
| a manual disconnect shows offline instead of an endless spinner | `sessionRecoveryOfflineBanner` present, no reconnecting banner, **zero** spinners, no retry button |
| syncing stays visible even while the connection is reconnecting | only `reconnecting` is suppressed; `syncing` banner + spinner still shown |

`AiChatView` (real view, real theme/fonts):

| Case | Asserts |
|---|---|
| messages stay on screen through reconnect and sync | `user_msg_m1` / `assistant_msg_m2` + the assistant text still rendered under `reconnecting` and under `syncing` |
| recovery while the connection banner is up stays quiet | banner slot present, no duplicate reconnecting notice, transcript still readable |
| a manual disconnect shows offline and keeps the conversation | offline banner instead of the spinner, transcript still readable |
| offline keeps the draft readable and editable, send disabled | `TextField.enabled` true, controller still holds the typed draft, `enterText` still reports edits, `sendMessageButton.onPressed` null, `sendMessageCalls == 0` |
| reconnecting the server re-enables sending | send disabled offline, enabled once connected (proves the disable was connection-driven) |
| incomplete / failed expose a retry that recovers | retry is enabled, one tap -> exactly 1 `recoverConnection()`, and the already-received message stays visible |

## Runs (reporter expanded, `set -o pipefail`, no masking pipeline)

```
$ set -o pipefail; flutter test test/features/background_recovery_ui_test.dart --reporter expanded
00:14 +14: All tests passed!
EXIT=0
# log: /tmp/opencode/bg_recovery_ui_run5.log  (2 extra consecutive runs also exit 0)

$ set -o pipefail; flutter test test/data/chat_recovery_merge_test.dart \
    test/infrastructure/acp_background_idle_test.dart \
    test/features/background_recovery_ui_test.dart --reporter expanded
00:39 +39: All tests passed!
PIPESTATUS[0]=0
# log: /tmp/opencode/recovery_all_three_final.log
```

Two iteration logs are kept for the record: `bg_recovery_ui_run2.log`
(`pumpAndSettle` timeouts on the two spinner cases - an indeterminate
`CircularProgressIndicator` never settles, now pumped with fixed frames) and
`bg_recovery_ui_run3.log` (the duplicate-override assertion described above).

## `flutter analyze --no-pub` after the widget tests

```
Analyzing valhalla...

   info - The import of '../../../data/models/session_recovery_status.dart' is unnecessary ... - lib/features/chat/widgets/remote_workspace_browser_dialog.dart:9:8 - unnecessary_import
   info - The import of 'package:valhalla/data/models/session_recovery_status.dart' is unnecessary ... - test/core/background_recovery_chat_state_test.dart:15:8 - unnecessary_import
  error - The method 'markReady' isn't defined for the type 'AgentRegistryNotifier' - test/core/background_recovery_chat_state_test.dart:443:12 - undefined_method
   info - Unnecessary use of multiple underscores - test/core/background_recovery_lifecycle_test.dart:481:13 - unnecessary_underscores

4 issues found. (ran in 3.7s)
```

Actual exit code: **1** (log: `/tmp/opencode/analyze_final_ui.log`)

**`test/features/background_recovery_ui_test.dart` is analyzer-clean** (two
findings it initially raised - an unused `server_profile.dart` import and a
redundant `session_recovery_status.dart` import re-exported through
`ai_chat_provider` - were fixed inside the new file before this run).

Delta since round 2 (6 issues -> 4), all resolved by other workers:

- The **SFTP production compile error is fixed** - `lib/features/files/sftp_file_view.dart:758:52` no longer reports `undefined_getter`; the gate has no production errors left.
- AgY cleared the `unused_import` warning in `session_recovery_banner.dart:9:8` and the `unnecessary_import` infos in `ai_chat_view.dart:29:8` and `cli_chat_view.dart:23:8`.

## Gate result (current)

- `flutter gen-l10n`: PASS (exit 0, round 1)
- focused suites owned by this worker (39 cases, 3 files): PASS (exit 0)
- `flutter analyze --no-pub`: FAIL (exit 1) - 1 error + 3 infos, **none in app code**, none in this worker's files

## Defects reported to root (not fixed here - outside this worker's ownership)

1. **Test compile error - `test/core/background_recovery_chat_state_test.dart:443:12`**
   `undefined_method`: `markReady` is not defined on `AgentRegistryNotifier`.
   That file belongs to the core-lifecycle worker, so it was not edited here.
   Either add the method to the notifier or drive readiness through the
   existing agent-registry API. (Line moved 441 -> 443 between runs, so the
   file was being written while the analyzer ran.)
2. **UI analyzer debt (AgY)** - `unnecessary_import` at
   `lib/features/chat/widgets/remote_workspace_browser_dialog.dart:9:8`.
3. **Test lint (core-lifecycle test owner)** - `unnecessary_import` at
   `test/core/background_recovery_chat_state_test.dart:15:8` and
   `unnecessary_underscores` at
   `test/core/background_recovery_lifecycle_test.dart:481:13`.

No blocker compile remains in the chat/recovery surface: the chat UI, the
recovery banner, and all three of this worker's suites compile and pass. The only
outstanding error is another worker's in-flight test file.

## Still not run (out of scope for round 3)

- `flutter build` / assemble
- adb / device runs
- Network or SSH operations
- Real Agent prompts
- Any edit to production/UI code or to another worker's tests


