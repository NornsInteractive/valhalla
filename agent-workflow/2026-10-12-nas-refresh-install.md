# Final Android packaging and preserved-data installation

Only execute after current full analysis/tests and responsive UI regressions pass.
OpenCode owns every build/signature/ADB verification command. Original AgY owns
any UI repair discovered by these gates. No git push, Release, Actions, version
bump, remote user-server mutations, uninstall, clear-data or signature replacement.

- Version remains 1.0.4+5. Build locally for arm64 and x86_64; retain official
  release-signed artifacts separately from the compatible emulator test artifact.
- Inspect installed package/certificate first. Expected current emulator is
  127.0.0.1:14251, sdk_gphone64_x86_64, but verify inventory before commands.
- Original debug certificate SHA256:
  2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9.
- Official certificate SHA256:
  73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d.
- Use existing project signing setup/private files, never print passwords or
  keystore contents. Do not modify release signing to accommodate the emulator.
- Previous isolated GRADLE_USER_HOME is
  /tmp/valhalla-app-center-gradle.mgpUTM; inspect/reuse if suitable. Global Gradle
  init script conflicts with Flutter included-build repository policy; do not
  edit global configuration. Normal Flutter pub generation is required; old
  --no-pub build carried a stale integration_test plugin registration.
- Install only compatible package with adb -s <verified device> install -r;
  preserve all application data. If certificate differs from both verified
  artifacts, stop and report, never uninstall to force success.
- Start app, inspect fresh logcat/diagnostic events without clearing historical
  logs. Exercise safe navigation, offline list, dialogs, return from background.
  Do not deploy an app, delete data, send an Agent message or inject failures on
  user servers. Use mocks or existing isolated pinned test VM for such checks.

Capture actual commands, exit statuses, artifact path/time/size/SHA256/certificate,
installed version/time, and what was actually exercised. Historical app-center
artifacts under build/app-center-validation are NOT this build. Report device
limits and skipped real media/network validation explicitly.
