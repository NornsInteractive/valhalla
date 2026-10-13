# Shared browser caller UI completion — 2026-10-13

The user authorized Codex to implement UI for this iteration. No AgY account,
credentials, production server, publication or signing settings were changed.

## Completed ownership boundary

- SFTP directory picker is a thin shared-dialog adapter; the duplicate renderer
  is removed. Normalized exact restricted paths and their descendants cannot be
  selected. A legal parent remains selectable, matching the previous copy/move
  contract. Source disposal and server/connection validation run before applying
  a result; factory-open failures return null with a localized error.
- ACP remote workspace picker is a thin shared-dialog adapter with the previous
  public `show` facade. It captures server connection, full AgentProfile
  (including Docker binding/user), session ID and draft working directory before
  opening. Context disposal, target replacement or recovery invalidates results.
  It never opens an ACP conversation. Unsupported types and entries exceeding
  the remaining per-type attachment byte budget cannot be selected.
- ACP chat callers capture their target before opening and revalidate before
  applying cwd or each attachment. Attachment errors remain per-file; the
  provider's aggregate byte check still rejects oversize multi-file combinations.
  There was no existing attachment-count policy, so no arbitrary count cap was
  introduced.
- CLI cwd picker retains the original agent/server/session/draft across awaits,
  disposes its source and displays opening errors without applying stale paths.
- Application data-root and mount pickers preserve form revisions and only apply
  to the original target and field. Factory failures leave form values intact.
  The main-service dropdown uses `initialValue`; unused store anchor index and
  obsolete imports are removed without changing the already-tested layout.

Shared widgets and source/NAS protocols are owned by the other workstreams.
Their mobile footer, source-invalidated fallback and directory double-tap
arbitration fixes were verified through these callers.

## Verification

Command:

```sh
flutter test --no-pub --concurrency=3 \
  test/features/application_path_flow_test.dart \
  test/features/acp_remote_workspace_browser_test.dart \
  test/features/cli_chat_view_test.dart --reporter expanded
```

Result: **82 passed, 0 failed, 0 skipped**, exit 0.

- Application path flow: 18 (including 3 new factory-open failure regressions).
- ACP workspace: 20 (including 3 new capability/budget/same-target cases).
- CLI chat: 44 (including 4 new Docker container/user/session/draft-change cases).
- Evidence: `/tmp/valhalla-callers-verified-tests.log`.
- Nine caller/test files pass targeted `dart analyze` after explicit mounted
  checks in wizard error callbacks.

Tests use real shared source/adapters with fake protocol/filesystem owners, not
remote production servers. Harness updates preserve the original behavioral
assertions, advance real provider-zone futures, scroll rows into view before
tapping and expect localized errors rather than raw protocol details.

No build, ADB installation, Git push or Release upload was performed by this
workstream; final whole-app and device gates belong to the root agent.
