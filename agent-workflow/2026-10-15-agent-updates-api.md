# Agent update core / UI handoff — 2026-10-15

Status: core implementation and focused mock verification complete. Under the user's per-turn verification exception, this agent replaced incomplete OpenCode fixtures, formatted only owned files, and ran the focused suite and analysis described below. Production UI/ARB remains AgY-owned. No remote installation/update, real server probes, build, ADB operation or publication was performed by this agent.

## UI contract

Import `core/providers/agent_update_provider.dart` (re-exports update models).

- `agentUpdatesProvider` → `AgentUpdatesState`: `serverId`, `agents: Map<String, AgentUpdateEntry>`, `availableCount`, `noticeCount`, `isChecking`, `isUpdating`, `generation`, `lastUpdatedAgentId`.
- Entry: `report`, `isChecking`, `isUpdating`, `interrupted`, `errorCode`, `log` (sanitized tail, 64 KiB, batched every 100 ms), `lastAttemptAt`, `lastSuccessfulCheckAt`.
- Report: `agentId`, `targetKey`, `checkedAt`, `components`, `diagnosticLog`, `hasUpdates`, `hasErrors`.
- Component: `component: cli|acp`, `status: current|available|unsupported|missing|error`, `installedVersion`, `latestVersion`, `source`, `reasonCode`, `canUpdate`. `command` is only present in fresh reports/plans, never persisted.
- `onChatEntered()` on real ACP/CLI page entry, not every build: enables update notices then checks all added Agents on the current server when due. Provider mounting alone performs no remote work.
- `checkAgent(id, {force = true})`, `checkAll({force = true})`: manual check. Two probes maximum, in-flight coalescing. Manual checks bypass successful-day/failure backoff and latest-catalog cache.
- `dismissUpdateNotice()`: acknowledge all currently advertised component/version combinations for today. Invoke on closing the top notice or opening update details. Same day/same target/same versions do not alert again, including after process restart. Later versions or next day can alert again.
- `prepareUpdate(id, {Set<AgentUpdateComponent>? components}) -> Future<AgentUpdatePlan>`: fresh read-only target/origin/version inspection; omit components to select all actionable upgrades. Throws stable `AgentUpdateException.code` when busy/no update/stale target/offline.
- Plan fields: `server`, `profile`, `targetKey`, `preparedAt`, `resolvedContainerId`, `components`, `commandPreview`. Display target server, host/container/user, each installed→latest version, exact command, migration warning and busy/restart implications. Explicitly confirm this plan; cancel performs no update.
- `applyConfirmedUpdate(plan) -> Future<void>` consumes that exact one-use plan. Do not regenerate a different plan after confirmation. Show progress/log/error from entry. Success increments generation; runtime cache invalidation and environment/version refresh are owned by core, not widget listeners.

Use a top overlay notice only (no layout insertion); recovery status takes priority over update notification. No auto-opening blocking dialogs, downloads, package installation, or new Agent conversations during checks. Every upgrade still requires confirmation. Cached `available` does not itself authorize execution: UI calls `prepareUpdate` even if `canUpdate` is false on a persisted row (commands intentionally excluded from cache).

## Cadence / identity / lifecycle

- Local calendar day, per SHA-256 target key (SSH connection identity + Agent ID + configured target/user/commands). Success once/day; failed attempts have 15-minute backoff. Offline check does not consume the day. After a chat page has been entered, a later SSH reconnection retries due checks. No OS scheduler/background timer.
- Interrupted upgrades persist an interrupted marker before remote execution; restart rechecks only, never replays an upgrade command. Failed/partial upgrades are visibly non-successful and require a fresh plan before retrying.
- `agent_update_lock_provider.dart` exposes `isAgentUpdateLocked(Ref, AgentProfile)` and a server-wide lease. Conservative server serialization covers container name/ID aliases and implicit/explicit user aliases. The lease is released even if the update notifier is disposed.
- CLI/ACP send/settings/auth/start paths and Agent edit/delete/install/login paths must consult this lease. Busy checks include private opening/recovery/history operations through runtime getters. Active generation, permission requests, login and interactive Agent terminals prevent updates.
- Before mutation: re-probe UID, HOME, executable paths, package origin/prefix and current versions. Docker is resolved to an exact ID and the update executes against that ID; a recreated name invalidates the plan. The update payload repeats UID/HOME checks.
- Before releasing the lease, both existing CLI and ACP runtimes are marked stale/closed using `refresh:false`, including uncertain/partial outcomes. After verified success and unlock, fresh capability queries occur without creating a conversation, loading history or sending prompts. Same-server cached aliases are invalidated.
- In-flight checks carry a separate revision and cannot overwrite installation progress or clear the persistent interrupted marker. Edited targets restore their own cache; deleted Agents leave the notice count.

## Supported sources / safety boundaries

- Known npm origins are verified by canonical executable→package ancestry under the same `npm root -g`. Update uses the resolved npm executable/prefix, explicit public registry and exact stable version with engine strictness. Preview/unparseable installed versions are manual-only, never downgraded.
- CLI: Codex npm; Claude npm and the normal native `~/.local/share/claude/versions` installation; OpenCode npm and `~/.opencode/bin`; AgY native `~/.local/bin/agy`. Native Claude respects `latest`/`stable`; explicit minimum/maximum/managed policy makes it manual-only. Unknown wrappers/brew/apt/manual origins remain manual-only rather than replacing another installation method.
- ACP: current `@agentclientprotocol/codex-acp`; current `@agentclientprotocol/claude-agent-acp`; OpenCode is the CLI package and is shown/updated once; Valhalla-managed AgY ACP.
- Exact legacy Claude defaults (`claude-code-acp` plus the original old npm install command) can migrate to `claude-agent-acp` after explicit update confirmation, installation and version verification. Node compatibility is checked. `commitVerifiedAdapterMigration(original, updated)` then saves only the verified command/installer change. No uninstall or auth/history removal.
- AgY CLI: official platform/musl manifest for check; `agy update` for confirmed update. Its install.sh is NOT reused as an updater (it exits early if the binary exists). Immediately before execution, force-refetch and compare approved version/URL/SHA-512 metadata; any change requires a new confirmation. The official updater still has a small check-to-execution window and may install a newer stable version than the confirmation snapshot; the confirmation UI must say it follows the official stable channel, and post-check requires at least the approved version, never an older one. No custom CLI archive installer was retained.
- AgY ACP: official registry metadata + exact expected `dl.google.com` HTTPS archive path for the remote OS/architecture. No redirects, arbitrary hosts/commands or phone architecture selection. New version directory must not exist; previous directory and launcher stay usable until extraction completes. Download ≤4 GiB, extraction ≤8 GiB plus available-space check, member count/ratio limits; traversal, symlinks, special/encrypted entries rejected; ZIP CRC validated on extraction. Save local version/file-size/SHA-256 manifest, then atomically replace the managed launcher. Old version retained. Existing conflicting target directory fails safely for manual inspection. Official registry currently provides no signed digest; local hash/ZIP CRC proves local integrity, not publisher-signature authenticity.
- Streaming command terminal exit code must be 0 AND the fresh installed version must meet the approved version; missing exit status is a failure. No automatic sudo, credential deletion, shell-profile modification, downgrade, package-source switching, or arbitrary remote command execution from catalog fields.

## Required regression coverage

1. Pure versions: stable equality/newer/older, prefix, build metadata, invalid/preview blocked; malformed catalog/version/package name rejected.
2. Probe commands: host/Docker selected user/HOME, standard Codex `--stdio` and absolute executable, rc noise, unknown wrapper not executed with guessed flags, no ACP `--help` process launch; paused/disconnected targets.
3. Sources: npm ownership matching/nonmatching prefix; Native Claude channel/managed settings; OpenCode shared CLI/ACP single row; AgY CLI manifest platform/musl; managed ACP exact archive allowlist and existing-destination refusal.
4. Update: explicit confirmation required; target UID/HOME/path/version/container changed while dialog open; expired/reused plan; zero/nonzero/missing exit; unchanged version; CLI-success/ACP-failure recheck; old Claude profile committed only after new version verification.
5. Provider cadence: both pages same day, next day, restart, failed 15-minute backoff, manual force, offline→connected, only current server profiles, max two probes, concurrent coalescing; edited target does not inherit successful-day cache.
6. Persistence: missing/corrupt/oversize records, valid 64-hex keys, false SharedPreferences writes reload/throw; no commands/auth values persisted; interrupted marker survives provider/process restart and never replays mutation. An interrupted upgrade gets an immediate first recovery probe; a thrown probe error or component-error report preserves the interrupted marker and applies the 15-minute failure backoff, including after another restart. Only a successful error-free report clears that marker.
7. Races: check completed during/after upgrade cannot overwrite updating state; dismissal survives in-flight check; provider dispose while remote command pending releases still-alive shared lease; cross-server stale replies discarded.
8. Busy gates and two-phase invalidation: private CLI/ACP operations, generation/approval/login/terminal, all same-server aliases, no send-between-unlock-and-invalidation, no prompts/history creation, visible cached UI retained.
9. Notifications: provider mount no notice; first actual chat entry enables; acknowledge same day/version persists; changed version/day visible; deletions and server switches do not leak notices; no layout shift.
10. AgY archive fixture-only tests: corrupt CRC, traversal/symlink, encrypted/special entries, zip bomb/low disk, existing version dir, failed extraction leaves previous launcher intact. Never test upgrades on the current live Codex/AgY tools or user production servers.

## Primary references verified during this change

- https://code.claude.com/docs/en/setup — native/npm updates, native path, release channels and custom launcher caveats.
- https://claude.ai/install.sh — native release endpoint `https://downloads.claude.ai/claude-code-releases` (read only; not executed).
- https://raw.githubusercontent.com/agentclientprotocol/claude-agent-acp/main/package.json — current npm package/binary name and Node requirements.
- https://www.npmjs.com/package/%40zed-industries/claude-code-acp?activeTab=readme — publisher deprecation/rename notice.
- https://github.com/agentclientprotocol/codex-acp — current supported npm package and separate CODEX_PATH semantics.
- https://opencode.ai/docs/cli/ — `upgrade [target]`, install method and shared `acp` subcommand.
- https://www.antigravity.google/docs/cli/install/ and https://antigravity.google/cli/install.sh — native update command and per-platform manifest source (script read only).
- https://github.com/agentclientprotocol/registry/blob/main/README.md and https://raw.githubusercontent.com/agentclientprotocol/registry/main/antigravity-acp/agent.json — official ACP distribution metadata; versions fetched at runtime, not hard-coded as latest.

## Focused verification completed

- Additional admission proof: `test/core/agent_update_provider_test.dart` now has
  19 passing cases, including same-server profile aliases blocked during ACP
  generation/permission and CLI sending/interactive terminal use. Both prepare
  and applying a previously prepared plan reject while busy, with zero service
  mutation, no leaked lease and original chat state identity preserved. Log:
  `/tmp/valhalla-agent-updates.aOvCbg/update-busy-final.log`; targeted analysis clean.
- `flutter test --no-pub test/data/agent_update_model_test.dart test/infrastructure/agent_update_service_test.dart test/core/agent_update_provider_test.dart --reporter expanded`: 39 tests passed, exit 0.
- Targeted `flutter analyze --no-pub` of those three tests plus the update model, service, provider and lease provider: no issues, exit 0.
- Log: `/tmp/valhalla-agent-updates.aOvCbg/update-final.log`. Earlier failed compiler/style attempts remain in the log; the final runs are the acceptance results.
- Replaced the falsely named target-key test with actual key assertions for server/user/port/container binding/user/CLI/ACP/install command changes and cosmetic edit stability. Persisted metadata explicitly excludes executable commands, migration flags and catalog identity.
- Service fixtures capture SSH commands without executing them. Covered exact target changes before execution, pinned Docker ID/user, expired plans, zero/nonzero/missing exit, unchanged versions, Node/catalog rejection, cache/force behavior, standard Codex ACP flags, OpenCode deduplication, verified Claude adapter migration, and AgY manifest changes.
- AgY ACP archive protection additionally has **9 passing real local execution fixtures** in `test/infrastructure/agent_update_archive_test.dart`: the actual command produced by `prepare` runs in temporary HOME with fake curl copying a local archive, never networking or executing an agent. Valid extraction verifies size/SHA-256 manifest and launcher replacement; traversal, absolute/backslash paths, symlink, special/encrypted entries, corrupt CRC and a bounded 2 MiB high-ratio archive are rejected while old launcher/runtime remain unchanged. The suite explicitly skips non-Linux platforms; Linux must run it and missing Python is a failure, not an implicit skip. Low-disk, over-20,000-member and existing-version-directory behavior remain command/static assertions, **not dynamically exercised fixtures**. Evidence: `/tmp/valhalla-agent-updates.aOvCbg/archive-execution.log` (9 passed; focused analysis zero issues).
- Provider fixtures have no real environment services or SSH access. Covered daily checks and notices across restart, exact 15-minute failure boundary, interrupted errors and successful recovery, current-server scope, two probe slots and coalescing, edited target cache separation, one-use plans, install/login busy gates, and stale check replies arriving during/after an update.
- Restored the removed lifecycle regression with separate parent/child ProviderContainers: the child updater is destroyed while apply is pending, the parent's live lease is still held until completion, then releases and can be reacquired. The interrupted marker remains persisted and no command is replayed. This does not dispose the lock itself to manufacture a passing assertion.

Unchecked: real server installation/upgrades, dynamic low-disk/over-20,000-member/existing-version-directory archive fixtures, native CLI vendor behavior on all OS versions, real login/session continuity and ADB UI. Those require isolated integration acceptance; no production upgrade was authorized by this handoff. Whole-project gates and UI/runtime integration tests remain the parent agent's responsibility.
