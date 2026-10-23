# ACP durable runtime and daily update prompt

User approved implementation: server-side Python stdlib broker, no public port,
explicit deployment consent, host and Docker agents, completed output retention
7 days. Closing/backgrounding/killing the app must detach, never cancel a turn.
Pending permissions remain pending. No real development Agent prompts in tests.
Original `.gitignore` modification and ignored `promo/` assets are user work.

## UI ownership: original AgY Valhalla only

Use conversation ec81a4be-7543-45ee-8658-f68966f57d3b,
gemini-3.8-flash-high, effort high. Modify UI/ARB only, not core implementation.

Core contract being implemented by Codex:

- AiChatState: `persistentRuntimeSetupRequired` bool,
  `persistentRuntimeSetupError` String?, `isSettingUpPersistentRuntime` bool,
  `recoveryNoticeDismissed` bool.
- AiChatNotifier: `Future<bool> approvePersistentRuntime()`,
  `void dismissPersistentRuntimeSetup()`, `void dismissRecoveryNotice()`.
- Show one consent dialog when setup required, explain Python 3 user-level
  service, SSH only/no public port, remote output stored 7 days after completion,
  agent continues after app exit. Enable calls approve; on success keep draft
  and let user send explicitly. Cancel closes consent, never sends a message.
- Incomplete/failed ACP recovery notice has dismiss action. Dismiss hides the
  notice only; preserve diagnostics/status. Do not hide CLI warnings accidentally.
- `AppUpdateState.pendingAutomaticPrompt` bool and notifier
  `Future<bool> claimAutomaticPrompt()`; root route coordinator watches the flag
  and calls claim immediately before showing existing AppUpdateDialog. Foreground
  only, one dialog at a time; defer behind active modal; never steal focus or IME.
  Root listener must not consider cache restoration an automatic check result.
- UI uses existing components and complete authored-localization parity.

## Verification ownership: OpenCode

Confirmed-free model only. Test broker in isolated temp dirs/fake ACP worker,
real process termination of the ATTACH client, not production Agent. Test daily
calendar checks, failed-check backoff, prompt claims. Code generation, format,
analysis, build and ADB belong to OpenCode under current rules. No release until
all core/UI/device gates actually pass; each release gets a new version.

## Completion gates

Runtime resource boundary: this implementation owns one broker and one ACP
process per local chat/Agent pair, retained until completion retention expires.
It does not yet pool idle Agent processes; frequent creation of many chats adds
server memory/process cost. A future idle eviction must perform a real Agent
resume before accepting another prompt, never reuse cached initialize/session
responses against a newly spawned Agent as if its session were still live.

Prompt acceptance idempotent; output persisted before delivery; reconnect cursor
committed with message checkpoint; no duplicate message/tool/permission replay;
resume live output and prompt completion after app restart; permission decisions
only user/explicit configured policy. Existing legacy sessions retained without
silent new remote session. Unsupported host reports clear error without claiming
durability. Server/container/admin termination is outside survival guarantee.
