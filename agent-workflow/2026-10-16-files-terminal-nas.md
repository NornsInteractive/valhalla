# 文件、终端、ACP 和 NAS 实施契约

用户已确认实施完整方案并要求新包 ADB 安装和测试，OpenCode 无额度时主代理完成验证。本轮保持 1.0.7+8，不发布。

## 2026-10-16 新包验证记录

- UI/ARB 由原 AgY 会话完成，核心、测试与本地验证由主代理负责。未创建其他 AgY 会话、未轮换登录文件。
- `flutter test --no-pub --reporter expanded`：**3895 passed，31 skipped，0 failed**；跳过项为需额外环境的可选测试。真实隔离 SSH VM 的一万条扫描、取消和缩略图读取另行启用测试通过。
- `flutter analyze --no-pub`：**No issues found**。NAS 可见范围/后台取消/来源指纹/服务替换等专项10项通过；3/4/5/6/9导航项 × LTR/RTL 几何检查通过。
- 全量回归额外发现并修复：旧界面测试未注入应用设置依赖；默认排序入口从更多移到常驻，相关交互测试同步；缩略图最后使用者释放时立即取消超时计时器，避免挂起平台I/O残留期限任务。
- 正式签名 APK：`build/local-packages/20261016-files-terminal-nas/valhalla-1.0.7+8-oct16-review.apk`，包名 `com.norns.valhalla`，版本1.0.7/8，arm64-v8a / armeabi-v7a / x86_64。
- 最终 APK SHA-256：`de728f214d8805fefad66a9e317b0fc07b8820adec4927c2cd75cc4ba644c84d`；原正式证书SHA-256：`73dc6d178bbd7aba1ef85dd18b266ad491ae000c08915b9ee62cfc8383a92c7d`。
- 最终正式构建完成UTC **2026-10-16 03:07:30**。ADB `install -r` 成功，设备版本1.0.7/8；设备所示更新时间 **2026-10-16 11:08:40（UTC+8）**，首次安装时间仍为2026-10-15 02:24:07。拉回安装后base.apk与最终构建包逐字节一致。服务器配置保留。
- 设备为 `127.0.0.1:14251` 的 **Android x86_64 模拟器**，并非ARM实体手机。最终包操作PID26134、清理后重新启动PID19578；日志与操作截图/XML归档在同目录 `evidence/`。生产服务器没有升级、安装或对话写入。

### ADB 操作验收与最终包复核

- 文件页路径模式“左右滑动→折叠→左右滑动”，目录不变；目录选择弹窗独立记住模式，关闭重开仍保留，且不显示文件。验收后两处均恢复左右滑动。
- 多选时两行分别显示选择控制与下载/复制/移动/删除，在360dp不必横滑；只打开复制的目录选择器后取消，没有执行文件复制、移动或删除。设备原有四项自定义工具栏未被重置；五项新默认值由回归测试证明。
- 新 SSH 终端在未打开键盘时即显示远端提示符；360dp两个短页签可见，文字中心长按可重命名/关闭。抽屉把当前普通终端与tmux历史分开；未为普通终端伪造历史。更多菜单清屏可用，关闭tmux设置弹窗不自动弹键盘。
- 首轮正式包在真实 Gboard 操作中发现：输入法会批量提交 `a\n`，修饰键若只处理独立换行会丢失Ctrl+Enter并残留Ctrl。此问题由AgY修复共享输入层，补齐31项输入回归，再重新正式构建并覆盖安装；旧包哈希 `193ac088…` 仅作首轮证据，**不是最终交付包**。
- 最终包 Gboard 在隔离SSH原始字节接收端实测：Ctrl+C=`03`，Shift+Tab=`1b5b5a`，普通`a`后Ctrl+Enter=`61 1b5b31333b3575`；合并记录 `031b5b5a611b5b31333b3575`。之后普通`q`正常退出接收器，未残留Ctrl状态。证据 `gboard-key-bytes-final.json`、`gboard-batch-regression.log`。
- 清理时仅移除本轮隔离VM目录中的10000张生成PNG，再成功空扫描（0条、2323ms）清空该测试源索引，通过应用清空其派生缓存并移除测试源；最后移除该目录剩余的明确白名单测试文件。原SFTP服务器及既有文件未删除。删除的是可重建的测试数据，不包含用户业务数据。
- NAS与CLI实验开关均恢复原来的关闭状态。重新启动后仪表盘仍显示原SFTP-Perf-Fixture连接配置，未清除应用数据。`final-experimental-restored`、`final-source-restored`、`final-dashboard-restored`截图和最终日志已保存。
- 未做真实krm宿主机ACP升级或真实Agent发消息；版本来源、隔离迁移、初始化验证及失败回退由模拟/集成回归覆盖，生产升级仍需用户确认。未验证ARM实体机及大原图广域网体验。

### NAS 实际测量与边界

测试数据位于独立SSH VM，1万张8×8有效PNG，总原文件约740KB；此数据用于索引规模验证，不代表大原图/广域网性能。

| 场景 | 条数 | 用时 | build P95 | raster P95 | total P95 | RSS变化 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 首次扫描 | 10000 | 4071ms | 1.18ms | 17.35ms | 19.96ms | 277934080 → 290451456 B |
| 重扫并立即切到仪表盘 | 10000 | 3681ms | 3.00ms | 22.25ms | 38.68ms | 287391744 → 300695552 B |
| 最终包重扫 | 10000 | 3740ms | 0.92ms | 16.80ms | 18.02ms | 287657984 → 299528192 B |

三次扫描均完成，应用可切页，返回保留图库与滚动位置，无ANR/未处理异常。第二次total P95包含页面过渡，**没有达到全场景≤32ms目标**；不能用扫描结果宣称所有切页场景达标，后续仍有渲染/过渡优化空间。前两次为首轮新包，最后一次为修复Gboard后重新构建的最终包；NAS相关源码期间未变。

照片分类显示10.0k；滚动后测试源缓存统计为 **36张派生缩略图、3.3KB**，下载列表0，没有全库原文件缓存。图库预布局挂载43项的回归已从43次读取降为可见项与前一屏的有界请求；全局预取上限24。音乐元数据只处理可见项，视口变更丢弃已经离屏的旧批次行。

### 构建过程说明

最初正式构建受到测试模式 `GeneratedPluginRegistrant.java` 中 `integration_test` 引用影响，两次失败日志已保留。当前Flutter SDK在`--no-pub`下不重新生成该注册文件；最终使用同一SDK的 `injectPlugins(releaseMode:true, androidPlatform:true)` 生成正式插件注册，再串行构建成功。未修改SDK或手改注册Java文件，也未把测试插件塞进正式依赖。

生产源码、未跟踪新增文件、pubspec/lock均包含在构建前后SHA清单中，两份一致。`fake_async 1.3.3`只从既有传递测试依赖明确声明为直接dev依赖，版本未变，无新增运行依赖。

本轮没有推送、发布或提升版本号。下文保留集成期间的问题记录作为修复过程，所列UI阻塞均已由AgY修正，并纳入上述最终通过的回归；不代表仍待处理。

## 所有权

UI/ARB/Widget 展示修改全部由原 AgY Valhalla 会话 `ec81a4be-7543-45ee-8658-f68966f57d3b`，`gemini-3.8-flash-high`、effort high 完成。主代理负责服务、存储、协议、集成、验证和构建。

## 展示验收

### 第三轮集成即时反馈（需 AgY 一并修正）

主代理重新生成语言后执行真实 UI 回归发现两处阻塞，不是旧日志：

- `lib/widgets/remote_browser_dialog.dart:541` 调用不存在的 `setPickerPathDisplayMode`。实际 API 只有 `settingsProvider.notifier.setRemotePathDisplayMode(mode, picker: true)`，请修改 UI 调用，不要给核心增加冗余别名。
- `terminal_accessory_bar.dart:870` 的修饰键 `Row` 在 2x 字号下水平溢出（320/360/430dp、LTR/RTL 全部复现）；44dp 命中尺寸已改善，但需要让 36dp 视觉内部文字布局约束兼容大字号，锁定图标也不能挤溢出。不改变44dp触控和现有修饰键事件。

日志 `/tmp/valhalla-oct16-ui-final1.log`，55 项通过、8 项失败（包括编译连带错误）。请在 NAS 接线之外仅修这两处；无需自己运行测试。

复核还发现 `terminal_view.dart` 新增 `Opacity(opacity:0.001)` 加 1px `OverflowBox` 隐藏旧清屏/tmux/Mosh按钮。这种为兼容旧测试留下的不可见可点击控件不可保留，会制造溢出/无障碍幽灵控件。请整个删除；主代理会把旧测试改为真实点击 More 菜单，不需要保留旧按钮 key。页签自动滚动目前 `index*96` 估算也不可靠，请使用实际页签 key/rect 的 ensureVisible（postframe、仅水平页签滚动，不改变终端输出滚动位置）。

新真实操作回归 `/tmp/valhalla-oct16-terminal-actions2.log` 还复现：直接长按 `terminal_tab_second` 中心后找不到 Close Tab 操作。标签内部 `Tooltip` 的默认长按手势可能抢占外层 `GestureDetector.onLongPress`，请处理此竞争，保证按标签文字中心也能打开重命名/关闭，不只按边缘。不得通过测试直接调用回调绕过真实手势。

下一次回归 `/tmp/valhalla-oct16-ui-final2.log`：90项通过、1项失败，仅新增 picker 模式反复保存测试遇到 `remote_browser_toolbar.dart:242/259` 模式菜单 Row 内长文字无 Flexible，宽256时溢出38px。路径存储/目录保持等断言均已通过，需AgY让两个菜单文本在窄屏/大字号自动换行或适配，不可裁掉关键内容。

- RemoteBrowserBreadcrumb 增加 mode/onModeChanged；mode 为 RemotePathDisplayMode.scroll/collapsed。settingsProvider 提供 filePathDisplayMode、pickerPathDisplayMode，分别持久化，默认 scroll；setRemotePathDisplayMode(mode, {required bool picker})。文件页传文件偏好，所有文件浏览弹窗传 picker 偏好，不影响目录、搜索、已选项。模式菜单两处可反复操作，折叠基于实际宽度。
- 文件工具栏默认 upload/create/view/transfers/sort，已有自定义值保留；多选两行，选择控制和业务操作分开，360dp 无需横滑，44dp 触控。
- 底部导航横条与每个 slot 中心对齐，任意数量、RTL、横向滚动都正确。
- SSH 顶部只保留会话入口、紧凑页签、新建、更多。更多含清屏、tmux 设置、新建 Mosh；360dp 两个短标题页签可见，页签长按关闭/重命名，会话抽屉同时展示当前终端及历史。保留原关闭和历史安全语义。
- 终端底部两行约92dp：默认 Esc/Tab/Ctrl/Shift/Alt/粘贴；右侧固定倒T方向区和右下角键盘。Fn 默认放更多。自定义添加、移除、拖动排序、恢复默认；超容量仅常驻区分页。视觉键34–36dp、触控>=44dp；方向长按重复，修饰键现有单次/按住/锁定保持。所有共享终端调用点一致。
- NAS NasThumbnailImage 不再 initState 自动请求；使用核心 nasPreviewRequestsProvider 控制允许的可见/预取 itemKey；每个列表在滚动停稳后提交 viewport 范围，可见优先、前方一屏最多24项预取、离开取消。大字号、主题、17语言齐全。
- Agent更新展示版本、路径、来源和迁移说明，未知来源只能确认安装新版独立副本，不直接覆盖未知二进制。

## 核心验收

### 集成复核待 AgY 修正

- 终端页签目前仍有常驻deleteIcon/onDeleted，与已确认去掉每项关闭图标不符；请移除，关闭操作保留长按/会话抽屉。增加选中页签自动滚入可视区，360dp至少两短标题。
- 新键区的38dp列和42dp行触控不足44dp；视觉可36dp，命中区至少44dp；常驻区列数不要clamp最小3，320dp不足时允许2列分页，字号2x不溢出。
- RemoteBrowserBreadcrumb默认值目前collapsed，请改scroll并将依赖旧行为的测试显式指定collapsed；不保留segments.length>3触发强制折叠，按实际宽度决定。
- 新增 test/features/oct16_navigation_alignment_test.dart 已复现原版LTR/RTL偏移，修改后运行用于精确几何验收（含3/4/5/6/9项）。
- 新增 test/features/oct16_terminal_layout_test.dart 检查320/360/430dp、2x字号、LTR/RTL，倒T物理方向不随RTL镜像、触控>=44dp、键盘固定物理右下；这是共享终端输入区，需要LTR方向布局而非继承页面RTL镜像。

### 已落地 NAS 展示接口

`lib/core/providers/nas_preview_provider.dart` 暴露 `nasPreviewKey(item)`、`nasPreviewRequestsProvider`，notifier `.update(owner, visible: List<NasMediaItem>, prefetch: List<NasMediaItem>)` 和 `.release(owner)`。state 为 Map<key,NasPreviewRequest>，entry.item / entry.visible；全局预取最多24项、可见优先去重。请 AgY 为 NAS 页面建立 viewport 观察器（复用滚动通知与已布局 tile 几何，不引入依赖），滚动时清空预取，停稳150ms再提交可见和滚动方向前一屏；离页/后台 release。NasThumbnailImage 按本key select，只允许entry非null才调用 `.thumbnail(item, owner:this, prefetch:!entry.visible)`，不允许时 release 并显示占位。必须在 home/照片/视频/音乐/分组/详情等所有缩略图调用点生效，Image.file 按实际显示像素设置cacheWidth/cacheHeight。限制源图16MiB。元数据服务只从该provider可见项获取音乐标签，扫描期间不执行。

主Shell的AnimatedIndexedStack已在隐藏页禁用TickerMode，viewport观察器依赖TickerMode.of(context)停止非当前页任务，并监听应用生命周期。详情/迷你播放器可单独作为可见viewport owner，不因离开主NAS列表丢失封面。不要在build/dispose同步写provider，使用安全的post-frame/异步释放。现有 test/features/nas_thumbnail_lifecycle_test.dart 替身已接受prefetch参数，UI行为测试须按可见范围新契约更新。

### 已落地 Agent 展示接口

AgentComponentUpdate 新增 `replacementAcpCommand`。当 `reasonCode == AGENT_UPDATE_CODEX_ADAPTER_MIGRATION` 时，显示“安装新版适配器并切换此 Agent”，说明保留旧程序／配置可回退，展示replacementAcpCommand、installed/latest/source和真实command。这不是普通原地升级；未知版本仍允许用户明确安装独立副本。core apply初始化验证通过后才持久化切换，不需要UI另写配置。

修复旧Codex ACP版本来源检测及安全迁移；Ctrl+Enter 编码区分普通Enter，保留Gboard单次状态和物理输入；扫描只索引不自动全库媒体探测，进度节流250ms，列表刷新<=2秒；预览<=2并发、本地解码<=1，仅可见/前一屏，图片16MiB音视频3MiB/5秒。原文件仅用户明确下载时缓存。失败扫描保留旧索引，连接/用户隔离。

完成后新包、原签名、ADB -r保留数据，检查真实安装时间/版本/拉回哈希，独占设备有界操作及隔离字节接收端测试，记录实际结果与未验范围。
