# SSH stability, NAS redesign/offline, files and application center

User approved this implementation plan after selecting a media-first NAS home and
including persistent offline downloads. Preserve all pre-existing worktree edits.
Version remains 1.0.4+5; no push, release, Actions or data clearing.

## Ownership and acceptance

Validation exception: user explicitly approved root completing this round's
remaining tests, packaging and preserved-data ADB install after OpenCode free-model
rate limits. UI ownership remains original AgY; no release/push/version change.
MiMo and Big Pickle errors confirmed in OpenCode operational log at 05:29:35 and
05:34:16 UTC: AI_APICallError / Rate limit exceeded. Last free-model availability
probe is recorded separately before taking over verification.
Nemotron completed batch27/nav2 and exposed a NAS fixture failure, then repeated
two long stalled widget runs without repairing the fixture. Root used this round's
explicit verification/build/install permission and stopped only that task's CLI
and child test processes. No other project processes were stopped. Root found the
actual fixture defect: one Notifier instance reused across tests; a single-use
stream teardown then waited indefinitely after failed initialization. Fixtures
now construct a fresh notifier and use a broadcast loading stream. No assertions
were removed. Actual scan-dialog responsive overflows were then revealed and
returned to original AgY; product UI ownership remains unchanged.

Root: core/data/infrastructure, dependency patch and documentation. UI/interaction/
ARB: original AgY Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b only, model
gemini-3.8-flash-high, effort high. OpenCode: tests, generation, analysis, builds,
artifact verification and compatible-signature ADB installation; explicit
opencode/mimo-v2.6-flash-free, verified-free fallbacks already user-authorized.
Previous root validation exceptions were task-specific and are not reused here.

1. Reproduce and fix unhandled SSH errors at owning layer. Local diagnosis already
   reproduced a dropped SFTP subsystem request using actual dartssh2 4.1.0 without
   a network server. Latest device stack alone does not identify its caller.
   Maintain genuine-error diagnostics; do not ignore SSHStateError globally.
2. NAS: content-first home, five local destinations Home/Photos/Videos/Music/Library;
   Library owns folders/favorites/playlists/offline. Compact source/search/manage
   controls, full-screen mobile forms, theme/locale/RTL support, existing global
   mini player. Preserve all source/index/favorite/position data and experiment gates.
3. Offline: durable task state, pause/resume/retry/restart, two downloads maximum,
   resource identity validation, atomic completion, local playback without server.
   Restore unfinished tasks paused. Never join bytes from a changed source; no HLS
   segment-packaging, cache eviction cannot delete offline files.
4. Files: reuse bookmarks/multiselect/batch APIs; add per-server last20 directories,
   failed-items-only retry with fresh target/source validation; preserve selection,
   scroll/search/hidden-file behavior and existing transfer persistence.
5. Applications: structured Docker health, free-space preflight, compatibility
   summary, manual catalog update comparison and task reconciliation. Never implicit
   upgrade or destructive data deletion; restoring config does not restore databases.

## Verification and rollout

Actual-protocol failures must be caught, pending work must settle, late callbacks
must not change a replacement connection. Use existing isolated pinned VM only;
do not run failure injection on user servers or send real Agent messages.
Cover persistent download restart/source mutation/range refusal/disk errors/offline
playback, incremental DB migration, bounded media home reads, source races,
batch partial results and Docker health. UI 320dp/large-font/RTL/desktop tests and
full analyzer/test gate before Android build. Keep release certificate separate
from emulator's existing debug certificate; install -r only, no downgrade/uninstall.
ADB was unavailable during planning; record actual availability at install time.

## Evidence

Completed: final analysis zero issues; full suite2647 passed/19 environment skips;
46 focused UI/offline/terminal regressions passed. Three official-signed Android
APKs built, separately signed compatible emulator APK installed with `-r`, exact
device hash confirmed and original firstInstallTime preserved. Startup, remote
file listing and short background-return smoke completed. No release/push.
See [durable final evidence](2026-10-12-nas-refresh-final-verification.md) for
artifact hashes, commands, ownership and explicit unverified limits.

Incremental evidence below records earlier stages, not the final status.

2026-10-12 SSH proof (OpenCode MiMo): corrected seven-test actual-protocol regression
on isolated hosted dartssh2 4.1.0 => 3 passed / 4 failed, exit1. Same test against
vendored patch => 7 passed / 0 failed, exit0. Logs:
`/tmp/valhalla-nas-refresh.OOGiIt/sftp-subsystem-hosted-baseline-rev2.log` and
`/tmp/valhalla-nas-refresh.OOGiIt/sftp-subsystem-vendored-baseline.log`.
Earlier send-failure fixture buffered before key exchange; corrected injection is
through printTrace on the outgoing message inside the same send try/catch, not
weakening assertions. Broader gates remain pending. The invalid initial NAS test
draft was replaced by verified-free OpenCode Big Pickle, then actually executed by
OpenCode MiMo: 6 persistence tests, 8 HTTP validator tests, and all 7 SSH tests pass
in fresh-* logs. Old failure-removes-partial expectation is being updated to the
approved non-destructive retention contract; it is not a product regression.

AgY phases C/D authored compile-error fixes, async task failure handling, native
notification acknowledgement/weak Activity reference, error localization and
restoration retry. These are not yet verified UI passes. New files/apps regressions
are authored/static-clean; actual execution and responsive UI tests are pending.
The author's proposed environment-category defect was rejected: revealing the
category changed is required; revealing secret values is prohibited. Likewise
synchronous path validation is an intentional API contract, not a runtime defect.

ADB read-only inventory now confirms 127.0.0.1:14251 device, sdk_gphone64_x86_64.
This is connectivity only, NOT a new build/install/functional result. Preserve data
and verify installed certificate before any later authorized compatible replacement.
