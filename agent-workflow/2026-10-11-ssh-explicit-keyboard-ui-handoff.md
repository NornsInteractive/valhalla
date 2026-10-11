# SSH terminal — explicit keyboard button

## User requirement

On the SSH terminal screen, tapping terminal output must not open the soft
keyboard. Provide an always-visible keyboard button at the lower right that
explicitly opens it. Preserve long-press selection/copy, scrolling, terminal
mouse reporting, shortcuts and physical keyboard/CJK input. Do not send cursor
movement commands just because the user taps the terminal.

## Ownership and scope

Only AgY, original Valhalla conversation
`ec81a4be-7543-45ee-8658-f68966f57d3b`, model
`gemini-3.8-flash-high`, effort `high`, may implement this UI.

Allowed files:
- `lib/features/terminal/terminal_view.dart`
- `lib/features/terminal/widgets/shared_terminal_canvas.dart`
- `lib/features/terminal/widgets/terminal_accessory_bar.dart`
- `packages/xterm/lib/src/terminal_view.dart`
- `lib/l10n/*.arb` (authored resources only, if an existing suitable label is absent)
- This handoff's Status section.

No core/provider/infrastructure, generated localization, tests, format, analysis,
build, ADB, git mutation, dependencies or subagents. OpenCode owns verification.
Preserve all existing dirty changes. Other terminal consumers keep their current
tap behavior by default: CLI, interactive login and Docker must not silently
inherit this SSH-only change.

## Existing mechanism and minimum complete change

`TerminalView._onTapDown` directly calls CustomTextEdit.requestKeyboard when
not hardwareKeyboardOnly. A default-compatible tap policy forwarded through
SharedTerminalCanvas and enabled only by the SSH caller is sufficient. Do not
use hardwareKeyboardOnly: it also disables the explicit mobile input path.
Tap may focus for hardware input and clear selection, without requesting IME.
Desktop normal focus/CJK behavior must remain functional.

The shared canvas already exposes a keyboard toggle and the accessory bar has
`terminal_accessory_keyboard_button`, but it is currently the first item INSIDE
the horizontally scrolling key row. For SSH place that control at the far right,
OUTSIDE that scroll area; do not add a second duplicate floating button or
obscure output/selection overlays. Keep >=44dp hit target, localized tooltip /
semantics, safe-area clearance and usability at 320dp / text scale 2. Reuse the
existing explicit request/close APIs. Button opens keyboard when closed; closing
again is acceptable. Changing tab, dialog close or app resume must not request it.

## Verification handoff

OpenCode must author real widget regressions: Android and iOS terminal tap does
not attach/show input connection; explicit lower-right button does; keyboard
button remains reachable after horizontal key scrolling; long-press copies;
selection-clearing tap does not open IME; modal close/resume stays closed;
physical input and desktop CJK remain; other consumers' default tap behavior
remains. Update only expectations actually superseded by this user requirement.
Run nearest IME, shared canvas, toolbar and scroll suites, localization parity
and targeted analyzer on exact source. No scratch copies or weakened assertions.

The preceding exact-source gate reports 125 passes / 3 failures, not a clean
gate. Also correct the two authored-resource defects within the allowed ARBs:
zh terminalConfirmPasteMessage lacks the count placeholder metadata; zh
updateArtifactHash duplicates the English label. The pinned-key drag test starts
at the ListTile center, although the draggable handle is now the 44dp leading
control; do not change reorder semantics to satisfy an incorrect pointer target.
OpenCode must inspect that failure and, if confirmed, drag the actual handle with
explicit coordinates while retaining the full persisted-order assertion.

## Status

Implemented by Antigravity. OpenCode's exact SSH toolbar suite passes 17 cases
(Android/iOS explicit IME, real 320dp/text-scale-2 geometry and Windows input),
localized catalog parity passes 9 cases, and targeted source/test analysis reports
no issues. The wider joint gate still has an unresolved existing pinned-key
reorder test; do not treat this as whole-app or device acceptance. See
`2026-10-11-ssh-keyboard-validation.md`. No new build or ADB install.

### Summary of Changes:
1. `packages/xterm/lib/src/terminal_view.dart`:
   - Added `requestKeyboardOnTap` parameter (default `true`).
   - In `_onTapDown`, when `requestKeyboardOnTap == false`: tapping focuses `_focusNode` and clears selection without requesting IME via `requestKeyboard()`.
   - Default tap behavior preserved for other callers (CLI, Docker, interactive login).
2. `lib/features/terminal/widgets/shared_terminal_canvas.dart`:
   - Added `requestKeyboardOnTap` (default `true`) and `pinKeyboardButtonTrailing` (default `false`).
   - Forwarded `requestKeyboardOnTap` to `TerminalView` and `pinKeyboardButtonTrailing` to `TerminalAccessoryBar`.
3. `lib/features/terminal/widgets/terminal_accessory_bar.dart`:
   - Added `pinKeyboardButtonTrailing` (default `false`).
   - When `pinKeyboardButtonTrailing: true`, places `_buildKeyboardButton` at the far right outside the horizontally scrolling pinned keys `SingleChildScrollView`.
   - Keyboard button has $\ge 44$dp hit target (`minimumSize: Size(44, 44)`), localized tooltip and semantics.
4. `lib/features/terminal/terminal_view.dart`:
   - Configured `SharedTerminalCanvas` with `requestKeyboardOnTap: false` and `pinKeyboardButtonTrailing: true` for the SSH view.
5. `lib/features/terminal/widgets/terminal_accessory_bar.dart`:
   - Localized keyboard toggle tooltip and semantics using `context.l10n.terminalToggleKeyboard`.
6. `lib/l10n/*.arb` (all 17 locales):
   - Added `terminalToggleKeyboard` in all 17 catalogs.
   - Added matching `@terminalConfirmPasteMessage` (`count: int`) metadata in all 16 non-English catalogs.
   - Localized `updateArtifactHash` in all 16 non-English catalogs without English cloning.

