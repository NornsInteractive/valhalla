# AgY final localized-error follow-up

Same original Valhalla conversation/model/high, existing UI whitelist only. Root
will not edit UI. Do not run tests, generation, analysis, formatting or builds.

nasSanitizedError maps several new download codes but falls back to raw backend
strings for common NAS_DOWNLOAD_FAILED, NAS_INCOMPLETE_DOWNLOAD,
NAS_DOWNLOAD_QUEUE_FULL, NAS_DOWNLOAD_NOT_COMPLETE, NAS_DOWNLOAD_SERVICE_CLOSED,
NAS_DOWNLOAD_TARGET_EXISTS. Map all download-service error codes to existing
appropriate localized messages, or add minimal ARB keys if no existing equivalent.
Do not expose raw codes/StateError text; keep meaningful source-change / offline
integrity / storage errors distinct. Do not mask unrelated genuine errors.

Download sheet restore with tasks snapshot + error uses retry invalidating only
nasDownloadsProvider; service.ready stays failed. Apply same safe service+stream
invalidation used by empty-error branch (the service protects failed load data).
Avoid any layout changes beyond this corrective work. Report files, unverified.
