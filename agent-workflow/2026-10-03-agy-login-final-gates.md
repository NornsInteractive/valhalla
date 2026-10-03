# Final OpenCode task after AgY dialog repair

This supersedes earlier tests-only/no-build instructions. Continue existing
OpenCode session, main/small opencode/mimo-v2.6-flash-free. Previous runner was
stopped exit130 to deliver the actual upstream fix, not a failing test gate.
Original AgY Valhalla / gemini-3.8-flash-high / high has now fixed UI and exited0:
2026-10-03-agy-login-dialog-fix-status.md. Root inspected actual source: explicit
DialogRoute, captured themes, route.completed before disposal, immediate sensitive
input clearing, and Flexible/scroll for the draft auth card. The installed 13:40
APK does NOT contain this fix and must be rebuilt.

## Execute now; no more general investigation

1. Remove the temporary standalone `PROBE dispose in finally` from
   test/features/auth_browser_widget_test.dart. Preserve its captured diagnostic
   evidence in the report; it deliberately demonstrates invalid framework usage,
   not the corrected app. Keep the eight actual app regression cases STRICT.
2. Run those eight widget cases against FIXED current product source. If a real
   assertion/layout/source defect remains report exact evidence to root/AgY;
   never swallow exceptions, alter lib/ARB semantics, weaken assertions or skip.
   Correct actual fixture defects only, use bounded pumps for progress indicators.
   The fake platform dependency is now direct dev and flutter pub get succeeded.
3. Check formatting on this round's ACTUAL touched lib paths, not just tests.
   Mechanical dart format on the following explicit paths is authorized if check
   fails: lib/core/logging/sanitizer.dart; lib/core/providers/ai_chat_provider.dart;
   lib/data/models/builtin_agent_preset.dart; lib/data/repositories/agent_repository.dart;
   lib/infrastructure/acp/acp_oauth_request.dart; acp_ssh_transport.dart;
   acp_client_adapter.dart; agent_environment_service.dart (all under same acp dir);
   lib/features/chat/ai_chat_view.dart; lib/features/agents/agent_management_view.dart;
   lib/l10n generated Dart files; all THIS ROUND'S login test files.
   Formatting is whitespace-only, NO hand edits to lib/ARB or UI behavior.
   Do not format unrelated files/repo. Check again and record exact scope.
4. Fresh gen-l10n / full flutter analyze --no-pub zero / full flutter test --no-pub
   all green, 18 existing skips allowed, no added skips. Record true exit codes.
5. Preserve current APK in a NEW timestamped backup, do NOT overwrite existing
   backups. flutter build apk --release, capture real exit, UTC mtime/size/sha256,
   signing cert. Must differ from 13:40 stage APK because lib changed.
6. Existing ADB 127.0.0.1:14251 only, compare signing cert then install -r only.
   No uninstall/pm clear, no new emulator, no adb root, preserve data. Stop on
   signature mismatch. Start app and perform finite foreground/process/fatal/ANR
   observation. NO new account/OAuth actions, no send/inference/history mutations.
   Browser opening was already proven in previous stage; preserve distinction:
   final APK startup is verified separately, fresh browser replay not performed.
7. Correct and append evidence in 2026-10-03-agy-login-verification.md and initial
   2026-10-03-agy-login-device.md: private SSH hostname/IP/port redacted, racknerd
   name only; ARB key restoration AND regeneration (not generation only);
   accurate format scope, unknown age of broad 34 violations; diagnostic SSH close
   at 05:42:32Z is UNRESOLVED, not complete root cause or proof of independence;
   temporary diagnostic-only adb root then unroot previously done (no databases
   or credentials read); Google consent/live callback/inference/Docker device OAuth
   pending user. Record interim failing tests and genuine UI repair, then final
   passing counts and new APK/install metadata. Use Edit, no shell report writes.
8. Exit after evidence, no git mutations/commit/push. Root will update main docs.

Do not re-explore platform launch implementations or invent model substitutions.
No extra dependency or production abstraction is needed. Existing lib/ARB fixes
are AgY-owned; tests and all gate execution remain yours.
