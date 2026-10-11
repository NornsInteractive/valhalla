# Six plan phase 2 — NAS index / thumbnail scheduler / recovery / ACP test validation

2026-10-11. Independent **test-only** job on base `b97a02c` + in-flight parallel edits.

## 1. Scope and limits

- Authored/edited files (this is the complete list of my writes):

| File | Change |
| --- | --- |
| `test/data/nas_index_perf_test.dart` | new, 1 test |
| `test/core/services/nas_thumbnail_scheduler_ownership_test.dart` | new, 3 tests |
| `test/core/nas_playback_download_proxy_test.dart` | +71 lines, 1 new test (13 → 14) |
| `agent-workflow/2026-10-11-six-nas-acp-validation.md` | this report |

- No `lib/`, `packages/`, `docs/`, `android/`, `windows/`, ARB, or generated files touched.
  The `lib/` and `docs/` entries visible in `git status` belong to Codex / AgY, who were
  editing while I worked (`features/**`, `system_provider.dart`, `sftp_provider.dart`,
  l10n, docs). I never opened them for write.
- No subagents, no paid-model fallback, no build, no packaging, no ADB, no network, no
  server process, no `integration_test/`, no whole-workspace test run while AgY edits
  `features/**`, no production prompt/history/auth mutation.
- Tooling restricted to tests: `dart format` was run on exactly the three test files
  above; `flutter analyze --no-pub` was run on exactly those three files
  (`No issues found!`). No whole-app analyzer run.
- Suite selection was done with `rg --files test | rg …` (see §4). No environment
  skips were used, so nothing is silently counted as passed.

## 2. New coverage written

### 2.1 `test/data/nas_index_perf_test.dart` (1 test, `Timeout(5 min)`)

Fixture style copied from `test/data/nas_index_repository_test.dart`: owned temp dir
(`Directory.systemTemp.createTemp('valhalla-nas-perf-')`), `sqlite3` Linux override in
`setUpAll`, teardown deletes **only** that directory.

- Seeds **exactly 10,000** `NasMediaItem` rows through `replaceServerItems` (10 × 1000
  batches); asserts `count() == 10000` and `totals().total == 10000`.
- `Stopwatch` measurements: seed, **cold** first 200-row keyset page (first read after
  the seed), **warm** page ×40, **cold** first 200-row search page, **warm** search ×40,
  full 50-page navigation, 3-page search navigation.
- Warm series are reported as actual **p50 / p95 in microseconds** (sorted samples,
  rounded index), not means.
- RSS: `ProcessInfo.currentRss` baseline before seeding and a peak sampled after every
  measured step; reports baseline / peak / delta. Asserts only `peak >= baseline`
  (true by construction, i.e. a sampling sanity check).
- Correctness assertions, no wall-clock budget anywhere:
  - every page `<= 200` rows and non-empty;
  - full navigation yields exactly `10000` rows, `50` pages, **no duplicate paths**;
  - each row is strictly ordered by the keyset sort key `(-modifiedEpoch, path)`;
  - navigation terminates inside a hard guard (`< 100` pages) and the guard must not
    be hit;
  - search (`album00` → FTS prefix) pages: `<= 200`/page, `3` pages, exactly `500`
    distinct rows, same ordering rule, and `count(search) == 500`.

### 2.2 `test/core/services/nas_thumbnail_scheduler_ownership_test.dart` (3 tests)

Same fixtures as the existing scheduler suite: `path_provider` MethodChannel mocked to
an owned temp dir, `_StubAdapter.thumbnail()` returns `null` (so nothing decodes PNGs,
nothing touches `dart:ui`, no NAS, no server), observations are adapter call lists,
returned futures and on-disk files.

Requested behaviours vs. what already existed:

| Requested | Status before this job |
| --- | --- |
| repeated same-owner request dedup | **missing** → added |
| warm-cache no-adapter read after released owner | cache-hit existed, the release → warm-read path did not → added |
| new visible priority | already covered (`the newest visible tile is served first`) |
| 64 queue bounded via observables | already covered (`the in-flight slot count is bounded`, `served <= 65` over 81 queued, counted from `adapter.calls`, no timing) |
| release of one owner while another waits | **missing** → added |

The three added tests:

1. **same-owner dedup** — a blocker occupies the pump, the same tile is then requested
   twice by `grid-1`: both calls return the *identical* future and the adapter is called
   exactly once for it.
2. **release one of two owners** — releasing `grid-1` must *not* settle the future
   (asserted through a `settled` flag after `pumpEventQueue`); releasing the last owner
   settles it to `null`; the cancelled work never runs a second time (adapter call list
   unchanged after the gate opens).
3. **warm read after release** — a pending tile is cancelled by its owner's release
   (`null`), the cancelled work does not re-run, and the next read of a warm tile
   returns its cached path with the adapter call list still holding only the one
   cancelled fetch.

Why a sibling file instead of editing `test/core/services/nas_thumbnail_scheduler_test.dart`:
that file contains **three literal `0x00` bytes** inside the Dart string used for the
cache-key fixture (line ~72), so the byte-oriented read/edit tools refuse it as binary.
Normalising those literals would have meant rewriting an existing fixture with a shell
tool, which is outside "native tools edit tests"; the new cases reuse the same
fixtures/mocks in a clean text file instead. The existing file was left byte-identical
and still passes (11 tests).

### 2.3 `test/core/nas_playback_download_proxy_test.dart` — player retry (+1 test)

`NasMediaPlayerService.retry()` (`lib/core/services/nas_media_player_service.dart:222`)
had **zero** non-UI coverage: `rg '\.retry\(' test/` only hit the download service.
Six-plan item 5 requires "explicit playback retry at existing position/queue". The new
test reuses the file's existing fakes (`_Player`, `_Adapter`, `_Ssh`, real temp index):

- `retry()` with nothing loaded throws `StateError` (not a silent no-op);
- after `open` → `jumpTo(2)` → `seek(42s)`, `retry()` re-opens **the same URI**
  exactly once, with `Media.start == 42s` and `player.state.position == 42s`;
- `current`, `state.index == 2` and the queue survive; the queue lease is not released
  (`closed == 0`); `state.error` stays null.

### 2.4 Recovery / ACP — gap analysis, no files added

Checked against six-plan item 3; coverage already exists, so nothing was written:

- *discovery never creates sessions*: `acp_client_features_test` ("session/list … never
  creates a session", asserts no `session/new`), `acp_initialize_coalescing_test`
  (coalesced/sequential/late-open all stay sessionless), `acp_usability_adapter_test`
  (`initializeOnly` sends no `session/new|load|prompt`), `ai_chat_provider_test`
  ("只发现方法，不建会话"), `ai_chat_usability_test` (draft `prepareRunSettings` and
  `queryAccountStatus` never create a session).
- *no automatic prompt/approval replay*: `acp_client_features_test` ("captureReplay
  replays history on session/load only, plain restore is silent", and a later turn must
  not replay again), `chat_replay_merge_test`, `chat_recovery_merge_test` (replay can
  never erase/rewrite local content).
- *permissions/approvals*: `acp_adapter_test` (permission request emitted, raw
  `optionId` echoed, null cancels, cancelled outcome) and `ai_chat_provider_test`
  group "ACP 第一阶段：审批选项、运行设置与工具增量" (`allow_always` never auto-chosen).
- *recovery retaining content*: `background_recovery_chat_state_test`
  (connected → disconnected keeps history/selection/draft), `background_recovery_lifecycle_test`,
  `_reconnect_test`, `_probe_test`, `_credential_race_test`, `chat_recovery_merge_test`,
  `chat_replay_merge_test`, `ai_chat_usability_test` (恢复偏好: `load`, never `new`).
- All of these use in-file fakes (`FakeAcpTransport`, `_Fake…` doubles, memory SQLite);
  no real Codex process, no real prompt, no real history, no auth.

## 3. Runs — complete counts and exits

One file per invocation, `flutter test --no-pub <file>` (isolated mocks, foreground,
natural end). Selected names via `rg --files test`.

| # | File | Tests | Exit | Wall |
| --- | --- | ---: | ---: | ---: |
| 1 | `test/data/nas_index_repository_test.dart` | 6 | 0 | 3s |
| 2 | `test/data/nas_index_perf_test.dart` | 1 | 0 | 2s |
| 3 | `test/core/services/nas_thumbnail_scheduler_test.dart` | 11 | 0 | 2s |
| 4 | `test/core/services/nas_thumbnail_scheduler_ownership_test.dart` | 3 | 0 | 1s |
| 5 | `test/core/nas_playback_download_proxy_test.dart` | 14 | 0 | 6s |
| 6 | `test/core/background_recovery_chat_state_test.dart` | 12 | 0 | 4s |
| 7 | `test/core/background_recovery_credential_race_test.dart` | 3 | 0 | 11s |
| 8 | `test/core/background_recovery_lifecycle_test.dart` | 16 | 0 | 2s |
| 9 | `test/core/background_recovery_probe_test.dart` | 16 | 0 | 3s |
| 10 | `test/core/background_recovery_reconnect_test.dart` | 11 | 0 | 2s |
| 11 | `test/core/ai_chat_provider_test.dart` (runtime) | 44 | 0 | 6s |
| 12 | `test/data/chat_run_settings_test.dart` (config) | 1 | 0 | 2s |
| 13 | `test/data/chat_run_settings_json_test.dart` (config) | 11 | 0 | 2s |
| 14 | `test/core/ai_chat_draft_failure_test.dart` (draft) | 2 | 0 | 4s |
| 15 | `test/core/ai_chat_usability_test.dart` (draft / recovery prefs) | 14 | 0 | 3s |
| 16 | `test/infrastructure/acp_adapter_test.dart` (permission) | 21 | 0 | 3s |
| 17 | `test/data/chat_recovery_merge_test.dart` (recovery) | 26 | 0 | 4s |
| 18 | `test/data/chat_replay_merge_test.dart` (recovery) | 13 | 0 | 3s |

- **18 files, 225 tests, 225 passed, 0 failed, 0 skipped, every exit code 0.**
- Group totals: index/scheduler/playback 35 · background_recovery 58 ·
  ai_chat runtime/config/draft/permission/recovery 132.
- Before the final table, the two new files and the player-retry test were each run
  individually while being iterated on (one intermediate run of the ownership suite
  failed with a 30 s timeout — the third test originally read the warm tile while the
  single pump was still blocked on the stub gate; the order was fixed and it has passed
  on every run since).
- **One combined re-run failed and is recorded in full in §6.** The 225 counts above are
  per-file counts and stay exactly as recorded; they are **not** aggregated with the
  29-test combined runs (§6.2) and the 28-test combined run that failed.
- `flutter analyze --no-pub` on my three test files: **No issues found** (one
  `unused_import` in the perf draft was removed before the final run).

## 4. Performance results (`nas_index_perf_test.dart`, three consecutive runs)

| Metric | Run 1 | Run 2 | Run 3 |
| --- | ---: | ---: | ---: |
| seed 10 000 rows | 855 ms | 895 ms | 877 ms |
| cold 200-row page | 4 ms | 4 ms | 4 ms |
| warm 200-row page p50 / p95 (×40) | 1283 / 2152 µs | 1294 / 2120 µs | 1225 / 2391 µs |
| cold 200-row search page | 3 ms | 3 ms | 3 ms |
| warm search p50 / p95 (×40) | 1812 / 1984 µs | 1851 / 2212 µs | 1827 / 2084 µs |
| navigate 50 pages (10 000 rows) | 68 ms | 71 ms | 70 ms |
| search navigation 3 pages (500 rows) | 5 ms | 5 ms | 5 ms |
| RSS baseline / peak / delta | 123.4 / 147.9 / **24.4 MiB** | 176.3 / 199.6 / **23.3 MiB** | 172.9 / 195.6 / **22.7 MiB** |

Raw line from run 3:

```
nas_index_perf(records=10000): seed=877ms coldPage200=4ms warmPage200x40: p50=1225us p95=2391us coldSearch200=3ms warmSearch200x40: p50=1827us p95=2084us navigate50pages=70ms search3pages=5ms rssBaseline=172.9MiB rssPeak=195.6MiB rssDelta=22.7MiB
```

## 5. Limitations

- **No wall-clock assertion by design.** Timings and RSS are reported, never gated, so
  a slow or loaded machine cannot fail the suite; there is likewise no performance
  *regression* threshold yet.
- "Cold" means the first read after seeding **inside the same process**; the OS page
  cache and the SQLite page cache are already warm, so this is not a first-open-from-
  disk measurement.
- RSS is process-wide (Dart VM + Flutter test harness) and the delta includes the
  isolate-spawn cost of `Isolate.run` used by every repository call; baseline varies
  between runs (~123–176 MiB) for reasons outside this test.
- Warm p95 over 40 samples is a coarse tail estimate; no outlier trimming, no warm-up
  samples discarded.
- The scheduler ownership tests deliberately keep the adapter's `thumbnail()` returning
  `null`, so the PNG decode / budget / prune path is exercised only indirectly by the
  existing suite (which writes bytes straight to the cache dir). No `dart:ui` decoding
  and no real image was needed, and none was synthesised.
- `test/core/services/nas_thumbnail_scheduler_test.dart` was **not** modified (literal
  NUL bytes, §2.2); its three extra key-fixture bytes are unchanged and it still passes.
- Not run: `test/features/**` (UI, AgY is editing `features/**`),
  `integration_test/**`, widget/golden suites, the rest of the workspace, `flutter build`,
  `gen-l10n`, whole-app `flutter analyze`, ADB, and any network path. Consequently this
  report proves **non-UI core behaviour only**; UI acceptance for six-plan items 1, 2, 5
  and 6 stays with the UI/verification workstreams.
- No environment-dependent skip was used anywhere, so the counts above are real
  executed assertions.

## 6. Flake record — recorded, not hidden

This section exists because a combined re-run failed **before** the three repeat
sweeps that are also recorded below. Nothing here is reconstructed from memory alone:
it separates what is provable from preserved output from what is not recoverable.

### 6.1 The failing run, exactly as it was issued

```
flutter test --no-pub \
  test/data/nas_index_perf_test.dart \
  test/core/services/nas_thumbnail_scheduler_test.dart \
  test/core/services/nas_thumbnail_scheduler_ownership_test.dart \
  test/core/nas_playback_download_proxy_test.dart \
  2>&1 | tr '\r' '\n' | grep -E 'All tests|Some tests|nas_index_perf|failed'
```

- **Natural exit code: not recorded, and cannot be inferred.** The command was a
  pipeline whose last stage was `grep`, so the only `$?` available was grep's. The
  actual `flutter test` exit status of that run is unknown and was never written down.
  The failure is established by the compact reporter's own text, not by an exit code.
- **Raw log: none exists.** That run was never redirected to a file, so there is no
  `/tmp/opencode/six/…` artifact for it. The only preserved trace is the filtered
  terminal output captured in the session, quoted here:

  ```
  00:01 +12 -1: …/test/data/nas_index_perf_test.dart: 10000 media records: …
  00:02 +13 -1: 10000 media records: …
  …
  00:02 +28 -1: 10000 media records: …
  00:02 +28 -1: (tearDownAll)
  00:02 +28 -1: Some tests failed.
  ```

- **Why the failing test cannot be named with certainty: my own filter destroyed it.**
  The `grep -E 'All tests|Some tests|nas_index_perf|failed'` pattern did not include
  `[E]`, so every `[E]`, `Expected:`, `Actual:`, `Which:`, and stack-trace line was
  dropped on the floor. The compact reporter's per-test label on those lines was also
  ambiguous (every captured line carried the perf test's label, a reporter artifact, so
  the label proves nothing about which file failed). The failing assertion's text is
  therefore **not recoverable from any preserved artifact**, and is not claimed here.

### 6.2 What the surviving evidence does establish

| Fact | Evidence | Confidence |
| --- | --- | --- |
| Exactly one test failed | final counter `+28 -1`, 29 total events across the 4 files | high |
| The three non-perf files contain 28 tests (11 + 3 + 14) | `rg -c` counts, §3 | high |
| The perf test's summary `print` (its last statement) never appeared | absent from the captured output; present in all 11 later combined runs (`combo_1..11.log`) and in every individual run | high |
| It was not a timeout | wall clock `00:02`; perf test carries `Timeout(5 min)`, suite default 30 s | high |
| Therefore the failing test was most likely `test/data/nas_index_perf_test.dart` | arithmetic 28 passed from the other three files + no perf summary print | **moderate-high, not proven** |
| The specific failing assertion | not recoverable | **unknown** |

The one alternative that the evidence cannot exclude: the `print` line was lost in the
`\r`-based conversion and one of the 28 other tests failed instead. That would be a
second flake class, and it is **equally unproven**. Both readings stay open until a
recurrence is captured with a raw, unfiltered log.

### 6.3 Remaining root-cause analysis, and what is deliberately unfixed

- **Unpatched, load-dependent risk:** both thumbnail suites assert a *presence* right
  after a single `await pumpEventQueue()` (e.g. `expect(adapter.calls,
  ['/media/blocker.mkv'])` in `nas_thumbnail_scheduler_ownership_test.dart`, and the
  same shape at `nas_thumbnail_scheduler_test.dart:125 / :148 / :172`). `pumpEventQueue`
  advances zero-duration timers, not pending file IO, so under the parallel load of a
  10 000-row seed plus ~130 `Isolate.run` spawns in a sibling process, the adapter call
  can legitimately not have happened yet. The bounded-pump-until hardening for this
  (a `_settle(bool Function())` helper) was designed but **never implemented** — no code
  edit was permitted in this follow-up. This is a real, still-open flake surface in
  *both* files, including the pre-existing one I must not rewrite.
- **Against the thumbnail hypothesis, for this specific failure:** the arithmetic in
  §6.2 points at the 10 000-row index fixture, whose assertions are otherwise
  deterministic (page sizes, `pages == 50`, no duplicates, `searchSeen == 500`,
  `rssPeak >= baseline`), and whose sole observed symptom would have to be a
  late-stage assertion before the summary print. Its only environment-sensitive parts
  are the FTS rebuild on first migrate and the RSS samples; neither had failed in any
  of the other 32 runs of that test.
- **Recurrence count:** 1 failure in 12 combined runs, 0 in the following 21 runs
  (11 combined + 10 thumbnail-paired), 0 in the 18 individual runs of §3. So the flake
  rate is ~8 % under combined 4-file load and is currently a non-reproducer on demand.

### 6.4 Repeat sweeps (natural exit codes, all redirected, all `exit 0`)

Every one of these was run as `flutter test --no-pub … > log 2>&1; code=$?` — **no pipe**
in front of the code that produced the log, so `code` really is flutter's exit status.

| Target | Runs | Evidence per run | Exit |
| --- | ---: | --- | ---: |
| Combined 4 files (29 tests) | 11 | `/tmp/opencode/six/combo_1.log` … `combo_11.log`, each `+29: All tests passed!`, each with its `nas_index_perf(...)` line | 0 |
| Thumbnail pair (14 tests) | 10 | `/tmp/opencode/six/thumb_1.log` … `thumb_10.log`, each `+14: All tests passed!` | 0 |
| 18 selected files (§3) | 1 | `/tmp/opencode/six/summary.txt` | 0 |

Representative raw evidence: `/tmp/opencode/six/combo_11.log` ends with

```
nas_index_perf(records=10000): seed=1005ms coldPage200=4ms warmPage200x40: p50=1448us p95=2221us coldSearch200=3ms warmSearch200x40: p50=1857us p95=2235us navigate50pages=69ms search3pages=5ms rssBaseline=173.0MiB rssPeak=196.9MiB rssDelta=24.0MiB
00:02 +29: All tests passed!
```

## 7. Status of this job — not complete

- The focused evidence (18 files, 225 tests, each exit 0) and the performance report in
  §4 stand unchanged and are not withdrawn.
- This job is **not** complete. What was missing was an honest record of the one
  combined failure, which §6 now provides — including the parts that cannot be
  explained. No claim is made that the flake is fixed, root-caused, or that the phase-2
  gate is green: the unfixed pump-settling surface in §6.3 is a live risk.
- Explicitly out of this follow-up by instruction: no repeat loops, no new tests, no
  further exploration, no production or UI edits, no formatting, no code generation,
  no build, no ADB, no git operations. The only change made in this follow-up is the
  text of this report.
- Still owed by other workstreams: whole-app `flutter analyze`, 17-locale parity,
  build/package/ADB validation, and all UI acceptance for six-plan items 1, 2, 5 and 6.
