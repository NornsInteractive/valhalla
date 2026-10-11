# Updater follow-up gate — OpenCode only

Use an explicitly confirmed-free main and small model; LongCat free is the
current working fallback. No live server, paid model, UI/production edits,
builds/ADB/cloud/push or scratch repository. Keep all original assertions.

Allowed: new test/core/app_update_provider_test.dart, small additions to existing
test/core/app_update_service_test.dart, this report. Reuse mock preferences,
PackageInfo.setMockInitialValues, method-channel path-provider fakes and
appUpdateServiceProvider.overrideWithValue; no new dependency or product hooks.

Regression tests needed for the current AppUpdateNotifier implementation:

- Pausing then immediately resuming waits for the old writer to settle before
  starting another writer on the same .part. A fake download remains blocked
  during cancellation cleanup. Assert only one active writer and no false failed
  state from the old canceled task; preserve the exact artifact/path.
- Cancel while reservePath is pending: no download or durable record write after
  the old epoch becomes stale. Two taps while downloading do not duplicate it.
- Manual refresh failing keeps the previous release/content and exposes error;
  a 404 clears the previous release. Default isolated providers do not make HTTP
  automatically; production explicit opt-in checks no more than once per 24h.
- An old restore/check must not overwrite a newer release or access disposed
  ref after PackageInfo/runtime metadata awaits.
- openDownloaded must use the exact captured file/artifact/version it validated,
  never a later state.localPath. Tampered completed download must not invoke any
  native installer/reveal. No real OS installer interaction in tests.
- Release notes above the limit, including Unicode astral characters, remain
  bounded without broken UTF-16; full text is available at the Release URL.

Run only provider/model/HTTP tests, formatting only the authored tests. Record
exact results and actual blockers. A fixture failure is not a production proof,
and a partial green subset is not a full workspace gate.

Status: pending delegate execution; no result claimed.
