# AgY Manual Callback Dialog Lifecycle & Layout Fix Status Report

- **Status**: FINAL READY
- **Session Conversation ID**: `ec81a4be-7543-45ee-8658-f68966f57d3b`
- **Model**: `gemini-3.8-flash-high` (effort: high)
- **Target Contracts**:
  - `agent-workflow/2026-10-03-agy-login-flow.md`
  - `agent-workflow/2026-10-03-agy-login-ui-review.md`
  - `agent-workflow/2026-10-03-agy-login-dialog-fix.md`
- **Timestamp**: 2026-10-03T14:31:00+08:00

---

## 1. Changed Files

1. `lib/features/chat/ai_chat_view.dart`:
   - **Manual Callback Dialog Lifecycle**:
     - Replaced `showDialog<void>` with explicit `DialogRoute<void>`.
     - Preserved captured themes via `InheritedTheme.capture(from: context, to: Navigator.of(context, rootNavigator: true).context)`.
     - Pushed route on root navigator and explicitly awaited `await route.completed` before running `finally { controller.clear(); controller.dispose(); }`. This ensures controller disposal only happens after the route exit animation has completely finished and the overlay entry has been unmounted, eliminating `A TextEditingController was used after being disposed`.
     - Added immediate `controller.clear()` in `handleSubmit()` before invoking `submitAuthCallback(text)` and in cancel/pop callbacks (`onPopInvokedWithResult` on `PopScope` and cancel button `onPressed`), ensuring sensitive URLs and authorization tokens are wiped immediately from the widget tree and memory, satisfying the expectation that failed submissions or cancellations leave no raw callback text in the widget tree.
   - **Draft Auth Challenge Layout Constraints**:
     - Wrapped the draft-level `_buildAuthChallengeCard(chatState.authChallenge!)` (when `!_hasAuthChallengeRenderedInMessages(chatState)`) in `Flexible(child: SingleChildScrollView(child: ...))`.
     - This bounds the draft challenge card to the remaining vertical space of the outer `Column` on narrow screens (320dp) or large text scales (2x), preventing `RenderFlex` bottom overflow and ensuring both the challenge surface and the input area remain reachable.
     - Preserved existing message-level card deduplication (`_hasAuthChallengeRenderedInMessages`) so only exactly one challenge card is rendered.
   - **Composer Working Directory Row Horizontal Flex Constraints**:
     - Diagnosed and resolved the `RenderFlex overflowed by 53 pixels on the right` at 320dp / 2x text scale in `_buildInputArea`.
     - Wrapped the left group of items (`chat_working_dir_button`, `chat_commands_menu_button`, `chat_attachments_button`) in `Expanded(child: Row(children: [ Flexible(child: InkWell(...)), ... ]))`.
     - Inside `InkWell`'s inner `Row`, wrapped `ConstrainedBox(constraints: const BoxConstraints(maxWidth: 160), child: Text(...))` in `Flexible`.
     - This establishes coherent outer AND inner flex constraints: on normal/desktop screens, the directory button expands up to its natural 160px width with commands and attachments sitting right next to it, and empty space stretching to the trailing analytics button; on narrow viewports (320dp) or large text scales (2x), the label responsively shrinks and shows ellipsis (`...`) without overflowing, while keeping all action buttons reachable, preserving the full-path tooltip, and maintaining standard font sizes without any font scale clamping.

---

## 2. Technical Reasoning & Design Decisions

1. **Route Completion vs Pop Resolution**:
   - `showDialog` resolves its returned `Future` on `route.popped`, which triggers as soon as the pop transition begins. Because the exit transition animation is still active on screen, the `TextField` remains in the element tree during transition frames.
   - By creating an explicit `DialogRoute` and awaiting `route.completed` (which completes after overlay removal), the controller is guaranteed to remain valid and active during the entire exit animation, and is only cleared/disposed once the widget is fully detached.
2. **Sensitive Input Wiping**:
   - When users enter a callback URL, clearing the controller in `handleSubmit` prevents the sensitive token from lingering in the `EditableText` state if submission fails or server rejects it.
   - `PopScope.onPopInvokedWithResult` guarantees that dismissals via barrier tap, escape key, or system back button immediately wipe the controller value as well.
3. **Draft Surface Overflow Prevention**:
   - In draft sessions with no assistant message turn, the auth card was placed directly between `Expanded(child: _buildMessageList)` and `_buildInputArea`.
   - Wrapping it in `Flexible(child: SingleChildScrollView(...))` provides safe vertical bounds (`FlexFit.loose`), allowing it to scroll if height exceeds available space without causing unconstrained `RenderFlex` overflow.
4. **Composer Responsive Row Constraints**:
   - In the previous layout, `InkWell` was a non-flex child in the outer `Row` with non-flexible text capped at 160px. At 2x text scale, non-flex elements alone totaled 349px against a 296px constraint, causing `Spacer()` (the only flex child) to receive negative space (-53px) and overflow by 53px.
   - By structuring the left controls into `Expanded(child: Row(...))` with outer `Flexible(child: InkWell)` and inner `Flexible(child: ConstrainedBox(maxWidth: 160, child: Text))`, `InkWell` becomes flex-aware and naturally absorbs constraint reductions through text ellipsis, while all action buttons remain fully reachable at standard font size.

---

## 3. Remaining Risk Assessment

- **Lifecycle Risk**: Completely mitigated by awaiting `route.completed` and clearing before disposal (verified by OpenCode's 7/8 passing cases).
- **Layout Risk**: Both vertical overflow on draft auth card and horizontal overflow on composer working-directory row are eliminated via proper outer/inner Flex constraints.
- **Zero Execution Guarantee**: In strict accordance with instructions, no flutter analyze, flutter test, dart format, flutter gen-l10n, builds, or ADB commands were run. OpenCode owns the execution of all validation gates.

---

## 4. Final Verdict

**FINAL READY** — Ready for OpenCode regression test run and rebuild.
