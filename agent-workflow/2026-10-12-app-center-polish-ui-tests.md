# Next gate after AgY finishes

Keep all UI and ARB changes AgY-only; tests may identify defects but must not fix
production/UI. Reuse test/features/application_center_ui_test.dart, its real
fonts and existing fixture; no extra testing framework. No weakened assertions.

Required meaningful widget scenarios:

1. Render actual ApplicationCenterView -> catalog row -> actual details ->
   install wizard -> config -> review -> execute once -> live task -> reconcile
   success -> Installed. Fake only provider/service, not widgets. Verify each
   transition and no duplicate execute on repeated tap. Task launch != success.
2. Failed/needsInspection task details show bounded selectable/copyable logs;
   recheck does refresh only, never execute. Cancellation exception is handled
   visibly with no uncaught error; cancel disabled offline/not cancellable.
3. Installed app actions offline/busy are disabled; stop/restart/uninstall
   require confirmation. Cancel confirmation invokes no mutation. Target switch
   while async dialog preparation prevents stale operation.
4. Preserve search/filter and scroll across tab switch and provider refresh.
   Source error with cached catalog remains browsable; no-results differs from
   no enabled sources. Keyboard does not open on dismissal/tab switch.
5. Real fonts 320dp / text2x, long app/service names, actual multiservice card,
   task detail + wizard, Arabic RTL, desktop. Render actual widgets and assert
   no exceptions/overflow. Do not fix by reducing scale/font or clipping.

Current four UI tests must stay meaningful (new localized invalid-port message
may replace raw APP_CENTER_PORT_INVALID assertion if actual text verified).
Report exact passing commands/results, failures with actual file/line to root
for AgY. Full tests/analyze/build wait until UI fixed. Do not claim full device
workflow based on widget mocks + VM service lifecycle; these are separate layers.
