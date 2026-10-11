# 2026-10-11 ACP reconnect + playback validation (verification only)

Mode: verification only. No production source edited, no test expectation
changed, no new test added, no build, no ADB, no SDK, no localization
generation, no commit, no push. Branch `main`. Environment: Flutter 3.44.2 /
Dart 3.10.0, linux_x64, 16 logical processors.

Scope excluded on purpose: the running transfer/draft verifier owns the
transfer and file-editor-draft areas. No file in those areas was read for
mutation, executed or reported here, so this run's evidence does not overlap
with it and the counts below must not be summed into any other suite's total.

## 1. Accepted completion contract

Read `agent-workflow/2026-10-11-completion.md` before running anything. The
clauses that bound this run:

- OpenCode owns write/run tests, format, localization generation, analyze and
  verification; Codex owns the business bridges.
- No live development Agent prompts, no production mutations for tests, no app
  uninstall/data clear, no shared cache deletion, no release/push.
- Accepted scope item 4 (ACP: host/container user identity, real auth/model/
  runtime/stream/approval/cancellation/recovery checks, no discovery sessions,
  bounded history and incremental output, inline single errors, explicit
  retries), item 1 (same-target reconnect keeps content/selection/drafts, cold
  start restores bounded cached data, never replay prompts/approvals/side
  effects) and item 8 (NAS: isolated fixtures and measured performance, no
  runtime claims based on build-only checks).
- "Focused regression proof per workstream" is the gate this run discharges
  for the ACP/reconnect/playback workstream only. Full suite, analyze and
  build gates remain open and are not claimed here.

## 2. Focused ACP / reconnect / playback suite — ACTUAL RESULT: 137 passed, 0 failed

Command (single invocation, all 13 requested files):

    flutter test --reporter=compact \
      test/core/ai_chat_usability_test.dart \
      test/core/acp_run_settings_rollback_test.dart \
      test/core/acp_navigation_and_preferences_test.dart \
      test/core/reconnect_provider_test.dart \
      test/core/background_recovery_lifecycle_test.dart \
      test/core/background_recovery_reconnect_test.dart \
      test/core/connection_lifecycle_test.dart \
      test/infrastructure/acp_adapter_test.dart \
      test/infrastructure/acp_client_features_test.dart \
      test/infrastructure/acp_session_resume_test.dart \
      test/infrastructure/acp_authenticate_now_test.dart \
      test/infrastructure/terminal_rebind_resilience_test.dart \
      test/core/services/nas_audio_handler_test.dart

Exit code `0`. Terminal line: `00:06 +137: All tests passed!`

Per-file counts were taken from an independent second invocation of the same
13 files with `--reporter=json` (`--reporter=compact` output is a single
overwritten progress line and cannot be tallied per file):

| File | passed |
| --- | --- |
| test/core/ai_chat_usability_test.dart | 14 |
| test/core/acp_run_settings_rollback_test.dart | 5 |
| test/core/acp_navigation_and_preferences_test.dart | 8 |
| test/core/reconnect_provider_test.dart | 24 |
| test/core/background_recovery_lifecycle_test.dart | 16 |
| test/core/background_recovery_reconnect_test.dart | 11 |
| test/core/connection_lifecycle_test.dart | 16 |
| test/infrastructure/acp_adapter_test.dart | 21 |
| test/infrastructure/acp_client_features_test.dart | 4 |
| test/infrastructure/acp_session_resume_test.dart | 9 |
| test/infrastructure/acp_authenticate_now_test.dart | 4 |
| test/infrastructure/terminal_rebind_resilience_test.dart | 2 |
| test/core/services/nas_audio_handler_test.dart | 3 |
| **total** | **137** |

The JSON run reported 137 non-hidden `testDone` events and 13 hidden ones; the
13 hidden entries are the reporter's own `loading <path>` placeholders, one per
file. Every non-hidden `testDone` carried `result: "success"`. Zero failures,
zero errors, zero skips-with-reason, suite-level `"success": true` only.

Two consecutive independent runs of the identical 13-file set produced the
same 137/0 outcome, so this is a stable result, not a one-shot pass.

### No actual failures to report

No test failed, so there is no failing test name, no assertion diff and no
source path to blame. Nothing was suppressed, filtered or `--name`-restricted:
every test in all 13 files ran.

### Mock-transport containment — verified, not assumed

`grep -rnE "Process\.run|Process\.start|dart:io|Socket\.connect|HttpClient"`
across all 13 files returns zero matches (grep exit 1). The files contain no
process spawn, no socket and no HTTP client, so no real SSH command, no real
Agents prompt and no remote call is reachable from this suite. SSH-typed
imports (`package:dartssh2/dartssh2.dart`,
`package:valhalla/infrastructure/ssh/ssh_client_manager.dart`) exist only for
interface typing; every injection point is overridden with a local double.
Doubles present in these files: `_FakeSshManager`, `_FakeSsh`,
`_FakeSshClient`, `_FakeSshChannel`, `_FakeSshSession`, `_FakeSshSocket`,
`_FakeSshExecutor`, `_FakeExecClient`, `_FakeExecutor`, `_FakeSession`,
`_FakeScheduler`, `_FakeTimer`, `_StubClient`, `_StubSession`,
`_StubActiveServer`.

### What the passing suite does and does not prove

Passing, per the test names and assertions actually exercised: draft run
settings call only `initialize` and never fire `session/new` on a draft
(`test/core/ai_chat_usability_test.dart`); run-settings persistence failure
leaves UI and local defaults untouched and never touches the remote, and
partial remote failure rolls back the already-pushed model while the local
default keeps the old value (`test/core/acp_run_settings_rollback_test.dart`);
`session/list` is answered with a page and never creates a session
(`test/infrastructure/acp_client_features_test.dart`); an existing remote
session id resumes via `session/load` and reuses that id, `load`+`resume`
failure never silently creates a new session, an empty-string sessionId is
never treated as resumable, and recovery failure is not misreported as an
auth requirement (`test/infrastructure/acp_session_resume_test.dart`).

Not proven by this run: no real agent, no real container, no real NAS device,
no real media file, no real network, no device or emulator, no
`flutter analyze`, no full-suite gate, no build, no release. The
`test/infrastructure/*` and `test/core/reconnect_provider_test.dart` results
are transport/protocol-level only; they are not evidence that a live ACP agent
over a live SSH container authenticates, streams, approves and cancels
correctly. Those still need the real-server acceptance the completion
contract has explicitly not claimed.

## 3. NAS index benchmark — ACTUAL MEASURED NUMBERS

`tool/nas_index_benchmark.dart` was read before execution
(`tool/nas_index_benchmark.dart:1-92`). Safety properties confirmed by
reading, not by assumption:

- It never touches application data. It creates its own
  `Directory.systemTemp.createTemp('valhalla-nas-bench-')` fixture at
  `tool/nas_index_benchmark.dart:13` and holds the SQLite file at
  `<temp>/index.sqlite3` (`tool/nas_index_benchmark.dart:16`).
- It deletes that temp directory in a `finally` block
  (`tool/nas_index_benchmark.dart:89-91`), so it cleans up on both success and
  failure.
- Its content is fully synthetic: `NasMediaItem`s generated from the loop
  index with fabricated paths under `/media/folder<n>/song<8 digits>.mp3`,
  fixed 8,000,000-byte size, synthetic titles/artists/albums
  (`tool/nas_index_benchmark.dart:22-43`). No real media, no real NAS, no
  thumbnail work.
- Row count is an explicit argument and is rejected below 1000
  (`tool/nas_index_benchmark.dart:11-12`), so a typo cannot silently run a
  trivial fixture.

Because it is isolated and self-cleaning, running it is safe and was run.

### Run A — 100,000 rows

    dart run tool/nas_index_benchmark.dart 100000

Exit `0`. Measured output:

| metric | measured |
| --- | --- |
| rows seeded | 100,000 |
| batch rows | 5,000 |
| seed time | 7.449 s |
| database size on disk | 128,589,824 bytes (~122.6 MiB) |
| sampled peak process RSS | 255,950,848 bytes (~244.0 MiB) |

| query | p50 ms | p95 ms | max ms |
| --- | --- | --- | --- |
| first_page | 1.401 | 2.853 | 5.154 |
| deep_page_95_percent | 1.219 | 1.304 | 1.878 |
| search_rare_prefix | 9.780 | 10.734 | 12.870 |
| search_common_prefix | 10.851 | 11.538 | 11.740 |
| totals | 9.234 | 9.617 | 9.970 |

### Run B — 1,000,000 rows (tool default)

    dart run tool/nas_index_benchmark.dart 1000000

Exit `0`. Measured output:

| metric | measured |
| --- | --- |
| rows seeded | 1,000,000 |
| batch rows | 5,000 |
| seed time | 82.001 s |
| database size on disk | 1,345,769,472 bytes (~1.253 GiB) |
| sampled peak process RSS | 275,181,568 bytes (~262.4 MiB) |

| query | p50 ms | p95 ms | max ms |
| --- | --- | --- | --- |
| first_page | 1.420 | 2.228 | 5.433 |
| deep_page_95_percent | 1.168 | 1.323 | 1.825 |
| search_rare_prefix | 94.296 | 99.072 | 99.175 |
| search_common_prefix | 105.253 | 112.949 | 114.440 |
| totals | 85.880 | 91.734 | 94.329 |

Each query above is 20 consecutive runs after seeding; p50/p95 are the
`times[9]`/`times[18]` order statistics the tool reports
(`tool/nas_index_benchmark.dart:61-74`).

### Peak RSS — reported honestly

The figure `sampled_peak_process_rss_bytes` is `ProcessInfo.currentRss`
sampled at seed-batch boundaries and after each query
(`tool/nas_index_benchmark.dart:17,39,67`). It is a sampled high-water mark,
not a kernel peak. For run B I additionally polled `/proc/<pid>/status`
`VmHWM` every 500 ms from outside the process and observed a maximum of
269,080 kB = 275,537,920 bytes, which is consistent with the tool's own
sampled 275,181,568 bytes. Treat the number as approximate; do not restate
it as a precise peak.

### Findings from the measurements

1. Paging is flat and bounded, as intended. `first_page` p50 1.42 ms and
   `deep_page_95_percent` (cursor at row 950,000 of 1,000,000) p50 1.168 ms at
   1M rows. Deep offset paging costs the same as the first page, which is the
   desired cursor behaviour and confirms the
   `nas_media_page ON nas_media(server_id, sort_epoch, path)` index at
   `lib/data/repositories/nas_index_repository.dart:160` is serving the
   ordered scan.
2. Search latency tracks library size, not result selectivity. This is a real
   observation, not a claim: `search_rare_prefix` p50 went 9.78 ms at 100k
   rows to 94.296 ms at 1M rows — 9.64x slower for 10x the rows, i.e. close to
   linear. A prefix that matches essentially one row
   (`song000000`, `tool/nas_index_benchmark.dart:58`) should not cost the same
   as a prefix matching most of the library; instead
   `search_common_prefix` (`Song`, `tool/nas_index_benchmark.dart:59`) is only
   about 12% slower (105.253 ms p50) than the rare-prefix case. Selectivity
   barely moves the number, so cost is dominated by table size rather than by
   the number of matches. Search does an FTS5 MATCH as a quoted token-prefix
   phrase inside `rowid IN (SELECT rowid FROM nas_media_search WHERE
   nas_media_search MATCH ?)` at
   `lib/data/repositories/nas_index_repository.dart:628-641`, against the FTS5
   table created at `lib/data/repositories/nas_index_repository.dart:183`; why
   the rare-prefix match is not sub-millisecond was not determined here and is
   left open, because this run is verification only and must not fix anything.
3. `totals` also scales with library size: 9.234 ms p50 at 100k to 85.880 ms
   p50 at 1M, ~9.3x for 10x rows. Same pattern as search, same open question.
4. Ingest throughput is about 12.2k rows/s (1,000,000 rows in 82.001 s,
   `tool/nas_index_benchmark.dart:84` counts only the seeding window, which
   excludes the query phase), at a disk cost of about 1,345 bytes per row
   (1,345,769,472 bytes / 1,000,000 rows). A one-million-item NAS library
   occupies roughly 1.25 GiB of local SQLite file.
5. Database size grew super-linearly relative to the row count: 128.6 MB at
   100k vs 1,345.8 MB at 1M, a 10.46x growth for 10x the rows. Minor, but
   recorded as measured rather than smoothed over.

### What the benchmark does NOT claim

No real media was decoded, played, seeked or thumbnailed. No real NAS server,
mount or network share was contacted. No player, audio focus, headphone or
queue behaviour is exercised here — the NAS playback proof in this run is
limited to `test/core/services/nas_audio_handler_test.dart` (3 tests) against
in-memory fakes, which asserts that a stale bind/detach cannot replace a newer
player, that system metadata/queue/playback state follows the current source
item, and that each system action routes exactly once to the authoritative
player. Those are logic-level assertions with no audio pipeline, no device
output and no measured playback latency. Consistent with accepted scope item
8, no runtime playback or scanning performance claim is made from this run.

## 4. What remains open

- `flutter analyze`: not run (out of bounded scope).
- Full test suite: not run (out of bounded scope). The 137 above are the ACP/
  reconnect/playback subset only and must not be summed into a full-suite
  count.
- Narrow-screen, large-font, desktop keyboard, localization and device/ADB
  checks: not run (out of bounded scope; ADB explicitly excluded).
- Real ACP agent over a real SSH container, real NAS device, real media
  playback: not run. The completion contract has not claimed these either.
- Search/`totals` selectivity-independent cost at 1M rows: open, diagnosed
  only to the level of measurement, deliberately not fixed here.
- Working tree: unchanged by this run apart from this evidence file. No
  commit, no push, no production or test file modified.