# v1.0.4 — Obsolete Accessory-Bar Harness Fixture Fix

- Date: 2026-10-11
- Scope: `test/features/interactive_login_test.dart` only (plus this report). No prod/UI changes, no other test files touched.
- Last gate (`14 fail`) symptom: `TerminalAccessoryBar renders all keys and triggers callbacks` [E] at `interactive_login_test.dart:125`.

## Root cause

Two stacked defects in the standalone harness (old `group('TerminalAccessoryBar')`, lines 100–151):

1. **Missing provider scope + localization.** The harness pumped a bare `MaterialApp` with no `ProviderScope` and no `AppLocalizations` delegates. The production bar is a `ConsumerStatefulWidget` that watches `terminalSettingsProvider` and reads `context.l10n` (`terminalToggleKeyboard`, `settingsTerminalPinnedKeys` via `context_extensions`), so it threw immediately:

   ```
   StateError was thrown building TerminalAccessoryBar(...)
   Bad state: No ProviderScope found
     at _TerminalAccessoryBarState.build terminal_accessory_bar.dart:131
   ```

   Evidence: `/tmp/opencode/v104-gate-fluttertest.log` line 3134 (first exception), where the widget subtree dies on mount.

2. **Obsolete inline-key assumption.** The test asserted `Ctrl+D` and `↑` are permanently inline. The approved bar only pins `ESC/TAB/CTRL/ALT/Ctrl+C/PASTE` (`TerminalSettings.defaultPinnedKeys`); unpinned keys are grouped behind the More button (`terminal_accessory_more_button`) into the Nav (`↑ ↓ ← → HOME END PGUP PGDN`) and Edit (`Ctrl+C Ctrl+D …`) category panels. Because the build had already failed, the follow-on expectation also reported `Found 0 widgets with text "ESC"` (log line 3251, test line 125).

## Fix

Replaced the standalone `MaterialApp` with the file's existing localized `createTestApp` helper (already used by the passing `InteractiveLoginDialog`/`AiChatView` groups): it wraps `ProviderScope` with `tempChatRepositoryOverride()` + `fixedTerminalSettingsOverrides()` (storage-free `terminalSettingsProvider` via `test/support/fixed_terminal_settings.dart`) and a `MaterialApp` carrying `AppLocalizations.localizationsDelegates` / `supportedLocales`.

Kept **all** existing render checks and callback checks, and routed the unpinned keys through the intended panels:

- Pinned row (asserted inline, panel closed): `ESC`, `TAB`, `CTRL`, `ALT`, `Ctrl+C`, paste icon (`Icons.content_paste`) — each `findsOneWidget`.
- Callbacks retained: tap `ESC` → `pressedKeys` contains `ESC`; tap `CTRL` → `ctrlToggled`; tap `ALT` → `altToggled`; tap `Ctrl+C` → `pressedKeys` contains `Ctrl+C`; tap paste icon → `pasted` true **and exactly one delivery** (`pasteDeliveries == 1`).
- Panel reachability: tap `terminal_accessory_more_button` → `↑` rendered once in Nav category and delivered exactly once (`HoldRepeatKey` fires `onPressed` once on pointer-down, cancels on up); switch to `Edit` tab → `Ctrl+D` rendered once and `pressedKeys` contains `Ctrl+D`.

No assertions deleted, no `skip:`/`markSkipped`, no suppression; remaining auth tests in the file untouched. Cross-checked against the passing `shared_terminal_canvas_test.dart` panel-interaction patterns (keys, more-button toggling, hold-repeat arrow semantics).

## Verification

- Format: `dart format test/features/interactive_login_test.dart` → 1 file changed (test file only).
- Run: `flutter test test/features/interactive_login_test.dart --no-pub --reporter expanded`
  → full log `/tmp/opencode/v104-fix-interactive-login.log`, **exit code 0**.
- Counts: **6/6 tests passed** (`+6`, `All tests passed!`), 1 failed → 0, 0 skipped.

| # | Test | Result |
|---|------|--------|
| 1 | TerminalAccessoryBar renders all keys and triggers callbacks | pass |
| 2 | InteractiveLoginDialog renders dialog and returns null on Close | pass |
| 3 | InteractiveLoginDialog returns true on Finish & Verify | pass |
| 4 | InteractiveLoginDialog copyAllButton copies terminal buffer to clipboard | pass |
| 5 | InteractiveLoginDialog detects login URL, renders loginUrlChip, and copies URL | pass |
| 6 | AiChatView Interactive Login Integration triggers launcher and rechecks loginAgent | pass |

## Re-run command

```
flutter test test/features/interactive_login_test.dart --no-pub --reporter expanded
```
