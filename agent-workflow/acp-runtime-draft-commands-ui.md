# ACP runtime alignment and draft commands — 2026-10-01

## Goal and evidence

User asks to fix CLI model working while ACP reports unknown metadata/ChatGPT 400,
and slash commands unavailable before the first turn. Local read-only evidence:
PATH Codex 0.159.3, codex-acp 2.0.0 bundled Codex 0.158.0. The user's actual remote
target/authentication has not been tested. No real prompt/history/auth changes.

Root business changes (implemented, verification pending):
- `agentAcpLaunchCommand` wraps standard `codex-acp` / optional `--stdio` / absolute
  executable launch inside the SAME host or Docker user shell. Resolves configured
  CLI via Bash `type -P` (bypasses aliases) or POSIX `command -v`, validates executable,
  exports `CODEX_PATH`, stderr records path. Missing CLI fails explicitly, no bundled
  fallback. Explicit custom launch scripts are preserved, not parsed/re-written.
  Adapter launch identity now includes cliCommand so editing it invalidates an old
  pinned runtime and late results; selected CLI --version is recorded on stderr too.
- `AcpSlashCommand.isDraftPreview` optional bool default false. `composerCommands`
  exposes verified codex-acp 2.0.0 builtins ONLY after initialize confirms exact
  `@agentclientprotocol/codex-acp` / `2.0.0`. This is a version-pinned compatibility
  preview, NOT sessionless remote discovery. Unknown versions/agents get no fake list.
  Real available_commands_update is authoritative, including an empty list.
- Provider publishes baseline before independent live `skills/list` so skill query
  failure does not erase commands. Opening menu does NOT create ACP/local session,
  resume/load history, or prompt. Selecting command inserts text; explicit Send uses
  existing lazy session setup and that command as the first prompt (no dummy turn).
- Model name/manual marker and reasoning/approval validation unchanged. No SDK dep.

## AgY UI task (only original Valhalla / Gemini3.8Flash high)

Whitelist:
- `lib/features/chat/widgets/chat_commands_skills_dialog.dart`
- `lib/features/chat/ai_chat_view.dart` ONLY if needed for error exposure or target guard
- `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`
- `agent-workflow/acp-runtime-draft-commands-ui-status.md`

Do not edit business/data/infrastructure/platform/tests/generated files; no tests,
format/gen-l10n, analyze, builds, ADB, commits. OpenCode owns all validation.

Minimum UI: when any shown commands has isDraftPreview true, display a concise ARB
notice that these are commands verified for the current adapter version; selecting
only inserts text, Send initializes session on demand and runs it without a prior
  ordinary AI conversation. After remote commands replace preview, notice disappears.
No requirement for model/layout redesign. Keep existing command+skill tabs, search,
refresh, client settings/directory actions, async mounted/target guards, narrow-screen
layout and accessible text. Do not hardcode translations or auto-send commands.
If discovery fails, keep available baseline/client actions accessible and expose
  retry/error clearly through existing state rather than blocking the menu.
  Root also clears only `AGENT_COMPOSER_QUERY_FAILED:` after successful retry, preserving
  unrelated errors. UI should only show that prefix as a catalog error in this dialog.

Report UI READY, actual file whitelist/model/conversation and changes. No claim that
the user's model or Docker conversation has been verified.

## OpenCode business then release verification

Main+small `opencode/mimo-v2.6-flash-free`; use current rules. Test edits only via
apply_patch/Edit. No product semantic edits; report defects. Existing harness reuse:
- Shell launch standard host/absolute/Docker dev/user/name targeting, alias-safe CLI
  resolution, missing CLI fail-closed, unchanged custom/non-Codex launch. Small local
  mock-executable shell proof allowed in isolated temp fixtures; no actual Codex prompt.
- default ACP factory uses new helper; independent catalog still same CLI/profile.
  Editing CLI on the same agent invalidates/reopens the old pinned ACP process.
  Root also fixed `AcpSshTransport.close` waiting forever for an incoming stream
  listener when runtime/cwd setup fails before initialize. A new actual-factory
  test exposed 30s teardown timeouts: dispose without initialize must complete,
  preserving awaited closure for subscribed transports. Include this fourth root
  source file in the final mechanical-format list and retain this regression.
- initialize-only 2.0.0 preview, unknown agent/version none; no session/new/load/resume/
  prompt/history creation on open/refresh; actual notification including [] supersedes.
- skills merged/deduped, skill failure retains baseline, target change ignores late data.
- first message `/status` runs directly with lazy session/new -> session/prompt, no
  dummy ordinary message; first skills selection similarly works, existing settings
  approval/model and manual-model regressions pass.
- After UI READY add notice disappearance/search/narrow-screen and selecting inserts
  only tests. Mechanical format touched files, gen-l10n, analyze zero, focused+full.
- Only GREEN: recoverable old APK backup then new release, verify hash/time/signing,
  adb install -r existing device 127.0.0.1:14251 without uninstall/clear; launch/check
  latest crash/ANR window. All commands/exit/counts in verification report; STOP.

True remote model acceptance remains user verification; no real login/inference,
credential reads or modifications, history writes, package installs/upgrades or git
push. Existing Debug cert != store signing. No new architecture/dependency needed.

## Narrow-screen regression gate (UI READY revoked until corrected)

OpenCode's new `test/features/acp_usability_widget_controls_test.dart` test
`窄屏下预览提示与命令仍可见且不溢出` fails at physical 320x640, DPR1 with Flutter
layout exceptions. The existing tab header Row with icon+gap+unconstrained count
text is the suspected responsible layer. Do NOT enlarge viewport, drop exception
check or skip test. AgY must make the smallest responsive layout correction in
whitelisted dialog, preserving counts/icons/tabs/search/preview/error/insertion.
No tests/builds by AgY. OpenCode paused before release; full gates remain blocked
until fresh UI READY and AgY exit. Existing APK remains the prior release.

AgY has now provided fresh UI READY in the same original Valhalla/high session:
dialog TabBar labelPadding reduced to 4px horizontal and both count labels wrapped
in Flexible with ellipsis. No test/viewport change or other product semantics.
AgY exited original conversation. OpenCode may run final gates after its active
business-only phase ends; the unchanged 320x640 check must pass before release.

Final full-suite gate exposed 13 OLD remote-session fixture failures in
`test/core/ai_chat_usability_test.dart` and
`test/core/background_recovery_chat_state_test.dart`: manually assembled old
launchKey values omit the newly required cliCommand. `AcpRemoteSession` is an
ephemeral target snapshot, not persisted history schema. Root confirms intentional
identity change: editing CLI invalidates old runtime/snapshots; do NOT make the
production target guard accept stale identities. OpenCode may narrowly update
those two fixture keys to the current contract, preserving ALL mismatched
server/agent/key rejection, recovery/history/draft assertions. No skips/removals or
other expectations loosened; re-run both files and full gates before release.

Fixture values must follow their actual `cliCommand: 'cli'`: append `|cli`,
not `|codex`. Root corrected its initial handoff after reading the fixtures;
do not change the profiles to fit the mistaken example.
