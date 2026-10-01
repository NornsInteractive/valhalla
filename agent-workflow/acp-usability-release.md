# ACP 可用性第二轮 — 验证收尾与 release 交付报告

- 执行者：OpenCode（`opencode/space-bunny-free`）
- 日期：2026-09-30（UTC）
- 仓库：`/workspace/projects/valhalla`，HEAD `a97fa54`
- 范围：验证收尾 + 一次归因更正。**未改动 `lib/**` 生产代码、未改 ARB、未改 UI。**
- 原始日志目录：`/tmp/valhalla-acp-usability-gates-20260930/`

> **本报告已于同日二次修订。** 首版把窄屏/大字体溢出结论误判为「测试字体假阳性」，
> 并把 0.4px 归因为「Flutter 框架自身取整」。该归因错误已更正：这两处是**真实的生产
> 布局缺陷**，已由 AgY 在本轮内修复，修复后的代码已随本文所述 release APK 出包。
> 详见「STEP 2 · 溢出问题的发现、归属与修复」。首版错误结论不再保留。

## 结论摘要

全部门禁通过，已产出本轮 release APK、覆盖安装到指定模拟器并冷启动成功。
**但真实 ACP 交互与 UI 人工验收仍未验证**（见文末「未验证项」）。

| 门禁 | 命令 | 退出码 | 结果 |
| --- | --- | --- | --- |
| l10n 生成 | `flutter gen-l10n` | 0 | 三个生成文件与上轮一致（无新增差异） |
| 格式化 | `dart format <49 个本轮变更文件>` | 0 | 6 changed |
| 静态分析（首次） | `flutter analyze` | **1** | 11 issues，**全在 AgY 的 UI 文件**（见下） |
| 静态分析（最终） | `flutter analyze` | **0** | `No issues found!` |
| 全量测试（出包前） | `flutter test --reporter expanded` | 0 | **1302 passed / 17 skipped / 0 failed** |
| 空白检查 | `git diff --check` | 0 | 无输出 |
| release 构建 | `flutter build apk --release` | 0 | 122.7 MB |
| 覆盖安装 | `adb -s 127.0.0.1:14251 install -r <apk>` | 0 | `Success` |
| 冷启动 | `monkey` LAUNCHER | 0 | 观测窗口内进程存活、MainActivity 前台、未见崩溃日志 |
| **回归补测（scale 2.0）** | `flutter test test/features/acp_run_settings_metadata_test.dart` | **0** | **18 passed / 0 failed**（新增 3 例） |
| **全量测试（回归后）** | `flutter test --reporter expanded` | **0** | **1305 passed / 17 skipped / 0 failed** |
| **静态分析（回归后）** | `flutter analyze` | **0** | `No issues found!` |
| **空白检查（回归后）** | `git diff --check` | **0** | 无输出 |
| **APK 指纹复核（回归后）** | `sha256sum` / `stat` | 0 | SHA256 与 mtime **未变**，未重建、未重装 |

## STEP 1 · l10n / 格式化 / 分析

```
flutter gen-l10n                                    → EXIT=0
  （l10n.yaml 生效；lib/l10n/app_localizations*.dart 与上轮生成结果一致）
dart format <49 个本轮变更 Dart 文件>                → EXIT=0  Formatted 49 files (6 changed)
flutter analyze（第 1 次）                           → EXIT=1  11 issues
```

**首次 analyze 的 11 个问题全部位于 AgY 负责的 UI 文件**（`lib/features/chat/**`），
按约束未作任何修改，交由 AgY：

| 文件:行 | 级别 | 问题 |
| --- | --- | --- |
| `ai_chat_view.dart:27:28` | warning | `AcpSlashCommand` shown but not used |
| `ai_chat_view.dart:29:8` | warning | unused import `sftp_client_service.dart` |
| `ai_chat_view.dart:1567,3283,3300,3301` | info | `unnecessary_underscores` |
| `widgets/image_zoom_dialog.dart:59,66` | info | `unnecessary_underscores` |
| `widgets/remote_workspace_browser_dialog.dart:722` | info | `unnecessary_underscores` |

**复核结果**：这些文件在我执行期间被 AgY 修改（mtime 19:45，晚于我 19:34 的首次 analyze）。
最终 `flutter analyze` 复跑为 **`No issues found!（EXIT=0）`**，上述问题已被 AgY 自行修掉，
无需我再介入。日志：`03-analyze.log`（首轮 1）、`20-analyze-full.log`（终轮 0）。

## STEP 2 · 溢出问题的发现、归属与修复（**本报告的更正重点**）

### 2.1 事实链

1. 我在写窄屏/大字体布局回归时，用**临时诊断探针**扫了
   320/360/411dp × scale 1.0/1.3/1.8/2.0 × 明暗两套主题。
2. 探针在**生产主题 + 真实 Inter 字体**下复现出稳定失败（`14-diag-realtheme.log`）：
   3 个宽度 × 明暗 2 套 = **6 组，scale 2.0 全部报同一个错误**：

   ```
   REAL dark  320.0x640.0 scale=2.0 -> errors=1 [A RenderFlex overflowed by 0.400 pixels on the bottom.]
   REAL dark  360.0x640.0 scale=2.0 -> errors=1 [A RenderFlex overflowed by 0.400 pixels on the bottom.]
   REAL dark  411.0x800.0 scale=2.0 -> errors=1 [A RenderFlex overflowed by 0.400 pixels on the bottom.]
   REAL light 320.0x640.0 scale=2.0 -> errors=1 [A RenderFlex overflowed by 0.400 pixels on the bottom.]
   REAL light 360.0x640.0 scale=2.0 -> errors=1 [A RenderFlex overflowed by 0.400 pixels on the bottom.]
   REAL light 411.0x800.0 scale=2.0 -> errors=1 [A RenderFlex overflowed by 0.400 pixels on the bottom.]
   ```

   溢出节点（`15-diag-subpixel.log`）是**应用自己构造的内容**：

   ```
   CREATOR: Column ← Align ← ConstrainedBox ← Semantics ← DropdownMenuItem<String> ← …
   size: Size(66.2, 41.6)   constraints: BoxConstraints(0.0<=w<=232.0, 0.0<=h<=41.6)
   ```

   即 `DropdownMenuItem` 里那个 `Column`（mode 标签 + mode 描述两行）放不进菜单项高度框。
3. 另有一处在更早的**脚手架字体**探针下更显眼（`11-diag-matrix.log`），溢出节点是设置弹窗
   **底部动作区**：`Padding ← Column ← ConstrainedBox`，320dp 下 `over=43`、360dp 下 `over=3.3`。
4. 主 Agent 随后让 AgY 依次修掉三处。修复均已落在 `git diff` 中，可复核。

### 2.2 三处修复（git diff 复核）

| 缺陷 | 位置 | 修法 | diff 依据 |
| --- | --- | --- | --- |
| 账号/额度标题与查询按钮行不换行 | `lib/features/chat/ai_chat_view.dart:2240`、`:2293` | 标题 `Row` 内 `Expanded` + `ellipsis`；额度小节标题 + 查询按钮改用 `Wrap`（`WrapAlignment.spaceBetween`） | `_buildInfoRow` 区块与 `chatQuotaSectionTitle` 区块 |
| 设置弹窗底部 Cancel/Save 硬编码 `Row` 溢出 | `chat_run_settings_dialog.dart:899` | `Row` → `SizedBox(width: double.infinity, child: OverflowBar(alignment: end, overflowAlignment: end))` | 动作区 diff 明确删除原 `Row`、新增 `OverflowBar` |
| mode 下拉折叠态 0.4px 纵向溢出 | `chat_run_settings_dialog.dart:693` | 新增 `selectedItemBuilder: (_) => caps.modes.map((m) => Text(m.label, overflow: ellipsis))`，折叠态只渲染单行标签；展开列表仍保留描述 | `selectedItemBuilder` 为纯新增块，紧邻既有 `items:` |

`docs/handoffs/2026-09-30-acp-usability.md:80-85` 亦逐条记录了这三处收尾修复。

### 2.3 首版报告的错误与更正

| 项 | 首版（错误） | 更正后 |
| --- | --- | --- |
| 43px 溢出 | 「测试字体假阳性，撤回」 | 脚手架字体下的 **43px 这个具体像素数不具设备参考性**（`11` 号日志是裸 `MaterialApp` 探针）；但**缺陷本身是真的**，底部动作区当时是硬编码不换行的 `Row`，已由 `OverflowBar` 修复 |
| 0.4px 溢出 | 「Flutter 框架 `DropdownMenuItem` 自身高度取整，非本应用布局缺陷」 | **归因错误。** 溢出的是应用自己放进 `DropdownMenuItem` 的两行 `Column`（标签 + 描述）；缺 `selectedItemBuilder` 时 Flutter 用 `items[i].child` 渲染折叠态，于是把两行内容塞进单行高度框。属应用侧布局缺陷，已由 `selectedItemBuilder` 修复 |
| 覆盖范围 | 矩阵只到 scale 1.8，把 2.0 排除在外 | scale 2.0 **必须**在矩阵内，否则这两处修复没有回归保护。本次已补入 |
| 结论 | 「本轮未发现生产 UI 布局缺陷」 | 本轮**发现并修复了 2 处生产布局缺陷**（+1 处账号/额度换行），修复已随 APK 出包 |

**保留的证据与正确的方法论**：

- 修复前失败日志原样保留：`10-diag.log`、`11-diag-matrix.log`、`14-diag-realtheme.log`、
  `15-diag-subpixel.log`（临时探针文件 `test/features/zz_diag*_test.dart` 已删除，仓库内无残留，
  复核见 `39-final-verify.log`）。
- **必须使用生产主题 + 真实字体的做法保留并继续执行**（`loadRealTextFonts()` /
  `pumpAcpHarness` / `acp_run_settings_metadata_test.dart` 均已用生产
  `AppTheme.buildTheme(...)` + 载入真实 Inter 资产）。
  但理由要写对：这样做是为了让**测得的文字度量与真机一致**，从而断言结论可信；
  **不是**为了把真实缺陷筛成「假阳性」。默认 `MaterialApp` 会退回 flutter_test 的等宽方块测试
  字体，其溢出数字不能代表设备表现，也不能用来否定缺陷——它只能说明「该数字不可引用」。

### 2.4 新增/更新控件回归（36 个用例，3 个新文件 + 1 个共享脚手架）

| 文件 | 用例 | 覆盖 |
| --- | --- | --- |
| `test/features/acp_usability_widget_controls_test.dart` | 9 | 输入框单行/`minLines`/`hintMaxLines`；命令/技能切换、搜索、前缀插入且不发送；无 `localPath` 草稿图片按 bytes 渲染并可点开放大；账号页未声明 status 时不显示可执行按钮 |
| `test/features/acp_remote_workspace_browser_test.dart` | 9 | 根目录禁上级 / POSIX 上一级；自动 resolve；目录模式隐藏 `.`/`..`；切目录清筛选；三视图切换；预览走 provider；失败目录不允许确认；关闭后迟到结果安全；中文文案 |
| `test/features/acp_run_settings_metadata_test.dart` | **18** | 元信息行显隐；刷新成功更新版本/时间/过期标记；刷新失败保留原元信息并可重试恢复；刷新返回 null 不覆盖能力；长版本号窄屏大字体可读；**12 组** 320/360/411dp × scale 1.0/1.3/1.8/**2.0** 无布局溢出（本次 +3） |
| `test/support/acp_chat_widget_harness.dart` | — | 共享脚手架：内存 `FakeWorkspace` 目录表 + `FakeAcpChatNotifier`，**不建立任何 SSH/Agent 连接** |

**未重复既有覆盖**：「会话更多菜单保留删除确认」已由
`test/features/ai_chat_session_isolation_test.dart:242-273` 完整覆盖
（打开 `session_more_menu_*` → `delete_session_*` → 确认弹窗 → 取消不删 / 确认删除），
故未另写重复用例。

## STEP 3 · 测试与分析门禁

### 3.1 出包前（对应已安装 APK 的源码状态）

```
flutter test test/features/acp_usability_widget_controls_test.dart \
               test/features/acp_remote_workspace_browser_test.dart \
               test/features/acp_run_settings_metadata_test.dart
  → 00:03 +33: All tests passed!   EXIT=0

flutter test                        → 01:17 +1302 ~17: All tests passed!   EXIT=0
flutter test --reporter expanded    → 01:08 +1302 ~17: All tests passed!   EXIT=0
flutter analyze                     → No issues found!   EXIT=0
git diff --check                    → (无输出)   EXIT=0
```

### 3.2 归因更正后的回归补测（本次，仅测试与报告）

```
dart format test/features/acp_run_settings_metadata_test.dart \
               test/support/acp_chat_widget_harness.dart
  → Formatted 2 files (0 changed)   EXIT=0

flutter test test/features/acp_run_settings_metadata_test.dart --reporter expanded
  → 00:03 +18: All tests passed!   EXIT=0
    含：320dp 字体 2.0 无布局溢出 / 360dp 字体 2.0 无布局溢出 / 411dp 字体 2.0 无布局溢出

flutter test --reporter expanded
  → 01:18 +1305 ~17: All tests passed!   EXIT=0

flutter analyze                     → No issues found!   EXIT=0
git diff --check                    → (无输出)   EXIT=0
```

- 1302 → **1305**，增量 **+3** 与新增的 3 个 scale 2.0 矩阵用例完全一致；
  相对上轮 1269 的本轮总增量为 **+36**（9 + 9 + 18）。
- scale 2.0 三例在**生产主题 + 真实 Inter 字体**下通过，直接证明
  `selectedItemBuilder` + `OverflowBar` 两处修复成立；断言为
  `expect(tester.takeException(), isNull)`，**没有** ignore 错误、**没有** skip。
- 计数以本次实际输出为准（上表 3.2 节），不使用历史数字。

### 3.3 17 条跳过的准确拆分（更正）

从 expanded 日志的 `Skip:` 行逐条读出（原报告的「7+8+1」漏了一处，实为 16/17）：

| 文件 | 条数 | 跳过原因（`Skip:` 原文） |
| --- | --- | --- |
| `test/infrastructure/app_operations_vm_test.dart` | **7** | `Set VALHALLA_OPERATIONS_VM_CREDENTIALS for the disposable VM` |
| `test/infrastructure/nas_install_vm_test.dart` | **8** | 1 条 `Requires the explicit existing device WebDAV fixture port.`（**设备 WebDAV fixture 端口**用例，`nas_install_vm_test.dart:161`）+ 7 条 `Requires explicit disposable VM credentials; never runs on user servers.`（组级 skip，`:578`） |
| `test/infrastructure/ssh_sftp_vm_test.dart` | **1** | `Requires the disposable VM fixture`（`:260`） |
| `test/infrastructure/server_power_vm_test.dart` | **1** | `Requires separate VALHALLA_VM_POWER_TEST=1 and isolated VM credentials`（`:163`，**需要额外 opt-in 开关**，首版漏记的就是这条） |
| **合计** | **17** | 全部因缺少一次性 VM 凭据 / WebDAV fixture 端口 / 电源测试 opt-in 而条件跳过 |

- 该拆分与本次 `flutter test --reporter expanded` 的 `~17` 一致；
  `test/core/services/nas_linux_media_controls_test.dart` 有 `skip: !Platform.isLinux`，
  本次在 Linux 上执行，**未**跳过。
- 与上轮完全一致，**未扩大 skip、未删除任何用例**。
- 上述 VM 测试按交接要求**未重跑**（无凭据），拆分依据是原始 expanded 日志 + 源码 skip 位置。

## STEP 4 · release APK 证据

```
flutter build apk --release
  BUILD_START_UTC=2026-09-30T11:57:52Z
  Running Gradle task 'assembleRelease'... 75.6s
  ✓ Built build/app/outputs/flutter-apk/app-release.apk (122.7MB)
  EXIT=0
  BUILD_END_UTC=2026-09-30T11:59:10Z
```

| 项 | 值 |
| --- | --- |
| APK 绝对路径 | `/workspace/projects/valhalla/build/app/outputs/flutter-apk/app-release.apk` |
| UTC mtime | `2026-09-30T11:59:08Z` |
| 字节数 | `122747763`（122.7 MB） |
| SHA-256 | `26e21334399485fe948caba51d1ec57a8677a84f8129d2287fbc43fd4110219a` |
| 包名 | `com.antigravity.valhalla.valhalla` |
| versionName / versionCode | `1.0.0` / `1`（pubspec `1.0.0+1`） |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 |

**本次（归因更正后）复核指纹 —— 未变**：

```
sha256sum build/app/outputs/flutter-apk/app-release.apk
  → 26e21334399485fe948caba51d1ec57a8677a84f8129d2287fbc43fd4110219a
TZ=UTC stat -c '%y %s'  → 2026-09-30 11:59:08.523224987 +0000   122747763
```

与上表逐字节一致。**本轮只改测试与报告，未重建、未重装、未改动设备**，
因此上表构建/安装/冷启动证据继续有效。

**签名（据实说明）**
`android/app/build.gradle:37` 为 `signingConfig = signingConfigs.getByName("debug")`，
因此本次 `--release` 产物由 **Android debug 密钥**签名：

```
apksigner verify --print-certs → Verifies
  v1: false   v2: true   v3: false   v3.1: false   v4: false
  Signer #1 certificate DN: C=US, O=Android, CN=Android Debug
  certificate SHA-256: 2faa583fb6462eecf507c8f6d0e14d46ee8b512fab7940b30c7a937b5c7f37e9
```

这是**既有的工程配置**，非本轮引入，也非本轮改动范围。据实表述：
**该 APK 使用现有 debug 签名，不适合作为生产/商店发布签名。**
它可以正常侧载、可以覆盖安装（本轮即通过侧载 + `install -r` 装机），
但若要上架应用商店或走正式发布流程，需要先配置独立的 release 签名。

## STEP 5 · ADB 覆盖安装与冷启动

```
adb devices -l                          → EXIT=0
  127.0.0.1:14251  device  product:sdk_gphone64_x86_64  model:sdk_gphone64_x86_64  device:emu64xa
```

仅此一个目标且 online，与上轮一致，无多设备歧义。

**签名可覆盖性核验**（拉取已安装 base.apk 比对）：

| | 证书 SHA-256 |
| --- | --- |
| 已安装应用 | `2faa583f…c7f37e9` |
| 本轮新 APK | `2faa583f…c7f37e9` |

完全一致 → `install -r` 可覆盖。

```
adb -s 127.0.0.1:14251 install -r <apk>
  INSTALL_START_UTC=2026-09-30T11:59:54Z
  Performing Streamed Install
  Success
  EXIT=0
  INSTALL_END_UTC=2026-09-30T11:59:57Z
```

**未卸载、未清数据**，由 `firstInstallTime` 前后一致佐证：

| | 安装前 | 安装后 |
| --- | --- | --- |
| firstInstallTime | 2026-09-23 03:26:04 | **2026-09-23 03:26:04（未变）** |
| lastUpdateTime | 2026-09-30 18:01:26 | 2026-09-30 19:59:28 |
| versionName | 1.0.0 | 1.0.0 |

**冷启动**（保留数据，仅启动应用，未发送任何 ACP 消息）：

```
adb shell am force-stop com.antigravity.valhalla.valhalla   → EXIT=0
adb logcat -c                                              → EXIT=0
COLDSTART_UTC=2026-09-30T12:00:08Z
adb shell monkey -p com.antigravity.valhalla.valhalla -c android.intent.category.LAUNCHER 1
  Events injected: 1                                       → EXIT=0
```

| 观测项 | 结果 |
| --- | --- |
| 进程 | `pidof` → `23648`（存活） |
| 前台 Activity | `topResumedActivity=…com.antigravity.valhalla.valhalla/.MainActivity` |
| 本次启动崩溃日志 | 该次 logcat 抓取中**未出现** `FATAL EXCEPTION` / `ANR in` / `beginning of crash` |
| 引擎日志 | `Using the Impeller rendering backend (OpenGLES)`、`flutterEngine warmed up` |

**结论的适用边界（重要）**：以上仅覆盖 **12:00:08Z 冷启动起、至 12:01:38Z 最终核验
这约 90 秒观测窗口**内抓取的 logcat 快照。该窗口内未见崩溃记录，
**不能据此声称应用绝对无崩溃** —— 观测窗口之外的路径、长时间运行、真实 ACP 会话
均未被本次证据覆盖。

logcat 中出现的 `AndroidRuntime` 行均属 **monkey 启动器自身**（PID 23609），
与应用进程 23648 无关；应用侧仅有模拟器平台噪声（CPU variant、attestation 属性拒绝、
`max_map_count` 读取拒绝等），无应用异常。

## 约束遵守

- **未修改 `lib/**` 生产代码、未改 ARB、未改任何 UI。** 本次改动仅限
  `test/features/acp_run_settings_metadata_test.dart`、`test/support/acp_chat_widget_harness.dart`
  与本报告。
- 手工文件编辑使用编辑工具（apply_patch 类），未用 Python 写文件。
- 保留所有既有改动；未 `git add` / `commit` / `push`。
- 未读取凭据、未连接真实 SSH/Agent、未发送真实消息、未改动真实会话。
- 格式化仅限本轮变更的 Dart 文件，未全仓格式化。
- 断言未弱化：新增 scale 2.0 用例沿用 `expect(tester.takeException(), isNull)`，
  **未** ignore FlutterError、**未** 扩大 skip、**未** 放宽任何阈值。
- APK 与设备未改动：未重建、未重装、未清数据；仅做只读指纹复核。

## 未验证项（须由用户 / AgY 验收）

以下**不在本轮自动化验证范围内**，不能视为已验收：

1. **真实 ACP 对话未验证** —— 本轮全部测试使用内存替身（`FakeAcpChatNotifier` /
   `FakeWorkspace`），**从未建立真实 SSH 或 Agent 会话，未发送任何真实消息**。
   协议级模拟测试 ≠ 真实对话验收。
2. **UI 人工验收未验证** —— 命令/技能面板、远端浏览选择器、图片放大、
   账号与额度弹窗的真实观感与交互手感未经人眼确认；自动化只覆盖了控件行为与布局不溢出。
3. **无崩溃结论限观察窗口** —— 冷启动观测窗口约 90 秒内未见崩溃记录，
   不构成「无崩溃」的普遍结论（见 STEP 5 的适用边界）。
4. **release APK 使用现有 debug 签名** —— 可侧载、可覆盖安装，
   但**不适合作为生产/商店发布签名**，正式发布前需配置独立 release 签名。
5. 上阶段遗留的开放项（`acp-usability-logic.md` 的 P2-2 启动页迁移、P2-3 `fixed`
   模式静默降级、P3 各项）本轮**未做修复，也未新增相关断言**，状态不变。
   其中「启动页保留用户独立选择、不迁移」按交接文档属**有意设计，非缺陷**。
