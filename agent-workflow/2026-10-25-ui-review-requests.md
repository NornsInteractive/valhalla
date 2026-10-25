> Resolved in final-ready verification: 115 regular tests passed, including unread/prepend, exact latest scroll, RTL/IME and localization parity. Historical diagnostics below describe intermediate work, not outstanding defects. See `2026-10-26-final-ready-findings.md`.

# Remaining UI review requests (actual regression evidence)

1. New ACP message `Stack` shrinks to zero width when no serverRun banner is shown. At 390dp the actual transcript rect changes from `Rect(195,49,195,654)` to `Rect(0,49,390,654)` when the banner appears. A non-positioned Consumer returning SizedBox.shrink makes Stack size to that child; with Positioned banner no such child exists. Force a stable full-width/full-height Stack (e.g. StackFit.expand / tight constraints), keep banner overlaid. This is a production layout bug; do not weaken the widget assertion.
2. The command label/copy row overflows 225px at width320/textScale2. Use a wrapping or bounded layout. Copy within scrolling body may require test ensureVisible; full details must scroll with fixed allow/cancel actions.
3. Unread counter must ignore prepending older pages. Absolute end = session.messageOffset + messages.length or stable tail IDs; do not count loaded historical messages as unread.

AgY alone modifies UI. OpenCode verifies widget behavior. Root does not change these UI files.
