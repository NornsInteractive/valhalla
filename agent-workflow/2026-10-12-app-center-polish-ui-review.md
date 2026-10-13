# UI review (AgY original session only)

Actual widget failure: test/features/application_center_ui_test.dart test
"multiservice installed card at desktop 2x expands without overflow" reports
RenderFlex overflow by423px at app_installed_tab.dart:765 service badge Row.
Constrain/wrap actual service labels at2x; don't reduce text scale or hide test.
Full output /tmp/valhalla-app-center-polish.gtzzQH/ui.log.
Actual second failure: store-to-install test double-taps Confirm before pumping;
notifier.executions becomes2 (expected1), confirming _executePlan loading guard.
FOLLOW-UP after initial guards: same test STILL observes2 executions. Awaiting
execute may complete before next frame, sets _isLoading=false and progress step,
but previous frame button still calls handler. Guard `_currentStep != review`
and/or `_runningTask != null`, not just _isLoading. Actual UI callback must remain
idempotent after success as well as while awaiting. Do not weaken this test.

Finish initial edits, then address these concrete issues without expanding scope:

- app_details_dialog.dart `_onInstallTapped` captures current connectionKey and
  immediately reads it again: comparison is tautological. Capture key at dialog
  initState; both load completion AND install tap must use that original key.
  If server changes after template loaded, do not install on new server based on
  old environment. Show localized target-changed / require reopening. Awaiting
  old-target load must not leave an eternal spinner.
- application_center_view.dart `_navigateToTab` may be invoked by a route after
  parent unmounts; guard mounted. Environment-inspecting Row Text needs Flexible
  for 320dp2x. Render state.error through existing resolver, not raw error code.
- app_task_details_dialog.dart currently falls back to initialTask after target
  switch, but cancellation controls use current connection status only. Capture
  origin key and disable stale actions/show target changed; never display it as
  current server data. finally cleanup of local spinner must run if mounted even
  when target changes (current conditionalkey prevents reset forever).
  Cancel/recheck buttons must be visibly disabled offline, not merely show a
  snackbar after tapping. Apply spinner cleanup to app_tasks_tab too.
- Wizard _executePlan must early-return if _isLoading or !_isTargetValid() so
  same-frame taps cannot double-submit even before next rebuild. _preparePlan
  also needs loading/target guards. Provider rejects real duplicate token but UI
  must not raise spurious error or call across target switch.

No tests/build/format/gen/ADB; root is handling validation under user's explicit
this-round exception. Only existing UI whitelist.
