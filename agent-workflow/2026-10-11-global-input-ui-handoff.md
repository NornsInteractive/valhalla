# Global mobile keyboard intent follow-up

Original Valhalla / gemini-3.8-flash-high / high only. Accepted scope is mobile
dialogs/drawers/navigation/resume never reopens an underlying editor keyboard.
Terminal CustomTextEdit explicit intent is already implemented. Nonterminal
TextFields (search/edit/chat/settings forms) still need a narrow shared safeguard.

Whitelist lib/main.dart input lifecycle/root NavigatorObserver, shell input
focus plumbing only, authored ARB only if needed, this report. No core/native/
tests/checks/format/generation/build/ADB. Preserve updater mounting changes.

Prefer one stable mobile-only NavigatorObserver clearing the previous route's
focus history before a modal/new route builds, so popping cannot restore an
underlying field's software keyboard. Do not globally disable focus or remove
autofocus inside an intentionally opened input dialog. On inactive/paused mobile
app lifecycle clear input focus without changing controllers/drafts/page state;
resumed must not request focus. Reuse existing shell drawer focus handling.
Desktop physical keyboard and CJK IME must retain their current behavior.

Do not implement delayed repeated keyboard hiding: it could close a newly
explicitly tapped field. Root observer must remain stable across theme rebuilds.
OpenCode will verify search/dialog close, drawer/navigation, resume, explicit
retap input and preserved drafts plus desktop keyboard. Report actual files;
never claim physical phone/OEM IME behavior without device evidence.

Status: Implemented by Antigravity; pending OpenCode verification.

### Implementation Details:
1. `lib/main.dart`:
   - Added stable `_mobileInputFocusObserver` (`_MobileInputFocusNavigatorObserver`) mounted on `MaterialApp`.
   - On mobile (`android` / `iOS`), clears underlying route focus and scope history via `UnfocusDisposition.scope` before a modal/new route builds (`didPush`, `didReplace`), and ensures focus is cleared when modal/route pops (`didPop`).
   - Retains intentional `autofocus` within newly opened dialogs/routes and explicit user retaps.
   - On `AppLifecycleState.inactive`, `hidden`, `paused`, and `detached`, clears primary focus on mobile without resetting controllers, drafts, or page state. `resumed` does not request focus.
   - Desktop and CJK IME remain completely unchanged.
2. `lib/features/shell/main_shell.dart`:
   - Added `_unfocusContentScopeOnMobile()` reusing existing `_contentFocusScopeNode`.
   - Clears content focus scope history on mobile during tab navigation (bottom navigation bar, navigation rail, drawer selection, and notification/intent switches).
   - Preserves desktop physical keyboard and existing drawer focus mechanics.
3. No edits to terminal widgets, ARB, core, native, providers, or updater mounting.

