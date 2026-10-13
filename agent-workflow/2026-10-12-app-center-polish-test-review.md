# Required test review corrections

Root reviewed the first authored tests; do not merely change expected counts to
make them green. Existing duplicate cache/disconnect test must be removed.

- Catalog tests need a configurable fake catalog. Seed a real source and actual
  successful rows first (centerApp.sourceId must match the saved source). Then
  return an empty disk cache and throw on network refresh. Assert the same rows,
  sourceErrors and loadingCatalog=false. Current fake always returns [] so the
  new catalog test does not simulate its title at all.
- Same-ID changed-URL test must FIRST prove old rows exist. Then change URL and
  make that source's cache empty/network fail, assert old rows are gone; retain
  an unchanged second source's rows. Current test starts empty and is vacuous.
- Add cache-read exception followed by successful network refresh; error clears
  and loading settles. Verify a server error isn't cleared by catalog refresh.
- Foreground test MUST import app_visibility_provider.dart and invoke actual
  setForeground(false/true), not disconnect/reconnect. Await initial refresh,
  record baseline, block onInspect with Completer, toggle foreground twice,
  assert one additional inspection while pending, existing rows/tasks visible,
  complete, assert no new launch. Never hardcode total inspections=1 after setup
  that already performs inspections.
- VM log expectations must match the real worker's log format (read source),
  rather than invented 'stage applying/checking' text. Exercise logs() as well
  as task logTail after generating HTTP traffic. Unique fixture only.
- tee needs a FILE within /tmp/valhalla-app-center-polish.gtzzQH, not directory;
  use pipefail to preserve test failure exit status.

Preserve original five provider tests. No production/UI changes. Scope and
machine identity protections in the main handoff remain mandatory.
