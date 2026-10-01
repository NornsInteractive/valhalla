# Live catalog / draft UI final verification and release

Continue OpenCode session with explicit main/small `opencode/mimo-v2.6-flash-free`.
Preserve dirty worktree; no commit/push, no real login/credentials/inference/remote history.
All test code/execution, format/gen-l10n/analyze/build/ADB are OpenCode's responsibility.
Root owns business; original AgY owns UI. Do not edit product semantics.

Current stage: AgY original-session UI READY after root review corrections (official
browser bridge, correct target fields, live/retry command catalog, target/mounted
guards, await-save, initialValue compatibility). UI is frozen for OpenCode verification.
Browser10 and prior OAuth40/whole1532 tests are previous snapshots; new UI gates required.
Original Valhalla has now reviewed and accepted the three narrow edits; its exit
resume ID was verified as ec81a4be-7543-45ee-8658-f68966f57d3b. Root authorizes release
and ADB installation ONLY after the final gates below pass. Stop on a failed gate.

Root late-callback review: commands dialog Consumer has a child WidgetRef. Retry
must also check its `ctx.mounted` after await before reading that child ref; checking
only the parent AiChatView mounted is insufficient when just the dialog closes.
AgY is receiving this narrow guard fix; prove closing a pending retry stays safe.

Invocation incident: combining --conversation with --prompt-interactive created
unexpected conversation 2f253f26-2292-40b8-9e26-a0aa7c9121a5 after restoring original.
That process is stopped. Its three narrow UI edits (AcpSlashCommand show import,
context.mounted guard, removing unused hasRemoteModel) were subsequently inspected
and accepted by original Valhalla; the incident remains recorded in its UI report.
Original-session reconciliation is complete; final verification gates remain.
Never use --prompt-interactive for this original-only workflow again.

Browser bridge: lib/core/services/model_authorization_browser.dart,
Android MainActivity method channel valhalla/model_authorization -> openBrowser.
Mock channel proof: HTTPS official host allowed, http/wrong host/userinfo/non443 port
rejected before dispatch, false/null/plugin/platform errors sanitized fixed browser failure.
No actual OAuth URL/browser launch/credentials. Android Kotlin compile covered by release build later.

After UI READY:
- gen-l10n and format ONLY task-touched UI/business/test files; no broad rewrite.
- Relevant existing/new widget tests: commands visible on draft, read-only discovery,
  loading/empty/retry, protocol commands and $skills insertion, local settings/cwd
  actions do not insert or send invented commands; target/dispose late-result guards.
- Settings empty/missing current model never Dropdown assert, refresh preserves a
  valid selection and never auto-applies first catalog item; HTTP failure still
  permits permission controls, dedicated localized warning/empty text.
- Codex-only independent authorization confirmation shows selected server/container/user,
  rejects declined confirm, waiting/cancel/dispose correctly cancel, no secrets/errors
  leaked. Preserve CLI callers with optional callbacks. Mock all actual authorization.
- Report defects to root (business) or AgY (UI), never fix UI yourself.
- Final format check, analyze no issues, focused and full flutter tests. Record all counts.
- Only after green gates, flutter build apk --release (normal pub if needed to refresh
  generated registrants). Preserve old APK recoverably before overwrite; record fresh
  mtime/size/SHA256/package/version/signing cert. Existing debug signing is not store signing.
- adb devices -l, use existing authorized target 127.0.0.1:14251 if available; never
  uninstall/clear data. adb install -r newly built APK, resolve/start app and inspect
  current process/logs for observed crash/ANR; do not claim real Agent acceptance.
- No unrelated device actions, agent changes, account login or remote prompts.
- If target unavailable record blocked installation, do not invent success.
- Write exact final report agent-workflow/live-models-draft-release-verification.md.
