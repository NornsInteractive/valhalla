# Shared remote browser, application data and NAS — approved implementation

## Authority and boundaries

Latest user authorization: “本轮UI由你负责”. Root/internal collaborators now own
the remaining UI as well as this round's already-authorized testing/build/ADB.
The earlier AgY-only clauses below describe prior ownership and are superseded
for this round only. No external agent is modifying these UI files concurrently.
Current delivery evidence will be recorded in `2026-10-13-ui-takeover-results.md`;
older green/red results below remain historical until rerun.

Round-specific update: user explicitly authorized root to supplement regression
tests and directly verify/build/retain-data ADB install after OpenCode tool-format
failures. Existing OpenCode work is preserved; its three active test writers were
stopped before reassignment to avoid concurrent edits. UI/ARB remain AgY-only.
No push/release/version/signing/data-clear expansion is authorized.

User approved the plan after choosing: whole instance data root includes unmounted
files; main container matches instance name and sidecars use name-service; remote
pickers share UI while local file upload/export keeps the OS picker; include NAS
source-aware browsing and the two demonstrated deployment reliability fixes.
Preserve this dirty worktree. No version bump, push, release, production writes,
credential rotation, APK uninstall/data clear or signing replacement. UI/ARB stay
with original AgY Valhalla. OpenCode initially owned validation; the explicit
round-specific exception above now permits root verification/build/ADB.

## Ownership

- Root: catalog refresh single-flight/state merge, documentation, integration and
  the newly authorized regression/verification/build/ADB work.
- app_cleanup_naming: application model, compose/deployment and cleanup helper.
- nas_browse_adapters: NAS adapters, source adapter model, scan service and SMB Dart.
- browser_core_contract: remote browser model/service/provider, ACP workspace files,
  NAS source provider transient browsing and identity isolation.
- AgY: UI, interactions and all locale catalogs. No core/test edits.
- OpenCode: regression authoring, generation/format/analyze/test/build/ADB; no UI
  fixes or remote production operations. Each actual gate must be recorded.

## Acceptance

1. Uninstall offers whole dataRoot and individual mounts, all initially unchecked.
   Whole-root includes unmounted content; children covered once, no duplicate
   removal. Explicit name/risk confirmation. Source from installed config only;
   revalidate target/config/inode/mount/shared refs. Preserve system/shared/link/
   nested-mount/named-volume protection and retry-only-original-selected scope.
   Show exact blocked reason and sanitized copyable details, not one generic label.
2. Extract actual remote file browser display into reusable Material components:
   compact breadcrumbs, own search row, hidden/sort/view, virtualized entries,
   bounded previews, selection footer. Host SFTP, agent Docker and NAS use captured
   read-only sources. Picker must not expose management actions/transfer state or
   mutate file-page navigation. Preserve no-such-path fallback only for ENOENT,
   restricted copy destinations, scope/session checks and no keyboard restoration.
3. New installs bind main container=name, others=name-service; main from single
   service/valid template metadata, else explicit user selection. Validate names,
   live/stopped conflicts and replicas; keep project/id/labels/network aliases.
   Legacy configs remain legacy. Preview active rename/recreation; rollback stable.
4. At normal scale320–599dp grid really has two columns and vertical cards; list
   remains horizontal. Large-text fallback can be one vertical card, not list UI.
   Preserve visible-item anchor, filters/selection and independent preferences.
5. NAS root/scan/deployment fields use same picker. SFTP absolute paths; SMB paths
   within endpoint share/base (rootPath default, not double prefix); WebDAV scan
   paths relative configured source root. Media services use accessible library
   names/IDs, root single all/library and scan include/exclude multi-select. Do not
   rewrite saved values or change empty-includes semantics. Literal paths, no glob.
   Excluded library IDs must exclude whole libraries; unknown old folder/item/path
   values retained; inability to resolve required exclusions must not broaden scan.
   Draft browsing never save/select/scan; changed endpoint/user cannot reuse secrets.
6. Coalesce per-source catalog requests; awaited completion means published result,
   full+single-source don't supersede each other, old scope cannot update new state.
   Existing native Jellyfin shows informational existing-install state, not generic
   failure; keep real blockers and core installation prohibition.

## Core UI contracts (being implemented)

ApplicationConfiguration: instanceContainerNames=false for legacy, mainService
optional; defaults() enables new strategy. Compose helpers serviceNames(template),
suggestedMainService(template), containerNames(template,config),
isValidContainerName(name). copyWith preserves the fields. CleanupTarget.isDataRoot
defaults false, merged with same-path bind. New errors CONTAINER_NAME_INVALID,
MAIN_SERVICE_REQUIRED, CONTAINER_NAME_CONFLICT, CONTAINER_REPLICAS_UNSUPPORTED
have APP_CENTER_ prefix. Exact code is authoritative once landed.

RemoteBrowserEntry(id,name,isDirectory,canEnter,sizeBytes,modifiedEpoch,
isSymbolicLink,linkTargetErrorCode,mimeType); filesystem IDs are paths, library IDs
are opaque with canEnter=false. RemoteBrowserSource exposes captured targetKey,
label, rootPath, initialPath, flat, isCurrent, list batch stream, optional bounded
preview and own disposal. RemoteBrowserSelection includes targetKey+entries.
NasSourcesNotifier.openBrowser accepts draft/saved source+credentials, keeps
existing secrets only for unchanged identity, and takes current-scope callback.
Factory signatures will be documented by their owner; do not invent UI SSH calls.

## Delivery gates

Regression tests for full-root vs child removal, shared/identity/TOCTOU protection,
new/legacy naming/aliases/rollback/conflicts, all picker callers and late scopes,
protocol roots/cancel/auth/library exclusion, literal glob characters, catalog
real-provider initialization race.320/360/390/430dp,2x/RTL and distinct x positions,
10k-item lazy rendering/anchor checks. UI snapshots, analyzer and full suite.
Only then compatible test-signed release-mode APK, pinned ADB retain-data install,
installed hash/time proof and fixture-only install/browse/uninstall device smoke.
Never label emulator acceptance physical-phone performance. Record actual skips.

Implementation in progress; focused gates below are real, but no new APK or
installation exists for this iteration.

## Integration checkpoint (not delivery acceptance)

Core contracts are now available; see browser/protocol handoffs for final APIs.
Directory request cancellation is per-read, not a whole-source shutdown. Cleanup
adds protected-descendant and external bind-alias checks. Scan roots retain explicit
child selections without duplicate traversal; unknown SFTP metadata is not treated
as a strong version or used to truncate reads.

OpenCode writers were stopped before the authorized root/internal-agent handoff.
Focused results: catalog36passed, application core194passed, browser/provider75
passed (then browser core expanded to23 individually), NAS72 plus SMB4passed,
locale parity9passed. Targeted core and test analysis is clean after brace/unused
parameter lint corrections. Do not sum overlapping re-runs as unique tests.

Pinned isolated VM integration is real:4passed, not skipped, covering actual Docker
inventory/name conflicts/aliases/network, lifecycle through restore/uninstall,
child-only and whole-root deletion, protected/shared descendants and named-volume
preservation. No production target used; exact fixtures/residuals are in
2026-10-13-app-data-vm-results.md. Only test-created disposable content was removed.

AgY implemented and corrected uninstall/naming forms, mobile AppStore grid and
existing-native information. Those four UI suites are **68passed**. Shared browser
is only partially complete: latest two-file widget run is11passed/5failed; files
can still confirm while loading/after partial-list failure, thumbnail rendering
and stale-source request deduplication still fail, and directory navigation can
leave preview permits stuck. ACP wrapper currently fails
compilation because of its remaining legacy body/imports. Main file page/NAS
callers are not yet migrated. Tests for SFTP/ACP/NAS callers are authored, not
marked passing. No full-suite green/build/ADB claim is made.

Latest fresh AgY CLI authenticated the currently authorized account using original
Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b and gemini-3.8-flash-high/high. That
request ended with a NEW service429 at step37566, reset2h44m48s. This is not a stale
pre-restart login inference; evidence is agy-component.log/jsonl in the directory
below. No credential files were modified. User was asked to restore an available
login or wait. UI-only ownership means remaining UI cannot be patched by root.

Evidence directory: /tmp/valhalla-browser-implementation.NXfb1raa. Resume small UI
batches via browser-component-only.md, browser-wrappers-only.md and UI-phase4.md
(all2026-10-13-prefixed in this directory), then full source/build/device gates.
Latest ADB read-only discovery still shows old installed update15:37:59; this turn
has made no install/launch/tap and has not reused historical APK evidence.

Known non-atomic pre-existing storage limitation: NAS credentials and source
metadata live in separate stores. The browser now invalidates old leases after a
successful secret write and blocks current-process use following partial saves;
cross-restart transaction recovery and cached playback adapters are not covered by
that browser guard. Do not claim an atomic credential/config transaction.
