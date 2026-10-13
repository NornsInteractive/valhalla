# Shared browser verification — OpenCode Phase1 results

## Root follow-up after explicit round-specific verification permission

Root added two actual platform-locale event tests: when app locale follows system,
an OS locale change refreshes the catalog and rejects the late old-locale result;
an explicit app locale ignores OS changes. Original34 cases remain. Command
`flutter test test/core/application_center_provider_test.dart --reporter expanded`
now reports **36 passed, exit0**, log
`/tmp/valhalla-browser-implementation.NXfb1raa/root-catalog-tests.log`.
The history below describes the earlier OpenCode34-case gate, not additional
unique tests or current device/build evidence.

Session authority: `agent-workflow/2026-10-13-shared-browser-tests.md`.
Scope authority: `agent-workflow/2026-10-13-shared-browser-and-app-data.md`.

- Explicit model: **opencode/mimo-v2.6-flash-free** (free tier only).
  Session `ses_ecb8bc51fffeiQkGb1ygyQ4dP2`. No paid model, no subagent, no
  task-delegation tool used.
- Environment: Flutter 3.44.2 stable, Dart 3.10.0, Linux host.
- Ownership honoured: tests only. `lib/`, UI, core, other agents' files and
  shared fakes (`test/support/application_center_fakes.dart`) untouched.
  No version bump, push, release, production write, credential access, ADB,
  build, APK, format, gen or full-suite run.
- Worktree preserved dirty; nothing committed.

## Phase1 scope executed

Catalog concurrency regression against the real `ApplicationCenterNotifier`
(`lib/core/providers/application_center_provider.dart`, read only) using the
file-local `_Catalog` service fake plus `Completer` gates.

## File changed

`test/core/application_center_provider_test.dart` (untracked new file in this
worktree, 823 → 1248 lines). Only this file was edited, via `apply_patch`.

Edits:

1. `_Catalog.cached` fake now returns a configurable `cachedRows` list
   (default `[]`, so every pre-existing expectation is unchanged).
2. Added imports for `package:flutter/widgets.dart` (`Locale`) and
   `settings_provider.dart` (`setLocale` gate).
3. Added `staleCatalogRow` fixture used by every supersession assertion.
4. Rewrote the pre-existing supersession test.
5. Added nine new regression tests. No existing assertion was deleted or
   weakened; every safety assertion from the supersession test is preserved
   (see "Preserved safety assertions").

## Baseline before edits (evidence of the behaviour change under test)

Command:

```
flutter test test/core/application_center_provider_test.dart
```

Result: `00:32 +23 -1: Some tests failed.` — 23 passed, **1 failed**.

Exact failure:

```
00:32 +11 -1: source-specific catalog retry late older retry cannot
  replace newer catalog results [E]
  TimeoutException after 0:00:30.000000: Test timed out after 30 seconds.
  See https://pub.dev/packages/test#timeouts
  dart:isolate  _RawReceivePort._handleMessage
```

Cause: the test asserted global supersession (a second same-context refresh
supersedes the first), but the provider now implements per-source
single-flight, so the second same-context refresh joined the gated in-flight
request and the test awaited forever. This is the test the Phase1 contract
required to be rewritten; it was not a product compilation break.

## Final gate (recorded)

Command:

```
flutter test test/core/application_center_provider_test.dart --reporter expanded
```

Exit code: **0**. Result: `00:01 +34: All tests passed!` (34 passed, 0 failed,
0 skipped).

Stability re-runs (same command without `--reporter`), 3 consecutive:

```
00:01 +34: All tests passed!
00:01 +34: All tests passed!
00:01 +34: All tests passed!
```

Scoped analyzer:

```
dart analyze test/core/application_center_provider_test.dart
→ Analyzing application_center_provider_test.dart...
  No issues found!
```

## Gates recorded (all green)

Totals: 34 tests = 23 unchanged pre-existing + 1 rewritten + 1 added to the
existing group + 9 in the new `catalog concurrency` group.

Unchanged pre-existing tests retained and passing (23):

1. cache survives disconnect and failed reconciliation
2. late old-target inspection cannot overwrite new server data
3. refresh singleflight waits for the same inspection
4. intent persists before launch and reconnect never replays
5. failed persistence prevents remote launch
6. missing disk cache and network failure retain populated catalog
7. same-ID changed URL discards old source rows but retains unchanged source
8. cache exception recovered by network clears source error not server error
9. source-specific catalog retry / retrying one source preserves other
   catalog, error and success time
10. source-specific catalog retry / failed single-source retry preserves
    usable catalog and success timestamps
11. source-specific catalog retry / unknown and disabled retry is a no-op and
    does not cancel valid in-flight refresh
12. source-specific catalog retry / default refresh still refreshes every
    enabled source after scoped retry
13. foreground return singleflight retains rows and never replays task
14. lightweight task refresh does not inspect or reconcile deployments
15. task refresh coalesces concurrent reads into one future
16. read failure during disconnect retains command, log and stage then recovers
17. changed remote identity requires inspection without discarding existing output
18. invalid cleanup result on cached uninstall requires inspection keeping selection
19. observed unresolved tasks poll each second without full inspection
20. observing terminal history reads its final log; clearing observation stops rereads
21. inspection recovery to terminal status triggers deployment reconciliation
22. unawaited observation and timer persistence failures stay handled and recover
23. late old-server task response cannot overwrite newly selected server

Rewritten / added inside the existing `source-specific catalog retry` group:

24. same-context retry joins the in-flight refresh (rewritten, see below)
25. supersession happens only when the source identity changes (new)

New `catalog concurrency` group (9):

26. first read auto refresh and immediate explicit refresh share one request —
    provider first read schedules the build microtask; an explicit
    `refreshCatalog()` is issued immediately, before the microtask runs.
    Asserts exactly one `cached` and one `refresh` call for the official
    source, that the explicit waiter does not settle early, that
    `loadingCatalog` stays true and the catalog stays empty while gated, and
    that the published catalog is useful after completion.
27. independent source completions merge rows, errors and timestamps — two
    sources gated independently; the first completion republishes only its own
    source (other source's rows, timestamp instance and identity preserved),
    the second source's network failure is merged as a per-source error, and
    the successful source's timestamp is preserved across the failure.
28. full refresh and scoped refresh share one in-flight request per source —
    `refreshCatalog(sourceId: …)` then full `refreshCatalog()`: neither
    waiter settles early, the shared source performs exactly one network call
    while the other source is fetched once by the full refresh.
29. rows published from a readable disk cache survive a network failure —
    cache publishes rows, network fails, catalog keeps the cache rows and
    records the source error.
30. cache failure with a failed network refresh recovers on the next retry —
    cache + network failure records the network error; the next retry
    re-reads cache and network and clears the error.
31. all sources disabled makes every refresh a no-op without service calls —
    no `cached`/`refresh` calls, catalog/errors/timestamps untouched,
    `loadingCatalog` false.
32. disabling sources stops loading while a stale request is still in flight —
    `loadingCatalog` true while effective, false immediately after every
    source is disabled even though the stale request has not completed, and
    the stale completion cannot publish.
33. locale change discards the superseded catalog result.
34. server change discards the superseded catalog result.

## Preserved safety assertions

The pre-existing `late older retry cannot replace newer catalog results`
test is split into the two behaviours the contract now requires; nothing was
dropped:

- Same-context half (`same-context retry joins the in-flight refresh`): still
  asserts that a later same-context refresh cannot replace earlier results —
  now because it is the *same* request. Asserts exactly one cache read and one
  network call for the source, `loadingCatalog` true while pending and false
  after, and the merged catalog contains the newer rows from both sources.
  The old `same(newest)` object identity check was replaced with the stronger
  single-flight evidence (call counts), because the provider now legitimately
  assigns a new state object in `_updateCatalogLoading()` when the joined
  request settles.
- Changed-identity half (`supersession happens only when the source identity
  changes`): a refresh started against the old URL stays in flight across
  `saveSources` with a replacement URL. After the newer identity has
  published, the stale completion is proven ignored by:
  `identical(after.catalog, newer.catalog)`,
  `identical(after.sourceErrors, newer.sourceErrors)`,
  `identical(after.sourceRefreshedAt, newer.sourceRefreshedAt)`,
  `after.catalog.map((app) => app.id)` not containing the stale row id, and
  the content assertions `containsAll([updated, otherApp])` plus
  `loadingCatalog == false`. Locale and server identity changes carry the
  same identity/content assertions.

## Not run / explicitly deferred

Per instruction, and recorded as actual skips:

- `dart format` — not run (deferred).
- `flutter gen-l10n` / code generation — not run (deferred).
- `flutter analyze` on the whole package — not run; only the scoped
  `dart analyze test/core/application_center_provider_test.dart` was run.
- Full test suite — not run (deferred until root freeze).
- Build, APK, signing, ADB install/device smoke — not run (deferred until
  root freeze). No emulator acceptance and no physical-phone performance
  claim is made.

## Blocked / notes for root

- None. No product compilation error was encountered; `lib/` was never
  edited, so no product breakage was reported or worked around.
- `test/core/application_center_provider_test.dart` is currently untracked
  (`git status` → `??`) in this worktree; the Phase1 edits above are local
  and uncommitted.
- Later gates in the contract (cleanup helper execution, naming/rollback,
  browser picker callers, UI layout positions, full gates, test-signed
  release APK and retain-data ADB) remain unscheduled pending root scope.
