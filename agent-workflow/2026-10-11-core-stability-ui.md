# AgY handoff: retained scroll and bounded work

Only original Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b,
gemini-3.8-flash-high, effort high. Read core-stability.md and project UI rules.
Own only lib/features/chat/ai_chat_view.dart,
lib/features/files/sftp_file_view.dart and this report. No core/data/native/tests,
dependencies, generation, format/analyze/test/build/ADB, git or subagents.

Investigate and fix concrete mechanisms, preserving existing layout and strings:

1. ACP long history: current listener scans nextMessages.any(...) on unrelated
   state changes to detect prepend; gate by actual message list identity/change.
   Post-frame session and prepend jumps must capture session/target and check
   they're still current when executed. Do not let a callback from old history
   move a newly selected session. Guard disposed scroll callbacks. Preserve
   browsing position during stream; follow output only when already near bottom.
   Keep first opening at latest message, history paging, stable message/tool keys,
   selection/copy/attachments/approval and auth browser launch behavior.
   Prefer comparing same-session messageOffset decrease for true history prepend;
   ordinary streamed messages replace the list too, so identity gating alone
   still performs a full scan during every streamed flush. Initial history load
   must still scroll to latest after the real messages have laid out.

2. Remote files: ListView and GridView currently have no path/target scroll
   identity. Preserve same-path refresh and page return position, while new
   directory starts independently; do not reuse another server's scroll. Reuse
   PageStorageKey or existing controllers rather than inventing persistence.
   Preserve list/grid adaptation, hidden file opacity, bookmarks, editor and
   batch actions. Scope selected paths to target/path; do not reset on transfer
   progress or harmless same-directory refresh. Retain cached list during reload.

No new controls or text unless necessary; narrow320dp, 2x fonts and RTL must retain
behavior. Record exact changes and any unresolved mechanism below; OpenCode will
write/run regressions. Do not claim validation based on reading code.

## Result

Completed AgY UI stability implementation and review follow-up within exact whitelist (`ai_chat_view.dart`, `sftp_file_view.dart`):

1. **ACP history and stream scroll stability (`lib/features/chat/ai_chat_view.dart`)**:
   - Comprehensive target identity guards: All delayed/post-frame scroll callbacks (`initState`, `_followBottomIfNeeded`, `_handleSend`, session switch, prepend, and late history arrival) now capture and verify both the server endpoint (`activeServer.connectionKey`) and agent profile (`activeAgentProfile.id`) alongside session ID before scrolling, ensuring target switches never execute stale scroll adjustments.
   - Late-arriving initial history: Added `_pendingInitialHistory` flag (set true when initial session has empty messages on `initState` or session switch). When initial history finishes loading for the same session (`_pendingInitialHistory && nextMessages.isNotEmpty`), it resets the flag and schedules a post-frame scroll jump to the latest message, properly handling late history arrival without breaking subsequent stream reading positions.
   - `_scrollToBottom` and stream following: Guarded `_scrollToBottom` with `if (!mounted || !_scrollController.hasClients) return;`. Guarded `_followBottomIfNeeded` with `!mounted || !_scrollController.hasClients || !_userNearBottom`, captured target identity, and re-verified `_userNearBottom` inside post-frame, ensuring user browsing position is strictly respected when scrolled up during streaming.
   - Prepend detection: Replaced the O(N) `nextMessages.any(...)` scan with O(1) `messageOffset` decrease check (`prevOffset != null && nextOffset != null && nextOffset < prevOffset && nextMessages.length > prevMessages.length`), guarded by target identity.

2. **Remote files scroll identity, selection isolation, and height stability (`lib/features/files/sftp_file_view.dart`)**:
   - Scroll storage identity: Bound `ListView.separated` and `GridView.builder` to `PageStorageKey<String>('sftp_files_${serverConnectionKey}_${state.currentPath}_${useGrid ? "grid" : "list"}')`, leveraging Flutter's native `PageStorage` to isolate scroll offsets by server connection settings record (`connectionKey`), directory path, and layout mode. Same-path refreshes and return navigation restore scroll position; different directories and servers remain completely independent.
   - Target and path selection scoping: Listened to `activeServerProvider.select((s) => s?.connectionKey)` and `sftpProvider.select((s) => s.currentPath)` to clear `_selectedPaths` and reset `_isSelectionMode = false` only when the active target server or directory path changes (`previous != null && previous != next`). Transfer progress updates and harmless same-directory reloads leave selections untouched.
   - Retained cached list and constant height during reload: Moved the refresh `LinearProgressIndicator(minHeight: 2)` into a `Stack` overlay (`Positioned(top: 0, left: 0, right: 0, ...)`) inside `Expanded`. The file list retains 100% of its viewport height before, during, and after background reloads, ensuring scroll offset does not jump.

Untested handoff status: Implementation complete. Per constraints, no core/test files touched, no formatting, analyze, tests, build, ADB, or git commands executed. Ready for OpenCode regression suite.
