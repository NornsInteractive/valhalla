# Terminal post-verification corrections — AgY only

Original Valhalla / gemini-3.8-flash-high / high. Implement after updater UI
without discarding existing changes. Terminal ownership same prior handoff.
No checks/tests/gen/format/build/ADB. OpenCode owns evidence.

Observed actual source issues:

- Read agent-workflow/2026-10-11-terminal-final-validation.md P1-P4 first.
  Both canvas and customize dialog import nonexistent core/theme/valhalla_theme.dart;
  monoTextStyle belongs to core/design/tokens.dart. Replace imports, no new theme.
  SSH terminal overlay still reads nullable activeTab.bridge at line 421 after
  originatingTab was captured; use captured non-null originatingTab consistently.
  Constrain AlertDialog content width explicitly so ReorderableListView is never
  asked for unsupported intrinsic viewport dimensions. Preserve narrow/large-font
  scrolling; do not replace test assertions with skips.

- CustomizePinnedKeysDialog AlertDialog.actions contains Spacer. Actions uses
  OverflowBar, not Flex; remove the invalid ParentDataWidget. It produces
  Incorrect use of ParentDataWidget in narrow/large-font and save tests.
- New dialog strings Pinned(count), No pinned keys, Available to add(count),
  and Failed to save pinned keys:error are hardcoded English. Add translated
  ARB keys/placeholders for all locales; use safe localized save failure, no
  raw diagnostic key in ordinary text. Remove unused localization/theme imports.
  Modifier tooltips (Ctrl/Alt locked/one-shot/tap/long-press) and keyboard/more
  actions must also be localized; CTRL/ALT/F1 themselves remain standard keys.
- Remove/unpin and drag handles currently use tiny controls/dense padding;
  maintain >=44dp actionable hit areas and localized labels/tooltips. Existing
  accessory arrow repeats must produce one initial key, no duplicate tap.
- Follow OpenCode final terminal validation report for additional genuine source
  defects, not fixture mistakes. Do not change core encoding or tests.

Do not restore legacy onPaste clipboard reread merely to satisfy an obsolete
test. Confirmed paste must use exact captured text and originating terminal.

Status: original AgY CLI restarted on user request; confirmed correct original
conversation/model/high and active source inspection. This phase also repairs
the updater nonexistent Close getter and hidden metadata/link-badge readability.
No completion claim until actual edits and OpenCode regression evidence.

OpenCode next bounded gate (after AgY stops writing): generate localizations,
format only changed UI files, then terminal IME/scroll/keys/canvas/toolbar and
terminal-settings widget suites, remote file view and localization key parity.
Use exact working tree, never a scratch-only source patch. Preserve assertions,
fix only obsolete test-fixture API/signatures under test ownership. Actual UI
failures return to AgY; Codex does not change their presentation or interaction.
