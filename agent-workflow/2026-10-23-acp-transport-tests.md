# ACP transport tests

## Changed

- `test/infrastructure/acp_client_adapter_durable_test.dart`: rewrote persistent fake init handling and added durable adapter tests.
- Removed scratch `test/infrastructure/min_persistent_test.dart`.

## _autoReplyInit behavior

- Parses stdin lines as JSON outer envelopes and reads `outer['frame']`.
- `initialize` replies with `{type:frame, frame:{jsonrpc:2.0, id, result:{protocolVersion:1, agentCapabilities:{}, authMethods:[]}}}`.
- `session/new` replies with `{sessionId:'sess'}`.
- `session/cancel` replies with an empty result.
- Persistent outbound frames are wrapped as outer envelopes, not raw ACP lines.

## Tests

- `initializes and prepares a persistent session`
- `permission request is emitted and dispose suppresses response`
- `explicit cancelPrompt sends session/cancel`
- `completed turn without live prompt emits complete`
- `initial status completed produces status and caught_up events`

## Verification

- `flutter test test/infrastructure/acp_client_adapter_durable_test.dart --timeout=120s`: 5 passed.
- `flutter test test/infrastructure/acp_ssh_durable_transport_test.dart --timeout=120s`: 3 passed.
- `flutter analyze test/infrastructure/acp_client_adapter_durable_test.dart`: no issues.