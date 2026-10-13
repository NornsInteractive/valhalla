# 2026-10-13 应用商店视图与清理保护只读审查

审查范围：AgY 第一批 `app_store_tab.dart` 的移动端视图/定位，以及
`application_cleanup_helper.dart` 新增目录预检、外部挂载别名保护。
本记录仅来自源码；未运行 Widget 测试、Python helper、Docker 或 ADB。
位置对应审查时文件，后续 AgY 修改可能使行号移动。UI 修正仍交 AgY。

## 待修正：应用商店视图

### 根代理后续实际验证（更新，优先处理）

后续四文件完整复验（native、naming、app-store、uninstall）**68passed，exit0**。
日志 `/tmp/valhalla-browser-implementation.NXfb1raa/root-stable-first-slices.log`。
这是这四个界面的稳定源码测试；共享浏览组件、调用方和设备交付仍待验。

Phase3更新：两个编译阻断已被AgY修复。命名UI5项已通过（根代理补测试中
新安装必须显式选择access的真实操作，没有放宽产品断言）；AppStore两项
`store first toggle|store grid bounds` 复验2passed，exit0。
日志分别`root-naming-ui2.log`与`root-store-regression2.log`，同下方证据目录。
共享浏览器与所有调用方/ADB仍待验，不能由这几项推导全面通过。

命名UI的新增 `test/features/application_naming_ui_test.dart` 首跑编译失败：
`app_operation_wizard_dialog.dart:1586` 访问不存在的
`ApplicationDeployment.configuration`；旧配置只来自
`widget.initialConfiguration`（按现有调用合同处理，不给model乱加属性）。
此外主服务有歧义时 `_mainService` 为null，dropdown却展示`serviceNames.first`，
用户以为已选但提交仍null。应保持未选择/提示选择直到用户明确选中；metadata
已有可信main则预选一致。该测试文件覆盖单服务精确命名、非法名、多服务显式选择、
metadata main及legacy配置保留。不要修测试来掩盖UI缺陷。

用户已授权本轮直接验证。2026-10-13 新17语言字段生成后，根代理执行三文件
Widget gate：52 passed / 3 failed，日志
`/tmp/valhalla-browser-implementation.NXfb1raa/root-first-slice-ui-tests.log`。
其中两项复现下方正文问题1、2；新增320/360/390/430dp真实两列测试均已通过，
整dataRoot/child选择去重Widget测试已通过。另一项是编译阻断：

- `lib/features/nas/widgets/nas_native_install_dialog.dart:837` 把
  `final displayedBlockers = ...` 放进了 `children: [ ... ]` widget集合中，
  Dart拒绝 `final` 声明。这项必须由AgY移到函数体局部（或合法Builder），
  仍只过滤ALREADY_INSTALLED，不过滤真实端口/系统阻断。
- 新native测试fixture现在带真实ALREADY_INSTALLED blocker，并补同时存在
  PORT_BUSY的用例，不能回退到旧空blockers假数据掩盖行为。

### 1. 默认模式使用两种宽度，首次切换可能没有效果

- 位置：`lib/features/app_center/widgets/app_store_tab.dart:428`、`:439`、`:447`
  用 `MediaQuery` 整屏宽；`:719` 实际列表布局用 `constraints.maxWidth`。
- 条件：未保存视图偏好，整屏宽度 >= 600dp，但侧栏/父容器扣除后内容区 < 600dp。
  页面实际为列表，按钮却按网格计算；首次点击仍设为列表，同时用错误布局计算锚点。
- 最小修法：按钮图标、提示、切换逻辑与内容区共用实际可用宽度和同一有效模式。
  不在 `_toggleViewMode` 再接收按整屏计算的 `isCompact`。
- 回归：例如整屏 640dp、内容区 560dp、无已保存偏好；首次点击必须从列表变两列卡片。

### 2. 版本号不受宽度约束，窄卡片可溢出

- 位置：同文件 `:1054` 的网格页脚 Row，`:1066` 版本 Text 没有 Flexible、maxLines 或 ellipsis；
  横向列表页脚也有同类写法。
- 320dp 两列网格中每卡宽 138dp，扣除内边距后仅 114dp。
  无约束版本号先按自身宽度排版，较长镜像版本/构建编号会挤出 Row。
- 最小修法：给版本号分配有界的弹性宽度并单行截断，来源仍可读；不要用缩小字体绕过。
- 回归：长版本号、长来源名称、正常字体两列和 2x 字体一列，检查无 RenderFlex 溢出。

### 3. 网格徽标高度预算未包含真实行高

- 位置：同文件 `:164` 使用 `max(18, textScaler.scale(10) + 6)`；
  真实徽标文字样式继承 `height: 1.5`，且另有上下各 2dp padding。
- 2x 字体时预算为 26dp，真实单行占位约 34dp，摘要区域因此少约 8dp；
  已安装/不兼容徽标换行时差距更大。
- 最小修法：像现有列表高度计算一样使用徽标 TextPainter 的真实行高加 padding；
  徽标文字限制单行省略，确保固定网格高度与内容合同一致。
- 回归：2x 字体，分别覆盖已安装、架构不兼容状态及长本地化标签，摘要不被截半行。

### 4. 锚点失效时仍使用旧索引

- 位置：同文件 `:247` 先取 `_anchorIndex`；`:252` 只有旧应用仍存在才替换索引。
  筛选回调和 `_clearFilters` 也未清除旧锚点或回到新结果起点。
- 条件：切换视图的 post-frame callback 执行前，筛选/目录刷新移除了原锚点应用；
  代码把旧序号夹到新结果长度，可能直接跳到新列表中部或末尾。
- 最小修法：筛选变化使待执行定位失效并重置锚点；旧应用不存在时回退新列表起点，
  不将其他结果的同一序号视为原应用。保留同一结果集视图切换时的应用 ID/来源 ID 定位。
- 本界面目前没有独立排序入口，不新增排序功能；目录刷新导致重排时优先按应用键定位。

## 源码可确认的正确部分（不是设备验收）

- `AppStoreGridLayout.compute` 的 compact 分支正常字体明确两列，2x 字体明确一列。
- 网格使用独立纵向卡片，不再把横向列表卡原样放进网格。
- 列表 itemExtent 为卡片高度 + 8dp，顶部 12dp；网格 row stride 为卡片高度 + 12dp，
  顶部 16dp。切换锚点使用的基本步长与实际布局一致。
- 大字体一列仍走纵向网格卡片，未退回横向列表外观。

## 清理保护：普通 dataRoot 是否被误拒绝

- `application_cleanup_helper.dart:176` 的 `guard_mount_aliases` 排除了
  `within(mountpoint, source)`，即承载候选目录的 `/`、`/home`、`/srv` 等祖先挂载。
  普通目录仅存在这些承载挂载时，不会因为其 filesystem root 覆盖候选就误报共享。
- 其他设备的挂载，以及同设备但 backing 子树不重叠的挂载，不触发新增 SHARED_PATH。
  对同设备、不同挂载点导出的相同/祖先/子树 backing 路径拒绝清理是预期保护。
- 只读预检不跟随普通符号链接、不读取文件正文；无 `.ssh`/`.gnupg`、无共享或嵌套挂载、
  可读取且在预算内的普通数据树不会因为新 guard 被拒绝。整个系统目录、实际挂载点仍按原规则保护。
- `.ssh`/`.gnupg` 名称的文件、目录、链接均保留；深度超 128、条目超 100 万或总时间超限时
  安全阻止。大目录可能需要更长预检或被预算限制，不能把这种结果显示成已删除或强制放行。
- 预检中消失的子项已映射 PATH_CHANGED，而不是将整个数据根误判 ALREADY_ABSENT。

未实际执行普通目录/外部 bind fixture，本段只能说明分支条件正确；仍需 OpenCode 用
隔离 fixture 覆盖正常 ancestor mounts、不同设备、精确/祖先/子树外部别名、预检后新增保护项。
