# Final analyze source defects — AgY only

OpenCode generated l10n and ran full analyze: 7 issues, 6 remaining UI items.
Root fixes use_of_void_result by making existing business switchAgent return
Future<void> awaiting history loading; this is also required to avoid auth-init
racing local selected-session changes. Keep UI await switchAgent.

AgY original Valhalla/Gemini3.8FlashHigh/high, ONLY these corrections:

- EN ARB accidentally dropped existing chatCommandsDraftPreviewNotice when adding
  new keys; restore original HEAD text exactly (git show read-only), preserve all
  keys. ZH already has it. No tests or generated edits.
- copiedToClipboard getter not present. Reuse agentLoginTerminalUrlCopied for
  copied authorization URL. Guard async clipboard completion with mounted AND
  captured widget BuildContext context.mounted (receiver is State.context, use
  local `final snackContext = context` before await then check both afterwards).
- RadioGroup.onChanged is non-nullable; never assign null. Always callback,
  return if isAuthenticating; add enabled: !isAuthenticating to each Radio child
  (current installed Flutter Radio supports enabled). Keep other tile disables.

Update UI status READY. Don't run format/gen/analyze/tests/build/ADB. Final gates
owned by OpenCode; no expansion/other refactoring.

Root source review confirms restored original EN key, valid copied-label getter,
captured snackContext with mounted guards, non-null RadioGroup callback, Radio
enabled control. Original AgY /exit returned 0. UI stable for all final gates.
