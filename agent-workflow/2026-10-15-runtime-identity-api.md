# Runtime identity UI / test contract

`lib/core/utils/app_runtime_identity.dart` exports:
- `List<String> applicationArchitectures()` is exactly the old update-provider
  ABI selection; first is actual running application ABI, macOS appends universal.
- `Map<String,String> appRuntimeIdentity(PackageInfo info)` returns applicationId,
  version, buildNumber, platform, architecture. No secrets or device identifier.
- The existing distribution architecture mapping now lives in this utility;
  AppUpdateService retains its public static forwarding method. This avoids a
  diagnostics → identity → update service → diagnostics import cycle without
  changing the mapping. Repeat the same identity/diagnostics/update tests and
  existing app_update_service_test.dart after this extraction.

AgY may reuse the existing AboutPrivacyCard PackageInfo future and show these
values with localized labels in compact expandable install details. Diagnostics
`_loadLogs` should call `widget.diagnostics.report()` instead of `read()` to show
the same identity header as export. Both are bounded local text, no remote calls.
Keep diagnostics injection tests supported. Configuration migration hint should
reuse existing export/import UI and clarify credentials must be supplied again.

`AppDiagnostics.report({int maxBytes=256*1024})` prepends sanitized application
identity to the existing bounded log tail; when PackageInfo is unavailable it
still reports actual platform/ABI and logs. Export uses report. Existing `read`
contract and log rotation are unchanged. Root owns core files; AgY owns UI.

OpenCode regression: PackageInfo.setMockInitialValues with com.norns.valhalla /
1.0.6 / 7, report contains identity plus redacted logs; no device supported-ABI
probe. appRuntimeIdentity architecture matches applicationArchitectures().first.
Existing update artifact routing and app_diagnostics tests must still pass.
