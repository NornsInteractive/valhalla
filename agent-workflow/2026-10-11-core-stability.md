# Core stability and frequent-operation performance

## Current status

Implementation and local gates completed at 2026-10-11 15:26 UTC, starting from
clean baseline `f71d906`. Final full suite: 2504 passed, 18 environment-dependent
skips, no failures, exit0; final analyzer exit0, no issues. The previous public
release remains 1.0.4+5. No build, installation, publication or remote push in
this task. Device and real-service acceptance remain separate, below.

## Accepted scope

1. Connection lifecycle: background/lock/network recovery preserves same-target
   visible data, drafts, selections and scroll. Cold start uses existing stored
   state and cache labels. Do not replay prompts, approvals or remote commands.
2. ACP: bounded long-history rendering, ordered stream/tool events, user scroll
   intent, model rollback, cancellation and recovery of the original session.
3. Files: 1,000/10,000-entry filtering/sorting/view changes, same-directory
   refresh retention and isolation of late responses after navigation.
4. Updates: actual application ABI, per-package hash/signature, interrupted
   download, wrong package rejection and data-preserving compatible installation.
5. Diagnostics: bounded, local, sanitized operation timing without credentials,
   chat bodies or file contents; distinguish current status from old evidence.

NAS persistent/offline downloads are deferred. Android is the primary target;
desktop source compatibility is required. Physical Android, native Windows and
real ACP need explicit evidence and cannot be inferred from simulated checks.

## Ownership and method

Codex owns core/data/infrastructure/native/docs. UI belongs only to original AgY
Valhalla `ec81a4be-7543-45ee-8658-f68966f57d3b`,
`gemini-3.8-flash-high`, effort high. Tests, formatting, analyzer and any local
build/ADB checks belong to OpenCode: explicit MiMo2.6 free main/small first,
previously authorized confirmed-free fallback only. No paid model or subagents.
All three confirmed-free OpenCode choices were rate limited; the user explicitly
allowed root regression authoring, formatting, analyzer/tests and measurements
for this task only. Future ownership is unchanged. UI was implemented only by
restarted original AgY, including a follow-up prompted by a failing widget test.
Capture a reproducible mechanism before editing. Preserve unrelated user changes.

## Acceptance

- Lifecycle: 10-second, 5-minute and 30-minute elapsed-background cases via
  controlled time; concurrent resumes, failed probes, target changes, explicit
  disconnect and process-restart cache behavior. No 30-minute blocking waits.
- ACP: 10,000 historical messages with bounded pages, burst text/tool updates,
  late/duplicate events, approval, cancellation and same-session recovery.
  Current development-agent histories are read-only; no production prompts.
- Files: raw list unchanged, ordering/filter semantics preserved, cache invalidated
  only by list/filter/sort/root changes, rapid navigation drops stale results.
- Updates: interrupted partial, integrity/identity failure, stale metadata and
  provider lifecycle races. Mock installation is not real installation proof.
- Add focused regressions, nearest affected checks and one full final suite.
  Record exact exits, skips and reasons. No repeatedly broadening green checks.

## Investigation findings

- `SftpState.filteredFiles` currently filters and sorts on every read, including
  transfer-progress and loading-only state changes. Large directories therefore
  repeat unchanged work; investigate baseline before selecting a cache fix.
- Existing update service already implements Range resume and SHA256 verification;
  this scope validates and fixes gaps instead of adding a second downloader.
- Existing connection coordinator coalesces resumes and guards target epochs;
  inspect in-flight lifecycle transitions before changing recovery architecture.
- Existing ACP stream throttles visible updates to 50 ms and checkpoints at 2 s;
  retain these contracts while investigating history and stream bottlenecks.
- Distribution architecture names are API identifiers, not package filenames:
  Ygg's current dashboard/client inference intentionally uses arm64-v8a for
  Windows/Linux ARM64 too and apple-silicon for macOS. Confirmed against local
  yggdrasil src/routes/clientApp.ts and src/views/dashboard.ts; preserve mapping.

## Delivered changes

- SFTP filtered/sorted projections are immutable and weak-key cached by raw list
  identity plus filter/sort/root parameters. Harmless state changes reuse them;
  changing inputs recomputes. Existing directory-first/dot/hidden behavior stays.
- File scroll storage is isolated by connection key, path and list/grid mode;
  same-path refresh keeps the list mounted at the same viewport height. Selection
  survives refresh but clears when path or connection identity changes.
- ACP prepend detection uses the absolute message offset rather than scanning
  messages on every update. Initial asynchronous history scrolls to latest;
  older-page prepend compensates position, output follows only near bottom.
  Delayed scroll callbacks check mount, session, Agent and server identity.
- Update opens are single-flight; after file verification, stale release/download
  epochs or disposal suppress native launch. Existing integrity/ABI/signature
  checks and resumed downloader are retained, not replaced.
- Connection resume uses an injectable clock for deterministic background cases,
  retaining the existing epoch/health single-flight implementation. Local timing
  instrumentation covers resume, ACP initialize/history/recovery, SFTP listing and
  update check/download using fixed labels and the bounded sanitized logger.

## Fresh verification evidence

Logs: `/tmp/valhalla-core-stability.j0LVyR` (local diagnostics, not release assets).
Detailed commands and ownership exceptions are in
[validation report](2026-10-11-core-stability-validation.md).

- Early directory/sort/diagnostics gate: 20 passed; updater/lifecycle/repository:
  49 passed; isolated directory benchmark/cache gate: 6 passed; nearby recovery,
  ACP protocol/rollback and HTTP update gate: 190 passed, each exit0. These overlap
  with the final suite; do not add them to the final total.
- UI regression first run: 46 passed, 1 failed, exit1. Same-session history that
  arrived after an empty summary remained at 0 instead of latest extent 2693.
  AgY corrected this; final UI gate including prepend: 48 passed, exit0.
- Final `flutter analyze --no-pub`: no issues, exit0.
- Final `flutter test --no-pub --reporter expanded`: 2504 passed, 18 skipped,
  0 failed, exit0, 94 seconds. No VM/E2E environment was configured, so destructive
  or real-service fixtures did not run on user servers.
- Same-host default-name projection benchmark, warmup followed by 20 uncached
  equivalent computations and 200 cached reads: 1000 entries 593.45 vs 0.24
  microseconds/read; 10000 entries 4352.45 vs 0.24. Exact result ordering compared;
  no wall-clock pass threshold. These are cache-hit CPU timings, not network
  listing time, full rendering time, mobile frame rate or sustained guarantees.
- Final repository fixture: 10000-message save 258ms; latest50 read 10ms;
  list30 and deep-offset summaries each 5ms, on this host's temporary DB only.
- `git diff --check` clean; formatting applied only to affected Dart files.

## Unverified and deferred

ADB inventory shows only emulator `127.0.0.1:14251`; the current source has not
been built or installed there. Physical phone keyboard/lock/network/frame-rate,
native Windows installation and real ACP/OAuth conversations remain unverified.
The 18 skips cover isolated operations/NAS/SSH-SFTP VM, real WebDAV/mosh and power
fixtures. Existing mock protocol tests are not substitute proof for remote Agents.
No development-agent prompt/history or user credentials were changed. NAS offline
downloads, additional dependencies, a new recovery architecture and publishing
were deliberately not added.
