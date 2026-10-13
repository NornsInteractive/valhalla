# AgY checkpoint correction and continuation

Same Valhalla conversation, gemini-3.8-flash-high/high. Previous CLI turn was
stopped gracefully by root only to deliver actual regression evidence. Preserve
all partial UI work and resume it. No core/model/test changes, no tests/analyzer/
generation/format/build/ADB. Root now has explicit user permission to do those.

First read these files completely:
- shared-browser-ui-phase2.md (same-directory file dated2026-10-13)
- 2026-10-13-shared-browser-ui-review.md
- 2026-10-13-remote-browser-ui-review.md
- 2026-10-13-browser-core-api.md

Do this batch in order, then return a factual checkpoint so root can run gates:
1. Fix both compile blockers (native displayedBlockers declaration in collection;
   wizard nonexistent deployment.configuration), and AppStore width/overflow/
   badge/anchor issues described by the review and actual failing tests.
2. Correct shared browser lifecycle/cancel/target guards, selection/confirmation,
   preview bounds and source scoping, navigation fallback, hidden styling/search
   row/large text/grid anchor per review. Support restricted directory predicate
   and ACP supported file predicate/count using minimal existing APIs. Current
   directory confirmation must be disabled until successful read, and on error;
   ordinary user navigation must not silently fallback after missing directory.
   Initial-only fallback preserves prior feature. Expose selection readiness to
   dialog. Don't merely catch exceptions or change tests.
3. Finish safe thin SFTP/ACP wrappers; remove their dead independent browser bodies
   once callers/tests use shared component, preserving public compatibility where
   needed. Fix ACP/CLI captured original target/session/draft guards and original
   supported-file limits. Single-service/new main dropdown display and submitted
   value must agree; ambiguous main begins null and requires explicit selection.

Do not start further NAS/main-page migrations in THIS batch until those three
items are finished. They remain required in the next batch, not waived. This
lets root validate a stable component before integrating every caller.

Current root tests: application_naming_ui_test.dart, application_path_flow_test.dart,
remote_browser_dialog_test.dart, nas_native_install_dialog_test.dart,
application_center_ui_test.dart, app_uninstall_dialog_test.dart. Read tests as
contract as useful but don't modify or run them. New ARB fields are yours in all17
catalogs; root will regenerate. Update shared-browser-ui-status.md with current
done/pending. Never claim build/install/device acceptance.
