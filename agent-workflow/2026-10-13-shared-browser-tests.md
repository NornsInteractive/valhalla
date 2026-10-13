# OpenCode verification contract

Use opencode/mimo-v2.6-flash-free explicitly; session
ses_ecb8bc51fffeiQkGb1ygyQ4dP2. Free only. Root/UI collaboration is in
2026-10-13-shared-browser-and-app-data.md. Do not edit product UI/core or other
agents' files. Test files/new fixtures and this report's result sibling allowed.
Use apply_patch for test edits. No ADB/build/full-suite until root says freeze.

## Phase1 now: catalog concurrency regression

Own test/core/application_center_provider_test.dart plus any minimal test support
needed (do not edit shared application_center_fakes.dart until you notify root).
Read actual provider. Root replaced global refresh supersession with per-source
single-flight: current epoch/generation/id/URL/locale key. Full and source refresh
share work; completion means cache/network publication. Scoped commits merge
current catalog/errors/timestamps, not captured snapshots. Old URL/locale/target
results ignored, loading only counts effective in-flight requests.

Use real notifier with _Catalog service fakes and Completers, including FIRST read
auto build microtask immediately followed by explicit official-source refresh.
Assert neither waiter completes early, only one same-source refresh and useful
catalog after completion. Include two independent source completions, full/single
crossing, locale/URL/server changes, cache failure/retry, retained cached rows on
network error, all sources disabled. Existing test for later same-context refresh
superseding earlier must become same-context single-flight, with supersession only
on changed identity. Do not weaken existing safety assertions.

Root added WidgetsBindingObserver.didChangeLocales: system-following language must
start a replacement refresh, not merely invalidate old responses. Explicit locale
unchanged ignores platform changes. Dispose removes observer. Regression includes
delayed old-language network request + platformDispatcher.localesTestValue change.
Stale completion must not even publish an extra new-state copy; outer refresh await
now has no final state write for nonempty sources.

Run focused provider test; record exact command, failures and successes in
agent-workflow/2026-10-13-shared-browser-test-results.md. Concurrent product edits
may temporarily break compilation: report exact error rather than editing product.
No real remote server calls, no test opt-in destructive VM variables, no secrets.

## Later gates (root will scope these after APIs settle)

Cleanup helper actual execution on isolated fixtures; dataRoot/root child grouping,
shared/protected/identity replacement, retry originally selected set. Naming defaults,
main/sidecars, legacy preserved, foreign stopped/running conflict, alias/labels,
new rename review/config rollback. Browser target isolation/lazy rendering/cancel,
all six old picker caller migrations+NAS draft browse/protocol roots/auth/library
exclusion/literal pattern chars. UI2 columns by actual positions at320–430dp,
2x/RTL/no focus restore. Generation/format/analyze/full tests then compatible
test-signed1.0.4+5 APK and retain-data ADB installed hash/time+guarded UI validation.
