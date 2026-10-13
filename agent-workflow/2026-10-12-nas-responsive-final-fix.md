# Actual runtime failures: responsive scan dialog

Root is authorized this round for tests/build/ADB; all UI remains original AgY.
No other UI writer. Read `/tmp/valhalla-nas-refresh.OOGiIt/root-targeted.log`.
38 pass / 2 fail; new provider/offline/library checks passed. The old loading
failure was a reused test Notifier, fixed in fixtures, NOT a UI routing defect.

Actual failures: test/features/nas_media_view_test.dart group
`NAS dialogs remain usable without RenderFlex overflow`, 320dp/2x text and Arabic
RTL. nas_scan_config_dialog.dart rows at 304,363,426 overflow by up to399px.
Fix these responsive layouts without reducing font scale, removing controls,
dropping labels or clipping inaccessible content. Reuse existing styles/components;
wrap/stack labels/actions when needed. Inspect remaining library/source dialog
rows too if same layout defect. UI whitelist only three nas *_dialog files.
Do not touch tests, core, generate, run Flutter, build, format, or publish. Root
will rerun exact failing tests and complete gates. Return authored files/status.
