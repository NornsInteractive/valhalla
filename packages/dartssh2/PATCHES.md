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
