# App icon and v1.0.2 release contract

User requests the exact image https://img.norns.cc.cd/images/2026/10/05/vahalla_icon.png
as the app icon, a new package, and GitHub Release publication. Preserve all
uncommitted experimental, language and remote-file changes; do not stage them.
User explicitly selected Android-only rebuilt release; other platforms update
icon source only. Skip cloud build triggers for this release.
Release source is current committed main (v1.0.1 baseline) plus ONLY new icons,
version 1.0.2+3, focused verification and this release documentation. Root will
prepare an isolated source tree for package verification/building.

## AgY ownership

ONLY original Valhalla conversation ec81a4be-7543-45ee-8658-f68966f57d3b,
model gemini-3.8-flash-high, effort high. Allowed files:
- assets/icons/valhalla_icon.png (original downloaded image).
- android/app/src/main/res/mipmap-*/ic_launcher.png, plus launcher-only adaptive
  icon resources if necessary; do not change application ID, SDK or permissions.
- ios/Runner/Assets.xcassets/AppIcon.appiconset/**.
- macos/Runner/Assets.xcassets/AppIcon.appiconset/**.
- windows/runner/resources/app_icon.ico.
- agent-workflow/2026-10-06-app-icon-ui-status.md.

Inspect the downloaded PNG, preserve its design, derive native required sizes
without distortion. Prefer already installed image tools; no permanent new
dependency, UI redesign, source-generation library or unrelated source edits.
Geometry decision is final: original asset stays byte-identical (640x650);
center-contain the entire original proportionally on a 650x650 transparent canvas,
then resize to native sizes with LANCZOS. Do not crop or stretch. For iOS only,
flatten against white so exported icons have no alpha. No further redesign or
geometry investigation is needed. Generate icons and report now.
Do not modify pubspec or lockfile. Linux icon integration must be reported if
not already present; do not expand native code without a separate handoff.
Do not run tests, analyze, Flutter generation/build, ADB, git writes or publish.
Report identity/model, exact changed files, dimensions and image handling.

## OpenCode ownership and acceptance

Use explicitly confirmed free main/small model; existing authorized fallback
opencode/space-bunny-free. Tests, verification and packaging are exclusively
OpenCode-owned. Root will hand off an isolated committed-source tree, never
build unrelated dirty features into an icon-only release. Verify original image
hash/format; icon dimensions, ICO sizes and platform references; versionCode 3,
versionName 1.0.2; preserve package ID and fixed signing certificate SHA256
73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d.
Focused resource checks plus analyze and nearest applicable tests before build.
Build Android release APKs with existing formal keystore, then verify signatures,
actual packaged icons, source commit, SHA256 and fresh timestamps. Never print
passwords or key data. No ADB, key regeneration, uninstall, cloud budget or
visibility changes. Windows/Apple availability must be explicit; no old package
may be presented as a rebuilt new-icon package.

## Publishing

Root owns explicit-whitelist commit, new version/tag, GitHub draft and upload.
Do not overwrite v1.0.0/v1.0.1. Do not trigger duplicate full-platform cloud
builds; billing restrictions do not authorize raising budgets or paid runners.
Only actually verified rebuilt artifacts can be uploaded. Record real outcomes,
unavailable platforms, release source and package signature boundary.
