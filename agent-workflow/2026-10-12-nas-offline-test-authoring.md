# OpenCode isolated NAS regression authoring

Started with opencode/mimo-v2.6-flash-free. After >5 minutes without progress,
continued in the same OpenCode session using user-authorized verified-free fallback
opencode/nemotron-3.5-lightning-free (input/output/cache all zero in current catalog).
No subagents. Root owns product logic;
original AgY owns ALL UI/ARBs; another OpenCode session owns dependency regression,
pub get, analysis and eventual test execution. Preserve existing changes.

Your exclusive write scope: NEW test/core/nas_offline_persistence_test.dart,
NEW test/infrastructure/nas_download_validators_test.dart, and append evidence here.
Do not change product, generated files, dependency config, other tests or UI.
Do not run Flutter commands/pub get/analyze/build/format yet; other verification
owns that shared state. Author focused tests, read dependencies as needed, then
report completion so the main verifier can run them.

Read NasDownloadService, model NasDownloadTask, NasIndexRepository and HTTP source
adapters. Cover durable task and file metadata after service reconstruction; paused
restart (not auto-network); real local directory and sqlite DB, fake adapter with
controllable version/size/stream cancellation; resume offset on unchanged resource,
changed version refused retaining partial, restart from zero, Range unsupported,
failed write, cancel/remove safety, local file checksum/missing-file rejection,
no adapter needed when resolving completed local media. No giant fixture or sleep;
use Completer for checkpoints and bounded Future timeouts; always await dispose.
Respect Flutter test binding for MissingPluginException notification channel.

HTTP validator tests use loopback HttpServer only: HEAD fresh strong ETag and
size, GET If-Match + exact Range, 412 source mutation, weak/missing validators,
HEAD405/501 safe full download with no resume. No external network/server writes.
Assert preserved existing favorites/playback/index on DB migration if economical.
Do not claim passing tests until another session actually executes them.
