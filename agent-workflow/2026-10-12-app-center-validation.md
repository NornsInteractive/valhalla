# Application center validation contract

Run only explicitly free OpenCode models. Root and AgY own implementation;
validator may add focused tests, generate official Flutter localization, resolve
dependencies, format the changed app-center core/UI sources, analyze and test.
Never edit authored UI/ARB files, business logic, native files, production
servers or users' actual Docker/agent history. No Git, release or version bump.

## Gates

1. `flutter pub get`, official `flutter gen-l10n`. Preserve dependency lockfile.
2. Focused tests for CasaOS v2 catalog envelopes/prefix paths/duplicates/HTTPS
   boundaries; Compose parse limits/interpolation/literal dollar values/ports/
   bind mounts/named volumes/multiple services/unsafe privileges and relative
   mounts; JSON persistence omits secrets and logs, experiments default off,
   connection-identity routing and delayed provider results.
3. Exercise emitted worker scripts for ALL operations using `bash -n` on
   temporary files. Pure temporary fake-Docker fixtures may exercise failures,
   cancellation checkpoints, private configuration and state persistence; do
   not run the real bootstrap/install scripts or use the host Docker daemon.
4. Analyze project and report UI/core findings to root without fixing UI.
5. Once findings are fixed, focused then full Flutter tests. Report actual counts
   and environment skips; never reuse earlier stability results.
6. Only after zero analyzer issues and tests pass, build debug APK. Preserve
   existing version and debug signing. Read-only ADB device/certificate checks;
   only compatible-signature `adb install -r` on 127.0.0.1:14251. Never uninstall,
   clear app data, or run integration-test runners that replace configured data.
   If no device/incompatible signature, report rather than deleting data.

Real Docker installation/update/reconnect/rollback needs an isolated Linux
fixture, not an existing user server. State explicitly when it is unavailable.
Document generated outputs, exact gates, errors, and APK/ADB evidence here.

## Evidence

MiMo V2.6 Flash free, Step5 free and Space Bunny free each returned upstream
rate limit before validation; the MiMo retry also failed. Cached OpenCode model
metadata confirms Nemotron 3 Ultra Free input/output/cache cost zero. Using the
previously approved free fallback, its run is responding and has completed
`flutter pub get` and `flutter gen-l10n` successfully. No current app-center
tests, analyzer, APK or ADB install result claimed yet.

Existing isolated Debian VM assets remain in `/tmp/valhalla-test-vm`, no QEMU
process currently running. `/usr/bin/qemu-system-x86_64` exists, preserved VM
restart script uses its original qcow2 and known_hosts. Validator may bring up
ONLY this documented disposable fixture and test unique app-center resources,
never production servers. Do not log or commit credentials.json contents. Do
not delete/reinitialize the VM. Read existing isolated-environment guide first.

## Latest verified checkpoint and validation interruption

OpenCode's actual `flutter test --no-pub --reporter expanded` output records
**62 passed** for application_compose_test, application_worker_test and
application_catalog_test. These include real `bash -n` for all nine operations,
both Docker-present/absent bootstrap scripts, network aliases, expanded YAML
limits, privilege blockers and literal default-dollar escaping. The model's
written per-file counts were inaccurate; only the command's final count is used.
This is not the full project gate or real Docker acceptance.

The latest `flutter analyze lib` run found three storage flow-control lint infos,
not zero issues. Root added braces only; that correction and the endpoint switch
to freshly reconciled deployment metadata still need re-analysis. A prior clean
snapshot must not be substituted for the current source.

Original AgY completed stable controller keys, private installed-template caller,
and invalid/cleared-port checks before confirmation; no root-authored UI changes.
Cache/persistence/provider/widget/isolated-VM test drafts are **not accepted**:
some have compile/assertion problems and do not prove their stated conditions.
They are new task-owned, uncommitted files, preserved for the validator to repair,
not test coverage to claim. Never disable tests or alter production to appease
an incorrect fake.

Further cache/provider/VM OpenCode runs each terminated with
`unknown certificate verification error`. DeepSeek free returned upstream CLI
server errors; Big Pickle produced no events and was stopped. No TLS bypass was
used. Only specifically identified task-owned CLI processes were stopped; other
projects and the user's original sessions were untouched. Root has not assumed
the earlier task-specific direct-validation exception or an unanswered request.

OpenCode resumed the original pinned isolated QEMU VM and confirmed Docker
Compose v5.5.1. No app-center install/restore/uninstall service acceptance has
passed. The VM disk, credentials and data remain intact and the VM is left online
for resumed validation. Existing user servers were not modified. No current APK,
ADB installation, full-suite success, release, push or version bump.

## User-authorized direct verification continuation

User explicitly allowed root testing and packaging for this continuation only.
Authored UI remains original AgY; no TLS bypass or reuse of an older exception.
Five unfinished task-owned test drafts were backed up intact to the private
task log directory before replacement. The new small tests use actual models,
minimal HTTP streams and a shared fake-service fixture, not invented SDK APIs.

Root found and fixed a real image-cache self-wait: `whenComplete` returned the
removed in-flight Future itself. Cleanup now returns void; cache/singleflight,
oversize, offline and recovery cases run rather than timing out. Current focused
core suite: **74 passed**; real Inter-font mobile widget suite: **4 passed**.
Original AgY fixed compact wizard footer with OverflowBar and German cloned
mount-label text. Additional identical labels in es/id/it/pt are being returned
to the same session; test translation rules were not relaxed.

Pinned isolated VM actual service lifecycle passed twice, latest run **3m03s**:
install, HTTP request, saved private configuration/template, reconnect/read
original task ID, stop/start/configure, explicit update, restore previous
configuration/template/version, uninstall preserving the data sentinel. Only
uniquely identified fixture application containers were removed; data, images,
configuration and task files remain. No production servers were changed.

Whole-project analysis passed after test-draft replacement. First full regression
recorded **2580 passed / 19 skipped / 2 failed**, failures being the translation
label and an old navigation fixture omitting the new opt-in feature. The latter
is corrected and its 8 settings widget cases pass. Final full regression and
Android packaging are still pending; this intermediate count is not a clean gate.

## Final source gates (2026-10-12)

Root's final complete `flutter test --no-pub --reporter expanded` finished exit0
in **1m47s: 2582 passed / 19 environment-dependent skipped / 0 failed**. Log:
`/tmp/valhalla-app-center.ShesTL/full-final.log`. Final `flutter analyze` reports
**No issues found**, `git diff --check` exit0. The official `flutter gen-l10n`
regenerated all locales after original AgY fixed the actual labels in
de/es/pt/it/id/fr. Production Inter-font wizard tests remain four actual passes.

Latest pinned-VM run with a checked HTTP request (not a semicolon hiding curl
failure) passed exit0 in **3m03s**, all lifecycle stages logged in
`/tmp/valhalla-app-center.ShesTL/vm-lifecycle.log`. Docker bootstrap was not
installed on the already-provisioned VM; syntax/negative guard coverage does
not claim a fresh apt installation. No actual user Agent conversations tested.

Android builds started only after these gates, version remains **1.0.4+5**.
Previous three split release APKs and debug APK are backed up at
`/tmp/valhalla-apk-before-app-center.Kff7xq/`. The connected emulator's pulled
APK has native versionCode4005 and the existing debug certificate
`2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9`.
Device testing must therefore use the same debug certificate and non-downgrade
native version code; signed release artifacts remain separate and use the fixed
release certificate `73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d`.
No uninstall/data clear/signature migration/push/release/Actions authorized.

First signed build failed before compilation: global `/home/dev/.gradle/init.gradle`
adds project Maven repositories, contradicting Flutter SDK included-build
`FAIL_ON_PROJECT_REPOS`. Investigation verified this exact mechanism, SDK and
project sources were unchanged. Retry uses an isolated task Gradle user home
`/tmp/valhalla-app-center-gradle.mgpUTM`, reusing existing caches/wrapper via
symlinks but not the global init script. No global Gradle configuration edits,
cache deletion, SDK modifications or TLS bypass. Separate retry log is
`/tmp/valhalla-app-center.ShesTL/android-signed-build-isolated.log`.

The isolated `--no-pub` retry exposed stale generated Android plugin registration
including the dev-only integration_test plugin. Repeating the official release
build with normal pub/tooling generation (no `--no-pub`) correctly excludes dev
plugins; no native generated code was hand-edited, SDK/Gradle files remain intact.
Final signed build finished exit0 in **56.2s** and produced ARMv7/ARM64/x86_64
APKs (44.5/46.3/51.3MB). Separate frozen signed copies live in
`build/app-center-validation/`, not overwritten by the device-test signing run.
Normal generation did not bump versions or upgrade dependencies.

All three frozen signed APKs passed `apksigner verify` and exact fixed
certificate SHA256 matching. Package is `com.antigravity.valhalla.valhalla`,
versionName1.0.4, native versionCodes1005/2005/4005 for ARMv7/ARM64/x86_64.
`build/app-center-validation/SHA256SUMS` was verified with `sha256sum -c`.
The separate x86_64 Release-mode device-test APK built exit0 in **58.9s**,
verified the original device debug certificate and versionCode4005. Compatible
`adb install -r` was issued, but installation/launch acknowledgements are pending
while emulator shell responses are slow; do not claim installed/booted yet.
No uninstallation, downgrade flag, data clear or global ADB reset was used.

Device read-only `shell uptime` and `logcat -d -b crash` each timed out at20s,
although `get-state` still returned device. Install had no acknowledgement after
4min. Only validated task-owned client PIDs767491/767534/767536 were terminated;
global adb server/transport and other projects were left untouched. Remote install
commit status remains **unknown**; resume by reading package update time and
signature before any repeat installation. ADB startup/UI/device performance is
not claimed. Test APK SHA256:
`bd9007b26fb21b707d48c57b54c5f7502021405829b9602d5cb09715d1a7790f`.

## ADB recovery and completed installation

User reported ADB restored. Read-only package inspection and pulled APK SHA256
proved the previous unacknowledged attempt had not replaced the old installation:
old hash1508e446162fe22c449520d883081fb6f396ebf8b1008b7473dd339c9de4ca0c,
lastUpdateTime2026-10-11 17:19:25. Old and new APKs both verified the same debug
certificate before retry, with native versionCode4005 (no downgrade).

`adb -s 127.0.0.1:14251 install -r` returned **Success**. Installed base.apk SHA256
is now exactly `bd9007b26fb21b707d48c57b54c5f7502021405829b9602d5cb09715d1a7790f`.
Package lastUpdateTime2026-10-12 11:17:45; firstInstallTime2026-09-23 03:26:04
and original app identity retained. No uninstall, data clear or signature changes.

`am start -W` reported Status:ok, LaunchState:COLD, TotalTime988ms. Process2733
remained live; screenshot and UI hierarchy show the dashboard and existing saved
server configuration/connection. Checked process log window contained no matching
FATAL/Unhandled/E/flutter/ANR entries. Evidence is stored privately alongside logs
as adb-recovery.png/xml, not published. This proves install/startup smoke only,
not a physical-device performance or all-screen interactive acceptance. Application
center remains opt-in; no experimental switches or server operations were changed.
No rebuild, push, release or production application installation during this
recovery continuation. It supersedes the earlier unknown ADB outcome.
