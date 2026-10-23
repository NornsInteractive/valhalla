# ACP provider tests report

Date: 2026-10-23

## File
- `test/core/acp_durable_recovery_test.dart`

## Tests
- production flag consent send holds draft and inserts no messages: pass
- approval installer override called once preserving draft: pass
- dismissRecoveryNotice retains status/diagnostics: pass
- AgentChatContext runtimeKey/cursor JSON roundtrip: pass
- ChatMessage.runtimeTurnId JSON roundtrip: pass
- managed recovery regression (live before+missed+live content, saved cursor 8): pass
- initial completed status is not terminal before backlog: pass

## Verified existing
- `test/core/background_recovery_chat_state_test.dart`: pass
- `test/core/ai_chat_provider_test.dart`: pass

## Notes
- Merged five consent/dismiss/JSON tests back; removed unused imports.
- No production/UI changes.
