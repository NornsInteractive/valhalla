# OpenCode regression authoring and validation

User approved apps/NAS reliability plan. Only explicitly free main+small model.
Own test/** only. No subagents, no product/UI/ARB edits, no git/version/publish,
build/ADB yet. Preserve ALL prior tests and work; use apply_patch edits. Never
weaken safety checks or delete tests. Report product failures to root, not fix UI.
Full plan and contracts in apps-nas-reliability.md and apps-nas-ui.md same folder.
Scratch /tmp/valhalla-apps-nas.wCun9l for logs; real exit codes, no masked pipelines.

First author/update focused core regressions below, run ONLY focused core tests
while AgY writes UI. No l10n generation/analyze until root asks later.
MANDATORY runner: /opt/flutter/bin/flutter test --no-pub --reporter expanded
<test paths>. This is Flutter, NEVER dart test and NEVER pub get/upgrade. Do not
mask exit with head/tail pipeline. A previous lightweight model wasted calls on
dart test (dart:ui errors); do not repeat this unrelated tooling mistake.

1. ApplicationPort optional bindAddress old JSON compatibility, mixed external
80/443 +SSH-only81, merge/changeVariables retain override, bad values rejected;
webPort must prioritize target81 over unrelated target80 remapped published81.
Deployment preflight now ss -H -ltun distinguishes protocol/address, old apps
require real Docker binding ownership before exempting used port. Update fakes
honestly using current command contract, not catch-all success. accessInfo fixed
loopback curl, missingcurl=unavailable; actual mappings shown, no mutation.
2. workerScript no longer awk/stop-first256KiB. Local Bash fixture with fake docker
in PATH can validate first output arrives while command still running, final
no-newline output, CR, rotation keeps last output, command and exit status metadata,
finish waits logger flush. Follow existing actual worker test fixture, never real
production Docker. Update old literal '[log truncated]' assertion to real bounded
latest-output behavior, do not simply drop it. ApplicationTask metadata optional;
command/log deliberately NOT persisted locally. lightweight refreshTasks must not
inspect/reconcile everysecond; transport failures retain stage/log +syncError;
reconnect no relaunch. Root currently editing these two files; run after stable.
3. Catalog fake responses keyed full URI required to distinguish hosts. Register
cached(official), then store/index/template/image fallback DNS/503. No fallback
401/404,TLS,corrupt JSON/oversize,custom source even if sameID. image(sourceId:)
required. Primary/raw ETag never cross host/locale. Old SocketException expectation
now typed APP_CENTER_SOURCE_NETWORK. Cache retained after failure.
4. NAS queryPage gains sortKey/sortAscending named options; patch fake overrides
in nas_offline_provider_test honestly. refresh gains preservePosition=true;
old refresh overrides must accept parameter. Explicit filter/sort resets page;
manualrefresh retains page. Test name/date/size directions with ties/no duplicate
pages, migration preserving favorites/playback/downloads,100k synthetic rows
bounded page perf. Batch favorite max3, playlist edits serial, partial failure,
failed-only retry, mixedsource rejection, source switching isolation. Per-source
category A-B-A restores scope/search/sort/page.

Start with reading existing fixture APIs, then create focused tests in small
steps and actually run each. Do not invent constructors/imports or use regex
to rewrite whole test files. Report exact tests passed/failed/skipped and logs.

Review addendum: worker readTask liveness now sampled BEFORE state to avoid
busy+just-exited falselyfailed125. needsInspection observed polls promptly and
completion refreshes app list; persistence errors caught. Cancellation/flock fail
terminal status only in finish afterdrain. NAS sameID source replacement invalidates
cached contexts, remote-success stale favorite never writes newsource/player;
local playlist ownership missing now throws with requireOwnership:true (new
optional parameter for repository fake overrides). Same-source changed requests
completed remotely should not be retried as failure. Manualplaylist order hides
media sort. Product bodies currently stable, UI still being authored.
