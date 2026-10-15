# Codex runtime / first-model handoff

Implementation and focused verification completed under the user's explicit
per-turn fallback authorization after external OpenCode could not complete the
work. No real Codex account, history or prompt has been used by this implementer;
runtime execution tests use only isolated fake CLI/adapter programs.
The user reports host Codex cannot converse after the metadata warning; its exact
remote failure stage has not been reproduced. Do not report live recovery yet.
Later root-only authorized ADB inspection found host CLI 0.162.1, ACP initialize
version 0.16.0 (its --version flag is unsupported), and a successful independent
CLI model catalog including GPT-6.1-Sol. A temporary detection profile was removed
after inspection, with original AgY selection restored; no prompt, upgrade or
login was performed. The old adapter has not been proven to use CODEX_PATH or
external CLI, so the 2.0.0-specific fixes cannot be claimed as a verified fix for
that host. ACP package-origin inspection and a separately confirmed compatible
adapter update remain necessary; do not widen the version allowlist by guesswork.

### Bounded legacy-source check after the ADB observation

The official `zed-industries/codex-acp` v0.16.0 source pins `codex-core` and
`codex-models-manager` to `rust-v0.137.0`, and creates an in-process
`CodexAgent`/`ThreadManager`; it is not the newer external-CLI/CODEX_PATH launch
chain. The embedded model manager fetches/caches models using its own version,
and falls back when metadata is missing. Thus updating the separately installed
CLI does not update this adapter's runtime. The observed version/argument behavior
matches this implementation, but is not proof of the host binary's provenance or
of every cause of prompt failure. No prompt was sent to reproduce that failure.

Primary evidence:
- https://github.com/zed-industries/codex-acp/blob/v0.16.0/Cargo.toml#L19-L36
- https://github.com/zed-industries/codex-acp/blob/v0.16.0/src/lib.rs#L31-L64
- https://github.com/zed-industries/codex-acp/blob/v0.16.0/src/codex_agent.rs#L67-L103
- https://github.com/openai/codex/blob/rust-v0.137.0/codex-rs/models-manager/src/manager.rs#L277-L285
- https://github.com/openai/codex/blob/rust-v0.137.0/codex-rs/models-manager/src/model_info.rs#L59-L99

Do not retrofit the verified 2.0.0 JSON configuration contract into this Rust
adapter. Its legacy `-c` argument, even if separately version-verified, would not
upgrade the embedded model runtime. A compatible adapter update needs separate
user confirmation and origin/version verification; retain existing auth/history.

## Owned production changes

- `agent_execution_target.dart`: `usesStandardCodexAcp(profile)`;
  `agentCodexTargetCommand(profile, command)`; `agentCodexExecutableScript(profile)`;
  `agentAcpLaunchCommand(profile, {String? initialModelId})`.
- Codex-only host execution loads login then interactive Bash startup so NVM/PATH
  in `.bashrc` is included even when a login profile does not source it. Docker
  still selects the configured container/user and resolves HOME from passwd.
  Startup output goes to stderr using target-local FD 3, then the actual payload
  restores protocol stdout. No PTY. Payload disables xtrace and shell history;
  no rc/config files are written. Other agents/custom ACP launchers are unchanged.
- Actual CLI/ACP paths bypass aliases/functions. CLI availability, authentication
  check, explicit install and native model/skill queries share the Codex helper.
  The existing general SSH login executor is not changed.
- Standard ACP exports the real `CODEX_PATH`; diagnostics contain CLI/ACP paths,
  CLI version, HOME/CODEX_HOME, presence (not value) of config/provider overrides.
  First-model startup additionally records the adapter version and override outcome.
- New-session startup model uses the official `CODEX_CONFIG` contract only for
  verified `@agentclientprotocol/codex-acp 2.0.0`. Other versions retain original
  launch with an explicit diagnostic that initial override was not applied.
  Config JSON is parsed/merged only in the remote process. Only `model` changes;
  existing provider, permission and other fields survive. Invalid JSON/non-object
  fails with `ACP_CODEX_CONFIG_INVALID`, never clears the config or prints its value.
  Node is needed for that verified npm adapter's merge; missing Node is explicit.
- `AcpTransportFactory` has optional named `{String? initialModelId}`. Existing
  two-positional call sites still work, but all test override closures need that
  optional named parameter. Production factory rejects an active update lock.
- AiChat passes the model only for a standard Codex target with no remote session.
  Changing an unstarted draft's model disposes only its sessionless adapter;
  creation stays lazy. Existing remote sessions receive no startup override and
  keep the formal ACP setting change/load/resume path. Failed local drafts that
  never created a remote session also store settings without first making a thread.
- `refreshRuntimeAfterUpdate(profile, {bool refresh = true})` invalidates the current idle agent on the
  same server (including a differently named profile aliasing the installation),
  preserves messages/remote IDs/account state,
  then optionally independently initializes and queries settings. The updater calls
  `refresh:false` under the server lock after a possibly-mutating attempt (including
  partial/unknown outcomes), before unlocking; this only disposes idle transport,
  invalidates internal caches and marks settings stale while keeping visible cached
  content. After unlocking call `refresh:true` for read-only capability refresh.
  It does not create/load a session and closes the unlock-before-invalidation race.
  It always refreshes the currently selected profile's own runtime, never applies
  the updated profile's commands/container/user to another selected profile.
- Pending model/skill discoveries check request epoch, active connection identity,
  selected profile/launch key, live SSH client and update lease before publishing.
  A late result for a previous alias/runtime cannot overwrite the new cache.
- Draft model changes also advance a dedicated runtime generation and discard old
  composer/opening Future ownership. Expected supersession is silent, fresh queries
  need not wait for old ones, and A-to-B-to-A cannot reinstall the first A process.
  Existing visible commands/messages stay intact. Actual in-flight open/composer
  counters remain busy until even superseded work finishes, so update admission
  cannot overlap a detached-but-not-yet-finished runtime operation.
- Send/settings/authorization/adapter creation/recovery respect the update lease.
  Public `isRuntimeBusy` includes preparation, opening transports, composer queries,
  independent remote-session listings, recovery/checkpointing, authentication and
  approval state as well as visible loading/generating flags; update admission uses
  it instead of inspecting visible flags alone.
  Failed initialize and prompt stages are retained in adapter diagnostics;
  provider failures preserve those sanitized diagnostics before disposing transport.

## Upstream capability evidence (read locally)

Installed package root:
`/opt/nvm/versions/node/v24.16.0/lib/node_modules/@agentclientprotocol/codex-acp/`.
`README.md` runtime options documents `CODEX_CONFIG` (JSON merged into session
config), `CODEX_PATH` (executable only), `MODEL_PROVIDER` (separate provider).
`dist/index.js` contains `startAcpServer` reading JSON, `createSessionConfig`
spreading `this.config`, and `newSession` sending that config to `threadStart`
before listing available models. Neither the ACP launch CLI nor `session/new`
supports an invented `-c model=...` or `_meta.model` field.

The override is therefore process-local **session** config, not an argument to
the underlying `app-server` startup. A startup/model-list failure can still require
correcting the actual installation/environment; no warning is hidden as a fix.
On restoring an old session a fresh transport has `initialModelId == null`, so
the inherited CODEX_CONFIG/model settings are untouched by Valhalla.

## Required OpenCode regression work

1. Update every `acpTransportFactoryProvider.overrideWithValue` closure to accept
   `{String? initialModelId}`. Capture it where verifying first-model semantics.
   Keep overrides fake; do not fall through to live SSH.
2. Reuse isolated shell fixtures, not real HOME/rc/Codex. Put different fake Codex
   installations in login and interactive PATH. Assert detection, model query and
   ACP resolve the intended same CLI; absolute paths and aliases work. Emit a fake
   rc banner and verify only protocol output reaches stdout. Missing executable
   fails. Verify payload history is disabled and no fixture history file is written.
3. Docker fake must retain the actual shell flags and model selected-user passwd
   HOME; protocol-safe entry is now `/bin/sh -c` (not login outer sh), with Bash
   `-ic` inside. FD 3 must be established inside the target, never inherited from
   the Docker-host process. No-Bash fallback remains `/bin/sh -lc` for payload.
4. Fake ACP `--version` advertises exactly the official 2.0.0 string, then checks
   `CODEX_PATH` and merged config. Existing model is replaced by explicit selected
   model, other fields including a synthetic secret remain byte-equivalent after
   JSON decode; the secret must not appear in stdout/stderr. Invalid JSON, null,
   array and scalar fail before ACP launch. Missing config is an empty object.
   Unknown adapter/version and custom wrappers do not inject model/config.
5. Public command assertions should check behavior and actual executable, not old
   literal `exec codex-acp` text: production now execs the verified resolved path.
   No direct live npm/Codex execution or remote session creation in tests.
6. Draft model A -> initialize -> choose B -> first send: only the B sessionless
   process survives, first new receives B, exactly one user prompt. No `session/new`
   for model discovery/selection. Missing CLI/config failure does not auto-retry or
   clear the user's draft. Test both unsent draft and failed-local/no-remote draft.
   Completer regression: start composer A with transport unresolved, save model B,
   request composer again immediately and assert it is a different Future. Complete
   B first and A last: no supersede error, old A disposed, new B commands survive;
   old completion does not clear B's pending Future. Repeat A -> B -> A, ensuring
   the first A still cannot become current just because its model name matches.
   Hold the preference-save Future, allow old A to finish while saving B, then
   finish saving: the now-current sessionless A must be disposed (not leaked by
   disposing only the adapter captured before the await). Preserve messages and
   already-visible commands throughout. Superseded actual opens/queries keep
   isRuntimeBusy true until their own finally blocks release their counts.
7. Existing remote session: no startup initial model, no replacement thread, formal
   set_config_option still used. Test switching away/target changes during pending
   factory open so the late transport is disposed without state leakage.
8. Lock sends/settings/auth starts; cancellation remains available. Successful
   update refresh after release keeps remote IDs/messages/account and performs
   initialize/model-list only; wrong server/busy/locked refresh is a no-op.
   Update profile A while profile B on that server is selected: B is invalidated
   and refreshed using B's runtime only, preserving B's existing remote session.
   Under-lock refresh:false must dispose the old idle transport without starting
   any RPC and without blanking visible cache. A send racing just after unlock
   cannot reuse the old process. Pending factory/catalog/auth/recovery work is busy
   even before a loading flag, so mutation cannot start concurrently.
   Pending pre-update/old-connection/model/skill responses cannot publish late;
   an old query's completion cannot clear the replacement query's busy ownership.
9. Check failure diagnostics contain initialize vs session/new/prompt phase and
   runtime identity without auth/config secrets. Preserve existing real error
   classification; do not treat a warning as success when the RPC actually fails.
10. Multiline generated update probes and the CODEX_CONFIG JavaScript merge must
    build successfully for both host and Docker targets. The target helper now
    quotes shell/JavaScript source with a private script-only quote function that
    accepts line breaks and rejects NUL. Verify apostrophes, newlines and literal
    shell substitution text survive each nested script argument without being
    evaluated by its enclosing shell. The global cliShellQuote data contract is
    unchanged: models, executable paths, container references and users still use
    strict validation/quoting. Cover the host outer/inner shells, Docker outer
    shell/Bash/sh fallback, and node -e merge source using isolated fake programs.

## Authorized focused validation completed

After the user's per-round validation exception, this subagent added isolated
execution regressions in `test/infrastructure/codex_agent_execution_test.dart`,
updated the original target-command fixtures, and added initial-model/restore and
Completer-driven A-to-B / A-to-B-to-A cases to
`test/core/independent_model_query_test.dart`.

The race regressions uncovered and fixed a real disposal leak: an adapter returned
by a superseded factory had a transport but no RPC connection yet. `dispose()` now
closes that transport as well, while retaining deferred close for permission-reply
ordering. No real Codex, ACP process, Docker daemon, credentials or user history
was used: the shell fixtures use temporary HOME/startup files and mock executables;
only the generated JavaScript merge executes in the local Node runtime.

Results:

- Focused `flutter test --no-pub` for the three files above: **86 passed**.
- `flutter analyze --no-pub` for the five owned runtime/provider source files and
  three test files: **no issues found**.
- `dart format` completed for those eight files.
- Evidence: `/tmp/valhalla-agent-updates.aOvCbg/codex-runtime-final.log` retains the
  initial failures, fixes and final successful rerun; the first failures must not
  be mistaken for the final result.
- A broader infrastructure run exposed four stale fixture assertions. Two model
  catalog tests still expected the old Docker login-shell flag; environment
  detection expected the old raw lookup. The legacy login test matched the old
  `codex login status` literal, so its fake returned default exit 0 for the new
  resolved `"$CODEX_PATH" login status` command. Its original unauthenticated /
  notLoggedIn expectations remain unchanged; the fixture now matches the full
  target command and asserts the failed login probe was actually executed.
  `codex_model_catalog_test.dart` and `agent_environment_service_test.dart` now
  pass **45 tests** with **no analysis issues**. Evidence:
  `/tmp/valhalla-agent-updates.aOvCbg/codex-fixture-final.log`.

No builds, ADB actions, real host/Docker Agent conversations, publication or git
operations were performed. Real-server acceptance remains a separate gate.
