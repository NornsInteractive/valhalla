# Current Analyze — 2026-10-11

Bounded static diagnostic only: `flutter analyze --no-pub` in `/workspace/projects/valhalla`. No source/test edits, no builds, no ADB.

## Result

15 issues found (ran in 7.4s).

## Errors (4)

| File | Line | Issue | Rule |
| --- | --- | --- | --- |
| lib/infrastructure/sftp/sftp_client_service.dart | 696 | The method 'lstat' isn't defined for the type 'SftpClient' | undefined_method |
| lib/infrastructure/sftp/sftp_client_service.dart | 705 | The method 'lstat' isn't defined for the type 'SftpClient' | undefined_method |
| test/features/nas_media_view_test.dart | 277 | `_FakeNasNotifier.thumbnailPath` (`Future<String?> Function(NasMediaItem)`) isn't a valid override of `NasNotifier.thumbnailPath` (`Future<String?> Function(NasMediaItem, {Object? owner})`) | invalid_override |
| test/features/sftp_file_view_test.dart | 166 | `_TestSftpNotifier.saveFileContent` (`Future<void> Function(String, String)`) isn't a valid override of `SftpNotifier.saveFileContent` (`Future<void> Function(String, String, {int? editorToken})`) | invalid_override |

## Warnings (1)

| File | Line | Issue | Rule |
| --- | --- | --- | --- |
| test/core/zz_scratch_probe_test.dart | 55 | The getter doesn't override an inherited getter | override_on_non_overriding_member |

## Info (10)

| File | Line | Issue | Rule |
| --- | --- | --- | --- |
| lib/core/services/app_update_service.dart | 94 | Use the null-aware marker '?' rather than a null check via an 'if' | use_null_aware_elements |
| lib/core/services/app_update_service.dart | 144 | Statements in an if should be enclosed in a block | curly_braces_in_flow_control_structures |
| lib/core/services/app_update_service.dart | 185 | Statements in an if should be enclosed in a block | curly_braces_in_flow_control_structures |
| lib/features/dashboard/dashboard_provider.dart | 140 | Statements in an if should be enclosed in a block | curly_braces_in_flow_control_structures |
| lib/features/docker/docker_provider.dart | 124 | Statements in an if should be enclosed in a block | curly_braces_in_flow_control_structures |
| test/core/zz_scratch_probe_test.dart | 52 | The variable name '_Controller' isn't a lowerCamelCase identifier | non_constant_identifier_names |
| test/core/zz_scratch_probe_test.dart | 105 | Don't invoke 'print' in production code | avoid_print |
| test/core/zz_scratch_probe_test.dart | 107 | Don't invoke 'print' in production code | avoid_print |
| test/core/zz_scratch_probe_test.dart | 108 | Don't invoke 'print' in production code | avoid_print |
| test/core/zz_scratch_probe_test.dart | 110 | Don't invoke 'print' in production code | avoid_print |

## Notes

- Errors are concentrated in `lib/infrastructure/sftp/sftp_client_service.dart` (2× undefined `SftpClient.lstat`) and two test fakes with stale override signatures.
- No fixes applied; diagnostic snapshot only.

## Environment

- Model: `opencode/step-5-preview-free` (free configured model, confirmed).
