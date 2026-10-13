# AgY handoff: NAS deployment, onboarding, diagnostics and storage

## Implementation checkpoint — 2026-10-13 (not final delivery)

- The original AgY Valhalla conversation remains
  `ec81a4be-7543-45ee-8658-f68966f57d3b`, model
  `gemini-3.8-flash-high`, effort `high`; UI edits remain AgY-only.
- `NasSourceDialog.initialDraft` is implemented. Selective uninstall selection,
  task results and explicit cleanup-only retry are implemented; the focused
  14-case UI gate and static analysis passed after fixing the narrow results row.
- Music grouping / Play All narrow-layout regression passed at 320dp / 2x text.
- Docker software profile is wired through `AppDetailsDialog` and all wizard
  configuration reconstructions. Four focused UI regressions and analysis passed
  after replacing the preview diff with actual deep-membership differences.
  The four `appCenterJellyfin*` labels are translated in all 17 locales.
- `nas_native_install_dialog.dart` is now present but is NOT routed from NAS.
  Its initial compiler and review/cancel/target-lifetime issues were patched by
  AgY at step 36596. The subsequent native widget gates passed 7/8 cases, including
  reopening an unconfirmed plan and changing targets while awaiting the service.
  The remaining 320dp / 2x review test has a 251px horizontal overflow in the
  unbounded Back/Edit + Confirm action Row at lines 961-992. AgY must wrap/stack
  those bounded actions without hiding text and remove three unnecessary `!`
  warnings at lines 452/454/456; no product compiler errors remain. The 16
  `nasNative*` labels currently exist only in en/zh.
- Whole-suite gate: 2950 passed / 25 environment cases skipped / 2 failed,
  actual exit 1. Only the missing locale keys and native review overflow failed;
  these tests remain required before building a new APK.
- The latest owned AgY process exited with a fresh quota error at step 36597
  (2h30m44s, exit 3), after the native patch was written. No AgY process was left
  running. Do not confuse this with historical aggregate EOF / quota reports.

Still required, in bounded batches: validate/fix native dialog; wire a Docker /
native chooser to both NAS deployment entries; remove legacy `servers.first`
new-install fallback; successful-deployment / existing-install source onboarding;
real source diagnostics and source-scoped cache/offline storage; complete all
new locale translations; then final validation, new APK and ADB acceptance.

Caller traps confirmed during this implementation:

- `refreshCatalog(sourceId:)` may return normally after writing `sourceErrors`,
  or no-op for a disabled source. Re-read source enabled state, exact catalog
  entry and `sourceErrors` after awaiting it; never silently enable a source.
- `applicationAccessServiceProvider` owns a persistent `NasSshTunnelService`.
  `forward(draft)` is valid; a dialog must not dispose this shared service or
  persist its temporary local endpoint into the new source.
- New source handoff after Docker success must resolve the exact successful
  task's `deploymentId` and captured server key, not the wizard's older fallback
  that matches any deployment with the same source/application.
- Connection keys are records; task server keys are hashes. Use the correct
  service/provider hash for task membership, and captured connection records
  for UI async lifetime guards. Native cancel/reconcile must also match the
  captured displayed task ID after awaiting the service provider.

Original Valhalla session/model/high only, taste skill as scoped in the master
contract. UI/interaction/ARB only, no core/data/tests or commands for validation,
format, generation, build, ADB or publication. Use short bounded rg/sed reads.

## Docker Jellyfin

Reuse AppDetailsDialog.show(application:) rather than making a second app store.
Require the currently connected activeServerProvider, capture connectionKey and
recheck after async work. Never servers.first fallback. If application center is
disabled ask first, then settingsProvider.notifier.setExperimentalFeature(
ExperimentalFeature.appCenter, true); do not change bottom menus/order.

Resolve catalog by exact sourceId ApplicationSource.official.id and app id
org.icewhale.jellyfin. Use cached state.catalog; when missing, refreshCatalog with
sourceId only and offer retry on failure. Do not silently enable an explicitly
disabled catalog source or substitute a title match.

Core supports an explicit Jellyfin software-decoding mode:

- ApplicationComposeService.supportsJellyfinSoftwareMode(originalTemplate).
- jellyfinSoftwareTemplate(originalTemplate) returns the reduced variant for
  diff/blocker preview. It removes reviewed GPU mappings and /opt/vc/lib,
  defaults /Media read-only. Other blockers remain enforced.
- notifier.defaultConfiguration(originalTemplate, jellyfinSoftwareMode: true).
- configuration.jellyfinSoftwareMode persists the choice. Always pass ORIGINAL
  template to prepare/build, not the transformed preview; core applies profile.

AppDetails currently disables install for devices. For this eligible official
template provide explicit software-profile choice, diff and explanation before
the install wizard; do not globally ignore blockers. Wizard must retain chosen
profile and generate defaults through above API. Existing configure/update
preserve choice. No GPU passthrough this iteration.

## Native host Jellyfin

New nas_native_install_provider.dart exposes nasNativeInstallServiceProvider
(FutureProvider) and nasNativeInstallTaskProvider (StreamProvider).
nas_native_install_service.dart exports the public types. Use
NasNativeInstallRequest.forServer(activeServer, mediaPath: absolutePath).

Service prepare(request) returns plan. Display exact server, OS/version,
architecture, pinned packageVersion, commands/steps, blockers and guidance;
confirmation only when plan.canInstall. execute(plan.confirmationToken) starts
durable task and returns; subscribe task provider, don't report success on return.
Task contains stage/currentCommand/logTail/errorCode/requiresReconciliation,
canCancel/isBusy/result. requestCancel is checkpoint-based; never claim it kills
apt/dpkg immediately. reconcile()/refresh() inspect only and do not restart install.
Dismissing UI cannot cancel the package operation. If server changes, disable
old-target actions; never operate against the newly selected target accidentally.

Support Debian/Ubuntu amd64/arm64 + systemd + root/sudo-n only. No sudo password
input or unapproved install script. Existing installs are check/connect only,
not overwritten/upgraded. Show readiness/blockers honestly; user handles any
manual follow-up. Native first deployment binds remote127.0.0.1:8096 via SSH.

## Deployment → source

Successful Docker Jellyfin task or healthy native result offers official web
setup and Add Source. Reuse existing tunneled web-open behavior. Don't bind
source to the phone's ephemeral tunnel port. New NasSource initial draft contains
type jellyfin, remote endpoint, sshServerId and a stable NEW id; credentials blank.
Add separate initialDraft argument to NasSourceDialog.show/constructor: its
existing source argument means EDIT and must not be reused for a new draft.
User initializes server, authenticates/probes, explicitly saves in existing secure
storage flow. Do not auto-create accounts or persist credentials in diagnostics.

## Connection/scan and space

New nasSourcesProvider state.diagnosticFor(source) has NasConnectionDiagnostic:
stage credentials/tunnel/checking/ready/failed, updatedAt, lastSuccess,
errorCode, httpStatus and sanitized diagnosticText. Explicit probe uses existing
notifier.probe(source,credentials,keepEmptySecrets:) and records real stages;
do not run probes automatically from build(). Unknown counts stay indeterminate.
Diagnostics bind the full source configuration; testing an unsaved edited draft
does not replace the saved source's diagnosis or inherit another endpoint's success.
Core scan fields documented in nas-core-ui-contract. Provide a copyable diagnosis
sheet combining these real fields, not simulated progress or fabricated logs.

Cache API documented there: thumbnailCacheUsageBySource map empty key is legacy.
In library settings show selected-source bytes/count, separate legacy entry and
confirmed source-specific clear. Global budget remains global. Cache deletion
never deletes offline media. nasDownloadsProvider exposes all NasDownloadTask;
group/filter on task.item.sourceId, show recorded received bytes separately
from thumbnail usage (not an exact OS disk-allocation claim). Reuse existing
download sheet and remove(taskId) with separate explicit confirmation.

All newly visible labels must support current locales, narrow320dp/2x/RTL and
desktop; keep existing theme/global mini player/navigation. OpenCode generates
localizations and validates after AgY finishes ARB changes.

## Small sequential UI batches — caller audit 2026-10-13

This is an implementation handoff, not completion evidence. At this audit the
two NAS deployment entries (source menu and empty state in nas_media_view.dart)
still call the legacy NasInstallDialog. No UI caller exists for initialDraft,
jellyfinSoftwareMode, nasNativeInstallServiceProvider, inspectUninstall or
cleanupResults. Preserve the ongoing gallery work; do not redraw it again.

### First bounded prerequisite: source draft only

Change only nas_source_dialog.dart. Add optional NasSource? initialDraft to its
constructor and show(), mutually exclusive with source. Initialize form fields
from source ?? initialDraft, but retain _isEditing = widget.source != null.
Create ONE dialog-scoped ID from source?.id ?? initialDraft?.id ?? Uuid().v4();
_buildSource() must reuse it for authenticate, probe and save. Do not generate a
fresh ID on each call. Credentials of a new draft remain blank; keepEmptySecrets
must remain false for drafts. Preserve an explicit initialDraft.sshServerId and
never replace it with active/first saved server. For a new SSH source without an
explicit draft, use only an actually selected active server; otherwise require
the existing server picker. Remove first-server fallbacks in initialization and
type/tunnel toggle handlers, without changing an explicitly edited source.

This batch needs no new visible copy: reuse nasAddSource/nasEditSource,
nasAuthenticate/nasProbe/nasSshServer/nasEndpoint and existing validation. It is
only the safe prerequisite for the later Add Source buttons, not onboarding done.

### Docker software profile: two existing UI files

In app_details_dialog.dart offer an unchecked explicit software profile ONLY
when ApplicationComposeService.supportsJellyfinSoftwareMode(_template!) is true.
Use jellyfinSoftwareTemplate(original) for reviewed mapping diff and remaining
blockers; keep original _template for the wizard. A throw/unknown mapping blocks
that profile rather than skipping validation. Do not bypass arch/server checks.

In app_operation_wizard_dialog.dart add a false-default initial profile argument
for new installs, and take persisted initialConfiguration.jellyfinSoftwareMode
for configure/update. Pass the selected value to EVERY defaultConfiguration call
and EVERY ApplicationConfiguration reconstruction (current code has three of
each). Retain it through variables, mount/port edits and final prepare. Do not
replace the stored original template with the transformed preview. Reuse the
existing review, mount read-only and plan-diff layout; only profile label and
hardware-removal explanation need new localized copy.

### Deployment routing: replace the two NAS entry calls, not the app store

Add one small deployment chooser widget; both nas_media_view.dart entries open
it. Require connected activeServerProvider and guard captured connectionKey.
Docker action resolves exact official source/id, optionally asks to enable
ExperimentalFeature.appCenter, then AppDetailsDialog.show(application: entry).
Use cached catalog first, otherwise refreshCatalog(sourceId: official.id). Source
disabled/unavailable gets an honest error/retry, never title-based substitution
or silent source re-enabling. Experimental enabling must not modify menu order.

Native action opens a separate narrow native-task dialog. Keep existing legacy
NasInstallDialog available for its old task reconciliation; do not convert old
Docker task models into native models. Any retained legacy new-install action
must also lose its servers.first fallback. Reuse nasInstallTitle and existing
app-center enable confirmation where appropriate; add only distinct Docker/app
center versus native-host option descriptions at this step.

### Native dialog and shared successful-deployment handoff

New native dialog uses ref.watch(nasNativeInstallServiceProvider) and
ref.watch(nasNativeInstallTaskProvider). Prepare with
NasNativeInstallRequest.forServer(activeServer, mediaPath: absolutePath), review
plan.steps/blockers/guidance/os/osVersion/architecture/packageVersion (localize
the step/blocker/guidance codes, not raw keys), then call
execute(plan.confirmationToken). Render task state/currentCommand/logTail from
the stream; execute returning is not success. Reopening observes recovered task;
reconcile/refresh is read-only. Cancellation is requestCancel() at safe checkpoints,
not killing apt/dpkg. Never reuse the old "starting container" or "pulling image"
labels for native stages. Reuse generic prepare/review/health/failure/log labels;
add native package-install/service-start and existing-install messages. Native
media input needs honest copy (no permission changes), not "read-only mount".
Existing-install prepare remains in review and refresh ignores review: it does
not provide a healthy result. Offer Connect existing via the source draft and
its real authenticate/probe flow; do not call execute or present assumed health.

Docker's successful install task/wizard and healthy native result need two
explicit actions: Open initial setup and Add Source. Use a new stable draft id,
NasSourceType.jellyfin, the REMOTE endpoint and captured sshServerId; Docker uses
the actual deployment.endpoint, not a hard-coded port. Native uses result.endpoint.
NasSourceDialog.show(initialDraft: draft) remains a new, unsaved record. Existing
app-center openApplication(deployment) handles Docker's tunneled web opening.
Native has no openApplication deployment and no service.openWeb API: reuse the
public ref.read(applicationAccessServiceProvider).forward(draft) plus launchUrl
pattern, with target checks before opening. Do not persist the returned local
forwarded URI or auto-create accounts/sources. Ensure the tunnel lifetime survives
the external browser; do not dispose it merely because a chooser closes.

### Separate selective-uninstall batches and final included follow-ups

Follow 2026-10-12-uninstall-ui-contract.md independently: first new shared
app_uninstall_dialog.dart plus AppInstalledTab entry (select/final-confirm/execute
returning a task); second AppTaskDetailsDialog and AppTasksTab per-path outcomes
and explicit cleanup retry reusing that dialog. Both batches are needed before
acceptance. Reuse existing task display and error resolver, not a new task system.

Already approved follow-ups remain required, not optional polish: expose actual
diagnosticFor(source) plus scan fields, and source-scoped thumbnail/legacy/offline
space with separate explicit clear/remove confirmation. Reuse existing library
settings and downloads UI, do not silently clear caches during navigation/tests.

Delivery remains a NEW current-tree test package, retained-data ADB installation,
and observed device interactions after OpenCode validation. No push, release or
version bump. Device install/navigation alone does not establish native/Docker
deployment or destructive-cleanup acceptance; those require the independently
identified disposable fixture target, never production servers.
