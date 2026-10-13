# OpenCode handoff: stability investigation and regression authoring

Read agent-development-rules.md and 2026-10-11-core-stability.md. Own only
`test/**`, task-specific diagnostic/benchmark scripts under `tool/` if required,
and this report. No production edits, generation, builds, installation, git,
publishing, production-agent prompts, preferences or remote operations yet.
No subagents or paid models. Run explicit MiMo2.6 free main/small; record actual
model. Other zero-cost model only under the user's existing fallback permission.

First investigate existing tests and author deterministic regressions for:
1. In-flight foreground health probe -> paused -> resumed: latest probe succeeds
   before older probe reports failure. A stale older result must not close a
   healthy current SSH client or broadcast transport death. Use existing fake
   transports and controlled completers; report mechanism, not guesses.
2. SFTP 1,000/10,000 entries: repeated filteredFiles reads and copyWith changes
   only in transfers/loading/error/viewMode should reuse computed immutable
   results. List/filter/sort/root changes must recompute correctly; input list
   and filters must not be modified. Preserve existing SftpState const callers.
3. ACP history/stream regressions using current mock adapter/harness: long history
   paging, first event order, duplicate and late stream events, cancellation,
   rollback and recovery no prompt/approval replay. Identify uncovered failures.
4. Update restore vs in-flight check/download, corrupt full file, partial resume,
   wrong artifact selection, cancellation during install verification. Existing
   focused tests are preferred to new parallel fake infrastructure.

Run relevant baseline checks and retain actual failing assertions/exit codes.
Benchmark current filter/sort in the same process with a warmup and report
1,000/10,000 entry counts, cold and repeated read timings; no hard wall-clock
assertions on shared CI. Do not make tests green by weakening requirements.
Record command logs under a unique /tmp directory and summary below.
Inspect ADB devices read-only, record whether an isolated or user device exists.
Do not uninstall, clear data, prompt production agents or consent Google OAuth.

## Results

2026-10-11: explicit MiMo2.6 free main/small attempted twice (ordinary then
`--pure`), followed by the user's previously authorized free Step5 and Space
Bunny main/small. Local model catalog confirmed zero costs; official Zen pricing
https://opencode.ai/docs/zen/ listed these models as Free. Each returned
`AI_APICallError: Rate limit exceeded. Please try again later.`; later logs report
`AI_RetryError: Failed after 3 attempts`. CLI runs were stopped with exit130
after confirmed upstream failure to avoid indefinite waiting. No test authored,
check executed or device result returned. No paid fallback. At that point changes
remained unverified and a direct-validation exception was requested, not assumed.
Do not reuse historical passing test counts.

User subsequently explicitly approved direct root regression authoring,
format/analyzer/tests and performance measurement for this task only. UI remains
original AgY; the future OpenCode ownership rule is unchanged. Root preliminary
checks: directory/diagnostics 20 passed, updater/lifecycle/repository 49 passed,
both actual exit0. ADB read-only inventory finds only Android x86_64 emulator
127.0.0.1:14251, not a physical phone. No current-source install performed.

## Final direct validation (user-authorized exception)

All commands used `/opt/flutter/bin/flutter` or `/opt/flutter/bin/dart`, from
the project root, with `--no-pub`. Full logs are under
`/tmp/valhalla-core-stability.j0LVyR`; no user server or current development Agent
was prompted, and no OAuth, uninstall, data clear or native installer was used.

- `flutter test test/core/sftp_listing_cache_test.dart test/core/sftp_sort_test.dart test/core/app_diagnostics_test.dart --reporter expanded`: 20 passed, exit0, before benchmark addition.
- `flutter test test/core/app_update_provider_test.dart test/core/background_recovery_lifecycle_test.dart test/data/chat_repository_test.dart --reporter expanded`: 49 passed, exit0.
- Directory benchmark/cache file alone after benchmark addition: 6 passed, exit0.
- Nearby 12-file gate: background chat state; reconnect provider/backoff;
  SSH transport/zombie; ACP adapter/features/session-resume/initialize-coalescing;
  run-settings rollback; update service/HTTP. 190 passed, exit0.
- `flutter test test/features/sftp_file_view_test.dart test/features/background_recovery_ui_test.dart --reporter expanded`: first 46 passed/1 failed, exit1; delayed same-session history stayed at pixels0 vs latest2693. AgY fixed it, then final gate with prepend test passed48, exit0 (`ui-tests-final.log`).
- Final `flutter analyze --no-pub`: no issues, exit0 (`analyze-final.log`).
- Final `flutter test --no-pub --reporter expanded`: **2504 passed, 18 skipped,
  no failures, exit0**, 94 seconds (`full-tests.log`). Skips: 7 operations VM,
  1 WebDAV fixture, 7 isolated NAS VM, 1 SSH/SFTP VM, 1 real mosh, 1 power VM.
  No matching VM/E2E environment variables were configured.
- Affected-file formatting and `git diff --check` passed. No generated files or
  dependencies changed. No build or installation was claimed.

Final same-host measurements: default-name projection over 1000/10000 entries,
20 equivalent uncached computations vs200 cached reads after3 warmups, 593.45 /
4352.45 microseconds vs0.24 /0.24 per read. Equality asserted, timing thresholds
not asserted. This measures repeat CPU projection, not remote directory load or
device frames. Temporary SQLite10000-message fixture: save258ms, latest50=10ms,
summary30=5ms, deep summary offset=5ms. Results vary with host load.

Added regressions exercise immutable projection reuse/invalidation, download
open single-flight/disposal/new-release races, controlled10sec/5min/30min resume
single-flight, 10000-message role-correct bounded paging, local timing, initial
history scroll/stream reading/prepend, list/grid directory scroll and selection
isolation. Full-suite desktop widget variants do not prove native Windows behavior.

AgY was explicitly restarted on user request and actual edits were produced by
original Valhalla, gemini-3.8-flash-high/effort high. Structured CLI results still
contained a quota ERROR alongside new implementation responses; CLI success was
not treated as proof. Exact UI diffs and the failing-then-passing widget gate
are the acceptance evidence. UI remained exclusively AgY-owned.
