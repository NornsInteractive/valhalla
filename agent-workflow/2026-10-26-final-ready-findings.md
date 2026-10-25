# SSH + ACP final-ready verification

OpenCode `opencode/beam-free` ran the final commands. Its response generation later failed upstream, after all commands had completed successfully; acceptance below comes from command exit files and machine events, not its narrative.

- `flutter gen-l10n`: exit 0.
- Formatting changed Dart files: exit 0.
- `flutter analyze --no-pub`: exit 0, no issues.
- Eight-file focused suite (durable recovery, terminal provider, Agent updates, session isolation, initial scroll, interaction details/unread/RTL/IME, generation compatibility and localization parity): exit 0; **115 regular tests passed**, zero errors/failures/skips. Hidden suite-loading events are excluded.
- Broker stdlib suite: 34 passed, exit 0, including v1/v2 inspection/cleanup, exact process ownership, descendant stop and orphan refusal; no broker source changes followed this proof.
- Previous full terminal gate passed terminal/tmux behavior after its explicit-close fixture update; its sole remaining failure was missing non-English placeholder metadata. The final parity suite passed after AgY added the metadata.

Final command evidence (ignored): `build/ssh-acp-validation/final-ready-*` stores generation, format, analysis and machine test logs and actual exit codes. Earlier command metadata is in `verified-gates.json`; isolated crash evidence from invalid test teardown was retained under `crash-dumps/`, not committed. Fixed teardown joins readers before closing SQLite. Old reports are superseded.

Core implementation belongs to root; visible UI and ARB changes belong to original AgY Valhalla conversation / Gemini 3.8 Flash high. OpenCode owns tests, formatting, generation and verification. Source changes preserve legacy generation-0 hashes and JSON defaults, native remote session IDs/history, explicit cleanup boundaries and rejected drafts.

No ADB, real SSH/Agent conversation or Windows/Apple binary validation. Packaging and publication are separate gates and are not claimed by this report. Android and Linux release work follows only after these checks.
