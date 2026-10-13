# Application center polish — current-round verification

Version remains1.0.4+5; no push, Release or Actions. All UI/ARB is authored by
AgY original Valhalla/gemini-3.8-flash-high/high. Root owns core fixes/docs.

## Execution ownership

MiMo2.6free returned rate limit at06:17:07UTC. Verified-zero-cost Nemotron3.5
Lightning authored initial tests, but review rejected unseeded/vacuous catalog
assertions and a foreground test that never invoked app visibility. A second
directed attempt did not correct them and delegated despite the no-subagents
instruction. Both task-owned CLI runs were stopped; root took over under the
user's explicit CURRENT-round validation/build/preserved-data ADB exception.
The five original provider regressions are retained, four new scenarios now
exercise real provider transitions; no production UI edits by root.

## Completed evidence

Scratch `/tmp/valhalla-app-center-polish.gtzzQH`:

- `provider.log`:9 passed. Missing cache/network failure retains seeded rows;
  changed URL invalidates old same-ID rows but preserves unchanged source;
  cache-read error recovers via network without clearing server errors;
  actual foreground false/true transitions singleflight with no task replay.
- `core.log`:92 passed across the seven application-center core suites.
- `vm.log`:1 full pinned-VM lifecycle passed in3m19s. Host fingerprints,
  hostname, machine-id, ready marker verified before writes. Actual install,
  HTTP, persisted intent, reconnect, stop/start/configure/restart, service logs,
  update, restore and uninstall; data sentinel survives. Unique fixture only.
- VM first attempt had a test assumption that restart always emits nonempty
  task text before terminal state; rejected that timing/CLI-output assumption.
  Final test verifies exit0/running state and actual HTTP access log via logs().
- `ui.log` initial run9 passed/2 failed: actual multiservice desktop2x overflow
  and same-frame Confirm double-submit. Routed to AgY; NOT counted as passing.

## UI review completed

AgY fixed actual badge overflow, stale target binding in details/task routes,
mounted navigation, offline actions, spinner cleanup, and same-frame callbacks.
Loading alone was insufficient: a fast Future completes before the next rendered
frame; wizard now also guards its expected step and existing submitted task.
`ui.log`:14 passed, real fonts320dp2x/RTL/desktop, full store-to-installed flow,
same-frame double tap, source/search retention, old-target refusal, cancellation
failure/offline disabling and live non-cancellable stage all verified.

First full suite2660passed/19environment-skipped/1failure: new non-English ARB
parameter metadata absent. AgY supplied the same five placeholder schemas in
all16 translations; root regenerated localizations. UI and ARB remain exclusively AgY-authored, root only ran
mechanical formatter/generator and authored tests under explicit exception.

Pre-device gate: **2661passed /19environment-skipped /0failed** in1m31s;
analysis clean. This is superseded by the final gate below. Previous failures
are retained as regression provenance, not current status.

At this stage fresh build/signature/ADB evidence was still pending; subsequent
device findings and final verified artifacts are recorded below.

## Device smoke caught additional integration bug (resolved in source)

First fresh Android build installed-r successfully at15:00:17device time;
firstInstallTime2026-09-23 03:26:04 remained unchanged. UI navigation into App
Center exposed APP_CENTER_SOURCE_UNSUPPORTED for official Chinese catalog.
The official localized index is `{apps:[{id,tagline,...}]}` (translations only),
whereas canonical index.json has178 complete v2 records. Fixed loader merges
only title/tagline by ID over canonical validated records; overlay cannot replace
compose URL, images, architecture or add apps. Empty/duplicate/bad field handling
covered. Fragment ETag is deliberately not reused to validate canonical index;
cached merged catalog remains usable offline. Parsing stays on an isolate.
Direct authoritative evidence:
https://raw.githubusercontent.com/IceWhaleTech/CasaOS-AppStore/gh-pages/index.zh_CN.json
https://cdn.jsdelivr.net/gh/IceWhaleTech/CasaOS-AppStore@gh-pages/index.json

`VALHALLA_APP_CATALOG_LIVE=true flutter test --no-pub --reporter expanded
test/core/application_catalog_cache_test.dart test/core/application_catalog_test.dart`
passed21, including real official Chinese catalog + BentoPDF template retrieval.
Default full suite skips this opt-in network test (now20environment skips).
Additional inspection regression ensures blocked remote Docker cannot offer
bootstrap (preparation already refused it). No production Docker changes made.
The first installed artifact is superseded: rebuilding and re-installing after
these actual device findings, not treating install success as functional success.

## Final gates and Android artifacts

- Final after catalog/bootstrap/recheck fixes: `full-test.log` **2664passed /
  20environment-skipped /0failed** in1m50s; `analyze.log` no issues. Network
  catalog test run explicitly above; isolated deployment VM run separately.
- `build-final.log` both local builds exit0. Version1.0.4+5 unchanged. Three
  official APKs retain certificate SHA256
  `73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d`.
- Directory `build/app-center-polish-validation/official/`:
  - arm64-v8a46,669,220bytes SHA256
    `322dcf9dbbca9d346cf30a552b159159c9f285729747b6fa01b6a152a2621741`.
  - armeabi-v7a44,826,956bytes SHA256
    `fab4fbb99fa35b989f1604d4c5594be9c2d584111ff2f2d36ee37ac0a73cff60`.
  - x86_6451,624,204bytes SHA256
    `19d84806821066125e82667c8e1a8fa735a1639f69cce5f9930904cce475325e`.
- `build/app-center-polish-validation/compatible/app-x86_64-release.apk`:
  51,620,108bytes, original debug certificate
  `2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`,
  SHA256`56c2ead822cf942561c9ecd6ce0855bbc0f4cd3c0e71f91a1664f9ad7ca588fd`.
  Release-mode binary; signing only differs to preserve existing emulator data.

## Final ADB evidence

`adb -s127.0.0.1:14251 install -r .../compatible/app-x86_64-release.apk` succeeded.
Installed base.apk SHA256 matches the compatible artifact. Package version4005 /
1.0.4; lastUpdateTime2026-10-12 15:13:48(UTC+8), original firstInstallTime
2026-09-23 03:26:04 unchanged. No uninstall, clear-data, key replacement or prefs
rewrite. Existing server configuration remains visible.

Read-only UI smoke: enter AppCenter -> official Chinese store -> BentoPDF
details -> installation configuration -> Cancel -> no deployment task; IME hidden
after cancellation. Short Home/return retained Tasks tab. No user-server install,
update, stop, restart or uninstall was submitted; mutations only in pinned VM.
First CDN request timed out; explicit retry loaded the real catalog successfully,
then details/configuration opened. This latency is not claimed as a speed pass.

Evidence XML: device-final-store-retry.xml, device-final-details-loaded.xml,
device-final-wizard.xml, device-final-cancelled.xml, device-final-tasks.xml,
device-final-resume.xml. Valid logcat from10-12 15:13:48.000, command exit0,
4938lines, no E/flutter/unhandled/FATAL/RenderFlex pattern matches in that window.
After valid checks the shared device foreground changed to another application;
stopped input immediately and removed the last unrelated screenshot/XML from
scratch. They are NOT verification evidence. No further device input was sent
after detecting the foreground switch.

Limits: automated widgets plus real VM lifecycle, NOT one full production-phone
deployment. Physical phone performance, long weak-network sessions, non-Android
builds and Docker auto-bootstrap not revalidated this round. CDN can transiently
time out; retry and cached catalog are available. No push, Release or Actions.
