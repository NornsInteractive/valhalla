# Exact validation-only execution

Do NOT author tests or product patches. No subagents, ADB, builds or network.
Use Nemotron only to execute these exact commands in /workspace/projects/valhalla:

1. /opt/flutter/bin/flutter gen-l10n
2. /opt/flutter/bin/dart format lib/core/services/application_compose_service.dart lib/core/services/application_deployment_service.dart lib/features/files/widgets/sftp_directory_picker_dialog.dart lib/features/app_center/widgets/app_center_error_resolver.dart
3. /opt/flutter/bin/flutter test --no-pub --reporter expanded test/core/application_compose_test.dart test/core/application_preflight_health_test.dart test/core/application_worker_test.dart test/core/l10n_key_parity_test.dart test/features/application_center_ui_test.dart test/features/sftp_file_view_test.dart
4. /opt/flutter/bin/flutter analyze --no-pub

Use logs at /tmp/valhalla-app-paths.HS4wpP/{generate,focused,analyze}.log,
retain each exit status (no pipelines masking failure). If generation currently
fails because AgY writes are not done, stop and report. Do not fix errors or
silence lint. On completion report exact counts/failures, not speculative pass.
