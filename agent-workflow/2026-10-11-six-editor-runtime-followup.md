# AgY editor runtime follow-up (actual joint +35 -3)

Production lib analyze now zero; 17-locale parity9/9; NAS lifecycle4/4.
Unfiltered `/tmp/opencode/nas_sftp_joint_test_rerun.log` contains three editor
failures; no assertion was weakened. Codex owns no UI changes, including mapper.

1. Generic save failure now falls through `_mapSftpErrorMessage` to generic
   TRANSFER message, losing existing `sftpSaveFailed` semantics. The old save
   regression has a real write-failure fake and its expected save message is
   legitimate. Preserve typed conflict/expired/atomic/draft mappings, but give
   `_handleSave` a save-specific fallback (`context.l10n.sftpSaveFailed`) for
   unknown errors, consistently inline and SnackBar. Reuse existing keys; no
   new translations or provider/test changes. A private optional mapper fallback
   is acceptable if needed; leave transfer callers' defaults unchanged.
2. Error SnackBars appear in both root page and dialog Scaffolds because both
   share root ScaffoldMessenger. Tests see two SnackBar/action widgets on flush
   and discard failure. Keep one visible feedback surface owned by the editor
   dialog, e.g. a local ScaffoldMessenger with captured live state for editor
   failure/copy. Successful save notification should remain visible on outer
   page after dialog closes. Preserve typed errors, draft text, copy action and
   route/confirmation/token guards; no test finder weakening in this job.
   Inspect exact assertions if necessary; do not assume two widgets == two
   separately generated exceptions. Respect Flutter shared-messenger behavior.

Only sftp_file_view.dart + UI report. No test/core/provider/ARB/manual format,
gen/analyze/build/ADB/git/subagents. Original Valhalla/model/effort. OpenCode
reruns the unchanged expected save message and copy behavior afterward.

07:30 UTC actual rerun: generic save wording now passes and only ONE SnackBar
exists. Two remaining failures are at test1627/1666: unscoped text tap now sees
the intentional persistent banner Copy Draft button AND the transient SnackBar
Copy Draft action. This is not two SnackBars or two exceptions. OpenCode owns
fixture correction: scope each tap to the SnackBarAction already explicitly
asserted, retain all draft/no-pop/error/clipboard assertions. No production UI
change is justified solely to make an ambiguous finder unique. Keep prior
+35-3 and latest +45-2 failure evidence. Afterwards rerun the whole joint set.
