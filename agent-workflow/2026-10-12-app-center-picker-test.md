# Narrow picker regression tests (OpenCode)

No product changes, no subagents, no build/ADB. Author only NEW
test/features/sftp_directory_picker_test.dart. Reuse centerServer,
CenterActiveServer from ../support/application_center_fakes.dart. Connected
ServerConnectionNotifier override returns connected state. SftpOperations fake
only implements listFiles; noSuchMethod throws for ALL other methods so any
write fails. Track requested paths and supply results/errors per path.

Widget host ProviderScope -> MaterialApp with AppLocalizations delegates and
supportedLocales, Scaffold + button opening SftpDirectoryPickerDialog.show.
Capture dialog result; use real button labels via l10n or type finders.
Never mount dialog as home itself (pop would affect root route).

Only 3 focused cases:
1. Start /home/dev/missing/app, typed SftpStatusError noSuchFile for that path
   and /home/dev/missing; /home/dev returns empty. Assert exact requests in that
   order, displayed /home/dev, enabled FilledButton, select returns /home/dev.
2. Start same path with typed permissionDenied, assert ONE request, displayed
   localized error, FilledButton.onPressed null. Cancel returns null.
3. Start /home/dev succeeds with one subdirectory gone. Tapping gone returns
   noSuchFile. Assert /home/dev then /home/dev/gone ONLY (no fallback), disabled
   FilledButton; retry cannot silently choose parent. No remote writes.

Use small apply_patch. Do not read unrelated tests or rewrite existing files.
Run only this file and retain exact exit/output in
/tmp/valhalla-app-paths.HS4wpP/picker-tests.log. If compilation fails due pending
AgY/codegen, report exact error; never modify production code or weaken asserts.
