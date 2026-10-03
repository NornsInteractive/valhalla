# SSH / ACP auth disconnect continuation

User: continue after the 14:44 release APK / 14:45 ADB install. Scope is the
remaining SSHStateError surfaced during racknerd readiness, and narrow auth
transport resilience. No new features, UI changes, dependency upgrades or
account actions authorized by this handoff.

## Root patch checkpoint (after actual red evidence)

With the guarded fixture corrected, callback cases (a) and (d) failed
while the other 9 passed (focused exit 1, no timeout). Root then patched ONLY
lib/infrastructure/acp/acp_oauth_request.dart: stderr failures join the awaited
operation; stdout, done and stdin close have immediate observers via eager
Future.wait; one 20s deadline covers the entire delivery including stdin; cleanup
always cancels stderr even if close throws. No URL/command/routing/UI change.
Any new run after this checkpoint is AFTER-fix proof, not original red evidence.
Do not edit product code. Complete the one SSH manager probe/report then exit;
root will request fresh after-fix/full/build/ADB gates separately.

Second patch supersedes the first race approach: require stderr drain before
success, alongside stdout/done/stdin; 20s covers write/read/completion AFTER the
exec channel is opened, not channel opening. Normal fake stderr must end as
native completed exec streams do. Fresh gate/build contract is now
2026-10-03-ssh-auth-disconnect-final-gates.md; original device close cause unknown.

## Evidence and limits

Prior sanitized diagnostic 2026-10-03T05:42:32.828045Z:
TerminalState.terminate -> AsyncQueue.closeWithError ->
SSHClient._terminatePendingOperations -> _handleTransportClosed.
This is the stack recorded when shared TerminalState stores the first terminal
error, NOT proof TerminalState.terminate itself throws. Local pinned dartssh2
4.1.0 matches the official archive on this function: it completes a void future
normally and stores StackTrace.current. Queue waiters are failed by teardown.
Only manager verifyAlive calls ping in our lib. Its awaited timeout chain appears
to handle rejection; reproduce before patching it. Manager disconnect and pending
connection fail call async client.close without observing its returned error;
this is another candidate, not a proven cause of the prior device event.

ACP callback deliverAcpOAuthCallback currently listens to stderr without onError,
and attaches stdout/done handling only after stdin.close. A failure there is a
credible AUTH-path unhandled-error mechanism, but real Google callback was never
performed in the previous device test. Do not falsely explain the prior event as
caused by an authorization callback that did not happen.

## OpenCode contract: diagnosis / tests first

Continue session ses_f0405efacffePPqWyhHc3GGJY7 with main AND small model
opencode/mimo-v2.6-flash-free. Read this contract, execute a bounded focused
investigation; stop after proof/report. Do not change lib, ARB or pubspec.

1. Add small test-only regressions using existing SSH manager and ACP callback
   test seams. Test pending heartbeat error/drop after timeout, coalesced verifiers,
   background->foreground, deliberate disconnect; errors should reach callers
   or connection state and MUST NOT become uncaught zone errors. Prefer real
   dartssh2 SSHClient on a fake socket for at least one pending global request
   teardown, reusing the package's visibleForTesting handlePacket fake-auth
   pattern if practical. No real remote socket, login or credential needed.
2. Test deliverAcpOAuthCallback stderr-only error (stdout 200, done normal),
   stdout error while stdin.close pending, stdin error, done error; immediate
   observers and cleanup are required. Existing success/routing/secret/limit
   assertions retained. No secrets in failure strings/output; dummy callback only.
   Current success test stderr remains open until session.close, so any future
   fix must not wait forever on fake or stalled stderr.
3. Run focused tests, capture true exit and exact failing assertion/unhandled
   stack. Keep test assertions strict (desired failure to caller AND no unhandled
   errors), no added skips, no catch-all success, no exception suppression to make
   green. Report actual fixture limitations vs product defects distinctly.
4. Write agent-workflow/2026-10-03-ssh-auth-disconnect-investigation-result.md with
   test names/results/source path/line + strongest supported cause/unknowns.
   Stop and exit after report; root will review evidence and own business patch.

All local edits via Edit/apply_patch (never Python/shell writes). Formatting ONLY
new/edited tests. No full build/ADB at this diagnostic stage. NO root/adbd changes,
account/OAuth, read credential/database/history, real inference, new sessions,
git mutation/commit/push or unrelated source cleanup. No model substitution.
