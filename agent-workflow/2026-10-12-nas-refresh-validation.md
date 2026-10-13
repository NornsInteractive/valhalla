# OpenCode: stability/offline/UI validation

Read agent-development-rules.md and 2026-10-12-nas-refresh.md. Only test/** and this
report writable for now. No product/UI/dependency edits, format, generation, builds,
install, git, external operations or subagents in this first phase. Explicit free
model only; report actual model and failure rather than claiming success.

First task: add a deterministic regression using real dartssh2 SSHClient plus fake
SSHSocket and protocol packet injection. See existing
test/infrastructure/ssh_client_manager_transport_test.dart and local proof
/tmp/valhalla-app-center.ShesTL/ssh_unhandled_probe.dart. Cover SFTP subsystem pending
then transport close, refusal, accepted path and channel-open transport failures.
Await public operation failures and assert no unhandled zone errors; ensure tests
do not silently time out inside an error zone. Actual current library leaks a Future
from sendSubsystem('sftp'). Root will vendor/fix this shared dependency after red
proof. Do not modify shared pub cache or weaken assertions to make green.

Record baseline and post-fix commands/logs at /tmp/valhalla-nas-refresh.OOGiIt.
Use Flutter /opt/flutter/bin/flutter. Later tasks will cover durable NAS downloads,
home paging, recent directories, file retry, structured Docker health and UI.
Do not reuse 2582 historical passes as current verification. ADB inventory read-only
allowed; no failure injection or messages to user servers/Agents.
