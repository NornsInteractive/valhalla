# Stitch NAS 媒体库复刻（UI handoff）

执行者：AgY CLI 仅历史 Valhalla 会话 `ec81a4be-7543-45ee-8658-f68966f57d3b`，模型 `gemini-3.8-flash-high`、effort `high`。已确认其 `stitch` HTTP MCP 启用并成功读取项目。验证/测试/格式化/构建/ADB 仅由 OpenCode `opencode/mimo-v2.6-flash-free` 负责。

## 设计来源与目标

- Stitch 项目：`Valhalla`，ID `106380959210290`。
- 移动 NAS 页面：`c4d37efca65c40f0a17a4030ee1bb7df`；桌面 NAS 页面：`2f750290bb634bbab8fef5e616fafb3c`。AgY 会话 scratch 中有 `nas_mobile.html`、`nas_desktop.html`、`screenshot_nas_mobile.png`、`screenshot_nas_desktop.png`；须以 Stitch MCP 当前页面为准，不使用过期截图或凭空补 UI。
- 用户要复刻当前 NAS 界面，而不是重建全 App。Stitch 截图中的移动底部 4-Tab、桌面 256px 侧边栏、全局顶部服务器栏已由 `MainShell` 负责；NAS 页面不得再画一套全局导航或修改 `MainShell`。

## 视觉计划（遵循现有 Valhalla 设计系统）

- 主题：Stitch 的暗底层级 `#10141a/#181c22`、翡翠主强调 `#4edea3`、影视紫与音频靛青，为方向而非硬编码常量。实际取 `Theme.of(context).colorScheme`、`VRadius`、`VSpace`；亮色/AMOLED/自定义强调色继续可用。现有 Inter 用于界面，JetBrains Mono 仅用于容量、码率/时长、路径等数据。
- 信息层级：真实来源/扫描状态 → 横滑分类胶囊与搜索 → 媒体内容。移动端单列、横向海报/照片条与音乐列表；宽屏端图库网格、影视海报墙、音乐唱片/曲目架。跨端都复用一个内容状态与操作契约。

```text
移动：来源/操作 → 分类胶囊 → [播放条由现有 Shell 承载] → 视频横滑 → 照片时间段 → 音乐列表
宽屏：[现有 Shell 侧栏] | 来源/搜索/操作 → 图库网格 → 视频海报墙 → 音乐架 | [现有全局播放条]
```

- 视觉记忆点是“真实媒体封面 + 轻量元数据”形成的三层媒体货架。只用 `thumbnailPath(item)` 等真实缓存/远端内容；无封面时用主题化占位，不嵌入 Stitch 的示例海报、名字、评分或虚构用量。

## 已有功能契约，必须保留

- `NasMediaView` 已有 8 个 `NasMediaTab`、来源切换/新增/编辑、扫描/配置/设置、搜索防抖、面包屑、照片查看器、视频/音乐应用内与外部打开、收藏、播放列表、下载、分页、错误/空态、加载骨架、Cast 菜单及 Mini Player。
- `nasProvider` 的 `NasState.items` 是当前索引分页（最多 200 条），`totals` 是库的真实分类总数。首页可用当前页做精选/最近预览，不能将当前页条数伪装成全库总量；某类总数大于零但本页无项时应提供进入对应分类的入口。不可在 widget 直接执行 SQLite/SSH/SFTP 查询。
- `NasMediaItem` 有真实 `title/artist/album/durationMillis/sizeBytes/modifiedEpoch/width/height/isFavorite`，无评分、进度、字幕、EXIF 明细、人脸聚类、物理磁盘剩余容量。仅展示有数据的字段；继续观看进度只有实际 `NasPlaybackState` 时才可展示。
- 当前存在前台 DLNA `NasCastService` 和 `NasCastSheet`，所以 Stitch 的投屏视觉可接已有 Cast；不要标注尚未实现的 AirPlay 2 或模拟设备。快速上传、智能人脸/刮削评分/离线同步/分类磁盘占用暂不做假按钮，也不借此扩展业务层。
- `MainShell` 已承载全局 Mini Player；NAS 独立页才渲染 `NasMiniPlayer`。避免播放条重复。已有可访问的控件 key（`nas_source_selector_button`、`nas_search_field`、`nas_tab_*`、`nas_image_grid`、`nas_media_list` 等）尽量保持，以免测试和自动化断裂。

## 允许与禁止文件

- AgY 可修改：`lib/features/nas/nas_media_view.dart`、`lib/features/nas/widgets/nas_mini_player.dart`、`lib/features/nas/widgets/nas_localizations.dart`；确有新增可见文案时仅 `lib/l10n/app_en.arb`、`lib/l10n/app_zh.arb`。若需要其他 UI 文件先说明，不得自行扩权。
- 禁止修改：`lib/core/**`、`lib/data/**`、`lib/infrastructure/**`、`lib/app/**`、`lib/features/shell/**`、所有测试文件、生成 l10n、依赖/平台代码，以及当前工作区未提交的 ACP 修改。不可用假数据补视觉，不可破坏原有媒体操作。

## 验收

1. 与两张 Stitch 页面可见的 NAS 内容结构、卡片密度、响应式分栏/横滑、主题氛围相符；不会重复全局导航；亮暗与窄屏无溢出。
2. 来源为空、未配置、未扫描、加载中、搜索无结果、连接失败、分页与播放中状态均可用。照片、视频、音乐、收藏、播放列表、下载和设置入口仍可到达；卡片点击仍使用原打开策略、下载/收藏/播放动作。
3. 200 条分页仍惰性构建或有上限；图片走现有缩略图缓存与占位，不因滚动反复下载或在 build 中作阻塞文件检查。语义标签、焦点、文字缩放与减弱动态效果基本可用。
4. AgY 完工只报告改动和与 Stitch 的对应关系，不运行测试。OpenCode 维护相关 widget 测试并执行格式化、生成本地化、静态分析、聚焦及全量测试、正式 APK 与 ADB。若 MiMo 模型不可用，必须明确记录而不得代跑。

## 实施与验证结果（2026-09-29）

- AgY 在指定 Valhalla 历史会话和 `gemini-3.8-flash-high`/high 中通过 Stitch MCP 读取移动、桌面 NAS 页面，修改 `nas_media_view.dart`：首页影视、照片、音乐货架与真实分类占比条，来源/扫描状态层级和横向分类胶囊；窄屏影视/照片横滑，宽屏改为同卡片响应式网格。保留 MainShell 导航及原 NAS 来源、扫描、搜索、下载等入口；未添加设计稿中的虚构评分、容量或上传按钮。
- 首页只展示当前分页中的前 8 个视频、10 张照片、4 条音乐；分类标题进入完整列表。首页不再提供“加载更多”（预览上加载后不可见），分类页保留分页。照片预览显示文件名与语义标签，视频预览可收藏，音乐列表复用原列表项操作。缩略图移除同步 `existsSync`，用 `Image.file(errorBuilder)` 降级。
- OpenCode 指定 `opencode/mimo-v2.6-flash-free` 已格式化 NAS UI，并把分页测试切到视频分类后再验证原有加载断言；`flutter test test/features/nas_media_view_test.dart test/features/nas_navigation_test.dart` 全部通过（32/32），`flutter analyze --no-pub` 为 `No issues found`，`git diff --check` 通过。
- OpenCode 在宽屏改动后重跑上述分析和定向测试仍通过，再次执行 `flutter build apk --release` 成功，产物 `build/app/outputs/flutter-apk/app-release.apk`（121.7 MB），并通过 `adb -s 127.0.0.1:14251 install -r` 重新安装成功。应用启动有进程；设备上进入 NAS 首页并滚动检查了影视、照片、音乐货架和概览条，无明显溢出。该设备当前使用 Fixture-WebDAV 测试源，真实远端 NAS 连接与媒体播放及宽屏实机视觉仍需另行手动验收。
