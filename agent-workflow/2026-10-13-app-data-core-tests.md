# OpenCode — application data and naming regression authoring

Explicit model opencode/mimo-v2.6-flash-free, no paid/subagent. Core implementation
is available in application_center model and application_* compose/deployment/
cleanup services. See approved shared-browser-and-app-data contract for boundaries.
You own TEST files only: test/core/application_cleanup_helper_test.dart,
application_compose_test.dart, application_worker_test.dart,
application_paths_test.dart, application_preflight_health_test.dart,
and a new test/core/application_container_naming_test.dart if needed. Do not edit
application_center_provider_test.dart (another OpenCode session owns that), UI,
lib/core, infrastructure, product models, credentials, or shared fakes without
notifying root. Use apply_patch for authored tests. No product fixes.

1. Real helper embedded Python tests: whole dataRoot candidate includes unmounted
   sentinel; selectsafe root with own child binds; same-path root/bind merge; child
   only keeps siblings/unmounted root sentinel; combined parent/child coalesced;
   protected/shared/bind-alias/identity changed paths cannot be deleted via parent;
   retry scope only original top-level authorized targets. Use isolated tempfile
   paths only; don't delete external paths or run opt-in production/VM tests now.
   Existing many helper tests only extract remove_directory: add inspect coverage
   with controlled Docker/owned config/target inventory, not just text assertions.
2. Compose helpers serviceNames/suggestedMainService/containerNames/name validity.
   New defaults enable mode; single/multi main, missing main error, exact instance
   and sidecar names, legal app-id default, user illegal input rejected, legacy
   JSON remains legacy, read/copy/serialization preserve fields, x-casaos.main and
   network aliases/labels/project identity retained. replicas>1/global/scale refused.
3. Deployment prepare + execute both check live+stopped name inventory; foreign
   instance/service conflict refused; malformed inventory fails closed; same owned
   service permitted. Actual docker Go-template correctness requires followup VM
   evidence later, not manual success JSON alone. Existing worker fake commands
   need adapting to new read-only inventory without weakening start/persist safety.
4. configure/update keep legacy strategy or chosen main; new mode rename review
   contains container_name; rollback original naming; selected main drives webPort.

## Security review additions (core owner patch in progress)

Whole-root parent selection must not bypass protection on unmounted .ssh/.gnupg
descendants (at any depth). Add preview and execution regression with protected
sentinels, plus a protected child introduced after preview. External bind alias:
dataRoot backing mounted at another unrelated location is shared even without
Docker refs or mountpoints below source; mountinfo coordinate inspection must
block it, while the ordinary containing ancestor filesystem must remain allowed.
Use controlled mount records in local helper fixtures; real bind verification only
later on explicitly pinned disposable VM, not this workspace filesystem.

Run only focused affected core test files when ready. Other product writers are
active outside this scope, so compile issues must be reported not fixed by you.
Record exact results/failures in agent-workflow/2026-10-13-app-data-core-results.md.
Do not run formatting, l10n, analyze, full suite, builds, ADB or remote commands yet.
