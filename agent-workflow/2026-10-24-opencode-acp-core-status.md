# OpenCode ACP Core Implementation Status

> Historical failed attempt, not acceptance evidence. This job reached free-model quota after creating this checklist and made no core implementation changes. Root subsequently implemented the core; OpenCode resumed with regression/verification ownership. Current evidence belongs to `2026-10-25-ssh-acp-test-findings.md`, `2026-10-25-ui-test-findings.md`, and final gate/release ledgers. The unchecked list below records that original attempt only.

## Overview
Implementing ACP Core per 2026-10-24-ssh-acp-implementation.md ownership: OpenCode owns `lib/core/providers/ai_chat_provider.dart` + new core tests.

## Progress

### Phase 1: AcpActiveRun + State Extensions
- [ ] Add `AcpActiveRun` class (immutable, in ai_chat_provider.dart)
- [ ] Add `serverRun`, `isServerBusy`, `isViewingRun` to `AiChatState`
- [ ] Add `clearServerRun` to `copyWith`
- [ ] Ensure backwards-compatible constructor

### Phase 2: Run Ownership & Decoupling
- [ ] Maintain run map by server target (not visible view)
- [ ] `isGenerating` reflects visible chat only
- [ ] `serverRun` prevents another prompt on same server
- [ ] Different servers may each own one run
- [ ] New draft created only on first explicit send
- [ ] Hidden chat updates reach repository even when filtered

### Phase 3: returnToRunningSession & Viewing
- [ ] Implement `returnToRunningSession()` - restores corresponding Agent/chat without interrupting work
- [ ] Background permission never steals focus
- [ ] Stop/permission responses validate captured run target

### Phase 4: deleteSession with stopAndClearRemote
- [ ] Optional `stopAndClearRemote` parameter
- [ ] Optional `expectedServerKey` parameter
- [ ] Local-only detaches without cancel
- [ ] Invalidates delayed saves before deletion
- [ ] Remote cleanup covers all deduplicated App-owned runtime keys
- [ ] Deletes local only after all cleanups succeed
- [ ] Partial cleanup remains visible/retryable
- [ ] Local-only usable offline
- [ ] No native remote history deletion

### Phase 5: inspectSessionRuntimes
- [ ] Returns affected runtime list using injected manager seam
- [ ] No production SSH in tests

### Phase 6: Runtime Generation Recovery
- [ ] On proven old terminal runtime, increment generation
- [ ] Retire verified old instance
- [ ] Persist cleared cursor/new key BEFORE opening
- [ ] Load/resume same remote session
- [ ] Agent without load/resume shows explicit unsupported error
- [ ] No session/new fallback or resend
- [ ] Running/unknown old runtime never silently resets

### Phase 7: Upgrade Marks RestartPending
- [ ] Agent upgrade marks related contexts `restartPending`
- [ ] Only idle, verified instances rotate
- [ ] Remote running/permission tasks block unsafe upgrade/restart

### Phase 8: Management Injection Seams
- [ ] Tests can run offline with fake inspectors/managers

### Phase 9: Tests (Failing First)
- [ ] Write failing regression tests
- [ ] Run focused tests
- [ ] Ensure tests inspect actual saved output and cursor, not just state flags

## Gaps to Report
- Root APIs must be present: `AcpRuntimeService.sessionKey` with generation, `inspect`, `activeForServer`, `manage`
- `AgentChatContext` already has `runtimeGeneration`, `runtimeRestartPending`, `clearPersistentRuntime`
- TerminalProvider APIs already added by root

## Current State
Reading implementation plan and existing code. Starting implementation.
