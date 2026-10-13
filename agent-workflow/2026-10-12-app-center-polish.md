# Application center usability and complete lifecycle

Completed this round: UI14, final full suite2664passed/20environment skips,
zero analysis, real isolated VM lifecycle and official Chinese source retrieval;
final local Android builds and preserved-data ADB installation verified. Actual
coverage/remaining device-network limitations and hashes:
[verification](2026-10-12-app-center-polish-validation.md).

User: improve application-center UI now and test a complete closed loop.
Preserve the existing dirty worktree. Version1.0.4+5, no push/release/Actions.
Root owns business logic/docs. All UI/interaction/ARB exclusively original AgY
Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b / gemini-3.8-flash-high / high.
OpenCode owns new tests/generation/format/analyze/build/ADB; explicit MiMo2.6
free first, confirmed-free fallbacks per prior authorization. Previous round's
direct-validation exception is NOT automatically reused for this new task.

Current-round exception now explicitly approved by user: root may complete
remaining validation, local packaging and preserved-data ADB if OpenCode cannot
finish. MiMo probe confirmed rate-limited at06:17:07 UTC; Nemotron3.5Lightning
free has zero input/output/cache pricing in current CLI metadata and is attempting
core/VM checks. UI ownership/no-push/no-release constraints remain unchanged.

## Observed gaps and narrow outcome

- Store hides per-source errors; refresh resets catalog to empty if disk cache is
  gone although usable data is in memory. Keep current data until replacements
  arrive; show refresh/source failure and distinct empty-filter/no-source states.
- Detail is a cramped AlertDialog on mobile. Reuse fullscreen mobile/bounded
  desktop pattern and preserve selected app/target identity through install.
- Wizard completion only closes; lead to installed app or ongoing task; a failed
  or unknown task must offer logs/recheck, never blindly replay install/update.
- Task operations/status/services expose enum/raw English; cancel callbacks
  discard Future failures; task preview logs are capped with no detail action.
- Installed menus remain enabled offline/busy; fixed desktop card height and
  unbounded health labels risk overflow. Show useful health/version/source,
  progress/actions, confirmation for disruptive operations, no duplicate execute.
- Refresh errors must preserve last-known service state, marked stale/unknown;
  success requires actual task reconciliation, not command submission.

No new catalog backend, accounts, native fnOS packages, automatic upgrades,
privileged containers, scripts, app-data erase, or framework/dependency additions.

## Design (reuse Norse Steel)

Audience: people managing self-hosted apps on the selected SSH server. One job:
find an app, safely deploy it, know whether it works, then manage it.
Keep existing shell title/theme/navigation; no duplicate page hero. Baseline
palette from current tokens: canvas#F5F6F8, surface#FFFFFF, accent#10B981,
healthy#0E9F6E, warning#B45309, danger#DC2626. Implementation MUST use ColorScheme
and VColors so customized dark/AMOLED/accent colors work, not new hex literals.
Inter labels/headings; JetBrains Mono only ports/paths/versions/logs. Existing
radius16 cards/12 controls, spacing8/12/16. Signature is an app's lifecycle:
catalog card -> environment/config/review -> live task -> installed health/action.
Do not add decorative gradients, marketing hero, made-up ratings or statistics.

Mobile:
  [Store | Installed | Tasks] [sources/refresh]
  [compact actual server environment status]
  [search full width] [category/source filters]
  [icon / name / useful description / installed-or-compatibility status]
Desktop: same hierarchy, adaptive cards; mobile dialogs fullscreen and scrollable.
Compare: giant hero plus tiny cards would hide operations, so retain compact
server context and devote room to real app data/actions. Preserve focus/scroll
across polling/tab changes; opening/closing a dialog must not summon keyboard.

## Acceptance and boundaries

1. Widget/provider tests: store filters/failures, browse->details->review->execute
   once->live task->success navigation; failed/unknown task logs and safe recheck;
   cancellation exception handled; offline/busy disabled; target switch refuses
   stale mutations; long multilingual names/health at320dp2x/RTL/desktop.
2. Real deployment lifecycle using existing pinned disposable Debian VM only:
   install->HTTP->private config/logs->reconnect same task->stop/start/restart->
   configure->manual update->restore->uninstall, confirm data sentinel retained.
   Reuse test/infrastructure/application_center_vm_test.dart and fixture guide.
   Validate host fingerprint+machine-id+hostname+ready marker BEFORE writes.
3. Analyze zero, full tests current state, local Android build and compatible
   `adb install -r` preserving existing app data. No production server mutation.
   Device UI test must select isolated VM before any operation; never racknerd.
   If full real device flow cannot be performed, state exactly which layers passed.
4. No weakening checks or claiming last round's2647 passes as current evidence.

Scratch: /tmp/valhalla-app-center-polish.gtzzQH. Existing emulator127.0.0.1:14251
and VM127.0.0.1:22023 were available at task start; verify current identity.
