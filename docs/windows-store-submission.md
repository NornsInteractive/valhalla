# Windows Microsoft Store package

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
