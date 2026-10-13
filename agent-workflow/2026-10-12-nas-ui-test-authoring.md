# NAS UI regression authoring only

OpenCode verified-free big-pickle. Exact write scope:
test/features/nas_media_view_test.dart and test/features/nas_navigation_test.dart,
plus this report. No product/UI/ARB/other tests, no subagents, no Flutter/pub/build
or test commands (main verifier owns execution). Standalone dart analyze owned
files allowed. Keep edits small, reuse all existing fakes, preserve assertions.

AgY changed NAS to five primary destinations Home/Photos/Videos/Music/Library.
Folders/Favorites/Playlists/Downloads are Library subsections. Adapt existing
tests tapping now-nested keys by tapping Library first. Existing home now reads
nasHomeProvider (bounded NasHomeSections), so fixture must supply real deterministic
home data through provider override, not sqlite/platform side effects.

Add focused regressions for 320dp with TextScaler.linear(2), Arabic RTL and desktop:
source, scan, library settings dialogs must remain usable/scrollable without
RenderFlex overflow. Existing test helpers already cover dialogs; extend them.
Offline download list must be reachable through Library with no active source;
loading/error/paused/completed states should not require remote adapter/network.
Do not fabricate provider APIs or skip failing behavior. If helpers cannot cover
an item cheaply, report gap rather than invent hundreds of lines of abstractions.
No real server or Agent interaction. Report authored/unverified; don't claim test
passes. Main verifier will run, send precise UI defects to original AgY.

## Handoff to execution

Root stopped the task-owned author process after authoring and three clean
standalone analyzer passes, while it was repeatedly speculating about runtime
behavior rather than finishing. Files are now free for main OpenCode verifier.
Authored: home provider fixture, Library navigation adaptation, offline tasks/
loading/error/top-bar zero-source cases, 320dp/2x/RTL/desktop form cases. NOT RUN.
Do not accept hypothetical layout reasoning as verification. Actual widget run
must confirm these cases and fix faulty fixtures without weakening assertions.
Root confirmed author's zero-source Library routing finding as a real UI defect
and queued it to AgY (nas-library-routing-review.md). Need test both submenu
access with no sources and retained subsection navigation after Downloads opens.
