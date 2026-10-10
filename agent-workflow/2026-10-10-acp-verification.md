# ACP verification — 2026-10-10

Scope: replace the uncompiled `test/core/acp_run_settings_rollback_test.dart`
draft with real regressions built from existing fixtures, and add the pending
history-load cancellation regression. User-authorized verification only; main
and small model explicitly free (`opencode/step-5-preview-free`).

## What changed

| File | Change |
| --- | --- |
| `test/core/acp_run_settings_rollback_test.dart` | Replaced entirely. 5 focused cases on real `AiChatNotifier.updateRunSettings` + `LocalStorageService` + `FakeAcpPair`. |
| `test/core/background_recovery_chat_state_test.dart` | Added group `本地历史读取中途掉线`, one case; `importedContainer` gained an optional `ChatRepository? repository` parameter (default path unchanged). |
| `test/support/fake_acp_transport.dart` | Two fixture fixes: (1) an accepted `session/set_config_option` value is now persisted into `configOptions` after any `configOptionsAfterChange` replacement, so later answers cannot report the pre-change value as current; (2) new `failConfigOptionWhen` predicate plus `errorConfigValues` set for per-request failure injection. |
| `tool/probe_sanitize.dart` | Deleted (temporary fake-secret probe; its coverage lives in `test/core/log_sanitizer_regression_test.dart`). |

No production, UI, ARB, build, git mutation or real remote operation.
Storage overrides are injected at container creation only; no runtime override.

## Fixture-fidelity bug found and fixed (fake only)

`FakeAcpPair` echoed the changed `currentValue` in the `session/set_config_option`
response but never updated its own `configOptions`. Any subsequent answer
(e.g. the `thought_level` change, or a later notification) re-emitted the stale
`legacy-model` as current, so a test that asserted the real protocol-confirmed
`high` reasoning level actually observed `low`. This was a fake-state defect,
not product behavior; product reads `result.configOptions` from the wire, which
already carried the accepted value. The overlay is now applied *after* the
replacement returned by `configOptionsAfterChange`, and the final echoed state
is persisted regardless of whether a replacement was produced.

## Cases covered (rollback test, 5)

1. 草稿持久化失败：界面与本地默认保持原样，且不触碰远端
   `_FailingStorage` (fails `saveChatRunDefault` only) is injected at container
   creation. No session exists, so `updateRunSettings` takes the draft branch,
   throws `STORAGE_WRITE_FAILED`, and must leave `runSettings` = `legacy-model`
   and the persisted default untouched, with exactly one write attempt and no
   ACP transport ever created (`_pairs` stays empty).
2. 远端部分失败：已下发的模型被回滚，本地默认保持旧值
   Agent accepts `model=new-model`, rejects `thought_level=high` (per-request
   failure predicate, code -32603). Expected rollback wires, in order:
   `model=new-model`, `thought_level=high`, `model=legacy-model`. Afterwards
   `runSettings`, the persisted default and `settingsStale=false` are truthful.
3. 远端已更新但本地写盘失败：本地默认与远端一起回到旧值
   Remote apply succeeds, then the local write fails. Persisted default stays
   `legacy-model` and the remote value is explicitly reverted.
4. 回滚失败：如实上报、标记陈旧并显示远端真实生效值
   Agent refuses both the `thought_level` change and the revert to
   `legacy-model`. Throws `ACP_SETTINGS_ROLLBACK_FAILED`, sets `settingsStale`,
   and `runSettings.modelId` reports what the agent actually still has
   (`new-model`) — not the requested value, not a silent success.
5. 成功路径：协议确认之后才持久化并更新界面
   Positive control: one `model=new-model` wire request, `runSettings` and the
   persisted default follow the confirmed protocol value, `settingsStale=false`.

## Case covered (background recovery test, 1)

读取中被断开：busy 被清掉，迟到结果被丢弃，重试补上更早的历史
70-message replay so the import brings only the last 50 (`messageOffset=20`),
making the older-page load a genuine paged read instead of a no-op. The local
`loadSession` is held via a small `ChatRepository` subclass, the connection is
dropped mid-read, then the stale future is completed with a bogus message.
Asserts: `isLoadingMessages` cleared by `_stopGeneration` (the pending-history
cancellation fix), session id and visible 50 messages preserved across the
disconnect, the stale result is not applied and raises no error, and a retry
really re-reads and restores all 70 messages in order.

## Commands, exit codes, counts

```
$ dart format test/core/acp_run_settings_rollback_test.dart \
    test/core/background_recovery_chat_state_test.dart \
    test/support/fake_acp_transport.dart
Formatted 3 files (2 changed)                                  exit 0

$ flutter test test/core/acp_run_settings_rollback_test.dart \
    test/core/independent_model_query_test.dart \
    test/core/background_recovery_chat_state_test.dart --reporter expanded
All tests passed!                                              exit 0
   (log: /tmp/opencode/acp_10_10.log)
   5  acp_run_settings_rollback_test.dart
   55 independent_model_query_test.dart
   12 background_recovery_chat_state_test.dart (11 existing + 1 new)
   72 total

$ flutter test test/core/background_recovery_chat_state_test.dart --reporter compact
All tests passed!                                              exit 0   (12 tests)
$ flutter test test/core/independent_model_query_test.dart --reporter compact
All tests passed!                                              exit 0   (55 tests)
   包含既有「模型与推理按顺序下发」用例：共享 fake 修正后由 +high/-low 回归为通过

$ flutter analyze --no-pub test/core/acp_run_settings_rollback_test.dart \
    test/core/background_recovery_chat_state_test.dart \
    test/support/fake_acp_transport.dart test/core/independent_model_query_test.dart
No issues found!                                               exit 0
```

An earlier combined run reported `RUN_EXIT=1` because the newly edited history
test referenced an undefined `retriedContents`; a secondary compiler message was
`The Dart compiler exited unexpectedly.` This was an authored test compilation
error, not demonstrated runtime/compiler flakiness. OpenCode restored the missing
local declaration; the same combined command then passed with exit 0, and the
per-file runs confirmed 5 / 55 / 12. Earlier drafts also needed real pagination
(70 messages, not two) and valid collection expectations; none count as coverage.

## Remaining production failures in these focused checks

None after main's production fixes. Both ACP behaviors under test (settings
rollback and pending-history cancellation) behaved as the 2026-10-09 contract
requires. This run also exposed defects in the authored tests/shared fake, fixed
above; it is not a claim that the pre-fix production code had no bugs.

## Remaining scope (not done here)

- Runtime acceptance is still unverified without an independent test target.
- Full-suite run, UI/ARB generation and build gates remain with their owners.
