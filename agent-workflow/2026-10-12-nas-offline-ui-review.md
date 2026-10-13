# Offline image preview corrective review

Same original AgY conversation/model/high and existing whitelist, no tests/build/
analysis/generation/format or business edits. Do not alter normal online behavior.

New localFilePath preview still retains remote pagination/slideshow/favorite/cast/
download controls from online image viewer, and can fall back to network if the
local file disappears. In this explicit local-file mode render one local image
with zoom, back and system-open only; hide/disable remote-only actions and next/
previous/slideshow that would query nasProvider pages. Never replace local failure
with a remote fetch. Show localized invalid-offline-file/error state if absent or
Image.file decode fails. Preserve all normal online gallery controls.

NasDownloadsSheet._handleInAppOpen passes onOpenExternal with an empty catch; show
localized open failure with mounted guard instead of silently doing nothing.
Remove any misleading no-op favorite callback if local mode no longer uses it;
preserve source compatibility of viewer signatures/callers as needed.

Root separately fixed NasNotifier.openInApp's eager remote adapter acquisition;
audio/video download action should continue calling that existing provider API.
No new service API is needed. Report files and unverified status.
