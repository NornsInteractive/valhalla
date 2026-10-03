# Final auth-disconnect regression / delivery gates

Continue same OpenCode session, main and small opencode/mimo-v2.6-flash-free.
Supersedes diagnostic-only/no-build instructions after this document is explicitly
assigned. Root owns product business patch; do NOT hand-edit lib/ARB/pubspec.
UI remains original AgY's unchanged final UI, so no UI edit or new AgY task needed.

## Root evidence / actual patch

Two raw callback defects: stderr ignored (reported success plus unhandled error),
done error not observed until stdout completes. Existing stdin/stdout errors were
handled; no claim they were four product bugs. Your corrected tests reproduce
the two defects. Guarded fixture initially used await outside error zone, causing
timeouts; its repair is test-only and cannot be recorded as product fix.

Root first patch attached observers immediately but raced normal success with
stderr failure. Your fresh strict test found stderr could still be skipped when
normal completion won first. Root now awaits stdout AND stderr drain AND done
AND stdin closing together, eagerError true, with 20s deadline after channel
opening. It cannot report success while stderr is still unread. Finally closes
session and ALWAYS cancels stderr. No credential, command, routing or UI change.

## Execute

1. Fix ONLY the normal-session fixture in acp_oauth_callback_delivery_test.dart:
   native completed exec eventually closes BOTH streams. Existing fake completing
   done/stdout but keeping stderr forever until cleanup was incomplete. Normal
   mock stderr must emit onDone; for stderrErrorOnListen emit its error then close
   after listen attaches, so the strict no-unhandled and identical caller error
   assertions stay. Preserve all 11 assertions/cases, secret and host/Docker
   routing checks. No added skip/relaxed expectation. Do not work around this
   mock by changing production to ignore unread stderr.
2. Run callback11 + SSH transport19 focused (actual counts verified, not guessed).
   Retain the new real authenticated SSHClient fake-socket pending-heartbeat test
   and ALL older tests (including user deliberate disconnect). SSH probe passes:
   do not modify manager/reconnect or claim racknerd underlying cause fixed.
   Focused must green with no missed errors. Report blockers to root if genuine.
3. Mechanical format ONLY lib/infrastructure/acp/acp_oauth_request.dart and the
   two touched test files (authorized whitespace only). Fresh full analyze zero,
   full tests all green. 18 previous skips only, no new skips. Do not regenerate
   unrelated code or investigate unrelated packages. Capture true exits.
4. If all green, preserve current14:44 APK to NEW timestamped unique backup
   (never overwrite older backups), flutter build apk --release. Record exit,
   mtime UTC/size/sha256/cert; hash MUST differ from
   6ff2244ea5cf00db417c3b956b5aa7f2d5332610f1da5bc7315c40e8aa13035e.
5. Existing device127.0.0.1:14251 only, verify cert compatible then install-r,
   preserve data; stop on mismatch, no uninstall/pm clear/root/new emulator.
   Start MainActivity, finite foreground/process/fatal/ANR check. NO account,
   browser/OAuth/credential/database/history read or change, no real inference,
   no new session or remote probe. Google/live callback/Docker e2e pending user.
   Actual package ID: com.antigravity.valhalla.valhalla; launch its .MainActivity,
   not the placeholder com.example.valhalla. Offline device is a real blocker:
   report install/startup as NOT EXECUTED, no repeated indefinite reconnect loop.
6. Write diagnostic result and final gates evidence in
   agent-workflow/2026-10-03-ssh-auth-disconnect-investigation-result.md using
   Edit/apply_patch. Distinguish prepatch true red proof, guard/type/timeouts fixture
   errors, first root patch stderr race still failing, final strict passing,
   existing SSH underlying cause UNKNOWN; final APK/install/startup distinct from
   13:40 old browser proof. Record all executed gates/exits/counts/hash/backup.
   No private host/IP, authcodes/URLs or screenshots. Do not overwrite earlier
   auth phase report as though older device actions happened on new APK.
7. EXIT after evidence; no git mutation/commit/push. Root updates main docs.

Use proper file edit tools only, never shell/Python/heredoc writes. Do not stop
early after tests because build/install are explicitly authorized here. Do not
start multiple runners or use another OpenCode model.
