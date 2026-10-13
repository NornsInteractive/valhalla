# OpenCode cleanup runtime review

Read-only review found a false-positive in the original selected-symlink case:
the test's own O_NOFOLLOW open rejected the link before production was called.
Capture identity from the real leaf outside the caught operation, then call only
`remove_directory` with the selected link path inside the exception handler.
Production raises OSError ENOTDIR/ELOOP here; the higher cleanup layer maps it to
failed/APP_CENTER_CLEANUP_DELETE_FAILED. Preserve and assert link and leaf content.

Additional minimal race proof before claiming live-attachment protection: open
root and child FDs in one Python process; rename child to a sibling in the same
unique fixture; create a new child at the original location. Call the actual
`empty_directory` on the original child FD with its original attachment chain.
Expect Blocked(APP_CENTER_CLEANUP_PATH_CHANGED) before deletion; both original
and replacement sentinels must remain. Read the actual signature before writing.

All paths must belong to Directory.systemTemp.createTemp fixtures; no real
Docker, SSH, account files or broad cleanup. Close FDs and tear down only these
fixtures. For Dart Process.run, pass serialized arguments in argv (read Python
sys.argv[1]) rather than inventing a stdin parameter or embedding quoted JSON.

OpenCode owns test edits, formatting and execution. None of these small tests
alone verifies Docker sharing, mount protection, authorization or full uninstall.
