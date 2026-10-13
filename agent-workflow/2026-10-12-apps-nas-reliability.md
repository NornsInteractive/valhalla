# Application Center observability, per-port access and NAS organization

Approved implementation. Preserve all pre-existing dirty work. No version bump,
push, Release, Actions, production Docker mutation, uninstall or data clearing.

Root owns task worker/polling, integration and docs. Core helpers own catalog,
port/Compose and NAS core only. UI/ARB exclusively original AgY Valhalla
ec81a4be-7543-45ee-8658-f68966f57d3b, gemini-3.8-flash-high, effort high.
All regression authoring/execution, generation, formatting, builds and ADB
installation belong to OpenCode explicitly free models, MiMo first. Prior
single-round root validation exceptions do not apply to this iteration.

Current-round exception (supersedes preceding assignment for remaining work):
user explicitly approved root finishing validation/build/retained-data ADB install
after MiMo+BigPickle rate limits and repeated invalid free-fallback test drafts.
Stop only this task's OpenCode invocation; retain meaningful port tests and repair
invalid worker assertions. UI ownership remains original AgY, no release/push.

## Acceptance

- Line-immediate bounded rolling worker log, sanitized current command/times,
  lightweight task refresh independent from environment/deployment reconciliation.
  Frontmost task polls each second, other busy tasks each3s; retain output/state
  on network loss and never replay operations. Old task JSON remains readable.
- Official catalog transport/5xx fallback to same upstream gh-pages via GitHub Raw;
  no fallback TLS/content failures, no custom-source rewrite. Retain cached list,
  classify failure, list/grid choice persisted without resetting filters.
- New installation explicitly chooses default localhost/all-interface access;
  per-port nullable bindAddress overrides default. Existing records retain old
  default binding. Configure/restore/merge paths preserve all overrides. Explain
  SSH tunnel vs direct URL; never automatically change firewall or open ports.
- NAS sort name/date/size via stable indexed cursors; preserve view context per
  source/category. Bounded batch favorite/playlist actions, failed-item results,
  metadata display, playback error/restore, visible scan and offline/cache status.
  No raw file deletion, new transcoder, scraping or new download engine.

## Safety / validation

Use existing pinned isolated VM for actual worker/deployment lifecycle only.
Production endpoints read-only. New tests cover pipe buffering and terminal flush,
rotation, command redaction, old records, source fallback, per-port Compose and
NAS sorting/source race/partial batch. UI narrow/large text/RTL and full suite
before release-mode compatible-signature APK and preserved-data ADB install.
Document measured results; installation alone is not functional acceptance.

Initial evidence: identical awk+fflush pipeline emitted an immediately written
line only after upstream exited2s later. Worker stops logging after first256KiB;
poll calls full inspect/reconcile before publishing all results. Catalog retains
cache already. Binding defaults127.0.0.1; app opening uses SSH forwarding.

## Verification checkpoint (not final acceptance)

After explicit user validation exception, root/team validated:
- catalog45passed/1defaultnetworkskip, plus separately enabled live Chinese
  official catalog+template test1passed (3seconds);
- port/Compose/access58passed;
- taskprovider/persistence29passed (includes5new single-source retry cases),
  taskreaderprotocol/security24passed;
- worker shell syntax+actual livepipe/partial/CR/rotation/exit/cancel39passed;
- NAScore27passed, including new emptylastpage and changed-source retry fixes;
- 100k legacy SQLite migration2.353s; indexed200-row query sample60pages,
  p50=1.639ms,p95=2.076ms; RSSdelta6,533,120bytes. Container measurements only;
- pinnedVM install/reconnect/stop/start/configure/restart/update/restore/uninstall
  1passed in4m25s, data retained (vm-round.log). The actual installed application
  is the isolated nginx:alpine two-service fixture, with loopback/public interface
  behavior and busy worker command/log timestamps verified. Nginx Proxy Manager
  only passed template/configuration preflight; its full real installation was
  NOT exercised. No production target modifications.

Focused core/static analyses clean. Full UI/full-suite gate NOT yet complete:
AgY current UI draft has compiler and access-wiring defects being returned to
the original session. No new round APK, no ADB installation, no release/push yet.
All logs in /tmp/valhalla-apps-nas.wCun9l. ADB127.0.0.1:14251 available,16GiBfree.

Next checkpoint: non-UI full directory suite2063passed/20environment skips
(62seconds, non-ui-suite.log). Single-source catalog retry adds5provider cases,
provider/persistence now29passed (task-provider-focused.log); do not add those5
to the earlier non-UI run's count or label that run as the full application suite.
UI tests exposed real anchor/SSH routing/URI/
layout/source-identity/debounce defects. First AgY invocation interrupted solely
to deliver consolidated evidence; same conversation/model/effort resumed
(agy-fix.jsonl). No UI edits by root/team. UI test fixture corrections reflect
actual CustomScrollView and explicit access selection, not relaxed behavior.
This remains an intermediate checkpoint: AgY UI work is unfinished; this round's
APK has not been built or installed. Prior installed packages are not this round's
deliverable, and core/VM passing results do not stand in for UI/device acceptance.

ADB pre-install checkpoint: installed1.0.4/code4005,lastUpdate2026-10-12T17:17:44.
Pulled APK to private scratch installed-before.apk (application binary only,
no user database/credentials): SHA256
28c1d991257770fb32f01fdb76e0ba22789d67d07727ee5b738e2c2929295927.
Installed certificateSHA256
2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9
(original AndroidDebug). Build a matching-signature test APK only after UI/full
gates; this is not the formal release certificate and must not be published.

## Current pause: AgY account quota

The original conversation completed the narrowed NAS UI batch. Its next process,
same conversation/model/high, failed before changing Application Center with
`RESOURCE_EXHAUSTED` / individual quota, reported reset in26h45m16s. Log:
`agy-apps-close.jsonl`. User has been asked to switch/login the account; no new
conversation, model or UI author is authorized. Preserve this checkpoint.

NAS source/search/category-tile selection/metadata regressions now pass. The two
NAS UI files finish51passed/2failed (nas-ui-final-interim.log): the320dp/2x batch
toolbar inner Row still overflows, and Home's photo tile opens the viewer while
selection mode is active. Both remain assigned to AgY. Application Center
deep-scroll anchor, per-source retry wiring and target-changed explanation remain
in `2026-10-12-apps-nas-ui-final-check.md`. Full `flutter analyze --no-pub` is clean
(analyze-checkpoint.log), but analysis is not evidence those interactions work.
No new APK built or installed; no push/release. Only resume build/install after
AgY fixes and final UI/full-suite verification. Latest user exception allows
root verification/build/install, not UI modification.
