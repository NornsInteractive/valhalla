# Library routing defects from source review

Same AgY UI ownership/session/model/high. Two concrete issues in NasMediaView:

1. _buildSurfaceContent returns NasDownloadsSheet early when Library/Downloads is
   selected, bypassing _buildLibrarySurface. This removes Library's own subsection
   navigation, so users cannot simply return to Folders/Favorites/Playlists.
2. Empty sources/config/loading gates run before _buildLibrarySurface. With zero
   sources, users can reach offline files only via the top-bar button, not through
   the promised Library/Downloads route. Completed local files must stay reachable
   without a configured source. The Library navigation shell must remain present;
   only online subsections show relevant source/config guidance.

Fix routing narrowly, retaining playlist-detail/back behavior and all online
guidance. No duplicate subsections or new service APIs. No tests/generation/build/
analysis/format. Main verifier will assert Library/Downloads with zero sources and
switching back to other subsections, beyond the existing top-bar reachability test.
