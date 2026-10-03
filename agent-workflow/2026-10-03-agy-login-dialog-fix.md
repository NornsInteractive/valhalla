# AgY-owned last-mile UI regression repair

## Latest follow-up (same owner, after first FINAL READY)

OpenCode fresh wt2.log: 7/8 real widget cases PASS (manual controller fix works).
One STRICT failure remains: 320dp x900dp / text scale2 initial render reports
`A RenderFlex overflowed by 53 pixels on the right` at test line489. Do NOT change
viewport/font test or ignore errors. Root source inspection suggests composer
_buildInputArea working-directory Row: non-flexible InkWell plus text capped at
160px, folder/dropdown/padding then commands/attachments/account icon controls.
At large text scale total intrinsic width exceeds parent. Diagnose exact Row,
make directory label responsively shrink/ellipsis with correct outer AND inner
Flex constraints while keeping all action buttons reachable and full-path tooltip.
Preserve ordinary layout and behavior; no fontsize clamp, overflow hiding or
wide-screen-only workaround. Check other rows if this is not the exact cause.
Tests/format/analyze/build/ADB remain OpenCode only. Update existing status and
mark FINAL READY then wait for /exit. Current OpenCode is investigating layout,
so source patch may proceed; final gates/build wait for your exit.

Exact renderer evidence now captured by OpenCode in /tmp/opencode/wt4.log:
Row at ai_chat_view.dart:3898:13, Row -> Column -> SafeArea -> input Container,
maxWidth296, actual intrinsic right overflow53. This CONFIRMS composer directory
row rather than the auth-method picker. Diagnostic assertion removals in widget
test are temporary and must be restored by OpenCode before final gates.

ONLY original Valhalla ec81a4be-7543-45ee-8658-f68966f57d3b,
gemini-3.8-flash-high / high. No tests, format, gen-l10n, analyze, build, ADB or
git mutations. UI/source changes ONLY in lib/features/chat/ai_chat_view.dart;
ARB only if genuinely needed. Root must not edit this UI; OpenCode owns testing.

## Proven defect (not just a test fixture)

OpenCode authored test/features/auth_browser_widget_test.dart. In captured
/tmp/opencode/wt1.log, second manual-callback cancel case reports:

`A TextEditingController was used after being disposed.`
TextField chat_auth_callback_input, ai_chat_view.dart:3168, during dialog removal.
The finally of _showManualCallbackDialog clears/disposes immediately after
showDialog's popped future resolves, while route exit animation still retains
the field. Repair lifecycle at the narrowest layer. Use standard widget-owned
controller disposal after unmount OR retain explicit DialogRoute and await its
completed (overlay removal) future before finally clearing/disposal. Preserve
root navigator, captured themes, barrier/cancel/back, localized UI, masked input,
target/request checks, loading/retry and no secret logging. Do not use a fixed
sleep, swallow Flutter errors, or leak the controller by omitting disposal.

## Additional layout risk to inspect

build's Column has Expanded(messageList) then non-scrollable authChallengeCard
outside it for drafts with no pending message, then input area. Live auth adds
waiting text + three fallback buttons, so 320dp/2x with four advertised methods
can exceed height. Confirm from constraints and minimally bound/scroll that
draft auth surface if needed; keep exactly one card and input reachable. Existing
pending-message card already lives in the message list; do not duplicate it.
This is a source/constraints risk, not yet a clean isolated failing test; record
the distinction. OpenCode will test strictly after lifecycle fix, no tests by AgY.

Write changed files / reasoning / remaining risk / FINAL READY to
agent-workflow/2026-10-03-agy-login-dialog-fix-status.md. Then exit cleanly; root
will read source, OpenCode must run all gates and rebuild/reinstall after this
product edit. Existing 13:40:52+0800 APK no longer final for these changes.
