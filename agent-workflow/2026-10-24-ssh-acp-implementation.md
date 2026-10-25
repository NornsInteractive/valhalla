# SSH + ACP stability and interaction implementation

Accepted: SSH and ACP only; preserve at least one SSH tab; allow viewing other ACP chats/agents and editing drafts while a run continues, but one executing ACP turn per server target; delete dialog defaults to local only and offers explicit stop + purge of App-owned runtime data. No ADB. UI only original AgY Valhalla / gemini-3.8-flash-high / high. Tests, format, analysis, builds via OpenCode free models. On green gates publish a new patch/build to GitHub, Ygg proxy and official website (Android 3 APK/AAB + Linux x64, no Actions).

## Ownership

- Root: `assets/runtime/acp_broker.py`, `lib/infrastructure/acp/acp_runtime_service.dart`, `lib/data/models/chat_session.dart`, `lib/core/providers/terminal_provider.dart`, docs.
- Root also owns `lib/core/providers/ai_chat_provider.dart`, `lib/infrastructure/acp/acp_background_run.dart` and repository metadata changes after the first OpenCode core attempt hit quota. OpenCode owns regression tests and verification only; no implementation/UI/ARB edits.
- AgY UI: `lib/features/terminal/terminal_view.dart`, `lib/features/chat/ai_chat_view.dart`, and ARB strings; no core edits, tests, builds or git.
- OpenCode verification: tests/format/generation/analyze/build later after core/UI freeze. No production SSH/Agent prompts or credentials, no test skips or weakened assertions.

## Root core APIs (being added)

- `AgentChatContext.runtimeGeneration` int default 0, `runtimeRestartPending` bool default false; copyWith supports both plus `clearPersistentRuntime` (clears runtime key/cursor only). Old JSON remains valid.
- `AcpRuntimeService.sessionKey(identity, profile, sessionId, {int generation = 0})`: generation 0 retains exact previous hash.
- `AcpRuntimeService.inspect(SSHClient, {required String runtimeKey}) -> Future<AcpRuntimeStatus>`.
- `AcpRuntimeService.activeForServer(SSHClient, String serverId) -> Future<List<AcpRuntimeStatus>>`: only App-owned active turns; no transcript read.
- `AcpRuntimeService.manage(SSHClient, {required String runtimeKey, required String action, bool stopRunning = false}) -> Future<void>`; action is retire/purge. Busy work requires stopRunning true; idempotent if absent. Purge affects only verified runtime folder, never native Agent history/project files.
- `AcpRuntimeStatus`: runtimeKey, state, alive, childAlive, protocolVersion, remoteSessionId, turnId; `canRecover` only proven terminal/expired/exited runtime. `AcpRuntimeUnavailableException.status` emitted by production open for such old instances. Unknown running/permission states must not restart automatically.
- `AcpRuntimeService.open` keeps existing signature/injection seam. Its production implementation probes before attach and uses profile.serverId for server concurrency scope. Do not change fake opener signatures.
- `TerminalNotifier.closeTabById(String id, {required String expectedTargetKey})`, `reconnectTab(String id, {required String expectedTargetKey})`; old closeTab(index) compatibility wrapper stays. Current target from TerminalHistoryRecord.targetFor(activeServer). Both validate target and membership and keep last tab. Reconnect preserves terminal output and never replays commands.

## OpenCode ACP provider/UI contract

Add shared immutable `AcpActiveRun` in ai_chat_provider.dart: serverTargetKey, serverId, sessionId, agentId, agentName, runtimeKey?, turnId?, state (running/waitingPermission/reconnecting), `isBusy`.
AiChatState adds nullable `serverRun`, getters `isServerBusy` and `isViewingRun`, constructor/copyWith backwards-compatible with clearServerRun.

- Visible selection is independent of run ownership. Run aggregation/checkpoints/permission IDs belong to captured server/session/agent/turn, not currently visible view. Maintain a map by server target; do not swap Riverpod state temporarily to run callbacks. Existing hidden chat updates must reach repository even when filtered from current visible sessions.
- state.isGenerating reflects the visible chat only; serverRun prevents another prompt on the same server. Different servers may each own one run. New draft is still created only on first explicit send.
- `returnToRunningSession()` restores the corresponding Agent and chat without interrupting work; background permission never steals focus. Stop/permission responses must validate captured run target to avoid acting on a newly selected chat.
- `deleteSession(id, {bool stopAndClearRemote = false, String? expectedServerKey})`: local-only detaches without cancel, invalidates delayed saves before deletion so deleted history never resurrects; remote cleanup covers all deduplicated App-owned runtime keys in that local chat, and deletes local only after all selected cleanups succeeded. Partial cleanup remains visible/retryable. Local-only is usable offline. No native remote history deletion.
- `inspectSessionRuntimes(id)` gives UI the affected runtime list using injected manager seam, no production SSH in tests.
- On proven old terminal runtime, increment generation, retire verified old instance, persist cleared cursor/new key BEFORE opening, then load/resume same remote session. Agent without load/resume must show explicit unsupported error, not session/new fallback or resend. Running/unknown old runtime never silently resets.
- Agent upgrade marks related contexts restartPending; only idle, verified instances rotate. Remote running/permission tasks block unsafe upgrade/restart even when another chat is selected.
- Preserve existing model discovery (CLI API, no hidden chat creation), auth, retention, replay ordering and target checks.

UI: compact terminal state badges + reconnect menu; close ordinary tab confirmation, tmux detach wording; preserve current accessory layout/animation. ACP run indicator + return action, busy send disabled with reason, bounded permission detail sheet/dialog (80% available height, scroll content and fixed actions), two-mode delete confirmation, return-to-latest with unread MESSAGE count, no layout-shifting reconnect banners. Keep current initial-scroll fix; matching outer KeyedSubtree keys are correct and must not be changed as a supposed bug.

## Evidence and stop conditions

First demonstrate each behavioral defect with isolated regressions. Cover 320/390dp, 2x text, RTL, IME, server switch with dialogs, concurrent state changes, 7-day expiry, v1/v2 migration, real isolated process ownership and tmux, background output + cold replay, upgrade + same remote thread, delete failures/idempotency/no resurrection. No ADB or real developer Agent prompts. Release only after actual final command exit codes and package/channel checks pass; failure resumes same version, never increments for a retry.

## 2026-10-25 continuation (not acceptance evidence)

OpenCode `opencode/nemotron-3-ultra-free` is responding again. Separate external jobs own Python broker tests and Dart tests/fixtures. Initial analyze is red (new ARB generation pending, mock override mismatch, UI/core lints); existing 12 broker tests passed before the latest hardening. New code is not yet verified or released.

Broker cleanup now verifies PID, UID, process group and start time. It checks live descendants after the leader exits; unprovable orphan group ownership fails closed instead of reporting successful cleanup. Add a regression for a TERM-exiting group leader with a child ignoring TERM. New UI must use typed target/completer guards, no dynamic fallbacks.

Foreground inventory discovery requires the existing persistent-runtime consent, is coalesced per server target and precedes recovery. Switching views preserves the task owner; disconnect detaches/checkpoints without cancel. Check concurrent server switching, lost-network tasks while another chat is viewed, and rejected draft preservation before acceptance.
