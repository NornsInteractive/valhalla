# Valhalla's narrow transport patch

Vendored dartssh2 4.1.0 from the official pub.dev archive. Archive SHA-256:
39359aceafcf5940b868249e3c9c6d86e4e0f989eec7417d033c943157c84c51.
Upstream: https://github.com/vicajilau/dartssh2. Original LICENSE retained.

Changes: await SFTP/subsystem acceptance, destroy refused/failed channels, and
return the reserved request Future on send failure instead of leaving a second
unobserved failed Future. No global SSH error suppression or cache edits.
Regression: test/infrastructure/ssh_sftp_subsystem_transport_test.dart.
Remove the local dependency only after the equivalent upstream fix passes it.

Analysis-only compatibility cleanup: retain the deprecated public onPacket getter
and constructor argument, store its handler privately so internal dispatch does
not reference a deprecated API. Callback behavior and onMessage precedence unchanged.
Original upstream analysis_options.yaml retained; no analyzer exclusions/suppression.

Transfer responsiveness (2026-10-14): packet receive and channel send loops yield
to the event queue after roughly 4ms, after sequence/window updates, while keeping
their existing serialization guards. Natural socket EOF drains received complete
packets before closing; explicit close/error still stops processing immediately.
ChunkBuffer compaction retains old views and grows only when space or compaction
headroom requires it, rather than doubling on every trailing-space exhaustion.
New focused regression and integration validation are recorded in
agent-workflow/2026-10-14-transfer-jank-and-grid.md; status there is authoritative.
