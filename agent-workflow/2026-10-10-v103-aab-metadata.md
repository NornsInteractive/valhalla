# v1.0.3 AAB Metadata — Release Acceptance (read-only)

- Artifact: `/tmp/opencode/valhalla-v1.0.3-source/build/app/outputs/bundle/release/app-release.aab` (78,399,360 bytes)
- Entry: `base/manifest/AndroidManifest.xml`, 11,578 bytes, binary AAPT protobuf XML
- Method: Python stdlib `zipfile` + inline specialized protobuf decoder (no files, no dependencies). Attribute schema per `XmlAttribute`: f1=namespace_uri, f2=name, f3=value; paired individually.

## Verified schema path (actual)
- Top message fields: `1` (wire-2, 11571 B, the root element), `3` (wire-2, 2 B).
- Root element located at top field 1: name at field 3 = `manifest` (element attrs at field 4, children at field 5 — 7 attributes total).
- The initial task incorrectly assumed `XmlNode.element=2`. The actual root is
  field 1, matching the [official Android AAPT schema](https://android.googlesource.com/platform/frameworks/base/+/master/tools/aapt2/Resources.proto):
  `XmlNode.element=1`, `XmlNode.text=2`, `XmlElement.name=3`, attributes=4,
  and attribute namespace/name/value=1/2/3. This was a check's schema-assumption
  error, not a malformed AAB. The final decoder paired individual attributes.

## Paired attribute values (name = value)
| attribute | value |
| --- | --- |
| package | `com.antigravity.valhalla.valhalla` |
| versionName | `1.0.3` |
| versionCode | `4` |

(Also present: compileSdkVersion 36, platformBuildVersionCode 36, compileSdkVersionCodename 16, platformBuildVersionName 16.)

## Assertions
- root element name == `manifest` — OK
- package == `com.antigravity.valhalla.valhalla` — OK
- versionName == `1.0.3` — OK
- versionCode == `4` — OK
- First assumed-field decoder: exit 1, `ROOT_ELEMENT_COUNT=0` (not a pass).
- Actual field-layout inspection: exit 0; final paired decode/assertions: exit 0.

## Result
PASS — AAB metadata matches v1.0.3 (versionCode 4) acceptance values.

## Limits / scope
- Read-only: no build, test, lint, analysis, or app/UI changes; no repo browsing, history, git, or env inspection; no uploads.
- No signing/private material read or emitted; nothing written outside this report.
- Residual risk: protobuf decode validated structurally (wire-type-safe) but no cross-tool comparison (e.g. aapt2/bundletool) was performed.
