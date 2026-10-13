# ACP workspace browser test migration — 2026-10-13

Only `test/features/acp_remote_workspace_browser_test.dart` changed. The public
`RemoteWorkspaceBrowserDialog.show` entry now obtains an injected
`remoteBrowserFactoryProvider`; its small factory fake delegates to the real
`agentRemoteBrowser` / `AcpWorkspaceFiles` with in-memory Docker SSH responses.
Legacy chat-notifier directory methods throw if called. No real SSH, ACP session,
server mutation, UI edit, generation, build, full-suite run or ADB operation.

The 17 cases preserve parent navigation/default resolution, filtering/search,
list/cards/images, image preview, error confirmation, late result cancellation,
and localization. Directory mode may hide or disable files, but never select one
as a directory. New boundaries cover image capability plus unsupported archive
filtering and selection counts, same-ID container/user edits, session/draft-folder
changes, caller disposal while awaiting the factory, and cancellation without
creating/sending any conversation or closing shared SSH.

## First focused run

```sh
flutter test --no-pub --concurrency=2 --reporter=expanded test/features/acp_remote_workspace_browser_test.dart
```

**BLOCKED at compilation; zero test cases executed.** The wrapper snapshot still
contains the old UI body and references an undefined `serverConnectionProvider`
at `lib/features/chat/widgets/remote_workspace_browser_dialog.dart:122` and `:194`.
AgY owns and is actively replacing this wrapper; no product fix was made by this
test agent. Rerun this command after its thin-wrapper replacement lands.

Three-view regression is deliberately retained: replacing ACP with a shared
two-state list/grid browser must not silently remove its existing image view.
The tests do not skip capability/count assertions or replace the new browser with
old notifier-only fakes to obtain a passing result.
