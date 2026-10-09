# Windows Microsoft Store package

## Windows 1.0.2 fixes (2026-10-09)

The follow-up SSH toolbar fix gives Windows tabs a native chip delete action
instead of nesting a close gesture inside the label. Closing an earlier tab
keeps the same active session; closing the active tab switches to an adjacent
session and refreshes its tmux offer. Clear now sends local screen/scrollback
erase sequences through xterm's output parser, which also notifies the canvas
to repaint immediately. It sends no command to the SSH shell. These changes
passed 38 terminal regression tests, including seven toolbar cases.

The Windows runner now enforces one instance per user/session across the
installed, portable and Store editions. Repeated launches restore the existing
window without recreating terminal sessions. The top-right toolbar provides
accent color, theme mode and language actions using the same settings dialogs
and persistence as Settings. Completed SFTP and NAS downloads have a separate
File Explorer action; deleted files fall back to their existing parent folder.

The local `packages/xterm` copy is upstream 4.0.0 with a Windows-only patch
which supplies `View.of(context).viewId` to `TextInputConfiguration`. This
addresses the Windows text-input client errors and missing terminal character
input while preserving IME composition. The package remains MIT licensed;
its original license and modification notice ship in `licenses/xterm`.

Verification covers 104 related tests, including theme/language persistence,
480-pixel layouts with large text, download actions and failures, terminal
text/IME composition, paste, Enter, Backspace, arrow keys and Ctrl+C. Actual
Windows Release checks cover concurrent startup, minimize/reactivate, normal
close/restart and abnormal exit/restart. A separate Release fixture confirms
that native Unicode window messages reach the shared canvas and a localhost
SSH server without unhandled text-input errors, and exercises the real Windows
Shell reveal calls. Physical keyboard input and a real IME candidate window
were not manually verified because the tool desktop cannot activate that
fixture. The fixture is never packaged as the application.

Run `tool/verify_windows_single_instance.ps1` after closing existing Valhalla
windows. For native-input verification, install AsyncSSH under
`D:\Data\Env\windows-smoke-deps`, run `tool/build_windows_native_smoke.ps1`,
then run `tool/verify_windows_native_input.ps1` using Windows PowerShell with
`-STA`. These checks use the existing portable build environment under
`D:\Data\Env` and restore the production bundle before packaging. The SSH
fixture binds only to localhost and uses test-only credentials.

Keep the app at `1.0.2+3` and Store package at `1.0.2.0` for this replacement
submission. EXE and portable ZIP updates belong to GitHub Release `v1.0.2`;
the unsigned MSIX is for Partner Center upload. Store search terms in all
17 listing languages now use generic feature terms rather than Docker or
Linux product names.

Product: Valhalla (Store ID `9MZ8ML12WH8R`).

| Property | Value |
| --- | --- |
| Package name | `Norns.Valhalla-` |
| Reserved display name | `Valhalla-服务器运维管理工具` |
| Publisher | `CN=257586C2-E7B0-47F3-BAED-A744A66748A1` |
| Publisher display name | `Norns` |
| Package family name | `Norns.Valhalla-_sxt4q0tm9x2xr` |
| Architecture | x64 |
| Minimum Windows version | Windows 10 2004, build 19041 |
| Initial Store package version | `1.0.2.0` |

The Flutter application version is `1.0.2+3`. The Store package uses
`1.0.2.0`, with the fourth component reserved for the Store.

Build the Windows release and prepare its release runtime DLLs first. Then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tool/package_windows_msix.ps1 -DisplayName "Valhalla-服务器运维管理工具"
```

The script defaults to the SDK installed under `D:\Data\Env`; use `-SdkBin`
to supply a different Windows SDK bin directory. It validates the manifest with
MakeAppx, generates tile assets from the existing app icon, checks the package
family name using Windows, and writes an unsigned Store submission package and
SHA-256 digest under `build/windows-artifacts`.

`-DisplayName` is required. Copy the exact reserved name from Partner Center's
Product management → Manage app names. Package identity `Norns.Valhalla-` and
the app's display name are separate values. Both the package DisplayName and
application VisualElements DisplayName use this parameter. MakeAppx validates
the manifest locally but cannot verify the account's reserved Store names.

Select only the Desktop device family (PC) for this Windows.Desktop package.
Do not select Xbox, Mobile, Holographic or other device families that this
package does not target. A package rejected during upload validation may also
cause the submission page to report that no valid package has been uploaded.

Upload `valhalla-1.0.2.0-windows-x64-store.msix` on the Partner Center Packages
page. This package targets Store submission; it is unsigned and cannot be
installed by ordinary double-click sideloading. Microsoft signs it after
certification. Future Store updates must use a suitable higher package version.

Additional license terms must contain PolyForm Noncommercial 1.0.0 rather than
being left blank. The current listing CSV contains the license and required
notice in every language. See [licensing notes](licensing.md).

Use this public URL for the Store listing's privacy policy:

https://gist.github.com/Naruto9Kurama/743fc88a1f2739f0a43ee733ca74afc6

In the app, Settings → About & privacy → Privacy policy opens bundled Chinese
and English policy text without needing a network connection. The contact is
`norns.soft@gmail.com`.

The package declares `runFullTrust` because Valhalla is an existing Flutter Win32
desktop client. If Partner Center asks for justification, explain that its native
Windows runner and plugins provide SSH terminal sessions, remote file transfers,
local configuration storage, and optional media playback. It runs as the current
user and does not request administrator elevation.

MakeAppx validation and Flutter tests are local checks; they do not replace the
Windows App Certification Kit or Microsoft Store certification. Run the Windows
App Certification Kit and complete Store listing, age rating, screenshots,
privacy URL and certification notes in Partner Center before publishing.

References:

- [Microsoft Store MSIX requirements](https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/msix/app-package-requirements)
- [Manual desktop application packaging](https://learn.microsoft.com/en-us/windows/msix/desktop/desktop-to-uwp-manual-conversion)
