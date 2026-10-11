# Review of updater test first authored draft (not a pass)

OpenCode owns fixes, no production hook/dependency for fixture convenience.

- SharedPreferences is used without its package import. Remove unused
  url_launcher_platform_interface/app_visibility imports if still unused; no
  transitive import or lint suppression needed for these two cases.
- AppUpdateNotifier has no `dispose`; ProviderContainer owns its lifetime.
  Do not call `notifier.dispose?.call()` or add one to production.
- In concurrent-check test compare Futures before awaiting, then complete fake
  check gate, then await both. Current `identical(await first, await second)`
  waits the blocked Future before gate completion and deadlocks. Future<void>
  does not return a non-null result; assert state via container.read instead.
- ParseRelease/Check signatures must use the actual installed code. Preserve
  check deduplication and disposed-provider no-storage-write assertions; fixing
  a fixture is not permission to remove the requirements.
- Do not inspect Notifier.state directly outside its subclass; read provider
  state from container. To observe a disposed lifetime capture listeners/storage
  call counters before disposal, not read a dead Ref afterward.

Only two focused cases first; remaining writer/cancel/restore/release-epoch
coverage is still owed and must be recorded as unverified until tested.

Actual download-test fixture failure: Linux Flutter tests use the default
MethodChannelPathProvider, whose getDownloadsPath throws before invoking any
channel unless its platform is macOS. A channel stub alone cannot isolate this
path. Main declared ALREADY installed path_provider_platform_interface2.1.3 as
direct dev dependency (same lock version), following this repository's existing
launcher-platform fake pattern; no runtime dependency/version change.
OpenCode should use a small PathProviderPlatform subclass, returning owned temp
paths and an optional Completer for getDownloadsPath, save/restore original
PathProviderPlatform.instance per test. Run pub get --offline, confirm lock only
dependency classification changes, remove diagnostic prints, retain all pause/
cancel/failure assertions. Do not add production injection just for the fixture.
