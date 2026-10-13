# OpenCode execution-only: verified path fix test package

No code/tests edits, no subagents, no UI input, no git/push/release/version changes.
Use the explicitly selected free main/small model. Do not print environment,
passwords, signing inputs or app data. Do not clear/uninstall the app.

First verify logs /tmp/valhalla-path-verification.vKv9vC/{focused,full,vm}.log
end All tests passed and analyze.log says No issues found. Stop if not.
Then execute these commands (capture full output + each real exit status in
your JSONL, stop on failure):

1. env -u VALHALLA_ANDROID_KEYSTORE -u VALHALLA_ANDROID_KEY_ALIAS -u VALHALLA_ANDROID_STORE_PASSWORD -u VALHALLA_ANDROID_KEY_PASSWORD -u VALHALLA_CI_UNSIGNED GRADLE_USER_HOME=/tmp/valhalla-app-center-gradle.mgpUTM /opt/flutter/bin/flutter build apk --release --split-per-abi --target-platform android-x64
2. mkdir -p build/app-center-paths-validation/compatible
3. cp build/app/outputs/flutter-apk/app-x86_64-release.apk build/app-center-paths-validation/compatible/app-x86_64-release.apk
4. /opt/android-sdk/build-tools/36.0.0/apksigner verify --print-certs build/app-center-paths-validation/compatible/app-x86_64-release.apk
5. sha256sum build/app-center-paths-validation/compatible/app-x86_64-release.apk
6. /opt/android-sdk/platform-tools/adb -s 127.0.0.1:14251 shell dumpsys package com.antigravity.valhalla.valhalla | rg 'versionCode|versionName|firstInstallTime|lastUpdateTime'
7. /opt/android-sdk/platform-tools/adb -s 127.0.0.1:14251 install -r build/app-center-paths-validation/compatible/app-x86_64-release.apk
8. Repeat step6, adb devices -l, report exact byte size/hash/certificate/timestamps.

Require original compatible certificate SHA256 before step7:
2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9.
On mismatch stop, never replace keystore or uninstall. Expected version1.0.4,
x64 code4005 unchanged. This is release-mode debug-signed TEST APK, not a signed
production Release. Do not call it a newly published official APK.

Do not launch, tap, dump unrelated app UI or operate production SSH servers.
Root handles targeted in-app verification after installation. Preserve prior
official artifacts in app-center-polish-validation; only new directory here.
